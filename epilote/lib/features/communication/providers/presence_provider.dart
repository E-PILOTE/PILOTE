import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_provider.dart';
import 'communication_scope.dart';

// ════════════════════════════════════════════════════════════════════════════
//  PRÉSENCE EN LIGNE (100 % Supabase Realtime Presence — aucune table, aucune
//  écriture en base). Chaque utilisateur connecté « track » son id sur un canal
//  de présence borné à son groupe (frontière tenant). On en déduit l'ensemble
//  des id en ligne, affiché en pastille verte sur les avatars + « en ligne »
//  dans l'en-tête de fil.
//
//  • Marche dès qu'on est connecté (super_admin / admin_groupe toujours en
//    ligne ; personnel école quand il a du réseau). Hors-ligne : on n'apparaît
//    pas et on ne voit personne — comportement correct et attendu.
//  • État éphémère : rien n'est persisté, donc rien à synchroniser offline.
// ════════════════════════════════════════════════════════════════════════════

/// Ensemble des `user_id` actuellement en ligne dans mon périmètre.
final onlinePresenceProvider =
    StreamProvider.autoDispose<Set<String>>((ref) {
  final me = ref.watch(authNotifierProvider).valueOrNull;
  final ctx = ref.watch(communicationContextProvider);
  final myId = me?.id ?? '';
  if (myId.isEmpty) return Stream.value(const <String>{});

  // Canal borné au groupe (tenant). super_admin sans groupe → canal plateforme.
  final scopeKey = (ctx.groupId ?? me?.groupId);
  final topic = (scopeKey == null || scopeKey.isEmpty)
      ? 'presence:platform'
      : 'presence:grp:$scopeKey';

  final client = Supabase.instance.client;
  final controller = StreamController<Set<String>>();

  final channel = client.channel(
    topic,
    opts: RealtimeChannelConfig(key: myId),
  );

  Set<String> collect() {
    final ids = <String>{};
    for (final state in channel.presenceState()) {
      for (final p in state.presences) {
        final uid = p.payload['user_id'];
        if (uid is String && uid.isNotEmpty) ids.add(uid);
      }
    }
    return ids;
  }

  channel.onPresenceSync((_) {
    if (!controller.isClosed) controller.add(collect());
  }).onPresenceJoin((_) {
    if (!controller.isClosed) controller.add(collect());
  }).onPresenceLeave((_) {
    if (!controller.isClosed) controller.add(collect());
  }).subscribe((status, _) async {
    if (status == RealtimeSubscribeStatus.subscribed) {
      await channel.track({'user_id': myId});
    }
  });

  ref.onDispose(() {
    channel.untrack();
    client.removeChannel(channel);
    controller.close();
  });

  // Émet d'abord moi-même (optimiste) puis les mises à jour de présence.
  return controller.stream.startWith({myId});
});

// Petite extension locale pour préfixer le stream d'une valeur initiale sans
// dépendre de rxdart.
extension _StartWith<T> on Stream<T> {
  Stream<T> startWith(T value) async* {
    yield value;
    yield* this;
  }
}
