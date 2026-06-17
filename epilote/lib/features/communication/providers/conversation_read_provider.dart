import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../auth/providers/auth_provider.dart';
import 'communication_scope.dart';

// ════════════════════════════════════════════════════════════════════════════
//  ÉTAT DE LECTURE DES CONVERSATIONS DE GROUPE (accusés de réception + non-lus)
//  Source de vérité : `conversation_members.last_read_at` (un horodatage par
//  membre). À l'ouverture d'un fil de groupe, on pousse son `last_read_at` à
//  maintenant ; on en déduit :
//   • combien de messages NON LUS j'ai dans chaque groupe (created_at > monLu),
//   • « lu par N/M » pour chacun de mes messages (lastRead_membre ≥ created_at).
//  Scope-aware : école → PowerSync (db.watch, réactif) ; admin/plateforme →
//  Supabase (+ realtime). Aucune violation de la règle online/offline.
// ════════════════════════════════════════════════════════════════════════════

/// last_read_at de chaque membre, par conversation : convId → (userId → date).
class ConvReadState {
  const ConvReadState(this._byConv);
  final Map<String, Map<String, DateTime>> _byConv;

  static const empty = ConvReadState({});

  Map<String, DateTime> membersOf(String convId) =>
      _byConv[convId] ?? const {};

  /// Mon dernier accusé de lecture sur une conversation (null = jamais lu).
  DateTime? myLastRead(String convId, String myId) => _byConv[convId]?[myId];

  /// Nombre de messages non lus dans [convId] pour [myId] sur la base d'une
  /// liste (id sender, date d'émission). Un message compte s'il n'est pas de moi
  /// et qu'il est postérieur à mon dernier accusé de lecture.
  int unreadCount(
    String convId,
    String myId,
    Iterable<({String senderId, DateTime at})> msgs,
  ) {
    final mine = _byConv[convId]?[myId];
    var n = 0;
    for (final m in msgs) {
      if (m.senderId == myId) continue;
      if (mine == null || m.at.isAfter(mine)) n++;
    }
    return n;
  }

  /// Membres (hors expéditeur) ayant lu un message émis à [sentAt].
  int readByCount(String convId, String senderId, DateTime sentAt) {
    final members = _byConv[convId];
    if (members == null) return 0;
    var n = 0;
    members.forEach((uid, last) {
      if (uid == senderId) return;
      if (!last.isBefore(sentAt)) n++;
    });
    return n;
  }
}

DateTime? _parseTs(Object? v) =>
    v == null ? null : DateTime.tryParse(v.toString())?.toUtc();

ConvReadState _rowsToState(List<Map<String, dynamic>> rows) {
  final byConv = <String, Map<String, DateTime>>{};
  for (final r in rows) {
    final cid = r['conversation_id'] as String?;
    final uid = r['user_id'] as String?;
    final ts = _parseTs(r['last_read_at']);
    if (cid == null || uid == null || ts == null) continue;
    byConv.putIfAbsent(cid, () => {})[uid] = ts;
  }
  return ConvReadState(byConv);
}

/// État de lecture de TOUTES mes conversations de groupe, réactif et scope-aware.
final conversationReadProvider =
    StreamProvider.autoDispose<ConvReadState>((ref) async* {
  final ctx = ref.watch(communicationContextProvider);
  final uid = ref.watch(authNotifierProvider).valueOrNull?.id ?? '';
  if (uid.isEmpty) {
    yield ConvReadState.empty;
    return;
  }

  if (ctx.isSchool) {
    yield* db
        .watch(
          '''SELECT conversation_id, user_id, last_read_at
               FROM conversation_members
              WHERE conversation_id IN (
                    SELECT conversation_id FROM conversation_members
                     WHERE user_id = ?)''',
          parameters: [uid],
        )
        .map(_rowsToState);
    return;
  }

  // Admin / plateforme : Supabase (online) + realtime sur conversation_members.
  final client = ref.watch(supabaseClientProvider);

  Future<ConvReadState> fetch() async {
    final mine = await client
        .from('conversation_members')
        .select('conversation_id')
        .eq('user_id', uid) as List;
    final ids = mine
        .map((r) => (r as Map)['conversation_id'] as String)
        .toList();
    if (ids.isEmpty) return ConvReadState.empty;
    final rows = await client
        .from('conversation_members')
        .select('conversation_id, user_id, last_read_at')
        .inFilter('conversation_id', ids) as List;
    return _rowsToState(
        rows.map((r) => Map<String, dynamic>.from(r as Map)).toList());
  }

  yield await fetch();

  final controller = StreamController<ConvReadState>();
  Timer? debounce;
  void schedule() {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 400), () async {
      if (!controller.isClosed) {
        try {
          controller.add(await fetch());
        } catch (_) {}
      }
    });
  }

  final channel = client.channel('conv_reads_$uid').onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'conversation_members',
        callback: (_) => schedule(),
      ).subscribe();
  ref.onDispose(() {
    debounce?.cancel();
    client.removeChannel(channel);
    controller.close();
  });
  yield* controller.stream;
});

/// Pousse mon `last_read_at` à maintenant sur une conversation de groupe.
/// Scope-aware ; idempotent (UPDATE sur ma ligne de membre).
Future<void> markConversationReadScoped(WidgetRef ref, String convId) async {
  final ctx = ref.read(communicationContextProvider);
  final uid = ref.read(authNotifierProvider).valueOrNull?.id ?? '';
  if (uid.isEmpty || convId.isEmpty) return;
  final now = DateTime.now().toUtc().toIso8601String();
  if (ctx.isSchool) {
    await db.execute(
      'UPDATE conversation_members SET last_read_at = ? '
      'WHERE conversation_id = ? AND user_id = ?',
      [now, convId, uid],
    );
  } else {
    await ref
        .read(supabaseClientProvider)
        .from('conversation_members')
        .update({'last_read_at': now})
        .eq('conversation_id', convId)
        .eq('user_id', uid);
  }
}
