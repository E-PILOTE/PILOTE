import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/media_compression.dart';
import '../../../services/powersync/powersync_service.dart';

const _uuid = Uuid();
const _bucket = 'student-documents';

// ════════════════════════════════════════════════════════════════════════════
//  DOSSIER DOCUMENTAIRE DE L'ÉLÈVE — pièces réelles téléversées (bucket privé).
//  Le dossier suit l'ÉLÈVE (student_id) : en RÉINSCRIPTION, les pièces déjà
//  présentes sont conservées (rien à re-téléverser).
//
//  ── OÙ SE DÉPOSE UNE PIÈCE, DÉSORMAIS ──────────────────────────────────────
//  Dans `services/powersync/student_document_upload.dart`, et nulle part
//  ailleurs : `attachStudentDocumentOffline` (l'élève existe) ou
//  `queueStudentDocumentFile` (l'assistant, où il n'existe pas encore).
//
//  Ce fichier portait un `uploadStudentDocumentFile` qui envoyait à Storage en
//  DIRECT — donc rien sans réseau. Il a été retiré plutôt que laissé de côté :
//  une fonction publique qui fait presque la bonne chose est un piège dormant,
//  et c'est précisément par elle que ce module s'était retrouvé le seul, avec
//  Examens et Stages sur la même table, à ne pas savoir travailler hors ligne.
// ════════════════════════════════════════════════════════════════════════════

/// Catalogue des pièces du dossier (slug stable → libellé).
const studentDocTypes = <String, String>{
  'acte_naissance':        "Extrait d'acte de naissance",
  'bulletin_precedent':    'Bulletin (année précédente)',
  'certificat_medical':    'Certificat médical de bonne santé',
  'photo_identite':        "Photo d'identité",
  'attestation_transfert': 'Attestation de transfert',
  'livret_scolaire':       'Livret scolaire',
};

String docTypeLabel(String slug) => studentDocTypes[slug] ?? slug;

/// Insère la ligne du dossier (offline-first). `file_url` = chemin Storage.
///
/// ⚠️ N'A QU'UN SEUL APPELANT LÉGITIME : l'enregistrement de l'assistant
/// d'inscription, qui écrit les lignes des pièces APRÈS avoir créé l'élève —
/// leurs octets, eux, sont partis en file dès l'étape 4. Partout ailleurs, la
/// pièce se dépose d'un seul geste par `attachStudentDocumentOffline`, qui met
/// les octets en file ET écrit la ligne. Appeler cette fonction avec un chemin
/// qui n'a pas été mis en file écrirait une pièce qui ne pointe sur rien.
Future<void> insertStudentDocumentRow({
  required String groupId,
  required String schoolId,
  required String studentId,
  required String documentType,
  required String documentName,
  required String fileUrl,
}) async {
  final id = _uuid.v4();
  final now = DateTime.now().toIso8601String();
  await db.execute(
    '''
    INSERT INTO student_documents
      (id, group_id, school_id, student_id, document_type, document_name,
       file_url, is_verified, created_at, updated_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?, ?)
    ''',
    [id, groupId, schoolId, studentId, documentType, documentName, fileUrl, now, now],
  );
}

/// Pièces du dossier d'un élève — offline-first (pour la fiche élève / réinscription).
final studentDocumentsProvider = StreamProvider.autoDispose
    .family<List<StudentDocument>, String>((ref, studentId) {
  return db
      .watch(
        '''
        SELECT id, document_type, document_name, file_url, is_verified, created_at
        FROM   student_documents
        WHERE  student_id = ?
        ORDER  BY created_at DESC
        ''',
        parameters: [studentId],
      )
      .map((rows) => [
            for (final r in rows)
              StudentDocument(
                id: r['id'] as String,
                documentType: r['document_type'] as String? ?? '',
                documentName: r['document_name'] as String? ?? '',
                fileUrl: r['file_url'] as String? ?? '',
                isVerified: r['is_verified'] == 1 || r['is_verified'] == true,
              ),
          ]);
});

class StudentDocument {
  const StudentDocument({
    required this.id,
    required this.documentType,
    required this.documentName,
    required this.fileUrl,
    required this.isVerified,
  });
  final String id, documentType, documentName, fileUrl;
  final bool isVerified;
}

/// URL signée (1h) pour consulter une pièce du dossier (bucket privé).
Future<String?> signedStudentDocUrl(SupabaseClient client, String path) async {
  if (path.isEmpty) return null;
  try {
    return await client.storage.from(_bucket).createSignedUrl(path, 3600);
  } catch (_) {
    return null;
  }
}

// ─── Photo de profil de l'élève (bucket public `avatars`) ────────────────────
/// Téléverse la photo de profil vers le bucket PUBLIC `avatars` et renvoie son
/// URL publique (affichable via CachedNetworkImage). Nécessite internet.
Future<String> uploadStudentPhoto({
  required SupabaseClient client,
  required String studentId,
  required Uint8List bytes,
  required String ext,
}) async {
  // Une photo d'élève sort d'un téléphone : 4 à 8 Mo pour une pastille de
  // 38 pixels dans l'annuaire. On réduit à 256 px avant l'envoi — sur une
  // école de 600 élèves, c'est plusieurs gigaoctets de transfert évités.
  final media = await compressAvatar(
    bytes: bytes,
    fileName: 'photo.$ext',
    mime: mimeForImageExtension(ext),
  );
  final e = media.fileName.split('.').last;
  final path = 'students/${studentId}_${DateTime.now().millisecondsSinceEpoch}.$e';
  await client.storage.from('avatars').uploadBinary(
        path,
        media.bytes,
        fileOptions: FileOptions(contentType: media.mime, upsert: true),
      );
  return client.storage.from('avatars').getPublicUrl(path);
}
