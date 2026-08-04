import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../structure/providers/academic_year_context.dart';
import '../services/obligation.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LES BARÈMES APPLICABLES ET CE QU'ILS RÉCLAMENT
//
//  Séparé des encaissements : ce fichier ne sait rien des paiements, il dit
//  seulement ce qu'un élève DOIT. Les deux se rencontrent dans
//  `paiements_provider.dart`, où l'état de chaque élève se calcule.
// ════════════════════════════════════════════════════════════════════════════

typedef Bareme = ({String feeType, int montant, String? levelId});

/// Barèmes actifs de l'année, école ET groupe.
///
/// ⚠️ `school_id IS NULL` est déjà pris en compte : le lot 2 fera remonter les
/// barèmes au groupe, et cette requête doit les voir sans être réécrite. Le
/// piège est le même que dans les sync-rules — une égalité stricte sur
/// `school_id` rend un barème de groupe invisible.
final baremesApplicablesProvider =
    StreamProvider.autoDispose<List<Bareme>>((ref) {
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final schoolId = profile?.schoolId;
  final yearId = ref.watch(activeYearIdProvider);
  if (schoolId == null || schoolId.isEmpty || yearId == null) {
    return Stream.value(const []);
  }
  return db.watch(
    'SELECT fee_type, amount_xaf, applies_to_level_id FROM fee_structures '
    'WHERE (school_id = ? OR school_id IS NULL) AND academic_year_id = ? '
    'AND COALESCE(is_active, 1) <> 0',
    parameters: [schoolId, yearId],
  ).map((rows) => [
        for (final r in rows)
          (
            feeType: (r['fee_type'] as String?) ?? 'autre',
            montant: (r['amount_xaf'] as num?)?.round() ?? 0,
            levelId: r['applies_to_level_id'] as String?,
          ),
      ]);
});

/// Ce qu'un élève de ce niveau doit à cette date, tous barèmes confondus.
int duPourNiveau(List<Bareme> baremes, String? levelId, int mois) {
  var total = 0;
  for (final b in baremes) {
    if (b.levelId != null && b.levelId != levelId) continue;
    total += duPourBareme(
        feeType: b.feeType, montant: b.montant, moisEcoules: mois);
  }
  return total;
}

/// Mois écoulés de l'année active — 1 si les dates manquent, pour qu'une
/// mensualité mal renseignée réclame un mois plutôt que zéro (un dû nul se
/// lirait « barème non défini », ce qui serait faux).
final moisEcoulesProvider = Provider<int>((ref) {
  final y = ref.watch(activeYearProvider);
  if (y == null) return 1;
  return moisEcoules(
      debut: y.startDate, fin: y.endDate, maintenant: DateTime.now());
});
