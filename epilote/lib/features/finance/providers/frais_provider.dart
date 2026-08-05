import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../structure/providers/academic_year_context.dart';

// ════════════════════════════════════════════════════════════════════════════
//  FRAIS DE SCOLARITÉ (table `fee_structures`) — LECTURE SEULE côté école.
//
//  Deux portées descendent sur le poste depuis la migration 0096 : le tarif du
//  réseau (`school_id IS NULL`, posé par le ministère pour toutes ses écoles)
//  et celui posé pour cet établissement. Dans les deux cas l'auteur est le
//  groupe — l'école reçoit et applique. 100% offline.
// ════════════════════════════════════════════════════════════════════════════

const kFeeTypes = <(String, String)>[
  ('inscription', 'Inscription'),
  ('mensualite', 'Mensualité'),
  ('frais_examens', 'Frais d\'examens'),
  ('cotisation_ape', 'Cotisation APE'),
  ('autre', 'Autre'),
];

/// D'où vient le tarif : du réseau entier, ou posé pour cet établissement.
/// Dans les deux cas c'est le GROUPE qui l'a écrit — l'école ne fait que lire.
enum BaremeScope { reseau, etablissement }

String feeTypeLabel(String? t) =>
    kFeeTypes.firstWhere((e) => e.$1 == t, orElse: () => ('autre', 'Autre')).$2;

class FeeStructure {
  const FeeStructure({
    required this.id,
    required this.name,
    required this.feeType,
    required this.amount,
    required this.dueDay,
    required this.levelId,
    required this.levelName,
    required this.scope,
    required this.sourceReference,
  });
  final String id, name, feeType;
  final int amount;
  final int? dueDay;
  final String? levelId, levelName, sourceReference;
  final BaremeScope scope;
}

final feeStructuresProvider =
    StreamProvider.autoDispose<List<FeeStructure>>((ref) {
  ref.keepAlive();
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final schoolId = profile?.schoolId;
  final groupId = profile?.groupId;
  final yearId = ref.watch(activeYearIdProvider);
  if (schoolId == null || schoolId.isEmpty || groupId == null) {
    return Stream.value(const []);
  }
  return db.watch(
    '''
    SELECT f.*, sl.name AS level_name
    FROM fee_structures f
    LEFT JOIN school_levels sl ON sl.id = f.applies_to_level_id
    -- ⚠️ `f.school_id = ?` SEUL rendrait invisible tout tarif du ministère :
    -- depuis la migration 0096, un barème de portée réseau porte `school_id`
    -- NULL. C'est le même piège que dans les sync-rules, une couche plus haut.
    -- ⚠️ `is_active = 1` rate les lignes écrites par l'application : la vue
    -- PowerSync ne garantit pas l'entier 1. COALESCE(...) <> 0 est la forme
    -- sûre (cf. [[powersync-is-active-egalite-stricte]]).
    WHERE f.group_id = ? AND (f.school_id = ? OR f.school_id IS NULL)
      AND f.academic_year_id = ?
      AND COALESCE(f.is_active, 1) <> 0
    ORDER BY f.fee_type, f.school_id IS NULL, f.amount_xaf DESC
    ''',
    parameters: [groupId, schoolId, yearId ?? ''],
  ).map((rows) => [
        for (final r in rows)
          FeeStructure(
            id: r['id'] as String,
            name: (r['name'] as String?) ?? '—',
            feeType: (r['fee_type'] as String?) ?? 'autre',
            amount: (r['amount_xaf'] as num?)?.round() ?? 0,
            dueDay: (r['due_day_of_month'] as num?)?.round(),
            levelId: r['applies_to_level_id'] as String?,
            levelName: r['level_name'] as String?,
            scope: (r['school_id'] as String?) == null
                ? BaremeScope.reseau
                : BaremeScope.etablissement,
            sourceReference: r['source_reference'] as String?,
          ),
      ]);
});

// ─── Aucune mutation ici, et c'est volontaire ────────────────────────────────
//
// Un barème est un ACTE DU GROUPE (migration 0096, décision D2). L'école le
// reçoit et l'applique. `saveFeeStructure` et `deleteFeeStructure` ont été
// retirées le 5 août 2026 : tant qu'elles existaient, il n'y avait aucun tarif
// de référence, donc aucun moyen de constater une surfacturation, et « combien
// coûte l'inscription en 6e » avait mille réponses.
//
// La RLS refuserait de toute façon l'écriture — mais un refus serveur (42501)
// abandonne le LOT PowerSync ENTIER, ce qui emporterait au passage le travail
// des autres modules, sans le moindre message. L'absence de bouton est la
// vraie protection ; la RLS n'est que le filet.
//
// Le seul écrivain est `features/admin_groupe/providers/admin_fees_provider`,
// en ligne, sur Supabase direct.

/// Niveaux distincts utilisés par l'école (pour le champ « niveau concerné »).
final schoolLevelOptionsProvider =
    StreamProvider.autoDispose<List<({String id, String name})>>((ref) {
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final schoolId = profile?.schoolId;
  final yearId = ref.watch(activeYearIdProvider);
  if (schoolId == null || schoolId.isEmpty) return Stream.value(const []);
  return db.watch(
    '''
    SELECT DISTINCT c.level_id AS id, COALESCE(sl.name, c.level_code) AS name,
           c.level_order AS ord
    FROM classes c
    LEFT JOIN school_levels sl ON sl.id = c.level_id
    WHERE c.school_id = ? AND c.academic_year_id = ? AND c.level_id IS NOT NULL
    ORDER BY c.level_order
    ''',
    parameters: [schoolId, yearId ?? ''],
  ).map((rows) => [
        for (final r in rows)
          (id: r['id'] as String, name: (r['name'] as String?) ?? '—'),
      ]);
});
