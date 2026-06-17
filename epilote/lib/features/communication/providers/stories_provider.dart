import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../auth/providers/auth_provider.dart';
import 'communication_scope.dart';

// ════════════════════════════════════════════════════════════════════════════
//  STORIES — statuts éphémères 24h (type WhatsApp), scope-aware.
//  • super_admin / admin_groupe → Supabase (online, realtime).
//  • personnel école → PowerSync (offline, db.watch).
//  Regroupées par auteur dans le bandeau ; le viewer page sur les stories d'un
//  même auteur. Lecture marquée dans story_views (« vu par »).
// ════════════════════════════════════════════════════════════════════════════

class StoryItem {
  const StoryItem({
    required this.id,
    required this.groupId,
    required this.authorId,
    required this.mediaType,
    required this.createdAt,
    required this.expiresAt,
    this.schoolId,
    this.mediaUrl,
    this.caption,
    this.textContent,
    this.bgColor,
    this.authorName,
    this.authorRole,
    this.authorAvatarUrl,
  });

  factory StoryItem.fromMap(Map<String, dynamic> m) {
    final p = m['profiles'] as Map<String, dynamic>?;
    final joinedName = p != null
        ? '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}'.trim()
        : (m['author_name'] as String?);
    return StoryItem(
      id:          m['id'] as String,
      groupId:     m['group_id'] as String? ?? '',
      schoolId:    m['school_id'] as String?,
      authorId:    m['author_id'] as String? ?? '',
      mediaType:   m['media_type'] as String? ?? 'image',
      mediaUrl:    m['media_url'] as String?,
      caption:     m['caption'] as String?,
      textContent: m['text_content'] as String?,
      bgColor:     m['bg_color'] as String?,
      createdAt:   DateTime.tryParse(m['created_at'] as String? ?? '')
                       ?.toLocal() ?? DateTime.now(),
      expiresAt:   DateTime.tryParse(m['expires_at'] as String? ?? '')
                       ?.toLocal() ?? DateTime.now(),
      authorName:  (joinedName != null && joinedName.isEmpty)
                       ? null : joinedName,
      authorRole:  p?['role'] as String? ?? m['author_role'] as String?,
      authorAvatarUrl:
          p?['avatar_url'] as String? ?? m['author_avatar_url'] as String?,
    );
  }

  final String   id, groupId, authorId, mediaType;
  final String?  schoolId, mediaUrl, caption, textContent, bgColor;
  final DateTime createdAt, expiresAt;
  final String?  authorName, authorRole, authorAvatarUrl;

  bool get isText  => mediaType == 'text';
  bool get isVideo => mediaType == 'video';
  bool get isImage => mediaType == 'image';
}

/// Groupe de stories d'un même auteur (1 anneau dans le bandeau).
class StoryGroup {
  StoryGroup(this.authorId, this.authorName, this.authorRole, this.authorAvatarUrl);
  final String  authorId;
  final String? authorName, authorRole, authorAvatarUrl;
  final List<StoryItem> items = [];

  DateTime get latest => items
      .map((s) => s.createdAt)
      .reduce((a, b) => a.isAfter(b) ? a : b);
}

/// Regroupe une liste plate de stories par auteur, triée (plus récent d'abord).
List<StoryGroup> groupStories(List<StoryItem> stories) {
  final map = <String, StoryGroup>{};
  for (final s in stories) {
    map
        .putIfAbsent(
            s.authorId,
            () => StoryGroup(
                s.authorId, s.authorName, s.authorRole, s.authorAvatarUrl))
        .items
        .add(s);
  }
  for (final g in map.values) {
    g.items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }
  final groups = map.values.toList()
    ..sort((a, b) => b.latest.compareTo(a.latest));
  return groups;
}

// ─── Stream online (fetch + JOIN profiles + realtime) ────────────────────────

Stream<List<StoryItem>> _watchStoriesOnline(
    Ref ref, SupabaseClient client, CommContext ctx) async* {
  Future<List<StoryItem>> fetch() async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    var q = client
        .from('stories')
        .select('*, profiles!author_id(first_name,last_name,avatar_url,role)')
        .gt('expires_at', nowIso);
    if (ctx.isGroup && ctx.groupId != null) {
      q = q.eq('group_id', ctx.groupId!);
    }
    final rows = await q.order('created_at', ascending: false) as List;
    return rows
        .map((r) => StoryItem.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  yield await fetch();

  final controller = StreamController<List<StoryItem>>();
  Timer? debounce;
  final channel = client.channel('stories_feed')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'stories',
        callback: (_) {
          debounce?.cancel();
          debounce = Timer(const Duration(milliseconds: 400), () async {
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

// ─── Provider unifié ─────────────────────────────────────────────────────────

final scopedStoriesProvider =
    StreamProvider.autoDispose<List<StoryItem>>((ref) async* {
  final ctx     = ref.watch(communicationContextProvider);
  final profile = ref.watch(authNotifierProvider).valueOrNull;

  if (ctx.isSchool) {
    final schoolId = profile?.schoolId ?? '';
    final nowIso   = DateTime.now().toIso8601String();
    yield* db
        .watch(
          '''
          SELECT s.*,
                 TRIM(COALESCE(p.first_name,'') || ' ' || COALESCE(p.last_name,''))
                   AS author_name,
                 p.avatar_url AS author_avatar_url,
                 p.role       AS author_role
            FROM stories s
            LEFT JOIN profiles p ON p.id = s.author_id
           WHERE s.expires_at > ?
             AND (s.school_id IS NULL OR s.school_id = ?)
           ORDER BY s.created_at DESC
          ''',
          parameters: [nowIso, schoolId],
        )
        .map((rows) => rows.map(StoryItem.fromMap).toList());
  } else {
    final client = ref.watch(supabaseClientProvider);
    yield* _watchStoriesOnline(ref, client, ctx);
  }
});

/// Stories déjà vues par l'utilisateur courant (ids) — pour l'anneau « vu ».
final viewedStoryIdsProvider =
    StreamProvider.autoDispose<Set<String>>((ref) async* {
  final ctx = ref.watch(communicationContextProvider);
  final uid = ref.watch(authNotifierProvider).valueOrNull?.id ?? '';
  if (uid.isEmpty) {
    yield <String>{};
    return;
  }
  if (ctx.isSchool) {
    yield* db
        .watch('SELECT story_id FROM story_views WHERE viewer_id = ?',
            parameters: [uid])
        .map((rows) =>
            rows.map((r) => r['story_id'] as String).toSet());
  } else {
    final client = ref.watch(supabaseClientProvider);
    yield* client
        .from('story_views')
        .stream(primaryKey: ['id'])
        .eq('viewer_id', uid)
        .map((rows) => rows.map((r) => r['story_id'] as String).toSet());
  }
});

// ─── Actions ─────────────────────────────────────────────────────────────────

/// Publie une story (image/vidéo : media_url déjà téléversé ; texte : bg+texte).
Future<void> createStoryScoped(
  WidgetRef ref, {
  required String mediaType,
  String? mediaUrl,
  String? caption,
  String? textContent,
  String? bgColor,
}) async {
  final ctx = ref.read(communicationContextProvider);
  final me  = ref.read(authNotifierProvider).valueOrNull;
  if (me == null) return;
  final now     = DateTime.now();
  final expires = now.add(const Duration(hours: 24));

  if (ctx.isSchool) {
    await db.execute(
      '''INSERT INTO stories
         (id, group_id, school_id, author_id, media_url, media_type,
          caption, text_content, bg_color, created_at, expires_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        const Uuid().v4(), me.groupId, me.schoolId, me.id, mediaUrl,
        mediaType, caption, textContent, bgColor,
        now.toIso8601String(), expires.toIso8601String(),
      ],
    );
  } else {
    final client = ref.read(supabaseClientProvider);
    await client.from('stories').insert({
      'group_id':     ctx.isGroup ? ctx.groupId : me.groupId,
      'school_id':    me.schoolId,
      'author_id':    me.id,
      'media_url':    mediaUrl,
      'media_type':   mediaType,
      'caption':      caption,
      'text_content': textContent,
      'bg_color':     bgColor,
      'expires_at':   expires.toUtc().toIso8601String(),
    });
  }
}

/// Marque une story comme vue (idempotent — UNIQUE story+viewer).
Future<void> markStoryViewed(WidgetRef ref, StoryItem story) async {
  final ctx = ref.read(communicationContextProvider);
  final me  = ref.read(authNotifierProvider).valueOrNull;
  if (me == null || story.authorId == me.id) return;

  if (ctx.isSchool) {
    await db.execute(
      '''INSERT OR IGNORE INTO story_views
         (id, story_id, group_id, viewer_id, viewed_at)
         VALUES (?, ?, ?, ?, ?)''',
      [
        const Uuid().v4(), story.id, story.groupId, me.id,
        DateTime.now().toIso8601String(),
      ],
    );
  } else {
    final client = ref.read(supabaseClientProvider);
    try {
      await client.from('story_views').insert({
        'story_id':  story.id,
        'group_id':  story.groupId,
        'viewer_id': me.id,
      });
    } catch (_) {/* doublon (déjà vu) : ignoré */}
  }
}

/// Supprime sa propre story.
Future<void> deleteStoryScoped(WidgetRef ref, String storyId) async {
  final ctx = ref.read(communicationContextProvider);
  if (ctx.isSchool) {
    await db.execute('DELETE FROM stories WHERE id = ?', [storyId]);
  } else {
    await ref.read(supabaseClientProvider)
        .from('stories')
        .delete()
        .eq('id', storyId);
  }
}
