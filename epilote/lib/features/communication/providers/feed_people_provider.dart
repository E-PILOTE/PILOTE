import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/providers/auth_provider.dart';
import '../../../services/powersync/powersync_service.dart';
import 'communication_scope.dart';

/// Une personne de la communauté (membre/contact) affichée dans le rail social.
class FeedPerson {
  const FeedPerson({
    required this.id,
    required this.name,
    this.role,
    this.subtitle,
    this.avatarUrl,
    this.lastLogin,
  });

  final String id;
  final String name;
  final String? role;
  final String? subtitle;
  final String? avatarUrl;
  final DateTime? lastLogin;

  /// « En ligne » = connexion il y a moins de 15 min (approximation réseau social).
  bool get isOnline {
    final t = lastLogin;
    if (t == null) return false;
    return DateTime.now().difference(t).inMinutes < 15;
  }
}

String _name(Map m) =>
    '${m['first_name'] ?? ''} ${m['last_name'] ?? ''}'.trim();

DateTime? _date(Object? v) =>
    v == null ? null : DateTime.tryParse(v.toString());

/// Membres de la communauté, **scope-aware** :
/// - super_admin (plateforme) → administrateurs de groupe (`get_platform_admins`)
/// - admin_groupe (groupe)    → utilisateurs actifs du groupe (`get_group_users`)
/// - personnel école (offline)→ collègues de l'école (PowerSync `profiles`)
final feedPeopleProvider =
    FutureProvider.autoDispose<List<FeedPerson>>((ref) async {
  ref.keepAlive();
  final client  = ref.watch(supabaseClientProvider);
  final ctx     = ref.watch(communicationContextProvider);
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final myId    = profile?.id;

  // ── Plateforme : administrateurs de groupe ────────────────────────────────
  if (ctx.isPlatform) {
    final rows = await client.rpc('get_platform_admins') as List;
    return rows
        .map((r) => r as Map)
        .where((m) => m['id'] != myId && (m['is_active'] as bool? ?? true))
        .map((m) => FeedPerson(
              id:        m['id'] as String,
              name:      _name(m),
              role:      (m['role'] ?? '').toString(),
              subtitle:  m['group_name'] as String?,
              avatarUrl: m['avatar_url'] as String?,
              lastLogin: _date(m['last_login']),
            ))
        .where((p) => p.name.isNotEmpty)
        .toList();
  }

  // ── Groupe : utilisateurs actifs du groupe ────────────────────────────────
  if (ctx.isGroup && ctx.groupId != null) {
    final rows = await client
        .rpc('get_group_users', params: {'p_group_id': ctx.groupId}) as List;
    return rows
        .map((r) => r as Map)
        .where((m) => m['id'] != myId && (m['is_active'] as bool? ?? true))
        .map((m) => FeedPerson(
              id:        m['id'] as String,
              name:      _name(m),
              role:      m['role'] as String?,
              subtitle:  m['school_name'] as String? ??
                  m['access_profile_name'] as String?,
              lastLogin: _date(m['last_login']),
            ))
        .where((p) => p.name.isNotEmpty)
        .toList();
  }

  return const [];
});

/// Collègues de MON école — chemin OFFLINE (PowerSync), personnel scolaire.
final schoolPeopleProvider =
    StreamProvider.autoDispose<List<FeedPerson>>((ref) {
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final uid    = profile?.id ?? '';
  final school = profile?.schoolId ?? '';
  if (uid.isEmpty || school.isEmpty) return Stream.value(const []);
  return db
      .watch(
        '''SELECT id, first_name, last_name, role, avatar_url, last_login
           FROM profiles
           WHERE school_id = ? AND id != ? AND COALESCE(is_active, 1) <> 0
           ORDER BY last_name, first_name''',
        parameters: [school, uid],
      )
      .map((rows) => rows
          .map((m) => FeedPerson(
                id:        m['id'] as String,
                name:      _name(m),
                role:      m['role'] as String?,
                avatarUrl: m['avatar_url'] as String?,
                lastLogin: _date(m['last_login']),
              ))
          .where((p) => p.name.isNotEmpty)
          .toList());
});

/// Personnes à afficher selon le périmètre (résout online/offline).
final communityPeopleProvider =
    Provider.autoDispose<AsyncValue<List<FeedPerson>>>((ref) {
  final ctx = ref.watch(communicationContextProvider);
  return ctx.isSchool
      ? ref.watch(schoolPeopleProvider)
      : ref.watch(feedPeopleProvider);
});
