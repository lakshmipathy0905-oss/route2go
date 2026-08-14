import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/providers/auth_provider.dart';
import '../../presentation/screens/splash/splash_screen.dart';
import '../../presentation/screens/onboarding/onboarding_screen.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/home/home_screen.dart';
import '../../presentation/screens/trip_planning/plan_trip_screen.dart';
import '../../presentation/screens/trip_planning/location_picker_screen.dart';
import '../../presentation/screens/trip_planning/route_results_screen.dart';
import '../../presentation/screens/trip_planning/budget_tracker_screen.dart';
import '../../presentation/screens/trip_planning/places_screen.dart';
import '../../presentation/screens/trip_planning/place_detail_screen.dart';
import '../../presentation/screens/trip_planning/stays_screen.dart';
import '../../presentation/screens/trip_planning/itinerary_screen.dart';
import '../../presentation/screens/trip_planning/confirm_trip_screen.dart';
import '../../presentation/screens/trip_planning/live_trip_screen.dart';
import '../../presentation/screens/vehicles/vehicle_garage_screen.dart';
import '../../presentation/screens/vehicles/vehicle_form_screen.dart';
import '../../presentation/screens/trips/trip_detail_screen.dart';
import '../../presentation/screens/expenses/expense_tracker_screen.dart';
import '../../presentation/screens/expenses/expense_edit_screen.dart';
import '../../presentation/screens/notifications/notifications_screen.dart';
import '../../presentation/screens/settings/settings_screen.dart';
import '../../presentation/screens/settings/profile_edit_screen.dart';
import '../../presentation/screens/settings/privacy_screen.dart';
import '../../presentation/screens/settings/terms_screen.dart';
import '../../presentation/screens/settings/help_support_screen.dart';
import '../../presentation/screens/settings/delete_account_screen.dart';
import '../../presentation/screens/favorites/favorites_screen.dart';
import '../../presentation/screens/search/search_screen.dart';
import '../../presentation/screens/admin/admin_dashboard_screen.dart';
import '../../presentation/screens/admin/admin_flags_screen.dart';
import '../../presentation/screens/admin/admin_audit_screen.dart';
import '../../presentation/screens/admin/admin_support_screen.dart';
import '../../presentation/screens/admin/admin_affiliate_screen.dart';
import '../../presentation/screens/admin/admin_users_screen.dart';
import '../../presentation/screens/shared/error_screen.dart';

/// Route path constants. Referencing these instead of raw strings keeps
/// deep links and `context.go(...)` calls typo-safe across the app.
class AppRoutes {
  AppRoutes._();

  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const home = '/home';

  // Plan Trip flow
  static const planTrip = '/plan-trip';
  static const locationPicker = '/plan-trip/location-picker';
  static const routeResults = '/plan-trip/results';
  static const budgetTracker = '/plan-trip/budget';
  static const places = '/plan-trip/places';
  static const placeDetail = '/plan-trip/places/:id';
  static const stays = '/plan-trip/stays';
  static const itinerary = '/plan-trip/itinerary';
  static const confirmTrip = '/plan-trip/confirm';
  static const liveTrip = '/live-trip';

  // Vehicle garage
  static const vehicles = '/vehicles';
  static const vehicleAdd = '/vehicles/add';
  static const vehicleEdit = '/vehicles/:id/edit';

  // Trip management
  static const tripDetail = '/trip/:id';
  static const tripExpenses = '/trip/:id/expenses';
  static const expenseAdd = '/trip/:id/expenses/new';

  // Account
  static const settings = '/settings';
  static const profileEdit = '/settings/profile';
  static const notifications = '/notifications';
  static const favorites = '/favorites';
  static const search = '/search';
  static const privacy = '/settings/privacy';
  static const terms = '/settings/terms';
  static const help = '/settings/help';
  static const deleteAccount = '/settings/delete-account';

  // Admin (spec 2.13) — isolated route group, server-gated.
  static const admin = '/admin';
  static const adminFlags = '/admin/flags';
  static const adminAudit = '/admin/audit';
  static const adminSupport = '/admin/support';
  static const adminAffiliate = '/admin/affiliate';
  static const adminUsers = '/admin/users';

  static String placeDetailOf(String id) => '/plan-trip/places/$id';
  static String tripDetailOf(String id) => '/trip/$id';
  static String tripExpensesOf(String id) => '/trip/$id/expenses';
  static String expenseAddOf(String id) => '/trip/$id/expenses/new';
  static String vehicleEditOf(String id) => '/vehicles/$id/edit';
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final loggedIn = authState.valueOrNull != null;
      final isAuthScreen = state.matchedLocation == AppRoutes.login;
      final isSplashOrOnboarding = state.matchedLocation == AppRoutes.splash ||
          state.matchedLocation == AppRoutes.onboarding;

      // Guest mode is allowed (spec Section 5.2): we do NOT force login here.
      // Only account-bound actions (save trip, group split, notifications)
      // check auth at the point of action — see GuestGateSheet.
      if (isSplashOrOnboarding || isAuthScreen) return null;
      if (!loggedIn && state.matchedLocation == AppRoutes.home) return null;

      return null;
    },
    errorBuilder: (context, state) => ErrorScreen(error: state.error),
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.planTrip,
        builder: (context, state) => const PlanTripScreen(),
      ),
      GoRoute(
        path: AppRoutes.locationPicker,
        builder: (context, state) =>
            LocationPickerScreen(target: (state.extra as String?) ?? 'origin'),
      ),
      GoRoute(
        path: AppRoutes.routeResults,
        builder: (context, state) => const RouteResultsScreen(),
      ),
      GoRoute(
        path: AppRoutes.budgetTracker,
        builder: (context, state) => const BudgetTrackerScreen(),
      ),
      GoRoute(
        path: AppRoutes.places,
        builder: (context, state) => const PlacesScreen(),
      ),
      GoRoute(
        path: AppRoutes.placeDetail,
        builder: (context, state) =>
            PlaceDetailScreen(id: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: AppRoutes.stays,
        builder: (context, state) => const StaysScreen(),
      ),
      GoRoute(
        path: AppRoutes.itinerary,
        builder: (context, state) => const ItineraryScreen(),
      ),
      GoRoute(
        path: AppRoutes.confirmTrip,
        builder: (context, state) => const ConfirmTripScreen(),
      ),
      GoRoute(
        path: AppRoutes.liveTrip,
        builder: (context, state) => const LiveTripScreen(),
      ),
      GoRoute(
        path: AppRoutes.vehicles,
        builder: (context, state) => const VehicleGarageScreen(),
      ),
      GoRoute(
        path: AppRoutes.vehicleAdd,
        builder: (context, state) => const VehicleFormScreen(),
      ),
      GoRoute(
        path: AppRoutes.vehicleEdit,
        builder: (context, state) =>
            VehicleFormScreen(vehicleId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: AppRoutes.tripDetail,
        builder: (context, state) =>
            TripDetailScreen(id: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: AppRoutes.tripExpenses,
        builder: (context, state) =>
            ExpenseTrackerScreen(tripId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: AppRoutes.expenseAdd,
        builder: (context, state) =>
            ExpenseEditScreen(tripId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.profileEdit,
        builder: (context, state) => const ProfileEditScreen(),
      ),
      GoRoute(
        path: AppRoutes.privacy,
        builder: (context, state) => const PrivacyScreen(),
      ),
      GoRoute(
        path: AppRoutes.terms,
        builder: (context, state) => const TermsScreen(),
      ),
      GoRoute(
        path: AppRoutes.help,
        builder: (context, state) => const HelpSupportScreen(),
      ),
      GoRoute(
        path: AppRoutes.deleteAccount,
        builder: (context, state) => const DeleteAccountScreen(),
      ),
      GoRoute(
        path: AppRoutes.favorites,
        builder: (context, state) => const FavoritesScreen(),
      ),
      GoRoute(
        path: AppRoutes.search,
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: AppRoutes.admin,
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminFlags,
        builder: (context, state) => const AdminFlagsScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminAudit,
        builder: (context, state) => const AdminAuditScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminSupport,
        builder: (context, state) => const AdminSupportScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminAffiliate,
        builder: (context, state) => const AdminAffiliateScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminUsers,
        builder: (context, state) => const AdminUsersScreen(),
      ),
    ],
  );
});
