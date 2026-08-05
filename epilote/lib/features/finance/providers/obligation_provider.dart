import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../structure/providers/academic_year_context.dart';
import '../services/bareme_applicable.dart';
import '../services/obligation.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LES BARÈMES APPLICABLES ET CE QU'ILS RÉCLAMENT
//
//  Séparé des encaissements : ce fichier ne sait rien des paiements, il dit
//  seulement ce qu'un élève DOIT. Les deux se rencontrent dans
//  `paiements_provider.dart`, où l'état de chaque élève se calcule.
// ════════════════════════════════════════════════════════════════════════════

/// Barèmes visibles sur le poste : ceux du GROUPE (`school_id IS NULL`, posés
/// par le ministère pour tout le réseau) et ceux posés pour cette école.
///
/// ⚠️ Une égalité stricte sur `school_id` rendrait un barème de groupe
/// invisible — le même piège que dans les sync-rules, une couche plus haut.
/// Le `group_id` explicite évite qu'un barème d'un autre groupe, resté en base
/// après une mutation d'appareil, ne remonte
/// (cf. `[[licence-coffre-appareil-cross-groupe]]`).
final baremesApplicablesProvider =
    StreamProvider.autoDispose<List<LigneBareme>>((ref) {
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final schoolId = profile?.schoolId;
  final groupId = profile?.groupId;
  final yearId = ref.watch(activeYearIdProvider);
  if (schoolId == null || schoolId.isEmpty || groupId == null || yearId == null) {
    return Stream.value(const []);
  }
  return db.watch(
    'SELECT id, fee_type, amount_xaf, school_id, applies_to_level_id '
    'FROM fee_structures '
    'WHERE group_id = ? AND (school_id = ? OR school_id IS NULL) '
    'AND academic_year_id = ? AND COALESCE(is_active, 1) <> 0',
    parameters: [groupId, schoolId, yearId],
  ).map((rows) => [
        for (final r in rows)
          (
            id: r['id'] as String,
            feeType: (r['fee_type'] as String?) ?? 'autre',
            montant: (r['amount_xaf'] as num?)?.round() ?? 0,
            schoolId: r['school_id'] as String?,
            levelId: r['applies_to_level_id'] as String?,
          ),
      ]);
});

/// Ce qu'un élève de ce niveau doit à cette date.
///
/// ⚠️ Passe d'abord par `baremesApplicables` : depuis que les deux portées
/// cohabitent, un même frais peut apparaître jusqu'à quatre fois (réseau,
/// école, niveau, école+niveau). Les additionner ferait payer l'élève quatre
/// fois — on ne retient que la ligne la plus proche de lui.
int duPourNiveau(List<LigneBareme> visibles, String? levelId, int mois) {
  var total = 0;
  for (final b in baremesApplicables(visibles, levelId: levelId)) {
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
