import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../auth/providers/auth_provider.dart';
import 'communication_scope.dart';
import 'messages_provider.dart'
    show MessageAttachment, messagesProvider, groupAdminRecipient;

// ════════════════════════════════════════════════════════════════════════════
//  CHAT DE GROUPE — conversations multi-membres, scope-aware.
//  • école → offline PowerSync (db.watch conversations + membres).
//  • admin_groupe / super_admin → online Supabase (+ realtime).
//  Les MESSAGES d'une conversation sont chargés par scopedMessagesProvider
//  (déjà filtrés par conversation_id) ; ici on ne gère que les métadonnées de
//  conversation (titre, membres) et la création.
// ════════════════════════════════════════════════════════════════════════════

class ConvMember {
  const ConvMember(
      {required this.userId, this.name, this.role, this.avatarUrl});
  final String  userId;
  final String? name, role, avatarUrl;
}

class GroupConversation {
  GroupConversation({
    required this.id,
    required this.groupId,
    required this.title,
    required this.isGroup,
    required this.createdBy,
    this.schoolId,
    this.avatarUrl,
    List<ConvMember>? members,
  }) : members = members ?? [];

  final String  id, groupId, createdBy;
  final String? title, schoolId, avatarUrl;
  final bool    isGroup;
  final List<ConvMember> members;

  /// Nom d'affichage : titre explicite, sinon liste des prénoms des membres.
  String displayTitle(String myId) {
    if (title != null && title!.trim().isNotEmpty) return title!.trim();
    final others = members
        .where((m) => m.userId != myId)
        .map((m) => (m.name ?? '').split(' ').first)
        .where((n) => n.isNotEmpty)
        .toList();
    if (others.isEmpty) return 'Groupe';
    if (others.length <= 3) return others.join(', ');
    return '${others.take(3).join(', ')} +${others.length - 3}';
  }

  int get memberCount => members.length;
}

// ─── Stream online (fetch + embed + realtime) ────────────────────────────────

Stream<List<GroupConversation>> _watchConversationsOnline(
    Ref ref, SupabaseClient client, String uid) async* {
  Future<List<GroupConversation>> fetch() async {
    // 1) Mes conversations (membre).
    final memberRows = await client
        .from('conversation_members')
        .select('conversation_id')
        .eq('user_id', uid) as List;
    final ids = memberRows
        .map((r) => (r as Map)['conversation_id'] as String)
        .toList();
    if (ids.isEmpty) return [];
    // 2) Conversations + tous leurs membres (avec profils).
    final convRows = await client
        .from('conversations')
        .select('*, conversation_members(user_id, role, '
            'profiles!user_id(first_name,last_name,avatar_url,role))')
        .inFilter('id', ids)
        .order('updated_at', ascending: false) as List;
    return convRows.map((r) {
      final m = Map<String, dynamic>.from(r as Map);
      final members = (m['conversation_members'] as List? ?? []).map((mm) {
        final map = Map<String, dynamic>.from(mm as Map);
        final p = map['profiles'] as Map?;
        final name = p != null
            ? '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}'.trim()
            : null;
        return ConvMember(
          userId: map['user_id'] as String,
          name: (name == null || name.isEmpty) ? null : name,
          role: p?['role'] as String?,
          avatarUrl: p?['avatar_url'] as String?,
        );
      }).toList();
      return GroupConversation(
        id: m['id'] as String,
        groupId: m['group_id'] as String? ?? '',
        schoolId: m['school_id'] as String?,
        title: m['title'] as String?,
        isGroup: m['is_group'] as bool? ?? true,
        avatarUrl: m['avatar_url'] as String?,
        createdBy: m['created_by'] as String? ?? '',
        members: members,
      );
    }).toList();
  }

  yield await fetch();

  final controller = StreamController<List<GroupConversation>>();
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
  final channel = client.channel('group_convs_$uid')
      .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversations',
          callback: (_) => schedule())
      .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversation_members',
          callback: (_) => schedule())
      .subscribe();
  ref.onDispose(() {
    debounce?.cancel();
    client.removeChannel(channel);
    controller.close();
  });
  yield* controller.stream;
}

// ─── Provider unifié ─────────────────────────────────────────────────────────

final groupConversationsProvider =
    StreamProvider.autoDispose<List<GroupConversation>>((ref) async* {
  final ctx = ref.watch(communicationContextProvider);
  final uid = ref.watch(authNotifierProvider).valueOrNull?.id ?? '';
  if (uid.isEmpty) {
    yield const [];
    return;
  }

  if (ctx.isSchool) {
    yield* db
        .watch(
          '''
          SELECT c.*,
                 cm.user_id   AS m_user_id,
                 cm.role      AS m_role,
                 p.first_name AS m_first,
                 p.last_name  AS m_last,
                 p.avatar_url AS m_avatar,
                 p.role       AS m_profile_role
            FROM conversations c
            JOIN conversation_members cm ON cm.conversation_id = c.id
            LEFT JOIN profiles p ON p.id = cm.user_id
           WHERE c.id IN (
                   SELECT conversation_id FROM conversation_members
                   WHERE user_id = ?)
           ORDER BY c.updated_at DESC
          ''',
          parameters: [uid],
        )
        .map(_groupRowsToConversations);
  } else {
    final client = ref.watch(supabaseClientProvider);
    yield* _watchConversationsOnline(ref, client, uid);
  }
});

/// Reconstruit les conversations à partir des lignes plates (1 ligne/membre).
List<GroupConversation> _groupRowsToConversations(
    List<Map<String, dynamic>> rows) {
  final map = <String, GroupConversation>{};
  for (final r in rows) {
    final id = r['id'] as String;
    final conv = map.putIfAbsent(
        id,
        () => GroupConversation(
              id: id,
              groupId: r['group_id'] as String? ?? '',
              schoolId: r['school_id'] as String?,
              title: r['title'] as String?,
              isGroup: r['is_group'] == 1 || r['is_group'] == true,
              avatarUrl: r['avatar_url'] as String?,
              createdBy: r['created_by'] as String? ?? '',
            ));
    final muid = r['m_user_id'] as String?;
    if (muid != null && !conv.members.any((m) => m.userId == muid)) {
      final name =
          '${r['m_first'] ?? ''} ${r['m_last'] ?? ''}'.trim();
      conv.members.add(ConvMember(
        userId: muid,
        name: name.isEmpty ? null : name,
        role: r['m_profile_role'] as String?,
        avatarUrl: r['m_avatar'] as String?,
      ));
    }
  }
  return map.values.toList();
}

// ─── Actions ─────────────────────────────────────────────────────────────────

/// Crée une conversation de groupe (moi = admin + membres choisis).
/// Renvoie l'id de la conversation créée.
Future<String> createGroupConversationScoped(
  WidgetRef ref, {
  required String title,
  required List<String> memberIds,
}) async {
  final ctx = ref.read(communicationContextProvider);
  final me  = ref.read(authNotifierProvider).valueOrNull;
  if (me == null) throw StateError('Session invalide.');
  final convId = const Uuid().v4();
  final now    = DateTime.now().toIso8601String();

  // ── Plateforme (super_admin) : les « membres » choisis sont des GROUPES.
  //   On résout chacun vers son admin (user) et on ancre la conversation au
  //   1er groupe (group_id NOT NULL ; RLS : super_admin autorisé). ──────────
  if (ctx.isPlatform) {
    final client = ref.read(supabaseClientProvider);
    String? anchorGroup;
    final adminIds = <String>[];
    for (final gid in memberIds) {
      anchorGroup ??= gid;
      final adminId = await groupAdminRecipient(client, gid);
      if (adminId != null && adminId != me.id) adminIds.add(adminId);
    }
    if (anchorGroup == null) throw StateError('Aucun groupe sélectionné.');
    await client.from('conversations').insert({
      'id':         convId,
      'group_id':   anchorGroup,
      'title':      title.trim(),
      'is_group':   true,
      'created_by': me.id,
    });
    await client.from('conversation_members').insert({
      'conversation_id': convId,
      'user_id':         me.id,
      'group_id':        anchorGroup,
      'role':            'admin',
    });
    if (adminIds.isNotEmpty) {
      await client.from('conversation_members').insert([
        for (final u in adminIds.toSet())
          {
            'conversation_id': convId,
            'user_id':         u,
            'group_id':        anchorGroup,
            'role':            'member',
          }
      ]);
    }
    ref.invalidate(groupConversationsProvider);
    return convId;
  }

  final allMembers = {me.id, ...memberIds}.toList();
  final groupId = ctx.groupId ?? me.groupId;

  if (ctx.isSchool) {
    await db.execute(
      '''INSERT INTO conversations
         (id, group_id, school_id, title, is_group, created_by, created_at, updated_at)
         VALUES (?, ?, ?, ?, 1, ?, ?, ?)''',
      [convId, groupId, me.schoolId, title.trim(), me.id, now, now],
    );
    for (final m in allMembers) {
      await db.execute(
        '''INSERT INTO conversation_members
           (id, conversation_id, user_id, group_id, role, joined_at)
           VALUES (?, ?, ?, ?, ?, ?)''',
        [const Uuid().v4(), convId, m, groupId, m == me.id ? 'admin' : 'member', now],
      );
    }
  } else {
    final client = ref.read(supabaseClientProvider);
    await client.from('conversations').insert({
      'id':         convId,
      'group_id':   groupId,
      'school_id':  me.schoolId,
      'title':      title.trim(),
      'is_group':   true,
      'created_by': me.id,
    });
    // Le créateur d'abord (RLS : user_id = auth.uid()), puis les autres membres
    // (RLS : is_conversation_creator). Sépare les deux inserts pour que la
    // policy conv_members_insert passe à coup sûr.
    await client.from('conversation_members').insert({
      'conversation_id': convId,
      'user_id':         me.id,
      'group_id':        groupId,
      'role':            'admin',
    });
    final others = allMembers.where((m) => m != me.id).toList();
    if (others.isNotEmpty) {
      await client.from('conversation_members').insert([
        for (final m in others)
          {
            'conversation_id': convId,
            'user_id':         m,
            'group_id':        groupId,
            'role':            'member',
          }
      ]);
    }
    // Affiche la nouvelle conversation immédiatement (sans attendre le Realtime).
    ref.invalidate(groupConversationsProvider);
  }
  return convId;
}

/// Envoie un message dans une conversation de groupe (recipient_id NULL).
Future<void> sendGroupMessageScoped(
  WidgetRef ref, {
  required String conversationId,
  required String groupId,
  required String body,
  List<MessageAttachment> attachments = const [],
  String? parentId,
}) async {
  final text = body.trim();
  if (text.isEmpty && attachments.isEmpty) return;
  final ctx = ref.read(communicationContextProvider);
  final me  = ref.read(authNotifierProvider).valueOrNull;
  if (me == null) return;
  final now = DateTime.now().toIso8601String();

  if (ctx.isSchool) {
    await db.execute(
      '''INSERT INTO messages
         (id, group_id, sender_id, conversation_id, body, parent_message_id,
          is_read, is_archived, attachments, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, 0, 0, ?, ?, ?)''',
      [
        const Uuid().v4(), groupId, me.id, conversationId, text, parentId,
        jsonEncode(attachments.map((a) => a.toJson()).toList()), now, now,
      ],
    );
    await db.execute(
      'UPDATE conversations SET updated_at = ? WHERE id = ?', [now, conversationId]);
  } else {
    final client = ref.read(supabaseClientProvider);
    await client.from('messages').insert({
      'group_id':         groupId,
      'sender_id':        me.id,
      'conversation_id':  conversationId,
      'body':             text,
      'parent_message_id': parentId,
      'is_read':          false,
      'is_archived':      false,
      'attachments':      attachments.map((a) => a.toJson()).toList(),
    });
    await client.from('conversations')
        .update({'updated_at': now}).eq('id', conversationId);
    // Rendu instantané côté expéditeur (sans attendre le Realtime).
    ref.invalidate(messagesProvider);
  }
}

// ─── Paramètres du groupe (renommer / avatar / membres / suppression) ─────────

/// Renomme une conversation de groupe. RLS `conv_update` : tout membre autorisé
/// (l'UI restreint au créateur). school → PowerSync, sinon Supabase.
Future<void> renameGroupConversationScoped(
    WidgetRef ref, String convId, String title) async {
  final ctx = ref.read(communicationContextProvider);
  final now = DateTime.now().toIso8601String();
  final t   = title.trim();
  if (t.isEmpty) return;
  if (ctx.isSchool) {
    await db.execute(
        'UPDATE conversations SET title = ?, updated_at = ? WHERE id = ?',
        [t, now, convId]);
  } else {
    await ref.read(supabaseClientProvider)
        .from('conversations')
        .update({'title': t, 'updated_at': now}).eq('id', convId);
    ref.invalidate(groupConversationsProvider);
  }
}

/// Persiste l'avatar (URL signée longue durée déjà téléversée) du groupe.
Future<void> updateGroupAvatarScoped(
    WidgetRef ref, String convId, String? avatarUrl) async {
  final ctx = ref.read(communicationContextProvider);
  final now = DateTime.now().toIso8601String();
  if (ctx.isSchool) {
    await db.execute(
        'UPDATE conversations SET avatar_url = ?, updated_at = ? WHERE id = ?',
        [avatarUrl, now, convId]);
  } else {
    await ref.read(supabaseClientProvider)
        .from('conversations')
        .update({'avatar_url': avatarUrl, 'updated_at': now}).eq('id', convId);
    ref.invalidate(groupConversationsProvider);
  }
}

/// Ajoute des membres à une conversation de groupe. Renvoie le nombre réellement
/// ajouté (côté plateforme, un groupe sans administrateur ne résout personne).
Future<int> addGroupMembersScoped(
  WidgetRef ref, {
  required String convId,
  required String groupId,
  required List<String> userIds,
}) async {
  if (userIds.isEmpty) return 0;
  final ctx = ref.read(communicationContextProvider);
  final now = DateTime.now().toIso8601String();
  if (ctx.isSchool) {
    final set = userIds.toSet();
    for (final u in set) {
      await db.execute(
        '''INSERT OR IGNORE INTO conversation_members
           (id, conversation_id, user_id, group_id, role, joined_at)
           VALUES (?, ?, ?, ?, 'member', ?)''',
        [const Uuid().v4(), convId, u, groupId, now],
      );
    }
    return set.length;
  } else {
    final client = ref.read(supabaseClientProvider);
    // Plateforme : les ids choisis sont des GROUPES → résoudre vers leur admin.
    final resolved = <String>{};
    if (ctx.isPlatform) {
      for (final gid in userIds.toSet()) {
        final adminId = await groupAdminRecipient(client, gid);
        if (adminId != null) resolved.add(adminId);
      }
    } else {
      resolved.addAll(userIds.toSet());
    }
    if (resolved.isEmpty) return 0;
    // Idempotent : UNIQUE(conversation_id,user_id) → un membre déjà présent est
    // ignoré (re-sélection d'un groupe déjà ajouté côté plateforme).
    await client.from('conversation_members').upsert(
      [
        for (final u in resolved)
          {
            'conversation_id': convId,
            'user_id':         u,
            'group_id':        groupId,
            'role':            'member',
          }
      ],
      onConflict: 'conversation_id,user_id',
      ignoreDuplicates: true,
    );
    ref.invalidate(groupConversationsProvider);
    return resolved.length;
  }
}

/// Retire un membre (ou se retire soi-même = quitter le groupe).
Future<void> removeGroupMemberScoped(
  WidgetRef ref, {
  required String convId,
  required String userId,
}) async {
  final ctx = ref.read(communicationContextProvider);
  if (ctx.isSchool) {
    await db.execute(
        'DELETE FROM conversation_members WHERE conversation_id = ? AND user_id = ?',
        [convId, userId]);
  } else {
    await ref.read(supabaseClientProvider)
        .from('conversation_members')
        .delete()
        .eq('conversation_id', convId)
        .eq('user_id', userId);
    ref.invalidate(groupConversationsProvider);
  }
}

/// Supprime entièrement une conversation de groupe (créateur / super_admin).
/// RLS `conv_delete` ; FK ON DELETE CASCADE purge membres + messages.
Future<void> deleteConversationScoped(WidgetRef ref, String convId) async {
  final ctx = ref.read(communicationContextProvider);
  if (ctx.isSchool) {
    // Purge locale immédiate (le serveur cascade de son côté à la sync).
    await db.execute('DELETE FROM messages WHERE conversation_id = ?', [convId]);
    await db.execute(
        'DELETE FROM conversation_members WHERE conversation_id = ?', [convId]);
    await db.execute('DELETE FROM conversations WHERE id = ?', [convId]);
  } else {
    await ref.read(supabaseClientProvider)
        .from('conversations')
        .delete()
        .eq('id', convId);
    ref.invalidate(groupConversationsProvider);
    ref.invalidate(messagesProvider);
  }
}

/// Supprime une discussion 1-à-1 : efface tous les messages échangés avec
/// l'interlocuteur (RLS `msg_delete` : expéditeur ou destinataire).
Future<void> deleteDirectConversationScoped(
    WidgetRef ref, List<String> messageIds) async {
  if (messageIds.isEmpty) return;
  final ctx = ref.read(communicationContextProvider);
  if (ctx.isSchool) {
    for (final id in messageIds) {
      await db.execute('DELETE FROM messages WHERE id = ?', [id]);
    }
  } else {
    final client = ref.read(supabaseClientProvider);
    await client.from('messages').delete().inFilter('id', messageIds);
    ref.invalidate(messagesProvider);
  }
}
