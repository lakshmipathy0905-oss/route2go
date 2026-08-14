import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datasources/api_client.dart';
import 'base_repository.dart';

/// Stats shown on the admin dashboard home (spec 2.13 / Section 5.15).
class AdminStats {
  const AdminStats({
    required this.trips,
    required this.users,
    required this.openSupportTickets,
    required this.affiliateClicks,
  });

  final int trips;
  final int users;
  final int openSupportTickets;
  final int affiliateClicks;

  factory AdminStats.fromJson(Map<String, dynamic> json) {
    return AdminStats(
      trips: (json['trips'] as num?)?.toInt() ?? 0,
      users: (json['users'] as num?)?.toInt() ?? 0,
      openSupportTickets: (json['open_support_tickets'] as num?)?.toInt() ?? 0,
      affiliateClicks: (json['affiliate_clicks'] as num?)?.toInt() ?? 0,
    );
  }
}

class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.actorFirebaseUid,
    required this.action,
    required this.entityType,
    this.entityId,
    this.beforeSummary,
    this.afterSummary,
    required this.createdAt,
  });

  final String id;
  final String? actorFirebaseUid;
  final String action;
  final String entityType;
  final String? entityId;
  final Map<String, dynamic>? beforeSummary;
  final Map<String, dynamic>? afterSummary;
  final DateTime? createdAt;

  factory AuditEntry.fromJson(Map<String, dynamic> json) {
    return AuditEntry(
      id: json['id'] as String,
      actorFirebaseUid: json['actor_firebase_uid'] as String?,
      action: json['action'] as String,
      entityType: json['entity_type'] as String,
      entityId: json['entity_id'] as String?,
      beforeSummary: json['before_summary'] is Map<String, dynamic>
          ? json['before_summary'] as Map<String, dynamic>
          : null,
      afterSummary: json['after_summary'] is Map<String, dynamic>
          ? json['after_summary'] as Map<String, dynamic>
          : null,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }
}

class FeatureFlag {
  const FeatureFlag({
    required this.key,
    required this.enabled,
    required this.description,
    this.updatedAt,
  });

  final String key;
  final bool enabled;
  final String description;
  final DateTime? updatedAt;

  factory FeatureFlag.fromJson(Map<String, dynamic> json) {
    return FeatureFlag(
      key: json['key'] as String,
      enabled: json['enabled'] as bool? ?? false,
      description: json['description'] as String? ?? '',
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
    );
  }
}

class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.userId,
    required this.subject,
    required this.message,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String? userId;
  final String subject;
  final String message;
  final String status; // open | in_progress | resolved | closed
  final DateTime? createdAt;

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    return SupportTicket(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      subject: json['subject'] as String? ?? '',
      message: json['message'] as String? ?? '',
      status: json['status'] as String? ?? 'open',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }
}

class AffiliateSummary {
  const AffiliateSummary({
    required this.days,
    required this.total,
    required this.byPartner,
  });

  final int days;
  final int total;
  final Map<String, int> byPartner;

  factory AffiliateSummary.fromJson(Map<String, dynamic> json) {
    final raw = json['by_partner'] is Map<String, dynamic>
        ? json['by_partner'] as Map<String, dynamic>
        : <String, dynamic>{};
    return AffiliateSummary(
      days: (json['days'] as num?)?.toInt() ?? 30,
      total: (json['total'] as num?)?.toInt() ?? 0,
      byPartner: raw.map((k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0)),
    );
  }
}

class AdminUser {
  const AdminUser({
    required this.id,
    this.email,
    this.phone,
    this.authProvider,
    this.createdAt,
  });

  final String id;
  final String? email;
  final String? phone;
  final String? authProvider;
  final DateTime? createdAt;

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      authProvider: json['auth_provider'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }
}

class AdminRole {
  const AdminRole({required this.role});

  final String role;

  factory AdminRole.fromJson(Map<String, dynamic> json) {
    return AdminRole(role: json['role'] as String);
  }
}

/// Client for the admin-only /admin Edge Function (spec 2.13). Every call is
/// server-gated on a verified admin_users row; privileged writes additionally
/// require the 'super_admin' role server-side.
class AdminRepository extends BaseRepository {
  AdminRepository(this._apiClient);
  final ApiClient _apiClient;

  Future<AdminRole> me() async {
    final res = await _apiClient.get('/admin/me');
    return parseObject(res, AdminRole.fromJson);
  }

  Future<AdminStats> stats() async {
    final res = await _apiClient.get('/admin/stats');
    return parseObject(res, AdminStats.fromJson);
  }

  Future<List<AuditEntry>> audit({int limit = 100, String? action}) async {
    final res = await _apiClient.get('/admin/audit', queryParameters: {
      'limit': '$limit',
      if (action != null) 'action': action,
    });
    return parseList(res, AuditEntry.fromJson);
  }

  Future<List<FeatureFlag>> flags() async {
    final res = await _apiClient.get('/admin/flags');
    return parseList(res, FeatureFlag.fromJson);
  }

  Future<void> setFlag(String key, bool enabled) async {
    await _apiClient
        .patch('/admin/flags', body: {'key': key, 'enabled': enabled});
  }

  Future<List<SupportTicket>> support({String? status}) async {
    final res = await _apiClient.get('/admin/support', queryParameters: {
      if (status != null) 'status': status,
    });
    return parseList(res, SupportTicket.fromJson);
  }

  Future<void> updateTicket(String ticketId, String status) async {
    await _apiClient.patch('/admin/support',
        body: {'ticket_id': ticketId, 'status': status});
  }

  Future<AffiliateSummary> affiliate({int days = 30}) async {
    final res = await _apiClient
        .get('/admin/affiliate', queryParameters: {'days': '$days'});
    return parseObject(res, AffiliateSummary.fromJson);
  }

  Future<List<AdminUser>> users({String query = ''}) async {
    final res = await _apiClient.get('/admin/users', queryParameters: {
      if (query.isNotEmpty) 'q': query,
    });
    return parseList(res, AdminUser.fromJson);
  }
}

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(ref.watch(apiClientProvider));
});
