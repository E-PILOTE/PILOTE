import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/auth/providers/auth_provider.dart';

// ─── Modèle AuditLog ──────────────────────────────────────────────────────────

class AuditLog {
  const AuditLog({
    required this.id,
    required this.userId,
    required this.action,
    required this.tableName,
    required this.createdAt,
    this.groupId,
    this.schoolId,
    this.recordId,
    this.userRole,
    this.oldValues,
    this.newValues,
    this.ipAddress,
    this.userAgent,
    this.userEmail,
  });

  factory AuditLog.fromMap(Map<String, dynamic> m) {
    final profile = m['profile'];
    final profileMap = profile is Map ? Map<String, dynamic>.from(profile) : const {};
    return AuditLog(
      id:         m['id']         as String,
      groupId:    m['group_id']   as String?,
      schoolId:   m['school_id']  as String?,
      userId:     m['user_id']    as String,
      userRole:   m['user_role']  as String?,
      action:     m['action']     as String? ?? '',
      tableName:  m['table_name'] as String? ?? '',
      recordId:   m['record_id']  as String?,
      oldValues:  m['old_values'] as Map<String, dynamic>?,
      newValues:  m['new_values'] as Map<String, dynamic>?,
      ipAddress:  m['ip_address'] as String?,
      userAgent:  m['user_agent'] as String?,
      userEmail:  profileMap['email'] as String?,
      createdAt:  DateTime.parse(m['created_at'] as String),
    );
  }

  final String  id, userId, action, tableName;
  final String? groupId, schoolId, recordId, userRole;
  final String? ipAddress, userAgent, userEmail;
  final Map<String, dynamic>? oldValues, newValues;
  final DateTime createdAt;

  String get actionLabel => switch (action) {
    'INSERT' => 'Création',
    'UPDATE' => 'Modification',
    'DELETE' => 'Suppression',
    _        => action,
  };

  String get tableLabel => _tableLabels[tableName] ?? tableName;

  String get userRoleLabel => switch (userRole) {
    'super_admin'          => 'Super Admin',
    'admin_groupe'         => 'Admin Groupe',
    'directeur'            => 'Directeur',
    'proviseur'            => 'Proviseur',
    'enseignant'           => 'Enseignant',
    'cpe'                  => 'CPE',
    'comptable'            => 'Comptable',
    'secretaire'           => 'Secrétaire',
    'surveillant'          => 'Surveillant',
    'parent'               => 'Parent',
    'eleve'                => 'Élève',
    'infirmier'            => 'Infirmier',
    'responsable_cantine'  => 'Resp. Cantine',
    _                      => userRole ?? '—',
  };

  String get initials {
    final e = userEmail ?? userRole ?? '?';
    return e[0].toUpperCase();
  }

  static const _tableLabels = {
    'school_groups':       'Groupes scolaires',
    'schools':             'Écoles',
    'profiles':            'Profils',
    'subscription_plans':  'Plans',
    'plan_modules':        'Modules plan',
    'modules':             'Modules',
    'module_categories':   'Catégories',
    'students':            'Élèves',
    'staff_members':       'Personnel',
    'classes':             'Classes',
    'announcements':       'Annonces',
    'group_invoices':      'Factures',
    'notifications':       'Notifications',
  };
}

// ─── Modèle données globales ───────────────────────────────────────────────────

class AuditData {
  const AuditData({
    required this.logs,
    required this.total,
    required this.inserts,
    required this.updates,
    required this.deletes,
    required this.todayCount,
    required this.distinctTables,
  });

  final List<AuditLog> logs;
  final int total, inserts, updates, deletes, todayCount, distinctTables;

  static const empty = AuditData(
    logs: [], total: 0, inserts: 0, updates: 0,
    deletes: 0, todayCount: 0, distinctTables: 0,
  );
}

// ─── Provider principal ─────────────────────────────────────────────────────────

final auditLogsProvider = FutureProvider.autoDispose<AuditData>((ref) async {
  ref.keepAlive();
  final client = ref.watch(supabaseClientProvider);

  List<AuditLog> logs = [];
  try {
    final rows = await client
        .from('audit_logs')
        .select('id, group_id, school_id, user_id, user_role, action, '
            'table_name, record_id, old_values, new_values, '
            'ip_address, user_agent, created_at, '
            'profile:profiles(email)')
        .order('created_at', ascending: false)
        .limit(500) as List;
    logs = rows.map((r) => AuditLog.fromMap(
        Map<String, dynamic>.from(r as Map))).toList();
  } catch (_) {}

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  int inserts = 0, updates = 0, deletes = 0, todayCount = 0;
  final tables = <String>{};
  for (final l in logs) {
    if (l.action == 'INSERT') { inserts++; }
    else if (l.action == 'UPDATE') { updates++; }
    else if (l.action == 'DELETE') { deletes++; }
    if (l.createdAt.isAfter(today)) { todayCount++; }
    tables.add(l.tableName);
  }

  return AuditData(
    logs:           logs,
    total:          logs.length,
    inserts:        inserts,
    updates:        updates,
    deletes:        deletes,
    todayCount:     todayCount,
    distinctTables: tables.length,
  );
});
