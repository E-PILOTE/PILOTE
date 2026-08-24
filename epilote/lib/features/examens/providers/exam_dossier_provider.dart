import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/powersync/powersync_service.dart';
import '../models/dossier_piece_state.dart';
import '../models/exam_dossier_piece.dart';

export '../models/dossier_piece_state.dart' show kStagePieceCode;

// ════════════════════════════════════════════════════════════════════════════
//  LE DOSSIER D'UN CANDIDAT — pièce par pièce.
//
//  La session dit ce qui est EXIGÉ ; la candidature dit ce qui MANQUE encore.
//  Le fourni s'en DÉDUIT (exigé − manquant) : on ne stocke jamais deux fois la
//  même vérité, sinon les deux divergent — c'est le principe déjà tenu par
//  `resolve_class_exam()`.
//
//  ── CE QUE CET ÉCRAN NE FAIT PAS (encore), ET POURQUOI ─────────────────────
//  Il ne relie pas une pièce à un FICHIER. `student-documents` (migration 0008)
//  existe et le bucket est prêt, mais rien ne pointe aujourd'hui d'une pièce
//  attendue vers un fichier réel. Tant que ce lien n'existe pas, la présence
//  d'une pièce ne peut être que DÉCLARÉE par l'agent.
//
//  C'est assumé, pas oublié : pour les pièces PHYSIQUES (chemise, enveloppe) la
//  déclaration restera de toute façon le seul mode possible. Le jour où le lien
//  existera, les pièces `fichier` se dériveront des fichiers et cette
//  déclaration deviendra un repli — la structure ci-dessous n'aura pas à bouger.
// ════════════════════════════════════════════════════════════════════════════

class DossierPieceState {
  const DossierPieceState({
    required this.piece,
    required this.provided,
    this.linkedStage,
    this.attached,
    this.declared = false,
  });

  final ExamDossierPiece piece;

  /// Le fichier réellement attaché à cette pièce — `null` si aucun.
  final AttachedPiece? attached;

  /// Déclarée fournie par un agent, sans fichier. Pour une pièce physique ou
  /// financière c'est l'état normal ; pour un fichier, une preuve faible.
  final bool declared;

  /// L'état affichable, fichier et déclaration confondus.
  PieceFileState get fileState =>
      pieceStateFor(attached: attached, declared: declared);

  /// Déclarée fournie par l'école. Pour une pièce conditionnelle, l'information
  /// est purement indicative : elle ne compte pas dans la complétude.
  final bool provided;

  /// Renseigné UNIQUEMENT sur la pièce `attestation_stage` quand une attestation
  /// a été émise dans le module Stages. La pièce est alors satisfaite PAR LE
  /// MODULE (source de vérité), pas par une déclaration manuelle.
  final StageAttestation? linkedStage;

  bool get isStageLinked => linkedStage != null;
}

/// L'attestation de stage vue depuis le dossier d'examen — le pont Examens↔Stages
/// pour le baccalauréat (`BAC`), dont le dossier exige la pièce
/// `attestation_stage`. Le module Stages la produit ; on ne redemande pas à
/// l'agent de cocher ce que le système sait déjà.
class StageAttestation {
  const StageAttestation({
    required this.issuedAt,
    required this.companyName,
    required this.title,
    required this.grade,
  });

  final DateTime? issuedAt;
  final String? companyName;
  final String? title;
  final double? grade;
}

class CandidateDossier {
  const CandidateDossier({
    required this.candidateId,
    required this.studentId,
    required this.groupId,
    required this.schoolId,
    required this.fullName,
    required this.examShortName,
    required this.status,
    required this.pieces,
  });

  final String candidateId;

  /// Nécessaires pour attacher une pièce (INSERT `student_documents`).
  final String studentId;
  final String groupId;
  final String schoolId;

  final String fullName;
  final String examShortName;
  final String? status;
  final List<DossierPieceState> pieces;

  /// Les pièces que tout le monde doit fournir — les seules qui décident.
  List<DossierPieceState> get mandatory =>
      pieces.where((p) => !p.piece.isConditional).toList();

  /// Affichées à part, jamais bloquantes (cf. `ExamDossierPiece.isConditional`).
  List<DossierPieceState> get conditional =>
      pieces.where((p) => p.piece.isConditional).toList();

  int get missingCount => mandatory.where((p) => !p.provided).length;

  bool get isComplete => missingCount == 0;

  /// Le dépôt est un acte humain : un dossier complet est *déposable*, il n'est
  /// pas déposé. Cf. `submitDossier`.
  bool get isSubmitted => status == 'depose' || status == 'valide';
}

/// `kStagePieceCode` vit désormais avec le modèle d'état des pièces ; il reste
/// visible ici pour les écrans qui l'importaient déjà depuis ce provider.

final candidateDossierProvider =
    FutureProvider.autoDispose.family<CandidateDossier?, String>(
  (ref, candidateId) async {
    final rows = await db.getAll(
      '''
      SELECT c.id, c.student_id, c.group_id, c.school_id,
             c.dossier_status, c.missing_documents,
             s.required_documents,
             st.first_name, st.last_name,
             e.short_name AS exam_short_name
        FROM exam_candidates c
        JOIN exam_sessions  s  ON s.id  = c.session_id
        JOIN national_exams e  ON e.id  = s.exam_id
        JOIN students       st ON st.id = c.student_id
       WHERE c.id = ?
      ''',
      [candidateId],
    );
    if (rows.isEmpty) return null;
    final r = rows.first;

    final required = ExamDossierPiece.parseList(r['required_documents']);
    final missingCodes = ExamDossierPiece.parseList(r['missing_documents'])
        .map((p) => p.code)
        .toSet();

    // Pont Examens↔Stages : uniquement si le dossier exige une attestation de
    // stage (bacs pro), on va lire dans le module Stages si elle a été émise.
    // On ne fait la requête que quand la pièce existe — inutile pour un BEPC.
    StageAttestation? stage;
    if (required.any((p) => p.code == kStagePieceCode)) {
      final st = await db.getAll(
        '''
        SELECT i.attestation_issued_at, i.title, i.evaluation_grade,
               co.name AS company
          FROM internships i
          LEFT JOIN internship_companies co ON co.id = i.company_id
         WHERE i.student_id = ? AND i.attestation_issued_at IS NOT NULL
         ORDER BY i.attestation_issued_at DESC
         LIMIT 1
        ''',
        [r['student_id'] as String],
      );
      if (st.isNotEmpty) {
        stage = StageAttestation(
          issuedAt: st.first['attestation_issued_at'] == null
              ? null
              : DateTime.tryParse(st.first['attestation_issued_at'] as String),
          companyName: st.first['company'] as String?,
          title: st.first['title'] as String?,
          grade: (st.first['evaluation_grade'] as num?)?.toDouble(),
        );
      }
    }

    // Les fichiers réellement attachés : pièces de l'ÉLÈVE (portée globale,
    // réutilisées d'une candidature à l'autre) + pièces de CETTE candidature.
    final studentId = r['student_id'] as String;
    final docRows = await db.getAll(
      '''
      SELECT id, document_type, document_name, file_url, exam_candidate_id,
             is_verified, verified_at
        FROM student_documents
       WHERE student_id = ?
         AND file_url IS NOT NULL AND file_url <> ''
         AND (exam_candidate_id IS NULL OR exam_candidate_id = ?)
       ORDER BY created_at DESC
      ''',
      [studentId, candidateId],
    );

    // La plus récente gagne pour un code donné (ORDER BY created_at DESC).
    final attached = <String, AttachedPiece>{};
    for (final d in docRows) {
      final code = d['document_type'] as String? ?? '';
      if (code.isEmpty || attached.containsKey(code)) continue;
      attached[code] = AttachedPiece(
        documentId: d['id'] as String,
        code: code,
        fileUrl: d['file_url'] as String? ?? '',
        fileName: d['document_name'] as String? ?? code,
        isVerified: d['is_verified'] == 1 || d['is_verified'] == true,
        verifiedAt: d['verified_at'] == null
            ? null
            : DateTime.tryParse(d['verified_at'] as String),
        examCandidateId: d['exam_candidate_id'] as String?,
      );
    }

    // Ce que l'agent avait coché avant l'arrivée des fichiers, retrouvé par
    // l'inverse de la règle d'écriture (cf. `recoverDeclared`).
    final declared = recoverDeclared(
      required: required,
      previousMissing: missingCodes,
      attachedCodes: attached.keys.toSet(),
    );

    return CandidateDossier(
      candidateId: r['id'] as String,
      studentId: studentId,
      groupId: r['group_id'] as String? ?? '',
      schoolId: r['school_id'] as String? ?? '',
      fullName:
          '${r['first_name'] ?? ''} ${r['last_name'] ?? ''}'.trim(),
      examShortName: (r['exam_short_name'] as String?) ?? '—',
      status: r['dossier_status'] as String?,
      pieces: [
        for (final p in required)
          DossierPieceState(
            piece: p,
            attached: attached[p.code],
            declared: declared.contains(p.code),
            // La pièce attestation_stage est satisfaite PAR LE MODULE Stages
            // dès qu'une attestation est émise : le système le sait, on ne
            // redemande pas à l'agent de le déclarer.
            provided: p.code == kStagePieceCode && stage != null
                ? true
                : p.isConditional
                    // Une pièce conditionnelle n'entre JAMAIS dans `missing` :
                    // la déduire « fournie » de son absence serait un mensonge.
                    ? attached.containsKey(p.code)
                    : attached.containsKey(p.code) || declared.contains(p.code),
            linkedStage: p.code == kStagePieceCode ? stage : null,
          ),
      ],
    );
  },
);
