/// Modèle correspondant à la table `subscriptions`
class SubscriptionModel {

  const SubscriptionModel({
    required this.id,
    required this.groupId,
    required this.planId,
    required this.status,
    required this.startDate,
    this.endDate,
    required this.isAutoRenew,
    required this.createdAt,
    required this.updatedAt,
    this.planName,
    this.planPriceMonthly,
    this.planMaxSchools,
  });

  factory SubscriptionModel.fromMap(Map<String, dynamic> map) {
    final plan = map['subscription_plans'] as Map<String, dynamic>?;
    return SubscriptionModel(
      id: map['id'] as String,
      groupId: map['group_id'] as String,
      planId: map['plan_id'] as String,
      status: map['status'] as String? ?? 'active',
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: map['end_date'] != null
          ? DateTime.parse(map['end_date'] as String)
          : null,
      isAutoRenew: map['is_auto_renew'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      planName: plan?['name'] as String?,
      planPriceMonthly: plan?['price_monthly'] as int?,
      planMaxSchools: plan?['max_schools'] as int?,
    );
  }
  final String id;
  final String groupId;
  final String planId;
  final String status; // active, expired, cancelled, trial
  final DateTime startDate;
  final DateTime? endDate;
  final bool isAutoRenew;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Jointure optionnelle avec subscription_plans
  final String? planName;
  final int? planPriceMonthly;
  final int? planMaxSchools;

  bool get isActive => status == 'active';
  bool get isExpired => status == 'expired' ||
      (endDate != null && endDate!.isBefore(DateTime.now()));

  int get daysRemaining {
    if (endDate == null) return 9999;
    return endDate!.difference(DateTime.now()).inDays;
  }

  String get statusLabel {
    switch (status) {
      case 'active': return 'Actif';
      case 'expired': return 'Expiré';
      case 'cancelled': return 'Résilié';
      case 'trial': return 'Essai';
      default: return status;
    }
  }

  @override
  String toString() => 'SubscriptionModel($id, ${planName ?? planId}, $status)';
}
