import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'powersync_service.dart';

// ════════════════════════════════════════════════════════════════════════════
//  File d'attente d'envoi de fichiers (table local-only `upload_outbox`).
//
//  PowerSync met en file les écritures SQL, mais PAS les fichiers : Supabase
//  Storage exige le réseau. Conséquence avant ce module : un enseignant hors
//  réseau pouvait envoyer un message texte (mis en file) mais dès qu'il y
//  joignait une photo, l'envoi ENTIER échouait.
//
//  Principe : le chemin Storage est calculé EN LOCAL (UUID — aucun réseau).
//  Les octets vont sur le disque, la ligne va dans `upload_outbox`, et le
//  message référence tout de suite ce chemin. Au retour du réseau, le fichier
//  est téléversé à ce chemin exact : la pièce jointe « se remplit » d'elle-même,
//  sans qu'aucune ligne déjà synchronisée n'ait à être corrigée.
//
//  Ne concerne QUE les appareils du personnel scolaire (les seuls à synchroniser
//  hors-ligne). super_admin / admin_groupe sont online par conception : chez eux
//  un échec réseau reste un échec, remonté à l'utilisateur.
// ════════════════════════════════════════════════════════════════════════════

/// Sous-dossier disque des fichiers en attente.
const _kOutboxDir = 'upload_outbox';

/// Chemin Storage d'une pièce jointe — calculé sans réseau.
/// Dossier = groupe (RLS Storage) ; nom imprévisible (UUID).
String buildStoragePath({required String groupId, required String fileName}) {
  final safeName = fileName.replaceAll(RegExp(r'[^\w\.\-]+'), '_');
  final folder = groupId.isEmpty ? 'platform' : groupId;
  return '$folder/${const Uuid().v4()}_$safeName';
}

/// Vrai si l'erreur traduit une absence de réseau (et non un REFUS du serveur).
/// Un refus (RLS, quota, MIME) ne doit JAMAIS être mis en file : il se
/// reproduirait à l'identique. Seul le transport est réessayable.
bool isTransportFailure(Object e) {
  if (e is SocketException || e is TimeoutException) return true;
  if (e is StorageException) return false; // refus explicite du serveur
  final s = e.toString();
  return s.contains('SocketException') ||
      s.contains('ClientException') ||
      s.contains('Connection closed') ||
      s.contains('Failed host lookup');
}

/// Met un fichier en file d'attente et renvoie son chemin Storage définitif.
/// Écrit les octets sur le disque : la SQLite ne doit pas porter de blobs.
Future<void> enqueueUpload({
  required String bucket,
  required String storagePath,
  required Uint8List bytes,
  required String mime,
  required String fileName,
}) async {
  final dir = Directory(
      p.join((await getApplicationDocumentsDirectory()).path, _kOutboxDir));
  if (!dir.existsSync()) dir.createSync(recursive: true);

  final local = p.join(dir.path, '${const Uuid().v4()}_$fileName');
  await File(local).writeAsBytes(bytes, flush: true);

  await db.execute(
    'INSERT INTO upload_outbox '
    '(id, bucket, storage_path, local_path, mime, file_name, size, '
    ' created_at, attempts, last_error) '
    'VALUES (uuid(), ?, ?, ?, ?, ?, ?, ?, 0, NULL)',
    [
      bucket,
      storagePath,
      local,
      mime,
      fileName,
      bytes.length,
      DateTime.now().toUtc().toIso8601String(),
    ],
  );
}

/// Fichier local d'une pièce jointe encore en attente — `null` si déjà envoyée.
/// Permet à l'expéditeur de VOIR sa propre photo immédiatement, hors réseau.
Future<File?> pendingFileFor(String storagePath) async {
  try {
    final row = await db.getOptional(
      'SELECT local_path FROM upload_outbox WHERE storage_path = ? LIMIT 1',
      [storagePath],
    );
    final path = row?['local_path'] as String?;
    if (path == null) return null;
    final f = File(path);
    return f.existsSync() ? f : null;
  } catch (_) {
    return null;
  }
}

// ─── Vidange de la file ─────────────────────────────────────────────────────

bool _flushing = false;

/// Téléverse tout ce qui attend. Idempotente et non concurrente.
/// Un refus serveur (RLS/quota/MIME) retire l'entrée : la ré-essayer
/// indéfiniment ne ferait qu'entretenir une file qui ne se viderait jamais.
Future<void> flushUploadOutbox(SupabaseClient client) async {
  if (_flushing) return;
  _flushing = true;
  try {
    final rows = await db.getAll(
      'SELECT id, bucket, storage_path, local_path, mime FROM upload_outbox '
      'ORDER BY created_at ASC',
    );
    for (final r in rows) {
      final id = r['id'] as String;
      final local = File(r['local_path'] as String);

      // Fichier disparu (purge disque) → l'entrée n'a plus d'objet.
      if (!local.existsSync()) {
        await db.execute('DELETE FROM upload_outbox WHERE id = ?', [id]);
        continue;
      }

      try {
        await client.storage.from(r['bucket'] as String).uploadBinary(
              r['storage_path'] as String,
              await local.readAsBytes(),
              fileOptions: FileOptions(contentType: r['mime'] as String),
            );
        await db.execute('DELETE FROM upload_outbox WHERE id = ?', [id]);
        try {
          await local.delete();
        } catch (_) {/* le fichier partira à la purge du cache */}
      } catch (e) {
        if (isTransportFailure(e)) {
          // Toujours hors réseau : on s'arrête, la file reste intacte.
          await db.execute(
            'UPDATE upload_outbox SET attempts = attempts + 1, last_error = ? '
            'WHERE id = ?',
            [e.toString(), id],
          );
          break;
        }
        // Refus définitif du serveur → on abandonne CE fichier (pas la file).
        await db.execute('DELETE FROM upload_outbox WHERE id = ?', [id]);
        try {
          await local.delete();
        } catch (_) {}
      }
    }
  } catch (_) {
    // Fail-soft : une file d'attente ne doit jamais faire tomber l'app.
  } finally {
    _flushing = false;
  }
}

/// Supprime du DISQUE les fichiers en attente. `powersync_clear()` vide la
/// table `upload_outbox` mais laisse les octets sur le disque : sans ce ménage,
/// un appareil réattribué à une autre école garderait les photos de la
/// précédente. À n'appeler QUE lors d'une purge assumée (changement d'agent).
Future<void> purgeUploadOutboxFiles() async {
  try {
    final dir = Directory(
        p.join((await getApplicationDocumentsDirectory()).path, _kOutboxDir));
    if (dir.existsSync()) await dir.delete(recursive: true);
  } catch (_) {/* fail-soft */}
}

// ─── Observabilité ──────────────────────────────────────────────────────────

/// Nombre de fichiers en attente d'envoi (0 si l'appareil n'est pas offline-first).
final pendingUploadsProvider = StreamProvider.autoDispose<int>((ref) {
  if (!isOfflineCapableDevice) return Stream.value(0);
  return db
      .watch('SELECT COUNT(*) AS n FROM upload_outbox')
      .map((rows) => rows.isEmpty ? 0 : (rows.first['n'] as int? ?? 0));
});
