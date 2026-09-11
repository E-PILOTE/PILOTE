import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/powersync/powersync_service.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE PARCOURS D'UN ÉLÈVE — toutes ses années, pas seulement celle en cours
//
//  ── CE QUE LA FICHE MONTRAIT, ET CE QUI MANQUAIT ───────────────────────────
//  Le tiroir de la liste montre l'inscription de l'ANNÉE ACTIVE. C'est ce
//  qu'il faut pour le geste de tous les jours — quelle classe, quel numéro
//  j'appelle. Ce n'est pas ce qu'il faut quand on instruit un dossier :
//  « cet enfant a-t-il déjà redoublé ? », « d'où vient-il ? », « pourquoi
//  a-t-il quitté l'école en mars ? ». Ces trois questions se répondent
//  toutes dans `class_enrollments`, et aucune n'était lisible nulle part.
//
//  ── POURQUOI TOUT LIRE, ET NON L'ANNÉE COURANTE ────────────────────────────
//  ⚠️ Une scolarité fait au plus une douzaine de lignes. Filtrer sur l'année
//  coûterait le seul renseignement que cette table porte et qu'aucune autre ne
//  reconstruit : la SUITE. Un redoublement se voit en comparant deux lignes,
//  pas en lisant l'une d'elles.
//
//  ── OFFLINE, COMME TOUT L'ESPACE SCOLAIRE ──────────────────────────────────
//  ⚠️ `db.watch` / `db.getAll` — JAMAIS `supabase.from()`. Le personnel
//  scolaire travaille sur la base locale ; c'est la règle centrale du projet,
//  et les tables lues ici sont toutes déclarées dans `powersync_schema.dart`
//  et servies par les sync-rules.
// ════════════════════════════════════════════════════════════════════════════

DateTime? _d(Object? v) =>
    (v is String && v.isNotEmpty) ? DateTime.tryParse(v) : null;

String _s(Object? v) => (v as String?)?.trim() ?? '';

bool _b(Object? v) => v == 1 || v == true;

double? _n(Object? v) => v is num ? v.toDouble() : double.tryParse('$v');

/// Une année de scolarité, telle qu'elle se lit sur un parcours.
class ParcoursAnnee {
  const ParcoursAnnee({
    required this.enrollmentId,
    required this.anneeLabel,
    required this.anneeDebut,
    required this.classe,
    required this.cycleCode,
    required this.niveauCode,
    required this.filiere,
    required this.statut,
    required this.type,
    required this.dateInscription,
    required this.redoublant,
    required this.ecolePrecedente,
    required this.classePrecedente,
    required this.motifTransfert,
    required this.dateRetrait,
    required this.motifRetrait,
    required this.motifRejet,
    required this.verdict,
    required this.moyenneAnnuelle,
    required this.tauxExoneration,
    required this.motifExoneration,
    required this.notes,
  });

  final String enrollmentId;
  final String anneeLabel;
  final DateTime? anneeDebut;
  final String classe, cycleCode, niveauCode, filiere;
  final String statut, type;
  final DateTime? dateInscription;
  final bool redoublant;
  final String ecolePrecedente, classePrecedente, motifTransfert;
  final DateTime? dateRetrait;
  final String motifRetrait, motifRejet;

  /// `promotion_decision` — le verdict de fin d'année, s'il a été rendu.
  final String verdict;
  final double? moyenneAnnuelle;

  final int? tauxExoneration;
  final String motifExoneration, notes;

  /// L'année est-elle allée à son terme ?
  ///
  /// ⚠️ Sert à colorer la ligne, pas à juger l'élève : une inscription
  /// « retirée » peut l'être pour un déménagement.
  bool get interrompue =>
      statut == 'withdrawn' || statut == 'transferred' || dateRetrait != null;
}

/// Le parcours complet, de la plus récente année à la plus ancienne.
///
/// La table est petite par élève (une ligne par année), et l'ordre décroissant
/// met en tête ce que l'agent regarde en premier : là où l'enfant en est.
final ficheParcoursProvider = StreamProvider.autoDispose
    .family<List<ParcoursAnnee>, String>((ref, studentId) {
  return db.watch(
    '''
    SELECT ce.id, ce.status, ce.inscription_type, ce.enrollment_date,
           ce.is_repeating, ce.previous_school_name, ce.previous_class_name,
           ce.transfer_reason, ce.withdrawal_date, ce.withdrawal_reason,
           ce.withdrawal_motif, ce.rejection_reason, ce.promotion_decision,
           ce.promotion_average, ce.exemption_rate, ce.exemption_motif,
           ce.notes,
           c.name AS class_name, c.cycle_code, c.level_code, c.filiere_label,
           ay.label AS year_label, ay.start_date AS year_start
      FROM class_enrollments ce
      LEFT JOIN classes        c  ON c.id  = ce.class_id
      LEFT JOIN academic_years ay ON ay.id = ce.academic_year_id
     WHERE ce.student_id = ?
     ORDER BY ay.start_date DESC, ce.enrollment_date DESC
    ''',
    parameters: [studentId],
  ).map((rows) => [
        for (final r in rows)
          ParcoursAnnee(
            enrollmentId: _s(r['id']),
            anneeLabel: _s(r['year_label']),
            anneeDebut: _d(r['year_start']),
            classe: _s(r['class_name']),
            cycleCode: _s(r['cycle_code']),
            niveauCode: _s(r['level_code']),
            filiere: _s(r['filiere_label']),
            statut: _s(r['status']),
            type: _s(r['inscription_type']),
            dateInscription: _d(r['enrollment_date']),
            redoublant: _b(r['is_repeating']),
            ecolePrecedente: _s(r['previous_school_name']),
            classePrecedente: _s(r['previous_class_name']),
            motifTransfert: _s(r['transfer_reason']),
            dateRetrait: _d(r['withdrawal_date']),
            // Deux colonnes portent le départ : le MOTIF codé et le texte
            // libre. On préfère le texte quand il existe — c'est celui qu'un
            // agent a écrit en connaissance de cause.
            motifRetrait: _s(r['withdrawal_reason']).isNotEmpty
                ? _s(r['withdrawal_reason'])
                : _s(r['withdrawal_motif']),
            motifRejet: _s(r['rejection_reason']),
            verdict: _s(r['promotion_decision']),
            moyenneAnnuelle: _n(r['promotion_average']),
            tauxExoneration: (r['exemption_rate'] as num?)?.toInt(),
            motifExoneration: _s(r['exemption_motif']),
            notes: _s(r['notes']),
          ),
      ]);
});

/// Les pièces déposées au dossier, comptées pour l'en-tête de la fiche.
///
/// Séparé de `studentDocumentsProvider` (qui rend la liste) parce que
/// l'en-tête n'a besoin que d'un nombre : le faire dériver de la liste
/// obligerait l'en-tête à attendre le chargement d'une section qu'il
/// n'affiche pas.
final fichePiecesCountProvider =
    StreamProvider.autoDispose.family<(int, int), String>((ref, studentId) {
  return db.watch(
    '''
    SELECT is_verified FROM student_documents WHERE student_id = ?
    ''',
    parameters: [studentId],
  ).map((rows) => (
        rows.length,
        rows.where((r) => _b(r['is_verified'])).length,
      ));
});
