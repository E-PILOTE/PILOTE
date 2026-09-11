import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:postgrest/postgrest.dart' show CountOption;
import 'package:realtime_client/realtime_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../../../core/utils/erreur_metier.dart';
import '../../auth/providers/auth_provider.dart';
import 'audit_models.dart';
import 'audit_noms.dart';
import 'audit_scope.dart';
import 'audit_timeline.dart';

export 'audit_noms.dart' show kNomNonResolu, kCompteIntrouvable;

export 'audit_models.dart';
export 'audit_scope.dart';

// La courbe des 30 jours vit dans son propre fichier depuis le 2026-09-09 ;
// les écrans continuent d'écrire `import '…/audit_data.dart'` et de lire
// `auditTimelineProvider` — la couture est interne, pas visible du dehors.
export 'audit_timeline.dart';

// ─── État des filtres (partagé) ───────────────────────────────────────────────
final auditFiltersProvider =
    StateProvider.autoDispose<AuditFilters>((ref) => const AuditFilters());

// ─── Helpers requête ──────────────────────────────────────────────────────────
/// Plancher de visibilité : exclut les actions dont l'acteur est d'un niveau
/// au-dessus du spectateur ([AuditScope.hiddenActorRoles]). Les lignes sans
/// `user_role` (rare : rôle acteur non résolu) restent visibles — on ne masque
/// jamais du travail légitime, on ne retire QUE les niveaux supérieurs nommés.
dynamic applyScopeFloor(dynamic q, AuditScope scope) {
  q = q.eq(scope.column, scope.id);
  if (scope.hiddenActorRoles.isNotEmpty) {
    final list = scope.hiddenActorRoles.join(',');
    q = q.or('user_role.is.null,user_role.not.in.($list)');
  }
  return q;
}

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
final AutoDisposeProvider<void> auditRealtimeProvider =
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
  ref.watch(auditRealtimeProvider);
  final filters = raw.facetKey;
  final client = ref.watch(supabaseClientProvider);
  final scope = ref.watch(auditScopeProvider);
  if (scope == null) return AuditFacets.empty;

  final tables = <String>{};
  final roles = <String>{};
  final schoolIds = <String>{};
  try {
    final base = applyScopeFloor(
        client.from('audit_logs').select('table_name, user_role, school_id'),
        scope);
    final r = await base.limit(2000) as List;
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
      var q = applyScopeFloor(
          client.from('audit_logs').count(CountOption.exact), scope);
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
    var q = applyScopeFloor(
        client.from('audit_logs').select('user_id, created_at'), scope);
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

// ─── Provider : page de journal (liste paginée) ───────────────────────────────
final auditPageProvider =
    FutureProvider.autoDispose.family<AuditPage, AuditFilters>((ref, filters) async {
  ref.keepAlive();
  ref.watch(auditRealtimeProvider);
  final client = ref.watch(supabaseClientProvider);
  final scope = ref.watch(auditScopeProvider);
  if (scope == null) return AuditPage.empty;

  final from = filters.page * kAuditPageSize;
  final to = from + kAuditPageSize - 1;
  final q = filters.query.trim();

  final List<Map<String, dynamic>> rows = [];
  int total = 0;
  try {
    var sel = applyScopeFloor(
        client.from('audit_logs').select(
            'id, action, table_name, record_id, user_id, user_role, '
            'school_id, old_values, new_values, ip_address, user_agent, created_at'),
        scope);
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
  var nomsIllisibles = false;
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
    } catch (e) {
      nomsIllisibles = true;
      debugPrint('ℹ️ Journal d’audit : noms des auteurs illisibles ($e).');
    }
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
      // ⚠️ « Système » est réservé aux lignes SANS auteur. L'écrire à la
      // place d'un nom qu'on n'a pas su lire attribue l'acte à la plateforme.
      userName: uid == null
          ? 'Système'
          : (userNames[uid] ??
              (nomsIllisibles ? kNomNonResolu : kCompteIntrouvable)),
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
    var sel = applyScopeFloor(
        client.from('audit_logs').select(
            'id, action, table_name, record_id, user_id, user_role, '
            'school_id, old_values, new_values, ip_address, user_agent, created_at'),
        scope);
    sel = _applyAuditFilters(sel, filters);
    if (q.isNotEmpty) sel = sel.ilike('table_name', '%$q%');
    final res = await sel
        .order('created_at', ascending: false)
        .limit(limit) as List;
    rows.addAll(res.cast<Map<String, dynamic>>());
  } catch (e) {
    // ⚠️ NE JAMAIS RENDRE `[]` ICI. Un export d'audit vide ne se lit pas comme
    // « la lecture a échoué » : il se lit comme « aucune activité sur la
    // période », et il part sous cette forme à un inspecteur, un ministère,
    // un commissaire aux comptes. C'est le seul endroit de l'application où
    // une lecture ratée fabrique un DOCUMENT qui affirme quelque chose de faux.
    //
    // La modale d'export attend déjà cette exception (`audit_export_dialog`,
    // `_errorMsg`) : tant que cette fonction avalait l'erreur, ce chemin de
    // rattrapage ne pouvait pas s'exécuter — il était écrit et inatteignable.
    throw ErreurMetier(
        "Le journal n'a pas pu être relu pour l'export : $e. "
        'Aucun fichier n’a été produit — un export vide se lirait comme une '
        'absence d’activité.');
  }

  return _hydrate(client, scope, rows);
}
