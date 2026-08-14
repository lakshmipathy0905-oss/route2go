import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/admin_repository.dart';
import '../providers/auth_provider.dart';

/// Admin session: gates the /admin route group on a verified admin_users row
/// (spec 2.13 / Section 5.15). The EF resolves the role server-side from the
/// Firebase token — the client never trusts a local role.
class AdminSession {
  const AdminSession({this.role});

  final String? role; // super | content | support | moderator | finance

  bool get isAdmin => role != null;
  bool get isSuper => role == 'super_admin';
}

class AdminSessionNotifier extends AsyncNotifier<AdminSession> {
  @override
  Future<AdminSession> build() async {
    await ref.watch(authStateProvider.future);
    if (ref.read(authStateProvider).valueOrNull == null) {
      return const AdminSession();
    }
    try {
      final repo = ref.watch(adminRepositoryProvider);
      final me = await repo.me();
      return AdminSession(role: me.role);
    } catch (_) {
      // Non-admin or unreachable — degrade to locked, never to open.
      return const AdminSession();
    }
  }
}

final adminSessionProvider =
    AsyncNotifierProvider<AdminSessionNotifier, AdminSession>(
  AdminSessionNotifier.new,
);

/// Role-gated loader for the dashboard's stat cards.
class AdminStatsNotifier extends AsyncNotifier<AdminStats> {
  @override
  Future<AdminStats> build() async {
    return ref.watch(adminRepositoryProvider).stats();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.watch(adminRepositoryProvider).stats(),
    );
  }
}

final adminStatsProvider =
    AsyncNotifierProvider<AdminStatsNotifier, AdminStats>(
  AdminStatsNotifier.new,
);

class AdminFlagsNotifier extends AsyncNotifier<List<FeatureFlag>> {
  @override
  Future<List<FeatureFlag>> build() async {
    return ref.watch(adminRepositoryProvider).flags();
  }

  Future<void> setFlag(String key, bool enabled) async {
    await ref.watch(adminRepositoryProvider).setFlag(key, enabled);
    await refresh();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.watch(adminRepositoryProvider).flags(),
    );
  }
}

final adminFlagsProvider =
    AsyncNotifierProvider<AdminFlagsNotifier, List<FeatureFlag>>(
  AdminFlagsNotifier.new,
);

class AdminAuditNotifier extends AsyncNotifier<List<AuditEntry>> {
  @override
  Future<List<AuditEntry>> build() async {
    return ref.watch(adminRepositoryProvider).audit(limit: 100);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.watch(adminRepositoryProvider).audit(limit: 100),
    );
  }
}

final adminAuditProvider =
    AsyncNotifierProvider<AdminAuditNotifier, List<AuditEntry>>(
  AdminAuditNotifier.new,
);

class AdminSupportNotifier extends AsyncNotifier<List<SupportTicket>> {
  @override
  Future<List<SupportTicket>> build() async {
    return ref.watch(adminRepositoryProvider).support();
  }

  Future<void> updateStatus(String ticketId, String status) async {
    await ref.watch(adminRepositoryProvider).updateTicket(ticketId, status);
    await refresh();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.watch(adminRepositoryProvider).support(),
    );
  }
}

final adminSupportProvider =
    AsyncNotifierProvider<AdminSupportNotifier, List<SupportTicket>>(
  AdminSupportNotifier.new,
);

class AdminAffiliateNotifier extends AsyncNotifier<AffiliateSummary> {
  @override
  Future<AffiliateSummary> build() async {
    return ref.watch(adminRepositoryProvider).affiliate(days: 30);
  }
}

final adminAffiliateProvider =
    AsyncNotifierProvider<AdminAffiliateNotifier, AffiliateSummary>(
  AdminAffiliateNotifier.new,
);

class AdminUsersNotifier extends AsyncNotifier<List<AdminUser>> {
  @override
  Future<List<AdminUser>> build() async {
    return ref.watch(adminRepositoryProvider).users();
  }

  Future<void> search(String query) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.watch(adminRepositoryProvider).users(query: query),
    );
  }
}

final adminUsersProvider =
    AsyncNotifierProvider<AdminUsersNotifier, List<AdminUser>>(
  AdminUsersNotifier.new,
);
