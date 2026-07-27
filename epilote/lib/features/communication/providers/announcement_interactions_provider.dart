import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../auth/providers/auth_provider.dart';
import 'communication_scope.dart';

// ─── Modèles ─────────────────────────────────────────────────────────────────

class AnnReactionState {
  const AnnReactionState({
    this.likeCount = 0,
    this.loveCount  = 0,
    this.clapCount  = 0,
    this.myReaction,
  });
  final int     likeCount;
  final int     loveCount;
  final int     clapCount;
  final String? myReaction; // null = pas réagi
  int get total => likeCount + loveCount + clapCount;

  AnnReactionState copyWith({
    int? likeCount, int? loveCount, int? clapCount, String? myReaction,
    bool clearMine = false,
  }) => AnnReactionState(
    likeCount: likeCount ?? this.likeCount,
    loveCount: loveCount ?? this.loveCount,
    clapCount: clapCount ?? this.clapCount,
    myReaction: clearMine ? null : (myReaction ?? this.myReaction),
  );
}

class AnnComment {

  factory AnnComment.fromMap(Map<String, dynamic> m) {
    final profiles = m['profiles'] as Map<String, dynamic>?;
    return AnnComment(
      id:             m['id'] as String,
      announcementId: m['announcement_id'] as String,
      authorId:       m['author_id'] as String,
      groupId:        m['group_id'] as String,
      content:        m['content'] as String,
      parentId:       m['parent_id'] as String?,
      createdAt:      DateTime.tryParse(m['created_at'] as String? ?? '')
                        ?.toLocal() ?? DateTime.now(),
      authorName:     profiles != null
                        ? '${profiles['first_name'] ?? ''} ${profiles['last_name'] ?? ''}'.trim()
                        : (m['author_name'] as String?),
      authorAvatarUrl: profiles?['avatar_url'] as String?
                        ?? m['avatar_url'] as String?,
      authorRole:     profiles?['role'] as String? ?? m['role'] as String?,
    );
  }
  AnnComment({
    required this.id,
    required this.announcementId,
    required this.authorId,
    required this.groupId,
    required this.content,
    required this.createdAt,
    this.parentId,
    this.authorName,
    this.authorAvatarUrl,
    this.authorRole,
  });
  final String  id;
  final String  announcementId;
  final String  authorId;
  final String  groupId;
  final String  content;
  final String? parentId;
  final DateTime createdAt;
  String?       authorName;
  String?       authorAvatarUrl;
  String?       authorRole;
}

// ─── Helpers offline (SQLite) ─────────────────────────────────────────────────

AnnReactionState _parseReactionsOffline(
    List<Map<String, dynamic>> rows, String uid) {
  int like = 0, love = 0, clap = 0;
  String? mine;
  for (final r in rows) {
    final t = r['reaction'] as String? ?? 'like';
    switch (t) {
      case 'like': like++; break;
      case 'love': love++; break;
      case 'clap': clap++; break;
    }
    if (r['user_id'] == uid) mine = t;
  }
  return AnnReactionState(
      likeCount: like, loveCount: love, clapCount: clap, myReaction: mine);
}

List<AnnComment> _parseCommentsOffline(List<Map<String, dynamic>> rows) =>
    rows.map(AnnComment.fromMap).toList();

/// Stream online des commentaires (avec JOIN profiles → nom/avatar/rôle résolus).
/// Le `.stream()` Supabase ne supporte pas les joins : on fait un `.select()`
/// enrichi, ré-émis à chaque changement realtime sur l'annonce. [ref] gère la
/// fermeture du canal et du contrôleur.
Stream<List<AnnComment>> _watchCommentsOnline(
    Ref ref, SupabaseClient client, String annId) async* {
  Future<List<AnnComment>> fetch() async {
    final rows = await client
        .from('announcement_comments')
        .select(
            '*, profiles!author_id(first_name,last_name,avatar_url,role)')
        .eq('announcement_id', annId)
        .order('created_at', ascending: false) as List;
    return rows
        .map((r) => AnnComment.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  yield await fetch();

  final controller = StreamController<List<AnnComment>>();
  Timer? debounce;
  final channel = client.channel('ann_comments_$annId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'announcement_comments',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'announcement_id',
          value: annId,
        ),
        callback: (_) {
          debounce?.cancel();
          debounce = Timer(const Duration(milliseconds: 300), () async {
            if (!controller.isClosed) {
              try {
                controller.add(await fetch());
              } catch (_) {}
            }
          });
        },
      )
      .subscribe();
  ref.onDispose(() {
    debounce?.cancel();
    client.removeChannel(channel);
    controller.close();
  });
  yield* controller.stream;
}

// ─── Providers réactifs ───────────────────────────────────────────────────────

/// Réactions pour une annonce — scope-aware (offline ou Supabase).
final annReactionsProvider = StreamProvider.autoDispose
    .family<AnnReactionState, String>((ref, annId) async* {
  final ctx = ref.watch(communicationContextProvider);
  final me  = ref.watch(authNotifierProvider).valueOrNull;
  final uid = me?.id ?? '';

  if (ctx.isSchool) {
    yield* db
        .watch(
          'SELECT * FROM announcement_reactions WHERE announcement_id = ?',
          parameters: [annId],
        )
        .map((rows) => _parseReactionsOffline(rows, uid));
  } else {
    // Online — Supabase realtime
    final client = ref.watch(supabaseClientProvider);
    yield* client
        .from('announcement_reactions')
        .stream(primaryKey: ['id'])
        .eq('announcement_id', annId)
        .map((rows) => _parseReactionsOffline(rows, uid));
  }
});

/// Commentaires pour une annonce — scope-aware.
final annCommentsProvider = StreamProvider.autoDispose
    .family<List<AnnComment>, String>((ref, annId) async* {
  final ctx = ref.watch(communicationContextProvider);

  if (ctx.isSchool) {
    yield* db
        .watch(
          '''
          SELECT c.*,
                 p.first_name AS author_name,
                 p.avatar_url,
                 p.role
            FROM announcement_comments c
            LEFT JOIN profiles p ON p.id = c.author_id
           WHERE c.announcement_id = ?
           ORDER BY c.created_at ASC
          ''',
          parameters: [annId],
        )
        .map(_parseCommentsOffline);
  } else {
    final client = ref.watch(supabaseClientProvider);
    yield* _watchCommentsOnline(ref, client, annId);
  }
});

/// Premier commentaire racine d'une annonce — pour la preview dans la card.
final annFirstCommentProvider = StreamProvider.autoDispose
    .family<AnnComment?, String>((ref, annId) async* {
  final ctx = ref.watch(communicationContextProvider);

  if (ctx.isSchool) {
    yield* db
        .watch(
          '''
          SELECT c.*,
                 TRIM(COALESCE(p.first_name,'') || ' ' || COALESCE(p.last_name,''))
                   AS author_name,
                 p.avatar_url,
                 p.role
            FROM announcement_comments c
            LEFT JOIN profiles p ON p.id = c.author_id
           WHERE c.announcement_id = ?
             AND c.parent_id IS NULL
           ORDER BY c.created_at ASC
           LIMIT 1
          ''',
          parameters: [annId],
        )
        .map((rows) => rows.isEmpty ? null : AnnComment.fromMap(rows.first));
  } else {
    final client = ref.watch(supabaseClientProvider);
    yield* _watchCommentsOnline(ref, client, annId).map((list) {
      final roots = list.where((c) => c.parentId == null);
      return roots.isEmpty ? null : roots.first;
    });
  }
});

// ─── Bookmarks (annonces enregistrées) — scope-aware ──────────────────────────

/// Ids des annonces enregistrées par l'utilisateur courant (réactif).
final savedAnnouncementIdsProvider =
    StreamProvider.autoDispose<Set<String>>((ref) async* {
  final ctx = ref.watch(communicationContextProvider);
  final uid = ref.watch(authNotifierProvider).valueOrNull?.id ?? '';
  if (uid.isEmpty) {
    yield <String>{};
    return;
  }
  if (ctx.isSchool) {
    yield* db
        .watch('SELECT announcement_id FROM saved_announcements WHERE user_id = ?',
            parameters: [uid])
        .map((rows) =>
            rows.map((r) => r['announcement_id'] as String).toSet());
  } else {
    final client = ref.watch(supabaseClientProvider);
    yield* client
        .from('saved_announcements')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .map((rows) => rows.map((r) => r['announcement_id'] as String).toSet());
  }
});

/// Enregistre / retire une annonce des favoris (idempotent).
Future<void> toggleSaveScoped(
    WidgetRef ref, String annId, String groupId, bool saved) async {
  final ctx = ref.read(communicationContextProvider);
  final me  = ref.read(authNotifierProvider).valueOrNull;
  if (me == null) return;

  if (ctx.isSchool) {
    if (saved) {
      await db.execute(
        'DELETE FROM saved_announcements WHERE announcement_id = ? AND user_id = ?',
        [annId, me.id]);
    } else {
      await db.execute(
        '''INSERT OR IGNORE INTO saved_announcements
           (id, announcement_id, user_id, group_id, created_at)
           VALUES (?, ?, ?, ?, ?)''',
        [const Uuid().v4(), annId, me.id, groupId,
         DateTime.now().toIso8601String()]);
    }
  } else {
    final client = ref.read(supabaseClientProvider);
    if (saved) {
      await client
          .from('saved_announcements')
          .delete()
          .eq('announcement_id', annId)
          .eq('user_id', me.id);
    } else {
      try {
        await client.from('saved_announcements').insert({
          'announcement_id': annId,
          'user_id':         me.id,
          'group_id':        groupId,
        });
      } catch (_) {/* déjà enregistré */}
    }
  }
}

// ─── Actions réactions ────────────────────────────────────────────────────────

/// Bascule une réaction (insert si absente, delete si identique, remplace sinon).
Future<void> toggleReactionScoped(
  WidgetRef ref, {
  required String annId,
  required String groupId,
  required String reaction,
}) async {
  final ctx    = ref.read(communicationContextProvider);
  final me     = ref.read(authNotifierProvider).valueOrNull;
  if (me == null) return;
  final uid    = me.id;

  if (ctx.isSchool) {
    // Chercher réaction existante
    final existing = await db.execute(
      'SELECT id, reaction FROM announcement_reactions WHERE announcement_id = ? AND user_id = ?',
      [annId, uid],
    );
    if (existing.rows.isEmpty) {
      // Insérer
      await db.execute(
        'INSERT INTO announcement_reactions(id,announcement_id,user_id,group_id,reaction,created_at) VALUES(?,?,?,?,?,?)',
        [const Uuid().v4(), annId, uid, groupId, reaction, DateTime.now().toIso8601String()],
      );
    } else {
      final cur = existing.rows.first[1] as String?;
      if (cur == reaction) {
        // Retirer
        await db.execute(
          'DELETE FROM announcement_reactions WHERE announcement_id = ? AND user_id = ?',
          [annId, uid],
        );
      } else {
        // Changer de type
        await db.execute(
          'UPDATE announcement_reactions SET reaction = ? WHERE announcement_id = ? AND user_id = ?',
          [reaction, annId, uid],
        );
      }
    }
  } else {
    final client = ref.read(supabaseClientProvider);
    // Vérifier réaction existante
    final existing = await client
        .from('announcement_reactions')
        .select('id, reaction')
        .eq('announcement_id', annId)
        .eq('user_id', uid)
        .maybeSingle();
    if (existing == null) {
      await client.from('announcement_reactions').insert({
        'announcement_id': annId,
        'user_id':         uid,
        'group_id':        groupId,
        'reaction':        reaction,
      });
    } else if (existing['reaction'] == reaction) {
      await client.from('announcement_reactions')
          .delete()
          .eq('announcement_id', annId)
          .eq('user_id', uid);
    } else {
      await client.from('announcement_reactions')
          .update({'reaction': reaction})
          .eq('announcement_id', annId)
          .eq('user_id', uid);
    }
    // Rafraîchissement immédiat (ne dépend pas du realtime serveur).
    ref.invalidate(annReactionsProvider(annId));
    ref.invalidate(annReactionPeopleProvider(annId));
  }
}

// ─── « Qui a réagi » — liste nominative par réaction ──────────────────────────

class AnnReactionPerson {
  const AnnReactionPerson({required this.name, required this.reaction, this.role});
  final String  name;
  final String  reaction;
  final String? role;
}

/// Personnes ayant réagi à une annonce (nom + rôle + type de réaction).
/// Chargé à la demande (ouverture du détail des réactions).
final annReactionPeopleProvider = FutureProvider.autoDispose
    .family<List<AnnReactionPerson>, String>((ref, annId) async {
  final ctx = ref.watch(communicationContextProvider);

  if (ctx.isSchool) {
    final rows = await db.getAll(
      '''
      SELECT r.reaction,
             TRIM(COALESCE(p.first_name,'') || ' ' || COALESCE(p.last_name,''))
               AS name,
             p.role
        FROM announcement_reactions r
        LEFT JOIN profiles p ON p.id = r.user_id
       WHERE r.announcement_id = ?
       ORDER BY r.created_at DESC
      ''',
      [annId],
    );
    return rows
        .map((m) => AnnReactionPerson(
              name: (m['name'] as String? ?? '').trim().isEmpty
                  ? 'Membre'
                  : (m['name'] as String).trim(),
              reaction: m['reaction'] as String? ?? 'like',
              role: m['role'] as String?,
            ))
        .toList();
  }

  final client = ref.watch(supabaseClientProvider);
  final rows = await client
      .from('announcement_reactions')
      .select('reaction, profiles!user_id(first_name, last_name, role)')
      .eq('announcement_id', annId)
      .order('created_at', ascending: false) as List;
  return rows.map((r) {
    final m = r as Map;
    final p = m['profiles'] as Map? ?? const {};
    final name =
        '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}'.trim();
    return AnnReactionPerson(
      name: name.isEmpty ? 'Membre' : name,
      reaction: m['reaction'] as String? ?? 'like',
      role: p['role'] as String?,
    );
  }).toList();
});

// ─── Actions commentaires ─────────────────────────────────────────────────────

Future<void> addCommentScoped(
  WidgetRef ref, {
  required String annId,
  required String groupId,
  required String content,
  String? parentId,
}) async {
  if (content.trim().isEmpty) return;
  final ctx = ref.read(communicationContextProvider);
  final me  = ref.read(authNotifierProvider).valueOrNull;
  if (me == null) return;

  if (ctx.isSchool) {
    await db.execute(
      'INSERT INTO announcement_comments(id,announcement_id,author_id,group_id,content,parent_id,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?)',
      [
        const Uuid().v4(), annId, me.id, groupId,
        content.trim(), parentId,
        DateTime.now().toIso8601String(), DateTime.now().toIso8601String(),
      ],
    );
  } else {
    final client = ref.read(supabaseClientProvider);
    await client.from('announcement_comments').insert({
      'announcement_id': annId,
      'author_id':       me.id,
      'group_id':        groupId,
      'content':         content.trim(),
      'parent_id': ?parentId,
    });
    // Rafraîchissement immédiat (ne dépend pas du realtime serveur).
    ref.invalidate(annCommentsProvider(annId));
    ref.invalidate(annFirstCommentProvider(annId));
  }
}

/// Modifie un commentaire (auteur uniquement — RLS `ann_comment_update`).
Future<void> updateCommentScoped(
    WidgetRef ref, String commentId, String content) async {
  if (content.trim().isEmpty) return;
  final ctx = ref.read(communicationContextProvider);
  final now = DateTime.now().toIso8601String();
  if (ctx.isSchool) {
    await db.execute(
      'UPDATE announcement_comments SET content = ?, updated_at = ? WHERE id = ?',
      [content.trim(), now, commentId],
    );
  } else {
    await ref.read(supabaseClientProvider)
        .from('announcement_comments')
        .update({'content': content.trim(), 'updated_at': now})
        .eq('id', commentId);
  }
}

Future<void> deleteCommentScoped(WidgetRef ref, String commentId) async {
  final ctx = ref.read(communicationContextProvider);
  if (ctx.isSchool) {
    await db.execute(
      'DELETE FROM announcement_comments WHERE id = ?', [commentId],
    );
  } else {
    await ref.read(supabaseClientProvider)
        .from('announcement_comments')
        .delete()
        .eq('id', commentId);
  }
}

// ─── Labels réaction ─────────────────────────────────────────────────────────

const kReactions = {
  'like': ('👍', 'J\'aime'),
  'love': ('❤️', 'Adorer'),
  'clap': ('👏', 'Bravo'),
};

String reactionEmoji(String type) => kReactions[type]?.$1 ?? '👍';
String reactionLabel(String type) => kReactions[type]?.$2 ?? 'J\'aime';
