// ════════════════════════════════════════════════════════════════════════════
//  LES MOTS DE LA SCOLARITÉ — un code de base, une phrase en français
//
//  ── POURQUOI CE FICHIER ────────────────────────────────────────────────────
//  ⚠️ Le défaut que ces tables corrigent est ancien et documenté : le CODE BRUT
//  s'affichait à l'écran. Le secrétariat lisait « monoparentale_pere » dans le
//  dossier d'un élève, « ajourne » sur un résultat d'examen, « withdrawn » sur
//  une inscription — à l'endroit même où il vérifie une situation avant
//  d'appeler une famille. `models/eleve_libelles.dart` avait réglé le cas de
//  la situation familiale ; les autres codes sont restés.
//
//  La fiche élève montre onze registres à la fois. Sans un point unique, elle
//  aurait recopié onze tables de correspondance — et la douzième aurait été
//  écrite à la main, en oubliant un cas.
//
//  ── LES VALEURS SONT CELLES DE LA BASE, RELEVÉES ───────────────────────────
//  ⚠️ Chaque table ci-dessous a été établie sur les valeurs RÉELLEMENT
//  présentes en production (relevé du 2026-09-10), et non sur ce qu'un schéma
//  laissait supposer. Le repli `_ =>` rend le code tel quel : un code inconnu
//  qui s'affiche est un signal ; un code inconnu remplacé par « — » est une
//  information perdue.
// ════════════════════════════════════════════════════════════════════════════

/// `class_enrollments.status`.
String enrollmentStatutLabel(String? s) => switch (s) {
      'active' => 'Validée',
      'pending_validation' => 'En attente de validation',
      'rejected' => 'Rejetée',
      'withdrawn' => 'Retirée',
      'transferred' => 'Transférée',
      'graduated' => 'Diplômée',
      null || '' => '—',
      _ => s,
    };

/// `class_enrollments.inscription_type`.
String inscriptionTypeLabel(String? t) => switch (t) {
      'new' => 'Nouvelle',
      'reinscription' => 'Réinscription',
      'transfer' => 'Transfert',
      null || '' => '—',
      _ => t,
    };

/// `class_enrollments.promotion_decision` — le verdict de fin d'année.
///
/// Ne pas confondre avec [distinctionConseilLabel] : l'un dit si l'enfant
/// monte de classe, l'autre ce que le conseil a écrit sur un trimestre. Les
/// deux vivent dans des colonnes différentes, gardées par `core/utils/decisions.dart`.
String verdictPassageLabel(String? v) => switch (v) {
      'passe' => 'Admis en classe supérieure',
      'redouble' => 'Redouble',
      'reoriente' => 'Réorienté',
      null || '' => '—',
      _ => v,
    };

/// `bulletins.decision` — la distinction du conseil de classe.
String distinctionConseilLabel(String? d) => switch (d) {
      'felicitations' => 'Félicitations',
      'encouragements' => 'Encouragements',
      'tableau_honneur' => "Tableau d'honneur",
      'avertissement_travail' => 'Avertissement · travail',
      'avertissement_conduite' => 'Avertissement · conduite',
      'blame' => 'Blâme',
      null || '' => '',
      _ => d,
    };

/// `bulletins.status`.
String bulletinStatutLabel(String? s) => switch (s) {
      'draft' => 'Brouillon',
      'submitted' => 'Soumis',
      'validated' => 'Validé',
      'published' => 'Publié',
      null || '' => '—',
      _ => s,
    };

/// `attendance_entries.status`.
String presenceStatutLabel(String? s) => switch (s) {
      'present' => 'Présent',
      'absent' => 'Absent',
      'late' => 'En retard',
      'excused' => 'Absence excusée',
      null || '' => '—',
      _ => s,
    };

/// `student_payments.status`.
String paiementStatutLabel(String? s) => switch (s) {
      'confirmed' => 'Confirmé',
      'pending' => 'En attente',
      'cancelled' => 'Annulé',
      'refunded' => 'Remboursé',
      null || '' => '—',
      _ => s,
    };

/// `issued_documents.document_type` — les actes que l'école DÉLIVRE.
///
/// À ne pas confondre avec `student_documents.document_type`, qui désigne les
/// pièces que la famille DÉPOSE (`docTypeLabel`, côté élèves).
String documentDelivreLabel(String? t) => switch (t) {
      'certificat_scolarite' => 'Certificat de scolarité',
      'carte_scolaire' => 'Carte scolaire',
      'attestation_travail' => 'Attestation de travail',
      'attestation_reussite' => 'Attestation de réussite',
      'bulletin' => 'Bulletin',
      'releve_notes' => 'Relevé de notes',
      null || '' => '—',
      _ => t,
    };

/// `exam_candidates.dossier_status`.
String examDossierLabel(String? s) => switch (s) {
      'valide' => 'Validé',
      'complet' => 'Complet',
      'depose' => 'Déposé',
      'incomplet' => 'Incomplet',
      null || '' => '—',
      _ => s,
    };

/// `exam_candidates.result`.
String examResultatLabel(String? r) => switch (r) {
      'admis' => 'Admis',
      'ajourne' => 'Ajourné',
      'absent' => 'Absent',
      'en_attente' => 'Résultat en attente',
      null || '' => '—',
      _ => r,
    };

/// `internships.status`.
String stageStatutLabel(String? s) => switch (s) {
      'prevu' => 'Prévu',
      'en_cours' => 'En cours',
      'termine' => 'Terminé',
      'valide' => 'Validé',
      'interrompu' => 'Interrompu',
      null || '' => '—',
      _ => s,
    };

/// `student_transfers.status`.
String transfertStatutLabel(String? s) => switch (s) {
      'pending' => 'En attente',
      'approved' => 'Approuvé',
      'completed' => 'Effectué',
      'rejected' => 'Refusé',
      'cancelled' => 'Annulé',
      null || '' => '—',
      _ => s,
    };

/// `canteen_records.meal_type`.
String repasLabel(String? t) => switch (t) {
      'dejeuner' => 'Déjeuner',
      'petit_dejeuner' => 'Petit-déjeuner',
      'gouter' => 'Goûter',
      'diner' => 'Dîner',
      null || '' => '—',
      _ => t,
    };
