import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../features/auth/providers/auth_provider.dart';
import '../../../services/powersync/powersync_service.dart';
import 'communication_scope.dart';

// ─── Modèles ──────────────────────────────────────────────────────────────────

/// Pièce jointe d'un message (image · audio · fichier). Stockée en jsonb.
/// `path`/`bucket` (Storage privé) permettent de re-signer une URL à l'affichage
/// — `url` n'est qu'un signed URL longue durée (fallback + cache hors-ligne).
class MessageAttachment {
  const MessageAttachment({
    required this.url,
    required this.name,
    required this.mime,
    required this.size,
    required this.kind,
    this.path,
    this.bucket,
  });

  factory MessageAttachment.fromJson(Map j) => MessageAttachment(
        url:  j['url'] as String? ?? '',
        name: j['name'] as String? ?? 'fichier',
        mime: j['mime'] as String? ?? 'application/octet-stream',
        size: (j['size'] as num?)?.toInt() ?? 0,
        kind: j['kind'] as String? ?? kindFor(j['mime'] as String? ?? ''),
        path:   j['path'] as String?,
        bucket: j['bucket'] as String?,
      );

  final String  url;
  final String  name;
  final String  mime;
  final int     size;
  final String  kind; // 'image' | 'audio' | 'video' | 'file'
  /// Chemin Storage ({groupId}/{uuid}_{nom}) — pour re-signer une URL.
  final String? path;
  /// Bucket Storage (message-attachments / communication-attachments).
  final String? bucket;

  bool get isImage => kind == 'image';
  bool get isAudio => kind == 'audio';
  bool get isVideo => kind == 'video';

  /// Clé de cache stable (= chemin) — survit à la rotation des signed URLs,
  /// d'où la persistance hors-ligne des images déjà vues.
  String get cacheKey => resolvedPath ?? url;

  /// Chemin Storage effectif : champ explicite OU déduit d'une vieille URL
  /// publique/signée (`/object/(public|sign)/{bucket}/{path}`).
  String? get resolvedPath {
    if (path != null && path!.isNotEmpty) return path;
    return _parse(url)?.$2;
  }

  /// Bucket effectif : champ explicite OU déduit de l'URL.
  String? get resolvedBucket {
    if (bucket != null && bucket!.isNotEmpty) return bucket;
    return _parse(url)?.$1;
  }

  /// Extrait (bucket, path) d'une URL Storage publique ou signée.
  static (String, String)? _parse(String u) {
    for (final marker in ['/object/public/', '/object/sign/']) {
      final i = u.indexOf(marker);
      if (i < 0) continue;
      var rest = u.substring(i + marker.length);
      final q = rest.indexOf('?');
      if (q >= 0) rest = rest.substring(0, q);
      final slash = rest.indexOf('/');
      if (slash <= 0) continue;
      return (rest.substring(0, slash), rest.substring(slash + 1));
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        'name': name,
        'mime': mime,
        'size': size,
        'kind': kind,
        if (path != null) 'path': path,
        if (bucket != null) 'bucket': bucket,
      };

  static String kindFor(String mime) {
    if (mime.startsWith('image/')) return 'image';
    if (mime.startsWith('audio/')) return 'audio';
    if (mime.startsWith('video/')) return 'video';
    return 'file';
  }

  /// Déduit un type MIME à partir de l'extension de fichier.
  static String mimeForExtension(String? ext) {
    switch ((ext ?? '').toLowerCase()) {
      case 'png':  return 'image/png';
      case 'jpg':
      case 'jpeg': return 'image/jpeg';
      case 'gif':  return 'image/gif';
      case 'webp': return 'image/webp';
      case 'heic': return 'image/heic';
      case 'mp3':  return 'audio/mpeg';
      case 'm4a':  return 'audio/mp4';
      case 'aac':  return 'audio/aac';
      case 'wav':  return 'audio/wav';
      case 'ogg':
      case 'opus': return 'audio/ogg';
      case 'mp4':  return 'video/mp4';
      case 'mkv':  return 'video/x-matroska';
      case 'webm': return 'video/webm';
      case 'avi':  return 'video/x-msvideo';
      case 'mov':  return 'video/quicktime';
      case 'pdf':  return 'application/pdf';
      case 'doc':
      case 'docx': return 'application/msword';
      case 'xls':
      case 'xlsx': return 'application/vnd.ms-excel';
      case 'ppt':
      case 'pptx': return 'application/vnd.ms-powerpoint';
      case 'odt':  return 'application/vnd.oasis.opendocument.text';
      case 'ods':  return 'application/vnd.oasis.opendocument.spreadsheet';
      case 'odp':  return 'application/vnd.oasis.opendocument.presentation';
      case 'txt':  return 'text/plain';
      case 'csv':  return 'text/csv';
      default:     return 'application/octet-stream';
    }
  }
}

class MessageModel {
  const MessageModel({
    required this.id,
    required this.subject,
    required this.body,
    required this.senderId,
    required this.senderName,
    required this.recipientId,
    required this.recipientName,
    required this.groupId,
    required this.groupName,
    required this.isRead,
    required this.isArchived,
    required this.insertedAt,
    this.attachments = const [],
    this.parentId,
    this.conversationId,
    this.senderRole,
    this.recipientRole,
    this.senderAvatarUrl,
    this.recipientAvatarUrl,
    this.readAt,
    this.reactions = const {},
    this.editedAt,
  });

  final String  id;
  final String  subject;
  final String  body;
  final String  senderId;
  final String  senderName;
  final String  recipientId;
  final String  recipientName;
  final String  groupId;
  final String  groupName;
  final bool    isRead;
  final bool    isArchived;
  final String  insertedAt;
  final List<MessageAttachment> attachments;
  final String? parentId;

  /// Conversation de groupe (null = message privé 1-à-1).
  final String? conversationId;
  bool get isGroupMessage => conversationId != null && conversationId!.isNotEmpty;

  /// Rôles (identité visuelle : couleur d'avatar, libellé sous le nom).
  final String? senderRole;
  final String? recipientRole;

  /// Photos de profil (avatar_url) — pour l'affichage des bulles/listes.
  final String? senderAvatarUrl;
  final String? recipientAvatarUrl;

  /// Date de lecture (accusé de lecture) — renseignée côté local uniquement.
  final String? readAt;

  /// Réactions emoji : { "👍": ["uid1","uid2"], "❤️": ["uid3"] }.
  final Map<String, List<String>> reactions;

  /// Horodatage de dernière édition (null = jamais modifié).
  final String? editedAt;

  bool get isEdited => editedAt != null && editedAt!.isNotEmpty;

  /// Total des réactions, toutes émojis confondues.
  int get reactionCount =>
      reactions.values.fold(0, (s, list) => s + list.length);

  /// Libellé de l'interlocuteur du point de vue de [myId].
  String counterpart(String myId) {
    if (senderId == myId) {
      return recipientName.isNotEmpty ? recipientName : groupName;
    }
    return senderName.isNotEmpty ? senderName : groupName;
  }

  /// Rôle de l'interlocuteur du point de vue de [myId].
  String? counterpartRole(String myId) =>
      senderId == myId ? recipientRole : senderRole;

  /// Photo de l'interlocuteur du point de vue de [myId].
  String? counterpartAvatarUrl(String myId) =>
      senderId == myId ? recipientAvatarUrl : senderAvatarUrl;
}

class MessagesData {
  const MessagesData({
    required this.messages,
    required this.totalCount,
    required this.unreadCount,
    required this.archivedCount,
  });

  final List<MessageModel> messages;
  final int                totalCount;
  final int                unreadCount;
  final int                archivedCount;
}

/// Destinataire possible pour la composition (scope-aware).
class RecipientOption {
  const RecipientOption({required this.value, required this.label, this.subtitle});
  final String  value;   // platform → groupId · group → userId
  final String  label;
  final String? subtitle;
}

// ─── Providers ────────────────────────────────────────────────────────────────

final messagesFilterProvider = StateProvider.autoDispose<String>((ref) => 'inbox');

String _fullName(Map? p, String fallback) {
  if (p == null) return fallback;
  final n = '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}'.trim();
  return n.isNotEmpty ? n : fallback;
}

/// Parse les pièces jointes depuis Postgres (List jsonb) OU SQLite local
/// (TEXT contenant le JSON). Public : réutilisé par annonces/événements.
List<MessageAttachment> parseAttachments(dynamic raw) {
  var v = raw;
  if (v is String && v.isNotEmpty) {
    try {
      v = jsonDecode(v);
    } catch (_) {
      return const [];
    }
  }
  if (v is List) {
    return v
        .whereType<Map>()
        .map(MessageAttachment.fromJson)
        .where((a) => a.url.isNotEmpty)
        .toList();
  }
  return const [];
}

/// Parse les réactions emoji depuis Postgres (Map jsonb) OU SQLite local (TEXT).
/// Forme attendue : { "👍": ["uid1","uid2"], ... }. Public (réutilisable).
Map<String, List<String>> parseReactions(dynamic raw) {
  var v = raw;
  if (v is String && v.isNotEmpty) {
    try {
      v = jsonDecode(v);
    } catch (_) {
      return const {};
    }
  }
  if (v is Map) {
    final out = <String, List<String>>{};
    v.forEach((k, val) {
      if (val is List) {
        final ids = val.whereType<String>().toList();
        if (ids.isNotEmpty) out['$k'] = ids;
      }
    });
    return out;
  }
  return const {};
}

final messagesProvider = FutureProvider.autoDispose<MessagesData>((ref) async {
  ref.keepAlive();
  final client = ref.watch(supabaseClientProvider);
  final ctx    = ref.watch(communicationContextProvider);

  // ── Realtime : nouveaux messages / lectures / archivages en direct ──────────
  Timer? debounce;
  void scheduleInvalidate() {
    debounce?.cancel();
    debounce =
        Timer(const Duration(milliseconds: 400), () => ref.invalidateSelf());
  }
  try {
    final channel = client.channel('comm_messages_list')
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

  var query = client.from('messages').select(
    'id, subject, body, sender_id, recipient_id, conversation_id, group_id, '
    'is_read, is_archived, created_at, parent_message_id, attachments, read_at, '
    'reactions, edited_at, '
    'school_groups!group_id(name), '
    'sender:profiles!sender_id(first_name,last_name,role,avatar_url), '
    'recipient:profiles!recipient_id(first_name,last_name,role,avatar_url)',
  );
  // Périmètre groupe (admin_groupe) — la plateforme voit tout via RLS.
  if (ctx.isGroup && ctx.groupId != null) {
    query = query.eq('group_id', ctx.groupId!);
  }

  final rows = await query.order('created_at', ascending: false).limit(300);

  final messages = (rows as List).map((r) {
    final m = r as Map;
    final sg = m['school_groups'] as Map? ?? const {};
    return MessageModel(
      id:            m['id'] as String,
      subject:       m['subject'] as String? ?? '(Sans objet)',
      body:          m['body'] as String? ?? '',
      senderId:      m['sender_id'] as String? ?? '',
      senderName:    _fullName(m['sender'] as Map?, 'Expéditeur'),
      recipientId:   m['recipient_id'] as String? ?? '',
      recipientName: _fullName(m['recipient'] as Map?, 'Destinataire'),
      groupId:       m['group_id'] as String? ?? '',
      groupName:     sg['name'] as String? ?? '—',
      isRead:         m['is_read'] as bool? ?? false,
      isArchived:     m['is_archived'] as bool? ?? false,
      insertedAt:     m['created_at'] as String? ?? '',
      attachments:    parseAttachments(m['attachments']),
      parentId:       m['parent_message_id'] as String?,
      conversationId: m['conversation_id'] as String?,
      senderRole:     (m['sender'] as Map?)?['role'] as String?,
      recipientRole:  (m['recipient'] as Map?)?['role'] as String?,
      senderAvatarUrl:    (m['sender'] as Map?)?['avatar_url'] as String?,
      recipientAvatarUrl: (m['recipient'] as Map?)?['avatar_url'] as String?,
      readAt:         m['read_at'] as String?,
      reactions:      parseReactions(m['reactions']),
      editedAt:       m['edited_at'] as String?,
    );
  }).toList();

  return MessagesData(
    messages:      messages,
    totalCount:    messages.length,
    unreadCount:   messages.where((m) => !m.isRead && !m.isArchived).length,
    archivedCount: messages.where((m) => m.isArchived).length,
  );
});

// ════════════════════════════════════════════════════════════════════════════
//  PERSONNEL ÉCOLE — messagerie offline-first (PowerSync, texte uniquement).
//  Lecture/écriture 100 % locale ; noms résolus via l'annuaire `school_directory`
//  (profiles synchronisés de l'école). Pas de pièces jointes hors-ligne.
// ════════════════════════════════════════════════════════════════════════════

/// Messages du membre (envoyés OU reçus), réactif depuis SQLite, avec noms.
final myMessagesProvider = StreamProvider.autoDispose<MessagesData>((ref) {
  final uid = ref.watch(authNotifierProvider).valueOrNull?.id ?? '';
  if (uid.isEmpty) {
    return Stream.value(const MessagesData(
        messages: [], totalCount: 0, unreadCount: 0, archivedCount: 0));
  }
  return db
      .watch(
        '''SELECT m.*,
                  sp.first_name AS s_fn, sp.last_name AS s_ln, sp.role AS s_role,
                  sp.avatar_url AS s_avatar,
                  rp.first_name AS r_fn, rp.last_name AS r_ln, rp.role AS r_role,
                  rp.avatar_url AS r_avatar
           FROM messages m
           LEFT JOIN profiles sp ON sp.id = m.sender_id
           LEFT JOIN profiles rp ON rp.id = m.recipient_id
           WHERE m.sender_id = ? OR m.recipient_id = ?
              OR m.conversation_id IN (
                   SELECT conversation_id FROM conversation_members
                   WHERE user_id = ?)
           ORDER BY m.created_at DESC''',
        parameters: [uid, uid, uid],
      )
      .map((rows) {
        final messages = rows.map(_msgFromLocalRow).toList();
        return MessagesData(
          messages:      messages,
          totalCount:    messages.length,
          unreadCount:   messages
              .where((m) => !m.isRead && !m.isArchived && m.recipientId == uid)
              .length,
          archivedCount: messages.where((m) => m.isArchived).length,
        );
      });
});

MessageModel _msgFromLocalRow(Map<String, dynamic> m) {
  String nm(Object? fn, Object? ln, String fb) {
    final n = '${fn ?? ''} ${ln ?? ''}'.trim();
    return n.isEmpty ? fb : n;
  }
  return MessageModel(
    id:            m['id'] as String,
    subject:       m['subject'] as String? ?? '(Sans objet)',
    body:          m['body'] as String? ?? '',
    senderId:      m['sender_id'] as String? ?? '',
    senderName:    nm(m['s_fn'], m['s_ln'], 'Expéditeur'),
    recipientId:   m['recipient_id'] as String? ?? '',
    recipientName: nm(m['r_fn'], m['r_ln'], 'Destinataire'),
    groupId:       m['group_id'] as String? ?? '',
    groupName:     '',
    isRead:         m['is_read'] == 1 || m['is_read'] == true,
    isArchived:     m['is_archived'] == 1 || m['is_archived'] == true,
    insertedAt:     m['created_at'] as String? ?? '',
    attachments:    parseAttachments(m['attachments']),
    parentId:       m['parent_message_id'] as String?,
    conversationId: m['conversation_id'] as String?,
    senderRole:     m['s_role'] as String?,
    recipientRole:  m['r_role'] as String?,
    senderAvatarUrl:    m['s_avatar'] as String?,
    recipientAvatarUrl: m['r_avatar'] as String?,
    readAt:         m['read_at'] as String?,
    reactions:      parseReactions(m['reactions']),
    editedAt:       m['edited_at'] as String?,
  );
}

/// Annuaire des collègues de MON école (destinataires possibles), hors moi-même.
/// Vide tant que la stream `school_directory` n'est pas déployée/synchronisée.
final schoolDirectoryProvider =
    StreamProvider.autoDispose<List<RecipientOption>>((ref) {
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final uid    = profile?.id ?? '';
  final school = profile?.schoolId ?? '';
  if (uid.isEmpty || school.isEmpty) return Stream.value(const []);
  return db
      .watch(
        '''SELECT id, first_name, last_name, role FROM profiles
           WHERE school_id = ? AND id != ?
           ORDER BY last_name, first_name''',
        parameters: [school, uid],
      )
      .map((rows) => rows
          .map((m) => RecipientOption(
                value:    m['id'] as String,
                label:    '${m['first_name'] ?? ''} ${m['last_name'] ?? ''}'.trim(),
                subtitle: m['role'] as String?,
              ))
          .where((o) => o.label.isNotEmpty)
          .toList());
});

// ─── Actions locales (offline-first) ────────────────────────────────────────────

Future<void> markMessageReadLocal(String id) async {
  final now = DateTime.now().toIso8601String();
  await db.execute(
    'UPDATE messages SET is_read = 1, read_at = ?, updated_at = ? WHERE id = ?',
    [now, now, id],
  );
}

/// Marque un message local comme NON lu (is_read=0, read_at remis à NULL).
Future<void> markMessageUnreadLocal(String id) async {
  final now = DateTime.now().toIso8601String();
  await db.execute(
    'UPDATE messages SET is_read = 0, read_at = NULL, updated_at = ? WHERE id = ?',
    [now, id],
  );
}

/// Archive (ou désarchive) un message local. À appliquer à chaque message
/// d'un fil pour archiver la conversation entière.
Future<void> archiveMessageLocal(String id, bool archived) async {
  final now = DateTime.now().toIso8601String();
  await db.execute(
    'UPDATE messages SET is_archived = ?, updated_at = ? WHERE id = ?',
    [archived ? 1 : 0, now, id],
  );
}

Future<void> sendMessageLocal({
  required String senderId,
  required String recipientId,
  required String groupId,
  required String subject,
  required String body,
  List<MessageAttachment> attachments = const [],
  String? parentId,
}) async {
  final id  = const Uuid().v4();
  final now = DateTime.now().toIso8601String();
  await db.execute(
    '''INSERT INTO messages
       (id, group_id, sender_id, recipient_id, subject, body,
        is_read, is_archived, attachments, parent_message_id,
        created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, 0, 0, ?, ?, ?, ?)''',
    [id, groupId, senderId, recipientId, subject.trim(), body.trim(),
     jsonEncode(attachments.map((a) => a.toJson()).toList()),
     parentId, now, now],
  );
}

/// Destinataires possibles selon le périmètre :
/// - plateforme → groupes scolaires (recipient = admin du groupe, résolu à l'envoi)
/// - groupe     → utilisateurs actifs du groupe (recipient = l'utilisateur)
final messageRecipientsProvider =
    FutureProvider.autoDispose<List<RecipientOption>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final ctx    = ref.watch(communicationContextProvider);

  if (ctx.isGroup && ctx.groupId != null) {
    final myId = client.auth.currentUser?.id;
    final rows = await client
        .rpc('get_group_users', params: {'p_group_id': ctx.groupId}) as List;
    return rows
        .map((r) => r as Map)
        .where((m) => m['id'] != myId && (m['is_active'] as bool? ?? true))
        .map((m) => RecipientOption(
              value:    m['id'] as String,
              label:    _fullName(m, '—'),
              subtitle: (m['school_name'] as String?) ??
                  (m['access_profile_name'] as String?) ??
                  (m['role'] as String?),
            ))
        .toList();
  }

  // Plateforme : liste des groupes
  final rows = await client
      .from('school_groups')
      .select('id, name')
      .order('name');
  return (rows as List)
      .map((r) => r as Map)
      .map((m) => RecipientOption(
            value: m['id'] as String,
            label: m['name'] as String? ?? '—',
          ))
      .toList();
});

/// Reconstruit le fil de conversation contenant [m] à partir de la liste
/// chargée : remonte la chaîne `parentId` jusqu'à la racine puis collecte
/// tous les messages du fil, triés par date croissante.
List<MessageModel> threadOf(List<MessageModel> all, MessageModel m) {
  final byId = {for (final x in all) x.id: x};

  String rootOf(MessageModel x) {
    var cur = x;
    final seen = <String>{};
    while (cur.parentId != null &&
        byId.containsKey(cur.parentId) &&
        seen.add(cur.id)) {
      cur = byId[cur.parentId]!;
    }
    return cur.id;
  }

  final root = rootOf(m);
  final thread = all.where((x) => rootOf(x) == root).toList()
    ..sort((a, b) => a.insertedAt.compareTo(b.insertedAt));
  return thread.isEmpty ? [m] : thread;
}

/// Sujet de base d'un fil (sans les préfixes « RE: » accumulés).
String baseSubject(String subject) {
  var s = subject.trim();
  final re = RegExp(r'^(re|rép|rep)\s*:\s*', caseSensitive: false);
  while (re.hasMatch(s)) {
    s = s.replaceFirst(re, '').trim();
  }
  return s.isEmpty ? subject : s;
}

// ─── Actions ──────────────────────────────────────────────────────────────────

Future<void> markMessageRead(dynamic client, String id) async {
  await client.from('messages').update({
    'is_read': true,
    'read_at': DateTime.now().toIso8601String(),
    'updated_at': DateTime.now().toIso8601String(),
  }).eq('id', id);
}

Future<void> markMessageUnread(dynamic client, String id) async {
  await client.from('messages').update({
    'is_read': false,
    'read_at': null,
    'updated_at': DateTime.now().toIso8601String(),
  }).eq('id', id);
}

Future<void> deleteMessage(dynamic client, String id) async {
  await client.from('messages').delete().eq('id', id);
}

Future<void> archiveMessage(dynamic client, String id) async {
  await client.from('messages').update({
    'is_archived': true,
    'updated_at':  DateTime.now().toIso8601String(),
  }).eq('id', id);
}

Future<void> unarchiveMessage(dynamic client, String id) async {
  await client.from('messages').update({
    'is_archived': false,
    'updated_at':  DateTime.now().toIso8601String(),
  }).eq('id', id);
}

/// Téléverse une pièce jointe (bucket `message-attachments` par défaut,
/// `communication-attachments` pour annonces/événements) et renvoie ses
/// métadonnées. Chemin imprévisible : `{groupId}/{uuid}_{nom}`.
/// ⚠️ Nécessite une connexion internet (Supabase Storage).
Future<MessageAttachment> uploadMessageAttachment({
  required SupabaseClient client,
  required String groupId,
  required String fileName,
  required Uint8List bytes,
  required String mime,
  String bucket = 'message-attachments',
}) async {
  final safeName = fileName.replaceAll(RegExp(r'[^\w\.\-]+'), '_');
  // Dossier = groupe (RLS Storage). Vide pour super_admin sans groupe.
  final folder = groupId.isEmpty ? 'platform' : groupId;
  final path = '$folder/${const Uuid().v4()}_$safeName';
  await client.storage.from(bucket).uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(contentType: mime, upsert: false),
      );
  // Bucket privé → signed URL longue durée (1 an) : fallback d'affichage + cache
  // hors-ligne. L'affichage re-signe au besoin via `signedAttachmentUrlProvider`.
  final url = await client.storage
      .from(bucket)
      .createSignedUrl(path, 31536000);
  return MessageAttachment(
    url:    url,
    name:   fileName,
    mime:   mime,
    size:   bytes.length,
    kind:   MessageAttachment.kindFor(mime),
    path:   path,
    bucket: bucket,
  );
}

/// Cache mémoire des URLs signées (bucket privé) — évite de re-signer à chaque
/// rendu. TTL 50 min (signed URL valable 1 h).
final _signedUrlCache = <String, ({String url, DateTime exp})>{};

/// URL signée DÉJÀ en cache (synchrone) — null si à (re)signer. Permet à
/// l'affichage d'éviter le spinner quand un contenu a déjà été ouvert une fois
/// (réouverture instantanée d'un chat, pas de rechargement).
String? cachedSignedUrl(MessageAttachment att) {
  final bucket = att.resolvedBucket;
  final path   = att.resolvedPath;
  // Legacy (URL publique/signée déjà complète) → utilisable telle quelle.
  if (bucket == null || path == null) return att.url;
  final hit = _signedUrlCache['$bucket::$path'];
  if (hit != null && hit.exp.isAfter(DateTime.now())) return hit.url;
  return null;
}

/// Re-signe une URL d'accès à une pièce jointe (bucket privé), avec cache.
/// En cas d'échec (hors-ligne), renvoie l'URL de secours stockée — combinée à
/// `cacheKey`, l'image/le fichier déjà vu reste affichable.
Future<String> resolveAttachmentUrl(
    SupabaseClient client, MessageAttachment att) async {
  final bucket = att.resolvedBucket;
  final path   = att.resolvedPath;
  if (bucket == null || path == null) return att.url;
  final key = '$bucket::$path';
  final hit = _signedUrlCache[key];
  if (hit != null && hit.exp.isAfter(DateTime.now())) return hit.url;
  try {
    final u = await client.storage.from(bucket).createSignedUrl(path, 3600);
    _signedUrlCache[key] =
        (url: u, exp: DateTime.now().add(const Duration(minutes: 50)));
    return u;
  } catch (_) {
    return att.url; // hors-ligne : on retombe sur l'URL stockée (+ cacheKey).
  }
}

/// Résout l'administrateur de groupe (destinataire) pour un groupe donné.
Future<String?> groupAdminRecipient(dynamic client, String groupId) async {
  final rows = await client
      .from('profiles')
      .select('id')
      .eq('group_id', groupId)
      .eq('role', 'admin_groupe')
      .eq('is_active', true)
      .limit(1);
  final list = rows as List;
  return list.isEmpty ? null : (list.first as Map)['id'] as String;
}

/// Envoie / compose — `recipient_id` et `group_id` sont NOT NULL en base.
Future<void> sendMessage({
  required dynamic client,
  required String senderId,
  required String recipientId,
  required String groupId,
  required String subject,
  required String body,
  List<MessageAttachment> attachments = const [],
  String? parentId,
}) async {
  final now = DateTime.now().toIso8601String();
  await client.from('messages').insert({
    'sender_id':          senderId,
    'recipient_id':       recipientId,
    'group_id':           groupId,
    'subject':            subject.trim(),
    'body':               body.trim(),
    'is_read':            false,
    'is_archived':        false,
    'attachments':        attachments.map((a) => a.toJson()).toList(),
    'parent_message_id': ?parentId,
    'created_at':         now,
    'updated_at':         now,
  });
}

/// Envoi multi-destinataires (fan-out) : `recipient_id` est NOT NULL et unique,
/// donc une ligne par destinataire. Les pièces jointes (déjà téléversées) sont
/// partagées entre toutes les copies.
Future<void> sendMessageToMany({
  required dynamic client,
  required String senderId,
  required List<String> recipientIds,
  required String groupId,
  required String subject,
  required String body,
  List<MessageAttachment> attachments = const [],
  String? parentId,
}) async {
  final now = DateTime.now().toIso8601String();
  final attachJson = attachments.map((a) => a.toJson()).toList();
  final rows = [
    for (final rid in recipientIds.toSet())
      {
        'sender_id':         senderId,
        'recipient_id':      rid,
        'group_id':          groupId,
        'subject':           subject.trim(),
        'body':              body.trim(),
        'is_read':           false,
        'is_archived':       false,
        'attachments':       attachJson,
        'parent_message_id': parentId,
        'created_at':        now,
        'updated_at':        now,
      }
  ];
  if (rows.isEmpty) return;
  await client.from('messages').insert(rows);
}

// ════════════════════════════════════════════════════════════════════════════
//  COUCHE UNIFIÉE SCOPE-AWARE — UNE seule messagerie (style WhatsApp) partagée
//  par super_admin / admin_groupe (online Supabase) ET école (offline PowerSync).
//  L'écran branche ces providers ; la source réelle est choisie via le scope,
//  sans jamais violer la règle online/offline (cf. CLAUDE.md).
// ════════════════════════════════════════════════════════════════════════════

/// Messages de l'utilisateur courant, quel que soit son espace, exposés comme
/// un `AsyncValue` unifié. school → PowerSync (`myMessagesProvider`, stream
/// réactif) ; platform/group → Supabase (`messagesProvider`, FutureProvider
/// réémis à chaque invalidation realtime). L'écran fait `.when()` dessus.
final scopedMessagesProvider =
    Provider.autoDispose<AsyncValue<MessagesData>>((ref) {
  final ctx = ref.watch(communicationContextProvider);
  return ctx.isSchool
      ? ref.watch(myMessagesProvider)
      : ref.watch(messagesProvider);
});

/// Destinataires possibles selon l'espace : collègues de l'école (annuaire
/// PowerSync) OU utilisateurs/groupes du périmètre (Supabase RPC).
final scopedRecipientsProvider =
    FutureProvider.autoDispose<List<RecipientOption>>((ref) {
  final ctx = ref.watch(communicationContextProvider);
  if (ctx.isSchool) {
    return ref.watch(schoolDirectoryProvider.future);
  }
  return ref.watch(messageRecipientsProvider.future);
});

/// Marque un message lu — local (école) ou Supabase (admin).
Future<void> markMessageReadScoped(WidgetRef ref, String id) async {
  final ctx = ref.read(communicationContextProvider);
  if (ctx.isSchool) {
    await markMessageReadLocal(id);
  } else {
    await markMessageRead(ref.read(supabaseClientProvider), id);
  }
}

/// Marque un message non lu — local (école) ou Supabase (admin).
Future<void> markMessageUnreadScoped(WidgetRef ref, String id) async {
  final ctx = ref.read(communicationContextProvider);
  if (ctx.isSchool) {
    await markMessageUnreadLocal(id);
  } else {
    await markMessageUnread(ref.read(supabaseClientProvider), id);
  }
}

/// Supprime un message — local (école, PowerSync) ou Supabase (admin).
Future<void> deleteMessageScoped(WidgetRef ref, String id) async {
  final ctx = ref.read(communicationContextProvider);
  if (ctx.isSchool) {
    await db.execute('DELETE FROM messages WHERE id = ?', [id]);
  } else {
    await deleteMessage(ref.read(supabaseClientProvider), id);
    ref.invalidate(messagesProvider);
  }
}

/// Archive / désarchive un message — local (école) ou Supabase (admin).
Future<void> archiveMessageScoped(
    WidgetRef ref, String id, bool archived) async {
  final ctx = ref.read(communicationContextProvider);
  if (ctx.isSchool) {
    await archiveMessageLocal(id, archived);
  } else if (archived) {
    await archiveMessage(ref.read(supabaseClientProvider), id);
  } else {
    await unarchiveMessage(ref.read(supabaseClientProvider), id);
  }
}

/// Résout le couple (destinataire réel, group_id) à partir d'une option
/// choisie dans le sélecteur, selon l'espace :
/// - école / admin_groupe : l'option EST l'utilisateur ; group_id = mon groupe.
/// - super_admin (plateforme) : l'option est un GROUPE ; le destinataire réel
///   est l'admin de ce groupe ; group_id = ce groupe.
/// Renvoie null si aucun destinataire ne peut être résolu (groupe sans admin).
Future<({String recipientId, String groupId})?> resolveScopedRecipient(
  WidgetRef ref,
  RecipientOption option,
  String myGroupId,
) async {
  final ctx = ref.read(communicationContextProvider);
  if (ctx.isPlatform) {
    final adminId = await groupAdminRecipient(
        ref.read(supabaseClientProvider), option.value);
    if (adminId == null) return null;
    return (recipientId: adminId, groupId: option.value);
  }
  return (recipientId: option.value, groupId: myGroupId);
}

/// Envoie un message (réponse dans un fil ou nouveau) vers UN destinataire,
/// quel que soit l'espace.
Future<void> sendMessageScoped(
  WidgetRef ref, {
  required String senderId,
  required String recipientId,
  required String groupId,
  required String subject,
  required String body,
  List<MessageAttachment> attachments = const [],
  String? parentId,
}) async {
  final ctx = ref.read(communicationContextProvider);
  if (ctx.isSchool) {
    await sendMessageLocal(
      senderId: senderId,
      recipientId: recipientId,
      groupId: groupId,
      subject: subject,
      body: body,
      attachments: attachments,
      parentId: parentId,
    );
  } else {
    await sendMessage(
      client: ref.read(supabaseClientProvider),
      senderId: senderId,
      recipientId: recipientId,
      groupId: groupId,
      subject: subject,
      body: body,
      attachments: attachments,
      parentId: parentId,
    );
    // Rafraîchissement optimiste : l'expéditeur voit son message instantanément
    // sans attendre l'aller-retour Realtime (le destinataire, lui, via Realtime).
    ref.invalidate(messagesProvider);
  }
}

/// Bascule (ajoute / retire) la réaction emoji de [myId] sur un message.
/// Scope-aware. RLS : membre de la conversation autorisé (cf. msg_update).
Future<void> toggleReactionScoped(
  WidgetRef ref, {
  required MessageModel msg,
  required String emoji,
  required String myId,
}) async {
  // Recalcule la map en basculant ma réaction sur cet emoji.
  final next = <String, List<String>>{
    for (final e in msg.reactions.entries) e.key: List<String>.from(e.value),
  };
  final users = next.putIfAbsent(emoji, () => <String>[]);
  if (users.contains(myId)) {
    users.remove(myId);
    if (users.isEmpty) next.remove(emoji);
  } else {
    users.add(myId);
  }

  final ctx = ref.read(communicationContextProvider);
  final now = DateTime.now().toIso8601String();
  if (ctx.isSchool) {
    await db.execute(
      'UPDATE messages SET reactions = ?, updated_at = ? WHERE id = ?',
      [jsonEncode(next), now, msg.id],
    );
  } else {
    await ref.read(supabaseClientProvider).from('messages').update({
      'reactions':  next,
      'updated_at': now,
    }).eq('id', msg.id);
    ref.invalidate(messagesProvider);
  }
}

/// Modifie le texte d'un message (mes messages uniquement, garde-fou UI) et
/// renseigne `edited_at`. Scope-aware.
Future<void> editMessageScoped(
    WidgetRef ref, String id, String newBody) async {
  final text = newBody.trim();
  if (text.isEmpty) return;
  final ctx = ref.read(communicationContextProvider);
  final now = DateTime.now().toIso8601String();
  if (ctx.isSchool) {
    await db.execute(
      'UPDATE messages SET body = ?, edited_at = ?, updated_at = ? WHERE id = ?',
      [text, now, now, id],
    );
  } else {
    await ref.read(supabaseClientProvider).from('messages').update({
      'body':       text,
      'edited_at':  now,
      'updated_at': now,
    }).eq('id', id);
    ref.invalidate(messagesProvider);
  }
}
