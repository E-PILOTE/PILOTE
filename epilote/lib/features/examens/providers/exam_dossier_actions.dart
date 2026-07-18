import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../../services/powersync/student_document_upload.dart';
import '../models/dossier_piece_state.dart';
import '../models/exam_dossier_piece.dart';

// ════════════════════════════════════════════════════════════════════════════
//  JOINDRE, VÉRIFIER, RETIRER UNE PIÈCE — et en tirer l'état du dossier.
//
//  ── Où vivent les DÉCLARATIONS, maintenant que les fichiers existent ? ─────
//  Nulle part de nouveau : `missing_documents` les contient déjà. La colonne
//  dit ce qui n'est PAS couvert ; on en déduit ce qui l'est :
//
//      déclaré = exigé − manquant − attaché
//
//  L'inverse exact de la règle d'écriture. Aucune colonne supplémentaire, et
//  surtout aucune seconde vérité à tenir synchronisée — le module refuse déjà
//  de stocker deux fois la même chose (cf. `resolve_class_exam()`).
//
//  ── Offline ────────────────────────────────────────────────────────────────
//  Le chemin Storage est calculé EN LOCAL (UUID, aucun réseau) ; les octets
//  vont sur le disque via `upload_outbox` ; la ligne `student_documents` est
//  écrite tout de suite avec ce chemin. Une école sans internet joint ses scans
//  normalement — la pièce se remplit d'elle-même au retour du réseau.
// ════════════════════════════════════════════════════════════════════════════

/// Statuts après lesquels le dossier est FIGÉ : il a été transmis, il ne doit
/// plus bouger en douce. Rouvrir est un acte explicite ([reopenDossier]).
const _kFrozen = {'depose', 'valide'};

/// Levée quand on tente d'écrire dans un dossier déjà déposé.
class DossierFrozenException implements Exception {
  const DossierFrozenException();
  @override
  String toString() =>
      'Dossier déposé : les pièces sont figées. Rouvrez-le pour le corriger.';
}

Future<String?> _statusOf(String candidateId) async {
  final r = await db.getOptional(
    'SELECT dossier_status FROM exam_candidates WHERE id = ?',
    [candidateId],
  );
  return r?['dossier_status'] as String?;
}

/// Garde d'écriture — posée ici et pas seulement dans l'UI : un dossier transmis
/// ne doit pas pouvoir être modifié par un autre chemin.
Future<void> _assertWritable(String candidateId) async {
  if (_kFrozen.contains(await _statusOf(candidateId))) {
    throw const DossierFrozenException();
  }
}

// ─── Joindre une pièce ──────────────────────────────────────────────────────

/// Attache un fichier réel à une pièce du dossier. Offline-first.
///
/// La PORTÉE dépend de la pièce, et c'est tout l'enjeu de la migration 0056 :
///  • `source: eleve`       → `exam_candidate_id = NULL` : la pièce suit l'élève
///    et ressert à chaque candidature (rien à re-téléverser en réinscription).
///  • `source: candidature` → liée à CETTE candidature ; la recycler d'une
///    session sur l'autre serait une faute.
Future<void> attachDossierPiece({
  required String candidateId,
  required String studentId,
  required String groupId,
  required String schoolId,
  required ExamDossierPiece piece,
  required String fileName,
  required Uint8List bytes,
  SupabaseClient? client,
}) async {
  await _assertWritable(candidateId);

  await attachStudentDocumentOffline(
    groupId: groupId,
    schoolId: schoolId,
    studentId: studentId,
    documentType: piece.code,
    documentName: piece.label,
    fileName: fileName,
    bytes: bytes,
    // Toute la portée tient dans cette ligne : une pièce de l'élève n'est
    // rattachée à aucune candidature, donc ressert à la suivante.
    examCandidateId:
        piece.source == PieceSource.candidature ? candidateId : null,
    client: client,
  );

  await recomputeDossier(candidateId);
}

// ─── Retirer / vérifier ─────────────────────────────────────────────────────

Future<void> removeDossierPiece({
  required String candidateId,
  required String documentId,
}) async {
  await _assertWritable(candidateId);
  await db.execute('DELETE FROM student_documents WHERE id = ?', [documentId]);
  await recomputeDossier(candidateId);
}

/// Marque une pièce vérifiée — un agent a OUVERT le scan et confirmé qu'il est
/// lisible, au bon nom, et légalisé si la pièce l'exige. Ne change pas la
/// complétude : une pièce fournie non encore vérifiée ne bloque pas le dépôt.
Future<void> setDossierPieceVerified({
  required String candidateId,
  required String documentId,
  required bool verified,
  String? verifiedBy,
}) async {
  await _assertWritable(candidateId);
  final now = DateTime.now().toIso8601String();
  await db.execute(
    'UPDATE student_documents '
    'SET is_verified = ?, verified_by = ?, verified_at = ?, updated_at = ? '
    'WHERE id = ?',
    [verified ? 1 : 0, verified ? verifiedBy : null, verified ? now : null,
      now, documentId],
  );
}

/// URL signée (1 h) pour consulter une pièce — le bucket est privé.
/// `null` hors réseau : on le dit, on ne fait pas semblant.
Future<String?> signedPieceUrl(SupabaseClient client, String storagePath) =>
    signedStudentDocumentUrl(client, storagePath);

// ─── Déclarations & recomposition ───────────────────────────────────────────

/// Enregistre les pièces DÉCLARÉES fournies (cases cochées) et recompose.
/// Seule voie possible pour les pièces physiques et financières.
Future<void> saveDossierDeclarations(
  String candidateId, {
  required Set<String> declared,
}) async {
  await _assertWritable(candidateId);
  await recomputeDossier(candidateId, declaredOverride: declared);
}

/// Recalcule `missing_documents` et `dossier_status` à partir de l'état RÉEL :
/// pièces exigées, fichiers attachés, déclarations, attestation de stage.
///
/// Sans `declaredOverride`, les déclarations antérieures sont retrouvées par
/// `déclaré = exigé − manquant − attaché`.
Future<void> recomputeDossier(
  String candidateId, {
  Set<String>? declaredOverride,
}) async {
  final rows = await db.getAll(
    '''
    SELECT c.student_id, c.missing_documents, s.required_documents
      FROM exam_candidates c
      JOIN exam_sessions s ON s.id = c.session_id
     WHERE c.id = ?
    ''',
    [candidateId],
  );
  if (rows.isEmpty) return;
  final r = rows.first;
  final studentId = r['student_id'] as String;

  final required = ExamDossierPiece.parseList(r['required_documents']);
  final previousMissing = ExamDossierPiece.parseList(r['missing_documents'])
      .map((p) => p.code)
      .toSet();

  final attachedCodes = await attachedCodesFor(
    candidateId: candidateId,
    studentId: studentId,
  );

  // `déclaré = exigé − manquant − attaché` : l'inverse exact de la règle
  // d'écriture, donc fidèle à ce que l'agent avait coché avant les fichiers.
  final declared = declaredOverride ??
      recoverDeclared(
        required: required,
        previousMissing: previousMissing,
        attachedCodes: attachedCodes,
      );

  final stageIssued = await _stageIssuedFor(studentId, required);

  final missing = deriveMissing(
    required: required,
    attachedCodes: attachedCodes,
    declaredCodes: declared,
    stageIssued: stageIssued,
  );

  await db.execute(
    'UPDATE exam_candidates SET missing_documents = ?, dossier_status = ?, '
    'updated_at = ? WHERE id = ?',
    [
      jsonEncode(missing.map((p) => p.toMap()).toList()),
      missing.isEmpty ? 'complet' : 'incomplet',
      DateTime.now().toIso8601String(),
      candidateId,
    ],
  );
}

/// Codes des pièces ayant un fichier attaché pour cette candidature :
/// les pièces de l'ÉLÈVE (portée globale) plus celles de CETTE candidature.
Future<Set<String>> attachedCodesFor({
  required String candidateId,
  required String studentId,
}) async {
  final rows = await db.getAll(
    '''
    SELECT document_type FROM student_documents
     WHERE student_id = ?
       AND file_url IS NOT NULL AND file_url <> ''
       AND (exam_candidate_id IS NULL OR exam_candidate_id = ?)
    ''',
    [studentId, candidateId],
  );
  return {
    for (final r in rows)
      if ((r['document_type'] as String?)?.isNotEmpty ?? false)
        r['document_type'] as String,
  };
}

Future<bool> _stageIssuedFor(
  String studentId,
  List<ExamDossierPiece> required,
) async {
  if (!required.any((p) => p.code == kStagePieceCode)) return false;
  final rows = await db.getAll(
    'SELECT 1 FROM internships '
    'WHERE student_id = ? AND attestation_issued_at IS NOT NULL LIMIT 1',
    [studentId],
  );
  return rows.isNotEmpty;
}

// ─── Rouvrir un dossier déposé ──────────────────────────────────────────────

/// Rouvre un dossier déposé pour correction.
///
/// Cette porte existe parce que la DEC exige parfois une rectification après
/// dépôt ; sans elle, l'exigence deviendrait impossible à satisfaire dans
/// l'app et l'école corrigerait hors système. Elle est gardée côté écran par
/// l'action `validate` — le même verrou que le dépôt lui-même.
Future<void> reopenDossier(String candidateId) async {
  final now = DateTime.now().toIso8601String();
  await db.execute(
    'UPDATE exam_candidates SET dossier_status = ?, submitted_at = NULL, '
    'updated_at = ? WHERE id = ?',
    ['complet', now, candidateId],
  );
  await recomputeDossier(candidateId);
}
