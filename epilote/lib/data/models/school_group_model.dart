// Helper : accepte bool (Supabase) et int 0/1 (SQLite PowerSync)
bool _b(dynamic v) => v == true || v == 1;

/// Table `school_groups` — synchée offline (contient plan_id)
class SchoolGroupModel {

  const SchoolGroupModel({
    required this.id,
    required this.name,
    this.slug,
    required this.groupType,
    this.department,
    required this.planId,
    required this.subscriptionStatus,
    this.subscriptionStart,
    this.subscriptionEnd,
    required this.adminEmail,
    this.phone,
    this.address,
    this.logoUrl,
    required this.isActive,
    this.notes,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SchoolGroupModel.fromMap(Map<String, dynamic> map) {
    return SchoolGroupModel(
      id:                 map['id']                  as String,
      name:               map['name']                as String,
      slug:               map['slug']                as String?,
      groupType:          map['group_type']          as String? ?? 'prive',
      department:         map['department']          as String?,
      planId:             map['plan_id']             as String,
      subscriptionStatus: map['subscription_status'] as String? ?? 'trial',
      subscriptionStart:  map['subscription_start'] != null
          ? DateTime.parse(map['subscription_start'] as String)
          : null,
      subscriptionEnd: map['subscription_end'] != null
          ? DateTime.parse(map['subscription_end'] as String)
          : null,
      adminEmail:  map['admin_email'] as String,
      phone:       map['phone']       as String?,
      address:     map['address']     as String?,
      logoUrl:     map['logo_url']    as String?,
      isActive:    _b(map['is_active']),
      notes:       map['notes']       as String?,
      createdBy:   map['created_by']  as String?,
      createdAt:   DateTime.parse(map['created_at'] as String),
      updatedAt:   DateTime.parse(map['updated_at'] as String),
    );
  }

  final String id;
  final String name;
  final String? slug;
  final String groupType;       // 'public' | 'prive' | 'catholique' | 'islamique' | …
  final String? department;
  final String planId;
  final String subscriptionStatus; // 'trial' | 'active' | 'suspended' | 'cancelled'
  final DateTime? subscriptionStart;
  final DateTime? subscriptionEnd;
  final String adminEmail;
  final String? phone;
  final String? address;
  final String? logoUrl;
  final bool isActive;
  final String? notes;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isSubscriptionActive => subscriptionStatus == 'active';
  bool get isOnTrial            => subscriptionStatus == 'trial';

  Map<String, dynamic> toInsertMap() => {
    'name':                name,
    'slug':                slug,
    'group_type':          groupType,
    'department':          department,
    'plan_id':             planId,
    'subscription_status': subscriptionStatus,
    'admin_email':         adminEmail,
    'phone':               phone,
    'address':             address,
    'is_active':           isActive,
    'notes':               notes,
  };

  @override
  String toString() => 'SchoolGroupModel($id, $name, $subscriptionStatus)';
}
