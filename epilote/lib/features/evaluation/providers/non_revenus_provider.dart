// ════════════════════════════════════════════════════════════════════════════
//  LES ÉLÈVES QUI NE SONT PAS REVENUS
//
//  ── LE TROU ────────────────────────────────────────────────────────────────
//  Le conseil de juin décide qu'un enfant passe. Le secrétariat réinscrit en
//  septembre. Et pour ceux dont la famille ne revient jamais, il ne se passe
//  RIEN : leur inscription de l'an dernier reste `active`. Ni sortis, ni
//  présents. La plateforme les compte encore dans un effectif où ils ne sont
//  plus, et la déperdition scolaire — le chiffre qu'un ministère publie —
//  reste invisible.
//
//  La migration 0082 a créé le motif `non_reinscrit`. Elle n'a rien créé qui
//  le DÉTECTE : c'est l'objet de ce fichier.
//
//  ── LE GARDE-FOU QUI COMPTE PLUS QUE LE RESTE ──────────────────────────────
//  Tant que la rentrée n'est pas saisie, AUCUN élève n'a d'inscription dans
//  l'année en cours — et la requête les déclarerait TOUS non revenus. Une
//  école de 400 élèves verrait 400 alertes le jour où elle ouvre son année.
//  D'où `reinscritsCetteAnnee` : au-dessous d'un seuil de saisie, l'écran se
//  tait et dit pourquoi. Une liste fausse ne se rattrape pas — on ne la croit
//  plus jamais.
//
//  ── OFFLINE-FIRST ──────────────────────────────────────────────────────────
//  Espace école : `db.getAll` / `db.execute` UNIQUEMENT. Un secrétariat de
//  rentrée travaille souvent sans réseau.
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/powersync/powersync_service.dart';

/// Un élève attendu qui n'est pas là.
class EleveNonRevenu {
  const EleveNonRevenu({
    required this.enrollmentId,
    required this.studentId,
    required this.firstName,
    required this.lastName,
    required this.className,
    this.ine,
    this.matricule,
    this.gender,
    this.decision,
    this.targetClassName,
    this.tutorPhone,
  });

  final String enrollmentId, studentId, firstName, lastName, className;
  final String? ine, matricule, gender, decision, targetClassName, tutorPhone;

  String get fullName => '${lastName.toUpperCase()} $firstName'.trim();

  /// Ce que le conseil avait décidé pour lui. Un enfant déclaré « passe » et
  /// jamais revenu n'est pas la même histoire qu'un redoublant découragé : la
  /// première dit qu'on a perdu un élève qui réussissait.
  String get decisionLabel => switch (decision) {
        'passe'     => 'Devait passer',
        'redouble'  => 'Devait redoubler',
        'reoriente' => 'Devait être réorienté',
        _           => 'Aucune décision',
      };
}

// ── Pourquoi on ne résout PAS « l'année précédente » par son identifiant ────
// `academic_years.school_id` est NULL sur les données réelles : les années
// sont portées par le GROUPE, pas par l'école. Selon les groupes, plusieurs
// lignes peuvent partager la même période. Choisir « la ligne dont la date de
// début précède » et comparer sur cet identifiant, c'est risquer de désigner
// une année à laquelle aucune inscription ne se rattache — et déclarer alors
// TOUTE l'école disparue.
//
// On raisonne donc par ÉLÈVE : sa dernière inscription active antérieure à
// l'année en cours, quelle que soit la ligne d'année qui la porte. C'est vrai
// quel que soit le découpage retenu par le groupe.
const String _sqlDerniereInscription = '''
  WITH courante AS (SELECT start_date FROM academic_years WHERE id = ?1),
  derniere AS (
    SELECT e.id AS enrollment_id, e.student_id, e.class_id,
           e.promotion_decision, e.promotion_target_class_id,
           ay.label AS year_label,
           ROW_NUMBER() OVER (PARTITION BY e.student_id
                              ORDER BY ay.start_date DESC) AS rang
      FROM class_enrollments e
      JOIN academic_years ay ON ay.id = e.academic_year_id
     WHERE e.status = 'active'
       AND e.academic_year_id <> ?1
       AND ay.start_date < (SELECT start_date FROM courante)
  )
''';

/// L'état de la rentrée : de quoi décider si la liste veut dire quelque chose.
class BilanRentree {
  const BilanRentree({
    required this.aUnPasse,
    required this.labelPrecedent,
    required this.effectifPrecedent,
    required this.reinscritsCetteAnnee,
    required this.eleves,
  });

  /// L'établissement a une année antérieure à laquelle comparer. Faux la
  /// toute première année : personne ne peut alors manquer à l'appel.
  final bool aUnPasse;

  /// Libellé de la dernière année où ces élèves étaient inscrits.
  final String? labelPrecedent;

  /// Effectif encore `active` sur l'année précédente.
  final int effectifPrecedent;

  /// Élèves de l'an dernier ayant déjà une inscription cette année.
  final int reinscritsCetteAnnee;

  final List<EleveNonRevenu> eleves;

  static const vide = BilanRentree(
    aUnPasse: false,
    labelPrecedent: null,
    effectifPrecedent: 0,
    reinscritsCetteAnnee: 0,
    eleves: [],
  );

  /// Part de l'effectif précédent déjà traitée. En dessous de 30 %, la rentrée
  /// n'est manifestement pas saisie : la liste n'est pas exploitable.
  double get avancement =>
      effectifPrecedent == 0 ? 0 : reinscritsCetteAnnee / effectifPrecedent;

  bool get rentreeSaisie => effectifPrecedent > 0 && avancement >= 0.30;

  /// Taux de non-retour, à ne lire QUE si la rentrée est saisie.
  double get tauxNonRetour =>
      effectifPrecedent == 0 ? 0 : eleves.length / effectifPrecedent;
}

/// Les élèves de l'an dernier sans inscription cette année.
final nonRevenusProvider = FutureProvider.autoDispose
    .family<BilanRentree, String>((ref, yearId) async {
  ref.keepAlive();

  // Effectif de référence : les élèves encore `active` sur leur dernière année
  // antérieure. Un transféré, un diplômé, un sorti portent déjà leur statut —
  // ils ne sont pas « non revenus », ils sont partis, et on sait pourquoi.
  final compte = await db.getAll(
    '''
    $_sqlDerniereInscription
    SELECT COUNT(*) AS effectif,
           SUM(CASE WHEN EXISTS (
                 SELECT 1 FROM class_enrollments n
                  WHERE n.student_id = d.student_id
                    AND n.academic_year_id = ?1) THEN 1 ELSE 0 END) AS revenus,
           MAX(d.year_label) AS label
      FROM derniere d
     WHERE d.rang = 1
    ''',
    [yearId],
  );
  final effectif = (compte.first['effectif'] as int?) ?? 0;
  final revenus  = (compte.first['revenus'] as int?) ?? 0;
  final label    = compte.first['label'] as String?;
  if (effectif == 0) return BilanRentree.vide;

  final rows = await db.getAll(
    '''
    $_sqlDerniereInscription
    SELECT d.enrollment_id,
           s.id            AS student_id,
           s.first_name, s.last_name, s.ine, s.matricule, s.gender,
           c.name          AS class_name,
           d.promotion_decision,
           tc.name         AS target_class_name,
           (SELECT t.phone_primary FROM student_tutors t
             WHERE t.student_id = s.id AND t.phone_primary IS NOT NULL
             LIMIT 1)      AS tutor_phone
      FROM derniere d
      JOIN students s  ON s.id = d.student_id
      LEFT JOIN classes c  ON c.id = d.class_id
      LEFT JOIN classes tc ON tc.id = d.promotion_target_class_id
     WHERE d.rang = 1
       AND NOT EXISTS (SELECT 1 FROM class_enrollments n
                        WHERE n.student_id = d.student_id
                          AND n.academic_year_id = ?1)
     ORDER BY c.name, s.last_name, s.first_name
    ''',
    [yearId],
  );

  return BilanRentree(
    aUnPasse: true,
    labelPrecedent: label,
    effectifPrecedent: effectif,
    reinscritsCetteAnnee: revenus,
    eleves: [
      for (final r in rows)
        EleveNonRevenu(
          enrollmentId:    r['enrollment_id'] as String,
          studentId:       r['student_id'] as String,
          firstName:       r['first_name'] as String? ?? '',
          lastName:        r['last_name'] as String? ?? '',
          className:       r['class_name'] as String? ?? '—',
          ine:             r['ine'] as String?,
          matricule:       r['matricule'] as String?,
          gender:          r['gender'] as String?,
          decision:        r['promotion_decision'] as String?,
          targetClassName: r['target_class_name'] as String?,
          tutorPhone:      r['tutor_phone'] as String?,
        ),
    ],
  );
});

/// Prononce la sortie des élèves qui ne sont pas revenus.
///
/// Le motif est `non_reinscrit` et rien d'autre : c'est une réponse HONNÊTE —
/// l'école ignore ce que l'enfant est devenu. Écrire « abandon » à sa place
/// serait inventer une cause, et fausser le seul agrégat qui compte.
/// L'agent qui SAIT (déménagement, transfert, mariage) doit passer par la
/// fiche de l'élève, où toute la nomenclature est offerte.
Future<int> prononcerNonRetour(List<String> enrollmentIds) async {
  if (enrollmentIds.isEmpty) return 0;
  final now = DateTime.now();
  final jour = now.toIso8601String().substring(0, 10);
  final horo = now.toIso8601String();
  final trous = List.filled(enrollmentIds.length, '?').join(',');

  await db.execute(
    '''
    UPDATE class_enrollments
       SET status           = 'withdrawn',
           withdrawal_motif = 'non_reinscrit',
           withdrawal_date  = COALESCE(withdrawal_date, ?),
           updated_at       = ?
     WHERE id IN ($trous) AND status = 'active'
    ''',
    [jour, horo, ...enrollmentIds],
  );
  return enrollmentIds.length;
}
