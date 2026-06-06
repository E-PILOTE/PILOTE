import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:realtime_client/realtime_client.dart';
import '../../../features/auth/providers/auth_provider.dart';

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
    this.schoolId,
    this.publishedAt,
    this.expiresAt,
    this.groupName,
  });

  factory AnnouncementDetail.fromMap(Map<String, dynamic> m) {
    final grp = m['group'];
    final grpMap = grp is Map ? Map<String, dynamic>.from(grp) : const {};
    return AnnouncementDetail(
      id:             m['id']              as String,
      groupId:        m['group_id']        as String,
      schoolId:       m['school_id']       as String?,
      title:          m['title']           as String? ?? '',
      content:        m['content']         as String? ?? '',
      targetAudience: m['target_audience'] as String? ?? 'all',
      isPinned:       m['is_pinned']       as bool? ?? false,
      isPublished:    m['is_published']    as bool? ?? false,
      publishedAt:    _date(m['published_at']),
      expiresAt:      _date(m['expires_at']),
      createdBy:      m['created_by']      as String,
      createdAt:      DateTime.parse(m['created_at'] as String),
      updatedAt:      DateTime.parse(m['updated_at'] as String),
      groupName:      grpMap['name']       as String?,
    );
  }

  final String  id, groupId, title, content, targetAudience, createdBy;
  final String? schoolId, groupName;
  final bool    isPinned, isPublished;
  final DateTime  createdAt, updatedAt;
  final DateTime? publishedAt, expiresAt;

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
  List<AnnouncementDetail> announcements = [];
  try {
    final rows = await client
        .from('announcements')
        .select('id, group_id, school_id, title, content, target_audience, '
            'is_pinned, is_published, published_at, expires_at, '
            'created_by, created_at, updated_at, '
            'group:school_groups(name)')
        .order('is_pinned',    ascending: false)
        .order('created_at',   ascending: false) as List;
    announcements = rows.map((r) => AnnouncementDetail.fromMap(
        Map<String, dynamic>.from(r as Map))).toList();
  } catch (_) {}

  // ── Groupes disponibles (pour le formulaire) ────────────────────────────────
  List<GroupOption> groups = [];
  try {
    final rows = await client
        .from('school_groups')
        .select('id, name')
        .eq('is_active', true)
        .order('name') as List;
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
