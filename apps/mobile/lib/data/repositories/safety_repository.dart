import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../datasources/api_client.dart';
import '../../domain/entities/trusted_contact.dart';

class SafetyRepository {
  final ApiClient _apiClient;

  SafetyRepository(this._apiClient);

  Future<List<TrustedContact>> listContacts() async {
    final res = await _apiClient.get('/safety/trusted-contacts');
    final list = res['contacts'] as List<dynamic>? ?? [];
    return list
        .map((e) => TrustedContact.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<TrustedContact> addContact({
    required String name,
    required String phone,
    String? email,
    bool canViewLiveLocation = true,
    bool canViewTripPlan = true,
    bool canViewEta = true,
  }) async {
    final res = await _apiClient.post('/safety/trusted-contacts', body: {
      'name': name,
      'phone': phone,
      if (email != null) 'email': email,
      'can_view_live_location': canViewLiveLocation,
      'can_view_trip_plan': canViewTripPlan,
      'can_view_eta': canViewEta,
    });
    return TrustedContact.fromJson(res['contact'] as Map<String, dynamic>);
  }

  Future<TrustedContact> updateContact(TrustedContact contact) async {
    final res = await _apiClient.patch(
      '/safety/trusted-contacts/${contact.id}',
      body: {
        'name': contact.name,
        'phone': contact.phone,
        'email': contact.email,
        'can_view_live_location': contact.canViewLiveLocation,
        'can_view_trip_plan': contact.canViewTripPlan,
        'can_view_eta': contact.canViewEta,
      },
    );
    return TrustedContact.fromJson(res['contact'] as Map<String, dynamic>);
  }

  Future<void> deleteContact(String id) async {
    await _apiClient.delete('/safety/trusted-contacts/$id');
  }

  Future<String> shareLiveTrip({
    required String tripId,
    required String contactId,
    required Duration expiry,
  }) async {
    final res = await _apiClient.post('/safety/share-live', body: {
      'trip_id': tripId,
      'contact_id': contactId,
      'expiry_minutes': expiry.inMinutes,
    });
    return res['share_link'] as String;
  }

  Future<void> revokeShare(String shareId) async {
    await _apiClient.delete('/safety/share-live/$shareId');
  }
}

final safetyRepositoryProvider = Provider<SafetyRepository>((ref) {
  return SafetyRepository(ref.read(apiClientProvider));
});
