import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'powersync_service.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Journal local d'échecs de synchro (table local-only `sync_failures`).
//  Rend OBSERVABLE et ACQUITTABLE la perte d'écritures locales rejetées
//  définitivement par le serveur (contrainte / RLS / données invalides).
//  100% local (db.watch/db.execute) — ne remonte jamais au serveur.
// ════════════════════════════════════════════════════════════════════════════

/// Un échec de synchro, tel qu'affiché à l'utilisateur.
///
/// ⚠️ DEUX NATURES OPPOSÉES, à ne jamais présenter du même mot :
///   • `abandon` — le serveur a refusé définitivement, la transaction a été
///     complétée pour ne pas bloquer la file : **les écritures sont perdues**.
///     À acquitter, parce qu'il faut les ressaisir.
///   • `blocage` — le serveur refuse pour une raison que retenter ne résoudra
///     jamais (le poste tourne sur un build antérieur au schéma). **Rien n'est
///     perdu**, mais ce poste n'envoie plus rien. Il n'y a rien à ressaisir :
///     il faut mettre à jour l'application.
///
/// Dire « données perdues » sur un blocage ferait ressaisir une école pour
/// rien ; dire « en attente » sur un abandon lui ferait attendre un envoi qui
/// n'aura jamais lieu.
class SyncFailure {
  const SyncFailure({
    required this.id,
    required this.at,
    required this.code,
    required this.message,
    required this.summary,
    this.kind = 'abandon',
  });

  final String id;
  final DateTime at;
  final String code;
  final String message;
  final String summary;

  /// `'abandon'` (écritures perdues) ou `'blocage'` (file arrêtée).
  /// Les lignes écrites avant l'ajout de la colonne valent `null` : ce sont
  /// toutes des abandons, c'est donc le défaut.
  final String kind;

  bool get estBlocage => kind == 'blocage';
}

/// Flux des échecs NON acquittés (les plus récents d'abord).
final syncFailuresProvider =
    StreamProvider.autoDispose<List<SyncFailure>>((ref) {
  return db
      .watch(
        'SELECT id, at, code, message, summary, kind '
        // Un blocage passe devant : il arrête TOUT l'envoi du poste, là où un
        // abandon ne concerne qu'une transaction.
        'FROM sync_failures WHERE acknowledged = 0 '
        "ORDER BY (kind = 'blocage') DESC, at DESC",
      )
      .map((rows) => rows
          .map((r) => SyncFailure(
                id: r['id'] as String,
                at: DateTime.tryParse((r['at'] as String?) ?? '')?.toLocal() ??
                    DateTime.now(),
                code: (r['code'] as String?) ?? '?',
                message: (r['message'] as String?) ?? '',
                summary: (r['summary'] as String?) ?? '',
                kind: (r['kind'] as String?) ?? 'abandon',
              ))
          .toList());
});

/// Acquitte un échec précis (l'utilisateur a pris connaissance de la perte).
Future<void> acknowledgeSyncFailure(String id) => db.execute(
      'UPDATE sync_failures SET acknowledged = 1 WHERE id = ?',
      [id],
    );

/// Acquitte toutes les PERTES en attente d'un coup.
///
/// ⚠️ N'ACQUITTE PAS LES BLOCAGES, délibérément. Un blocage n'est pas une
/// nouvelle qu'on prend en compte : c'est un ÉTAT qui dure. Le laisser masquer
/// d'un clic rendrait à nouveau muet un poste qui n'envoie plus rien — le
/// défaut même qu'on vient de corriger. Il s'efface tout seul, et seulement,
/// quand une transaction repasse (`_finBlocage` dans le connecteur).
///
/// `coalesce` : les lignes écrites avant la colonne `kind` valent « abandon ».
Future<void> acknowledgeAllSyncFailures() => db.execute(
      'UPDATE sync_failures SET acknowledged = 1 '
      "WHERE acknowledged = 0 AND coalesce(kind, 'abandon') <> 'blocage'",
    );
