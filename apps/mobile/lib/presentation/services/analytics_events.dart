import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Product analytics events (spec Section 19).
///
/// These events track the core user funnel without collecting unnecessary
/// personal data. Location history is never tracked — only product events.
class AnalyticsEvents {
  AnalyticsEvents._();

  static Future<void> onboardingCompleted() => _log('onboarding_completed');

  static Future<void> guestTripStarted() => _log('guest_trip_started');

  static Future<void> tripCreated({
    required String tripType,
    required int travellers,
  }) =>
      _log('trip_created', parameters: {
        'trip_type': tripType,
        'travellers': travellers,
      });

  static Future<void> routeCalculated({
    required int optionCount,
    required String provider,
  }) =>
      _log('route_calculated', parameters: {
        'option_count': optionCount,
        'provider': provider,
      });

  static Future<void> routeSelected({
    required String routeType,
  }) =>
      _log('route_selected', parameters: {
        'route_type': routeType,
      });

  static Future<void> itineraryGenerated({
    required int days,
    required int stops,
  }) =>
      _log('itinerary_generated', parameters: {
        'days': days,
        'stops': stops,
      });

  static Future<void> placeAdded({
    required String category,
  }) =>
      _log('place_added', parameters: {
        'category': category,
      });

  static Future<void> budgetOptimized({
    required double savingsPercent,
  }) =>
      _log('budget_optimized', parameters: {
        'savings_percent': savingsPercent,
      });

  static Future<void> tripSaved() => _log('trip_saved');

  static Future<void> tripShared() => _log('trip_shared');

  static Future<void> tripStarted() => _log('trip_started');

  static Future<void> tripCompleted({
    required bool hasActualExpenses,
  }) =>
      _log('trip_completed', parameters: {
        'has_actual_expenses': hasActualExpenses,
      });

  static Future<void> partnerClicked({
    required String partnerType,
  }) =>
      _log('partner_clicked', parameters: {
        'partner_type': partnerType,
      });

  static Future<void> businessSubmitted() => _log('business_submitted');

  static Future<void> sponsoredViewed({
    required String businessId,
  }) =>
      _log('sponsored_viewed', parameters: {
        'business_id': businessId,
      });

  static Future<void> _log(String name,
      {Map<String, Object>? parameters}) async {
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: name,
        parameters: parameters,
      );
    } catch (_) {
      if (kDebugMode) {
        debugPrint('Analytics event failed: $name $parameters');
      }
    }
  }
}
