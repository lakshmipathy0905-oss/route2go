import 'package:flutter/foundation.dart';

@immutable
class TrustedContact {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final bool canViewLiveLocation;
  final bool canViewTripPlan;
  final bool canViewEta;
  final DateTime createdAt;

  const TrustedContact({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.canViewLiveLocation = true,
    this.canViewTripPlan = true,
    this.canViewEta = true,
    required this.createdAt,
  });

  TrustedContact copyWith({
    String? name,
    String? phone,
    String? email,
    bool? canViewLiveLocation,
    bool? canViewTripPlan,
    bool? canViewEta,
  }) {
    return TrustedContact(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      canViewLiveLocation: canViewLiveLocation ?? this.canViewLiveLocation,
      canViewTripPlan: canViewTripPlan ?? this.canViewTripPlan,
      canViewEta: canViewEta ?? this.canViewEta,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      if (email != null) 'email': email,
      'can_view_live_location': canViewLiveLocation,
      'can_view_trip_plan': canViewTripPlan,
      'can_view_eta': canViewEta,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory TrustedContact.fromJson(Map<String, dynamic> json) {
    return TrustedContact(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      email: json['email'] as String?,
      canViewLiveLocation: json['can_view_live_location'] as bool? ?? true,
      canViewTripPlan: json['can_view_trip_plan'] as bool? ?? true,
      canViewEta: json['can_view_eta'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

@immutable
class LiveTripShare {
  final String id;
  final String tripId;
  final String contactId;
  final String shareLink;
  final DateTime expiresAt;
  final bool isActive;

  const LiveTripShare({
    required this.id,
    required this.tripId,
    required this.contactId,
    required this.shareLink,
    required this.expiresAt,
    this.isActive = true,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trip_id': tripId,
      'contact_id': contactId,
      'share_link': shareLink,
      'expires_at': expiresAt.toIso8601String(),
      'is_active': isActive,
    };
  }
}
