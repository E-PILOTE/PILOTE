import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/auth/providers/auth_provider.dart';
import '../../../services/powersync/powersync_service.dart' show db;
import 'communication_scope.dart';

/// Nombre de messages non lus adressés à l'utilisateur connecté.
/// Universel (super_admin / admin_groupe / personnel) : compte les messages
/// où `recipient_id = moi`, non lus et non archivés. Sert au badge sidebar.
/// Scope-aware : personnel école = SQLite local PowerSync (offline-first,
/// réactif via db.watch) ; super_admin / admin_groupe = Supabase + Realtime.
final unreadMessagesCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  ref.keepAlive();
  final ctx = ref.watch(communicationContextProvider);
  if (ctx.isSchool) return _unreadCountOffline(ref);

  final client = ref.watch(supabaseClientProvider);
  final uid = client.auth.currentUser?.id;
  if (uid == null) return 0;

  Timer? debounce;
  void scheduleInvalidate() {
    debounce?.cancel();
    debounce = Timer(const Duration(seconds: 1), () => ref.invalidateSelf());
  }
  try {
    final channel = client.channel('comm_messages_badge')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: (_) => scheduleInvalidate(),
        )
        .subscribe();
    ref.onDispose(() {
      debounce?.cancel();
      client.removeChannel(channel);
    });
  } catch (_) {}

  final res = await client
      .from('messages')
      .select('id')
      .eq('recipient_id', uid)
      .eq('is_read', false)
      .eq('is_archived', false)
      .count(CountOption.exact);
  return res.count;
});

// ─── Périmètre école — comptage offline-first (PowerSync) ──────────────────────
// Réactif : ré-évalue à chaque changement local de `messages` (réception via
// synchro ou lecture via db.execute), fonctionne hors-ligne.
Future<int> _unreadCountOffline(Ref ref) async {
  final uid = ref.watch(authNotifierProvider).valueOrNull?.id;
  if (uid == null || uid.isEmpty) return 0;

  final sub = db
      .watch('SELECT id FROM messages WHERE recipient_id = ?',
          parameters: [uid])
      .skip(1)
      .listen((_) => ref.invalidateSelf());
  ref.onDispose(sub.cancel);

  final row = await db.get(
    '''SELECT COUNT(*) AS n FROM messages
       WHERE recipient_id = ?
         AND COALESCE(is_read, 0) = 0
         AND COALESCE(is_archived, 0) = 0''',
    [uid],
  );
  return (row['n'] as int?) ?? 0;
}
