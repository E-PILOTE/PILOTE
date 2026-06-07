import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/auth/providers/auth_provider.dart';

/// Nombre de messages non lus adressés à l'utilisateur connecté.
/// Universel (super_admin / admin_groupe / personnel) : compte les messages
/// où `recipient_id = moi`, non lus et non archivés. Sert au badge sidebar.
/// Realtime : le badge se met à jour en direct à chaque message/lecture.
final unreadMessagesCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  ref.keepAlive();
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
