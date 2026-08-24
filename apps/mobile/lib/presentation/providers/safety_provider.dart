import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/trusted_contact.dart';
import '../../data/repositories/safety_repository.dart';

class SafetyNotifier extends StateNotifier<AsyncValue<List<TrustedContact>>> {
  final SafetyRepository _repository;

  SafetyNotifier(this._repository) : super(const AsyncValue.loading());

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repository.listContacts());
  }

  Future<void> addContact({
    required String name,
    required String phone,
    String? email,
    bool canViewLiveLocation = true,
    bool canViewTripPlan = true,
    bool canViewEta = true,
  }) async {
    final contact = await _repository.addContact(
      name: name,
      phone: phone,
      email: email,
      canViewLiveLocation: canViewLiveLocation,
      canViewTripPlan: canViewTripPlan,
      canViewEta: canViewEta,
    );
    state = AsyncValue.data([...?state.value, contact]);
  }

  Future<void> updateContact(TrustedContact contact) async {
    final updated = await _repository.updateContact(contact);
    state = AsyncValue.data([
      for (final c in state.value ?? [])
        if (c.id == updated.id) updated else c
    ]);
  }

  Future<void> deleteContact(String id) async {
    await _repository.deleteContact(id);
    state = AsyncValue.data([
      for (final c in state.value ?? [])
        if (c.id != id) c
    ]);
  }

  Future<String> shareLiveTrip({
    required String tripId,
    required String contactId,
    Duration expiry = const Duration(hours: 24),
  }) {
    return _repository.shareLiveTrip(
      tripId: tripId,
      contactId: contactId,
      expiry: expiry,
    );
  }
}

final safetyProvider =
    StateNotifierProvider<SafetyNotifier, AsyncValue<List<TrustedContact>>>(
        (ref) {
  return SafetyNotifier(ref.read(safetyRepositoryProvider));
});
