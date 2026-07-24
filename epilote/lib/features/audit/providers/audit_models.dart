import 'package:flutter/foundation.dart';

import '../../admin_groupe/providers/admin_users_provider.dart' show roleLabel;

// ─── Constantes ───────────────────────────────────────────────────────────────
const int kAuditPageSize = 40;

// ─── Modèle d'une entrée ──────────────────────────────────────────────────────
class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.action,
    required this.tableName,
    required this.userName,
    required this.userRole,
    required this.createdAt,
    this.recordId,
    this.schoolName,
    this.schoolId,
    this.ipAddress,
    this.userAgent,
    this.oldValues,
    this.newValues,
  });

  final String id;
  final String action;
  final String tableName;
  final String userName;
  final String userRole;
  final DateTime? createdAt;
  final String? recordId;
  final String? schoolName;
  final String? schoolId;
  final String? ipAddress;
  final String? userAgent;
  final Map<String, dynamic>? oldValues;
  final Map<String, dynamic>? newValues;

  String get actionLabel => switch (action.toUpperCase()) {
        'INSERT' => 'Création',
        'UPDATE' => 'Modification',
        'DELETE' => 'Suppression',
        _ => action,
      };

  String get entityLabel => auditEntityLabel(tableName);
  String get roleLbl => userRole.isEmpty ? 'Système' : roleLabel(userRole);

  List<String> get newFields =>
      newValues?.keys.map((k) => k.toString()).toList() ?? const [];

  AuditSeverity get severity {
    if (action.toUpperCase() == 'DELETE') return AuditSeverity.high;
    const sensitiveEntities = {
      'profiles', 'access_profiles', 'profile_permissions',
      'student_payments', 'group_invoices', 'grades', 'bulletins',
      'payroll', 'expenses', 'budget_lines', 'staff_members',
      'discipline_incidents', 'infirmary_visits',
    };
    if (sensitiveEntities.contains(tableName)) return AuditSeverity.medium;
    return AuditSeverity.low;
  }

  List<AuditFieldDiff> buildDiff() {
    final oldV = oldValues ?? const {};
    final newV = newValues ?? const {};
    final keys = <String>{...oldV.keys, ...newV.keys}.toList()..sort();
    final result = <AuditFieldDiff>[];
    for (final k in keys) {
      final hasOld = oldV.containsKey(k);
      final hasNew = newV.containsKey(k);
      final before = hasOld ? oldV[k] : null;
      final after = hasNew ? newV[k] : null;
      final AuditDiffKind kind;
      if (!hasOld && hasNew) {
        kind = AuditDiffKind.added;
      } else if (hasOld && !hasNew) {
        kind = AuditDiffKind.removed;
      } else if (!_jsonEq(before, after)) {
        kind = AuditDiffKind.changed;
      } else {
        kind = AuditDiffKind.unchanged;
      }
      result.add(AuditFieldDiff(
        field: k,
        before: before,
        after: after,
        hasOld: hasOld,
        hasNew: hasNew,
        kind: kind,
      ));
    }
    return result;
  }

  static bool _jsonEq(dynamic a, dynamic b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a.toString() == b.toString();
  }
}

enum AuditDiffKind { added, removed, changed, unchanged }

enum AuditSeverity { low, medium, high }

class AuditFieldDiff {
  const AuditFieldDiff({
    required this.field,
    required this.before,
    required this.after,
    required this.hasOld,
    required this.hasNew,
    required this.kind,
  });
  final String field;
  final dynamic before;
  final dynamic after;
  final bool hasOld;
  final bool hasNew;
  final AuditDiffKind kind;
}

String auditEntityLabel(String t) => switch (t) {
      'schools' => 'École',
      'school_groups' => 'Groupe',
      'students' => 'Élève',
      'staff_members' => 'Personnel',
      'classes' => 'Classe',
      'class_enrollments' => 'Inscription classe',
      'student_payments' => 'Paiement',
      'fee_structures' => 'Frais de scolarité',
      'group_invoices' => 'Facture',
      'access_profiles' => "Profil d'accès",
      'profile_permissions' => 'Permission',
      'profiles' => 'Utilisateur',
      'grades' => 'Note',
      'bulletins' => 'Bulletin',
      'evaluations' => 'Évaluation',
      'attendance_records' => 'Présence',
      'attendance_entries' => 'Présence',
      'discipline_incidents' => 'Incident',
      'infirmary_visits' => 'Passage infirmerie',
      'payroll' => 'Paie',
      'expenses' => 'Dépense',
      'budget_lines' => 'Budget',
      'leave_requests' => 'Congé',
      'support_tickets' => 'Ticket support',
      'subscription_plans' => "Plan d'abonnement",
      'announcements' => 'Annonce',
      'events' => 'Événement',
      'group_settings' => 'Paramètres',
      'student_documents' => 'Document élève',
      _ => t.replaceAll('_', ' '),
    };

// ─── Filtres ──────────────────────────────────────────────────────────────────
@immutable
class AuditFilters {
  const AuditFilters({
    this.action = 'all',
    this.table = 'all',
    this.role = 'all',
    this.schoolId = 'all',
    this.dateFrom,
    this.dateTo,
    this.query = '',
    this.page = 0,
  });

  final String action;
  final String table;
  final String role;
  final String schoolId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String query;
  final int page;

  bool get hasActiveFilters =>
      action != 'all' ||
      table != 'all' ||
      role != 'all' ||
      schoolId != 'all' ||
      dateFrom != null ||
      dateTo != null ||
      query.trim().isNotEmpty;

  AuditFilters get facetKey => copyWith(page: 0);

  AuditFilters copyWith({
    String? action,
    String? table,
    String? role,
    String? schoolId,
    Object? dateFrom = _sentinel,
    Object? dateTo = _sentinel,
    String? query,
    int? page,
  }) {
    return AuditFilters(
      action: action ?? this.action,
      table: table ?? this.table,
      role: role ?? this.role,
      schoolId: schoolId ?? this.schoolId,
      dateFrom: dateFrom == _sentinel ? this.dateFrom : dateFrom as DateTime?,
      dateTo: dateTo == _sentinel ? this.dateTo : dateTo as DateTime?,
      query: query ?? this.query,
      page: page ?? this.page,
    );
  }

  static const Object _sentinel = Object();

  @override
  bool operator ==(Object other) =>
      other is AuditFilters &&
      other.action == action &&
      other.table == table &&
      other.role == role &&
      other.schoolId == schoolId &&
      other.dateFrom == dateFrom &&
      other.dateTo == dateTo &&
      other.query.trim() == query.trim() &&
      other.page == page;

  @override
  int get hashCode =>
      Object.hash(action, table, role, schoolId, dateFrom, dateTo, query.trim(), page);
}

// ─── Résultat paginé ──────────────────────────────────────────────────────────
class AuditPage {
  const AuditPage({required this.entries, required this.totalCount});
  final List<AuditEntry> entries;
  final int totalCount;
  static const empty = AuditPage(entries: [], totalCount: 0);
}

// ─── Facettes + KPI ───────────────────────────────────────────────────────────
class AuditFacets {
  const AuditFacets({
    required this.tables,
    required this.roles,
    required this.schools,
    required this.total,
    required this.creations,
    required this.modifications,
    required this.suppressions,
    required this.activeUsers,
    required this.lastEventAt,
  });

  final List<String> tables;
  final List<String> roles;
  final List<({String id, String name})> schools;
  final int total;
  final int creations;
  final int modifications;
  final int suppressions;
  final int activeUsers;
  final DateTime? lastEventAt;

  static const empty = AuditFacets(
    tables: [],
    roles: [],
    schools: [],
    total: 0,
    creations: 0,
    modifications: 0,
    suppressions: 0,
    activeUsers: 0,
    lastEventAt: null,
  );
}

// ─── Modèles graphiques ───────────────────────────────────────────────────────
class AuditDayBucket {
  const AuditDayBucket({
    required this.day,
    required this.inserts,
    required this.updates,
    required this.deletes,
  });
  final DateTime day;
  final int inserts;
  final int updates;
  final int deletes;
  int get total => inserts + updates + deletes;
  String get dayLabel {
    final now = DateTime.now();
    final diff = DateTime(now.year, now.month, now.day)
        .difference(DateTime(day.year, day.month, day.day))
        .inDays;
    if (diff == 0) return 'Auj.';
    if (diff == 1) return 'Hier';
    return '${day.day}/${day.month}';
  }
}

class AuditTopActor {
  const AuditTopActor({
    required this.userId,
    required this.name,
    required this.role,
    required this.count,
  });
  final String userId;
  final String name;
  final String role;
  final int count;
}

class AuditEntityStat {
  const AuditEntityStat({required this.table, required this.count});
  final String table;
  final int count;
  String get label => auditEntityLabel(table);
}

class AuditSchoolStat {
  const AuditSchoolStat({
    required this.schoolId,
    required this.name,
    required this.count,
  });
  final String schoolId;
  final String name;
  final int count;
}

class AuditTimeline {
  const AuditTimeline({
    required this.buckets,
    required this.topActors,
    required this.topEntities,
    required this.topSchools,
  });
  final List<AuditDayBucket> buckets;
  final List<AuditTopActor> topActors;
  final List<AuditEntityStat> topEntities;
  final List<AuditSchoolStat> topSchools;

  static const empty = AuditTimeline(
    buckets: [],
    topActors: [],
    topEntities: [],
    topSchools: [],
  );
}

// ─── Alertes / Anomalies ─────────────────────────────────────────────────────
enum AuditAlertLevel { info, warning, critical }

class AuditAlert {
  const AuditAlert({
    required this.level,
    required this.title,
    required this.description,
    required this.iconCode,
  });
  final AuditAlertLevel level;
  final String title;
  final String description;
  final int iconCode;
}

List<AuditAlert> computeAuditAlerts(AuditTimeline timeline, AuditFacets facets) {
  final alerts = <AuditAlert>[];
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  if (timeline.buckets.isNotEmpty) {
    // 1. Suppressions massives : un jour avec ≥ 5 suppressions
    for (final b in timeline.buckets) {
      if (b.deletes >= 5) {
        final diff = today.difference(DateTime(b.day.year, b.day.month, b.day.day)).inDays;
        final dayStr = diff == 0 ? "aujourd'hui" : diff == 1 ? 'hier' : 'le ${b.day.day}/${b.day.month}';
        alerts.add(AuditAlert(
          level: AuditAlertLevel.critical,
          title: 'Suppressions massives',
          description:
              '${b.deletes} suppressions détectées $dayStr. Vérifiez si ces suppressions sont légitimes.',
          iconCode: 0xe801, // Icons.delete_forever_rounded
        ));
        break;
      }
    }

    // 2. Pic d'activité : 7 derniers jours vs 7 précédents
    final last7 = timeline.buckets
        .where((b) => today.difference(DateTime(b.day.year, b.day.month, b.day.day)).inDays < 7)
        .fold(0, (s, b) => s + b.total);
    final prev7 = timeline.buckets.where((b) {
      final d = today.difference(DateTime(b.day.year, b.day.month, b.day.day)).inDays;
      return d >= 7 && d < 14;
    }).fold(0, (s, b) => s + b.total);

    if (prev7 > 5 && last7 > prev7 * 2.5) {
      final pct = ((last7 / prev7 - 1) * 100).round();
      alerts.add(AuditAlert(
        level: AuditAlertLevel.warning,
        title: "Pic d'activité inhabituel",
        description:
            '$last7 événements cette semaine vs $prev7 la semaine précédente (+$pct%). Activité anormalement élevée.',
        iconCode: 0xe8e5, // Icons.trending_up_rounded
      ));
    }

    // 3. Taux de suppression élevé (> 25%)
    if (facets.total > 20) {
      final ratio = facets.suppressions / facets.total;
      if (ratio > 0.25) {
        alerts.add(AuditAlert(
          level: AuditAlertLevel.warning,
          title: 'Taux de suppression élevé',
          description:
              '${(ratio * 100).round()}% des opérations sont des suppressions'
              ' (${facets.suppressions}/${facets.total}). À surveiller.',
          iconCode: 0xe002, // Icons.warning_amber_rounded
        ));
      }
    }

    // 4. Acteur dominant : un utilisateur > 60% des événements
    if (timeline.topActors.isNotEmpty && facets.total > 10) {
      final top = timeline.topActors.first;
      if (top.count / facets.total > 0.6) {
        alerts.add(AuditAlert(
          level: AuditAlertLevel.info,
          title: 'Activité concentrée',
          description:
              '${top.name} représente ${(top.count / facets.total * 100).round()}%'
              ' des événements (${top.count}/${facets.total}). Un seul acteur domine le journal.',
          iconCode: 0xe7fd, // Icons.person_alert_rounded
        ));
      }
    }
  }

  // 5. Journal inactif depuis > 7 jours
  if (facets.total > 0 && facets.lastEventAt != null) {
    final daysSince = now.difference(facets.lastEventAt!).inDays;
    if (daysSince >= 7) {
      alerts.add(AuditAlert(
        level: AuditAlertLevel.info,
        title: 'Inactivité prolongée',
        description:
            'Aucun événement enregistré depuis $daysSince jours. Vérifiez que les utilisateurs sont bien connectés.',
        iconCode: 0xe192, // Icons.schedule_rounded
      ));
    }
  }

  return alerts;
}
