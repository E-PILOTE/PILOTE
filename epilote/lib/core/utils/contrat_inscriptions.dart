// ════════════════════════════════════════════════════════════════════════════
//  LE CONTRAT DE `class_enrollments` — ÉCRIT UNE FOIS, POUR CINQ ÉCRIVAINS
//
//  C'est la table la plus lue de la plateforme : tout l'espace école y entre.
//  CINQ fichiers y écrivent, NEUF domaines la lisent. Chaque écrivain doit
//  donc tenir le contrat de tous les lecteurs — et ce contrat n'était écrit
//  nulle part. Les trois clauses ci-dessous ont chacune été trouvée rompue au
//  moins une fois pendant l'analyse de septembre 2026.
//
//  Les écrivains (`grep "UPDATE class_enrollments\|INSERT INTO class_enrollments"`) :
//    classes/providers/class_provider.dart            inscription, sortie, réaffectation
//    evaluation/providers/passage_provider.dart       verdict annuel
//    evaluation/providers/cloture_examen_provider.dart clôture d'année, sortie diplômée
//    evaluation/providers/non_revenus_provider.dart   élèves non revenus
//    vie_scolaire/providers/discipline_provider.dart  exclusion définitive
//
//  ── CONTRAT 1 — L'EFFECTIF, C'EST DEUX CONDITIONS, PAS UNE ────────────────
//  Un élève compte dans l'effectif si `class_enrollments.status = 'active'`
//  ET `students.is_active <> 0`.
//
//  `status` seul ne suffit PAS : `deactivateStudent` retire un élève du
//  registre sans toucher à son inscription. Compter sur `status` seul laisse
//  l'école se déclarer plus nombreuse qu'elle n'est — et les dotations
//  publiques suivent l'effectif déclaré.
//
//  Utiliser [effectifActif] partout où le nombre est un EFFECTIF (un état
//  signé, une déclaration, une facturation). Les lectures qui répondent à
//  « qui est inscrit dans cette classe » — saisir une note, ouvrir un
//  bulletin — n'ont pas cette exigence : elles ne déclarent rien.
//
//  ── CONTRAT 2 — TOUTE SORTIE PORTE SON MOTIF ──────────────────────────────
//  Poser un statut de [kStatutsDeSortie] SANS écrire `withdrawal_motif` dans
//  la même instruction fait disparaître la sortie de `v_sorties_par_motif` —
//  la statistique nationale de déperdition scolaire.
//
//  ⚠️ `graduated` EST une sortie. La vue le compte comme les deux autres. La
//  clôture d'année posait `graduated` sans motif : une promotion entière de
//  Terminale serait tombée dans le seau `NULL`, à côté des abandons
//  inexpliqués. Corrigé le 2026-09-10 (`fin_de_scolarite`).
//
//  Le motif appartient à `core/utils/sortie_motif.dart`, fermé par la
//  contrainte `class_enrollments_withdrawal_motif_check` (migration 0082).
//
//  ── CONTRAT 3 — L'EXONÉRATION S'APPLIQUE LIGNE À LIGNE ────────────────────
//  `exemption_rate` est un taux sur les FRAIS DE SCOLARITÉ, pas une remise
//  sur le total dû. L'appliquer au total exonérerait aussi la cantine, le
//  transport et les frais annexes — que l'école a réellement engagés.
//  L'autorité est `duScolarite` (`finance/providers/obligation_provider.dart`),
//  qui n'applique `apresExoneration` qu'aux lignes de `kFraisScolarite`.
//
//  Tenu par `test/contrat_des_inscriptions_test.dart`.
// ════════════════════════════════════════════════════════════════════════════

/// Les six valeurs de l'énumération serveur `enrollment_status`.
const Set<String> kStatutsInscription = {
  'pending_validation',
  'active',
  'rejected',
  'transferred',
  'withdrawn',
  'graduated',
};

/// Les trois statuts qui font SORTIR de l'effectif — et que
/// `v_sorties_par_motif` compte ensemble. Chacun exige un `withdrawal_motif`.
const Set<String> kStatutsDeSortie = {
  'transferred',
  'withdrawn',
  'graduated',
};

/// Ce statut fait-il sortir l'élève de l'effectif ?
bool estUneSortie(String? status) =>
    status != null && kStatutsDeSortie.contains(status);

/// La clause SQL de l'EFFECTIF — les deux conditions, jamais une seule.
///
/// [inscription] et [eleve] sont les alias de la requête appelante ; chaque
/// module nomme ses tables à sa façon, seule la règle est commune.
///
/// ```dart
/// 'WHERE ${effectifActif()} AND ce.class_id = ?'
/// 'WHERE ${effectifActif(inscription: "e", eleve: "st")} AND ...'
/// ```
String effectifActif({String inscription = 'ce', String eleve = 's'}) =>
    "$inscription.status = 'active' "
    'AND COALESCE($eleve.is_active, 1) <> 0';
