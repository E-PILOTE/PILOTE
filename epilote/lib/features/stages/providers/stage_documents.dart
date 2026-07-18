import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../../services/powersync/student_document_upload.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LES PIÈCES D'UN STAGE — ce que l'entreprise renvoie, et qui fait foi.
//
//  L'attestation, elle, est PRODUITE par l'école : elle a son propre circuit
//  (module Stages, PDF officiel). Ces pièces-ci arrivent de l'extérieur et
//  n'existent que sous forme de papier signé — la convention retournée par
//  l'entreprise, la fiche d'évaluation remplie par le tuteur. Sans un endroit
//  où les déposer, elles finissent dans un classeur et disparaissent avec lui.
//
//  Rattachées au STAGE (migration 0057), pas à l'élève : un élève peut en
//  accomplir plusieurs, et la convention de l'an dernier ne vaut pas pour
//  cette année.
// ════════════════════════════════════════════════════════════════════════════

/// Catalogue des pièces d'un stage (slug stable → libellé).
const stageDocTypes = <String, String>{
  'convention_stage_signee': 'Convention de stage signée',
  'evaluation_tuteur': 'Fiche d\'évaluation du tuteur',
  'rapport_stage': 'Rapport de stage de l\'élève',
};

String stageDocLabel(String slug) => stageDocTypes[slug] ?? slug;

class StageDocument {
  const StageDocument({
    required this.id,
    required this.type,
    required this.name,
    required this.fileUrl,
    required this.isVerified,
  });

  final String id, type, name, fileUrl;
  final bool isVerified;
}

/// Les pièces déposées pour CE stage — offline-first.
final stageDocumentsProvider = StreamProvider.autoDispose
    .family<List<StageDocument>, String>((ref, internshipId) {
  return db
      .watch(
        '''
        SELECT id, document_type, document_name, file_url, is_verified
          FROM student_documents
         WHERE internship_id = ?
           AND file_url IS NOT NULL AND file_url <> ''
         ORDER BY created_at DESC
        ''',
        parameters: [internshipId],
      )
      .map((rows) => [
            for (final r in rows)
              StageDocument(
                id: r['id'] as String,
                type: r['document_type'] as String? ?? '',
                name: r['document_name'] as String? ?? '',
                fileUrl: r['file_url'] as String? ?? '',
                isVerified: r['is_verified'] == 1 || r['is_verified'] == true,
              ),
          ]);
});

Future<void> attachStageDocument({
  required String internshipId,
  required String studentId,
  required String groupId,
  required String schoolId,
  required String typeSlug,
  required String fileName,
  required Uint8List bytes,
  SupabaseClient? client,
}) =>
    attachStudentDocumentOffline(
      groupId: groupId,
      schoolId: schoolId,
      studentId: studentId,
      documentType: typeSlug,
      documentName: stageDocLabel(typeSlug),
      fileName: fileName,
      bytes: bytes,
      internshipId: internshipId,
      client: client,
    );

Future<void> removeStageDocument(String documentId) =>
    db.execute('DELETE FROM student_documents WHERE id = ?', [documentId]);
