import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/powersync/powersync_service.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LES ACTES QUI JALONNENT UNE SCOLARITÉ
//
//  Cinq registres qui ont en commun d'être RARES et DÉFINITIFS : un papier
//  délivré, une candidature à un examen d'État, un avis d'orientation, un
//  stage, un transfert. Chacun tient en quelques lignes par élève, sur toute
//  sa scolarité — on les lit donc en entier, sans borne d'année.
//
//  ── POURQUOI ILS SONT ENSEMBLE ─────────────────────────────────────────────
//  Ce ne sont pas cinq sections d'écran, mais cinq réponses à la même
//  question, celle qu'on pose au guichet : « qu'est-ce que l'école a produit
//  pour cet enfant, et qu'est-ce qui a été décidé de lui ? ». Les séparer en
//  cinq providers ferait cinq attentes de chargement pour un seul onglet.
//
//  ── LES DOCUMENTS DÉLIVRÉS NE SONT PAS LES PIÈCES DU DOSSIER ───────────────
//  ⚠️ `issued_documents` = ce que l'école ÉMET (certificat de scolarité, carte
//  scolaire). `student_documents` = ce que la famille DÉPOSE (acte de
//  naissance, certificat médical). Les deux tables se ressemblent et portent
//  toutes deux une colonne `document_type` — les confondre ferait dire à la
//  fiche que le dossier est complet parce que l'école a imprimé une carte.
// ════════════════════════════════════════════════════════════════════════════

DateTime? _d(Object? v) =>
    (v is String && v.isNotEmpty) ? DateTime.tryParse(v) : null;

String _s(Object? v) => (v as String?)?.trim() ?? '';

double? _n(Object? v) =>
    v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));

/// Un papier que l'école a délivré.
class ActeDelivre {
  const ActeDelivre({
    required this.type,
    required this.date,
    required this.parQui,
    required this.motif,
    required this.reference,
    required this.anneeLabel,
  });

  final String type, parQui, motif, reference, anneeLabel;
  final DateTime? date;
}

/// Une candidature à un examen d'État.
class CandidatureExamen {
  const CandidatureExamen({
    required this.examen,
    required this.session,
    required this.numero,
    required this.statutDossier,
    required this.piecesManquantes,
    required this.resultat,
    required this.moyenne,
    required this.mention,
    required this.redoublant,
    required this.centre,
  });

  final String examen, session, numero, statutDossier, piecesManquantes;
  final String resultat, mention, centre;
  final double? moyenne;
  final bool redoublant;
}

/// Un avis d'orientation rendu par le conseil.
class AvisOrientation {
  const AvisOrientation({
    required this.anneeLabel,
    required this.trimestre,
    required this.recommandation,
    required this.niveauVise,
    required this.filiereVisee,
    required this.familleConsultee,
    required this.date,
  });

  final String anneeLabel, trimestre, recommandation, niveauVise, filiereVisee;
  final bool familleConsultee;
  final DateTime? date;
}

/// Un stage en entreprise.
class StageLigne {
  const StageLigne({
    required this.titre,
    required this.entreprise,
    required this.debut,
    required this.fin,
    required this.statut,
    required this.tuteurEntreprise,
    required this.note,
    required this.appreciation,
    required this.conventionSignee,
    required this.attestationLe,
  });

  final String titre, entreprise, statut, tuteurEntreprise, appreciation;
  final DateTime? debut, fin, conventionSignee, attestationLe;
  final double? note;
}

/// Un transfert vers une autre école.
class TransfertLigne {
  const TransfertLigne({
    required this.destination,
    required this.date,
    required this.motif,
    required this.statut,
    required this.approuveLe,
    required this.anneeLabel,
  });

  final String destination, motif, statut, anneeLabel;
  final DateTime? date, approuveLe;
}

/// Tout ce qui a été produit ou décidé pour cet élève.
class ActesEleve {
  const ActesEleve({
    required this.delivres,
    required this.examens,
    required this.orientations,
    required this.stages,
    required this.transferts,
  });

  final List<ActeDelivre> delivres;
  final List<CandidatureExamen> examens;
  final List<AvisOrientation> orientations;
  final List<StageLigne> stages;
  final List<TransfertLigne> transferts;

  int get total =>
      delivres.length +
      examens.length +
      orientations.length +
      stages.length +
      transferts.length;
}

/// Les cinq registres, lus d'un seul geste.
final ficheActesProvider =
    FutureProvider.autoDispose.family<ActesEleve, String>((ref, studentId) async {
  final delivres = await db.getAll(
    '''
    SELECT id.document_type, id.issued_at, id.issued_by_name, id.purpose,
           id.recipient_ref, ay.label AS year_label
      FROM issued_documents id
      LEFT JOIN academic_years ay ON ay.id = id.academic_year_id
     WHERE id.student_id = ?
     ORDER BY id.issued_at DESC
    ''',
    [studentId],
  );

  final examens = await db.getAll(
    '''
    SELECT ec.candidate_number, ec.dossier_status, ec.missing_documents,
           ec.result, ec.average, ec.mention, ec.is_repeater,
           es.year_label,
           ne.name AS exam_name, ne.short_name,
           c.name AS center_name
      FROM exam_candidates ec
      LEFT JOIN exam_sessions  es ON es.id = ec.session_id
      LEFT JOIN national_exams ne ON ne.id = es.exam_id
      LEFT JOIN exam_centers   c  ON c.id  = ec.center_id
     WHERE ec.student_id = ?
     ORDER BY es.year_label DESC
    ''',
    [studentId],
  );

  final orientations = await db.getAll(
    '''
    SELECT so.recommendation, so.target_level, so.target_filiere,
           so.parent_consulted, so.created_at,
           t.label AS trimester_label, ay.label AS year_label
      FROM student_orientations so
      LEFT JOIN trimesters     t  ON t.id  = so.trimester_id
      LEFT JOIN academic_years ay ON ay.id = so.academic_year_id
     WHERE so.student_id = ?
     ORDER BY so.created_at DESC
    ''',
    [studentId],
  );

  final stages = await db.getAll(
    '''
    SELECT i.title, i.start_date, i.end_date, i.status, i.company_tutor_name,
           i.evaluation_grade, i.evaluation_comment, i.convention_signed_at,
           i.attestation_issued_at,
           ic.name AS company_name
      FROM internships i
      LEFT JOIN internship_companies ic ON ic.id = i.company_id
     WHERE i.student_id = ?
     ORDER BY i.start_date DESC
    ''',
    [studentId],
  );

  final transferts = await db.getAll(
    '''
    SELECT st.to_school_name, st.transfer_date, st.reason, st.status,
           st.approved_at, ay.label AS year_label
      FROM student_transfers st
      LEFT JOIN academic_years ay ON ay.id = st.academic_year_id
     WHERE st.student_id = ?
     ORDER BY st.transfer_date DESC
    ''',
    [studentId],
  );

  return ActesEleve(
    delivres: [
      for (final r in delivres)
        ActeDelivre(
          type: _s(r['document_type']),
          date: _d(r['issued_at']),
          parQui: _s(r['issued_by_name']),
          motif: _s(r['purpose']),
          reference: _s(r['recipient_ref']),
          anneeLabel: _s(r['year_label']),
        ),
    ],
    examens: [
      for (final r in examens)
        CandidatureExamen(
          // Le nom court quand il existe : « BEPC » se lit mieux que
          // « Brevet d'Études du Premier Cycle » dans une colonne.
          examen: _s(r['short_name']).isNotEmpty
              ? _s(r['short_name'])
              : _s(r['exam_name']),
          session: _s(r['year_label']),
          numero: _s(r['candidate_number']),
          statutDossier: _s(r['dossier_status']),
          piecesManquantes: _s(r['missing_documents']),
          resultat: _s(r['result']),
          moyenne: _n(r['average']),
          mention: _s(r['mention']),
          redoublant: r['is_repeater'] == 1 || r['is_repeater'] == true,
          centre: _s(r['center_name']),
        ),
    ],
    orientations: [
      for (final r in orientations)
        AvisOrientation(
          anneeLabel: _s(r['year_label']),
          trimestre: _s(r['trimester_label']),
          recommandation: _s(r['recommendation']),
          niveauVise: _s(r['target_level']),
          filiereVisee: _s(r['target_filiere']),
          familleConsultee:
              r['parent_consulted'] == 1 || r['parent_consulted'] == true,
          date: _d(r['created_at']),
        ),
    ],
    stages: [
      for (final r in stages)
        StageLigne(
          titre: _s(r['title']),
          entreprise: _s(r['company_name']),
          debut: _d(r['start_date']),
          fin: _d(r['end_date']),
          statut: _s(r['status']),
          tuteurEntreprise: _s(r['company_tutor_name']),
          note: _n(r['evaluation_grade']),
          appreciation: _s(r['evaluation_comment']),
          conventionSignee: _d(r['convention_signed_at']),
          attestationLe: _d(r['attestation_issued_at']),
        ),
    ],
    transferts: [
      for (final r in transferts)
        TransfertLigne(
          destination: _s(r['to_school_name']),
          date: _d(r['transfer_date']),
          motif: _s(r['reason']),
          statut: _s(r['status']),
          approuveLe: _d(r['approved_at']),
          anneeLabel: _s(r['year_label']),
        ),
    ],
  );
});
