class Subscription {
  final String status; // ACTIVE, INACTIVE, EXPIRED, TRIAL, TRIAL_EXPIRED
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool? isTrial;
  final String? trialStartDate;
  final String? trialEndDate;
  final int? trialDays;
  final int? trialDaysRemaining;
  final SubscriptionPlan? plan;

  Subscription({
    required this.status,
    this.createdAt,
    this.updatedAt,
    this.isTrial,
    this.trialStartDate,
    this.trialEndDate,
    this.trialDays,
    this.trialDaysRemaining,
    this.plan,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      status: json['status'] as String,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      isTrial: json['isTrial'] as bool?,
      trialStartDate: json['trialStartDate'] as String?,
      trialEndDate: json['trialEndDate'] as String?,
      trialDays: json['trialDays'] as int?,
      trialDaysRemaining: json['trialDaysRemaining'] as int?,
      plan: json['plan'] != null
          ? SubscriptionPlan.fromJson(json['plan'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'isTrial': isTrial,
      'trialStartDate': trialStartDate,
      'trialEndDate': trialEndDate,
      'trialDays': trialDays,
      'trialDaysRemaining': trialDaysRemaining,
      'plan': plan?.toJson(),
    };
  }
}

class SubscriptionPlan {
  final String name;
  final String? description;
  final List<PlanFeature> features;

  SubscriptionPlan({
    required this.name,
    this.description,
    required this.features,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      name: json['name'] as String,
      description: json['description'] as String?,
      features: (json['features'] as List<dynamic>?)
              ?.map((e) => PlanFeature.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'features': features.map((e) => e.toJson()).toList(),
    };
  }
}

class PlanFeature {
  final String feature;
  final bool enabled;

  PlanFeature({
    required this.feature,
    required this.enabled,
  });

  factory PlanFeature.fromJson(Map<String, dynamic> json) {
    return PlanFeature(
      feature: json['feature'] as String,
      enabled: json['enabled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'feature': feature,
      'enabled': enabled,
    };
  }
}
