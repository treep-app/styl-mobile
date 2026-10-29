import '../routing/app_routes.dart';
import 'auth_controller.dart';
import 'session_store.dart';

class PostAuthDestination {
  const PostAuthDestination(this.route, {this.arguments});

  final String route;
  final Object? arguments;
}

bool isPlaceholderSalonAddress(String? address) {
  final value = (address ?? '').trim().toLowerCase();
  return value.isEmpty ||
      value == 'address to be added' ||
      value.contains('to be added');
}

SalonSetupArgs _setupArgs(String? shopId) => SalonSetupArgs(
      shopId: shopId,
      fromOnboarding: true,
    );

Future<PostAuthDestination> _ownerHomeDestination(
  AuthController auth,
  SessionStore session,
) async {
  final preferCustomer = await session.readPreferCustomerView();
  if (preferCustomer) {
    return const PostAuthDestination(AppRoutes.customerShell);
  }

  try {
    final shops = await auth.catalogApi.listMyShops();
    if (shops.any((s) => s.isOwner == true)) {
      return const PostAuthDestination(AppRoutes.providerSalonDashboard);
    }
  } catch (_) {}

  return const PostAuthDestination(AppRoutes.providerShell);
}

Future<void> _markOwnerSetupComplete(SessionStore session) async {
  await session.setOwnerOnboardingComplete(true);
  await session.clearProviderSetup();
}

/// True when the owner has progressed past the first profile step (so a stale
/// `salon_profile` stage should not trap them after refresh).
Future<bool> _ownerHasProgressedPastProfile(
  AuthController auth,
  String shopId,
) async {
  try {
    final services =
        await auth.catalogApi.listServices(shopId, includeInactive: true);
    if (services.isNotEmpty) return true;
  } catch (_) {}
  try {
    final shop = await auth.catalogApi.getShop(shopId);
    final phone = (shop.phone ?? '').trim();
    if (phone.isNotEmpty) return true;
    if (!isPlaceholderSalonAddress(shop.addressLine) &&
        shop.addressLine.trim().isNotEmpty) {
      return true;
    }
  } catch (_) {}
  return false;
}

/// Resolves where a logged-in user should land after splash / login / OTP.
///
/// Owner salon setup: profile → services → hours → team → booking → salon dashboard.
/// Once marked complete (booking Save or owner dashboard), the wizard never resumes.
Future<PostAuthDestination> resolvePostAuthDestination(
  AuthController auth, {
  SessionStore? store,
}) async {
  final session = store ?? SessionStore();
  final user = auth.user;
  if (user == null) {
    return const PostAuthDestination(AppRoutes.welcome);
  }

  if (!user.isBarber) {
    final nameMissing = (user.fullName ?? '').trim().isEmpty;
    final emailMissing = !user.hasEmail;
    if (nameMissing || emailMissing) {
      return const PostAuthDestination(
        AppRoutes.customerPersonalInfo,
        arguments: CustomerPersonalInfoArgs(fromOnboarding: true),
      );
    }
    return const PostAuthDestination(AppRoutes.customerShell);
  }

  final preferCustomer = await session.readPreferCustomerView();
  if (preferCustomer) {
    return const PostAuthDestination(AppRoutes.customerShell);
  }

  final ownerDone = await session.readOwnerOnboardingComplete();
  if (ownerDone) {
    await session.clearProviderSetup();
    return await _ownerHomeDestination(auth, session);
  }

  final stage = await session.readProviderSetupStage();
  final savedShopId = await session.readProviderSetupShopId();

  switch (stage) {
    case 'provider_type':
      return const PostAuthDestination(AppRoutes.providerType);
    case 'salon_profile':
      // Recover owners who finished setup but were re-queued here because the
      // salon address was still a placeholder.
      if (savedShopId != null &&
          await _ownerHasProgressedPastProfile(auth, savedShopId)) {
        await _markOwnerSetupComplete(session);
        return await _ownerHomeDestination(auth, session);
      }
      try {
        final shops = await auth.catalogApi.listMyShops();
        final owned = shops.where((s) => s.isOwner == true).toList();
        if (owned.isNotEmpty &&
            await _ownerHasProgressedPastProfile(auth, owned.first.id)) {
          await _markOwnerSetupComplete(session);
          return await _ownerHomeDestination(auth, session);
        }
      } catch (_) {}
      return PostAuthDestination(
        AppRoutes.providerSalonProfile,
        arguments: SalonProfileArgs(
          shopId: savedShopId,
          fromOnboarding: true,
        ),
      );
    case 'services':
      return PostAuthDestination(
        AppRoutes.providerServices,
        arguments: ProviderServicesArgs(
          shopId: savedShopId,
          fromOnboarding: true,
        ),
      );
    case 'opening_hours':
      return PostAuthDestination(
        AppRoutes.providerSalonHours,
        arguments: _setupArgs(savedShopId),
      );
    case 'team':
      return PostAuthDestination(
        AppRoutes.providerSalonTeam,
        arguments: _setupArgs(savedShopId),
      );
    case 'booking_settings':
      return PostAuthDestination(
        AppRoutes.providerSalonBookingSettings,
        arguments: _setupArgs(savedShopId),
      );
  }

  // No active wizard stage — owners with a salon go to the dashboard.
  try {
    final shops = await auth.catalogApi.listMyShops();
    if (shops.any((s) => s.isOwner == true)) {
      await _markOwnerSetupComplete(session);
      return const PostAuthDestination(AppRoutes.providerSalonDashboard);
    }
  } catch (_) {}

  return const PostAuthDestination(AppRoutes.providerShell);
}

/// First screen after the OS launch splash (no second in-app splash).
Future<PostAuthDestination> resolveStartupDestination(
  AuthController auth, {
  SessionStore? store,
}) async {
  if (auth.isLoggedIn) {
    return resolvePostAuthDestination(auth, store: store);
  }
  final session = store ?? SessionStore();
  final onboardingDone = await session.isOnboardingDone();
  return PostAuthDestination(
    onboardingDone ? AppRoutes.welcome : AppRoutes.onboarding,
  );
}
