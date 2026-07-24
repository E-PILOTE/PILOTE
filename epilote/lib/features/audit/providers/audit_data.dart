import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:postgrest/postgrest.dart' show CountOption;
import 'package:realtime_client/realtime_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../../auth/providers/auth_provider.dart';
import 'audit_models.dart';
import 'audit_scope.dart';

export 'audit_models.dart';
export 'audit_scope.dart';

// ─── État des filtres (partagé) ───────────────────────────────────────────────
final auditFiltersProvider =
    StateProvider.autoDispose<AuditFilters>((ref) => const AuditFilters());

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
final AutoDisposeProvider<void> _auditRealtimeProvider =
    Provider.autoDispose<void>((ref) {
  ref.keepAlive();
  final client = ref.watch(supabaseClientProvider);
  final scope = ref.watch(auditScopeProvider);
  if (scope == null) return;

  Timer? debounce;
  try {
    final channel = client.channel('audit_${scope.channelKey}');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'audit_logs',
      filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: scope.column,
          value: scope.id),
      callback: (_) {
        debounce?.cancel();
        debounce = Timer(const Duration(seconds: 2), () {
          ref.invalidate(auditFacetsProvider);
          ref.invalidate(auditPageProvider);
          ref.invalidate(auditTimelineProvider);
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
final auditFacetsProvider =
    FutureProvider.autoDispose.family<AuditFacets, AuditFilters>((ref, raw) async {
  ref.keepAlive();
  ref.watch(_auditRealtimeProvider);
  final filters = raw.facetKey;
  final client = ref.watch(supabaseClientProvider);
  final scope = ref.watch(auditScopeProvider);
  if (scope == null) return AuditFacets.empty;

  final tables = <String>{};
  final roles = <String>{};
  final schoolIds = <String>{};
  try {
    final r = await client
        .from('audit_logs')
        .select('table_name, user_role, school_id')
        .eq(scope.column, scope.id)
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

  // Dimension « École » : résolue seulement en périmètre groupe (en périmètre
  // école, une seule école → filtre déroulant redondant, on ne le peuple pas).
  final schoolNameMap = <String, String>{};
  if (scope.showSchoolDimension && schoolIds.isNotEmpty) {
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
  final schoolList = scope.showSchoolDimension
      ? (schoolIds
          .map((id) => (id: id, name: schoolNameMap[id] ?? id))
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name)))
      : const <({String id, String name})>[];

  Future<int> countFor(String? action) async {
    try {
      var q = client
          .from('audit_logs')
          .count(CountOption.exact)
          .eq(scope.column, scope.id);
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
        .eq(scope.column, scope.id);
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
final auditTimelineProvider =
    FutureProvider.autoDispose<AuditTimeline>((ref) async {
  ref.keepAlive();
  ref.watch(_auditRealtimeProvider);
  final client = ref.watch(supabaseClientProvider);
  final scope = ref.watch(auditScopeProvider);
  if (scope == null) return AuditTimeline.empty;

  final now = DateTime.now();
  final cutoff = DateTime(now.year, now.month, now.day)
      .subtract(const Duration(days: 29))
      .toUtc();

  try {
    final res = await client
        .from('audit_logs')
        .select('action, created_at, user_id, user_role, table_name, school_id')
        .eq(scope.column, scope.id)
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

    // Top écoles — périmètre groupe uniquement (redondant pour une seule école)
    var topSchools = <AuditSchoolStat>[];
    if (scope.showSchoolDimension) {
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
      topSchools = topSchoolIds
          .map((id) => AuditSchoolStat(
                schoolId: id,
                name: schoolNames[id] ?? '—',
                count: schoolCount[id]!,
              ))
          .toList();
    }

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
final auditPageProvider =
    FutureProvider.autoDispose.family<AuditPage, AuditFilters>((ref, filters) async {
  ref.keepAlive();
  ref.watch(_auditRealtimeProvider);
  final client = ref.watch(supabaseClientProvider);
  final scope = ref.watch(auditScopeProvider);
  if (scope == null) return AuditPage.empty;

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
        .eq(scope.column, scope.id);
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

  final entries = await _hydrate(client, scope, rows);
  return AuditPage(entries: entries, totalCount: total);
});

// ─── Hydratation : résout auteurs (+ écoles en périmètre groupe) ──────────────
Future<List<AuditEntry>> _hydrate(
    SupabaseClient client, AuditScope scope, List<Map<String, dynamic>> rows) async {
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

  // Noms d'école : seulement en périmètre groupe (colonne « École » affichée).
  final schoolNames = <String, String>{};
  if (scope.showSchoolDimension && schoolIds.isNotEmpty) {
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

// ─── Fonction utilitaire : récupère TOUS les résultats filtrés pour l'export ─
Future<List<AuditEntry>> fetchAllAuditForExport({
  required SupabaseClient client,
  required AuditScope scope,
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
        .eq(scope.column, scope.id);
    sel = _applyAuditFilters(sel, filters);
    if (q.isNotEmpty) sel = sel.ilike('table_name', '%$q%');
    final res = await sel
        .order('created_at', ascending: false)
        .limit(limit) as List;
    rows.addAll(res.cast<Map<String, dynamic>>());
  } catch (_) {
    return [];
  }

  return _hydrate(client, scope, rows);
}
