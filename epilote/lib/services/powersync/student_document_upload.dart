import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/media_compression.dart';
import 'powersync_service.dart';
import 'upload_outbox.dart';

// ════════════════════════════════════════════════════════════════════════════
//  ATTACHER UN FICHIER À UN ÉLÈVE — le chemin unique, offline-first.
//
//  Examens et Stages joignent tous deux des scans à `student_documents`. Écrire
//  deux fois la même séquence (calcul du chemin, mise en file, INSERT complet)
//  serait deux fois l'occasion d'oublier une colonne NOT NULL — et un rejet
//  serveur abandonne le lot PowerSync ENTIER, silencieusement. D'où ce chemin
//  unique.
//
//  Principe offline : le chemin Storage est calculé EN LOCAL (UUID, aucun
//  réseau), les octets vont sur le disque via `upload_outbox`, et la ligne est
//  écrite tout de suite avec ce chemin. Au retour du réseau le fichier monte à
//  ce chemin exact : la pièce se remplit d'elle-même, sans corriger une ligne
//  déjà synchronisée.
// ════════════════════════════════════════════════════════════════════════════

const _uuid = Uuid();
const kStudentDocsBucket = 'student-documents';

String studentDocMime(String ext) => switch (ext.toLowerCase()) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'pdf' => 'application/pdf',
      _ => 'application/octet-stream',
    };

/// Met les OCTETS d'une pièce en file et renvoie son chemin Storage — SANS
/// écrire la ligne `student_documents`.
///
/// ── POURQUOI CETTE MOITIÉ EXISTE SÉPARÉMENT ────────────────────────────────
/// L'assistant d'inscription collecte les pièces à l'étape 4, mais l'élève
/// n'est créé qu'à l'enregistrement, à la fin. Écrire la ligne dès l'étape 4 la
/// placerait dans la file PowerSync AVANT l'insertion de `students` : le
/// serveur répondrait `23503` (clé étrangère `student_id`), un code que le
/// connecteur tient pour fatal — et c'est le LOT ENTIER qui serait abandonné en
/// silence, l'élève, ses tuteurs et son inscription compris.
///
/// L'assistant met donc les octets en file ici, garde le chemin, et n'écrit la
/// ligne qu'après avoir créé l'élève. Le chemin, lui, se calcule au même
/// endroit pour tout le monde : c'est ce qui garantit qu'un fichier et sa ligne
/// se retrouvent.
Future<String> queueStudentDocumentFile({
  required String schoolId,
  required String studentId,
  required String documentType,
  required String fileName,
  required Uint8List bytes,
  SupabaseClient? client,
}) async {
  final rawExt = fileName.contains('.') ? fileName.split('.').last : 'bin';

  // On compresse AVANT la mise en file, pas au moment de l'envoi. Hors ligne,
  // ces octets dorment sur le disque du poste — parfois des jours. Une pièce
  // photographiée au téléphone (4 à 8 Mo) mise en file telle quelle occupe
  // cette place tout ce temps, et une école qui constitue cinquante dossiers
  // avant de retrouver du réseau sature son propre appareil. Les PDF passent
  // inchangés.
  final media = await compressForUpload(
    bytes: bytes,
    fileName: fileName,
    mime: studentDocMime(rawExt),
  );
  final ext = media.fileName.contains('.')
      ? media.fileName.split('.').last
      : rawExt;
  final safe = media.fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  final storagePath =
      '$schoolId/$studentId/${documentType}_${_uuid.v4().substring(0, 8)}_$safe';

  await enqueueUpload(
    bucket: kStudentDocsBucket,
    storagePath: storagePath,
    bytes: media.bytes,
    mime: studentDocMime(ext),
    fileName: safe,
  );

  // Envoi immédiat si le réseau est là ; sinon la file part au prochain retour.
  if (client != null) unawaited(flushUploadOutbox(client));
  return storagePath;
}

/// Joint un fichier au dossier d'un élève, éventuellement rattaché à une
/// candidature d'examen ([examCandidateId]) ou à un stage ([internshipId]).
///
/// Les deux rattachements sont exclusifs par nature mais non contraints ici :
/// c'est l'appelant qui sait de quoi il parle. Laisser les deux à `null` crée
/// une pièce de l'ÉLÈVE, réutilisable partout.
///
/// ⚠️ À n'appeler que si l'élève EXISTE déjà. Sinon, voir
/// [queueStudentDocumentFile] et l'ordre de la file PowerSync.
Future<String> attachStudentDocumentOffline({
  required String groupId,
  required String schoolId,
  required String studentId,
  required String documentType,
  required String documentName,
  required String fileName,
  required Uint8List bytes,
  String? examCandidateId,
  String? internshipId,
  SupabaseClient? client,
}) async {
  // Les octets d'abord : si la mise en file échoue, aucune ligne ne doit
  // promettre un fichier qui n'arrivera jamais.
  final storagePath = await queueStudentDocumentFile(
    schoolId: schoolId,
    studentId: studentId,
    documentType: documentType,
    fileName: fileName,
    bytes: bytes,
  );

  final now = DateTime.now().toIso8601String();
  await db.execute(
    '''
    INSERT INTO student_documents
      (id, group_id, school_id, student_id, document_type, document_name,
       file_url, exam_candidate_id, internship_id, is_verified,
       created_at, updated_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?)
    ''',
    [
      _uuid.v4(),
      groupId,
      schoolId,
      studentId,
      documentType,
      documentName,
      storagePath,
      examCandidateId,
      internshipId,
      now,
      now,
    ],
  );

  // Envoi immédiat si le réseau est là ; sinon la file part au prochain retour.
  if (client != null) unawaited(flushUploadOutbox(client));
  return storagePath;
}

/// URL signée (1 h) pour consulter une pièce — le bucket est privé.
/// `null` hors réseau : on le dit, on ne fait pas semblant.
Future<String?> signedStudentDocumentUrl(
  SupabaseClient client,
  String storagePath,
) async {
  if (storagePath.isEmpty) return null;
  try {
    return await client.storage
        .from(kStudentDocsBucket)
        .createSignedUrl(storagePath, 3600);
  } catch (_) {
    return null;
  }
}
