import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'powersync_service.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Journal local d'échecs de synchro (table local-only `sync_failures`).
//  Rend OBSERVABLE et ACQUITTABLE la perte d'écritures locales rejetées
//  définitivement par le serveur (contrainte / RLS / données invalides).
//  100% local (db.watch/db.execute) — ne remonte jamais au serveur.
// ════════════════════════════════════════════════════════════════════════════

/// Une transaction locale perdue, telle qu'affichée à l'utilisateur.
class SyncFailure {
  const SyncFailure({
    required this.id,
    required this.at,
    required this.code,
    required this.message,
    required this.summary,
  });

  final String id;
  final DateTime at;
  final String code;
  final String message;
  final String summary;
}

/// Flux des échecs NON acquittés (les plus récents d'abord).
final syncFailuresProvider =
    StreamProvider.autoDispose<List<SyncFailure>>((ref) {
  return db
      .watch(
        'SELECT id, at, code, message, summary '
        'FROM sync_failures WHERE acknowledged = 0 ORDER BY at DESC',
      )
      .map((rows) => rows
          .map((r) => SyncFailure(
                id: r['id'] as String,
                at: DateTime.tryParse((r['at'] as String?) ?? '')?.toLocal() ??
                    DateTime.now(),
                code: (r['code'] as String?) ?? '?',
                message: (r['message'] as String?) ?? '',
                summary: (r['summary'] as String?) ?? '',
              ))
          .toList());
});

/// Acquitte un échec précis (l'utilisateur a pris connaissance de la perte).
Future<void> acknowledgeSyncFailure(String id) => db.execute(
      'UPDATE sync_failures SET acknowledged = 1 WHERE id = ?',
      [id],
    );

/// Acquitte tous les échecs en attente d'un coup.
Future<void> acknowledgeAllSyncFailures() => db.execute(
      'UPDATE sync_failures SET acknowledged = 1 WHERE acknowledged = 0',
    );
