import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:realtime_client/realtime_client.dart';
import '../../../features/auth/providers/auth_provider.dart';

// ─── Modèle AdminDetail ───────────────────────────────────────────────────────

class AdminDetail {
  const AdminDetail({
    required this.id,
    required this.email,
    required this.role,
    required this.firstName,
    required this.lastName,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.phone,
    this.groupId,
    this.groupName,
    this.groupLogo,
    this.avatarUrl,
    this.lastLogin,
  });

  factory AdminDetail.fromMap(Map<String, dynamic> m) => AdminDetail(
    id:         m['id']          as String,
    email:      m['email']       as String,
    role:       m['role']        as String,
    firstName:  m['first_name']  as String? ?? '',
    lastName:   m['last_name']   as String? ?? '',
    phone:      m['phone']       as String?,
    isActive:   m['is_active']   as bool?   ?? true,
    groupId:    m['group_id']    as String?,
    groupName:  m['group_name']  as String?,
    groupLogo:  m['group_logo']  as String?,
    avatarUrl:  m['avatar_url']  as String?,
    lastLogin:  m['last_login'] != null
        ? DateTime.tryParse(m['last_login'] as String)
        : null,
    createdAt:  DateTime.parse(m['created_at'] as String),
    updatedAt:  DateTime.parse(m['updated_at'] as String),
  );

  final String  id, email, role, firstName, lastName;
  final String? phone, groupId, groupName, groupLogo, avatarUrl;
  final bool    isActive;
  final DateTime  createdAt, updatedAt;
  final DateTime? lastLogin;

  String get fullName {
    final n = '${firstName.trim()} ${lastName.trim()}'.trim();
    return n.isNotEmpty ? n : email;
  }

  String get initials {
    final f = firstName.trim();
    final l = lastName.trim();
    if (f.isNotEmpty && l.isNotEmpty) return '${f[0]}${l[0]}'.toUpperCase();
    if (f.isNotEmpty) return f[0].toUpperCase();
    return email.isNotEmpty ? email[0].toUpperCase() : '?';
  }

  String get roleLabel => switch (role) {
    'super_admin'  => 'Super Admin',
    'admin_groupe' => 'Admin Groupe',
    _              => role,
  };

  String get lastLoginLabel {
    if (lastLogin == null) return 'Jamais';
    final diff = DateTime.now().difference(lastLogin!);
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24)   return 'Aujourd\'hui';
    if (diff.inDays == 1)    return 'Hier';
    if (diff.inDays < 30)    return 'Il y a ${diff.inDays} j';
    if (diff.inDays < 365)   return 'Il y a ${(diff.inDays / 30).round()} mois';
    return 'Il y a ${(diff.inDays / 365).round()} an(s)';
  }
}

// ─── Modèle GroupInfo (pour le sélecteur dans le formulaire) ─────────────────

class GroupInfo {
  const GroupInfo({required this.id, required this.name, this.logoUrl});
  final String id, name;
  final String? logoUrl;
}

// ─── Modèle données globales ──────────────────────────────────────────────────

class AdminsData {
  const AdminsData({
    required this.admins,
    required this.groups,
    required this.total,
    required this.superAdmins,
    required this.adminsGroupe,
    required this.actifs,
    required this.connectes7j,
  });

  final List<AdminDetail> admins;
  final List<GroupInfo>   groups;
  final int total, superAdmins, adminsGroupe, actifs, connectes7j;

  static const empty = AdminsData(
    admins: [], groups: [], total: 0,
    superAdmins: 0, adminsGroupe: 0, actifs: 0, connectes7j: 0,
  );
}

// ─── Provider principal ───────────────────────────────────────────────────────

final administratorsProvider =
    FutureProvider.autoDispose<AdminsData>((ref) async {
  ref.keepAlive();
  final client = ref.watch(supabaseClientProvider);

  // Realtime : invalidation silencieuse sur changements profiles
  Timer? debounce;
  try {
    final channel = client.channel('platform_admins_list')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'profiles',
          callback: (_) {
            debounce?.cancel();
            debounce = Timer(const Duration(seconds: 2), () => ref.invalidateSelf());
          },
        )
        .subscribe();
    ref.onDispose(() {
      debounce?.cancel();
      client.removeChannel(channel);
    });
  } catch (_) {}

  // ── Admins plateforme (via RPC SECURITY DEFINER) ──────────────────────────
  List<AdminDetail> admins = [];
  try {
    final rows = await client.rpc('get_platform_admins') as List;
    admins = rows.map((r) => AdminDetail.fromMap(Map<String, dynamic>.from(r as Map))).toList();
  } catch (_) {}

  // ── Groupes scolaires actifs (pour le formulaire) ─────────────────────────
  List<GroupInfo> groups = [];
  try {
    final rows = await client
        .from('school_groups')
        .select('id, name, logo_url')
        .eq('is_active', true)
        .order('name') as List;
    groups = rows.map((r) => GroupInfo(
      id:      r['id']       as String,
      name:    r['name']     as String,
      logoUrl: r['logo_url'] as String?,
    )).toList();
  } catch (_) {}

  // ── KPIs ──────────────────────────────────────────────────────────────────
  int superAdmins = 0, adminsGroupe = 0, actifs = 0, connectes7j = 0;
  final since7j   = DateTime.now().subtract(const Duration(days: 7));
  for (final a in admins) {
    if (a.role == 'super_admin')  superAdmins++;
    if (a.role == 'admin_groupe') adminsGroupe++;
    if (a.isActive)               actifs++;
    if (a.lastLogin != null && a.lastLogin!.isAfter(since7j)) connectes7j++;
  }

  return AdminsData(
    admins:       admins,
    groups:       groups,
    total:        admins.length,
    superAdmins:  superAdmins,
    adminsGroupe: adminsGroupe,
    actifs:       actifs,
    connectes7j:  connectes7j,
  );
});
