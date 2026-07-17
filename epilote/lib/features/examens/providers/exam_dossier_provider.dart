import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/powersync/powersync_service.dart';
import '../models/exam_dossier_piece.dart';

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
  const DossierPieceState({required this.piece, required this.provided});

  final ExamDossierPiece piece;

  /// Déclarée fournie par l'école. Pour une pièce conditionnelle, l'information
  /// est purement indicative : elle ne compte pas dans la complétude.
  final bool provided;
}

class CandidateDossier {
  const CandidateDossier({
    required this.candidateId,
    required this.fullName,
    required this.examShortName,
    required this.status,
    required this.pieces,
  });

  final String candidateId;
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

final candidateDossierProvider =
    FutureProvider.autoDispose.family<CandidateDossier?, String>(
  (ref, candidateId) async {
    final rows = await db.getAll(
      '''
      SELECT c.id, c.dossier_status, c.missing_documents,
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

    return CandidateDossier(
      candidateId: r['id'] as String,
      fullName:
          '${r['first_name'] ?? ''} ${r['last_name'] ?? ''}'.trim(),
      examShortName: (r['exam_short_name'] as String?) ?? '—',
      status: r['dossier_status'] as String?,
      pieces: [
        for (final p in required)
          DossierPieceState(
            piece: p,
            // Une pièce conditionnelle n'entre JAMAIS dans `missing` : la
            // déduire « fournie » de son absence serait un mensonge par
            // construction. Elle n'a pas d'état — c'est un rappel, pas une case.
            provided: p.isConditional ? false : !missingCodes.contains(p.code),
          ),
      ],
    );
  },
);
