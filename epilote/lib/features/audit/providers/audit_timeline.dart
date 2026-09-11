import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import 'audit_data.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LA COURBE DES 30 JOURS, ET LES TROIS CLASSEMENTS QUI L'ACCOMPAGNENT
//
//  Séparée de `audit_data.dart` le 2026-09-09, le long d'une couture réelle :
//  les facettes et la page du journal répondent à « quoi filtrer » et « que
//  montrer » ; ce fichier répond à « comment l'activité s'est répartie ». Il
//  ne partage avec eux que le périmètre et les filtres.
//
//  ⚠️ C'est ici que vit le PLAFOND DE LECTURE (`kAuditTimelineMax`). Les KPI
//  du haut de page, eux, sont des `count(exact)` : ils restent exacts quelle
//  que soit la taille du journal. Seuls la courbe et les classements sont
//  bornés — et quand ils le sont, `AuditTimeline.tronquee` le dit, et l'écran
//  l'affiche. Un graphique bâti sur une fraction de la période sans le dire,
//  c'est le « zéro menteur » appliqué à une courbe.
// ════════════════════════════════════════════════════════════════════════════

// ─── Provider : timeline 30 jours ────────────────────────────────────────────
final auditTimelineProvider =
    FutureProvider.autoDispose<AuditTimeline>((ref) async {
  ref.keepAlive();
  ref.watch(auditRealtimeProvider);
  final client = ref.watch(supabaseClientProvider);
  final scope = ref.watch(auditScopeProvider);
  if (scope == null) return AuditTimeline.empty;

  final now = DateTime.now();
  final cutoff = DateTime(now.year, now.month, now.day)
      .subtract(const Duration(days: 29))
      .toUtc();

  try {
    final base = applyScopeFloor(
        client.from('audit_logs').select(
            'action, created_at, user_id, user_role, table_name, school_id'),
        scope);
    final res = await base
        .gte('created_at', cutoff.toIso8601String())
        // ⚠️ L'ordre est ASCENDANT : quand la fenêtre dépasse le plafond, ce
        // sont les jours les plus RÉCENTS qui manquent — ceux qu'on regarde.
        // On lit donc du plus récent au plus ancien, puis on remet dans
        // l'ordre : la troncature ronge alors le début de la période, et le
        // drapeau `tronquee` le dit à l'écran.
        .order('created_at', ascending: false)
        .limit(kAuditTimelineMax + 1) as List;
    final tronquee = res.length > kAuditTimelineMax;
    final lignes = (tronquee ? res.take(kAuditTimelineMax).toList() : res)
        .reversed
        .toList();

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

    for (final row in lignes) {
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
    var nomsIllisibles = false;
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
      } catch (e) {
        // Cinq lignes nommées « Utilisateur » se lisent comme cinq personnes
        // anonymes, pas comme un nom qu'on n'a pas su lire.
        nomsIllisibles = true;
        debugPrint('ℹ️ Journal d’audit : noms des acteurs illisibles ($e).');
      }
    }
    final topActors = topActorIds.map((id) {
      final info = actorCount[id]!;
      return AuditTopActor(
        userId: id,
        name: userNames[id] ??
            (nomsIllisibles ? kNomNonResolu : kCompteIntrouvable),
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
      tronquee: tronquee,
    );
  } catch (_) {
    return AuditTimeline.empty;
  }
});

String _dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
