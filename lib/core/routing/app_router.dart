import 'package:flutter/material.dart';

import '../../features/auth/presentation/account_created_screen.dart';
import '../../features/auth/presentation/choose_role_screen.dart';
import '../../features/auth/presentation/customer_sign_up_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/otp_verification_screen.dart';
import '../../features/auth/presentation/provider_type_screen.dart';
import '../../features/auth/presentation/role_selection_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/auth/presentation/welcome_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/customer/data/customer_demo_data.dart';
import '../../features/customer/presentation/add_card_screen.dart';
import '../../features/customer/presentation/barber_list_screen.dart';
import '../../features/customer/presentation/book_appointment_screen.dart';
import '../../features/customer/presentation/customer_shell.dart';
import '../../features/customer/presentation/notifications_screen.dart';
import '../../features/customer/presentation/personal_info_screen.dart';
import '../../features/customer/presentation/customer_settings_screen.dart';
import '../../features/customer/presentation/browse_services_screen.dart';
import '../../features/customer/presentation/search_services_screen.dart';
import '../../features/customer/presentation/choose_look_screen.dart';
import '../../features/customer/presentation/find_professionals_screen.dart';
import '../../features/customer/presentation/find_this_look_screen.dart';
import '../../features/customer/presentation/leave_review_screen.dart';
import '../../features/customer/presentation/location_search_screen.dart';
import '../../features/customer/presentation/look_details_screen.dart';
import '../../features/customer/presentation/looks_book_screen.dart';
import '../../features/customer/presentation/marketplace_search_screen.dart';
import '../../features/customer/presentation/available_today_screen.dart';
import '../../features/customer/presentation/book_again_screen.dart';
import '../../features/customer/presentation/salon_professionals_screen.dart';
import '../../features/customer/presentation/nearby_map_screen.dart';
import '../../features/customer/presentation/results_filter_screen.dart';
import '../../features/customer/data/salon_filters.dart';
import '../../features/customer/presentation/provider_detail_screen.dart';
import '../../features/provider/presentation/add_barber_screen.dart';
import '../../features/provider/presentation/add_professional_screen.dart';
import '../../features/provider/presentation/invitation_sent_screen.dart';
import '../../features/provider/presentation/pending_invitation_screen.dart';
import '../../features/provider/presentation/professional_added_screen.dart';
import '../../features/provider/presentation/barber_roster_detail_screen.dart';
import '../../features/provider/presentation/manage_salon_screen.dart';
import '../../features/provider/presentation/salon_profile_screen.dart';
import '../../features/provider/presentation/salon_opening_hours_screen.dart';
import '../../features/provider/presentation/salon_team_onboarding_screen.dart';
import '../../features/provider/presentation/salon_booking_settings_screen.dart';
import '../../features/provider/presentation/salon_verification_screen.dart';
import '../../features/provider/presentation/salon_owner_dashboard_screen.dart';
import '../../features/provider/presentation/provider_services_screen.dart';
import '../../features/provider/presentation/provider_service_edit_screen.dart';
import '../../features/provider/presentation/provider_service_assign_screen.dart';
import '../../features/provider/presentation/provider_appointments_list_screen.dart';
import '../../features/provider/presentation/provider_analytics_screen.dart';
import '../../features/provider/presentation/provider_availability_screen.dart';
import '../../features/provider/presentation/provider_info_page.dart';
import '../../features/provider/presentation/provider_portfolio_screen.dart';
import '../../features/provider/presentation/provider_settings_screen.dart';
import '../../features/provider/presentation/provider_shell.dart';
import '../../features/provider/presentation/provider_sign_up_screen.dart';
import 'app_routes.dart';

abstract final class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.splash:
        return _page(const SplashScreen(), settings);
      case AppRoutes.onboarding:
        return _page(const OnboardingScreen(), settings);
      case AppRoutes.roleSelection:
        return _page(const RoleSelectionScreen(), settings);
      case AppRoutes.welcome:
        return _page(const WelcomeScreen(), settings);
      case AppRoutes.chooseRole:
        return _page(const ChooseRoleScreen(), settings);
      case AppRoutes.providerType:
        return _page(const ProviderTypeScreen(), settings);
      case AppRoutes.accountCreated:
        final createdArgs = settings.arguments as AccountCreatedArgs? ??
            const AccountCreatedArgs();
        return _page(AccountCreatedScreen(args: createdArgs), settings);
      case AppRoutes.customerSignUp:
        return _page(const CustomerSignUpScreen(), settings);
      case AppRoutes.customerLogin:
      case AppRoutes.providerLogin:
        final loginArgs = settings.arguments as LoginArgs? ??
            LoginArgs(
              isServiceProvider: settings.name == AppRoutes.providerLogin,
            );
        return _page(LoginScreen(args: loginArgs), settings);
      case AppRoutes.customerOtp:
        final args = settings.arguments as OtpArgs? ??
            const OtpArgs(phoneNumber: '+440000000000');
        return _page(OtpVerificationScreen(args: args), settings);
      case AppRoutes.customerShell:
        return _page(const CustomerShell(), settings);
      case AppRoutes.providerDetail:
        final args = settings.arguments as ProviderDetailArgs? ??
            const ProviderDetailArgs(
              shopId: '',
              name: 'Salon',
              subtitle: 'Hair specialist',
              rating: 0,
              distance: 'Nearby',
              address: '',
            );
        return _page(ProviderDetailScreen(args: args), settings);
      case AppRoutes.bookAppointment:
        final bookArgs = settings.arguments as BookAppointmentArgs? ??
            const BookAppointmentArgs(
              shopId: '',
              salonName: 'Salon',
              address: '',
            );
        return _page(BookAppointmentScreen(args: bookArgs), settings);
      case AppRoutes.barberList:
        final args = settings.arguments as BarberListArgs? ??
            const BarberListArgs(mode: BarberListMode.shops);
        return _page(BarberListScreen(args: args), settings);
      case AppRoutes.notifications:
        return _page(const NotificationsScreen(), settings);
      case AppRoutes.addCard:
        return _page(const AddCardScreen(), settings);
      case AppRoutes.customerPersonalInfo:
        final infoArgs = settings.arguments as CustomerPersonalInfoArgs?;
        return _page(
          PersonalInfoScreen(
            fromOnboarding: infoArgs?.fromOnboarding ?? false,
          ),
          settings,
        );
      case AppRoutes.providerPersonalInfo:
        return _page(
          const PersonalInfoScreen(isServiceProvider: true),
          settings,
        );
      case AppRoutes.providerSignUp:
        return _page(const ProviderSignUpScreen(), settings);
      case AppRoutes.providerShell:
        return _page(const ProviderShell(), settings);
      case AppRoutes.providerAppointmentsList:
        final listArgs = settings.arguments as ProviderApptListArgs? ??
            const ProviderApptListArgs();
        return _page(
          ProviderAppointmentsListScreen(args: listArgs),
          settings,
        );
      case AppRoutes.providerAbout:
        return _page(
          const ProviderInfoPage(title: 'About Us', body: kStylAboutBody),
          settings,
        );
      case AppRoutes.providerPrivacy:
        return _page(
          const ProviderInfoPage(
            title: 'Privacy Statement',
            body: kStylPrivacyBody,
          ),
          settings,
        );
      case AppRoutes.providerTerms:
        return _page(
          const ProviderInfoPage(
            title: 'Terms & Conditions',
            body: kStylTermsBody,
          ),
          settings,
        );
      case AppRoutes.providerHelp:
        return _page(
          const ProviderInfoPage(title: 'Help', body: kStylHelpBody),
          settings,
        );
      case AppRoutes.chooseLook:
        final lookArgs = settings.arguments as ChooseLookArgs? ??
            const ChooseLookArgs(categoryId: 'barber');
        return _page(ChooseLookScreen(args: lookArgs), settings);
      case AppRoutes.lookDetails:
        final detailsArgs = settings.arguments as LookDetailsArgs? ??
            const LookDetailsArgs(lookId: 'low-fade');
        return _page(LookDetailsScreen(args: detailsArgs), settings);
      case AppRoutes.findProfessionals:
        final findArgs = settings.arguments as FindProfessionalsArgs? ??
            const FindProfessionalsArgs(lookId: 'low-fade');
        return _page(FindProfessionalsScreen(args: findArgs), settings);
      case AppRoutes.looksBook:
        final looksBook = settings.arguments as LooksBookArgs? ??
            const LooksBookArgs(
              shopId: '',
              salonName: 'Salon',
              address: '',
            );
        return _page(LooksBookScreen(args: looksBook), settings);
      case AppRoutes.leaveReview:
        final reviewArgs = settings.arguments as LeaveReviewArgs? ??
            const LeaveReviewArgs(
              appointmentId: '',
              salonName: 'Salon',
              serviceName: 'Service',
              dateLabel: '',
            );
        return _page(LeaveReviewScreen(args: reviewArgs), settings);
      case AppRoutes.marketplaceSearch:
        final searchArgs = settings.arguments as MarketplaceSearchArgs? ??
            const MarketplaceSearchArgs();
        return _page(MarketplaceSearchScreen(args: searchArgs), settings);
      case AppRoutes.locationSearch:
        final locationArgs = settings.arguments as LocationSearchArgs? ??
            const LocationSearchArgs();
        return _page(LocationSearchScreen(args: locationArgs), settings);
      case AppRoutes.browseServices:
        final browseArgs = settings.arguments as BrowseServicesArgs? ??
            const BrowseServicesArgs();
        return _page(BrowseServicesScreen(args: browseArgs), settings);
      case AppRoutes.searchServices:
        return _page(const SearchServicesScreen(), settings);
      case AppRoutes.findThisLook:
        final lookPhoto = settings.arguments as FindThisLookArgs? ??
            const FindThisLookArgs(photoPath: '');
        return _page(FindThisLookScreen(args: lookPhoto), settings);
      case AppRoutes.nearbyMap:
        final mapArgs = settings.arguments as NearbyMapArgs? ??
            const NearbyMapArgs();
        return _page(NearbyMapScreen(args: mapArgs), settings);
      case AppRoutes.availableToday:
        final availArgs = settings.arguments as AvailableTodayArgs? ??
            const AvailableTodayArgs();
        return _page(AvailableTodayScreen(args: availArgs), settings);
      case AppRoutes.filterResults:
        final filterArgs = settings.arguments as FilterResultsArgs? ??
            const FilterResultsArgs(initial: SalonFilters.defaults, results: []);
        return _page(ResultsFilterScreen(args: filterArgs), settings);
      case AppRoutes.bookAgain:
        return _page(const BookAgainScreen(), settings);
      case AppRoutes.salonProfessionals:
        final teamArgs = settings.arguments as SalonProfessionalsArgs? ??
            const SalonProfessionalsArgs(shopId: '', salonName: 'Salon', address: '');
        return _page(SalonProfessionalsScreen(args: teamArgs), settings);
      case AppRoutes.customerSettings:
        return _page(const CustomerSettingsScreen(), settings);
      case AppRoutes.providerSettings:
        return _page(const ProviderSettingsScreen(), settings);
      case AppRoutes.providerManageSalon:
        final shopId = settings.arguments as String?;
        return _page(ManageSalonScreen(shopId: shopId), settings);
      case AppRoutes.providerSalonProfile:
        final profileArgs = settings.arguments as SalonProfileArgs?;
        return _page(
          SalonProfileScreen(
            shopId: profileArgs?.shopId,
            fromOnboarding: profileArgs?.fromOnboarding ?? false,
          ),
          settings,
        );
      case AppRoutes.providerPortfolio:
        return _page(const ProviderPortfolioScreen(), settings);
      case AppRoutes.providerServices:
        final servicesArgs = settings.arguments as ProviderServicesArgs?;
        return _page(
          ProviderServicesScreen(
            shopId: servicesArgs?.shopId,
            fromOnboarding: servicesArgs?.fromOnboarding ?? false,
          ),
          settings,
        );
      case AppRoutes.providerServiceEdit:
        final editArgs = settings.arguments as ProviderServiceEditArgs? ??
            const ProviderServiceEditArgs(shopId: '');
        return _page(
          ProviderServiceEditScreen(
            shopId: editArgs.shopId,
            service: editArgs.service,
          ),
          settings,
        );
      case AppRoutes.providerServiceAssign:
        final assignArgs = settings.arguments as ProviderServiceAssignArgs?;
        if (assignArgs == null) {
          return _page(const SplashScreen(), settings);
        }
        return _page(
          ProviderServiceAssignScreen(
            shopId: assignArgs.shopId,
            service: assignArgs.service,
          ),
          settings,
        );
      case AppRoutes.providerSalonHours:
        final hoursArgs = settings.arguments as SalonSetupArgs?;
        return _page(
          SalonOpeningHoursScreen(
            shopId: hoursArgs?.shopId,
            fromOnboarding: hoursArgs?.fromOnboarding ?? false,
          ),
          settings,
        );
      case AppRoutes.providerSalonTeam:
        final teamArgs = settings.arguments as SalonSetupArgs?;
        return _page(
          SalonTeamOnboardingScreen(
            shopId: teamArgs?.shopId,
            fromOnboarding: teamArgs?.fromOnboarding ?? false,
          ),
          settings,
        );
      case AppRoutes.providerSalonBookingSettings:
        final bookingArgs = settings.arguments as SalonSetupArgs?;
        return _page(
          SalonBookingSettingsScreen(
            shopId: bookingArgs?.shopId,
            fromOnboarding: bookingArgs?.fromOnboarding ?? false,
          ),
          settings,
        );
      case AppRoutes.providerSalonVerification:
        final verifyArgs = settings.arguments as SalonSetupArgs?;
        return _page(
          SalonVerificationScreen(shopId: verifyArgs?.shopId),
          settings,
        );
      case AppRoutes.providerSalonDashboard:
        return _page(const SalonOwnerDashboardScreen(), settings);
      case AppRoutes.providerAvailability:
        return _page(const ProviderAvailabilityScreen(), settings);
      case AppRoutes.providerAnalytics:
        return _page(const ProviderAnalyticsScreen(), settings);
      case AppRoutes.providerAddBarber:
        final addArgs = settings.arguments as ProviderAddBarberArgs? ??
            const ProviderAddBarberArgs(shopId: '');
        return _page(AddBarberScreen(args: addArgs), settings);
      case AppRoutes.providerAddProfessional:
        final inviteArgs = settings.arguments as AddProfessionalArgs? ??
            const AddProfessionalArgs(shopId: '');
        return _page(AddProfessionalScreen(args: inviteArgs), settings);
      case AppRoutes.providerInvitationSent:
        final sentArgs = settings.arguments as InvitationSentArgs?;
        if (sentArgs == null) {
          return _page(const SplashScreen(), settings);
        }
        return _page(InvitationSentScreen(args: sentArgs), settings);
      case AppRoutes.providerPendingInvitation:
        final pendingArgs = settings.arguments as PendingInvitationArgs?;
        if (pendingArgs == null) {
          return _page(const SplashScreen(), settings);
        }
        return _page(PendingInvitationScreen(args: pendingArgs), settings);
      case AppRoutes.providerProfessionalAdded:
        final addedArgs = settings.arguments as ProfessionalAddedArgs?;
        if (addedArgs == null) {
          return _page(const SplashScreen(), settings);
        }
        return _page(ProfessionalAddedScreen(args: addedArgs), settings);
      case AppRoutes.providerBarberDetail:
        final detailArgs = settings.arguments as ProviderBarberDetailArgs? ??
            const ProviderBarberDetailArgs(shopId: '', barberUserId: '');
        return _page(
          BarberRosterDetailScreen(args: detailArgs),
          settings,
        );
      default:
        return _page(const SplashScreen(), settings);
    }
  }

  static MaterialPageRoute<dynamic> _page(
    Widget child,
    RouteSettings settings,
  ) {
    return MaterialPageRoute<dynamic>(
      builder: (_) => child,
      settings: settings,
    );
  }
}
