import '../network/api_models.dart';

/// Named routes for the unique customer + service provider journeys.
///
/// Figma duplicates (OTP-1..4, Sign Up-(Barber)-2 variants, appointment
/// list variants) are collapsed into one screen each.
abstract final class AppRoutes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const roleSelection = '/role-selection';
  static const welcome = '/welcome';
  static const chooseRole = '/choose-role';
  static const providerType = '/provider-type';
  static const accountCreated = '/account-created';

  // Customer auth
  static const customerSignUp = '/customer/sign-up';
  static const customerLogin = '/customer/login';
  static const customerOtp = '/customer/otp';

  // Customer main
  static const customerShell = '/customer';
  static const providerDetail = '/customer/provider';
  static const bookAppointment = '/customer/book';
  static const barberList = '/customer/barber-list';
  static const notifications = '/customer/notifications';
  static const addCard = '/customer/add-card';
  static const customerPersonalInfo = '/customer/personal-info';
  static const customerSettings = '/customer/settings';
  static const chooseLook = '/customer/choose-look';
  static const lookDetails = '/customer/look';
  static const findProfessionals = '/customer/find-professionals';
  static const looksBook = '/customer/looks-book';
  static const leaveReview = '/customer/leave-review';
  static const marketplaceSearch = '/customer/search';
  static const locationSearch = '/customer/location';
  static const browseServices = '/customer/browse-services';
  static const searchServices = '/customer/search-services';
  static const findThisLook = '/customer/find-this-look';
  static const nearbyMap = '/customer/nearby-map';
  static const availableToday = '/customer/available-today';
  static const filterResults = '/customer/filter-results';
  static const bookAgain = '/customer/book-again';
  static const salonProfessionals = '/customer/salon-professionals';

  // Service provider auth
  static const providerSignUp = '/provider/sign-up';
  static const providerLogin = '/provider/login';

  // Service provider main
  static const providerShell = '/provider';
  static const providerAppointmentsList = '/provider/appointments-list';
  static const providerPersonalInfo = '/provider/personal-info';
  static const providerAbout = '/provider/about';
  static const providerPrivacy = '/provider/privacy';
  static const providerTerms = '/provider/terms';
  static const providerHelp = '/provider/help';
  static const providerManageSalon = '/provider/manage-salon';
  static const providerSalonProfile = '/provider/salon-profile';
  static const providerServices = '/provider/services';
  static const providerServiceEdit = '/provider/service-edit';
  static const providerServiceAssign = '/provider/service-assign';
  static const providerSalonHours = '/provider/salon-hours';
  static const providerSalonTeam = '/provider/salon-team';
  static const providerSalonBookingSettings = '/provider/salon-booking-settings';
  static const providerSalonVerification = '/provider/salon-verification';
  static const providerSalonDashboard = '/provider/salon-dashboard';
  static const providerAddBarber = '/provider/add-barber';
  static const providerAddProfessional = '/provider/add-professional';
  static const providerInvitationSent = '/provider/invitation-sent';
  static const providerPendingInvitation = '/provider/pending-invitation';
  static const providerProfessionalAdded = '/provider/professional-added';
  static const providerBarberDetail = '/provider/barber-detail';
  static const providerSettings = '/provider/settings';
  static const providerPortfolio = '/provider/portfolio';
  static const providerAvailability = '/provider/availability';
  static const providerAnalytics = '/provider/analytics';
}

/// Customer personal info — settings edit or post-signup setup.
class CustomerPersonalInfoArgs {
  const CustomerPersonalInfoArgs({this.fromOnboarding = false});

  final bool fromOnboarding;
}

/// Arguments for [AppRoutes.customerOtp].
class OtpArgs {
  const OtpArgs({
    required this.phoneNumber,
    this.fullName,
    this.password,
    this.fromSignUp = true,
    this.isServiceProvider = false,
    this.providerSignup,
  });

  final String phoneNumber;
  final String? fullName;
  final String? password;
  final bool fromSignUp;
  final bool isServiceProvider;
  final ProviderSignupDraft? providerSignup;
}

/// Captures provider onboarding fields to apply after OTP verify.
class ProviderSignupDraft {
  const ProviderSignupDraft({
    required this.createSalon,
    this.linkShopId,
    this.salonName,
    this.addressLine,
    this.area,
    this.district,
    this.pincode,
    this.description,
    this.website,
    this.services = const [],
  });

  final bool createSalon;
  final String? linkShopId;
  final String? salonName;
  final String? addressLine;
  final String? area;
  final String? district;
  final String? pincode;
  final String? description;
  final String? website;
  final List<ProviderServiceDraft> services;
}

class ProviderServiceDraft {
  const ProviderServiceDraft({
    required this.name,
    required this.priceAmount,
  });

  final String name;
  final double priceAmount;
}

/// Arguments for login screens (customer or provider).
class LoginArgs {
  const LoginArgs({this.isServiceProvider = false});

  final bool isServiceProvider;
}

/// Arguments for [AppRoutes.providerDetail].
class ProviderDetailArgs {
  const ProviderDetailArgs({
    required this.shopId,
    required this.name,
    required this.subtitle,
    required this.rating,
    required this.distance,
    required this.address,
    this.imageUrl,
    this.description,
    this.barberUserId,
    this.lookName,
    this.lookImageUrl,
  });

  final String shopId;
  final String name;
  final String subtitle;
  final double rating;
  final String distance;
  final String address;
  final String? imageUrl;
  final String? description;
  final String? barberUserId;
  final String? lookName;
  final String? lookImageUrl;
}

/// Arguments for [AppRoutes.looksBook].
class LooksBookArgs {
  const LooksBookArgs({
    required this.shopId,
    required this.salonName,
    required this.address,
    this.imageUrl,
    this.barberUserId,
    this.lookName,
    this.lookImageUrl,
    this.rating = 0,
    this.distance = 'Nearby',
    this.serviceId,
    this.preferredDate,
    this.preferredSlotStartAt,
  });

  final String shopId;
  final String salonName;
  final String address;
  final String? imageUrl;
  final String? barberUserId;
  final String? lookName;
  final String? lookImageUrl;
  final double rating;
  final String distance;
  final String? serviceId;
  final DateTime? preferredDate;
  final String? preferredSlotStartAt;
}

/// Arguments for [AppRoutes.leaveReview].
class LeaveReviewArgs {
  const LeaveReviewArgs({
    required this.appointmentId,
    required this.salonName,
    required this.serviceName,
    required this.dateLabel,
    this.imageUrl,
  });

  final String appointmentId;
  final String salonName;
  final String serviceName;
  final String dateLabel;
  final String? imageUrl;
}

/// Arguments for [AppRoutes.bookAppointment].
class BookAppointmentArgs {
  const BookAppointmentArgs({
    required this.shopId,
    required this.salonName,
    required this.address,
    this.service = 'Hair Cut',
    this.serviceId,
    this.priceLabel = '£50',
    this.priceAmount = 50,
    this.imageUrl =
        'https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=800&q=80',
    this.preferredBarberUserId,
  });

  final String shopId;
  final String salonName;
  final String address;
  final String service;
  final String? serviceId;
  final String priceLabel;
  final double priceAmount;
  final String imageUrl;
  final String? preferredBarberUserId;

  factory BookAppointmentArgs.fromProvider(
    ProviderDetailArgs provider, {
    ServiceDto? service,
  }) {
    return BookAppointmentArgs(
      shopId: provider.shopId,
      salonName: provider.name,
      address: provider.address,
      service: service?.name ?? 'Hair Cut',
      serviceId: service?.id,
      priceLabel: service?.priceLabel ?? '£50',
      priceAmount: service?.priceAmount ?? 50,
      imageUrl: provider.imageUrl ??
          'https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=800&q=80',
      preferredBarberUserId: provider.barberUserId,
    );
  }
}

/// Filter for provider appointment list screen.
enum ProviderApptFilter { total, opened, closed }

class ProviderApptListArgs {
  const ProviderApptListArgs({this.filter = ProviderApptFilter.total});

  final ProviderApptFilter filter;
}

class ProviderAddBarberArgs {
  const ProviderAddBarberArgs({required this.shopId});

  final String shopId;
}

class AddProfessionalArgs {
  const AddProfessionalArgs({
    required this.shopId,
    this.salonName,
  });

  final String shopId;
  final String? salonName;
}

class InvitationSentArgs {
  const InvitationSentArgs({
    required this.shopId,
    required this.salonName,
    required this.invitation,
  });

  final String shopId;
  final String salonName;
  final ShopInvitationDto invitation;
}

class PendingInvitationArgs {
  const PendingInvitationArgs({
    required this.shopId,
    required this.invitation,
  });

  final String shopId;
  final ShopInvitationDto invitation;
}

class ProfessionalAddedArgs {
  const ProfessionalAddedArgs({
    required this.shopId,
    required this.specialist,
    this.showJoinedBanner = true,
  });

  final String shopId;
  final SpecialistDto specialist;
  final bool showJoinedBanner;
}

class SalonProfileArgs {
  const SalonProfileArgs({
    this.shopId,
    this.fromOnboarding = false,
  });

  final String? shopId;
  final bool fromOnboarding;
}

class SalonSetupArgs {
  const SalonSetupArgs({
    this.shopId,
    this.fromOnboarding = false,
  });

  final String? shopId;
  final bool fromOnboarding;
}

class ProviderServicesArgs {
  const ProviderServicesArgs({
    this.shopId,
    this.fromOnboarding = false,
  });

  final String? shopId;
  final bool fromOnboarding;
}

class ProviderServiceEditArgs {
  const ProviderServiceEditArgs({
    required this.shopId,
    this.service,
  });

  final String shopId;
  final ServiceDto? service;
}

class ProviderServiceAssignArgs {
  const ProviderServiceAssignArgs({
    required this.shopId,
    required this.service,
  });

  final String shopId;
  final ServiceDto service;
}

class ProviderBarberDetailArgs {
  const ProviderBarberDetailArgs({
    required this.shopId,
    required this.barberUserId,
    this.specialist,
    this.isOwner = false,
  });

  final String shopId;
  final String barberUserId;
  final SpecialistDto? specialist;
  final bool isOwner;
}
