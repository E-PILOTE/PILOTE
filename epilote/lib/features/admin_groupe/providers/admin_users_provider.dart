import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:realtime_client/realtime_client.dart';

import '../../../features/auth/providers/auth_provider.dart';

// ─── Rôles métier (personnel scolaire) ──────────────────────────────────────
// L'enum user_role n'a PAS de 'utilisateur' : le rôle EST le métier.
const List<({String value, String label})> kStaffRoles = [
  (value: 'directeur',           label: 'Directeur'),
  (value: 'proviseur',           label: 'Proviseur'),
  (value: 'enseignant',          label: 'Enseignant'),
  (value: 'cpe',                 label: 'CPE'),
  (value: 'comptable',           label: 'Comptable'),
  (value: 'secretaire',          label: 'Secrétaire'),
  (value: 'surveillant',         label: 'Surveillant'),
  (value: 'infirmier',           label: 'Infirmier'),
  (value: 'responsable_cantine', label: 'Responsable cantine'),
];

String roleLabel(String role) => switch (role) {
  'directeur'           => 'Directeur',
  'proviseur'           => 'Proviseur',
  'enseignant'          => 'Enseignant',
  'cpe'                 => 'CPE',
  'comptable'           => 'Comptable',
  'secretaire'          => 'Secrétaire',
  'surveillant'         => 'Surveillant',
  'infirmier'           => 'Infirmier',
  'responsable_cantine' => 'Responsable cantine',
  'parent'              => 'Parent',
  'eleve'               => 'Élève',
  'admin_groupe'        => 'Admin Groupe',
  'super_admin'         => 'Super Admin',
  _                     => role,
};

// ─── Modèles ────────────────────────────────────────────────────────────────
class AdminUser {
  const AdminUser({
    required this.id,
    required this.email,
    required this.role,
    required this.firstName,
    required this.lastName,
    required this.isActive,
    this.phone,
    this.employeeNumber,
    this.schoolId,
    this.schoolName,
    this.accessProfileId,
    this.accessProfileName,
    this.lastLogin,
    this.createdAt,
    this.gender,
    this.dateOfBirth,
    this.address,
    this.birthPlace,
    this.employmentStatus,
    this.grade,
    this.echelon,
    this.category,
    this.speciality,
    this.hireDate,
  });

  factory AdminUser.fromMap(Map<String, dynamic> m) => AdminUser(
        id:                 m['id'] as String,
        email:              m['email'] as String? ?? '',
        role:               m['role'] as String? ?? '',
        firstName:          m['first_name'] as String? ?? '',
        lastName:           m['last_name'] as String? ?? '',
        phone:              m['phone'] as String?,
        employeeNumber:     m['employee_number'] as String?,
        isActive:           m['is_active'] as bool? ?? true,
        schoolId:           m['school_id'] as String?,
        schoolName:         m['school_name'] as String?,
        accessProfileId:    m['access_profile_id'] as String?,
        accessProfileName:  m['access_profile_name'] as String?,
        lastLogin: m['last_login'] != null
            ? DateTime.tryParse(m['last_login'] as String)
            : null,
        createdAt: m['created_at'] != null
            ? DateTime.tryParse(m['created_at'] as String)
            : null,
        gender:     m['gender'] as String?,
        dateOfBirth: m['date_of_birth'] != null
            ? DateTime.tryParse(m['date_of_birth'] as String)
            : null,
        address:    m['address'] as String?,
        birthPlace: m['birth_place'] as String?,
        employmentStatus: m['employment_status'] as String?,
        grade:      m['grade'] as String?,
        echelon:    m['echelon'] as String?,
        category:   m['category'] as String?,
        speciality: m['speciality'] as String?,
        hireDate: m['hire_date'] != null
            ? DateTime.tryParse(m['hire_date'] as String)
            : null,
      );

  final String id;
  final String email;
  final String role;
  final String firstName;
  final String lastName;
  final bool isActive;
  final String? phone;
  final String? employeeNumber;
  final String? schoolId;
  final String? schoolName;
  final String? accessProfileId;
  final String? accessProfileName;
  final DateTime? lastLogin;
  final DateTime? createdAt;
  // Nouveaux champs (migration add_extended_profile_fields)
  final String?   gender;
  final DateTime? dateOfBirth;
  final String?   address;
  final String?   birthPlace;
  // Volet carrière RH (migration 0023)
  final String?   employmentStatus;
  final String?   grade;
  final String?   echelon;
  final String?   category;
  final String?   speciality;
  final DateTime? hireDate;

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

  String get roleLbl => roleLabel(role);

  String get lastLoginLabel {
    if (lastLogin == null) return 'Jamais connecté';
    final diff = DateTime.now().difference(lastLogin!);
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24)   return "Aujourd'hui";
    if (diff.inDays == 1)    return 'Hier';
    if (diff.inDays < 30)    return 'Il y a ${diff.inDays} j';
    if (diff.inDays < 365)   return 'Il y a ${(diff.inDays / 30).round()} mois';
    return 'Il y a ${(diff.inDays / 365).round()} an(s)';
  }

  String get genderLabel => switch (gender) {
    'M'   => 'Masculin',
    'F'   => 'Féminin',
    'autre' => 'Autre',
    _     => '—',
  };
}

class SchoolOption {
  const SchoolOption({required this.id, required this.name});
  final String id;
  final String name;
}

class AccessProfileOption {
  const AccessProfileOption({required this.id, required this.name});
  final String id;
  final String name;
}

class AdminUsersData {
  const AdminUsersData({
    required this.users,
    required this.schools,
    required this.accessProfiles,
  });
  final List<AdminUser> users;
  final List<SchoolOption> schools;
  final List<AccessProfileOption> accessProfiles;

  int get total    => users.length;
  int get actifs   => users.where((u) => u.isActive).length;
  int get inactifs => total - actifs;
  int get enseignants    => users.where((u) => u.role == 'enseignant').length;
  int get administration => total - enseignants;
  int get connectes7j {
    final since = DateTime.now().subtract(const Duration(days: 7));
    return users.where((u) => u.lastLogin != null && u.lastLogin!.isAfter(since)).length;
  }

  static const empty = AdminUsersData(users: [], schools: [], accessProfiles: []);
}

// ─── Provider liste ─────────────────────────────────────────────────────────
final adminUsersProvider =
    FutureProvider.autoDispose<AdminUsersData>((ref) async {
  ref.keepAlive();
  final client  = ref.watch(supabaseClientProvider);
  final groupId = ref.watch(authNotifierProvider).valueOrNull?.groupId;
  if (groupId == null) return AdminUsersData.empty;

  // Realtime : invalidation silencieuse
  Timer? debounce;
  try {
    final channel = client.channel('admin_users_$groupId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'profiles',
      filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq, column: 'group_id', value: groupId),
      callback: (_) {
        debounce?.cancel();
        debounce = Timer(const Duration(seconds: 2), () => ref.invalidateSelf());
      },
    );
    channel.subscribe();
    ref.onDispose(() {
      debounce?.cancel();
      client.removeChannel(channel);
    });
  } catch (_) {}

  // Utilisateurs (RPC SECURITY DEFINER — email vit dans auth.users)
  final List<AdminUser> users = [];
  try {
    final rows = await client.rpc('get_group_users', params: {'p_group_id': groupId}) as List;
    for (final r in rows) {
      users.add(AdminUser.fromMap(Map<String, dynamic>.from(r as Map)));
    }
  } catch (_) {}

  // Écoles du groupe (pour le formulaire / filtres)
  final List<SchoolOption> schools = [];
  try {
    final rows = await client.from('schools')
        .select('id, name')
        .eq('group_id', groupId)
        .eq('is_active', true)
        .order('name', ascending: true) as List;
    for (final s in rows) {
      schools.add(SchoolOption(id: s['id'] as String, name: s['name'] as String? ?? '—'));
    }
  } catch (_) {}

  // Profils d'accès du groupe
  final List<AccessProfileOption> aps = [];
  try {
    final rows = await client.from('access_profiles')
        .select('id, name')
        .eq('group_id', groupId)
        .eq('is_active', true)
        .order('name', ascending: true) as List;
    for (final a in rows) {
      aps.add(AccessProfileOption(id: a['id'] as String, name: a['name'] as String? ?? '—'));
    }
  } catch (_) {}

  return AdminUsersData(users: users, schools: schools, accessProfiles: aps);
});

// ─── Service mutations ──────────────────────────────────────────────────────
class AdminUsersService {
  AdminUsersService(this._ref);
  final Ref _ref;

  Future<void> createUser({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String schoolId,
    required String role,
    String? accessProfileId,
    String? phone,
    String? employeeNumber,
    String? gender,
    DateTime? dateOfBirth,
    String? address,
    String? birthPlace,
  }) async {
    final client = _ref.read(supabaseClientProvider);
    await client.rpc('create_school_user', params: {
      'p_email':              email,
      'p_password':           password,
      'p_first_name':         firstName,
      'p_last_name':          lastName,
      'p_school_id':          schoolId,
      'p_role':               role,
      'p_access_profile_id':  accessProfileId,
      'p_phone':              phone,
      'p_employee_number':    employeeNumber,
      'p_gender':             gender,
      'p_date_of_birth':      dateOfBirth?.toIso8601String().substring(0, 10),
      'p_address':            address,
      'p_birth_place':        birthPlace,
    });
    _ref.invalidate(adminUsersProvider);
  }

  // L'email est immuable (identité de connexion). Édition = champs profil.
  Future<void> updateUser({
    required String id,
    required String firstName,
    required String lastName,
    required String schoolId,
    required String role,
    String? accessProfileId,
    String? phone,
    String? employeeNumber,
    String? gender,
    DateTime? dateOfBirth,
    String? address,
    String? birthPlace,
    // Volet carrière RH (migration 0023) — renseigné à la source par l'admin.
    String? employmentStatus,
    String? grade,
    String? echelon,
    String? category,
    String? speciality,
    DateTime? hireDate,
  }) async {
    final client = _ref.read(supabaseClientProvider);
    String? nz(String? v) => (v != null && v.trim().isNotEmpty) ? v.trim() : null;
    await client.from('profiles').update({
      'first_name':        firstName,
      'last_name':         lastName,
      'school_id':         schoolId,
      'role':              role,
      'access_profile_id': accessProfileId,
      'phone':             nz(phone),
      'employee_number':   nz(employeeNumber),
      'gender':            nz(gender),
      'date_of_birth':     dateOfBirth?.toIso8601String().substring(0, 10),
      'address':           nz(address),
      'birth_place':       nz(birthPlace),
      'employment_status': nz(employmentStatus),
      'grade':             nz(grade),
      'echelon':           nz(echelon),
      'category':          nz(category),
      'speciality':        nz(speciality),
      'hire_date':         hireDate?.toIso8601String().substring(0, 10),
      'updated_at':        DateTime.now().toIso8601String(),
    }).eq('id', id);
    _ref.invalidate(adminUsersProvider);
  }

  Future<void> setActive(String id, bool active) async {
    final client = _ref.read(supabaseClientProvider);
    await client.from('profiles').update({
      'is_active':  active,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
    _ref.invalidate(adminUsersProvider);
  }

  Future<void> resetPassword(String userId, String newPassword) async {
    final client = _ref.read(supabaseClientProvider);
    await client.rpc('set_school_user_password', params: {
      'p_user_id':  userId,
      'p_password': newPassword,
    });
  }

  /// Réinitialise le code PIN de poste de l'agent : pose un horodatage serveur
  /// qui, synchronisé sur les postes de l'école, invalide le PIN local (l'agent
  /// devra en recréer un). Cf. migration 0033 + `pinResetInvalidates`.
  Future<void> resetAgentPin(String userId) async {
    final client = _ref.read(supabaseClientProvider);
    final now = DateTime.now().toIso8601String();
    await client.from('profiles').update({
      'pin_reset_requested_at': now,
      'updated_at': now,
    }).eq('id', userId);
    _ref.invalidate(adminUsersProvider);
  }
}

final adminUsersServiceProvider =
    Provider<AdminUsersService>((ref) => AdminUsersService(ref));
