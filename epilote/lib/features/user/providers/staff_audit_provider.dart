import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/providers/auth_provider.dart';
import '../../admin_groupe/providers/admin_users_provider.dart' show roleLabel;

// ════════════════════════════════════════════════════════════════════════════
//  Journal d'audit — espace ÉCOLE (outil natif de direction).
//  ⚠️ EXCEPTION ASSUMÉE à la règle « personnel = PowerSync only » : l'audit est
//  une donnée de GOUVERNANCE (consultation), pas de terrain → lecture ONLINE
//  via supabase.from(), scopée à l'école par la RLS `audit_logs_tenant`
//  (school_id = auth_school_id()). Nécessite donc une connexion.
//  Réservé aux rôles direction (cf. AppConstants.directionRoles dans la sidebar).
// ════════════════════════════════════════════════════════════════════════════

enum StaffAuditSeverity { low, medium, high }

/// Libellé lisible d'une table auditée (sous-ensemble utile à l'école).
String staffAuditEntity(String table) => switch (table) {
      'profiles' => 'Utilisateur',
      'students' => 'Élève',
      'class_enrollments' => 'Inscription classe',
      'classes' => 'Classe',
      'grades' => 'Note',
      'bulletins' => 'Bulletin',
      'attendance_records' || 'attendance_entries' => 'Présence',
      'student_payments' => 'Paiement élève',
      'fee_structures' => 'Frais de scolarité',
      'payroll' => 'Paie',
      'expenses' => 'Dépense',
      'budget_lines' => 'Budget',
      'staff_members' => 'Personnel (RH)',
      'discipline_incidents' => 'Incident discipline',
      'infirmary_visits' => 'Passage infirmerie',
      'access_profiles' => "Profil d'accès",
      'profile_permissions' => 'Permissions',
      _ => table,
    };

class StaffAuditEntry {
  const StaffAuditEntry({
    required this.id,
    required this.action,
    required this.tableName,
    required this.actorName,
    required this.actorRole,
    required this.createdAt,
    this.recordId,
    this.oldValues,
    this.newValues,
  });

  factory StaffAuditEntry.fromRow(
      Map<String, dynamic> r, Map<String, String> names) {
    final uid = r['user_id'] as String?;
    return StaffAuditEntry(
      id:        r['id'] as String,
      action:    (r['action'] as String? ?? '').toUpperCase(),
      tableName: r['table_name'] as String? ?? '',
      actorName: (uid != null && (names[uid]?.isNotEmpty ?? false))
          ? names[uid]!
          : 'Système',
      actorRole: r['user_role'] as String? ?? '',
      recordId:  r['record_id'] as String?,
      createdAt: r['created_at'] != null
          ? DateTime.tryParse(r['created_at'] as String)
          : null,
      oldValues: r['old_values'] as Map<String, dynamic>?,
      newValues: r['new_values'] as Map<String, dynamic>?,
    );
  }

  final String id;
  final String action;
  final String tableName;
  final String actorName;
  final String actorRole;
  final String? recordId;
  final DateTime? createdAt;
  final Map<String, dynamic>? oldValues;
  final Map<String, dynamic>? newValues;

  String get actionLabel => switch (action) {
        'INSERT' => 'Création',
        'UPDATE' => 'Modification',
        'DELETE' => 'Suppression',
        _ => action.isEmpty ? '—' : action,
      };

  String get entityLabel => staffAuditEntity(tableName);
  String get roleLabelStr => actorRole.isEmpty ? 'Système' : roleLabel(actorRole);

  StaffAuditSeverity get severity {
    if (action == 'DELETE') return StaffAuditSeverity.high;
    const sensitive = {
      'profiles', 'access_profiles', 'profile_permissions',
      'student_payments', 'payroll', 'expenses', 'budget_lines',
      'staff_members', 'grades', 'bulletins', 'discipline_incidents',
      'infirmary_visits',
    };
    return sensitive.contains(tableName)
        ? StaffAuditSeverity.medium
        : StaffAuditSeverity.low;
  }

  /// Champs modifiés (clés des nouvelles valeurs) — aperçu compact.
  List<String> get changedFields {
    final keys = <String>{...?oldValues?.keys, ...?newValues?.keys}
      ..removeWhere((k) => k == 'updated_at' || k == 'created_at');
    return keys.toList()..sort();
  }
}

/// Filtre par type d'action ('all' | 'INSERT' | 'UPDATE' | 'DELETE').
final staffAuditActionFilterProvider =
    StateProvider.autoDispose<String>((_) => 'all');

/// Journal d'audit de l'école courante (online, RLS school-scopée).
final staffAuditProvider =
    FutureProvider.autoDispose<List<StaffAuditEntry>>((ref) async {
  ref.keepAlive();
  final client   = ref.watch(supabaseClientProvider);
  final schoolId = ref.watch(authNotifierProvider).valueOrNull?.schoolId;
  if (schoolId == null) return const [];

  final rows = await client
      .from('audit_logs')
      .select('id, action, table_name, record_id, user_id, user_role, '
          'old_values, new_values, created_at')
      .eq('school_id', schoolId)
      .order('created_at', ascending: false)
      .limit(300) as List;

  // Résolution des acteurs via profiles (audit_logs n'a pas le nom).
  final userIds = <String>{
    for (final r in rows)
      if (r['user_id'] != null) r['user_id'] as String,
  };
  final names = <String, String>{};
  if (userIds.isNotEmpty) {
    final prof = await client
        .from('profiles')
        .select('id, first_name, last_name')
        .inFilter('id', userIds.toList()) as List;
    for (final p in prof) {
      names[p['id'] as String] =
          '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}'.trim();
    }
  }

  return [
    for (final r in rows)
      StaffAuditEntry.fromRow(Map<String, dynamic>.from(r as Map), names),
  ];
});
