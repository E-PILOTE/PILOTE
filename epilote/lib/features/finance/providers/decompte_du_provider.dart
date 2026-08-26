import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../structure/providers/academic_year_context.dart';
import '../services/bareme_applicable.dart';
import '../services/obligation.dart';
import 'obligation_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE DÉCOMPTE — ce qu'un élève doit, LIGNE PAR LIGNE
//
//  ── POURQUOI UN TOTAL NE SUFFIT PAS ────────────────────────────────────────
//  `duScolarite` rend un nombre. C'est ce qu'il faut pour compter les élèves à
//  jour, et c'est inutilisable au guichet : quand un parent demande pourquoi il
//  doit 48 000 F, « 48 000 F » n'est pas une réponse. La caisse doit pouvoir
//  dire : inscription 15 000, cantine 10 000, transport 15 000, deux mois de
//  scolarité 8 000 — et, s'il y a lieu, la remise qui s'applique.
//
//  Depuis que trois choses distinctes agissent sur le montant (la fenêtre de
//  présence, les frais annexes multiples, l'exonération), un total opaque est
//  devenu indéfendable : trois élèves d'une même classe peuvent devoir trois
//  sommes différentes, toutes justes.
//
//  ⚠️ Ce fichier ne DÉCIDE de rien. Il décompose ce que `duScolarite` calcule,
//  avec les mêmes règles et les mêmes exclusions. Si les deux divergent, c'est
//  ce fichier qui a tort — verrouillé par `decompte_du_test.dart`.
// ════════════════════════════════════════════════════════════════════════════

/// Une ligne du décompte, telle qu'elle se lit sur un papier remis à la
/// famille.
///
/// [montant] est le montant AVANT exonération, mensualité déjà multipliée par
/// les mois dus. [verse] est le net encaissé SUR CETTE LIGNE — c'est ce qui
/// permet au guichet de dire « il reste 5 000 sur la cantine » plutôt qu'un
/// solde global dans lequel plus personne ne se retrouve.
typedef LigneDu = ({
  String id,
  String libelle,
  String feeType,
  int montant,
  int verse,
});

class DecompteDu {
  const DecompteDu({
    this.lignes = const [],
    this.verseLibre = 0,
    this.mois = 0,
    this.exoneration,
    this.motifExoneration,
    this.boursierDeclare = false,
  });

  final List<LigneDu> lignes;

  /// Ce qui a été encaissé SANS être rattaché à une ligne du décompte : les
  /// versements « Autre / libre », et ceux rattachés à un barème qui ne
  /// s'applique plus à cet élève (tarif retiré, changement de niveau).
  ///
  /// ⚠️ Ce montant DOIT exister. Le déduire des seules lignes applicables
  /// ferait disparaître de la caisse tout versement dont le barème a bougé —
  /// l'élève réapparaîtrait débiteur d'une somme qu'il a réellement payée.
  final int verseLibre;

  /// Mensualités dues par cet élève, d'après sa fenêtre de présence.
  final int mois;

  final int? exoneration;
  final String? motifExoneration;

  /// `students.has_scholarship` — la SITUATION de l'enfant, distincte de la
  /// décision financière (cf. migration 0109).
  final bool boursierDeclare;

  bool get vide => lignes.isEmpty;
  bool get estExonere => (exoneration ?? 0) > 0;

  /// L'élève est déclaré boursier et aucun taux n'a été saisi : il doit donc
  /// la scolarité ENTIÈRE.
  ///
  /// ⚠️ C'est au COMPTOIR que ce silence coûte le plus cher — le caissier est
  /// sur le point de réclamer le plein tarif à une famille qui a obtenu une
  /// bourse. On ne devine jamais de taux pour autant : « boursier » ne dit pas
  /// de combien, et l'inventer offrirait ou refuserait une scolarité au hasard.
  bool get boursierSansTaux => boursierDeclare && !estExonere;

  /// Le total au tarif plein.
  int get brut => lignes.fold(0, (a, l) => a + l.montant);

  /// Ce que l'exonération retire. Calculé ligne à ligne et non sur le total :
  /// seuls les frais de scolarité sont exonérables, et un pourcentage appliqué
  /// au total remettrait aussi la cantine.
  int get remise => lignes.fold(0, (a, l) => a + (l.montant - duDe(l)));

  int get net => brut - remise;

  /// Net encaissé cette année sur la SCOLARITÉ (frais d'examen exclus, comme
  /// partout ailleurs — cf. `_horsFraisExamens`).
  int get verse => lignes.fold(verseLibre, (a, l) => a + l.verse);

  int get reste => (net - verse).clamp(0, net);

  /// ⚠️ `!vide && net == 0` ne peut signifier qu'une chose : des barèmes
  /// s'appliquent et l'exonération les a tous remis (un barème à 0 F est
  /// refusé en base par `fee_structures_montant_positif`).
  EtatObligation get etat => etatObligation(
        du: net,
        verse: verse,
        exonereTotal: !vide && net == 0,
      );

  /// Ce que CETTE ligne réclame réellement, exonération déduite.
  int duDe(LigneDu l) => kFraisScolarite.contains(l.feeType)
      ? apresExoneration(l.montant, exoneration)
      : l.montant;

  /// Ce qu'il reste à encaisser sur CETTE ligne.
  ///
  /// ⚠️ Jamais négatif : un trop-versé sur la cantine ne vient pas éponger
  /// l'inscription. Le dépassement se traite au remboursement, pas par une
  /// compensation silencieuse entre deux frais.
  int resteDe(LigneDu l) {
    final du = duDe(l);
    return (du - l.verse).clamp(0, du);
  }

  /// Les lignes qu'il reste à régler — ce que le guichet propose d'encaisser.
  List<LigneDu> get lignesOuvertes =>
      [for (final l in lignes) if (resteDe(l) > 0) l];
}

/// Le décompte d'une inscription. La clé est l'inscription et non l'élève :
/// elle porte la classe (donc le niveau, donc les tarifs), l'année (donc le
/// périmètre des versements), les dates de présence et l'exonération.
///
/// ⚠️ Un FLUX, pas une lecture unique. Le décompte s'affiche à côté du bouton
/// « Nouveau paiement » : après un encaissement, une valeur figée montrerait
/// un reste dû inchangé, et le caissier réclamerait deux fois. `triggerOnTables`
/// le fait réagir aussi aux écritures sur `student_payments`, que la requête
/// d'inscription ne touche pas — sans quoi il faudrait penser à l'invalider
/// depuis chacun des écrans qui encaissent, et l'un d'eux finirait par oublier.
final decompteDuProvider =
    StreamProvider.autoDispose.family<DecompteDu, String>((ref, enrollmentId) {
  final baremes = ref.watch(baremesApplicablesProvider).valueOrNull ?? const [];
  final calendrier = ref.watch(calendrierDuProvider);
  final yearId = ref.watch(activeYearIdProvider);
  if (yearId == null || baremes.isEmpty) {
    return Stream.value(const DecompteDu());
  }

  return db
      .watch(
        'SELECT ce.student_id, ce.enrollment_date, ce.withdrawal_date, '
        '       ce.exemption_rate, ce.exemption_motif, c.level_id, '
        '       s.has_scholarship '
        '  FROM class_enrollments ce '
        '  JOIN students s ON s.id = ce.student_id '
        '  LEFT JOIN classes c ON c.id = ce.class_id '
        ' WHERE ce.id = ?',
        parameters: [enrollmentId],
        triggerOnTables: const [
          'class_enrollments',
          'student_payments',
          'fee_structures',
          'students',
        ],
      )
      .asyncMap((rows) => rows.isEmpty
          ? Future.value(const DecompteDu())
          : _composer(rows.first,
              baremes: baremes, calendrier: calendrier, yearId: yearId));
});

Future<DecompteDu> _composer(
  Map<String, dynamic> enr, {
  required List<LigneBareme> baremes,
  required CalendrierDu calendrier,
  required String yearId,
}) async {
  final mois = calendrier.moisPour(
    entree: enr['enrollment_date'] as String?,
    sortie: enr['withdrawal_date'] as String?,
    // Le reçu que la famille emporte doit compter les mêmes mois que l'écran
    // de recouvrement : l'échéance de la mensualité s'y applique aussi.
    jourEcheance:
        jourEcheanceMensualite(baremes, levelId: enr['level_id'] as String?),
  );

  // ── Ce qui a été encaissé, par barème ──────────────────────────────────────
  //
  // ⚠️ `COALESCE(fee_structure_id, '')` : un versement libre a un barème NUL,
  // et `GROUP BY` sur NULL le rangerait dans un groupe qu'aucune jointure ne
  // retrouve. La chaîne vide lui donne une clé stable, distincte de tout id.
  final verses = await db.getAll(
    "SELECT COALESCE(sp.fee_structure_id, '') AS fid, "
    '       COALESCE(SUM(MAX(sp.amount_xaf - COALESCE(sp.refunded_amount_xaf, 0), 0)), 0) AS net '
    '  FROM student_payments sp '
    ' WHERE sp.student_id = ? AND sp.academic_year_id = ? '
    "   AND sp.status IN ('confirmed', 'refunded') "
    '   AND COALESCE((SELECT f.fee_type FROM fee_structures f '
    "                  WHERE f.id = sp.fee_structure_id), '') <> 'frais_examens' "
    ' GROUP BY fid',
    [enr['student_id'], yearId],
  );
  return composerDecompte(
    baremes: baremes,
    levelId: enr['level_id'] as String?,
    verseParBareme: {
      for (final v in verses)
        (v['fid'] as String? ?? ''): (v['net'] as num?)?.round() ?? 0,
    },
    mois: mois,
    exoneration: (enr['exemption_rate'] as num?)?.round(),
    motifExoneration: enr['exemption_motif'] as String?,
    // `== 1` serait le piège habituel : la valeur arrive à 0, 1 ou NULL.
    boursierDeclare: ((enr['has_scholarship'] as num?) ?? 0) != 0,
  );
}

/// Assemble le décompte à partir de données DÉJÀ lues.
///
/// Séparé de `_composer` pour une raison précise : trois règles vivaient
/// derrière un `db.getAll` et n'étaient donc atteignables par aucun test —
/// l'ordre des lignes, le libellé de repli, et surtout le RELIQUAT. Ce sont
/// exactement celles qu'une modification ultérieure casserait sans bruit.
///
/// [verseParBareme] associe un identifiant de barème au net encaissé dessus ;
/// la clé vide y range les versements libres.
DecompteDu composerDecompte({
  required List<LigneBareme> baremes,
  required String? levelId,
  required Map<String, int> verseParBareme,
  required int mois,
  int? exoneration,
  String? motifExoneration,
  bool boursierDeclare = false,
}) {
  // Les frais d'examen relèvent du module Examens, qui seul connaît les
  // candidats. Les faire figurer ici les réclamerait à toute la classe.
  final examens = {
    for (final b in baremes)
      if (b.feeType == 'frais_examens') b.id,
  };

  final lignes = <LigneDu>[];
  var verseAffecte = 0;
  var verseTotal = 0;
  for (final e in verseParBareme.entries) {
    // ⚠️ Un versement d'examen ne doit pas non plus tomber dans le reliquat :
    // ce n'est pas l'argent de l'école, il ne solde donc aucune scolarité. La
    // requête l'écarte déjà ; on ne le refait pas par méfiance mais parce que
    // la règle doit tenir sans dépendre d'un `WHERE` situé ailleurs.
    if (examens.contains(e.key)) continue;
    verseTotal += e.value;
  }

  for (final b in baremesApplicables(baremes, levelId: levelId)) {
    if (b.feeType == 'frais_examens') continue;
    final verse = verseParBareme[b.id] ?? 0;
    verseAffecte += verse;
    lignes.add((
      id: b.id,
      libelle: b.nom.trim().isEmpty ? _libelleDefaut(b.feeType) : b.nom.trim(),
      feeType: b.feeType,
      montant: duPourBareme(
          feeType: b.feeType, montant: b.montant, moisEcoules: mois),
      verse: verse,
    ));
  }

  // L'ordre est celui dans lequel une famille lit une facture : ce qu'on paie
  // une fois d'abord, ce qui court ensuite, les services en dernier.
  lignes.sort((a, b) => _rang(a.feeType).compareTo(_rang(b.feeType)));

  return DecompteDu(
    lignes: lignes,
    // Le reliquat, et non « la somme des versements libres » : ainsi le total
    // encaissé reste EXACTEMENT celui de la caisse, quoi qu'il soit arrivé aux
    // barèmes depuis. Un tarif retiré ne fait disparaître l'argent de personne.
    verseLibre: (verseTotal - verseAffecte).clamp(0, verseTotal),
    mois: mois,
    exoneration: exoneration,
    motifExoneration: motifExoneration,
    boursierDeclare: boursierDeclare,
  );
}

/// Un barème sans intitulé ne doit pas produire une ligne vide sur un papier
/// remis à une famille. La base l'interdit depuis la migration 0108 ; les
/// lignes créées avant restent possibles.
String _libelleDefaut(String feeType) => switch (feeType) {
      'inscription' => 'Frais d\'inscription',
      'mensualite' => 'Scolarité mensuelle',
      'cotisation_ape' => 'Cotisation APE',
      'frais_examens' => 'Frais d\'examen',
      _ => 'Frais annexes',
    };

int _rang(String feeType) => switch (feeType) {
      'inscription' => 0,
      'cotisation_ape' => 1,
      'mensualite' => 2,
      _ => 3,
    };
