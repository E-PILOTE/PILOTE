import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:realtime_client/realtime_client.dart';
import 'package:uuid/uuid.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../services/powersync/powersync_service.dart';
import 'communication_scope.dart';
import 'messages_provider.dart' show MessageAttachment, parseAttachments;
import '../../../core/utils/erreur_metier.dart';
import 'comm_droits.dart';

// ─── Modèle AnnouncementDetail ────────────────────────────────────────────────

class AnnouncementDetail {
  const AnnouncementDetail({
    required this.id,
    required this.groupId,
    required this.title,
    required this.content,
    required this.targetAudience,
    required this.isPinned,
    required this.isPublished,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.isArchived = false,
    this.schoolId,
    this.publishedAt,
    this.expiresAt,
    this.groupName,
    this.attachments = const [],
    this.authorName,
    this.authorRole,
    this.authorAvatarUrl,
  });

  factory AnnouncementDetail.fromMap(Map<String, dynamic> m) {
    final grp    = m['group'];
    final grpMap = grp is Map ? Map<String, dynamic>.from(grp) : const <String, dynamic>{};
    final author = m['author'];
    final authorMap = author is Map ? Map<String, dynamic>.from(author) : const <String, dynamic>{};
    final fn = authorMap['first_name'] ?? m['author_first_name'] ?? '';
    final ln = authorMap['last_name']  ?? m['author_last_name']  ?? m['author_name'] ?? '';
    final fullName = '$fn $ln'.trim();
    return AnnouncementDetail(
      id:              m['id']              as String,
      groupId:         m['group_id']        as String,
      schoolId:        m['school_id']       as String?,
      title:           m['title']           as String? ?? '',
      content:         m['content']         as String? ?? '',
      targetAudience:  m['target_audience'] as String? ?? 'all',
      isPinned:        m['is_pinned']       as bool? ?? false,
      isPublished:     m['is_published']    as bool? ?? false,
      isArchived:      m['is_archived']     as bool? ?? false,
      publishedAt:     _date(m['published_at']),
      expiresAt:       _date(m['expires_at']),
      createdBy:       m['created_by']      as String,
      createdAt:       DateTime.parse(m['created_at'] as String),
      updatedAt:       DateTime.parse(m['updated_at'] as String),
      groupName:       grpMap['name']       as String?,
      attachments:     parseAttachments(m['attachments']),
      authorName:      fullName.isEmpty ? null : fullName,
      authorRole:      authorMap['role'] as String? ?? m['author_role'] as String?,
      authorAvatarUrl: authorMap['avatar_url'] as String? ?? m['author_avatar_url'] as String?,
    );
  }

  final String  id, groupId, title, content, targetAudience, createdBy;
  final String? schoolId, groupName;
  final String? authorName, authorRole, authorAvatarUrl;
  final bool    isPinned, isPublished, isArchived;
  final DateTime  createdAt, updatedAt;
  final DateTime? publishedAt, expiresAt;
  final List<MessageAttachment> attachments;

  bool get isExpired {
    if (expiresAt == null) return false;
    return expiresAt!.isBefore(DateTime.now());
  }

  String get targetAudienceLabel => switch (targetAudience) {
    'all'      => 'Tout le monde',
    'staff'    => 'Personnel',
    'teachers' => 'Enseignants',
    'parents'  => 'Parents',
    'students' => 'Élèves',
    _          => targetAudience,
  };

  String get initials {
    final n = title.trim();
    if (n.isEmpty) return '?';
    final parts = n.split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return n.substring(0, n.length > 1 ? 2 : 1).toUpperCase();
  }
}

DateTime? _date(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v as String);
}

// ─── Modèle GroupOption (sélecteur de groupe dans le formulaire) ───────────────

class GroupOption {
  const GroupOption({required this.id, required this.name});
  final String id, name;
}

// ─── Modèle données globales ───────────────────────────────────────────────────

class AnnouncementsData {
  const AnnouncementsData({
    required this.announcements,
    required this.groups,
    required this.total,
    required this.published,
    required this.pinned,
    required this.pending,
    required this.expired,
  });

  final List<AnnouncementDetail> announcements;
  final List<GroupOption>        groups;
  final int total, published, pinned, pending, expired;

  static const empty = AnnouncementsData(
    announcements: [], groups: [], total: 0,
    published: 0, pinned: 0, pending: 0, expired: 0,
  );
}

// ─── Provider principal ─────────────────────────────────────────────────────────

final announcementsProvider =
    FutureProvider.autoDispose<AnnouncementsData>((ref) async {
  ref.keepAlive();
  final client = ref.watch(supabaseClientProvider);
  final ctx    = ref.watch(communicationContextProvider);

  // Realtime
  Timer? debounce;
  void scheduleInvalidate() {
    debounce?.cancel();
    debounce = Timer(const Duration(seconds: 2), () => ref.invalidateSelf());
  }

  try {
    final channel = client.channel('platform_announcements_list')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'announcements',
          callback: (_) => scheduleInvalidate(),
        )
        .subscribe();
    ref.onDispose(() {
      debounce?.cancel();
      client.removeChannel(channel);
    });
  } catch (_) {}

  // ── Annonces (avec nom du groupe) ───────────────────────────────────────────
  // Scope : admin_groupe ne voit/gère que les annonces de SON groupe.
  List<AnnouncementDetail> announcements = [];
  try {
    final sel = client
        .from('announcements')
        .select('id, group_id, school_id, title, content, target_audience, '
            'is_pinned, is_published, is_archived, published_at, expires_at, attachments, '
            'created_by, created_at, updated_at, '
            'group:school_groups(name), '
            'author:profiles!created_by(first_name, last_name, avatar_url, role)');
    final rows = await (ctx.isGroup && ctx.groupId != null
            ? sel.eq('group_id', ctx.groupId!)
            : sel)
        .order('is_pinned',  ascending: false)
        .order('created_at', ascending: false) as List;
    announcements = rows.map((r) => AnnouncementDetail.fromMap(
        Map<String, dynamic>.from(r as Map))).toList();
  } catch (_) {}

  // ── Groupes disponibles (sélecteur du formulaire) ───────────────────────────
  // platform → tous les groupes ; group → uniquement le sien (sélecteur verrouillé).
  List<GroupOption> groups = [];
  try {
    final sel = client.from('school_groups').select('id, name');
    final rows = await (ctx.isGroup && ctx.groupId != null
            ? sel.eq('id', ctx.groupId!)
            : sel.eq('is_active', true).order('name', ascending: true)) as List;
    groups = rows.map((r) {
      final m = Map<String, dynamic>.from(r as Map);
      return GroupOption(id: m['id'] as String, name: m['name'] as String? ?? '');
    }).toList();
  } catch (_) {}

  // ── KPIs ──────────────────────────────────────────────────────────────────
  int published = 0, pinned = 0, pending = 0, expired = 0;
  for (final a in announcements) {
    if (a.isPublished) published++;
    if (a.isPinned) pinned++;
    if (!a.isPublished) pending++;
    if (a.isExpired) expired++;
  }

  return AnnouncementsData(
    announcements: announcements,
    groups:        groups,
    total:         announcements.length,
    published:     published,
    pinned:        pinned,
    pending:       pending,
    expired:       expired,
  );
});

// ─── Personnel école — fil d'annonces offline-first (lecture seule) ─────────────
// Annonces PUBLIÉES, non expirées. Les sync-rules descendent les annonces du
// GROUPE entier (bucket by_group) : on re-filtre donc localement le ciblage —
// `school_id IS NULL` = annonce réseau (toutes les écoles), sinon uniquement
// celles adressées à MON école. 100 % local (SQLite), réactif, hors-ligne.
final schoolAnnouncementsProvider =
    StreamProvider.autoDispose<List<AnnouncementDetail>>((ref) {
  final profile  = ref.watch(authNotifierProvider).valueOrNull;
  final schoolId = profile?.schoolId ?? '';
  final groupId  = profile?.groupId ?? '';
  if (schoolId.isEmpty && groupId.isEmpty) return Stream.value(const []);

  final nowIso = DateTime.now().toIso8601String();
  return db
      .watch(
        '''
        SELECT a.*,
               TRIM(COALESCE(p.first_name, '') || ' ' || COALESCE(p.last_name, ''))
                 AS author_name,
               p.role        AS author_role,
               p.avatar_url  AS author_avatar_url
        FROM   announcements a
        LEFT JOIN profiles p ON p.id = a.created_by
        WHERE  a.is_published = 1
          AND  (a.expires_at IS NULL OR a.expires_at > ?)
          AND  (a.school_id  IS NULL OR a.school_id  = ?)
        ORDER  BY a.is_pinned DESC, COALESCE(a.published_at, a.created_at) DESC
        ''',
        parameters: [nowIso, schoolId],
      )
      .map((rows) => rows.map(_annFromLocalRow).toList());
});

/// Mappe une ligne SQLite locale (booléens en INTEGER 0/1) → AnnouncementDetail.
AnnouncementDetail _annFromLocalRow(Map<String, dynamic> m) {
  final rawName = m['author_name'] as String? ?? '';
  return AnnouncementDetail(
    id:              m['id'] as String,
    groupId:         m['group_id'] as String? ?? '',
    schoolId:        m['school_id'] as String?,
    title:           m['title'] as String? ?? '',
    content:         m['content'] as String? ?? '',
    targetAudience:  m['target_audience'] as String? ?? 'all',
    isPinned:        m['is_pinned'] == 1 || m['is_pinned'] == true,
    isPublished:     m['is_published'] == 1 || m['is_published'] == true,
    isArchived:      m['is_archived'] == 1 || m['is_archived'] == true,
    publishedAt:     _date(m['published_at']),
    expiresAt:       _date(m['expires_at']),
    createdBy:       m['created_by'] as String? ?? '',
    createdAt:       _date(m['created_at']) ?? DateTime.now(),
    updatedAt:       _date(m['updated_at']) ?? DateTime.now(),
    attachments:     parseAttachments(m['attachments']),
    authorName:      rawName.trim().isEmpty ? null : rawName.trim(),
    authorRole:      m['author_role'] as String?,
    authorAvatarUrl: m['author_avatar_url'] as String?,
  );
}

// ─── Actions locales DIRECTION (offline-first, scope = MON école) ──────────────
// RLS serveur : announce_write autorise l'écriture si school_id = auth_school_id().
// Le texte part hors-ligne ; les pièces jointes exigent internet (Storage).

Future<String> createSchoolAnnouncementLocal({
  required String groupId,
  required String schoolId,
  required String createdBy,
  required String title,
  required String content,
  required String targetAudience,
  bool isPinned = false,
  DateTime? expiresAt,
  List<MessageAttachment> attachments = const [],
}) async {
  final id  = const Uuid().v4();
  final now = DateTime.now().toIso8601String();
  await db.execute(
    '''INSERT INTO announcements
       (id, group_id, school_id, title, content, target_audience,
        is_pinned, is_published, published_at, expires_at, attachments,
        created_by, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?, ?, ?, ?, ?, ?)''',
    [id, groupId, schoolId, title.trim(), content.trim(), targetAudience,
     isPinned ? 1 : 0, now, expiresAt?.toIso8601String(),
     jsonEncode(attachments.map((a) => a.toJson()).toList()),
     createdBy, now, now],
  );
  return id;
}

Future<void> updateSchoolAnnouncementLocal({
  required String id,
  required String title,
  required String content,
  required String targetAudience,
  required bool isPinned,
  DateTime? expiresAt,
  List<MessageAttachment>? attachments,
}) async {
  final now = DateTime.now().toIso8601String();
  await db.execute(
    '''UPDATE announcements
       SET title = ?, content = ?, target_audience = ?, is_pinned = ?,
           expires_at = ?${attachments != null ? ', attachments = ?' : ''},
           updated_at = ?
       WHERE id = ?''',
    [title.trim(), content.trim(), targetAudience, isPinned ? 1 : 0,
     expiresAt?.toIso8601String(),
     if (attachments != null)
       jsonEncode(attachments.map((a) => a.toJson()).toList()),
     now, id],
  );
}

Future<void> setAnnouncementPinnedLocal(String id, bool pinned) async {
  await db.execute(
    'UPDATE announcements SET is_pinned = ?, updated_at = ? WHERE id = ?',
    [pinned ? 1 : 0, DateTime.now().toIso8601String(), id],
  );
}

Future<void> deleteSchoolAnnouncementLocal(String id) async {
  await db.execute('DELETE FROM announcements WHERE id = ?', [id]);
}

// ════════════════════════════════════════════════════════════════════════════
//  COUCHE UNIFIÉE SCOPE-AWARE — UN seul feed d'annonces partagé par
//  super_admin / admin_groupe (online Supabase) ET école (offline PowerSync).
// ════════════════════════════════════════════════════════════════════════════

/// Liste d'annonces affichée par le feed, quel que soit l'espace.
/// school → PowerSync (`schoolAnnouncementsProvider`) ;
/// platform/group → Supabase (`announcementsProvider`).
final scopedAnnouncementsProvider =
    Provider.autoDispose<AsyncValue<List<AnnouncementDetail>>>((ref) {
  final ctx = ref.watch(communicationContextProvider);
  if (ctx.isSchool) return ref.watch(schoolAnnouncementsProvider);
  return ref.watch(announcementsProvider).whenData((d) => d.announcements);
});

// ── Écritures ONLINE (super_admin / admin_groupe) ───────────────────────────

Future<String> createOnlineAnnouncement({
  required dynamic client,
  required String groupId,
  String? schoolId,
  required String createdBy,
  required String title,
  required String content,
  required String targetAudience,
  bool isPinned = false,
  bool isPublished = true,
  DateTime? expiresAt,
  List<MessageAttachment> attachments = const [],
}) async {
  final now = DateTime.now().toIso8601String();
  final res = await client.from('announcements').insert({
    'group_id':        groupId,
    'school_id':      ?schoolId,
    'title':           title.trim(),
    'content':         content.trim(),
    'target_audience': targetAudience,
    'is_pinned':       isPinned,
    'is_published':    isPublished,
    'published_at':    isPublished ? now : null,
    'expires_at':      expiresAt?.toIso8601String(),
    'attachments':     attachments.map((a) => a.toJson()).toList(),
    'created_by':      createdBy,
    'created_at':      now,
    'updated_at':      now,
  }).select('id').single();
  return res['id'] as String;
}

Future<void> updateOnlineAnnouncement({
  required dynamic client,
  required String id,
  required String title,
  required String content,
  required String targetAudience,
  required bool isPinned,
  DateTime? expiresAt,
  List<MessageAttachment>? attachments,
}) async {
  final payload = <String, dynamic>{
    'title':           title.trim(),
    'content':         content.trim(),
    'target_audience': targetAudience,
    'is_pinned':       isPinned,
    'expires_at':      expiresAt?.toIso8601String(),
    'updated_at':      DateTime.now().toIso8601String(),
  };
  if (attachments != null) {
    payload['attachments'] = attachments.map((a) => a.toJson()).toList();
  }
  await client.from('announcements').update(payload).eq('id', id);
}

Future<void> setAnnouncementPinnedOnline(
        dynamic client, String id, bool pinned) async =>
    client.from('announcements').update({
      'is_pinned':  pinned,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);

Future<void> setAnnouncementArchivedOnline(
        dynamic client, String id, bool archived) async =>
    client.from('announcements').update({
      'is_archived': archived,
      'updated_at':  DateTime.now().toIso8601String(),
    }).eq('id', id);

Future<void> setAnnouncementArchivedLocal(String id, bool archived) async {
  await db.execute(
    'UPDATE announcements SET is_archived = ?, updated_at = ? WHERE id = ?',
    [archived ? 1 : 0, DateTime.now().toIso8601String(), id],
  );
}

Future<void> deleteOnlineAnnouncement(dynamic client, String id) async =>
    client.from('announcements').delete().eq('id', id);

// ── Wrappers SCOPE-AWARE (branchent local OU online) ────────────────────────

Future<void> setAnnouncementPinnedScoped(
    WidgetRef ref, String id, bool pinned) async {
  exigerDroitComm(ref, kSlugAnnonces, 'update');
  final ctx = ref.read(communicationContextProvider);
  if (ctx.isSchool) {
    await setAnnouncementPinnedLocal(id, pinned);
  } else {
    await setAnnouncementPinnedOnline(
        ref.read(supabaseClientProvider), id, pinned);
    ref.invalidate(announcementsProvider);
  }
}

Future<void> setAnnouncementArchivedScoped(
    WidgetRef ref, String id, bool archived) async {
  exigerDroitComm(ref, kSlugAnnonces, 'update');
  final ctx = ref.read(communicationContextProvider);
  if (ctx.isSchool) {
    await setAnnouncementArchivedLocal(id, archived);
  } else {
    await setAnnouncementArchivedOnline(
        ref.read(supabaseClientProvider), id, archived);
    ref.invalidate(announcementsProvider);
  }
}

Future<void> deleteAnnouncementScoped(WidgetRef ref, String id) async {
  exigerDroitComm(ref, kSlugAnnonces, 'delete');
  final ctx = ref.read(communicationContextProvider);
  if (ctx.isSchool) {
    await deleteSchoolAnnouncementLocal(id);
  } else {
    await deleteOnlineAnnouncement(ref.read(supabaseClientProvider), id);
    ref.invalidate(announcementsProvider);
  }
}

/// Retire UNE pièce jointe d'une annonce sans supprimer la publication.
/// (Réécrit la liste `attachments` moins le fichier ciblé.)
Future<void> removeAttachmentScoped(
    WidgetRef ref, AnnouncementDetail ann, MessageAttachment att) async {
  final remaining =
      ann.attachments.where((a) => a.cacheKey != att.cacheKey).toList();
  final ctx = ref.read(communicationContextProvider);
  if (ctx.isSchool) {
    await updateSchoolAnnouncementLocal(
      id: ann.id,
      title: ann.title,
      content: ann.content,
      targetAudience: ann.targetAudience,
      isPinned: ann.isPinned,
      expiresAt: ann.expiresAt,
      attachments: remaining,
    );
  } else {
    await updateOnlineAnnouncement(
      client: ref.read(supabaseClientProvider),
      id: ann.id,
      title: ann.title,
      content: ann.content,
      targetAudience: ann.targetAudience,
      isPinned: ann.isPinned,
      expiresAt: ann.expiresAt,
      attachments: remaining,
    );
    ref.invalidate(announcementsProvider);
  }
}

/// Groupes disponibles pour le sélecteur du formulaire (super_admin = tous,
/// admin_groupe = le sien). Vide côté école (publication locale, pas de choix).
final announcementGroupsProvider = Provider.autoDispose<List<GroupOption>>((ref) {
  final ctx = ref.watch(communicationContextProvider);
  if (ctx.isSchool) return const [];
  return ref.watch(announcementsProvider).valueOrNull?.groups ?? const [];
});

/// Valeur sentinelle du sélecteur de groupe (super_admin) = « Toutes les écoles ».
/// Déclenche une diffusion plateforme : une annonce créée dans chaque groupe.
const String kAllGroupsSentinel = '__all__';

/// Création SCOPE-AWARE : école → local (offline) ; admin_groupe → online sur
/// SON groupe ; super_admin → online sur le groupe choisi (`groupIdOverride`),
/// ou sur TOUS les groupes si `groupIdOverride == kAllGroupsSentinel`.
Future<void> createAnnouncementScoped(
  WidgetRef ref, {
  required String title,
  required String content,
  required String targetAudience,
  bool isPinned = false,
  DateTime? expiresAt,
  List<MessageAttachment> attachments = const [],
  String? groupIdOverride,
}) async {
  exigerDroitComm(ref, kSlugAnnonces, 'create');
  final ctx = ref.read(communicationContextProvider);
  final me  = ref.read(authNotifierProvider).valueOrNull;
  if (me == null) throw const ErreurMetier('Session invalide.');
  if (ctx.isSchool) {
    await createSchoolAnnouncementLocal(
      groupId: me.groupId!,
      schoolId: me.schoolId!,
      createdBy: me.id,
      title: title,
      content: content,
      targetAudience: targetAudience,
      isPinned: isPinned,
      expiresAt: expiresAt,
      attachments: attachments,
    );
  } else {
    final client = ref.read(supabaseClientProvider);
    // super_admin → « Toutes les écoles » : diffusion à chaque groupe.
    if (ctx.isPlatform && groupIdOverride == kAllGroupsSentinel) {
      final groups = ref.read(announcementGroupsProvider);
      if (groups.isEmpty) throw const ErreurMetier('Aucun groupe destinataire.');
      for (final g in groups) {
        await createOnlineAnnouncement(
          client: client,
          groupId: g.id,
          createdBy: me.id,
          title: title,
          content: content,
          targetAudience: targetAudience,
          isPinned: isPinned,
          expiresAt: expiresAt,
          attachments: attachments,
        );
      }
      ref.invalidate(announcementsProvider);
      return;
    }
    final groupId = ctx.isGroup ? ctx.groupId : groupIdOverride;
    if (groupId == null || groupId.isEmpty) {
      throw const ErreurMetier('Choisissez un groupe destinataire.');
    }
    await createOnlineAnnouncement(
      client: client,
      groupId: groupId,
      createdBy: me.id,
      title: title,
      content: content,
      targetAudience: targetAudience,
      isPinned: isPinned,
      expiresAt: expiresAt,
      attachments: attachments,
    );
    ref.invalidate(announcementsProvider);
  }
}

/// Mise à jour SCOPE-AWARE : école → local ; admin/super → online.
Future<void> updateAnnouncementScoped(
  WidgetRef ref, {
  required String id,
  required String title,
  required String content,
  required String targetAudience,
  required bool isPinned,
  DateTime? expiresAt,
  List<MessageAttachment>? attachments,
}) async {
  exigerDroitComm(ref, kSlugAnnonces, 'update');
  final ctx = ref.read(communicationContextProvider);
  if (ctx.isSchool) {
    await updateSchoolAnnouncementLocal(
      id: id,
      title: title,
      content: content,
      targetAudience: targetAudience,
      isPinned: isPinned,
      expiresAt: expiresAt,
      attachments: attachments,
    );
  } else {
    await updateOnlineAnnouncement(
      client: ref.read(supabaseClientProvider),
      id: id,
      title: title,
      content: content,
      targetAudience: targetAudience,
      isPinned: isPinned,
      expiresAt: expiresAt,
      attachments: attachments,
    );
    ref.invalidate(announcementsProvider);
  }
}
