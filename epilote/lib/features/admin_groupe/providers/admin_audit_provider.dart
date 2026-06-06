import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:postgrest/postgrest.dart' show CountOption;
import 'package:realtime_client/realtime_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../../../features/auth/providers/auth_provider.dart';
import 'admin_users_provider.dart' show roleLabel;

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
      'discipline_incidents' => 'Incident',
      'support_tickets' => 'Ticket support',
      'subscription_plans' => "Plan d'abonnement",
      'announcements' => 'Annonce',
      'events' => 'Événement',
      'group_settings' => 'Paramètres',
      'student_documents' => 'Document élève',
      'leave_requests' => 'Congé',
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

final adminAuditFiltersProvider =
    StateProvider.autoDispose<AuditFilters>((ref) => const AuditFilters());

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

// ─── Helpers requête ──────────────────────────────────────────────────────────
dynamic _applyAuditFilters(dynamic q, AuditFilters f) {
  if (f.action != 'all') q = q.eq('action', f.action);
  if (f.table != 'all') q = q.eq('table_name', f.table);
  if (f.role != 'all') q = q.eq('user_role', f.role);
  if (f.schoolId != 'all') q = q.eq('school_id', f.schoolId);
  if (f.dateFrom != null) {
    q = q.gte('created_at', f.dateFrom!.toUtc().toIso8601String());
  }
  if (f.dateTo != null) {
    final endExclusive =
        DateTime(f.dateTo!.year, f.dateTo!.month, f.dateTo!.day)
            .add(const Duration(days: 1));
    q = q.lt('created_at', endExclusive.toUtc().toIso8601String());
  }
  return q;
}

// ─── Realtime ─────────────────────────────────────────────────────────────────
final AutoDisposeProvider<void> _adminAuditRealtimeProvider =
    Provider.autoDispose<void>((ref) {
  ref.keepAlive();
  final client = ref.watch(supabaseClientProvider);
  final groupId = ref.watch(authNotifierProvider).valueOrNull?.groupId;
  if (groupId == null) return;

  Timer? debounce;
  try {
    final channel = client.channel('admin_audit_$groupId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'audit_logs',
      filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq, column: 'group_id', value: groupId),
      callback: (_) {
        debounce?.cancel();
        debounce = Timer(const Duration(seconds: 2), () {
          ref.invalidate(adminAuditFacetsProvider);
          ref.invalidate(adminAuditPageProvider);
          ref.invalidate(adminAuditTimelineProvider);
        });
      },
    );
    channel.subscribe();
    ref.onDispose(() {
      debounce?.cancel();
      client.removeChannel(channel);
    });
  } catch (_) {}
});

// ─── Provider : facettes + KPI ────────────────────────────────────────────────
final adminAuditFacetsProvider =
    FutureProvider.autoDispose.family<AuditFacets, AuditFilters>((ref, raw) async {
  ref.keepAlive();
  ref.watch(_adminAuditRealtimeProvider);
  final filters = raw.facetKey;
  final client = ref.watch(supabaseClientProvider);
  final groupId = ref.watch(authNotifierProvider).valueOrNull?.groupId;
  if (groupId == null) return AuditFacets.empty;

  final tables = <String>{};
  final roles = <String>{};
  final schoolIds = <String>{};
  try {
    final r = await client
        .from('audit_logs')
        .select('table_name, user_role, school_id')
        .eq('group_id', groupId)
        .limit(2000) as List;
    for (final row in r) {
      final t = row['table_name'] as String?;
      final ro = row['user_role'] as String?;
      final sid = row['school_id'] as String?;
      if (t != null && t.isNotEmpty) tables.add(t);
      if (ro != null && ro.isNotEmpty) roles.add(ro);
      if (sid != null) schoolIds.add(sid);
    }
  } catch (_) {}

  // Résolution des noms d'école pour le filtre dropdown
  final schoolNameMap = <String, String>{};
  if (schoolIds.isNotEmpty) {
    try {
      final s = await client
          .from('schools')
          .select('id, name')
          .inFilter('id', schoolIds.toList()) as List;
      for (final r in s) {
        schoolNameMap[r['id'] as String] = r['name'] as String? ?? '—';
      }
    } catch (_) {}
  }
  final schoolList = schoolIds
      .map((id) => (id: id, name: schoolNameMap[id] ?? id))
      .toList()
    ..sort((a, b) => a.name.compareTo(b.name));

  Future<int> countFor(String? action) async {
    try {
      var q = client
          .from('audit_logs')
          .count(CountOption.exact)
          .eq('group_id', groupId);
      q = _applyAuditFilters(
          q, action == null ? filters : filters.copyWith(action: action));
      return await q;
    } catch (_) {
      return 0;
    }
  }

  final total = await countFor(null);
  final creations = await countFor('INSERT');
  final modifications = await countFor('UPDATE');
  final suppressions = await countFor('DELETE');

  int activeUsers = 0;
  DateTime? lastEventAt;
  try {
    var q = client
        .from('audit_logs')
        .select('user_id, created_at')
        .eq('group_id', groupId);
    q = _applyAuditFilters(q, filters);
    final r = await q.order('created_at', ascending: false).limit(2000) as List;
    final seen = <String>{};
    for (final row in r) {
      final uid = row['user_id'] as String?;
      if (uid != null) seen.add(uid);
    }
    activeUsers = seen.length;
    if (r.isNotEmpty) {
      lastEventAt = DateTime.tryParse(r.first['created_at'] as String? ?? '');
    }
  } catch (_) {}

  return AuditFacets(
    tables: tables.toList()..sort(),
    roles: roles.toList()..sort(),
    schools: schoolList,
    total: total,
    creations: creations,
    modifications: modifications,
    suppressions: suppressions,
    activeUsers: activeUsers,
    lastEventAt: lastEventAt,
  );
});

// ─── Provider : timeline 30 jours ────────────────────────────────────────────
final adminAuditTimelineProvider =
    FutureProvider.autoDispose<AuditTimeline>((ref) async {
  ref.keepAlive();
  ref.watch(_adminAuditRealtimeProvider);
  final client = ref.watch(supabaseClientProvider);
  final groupId = ref.watch(authNotifierProvider).valueOrNull?.groupId;
  if (groupId == null) return AuditTimeline.empty;

  final now = DateTime.now();
  final cutoff = DateTime(now.year, now.month, now.day)
      .subtract(const Duration(days: 29))
      .toUtc();

  try {
    final res = await client
        .from('audit_logs')
        .select('action, created_at, user_id, user_role, table_name, school_id')
        .eq('group_id', groupId)
        .gte('created_at', cutoff.toIso8601String())
        .order('created_at', ascending: true)
        .limit(5000) as List;

    // Buckets initialisés sur 30 jours complets
    final bucketMap = <String, Map<String, int>>{};
    for (int i = 0; i < 30; i++) {
      final d =
          DateTime(now.year, now.month, now.day).subtract(Duration(days: 29 - i));
      final key = _dayKey(d);
      bucketMap[key] = {'INSERT': 0, 'UPDATE': 0, 'DELETE': 0};
    }

    final actorCount = <String, ({int count, String role})>{};
    final entityCount = <String, int>{};
    final schoolCount = <String, int>{};

    for (final row in res) {
      final createdAt = DateTime.tryParse(row['created_at'] as String? ?? '');
      if (createdAt == null) continue;
      final local = createdAt.toLocal();
      final key = _dayKey(local);
      final action = (row['action'] as String? ?? '').toUpperCase();
      if (bucketMap.containsKey(key) &&
          ['INSERT', 'UPDATE', 'DELETE'].contains(action)) {
        bucketMap[key]![action] = (bucketMap[key]![action] ?? 0) + 1;
      }
      final uid = row['user_id'] as String?;
      if (uid != null) {
        final r = row['user_role'] as String? ?? '';
        final existing = actorCount[uid];
        actorCount[uid] = (count: (existing?.count ?? 0) + 1, role: r);
      }
      final table = row['table_name'] as String? ?? '';
      if (table.isNotEmpty) entityCount[table] = (entityCount[table] ?? 0) + 1;
      final sid = row['school_id'] as String?;
      if (sid != null) schoolCount[sid] = (schoolCount[sid] ?? 0) + 1;
    }

    final buckets = bucketMap.entries.map((e) {
      final parts = e.key.split('-');
      final day = DateTime(
          int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      return AuditDayBucket(
        day: day,
        inserts: e.value['INSERT'] ?? 0,
        updates: e.value['UPDATE'] ?? 0,
        deletes: e.value['DELETE'] ?? 0,
      );
    }).toList()
      ..sort((a, b) => a.day.compareTo(b.day));

    // Top acteurs
    final sortedActors = actorCount.entries.toList()
      ..sort((a, b) => b.value.count.compareTo(a.value.count));
    final topActorIds = sortedActors.take(5).map((e) => e.key).toList();

    final userNames = <String, String>{};
    if (topActorIds.isNotEmpty) {
      try {
        final p = await client
            .from('profiles')
            .select('id, first_name, last_name')
            .inFilter('id', topActorIds) as List;
        for (final r in p) {
          final fn = (r['first_name'] as String? ?? '').trim();
          final ln = (r['last_name'] as String? ?? '').trim();
          userNames[r['id'] as String] = '$fn $ln'.trim();
        }
      } catch (_) {}
    }
    final topActors = topActorIds.map((id) {
      final info = actorCount[id]!;
      return AuditTopActor(
        userId: id,
        name: userNames[id] ?? 'Utilisateur',
        role: info.role,
        count: info.count,
      );
    }).toList();

    // Top écoles
    final sortedSchools = schoolCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topSchoolIds = sortedSchools.take(5).map((e) => e.key).toList();

    final schoolNames = <String, String>{};
    if (topSchoolIds.isNotEmpty) {
      try {
        final s = await client
            .from('schools')
            .select('id, name')
            .inFilter('id', topSchoolIds) as List;
        for (final r in s) {
          schoolNames[r['id'] as String] = r['name'] as String? ?? '—';
        }
      } catch (_) {}
    }
    final topSchools = topSchoolIds
        .map((id) => AuditSchoolStat(
              schoolId: id,
              name: schoolNames[id] ?? '—',
              count: schoolCount[id]!,
            ))
        .toList();

    // Top entités
    final topEntities = (entityCount.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(5)
        .map((e) => AuditEntityStat(table: e.key, count: e.value))
        .toList();

    return AuditTimeline(
      buckets: buckets,
      topActors: topActors,
      topEntities: topEntities,
      topSchools: topSchools,
    );
  } catch (_) {
    return AuditTimeline.empty;
  }
});

String _dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// ─── Provider : page de journal (liste paginée) ───────────────────────────────
final adminAuditPageProvider =
    FutureProvider.autoDispose.family<AuditPage, AuditFilters>((ref, filters) async {
  ref.keepAlive();
  ref.watch(_adminAuditRealtimeProvider);
  final client = ref.watch(supabaseClientProvider);
  final groupId = ref.watch(authNotifierProvider).valueOrNull?.groupId;
  if (groupId == null) return AuditPage.empty;

  final from = filters.page * kAuditPageSize;
  final to = from + kAuditPageSize - 1;
  final q = filters.query.trim();

  final List<Map<String, dynamic>> rows = [];
  int total = 0;
  try {
    var sel = client
        .from('audit_logs')
        .select(
            'id, action, table_name, record_id, user_id, user_role, '
            'school_id, old_values, new_values, ip_address, user_agent, created_at')
        .eq('group_id', groupId);
    sel = _applyAuditFilters(sel, filters);
    if (q.isNotEmpty) {
      sel = sel.ilike('table_name', '%$q%');
    }
    final res = await sel
        .order('created_at', ascending: false)
        .range(from, to)
        .count(CountOption.exact);
    total = res.count;
    rows.addAll((res.data as List).cast<Map<String, dynamic>>());
  } catch (_) {
    return AuditPage.empty;
  }

  final userIds = <String>{
    for (final r in rows)
      if (r['user_id'] != null) r['user_id'] as String
  };
  final schoolIds = <String>{
    for (final r in rows)
      if (r['school_id'] != null) r['school_id'] as String
  };

  final userNames = <String, String>{};
  if (userIds.isNotEmpty) {
    try {
      final p = await client
          .from('profiles')
          .select('id, first_name, last_name')
          .inFilter('id', userIds.toList()) as List;
      for (final r in p) {
        final fn = (r['first_name'] as String? ?? '').trim();
        final ln = (r['last_name'] as String? ?? '').trim();
        final full = '$fn $ln'.trim();
        userNames[r['id'] as String] = full.isEmpty ? 'Système' : full;
      }
    } catch (_) {}
  }

  final schoolNames = <String, String>{};
  if (schoolIds.isNotEmpty) {
    try {
      final s = await client
          .from('schools')
          .select('id, name')
          .inFilter('id', schoolIds.toList()) as List;
      for (final r in s) {
        schoolNames[r['id'] as String] = r['name'] as String? ?? '—';
      }
    } catch (_) {}
  }

  final entries = rows.map((r) {
    final uid = r['user_id'] as String?;
    final sid = r['school_id'] as String?;
    final oldV = r['old_values'];
    final newV = r['new_values'];
    return AuditEntry(
      id: r['id'] as String,
      action: r['action'] as String? ?? '',
      tableName: r['table_name'] as String? ?? '',
      recordId: r['record_id'] as String?,
      userName: uid != null ? (userNames[uid] ?? 'Système') : 'Système',
      userRole: r['user_role'] as String? ?? '',
      schoolName: sid != null ? schoolNames[sid] : null,
      schoolId: sid,
      ipAddress: r['ip_address'] as String?,
      userAgent: r['user_agent'] as String?,
      createdAt: DateTime.tryParse(r['created_at'] as String? ?? ''),
      oldValues: oldV is Map ? Map<String, dynamic>.from(oldV) : null,
      newValues: newV is Map ? Map<String, dynamic>.from(newV) : null,
    );
  }).toList();

  return AuditPage(entries: entries, totalCount: total);
});

// ─── Fonction utilitaire : récupère TOUS les résultats filtrés pour l'export ─
Future<List<AuditEntry>> fetchAllAuditForExport({
  required SupabaseClient client,
  required String groupId,
  required AuditFilters filters,
  int limit = 5000,
}) async {
  final q = filters.query.trim();
  final List<Map<String, dynamic>> rows = [];
  try {
    var sel = client
        .from('audit_logs')
        .select(
            'id, action, table_name, record_id, user_id, user_role, '
            'school_id, old_values, new_values, ip_address, user_agent, created_at')
        .eq('group_id', groupId);
    sel = _applyAuditFilters(sel, filters);
    if (q.isNotEmpty) sel = sel.ilike('table_name', '%$q%');
    final res = await sel
        .order('created_at', ascending: false)
        .limit(limit) as List;
    rows.addAll(res.cast<Map<String, dynamic>>());
  } catch (_) {
    return [];
  }

  final userIds = <String>{
    for (final r in rows)
      if (r['user_id'] != null) r['user_id'] as String
  };
  final schoolIds = <String>{
    for (final r in rows)
      if (r['school_id'] != null) r['school_id'] as String
  };

  final userNames = <String, String>{};
  if (userIds.isNotEmpty) {
    try {
      final p = await client
          .from('profiles')
          .select('id, first_name, last_name')
          .inFilter('id', userIds.toList()) as List;
      for (final r in p) {
        final fn = (r['first_name'] as String? ?? '').trim();
        final ln = (r['last_name'] as String? ?? '').trim();
        userNames[r['id'] as String] = '$fn $ln'.trim().isEmpty
            ? 'Système'
            : '$fn $ln'.trim();
      }
    } catch (_) {}
  }

  final schoolNames = <String, String>{};
  if (schoolIds.isNotEmpty) {
    try {
      final s = await client
          .from('schools')
          .select('id, name')
          .inFilter('id', schoolIds.toList()) as List;
      for (final r in s) {
        schoolNames[r['id'] as String] = r['name'] as String? ?? '—';
      }
    } catch (_) {}
  }

  return rows.map((r) {
    final uid = r['user_id'] as String?;
    final sid = r['school_id'] as String?;
    final oldV = r['old_values'];
    final newV = r['new_values'];
    return AuditEntry(
      id: r['id'] as String,
      action: r['action'] as String? ?? '',
      tableName: r['table_name'] as String? ?? '',
      recordId: r['record_id'] as String?,
      userName: uid != null ? (userNames[uid] ?? 'Système') : 'Système',
      userRole: r['user_role'] as String? ?? '',
      schoolName: sid != null ? schoolNames[sid] : null,
      schoolId: sid,
      ipAddress: r['ip_address'] as String?,
      userAgent: r['user_agent'] as String?,
      createdAt: DateTime.tryParse(r['created_at'] as String? ?? ''),
      oldValues: oldV is Map ? Map<String, dynamic>.from(oldV) : null,
      newValues: newV is Map ? Map<String, dynamic>.from(newV) : null,
    );
  }).toList();
}
