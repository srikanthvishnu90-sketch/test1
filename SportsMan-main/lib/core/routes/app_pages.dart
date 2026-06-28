import 'package:get/get.dart';
import 'app_routes.dart';
import '../../presentation/splash/splash_screen.dart';
import '../../presentation/onboarding/onboarding_selection_screen.dart';
import '../../presentation/onboarding/select_sports_screen.dart';
import '../../presentation/onboarding/identity_screen.dart';
import '../../presentation/onboarding/mission_screen.dart';
import '../../presentation/onboarding/almost_done_screen.dart';
import '../../presentation/onboarding/provider_identity_screen.dart';
import '../../presentation/onboarding/provider_sports_screen.dart';
import '../../presentation/onboarding/provider_capacity_screen.dart';
import '../../presentation/onboarding/provider_pricing_screen.dart';
import '../../presentation/onboarding/provider_media_screen.dart';
import '../../presentation/onboarding/provider_activation_screen.dart';
import '../../presentation/onboarding/provider_tutorial_screen.dart';
import '../../presentation/onboarding/provider_onboard_intake_screen.dart';
import '../../presentation/onboarding/provider_onboard_review_screen.dart';
import '../../presentation/provider/provider_main_nav_screen.dart';
import '../../presentation/provider/view/provider_dashboard_screen.dart';
import '../../presentation/provider/view/provider_listings_screen.dart';
import '../../presentation/authentication/auth_entry_screen.dart';
import '../../presentation/authentication/signup_screen.dart';
import '../../presentation/authentication/verify_email_screen.dart';
import '../../presentation/authentication/login_screen.dart';
import '../../presentation/authentication/provider_login_screen.dart';
import '../../presentation/authentication/forgot_password_screen.dart';
import '../../presentation/bottom_nav/bottom_nav_screen.dart';
import '../../presentation/client/view/search_screen.dart';
import '../../presentation/client/view/filter_screen.dart';
import '../../presentation/client/view/nearby_session_screen.dart';
import '../../presentation/client/view/session_details_screen.dart';
import '../../presentation/client/view/booking_flow_screen.dart';
import '../../presentation/client/view/chat_details_screen.dart';
import '../../presentation/provider/view/provider_roster_screen.dart';
import '../../presentation/provider/view/provider_finances_screen.dart';
import '../../presentation/provider/view/provider_payouts_payments_screen.dart';
import '../../presentation/shared/notification_settings_screen.dart';
import '../../presentation/provider/view/personal_profile_screen.dart';
import '../../presentation/provider/view/service_profile_screen.dart';

class AppPages {
  static const String initial = AppRoutes.splash;

  static final List<GetPage> routes = [
    GetPage(
      name: AppRoutes.splash,
      page: () => const SplashScreen(),
    ),
    GetPage(
      name: AppRoutes.authEntry,
      page: () => const AuthEntryScreen(),
    ),
    GetPage(
      name: AppRoutes.signup,
      page: () => const SignupScreen(),
    ),
    GetPage(
      name: AppRoutes.login,
      page: () => const LoginScreen(),
    ),
    GetPage(
      name: AppRoutes.providerLogin,
      page: () => const ProviderLoginScreen(),
    ),
    GetPage(
      name: AppRoutes.verifyEmail,
      page: () => const VerifyEmailScreen(),
    ),
    GetPage(
      name: AppRoutes.forgotPassword,
      page: () => const ForgotPasswordScreen(),
    ),
    GetPage(
      name: AppRoutes.onboarding,
      page: () => const OnboardingSelectionScreen(),
    ),
    GetPage(
      name: AppRoutes.selectSports,
      page: () => SelectSportsScreen(),
    ),
    GetPage(
      name: AppRoutes.identity,
      page: () => IdentityScreen(),
    ),
    GetPage(
      name: AppRoutes.mission,
      page: () => MissionScreen(),
    ),
    GetPage(
      name: AppRoutes.almostDone,
      page: () => AlmostDoneScreen(),
    ),
    GetPage(
      name: AppRoutes.providerIdentity,
      page: () => const ProviderIdentityScreen(),
    ),
    GetPage(
      name: AppRoutes.providerSports,
      page: () => ProviderSportsScreen(),
    ),
    GetPage(
      name: AppRoutes.providerCapacity,
      page: () => const ProviderCapacityScreen(),
    ),
    GetPage(
      name: AppRoutes.providerPricing,
      page: () => const ProviderPricingScreen(),
    ),
    GetPage(
      name: AppRoutes.providerMedia,
      page: () => const ProviderMediaScreen(),
    ),
    GetPage(
      name: AppRoutes.providerActivation,
      page: () => const ProviderActivationScreen(),
    ),
    GetPage(
      name: AppRoutes.providerMainNav,
      page: () => const ProviderMainNavScreen(),
    ),
    GetPage(
      name: AppRoutes.providerDashboard,
      page: () => const ProviderDashboardScreen(),
    ),
    GetPage(
      name: AppRoutes.providerListings,
      page: () => const ProviderListingsScreen(),
    ),
    GetPage(
      name: AppRoutes.mainNav,
      page: () => const MainNavScreen(),
    ),
    GetPage(
      name: AppRoutes.search,
      page: () => const SearchScreen(),
    ),
    GetPage(
      name: AppRoutes.filters,
      page: () => const FilterScreen(),
    ),
    GetPage(
      name: AppRoutes.nearbySession,
      page: () => const NearbySessionScreen(),
    ),
    GetPage(
      name: AppRoutes.sessionDetails,
      page: () => const SessionDetailsScreen(),
    ),
    GetPage(
      name: AppRoutes.bookingFlow,
      page: () => const BookingFlowScreen(),
    ),
    GetPage(
      name: AppRoutes.chatDetails,
      page: () => const ChatDetailsScreen(),
    ),
    GetPage(
      name: AppRoutes.providerRoster,
      page: () => const ProviderRosterScreen(),
    ),
    GetPage(
      name: AppRoutes.providerFinances,
      page: () => const ProviderFinancesScreen(),
    ),
    GetPage(
      name: AppRoutes.providerWithdrawal,
      page: () => const ProviderWithdrawalScreen(),
    ),
    GetPage(
      name: AppRoutes.providerPayoutsPayments,
      page: () => const ProviderPayoutsPaymentsScreen(),
    ),
    GetPage(
      name: AppRoutes.notificationSettings,
      page: () => const NotificationSettingsScreen(),
    ),
    GetPage(
      name: AppRoutes.providerTutorial,
      page: () => const ProviderTutorialScreen(),
    ),
    GetPage(
      name: AppRoutes.providerPersonalProfile,
      page: () => const PersonalProfileScreen(),
    ),
    GetPage(
      name: AppRoutes.providerServiceProfile,
      page: () => const ServiceProfileScreen(),
    ),
    GetPage(
      name: AppRoutes.providerOnboardIntake,
      page: () => const ProviderOnboardIntakeScreen(),
    ),
    GetPage(
      name: AppRoutes.providerOnboardReview,
      page: () => const ProviderOnboardReviewScreen(),
    ),
  ];
}
