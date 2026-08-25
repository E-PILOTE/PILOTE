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
  // ── Le niveau NATIONAL se traduit ici, en SQL ──────────────────────────────
  //
  // Depuis la migration 0101, le ministère tarifie « la 6e » pour tout le
  // réseau via `applies_to_education_level_id` (référentiel partagé). Le poste,
  // lui, raisonne en niveaux DE SON ÉCOLE. La jointure fait la conversion là où
  // la correspondance vit — `school_levels.education_level_id` — et le
  // résolveur en aval continue de ne connaître qu'un `levelId`. Rien à changer
  // dans `baremesApplicables`, ni chez ses appelants.
  //
  // ⚠️ `AND sl.id IS NOT NULL` n'est PAS décoratif : sans lui, un tarif visant
  // un niveau que cette école n'a pas ressortirait avec `level_id` NULL —
  // c'est-à-dire déguisé en « tous niveaux », et il serait réclamé à TOUS les
  // élèves. Le tarif de la 6e tomberait sur les terminales.
  return db.watch(
    '''
    SELECT f.id,
           f.fee_type,
           -- L'intitulé fait partie de l'IDENTITÉ d'un frais annexe depuis la
           -- migration 0108 : sans lui, la cantine et le bus se disputeraient
           -- la même place et l'un des deux ne serait jamais réclamé.
           f.name,
           f.amount_xaf,
           f.school_id,
           COALESCE(f.applies_to_level_id, sl.id) AS level_id
      FROM fee_structures f
      LEFT JOIN school_levels sl
             ON sl.education_level_id = f.applies_to_education_level_id
            AND sl.school_id = ?
            AND COALESCE(sl.is_active, 1) <> 0
     WHERE f.group_id = ?
       AND (f.school_id = ? OR f.school_id IS NULL)
       AND f.academic_year_id = ?
       AND COALESCE(f.is_active, 1) <> 0
       AND (f.applies_to_education_level_id IS NULL OR sl.id IS NOT NULL)
    ''',
    parameters: [schoolId, groupId, schoolId, yearId],
  ).map((rows) => [
        for (final r in rows)
          (
            id: r['id'] as String,
            feeType: (r['fee_type'] as String?) ?? kFeeTypeAnnexe,
            nom: (r['name'] as String?) ?? '',
            montant: (r['amount_xaf'] as num?)?.round() ?? 0,
            schoolId: r['school_id'] as String?,
            levelId: r['level_id'] as String?,
          ),
      ]);
});

/// Ce qu'un élève doit AU TITRE DE SA SCOLARITÉ, à cette date.
///
/// [levelId] choisit les barèmes ; [mois] est le nombre de mensualités dues par
/// CET élève — cf. [CalendrierDu.moisPour]. Les deux élèves d'une même classe
/// peuvent donc devoir des sommes différentes, et c'est voulu : l'un est là
/// depuis la rentrée, l'autre est arrivé en mars.
///
/// ⚠️ Passe d'abord par `baremesApplicables` : depuis que les deux portées
/// cohabitent, un même frais peut apparaître jusqu'à quatre fois (réseau,
/// école, niveau, école+niveau). Les additionner ferait payer l'élève quatre
/// fois — on ne retient que la ligne la plus proche de lui.
///
/// ── Pourquoi les FRAIS D'EXAMEN sont exclus ─────────────────────────────────
///
/// Les barèmes se choisissent par NIVEAU, donc par classe. Or un frais d'examen
/// n'est dû que par les CANDIDATS, et la candidature est individuelle
/// (`exam_candidates`). Tant que le barème se dérive du niveau, Finance ne peut
/// pas savoir qui se présente — et prétendre le savoir est exactement ce qui
/// produisait l'erreur : un barème
/// « frais d'examens » de portée réseau, sans niveau visé, entrait dans le dû
/// de CHAQUE élève. Mesuré le 13/08/2026 sur le METP : 1 775 élèves × 30 000 F
/// de dette fictive, dont des élèves de 6e pour un baccalauréat.
///
/// Le module Examens est l'autorité sur ces frais : il connaît les candidats et
/// résout le barème par l'examen visé (`examFeesProvider`, migration 0103).
///
/// ⚠️ La contrepartie est OBLIGATOIRE : les versements rattachés à un frais
/// d'examen doivent sortir du « versé » de la même vue. Sinon un candidat ayant
/// réglé ses frais d'examen paraîtrait à jour d'une scolarité impayée. Cf.
/// `paiements_provider` (`_horsFraisExamens`).
///
/// ── L'exonération (migration 0109) ──────────────────────────────────────────
///
/// [exoneration] est le taux accordé à CET élève pour CETTE année, en %.
/// Il ne s'applique qu'aux frais de scolarité (`kFraisScolarite`) : ni aux
/// frais d'examen, déjà exclus, ni aux frais annexes — cf. la doc de la
/// constante pour la raison.
int duScolarite(
  List<LigneBareme> visibles, {
  required String? levelId,
  required int mois,
  int? exoneration,
}) {
  var total = 0;
  for (final b in baremesApplicables(visibles, levelId: levelId)) {
    if (b.feeType == 'frais_examens') continue;
    final du = duPourBareme(
        feeType: b.feeType, montant: b.montant, moisEcoules: mois);
    total += kFraisScolarite.contains(b.feeType)
        ? apresExoneration(du, exoneration)
        : du;
  }
  return total;
}

/// La situation d'UN élève vis-à-vis du recouvrement.
///
/// [du] est ce qu'il doit après remise, [duBrut] le même montant sans la
/// remise ; [aJour] dit s'il compte parmi les élèves en règle — ce qui inclut
/// l'exonéré total.
typedef RecouvrementEleve = ({
  int du,
  int duBrut,
  EtatObligation etat,
  bool aJour,
});

/// Décide, pour un élève, ce qu'il doit et s'il est en règle.
///
/// ⚠️ Extrait de `paymentsOverviewProvider`, où cette décision était enfouie
/// dans une boucle sur un `db.getAll` — donc hors de portée de tout test, alors
/// qu'elle produit le TAUX DE RECOUVREMENT lu par l'école et par le ministère.
/// Deux règles y tiennent, et aucune n'est évidente :
///
/// - le dû se calcule DEUX fois, avant et après remise. Sans le brut, un
///   exonéré à 100 % et un élève dont l'école n'a posé aucun tarif rendent le
///   même zéro, et l'écran réclame un barème qui existe.
/// - l'exonéré total COMPTE parmi les élèves à jour : il n'a rien à régler.
///   L'exclure ferait baisser le taux de chaque école qui accueille des
///   boursiers — pénalisée dans les statistiques du réseau pour avoir accordé
///   des bourses, et incapable d'atteindre 100 %.
RecouvrementEleve recouvrementEleve(
  List<LigneBareme> visibles, {
  required String? levelId,
  required int mois,
  required int verse,
  int? exoneration,
}) {
  final brut = duScolarite(visibles, levelId: levelId, mois: mois);
  final du = duScolarite(visibles,
      levelId: levelId, mois: mois, exoneration: exoneration);
  final etat =
      etatObligation(du: du, verse: verse, exonereTotal: brut > 0 && du <= 0);
  return (
    du: du,
    duBrut: brut,
    etat: etat,
    aJour: etat == EtatObligation.aJour || etat == EtatObligation.exonere,
  );
}

/// Le calendrier de l'année active, capable de dire combien de mensualités
/// CHAQUE élève doit selon sa fenêtre de présence.
///
/// ⚠️ C'est un objet et non un `int` parce que le nombre de mois n'est PLUS le
/// même pour tous les élèves d'une classe. Un compteur unique — ce qu'était
/// `moisEcoulesProvider` — réclamait l'année entière à un élève arrivé en mars
/// et faisait grossir la dette d'un élève parti en décembre (cf. [moisDus]).
class CalendrierDu {
  const CalendrierDu({required this.debut, required this.fin});

  /// Aucune année résolue : on ne sait pas compter les mois.
  const CalendrierDu.indetermine() : debut = null, fin = null;

  final DateTime? debut, fin;

  /// [entree] et [sortie] arrivent telles que SQLite les rend : `YYYY-MM-DD`,
  /// ou nulles. Une date illisible est traitée comme absente — mieux vaut le
  /// dû de l'année entière qu'un plantage au guichet.
  int moisPour({String? entree, String? sortie}) {
    final d = debut, f = fin;
    // Dates d'année manquantes : un mois plutôt que zéro, pour qu'une
    // mensualité mal renseignée réclame quelque chose (un dû nul se lirait
    // « barème non défini », ce qui serait faux).
    if (d == null || f == null) return 1;
    return moisDus(
      debutAnnee: d,
      finAnnee: f,
      maintenant: DateTime.now(),
      entree: DateTime.tryParse(entree ?? ''),
      sortie: DateTime.tryParse(sortie ?? ''),
    );
  }
}

final calendrierDuProvider = Provider<CalendrierDu>((ref) {
  final y = ref.watch(activeYearProvider);
  if (y == null) return const CalendrierDu.indetermine();
  return CalendrierDu(debut: y.startDate, fin: y.endDate);
});
