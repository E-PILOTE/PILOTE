import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:realtime_client/realtime_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show CountOption;

import '../../../core/utils/paged_fetch.dart';
import '../../../core/utils/plan_referential_realtime.dart';
import '../../../features/auth/providers/auth_provider.dart';
import 'admin_dashboard_provider.dart';
import 'admin_regional_provider.dart';

// ─── Détail d'une école ─────────────────────────────────────────────────────
class SchoolDetail {
  const SchoolDetail({
    required this.id,
    required this.name,
    required this.type,
    required this.isActive,
    required this.students,
    required this.staff,
    required this.classes,
    this.code,
    this.address,
    this.city,
    this.province,
    this.arrondissement,
    this.department,
    this.phone,
    this.email,
    this.website,
    this.motto,
    this.foundedYear,
    this.directorId,
    this.logoUrl,
    this.capacity,
    this.latitude,
    this.longitude,
    this.locationSource,
  });
  final String id;
  final String name;
  final String type;
  final bool isActive;
  final int students;
  final int staff;
  final int classes;
  final String? code;
  final String? address;
  final String? city;
  final String? province;
  final String? arrondissement;
  final String? department;
  final String? phone;
  final String? email;
  final String? website;
  final String? motto;
  final int? foundedYear;
  final String? directorId;
  final String? logoUrl;
  final int? capacity;
  final double? latitude;
  final double? longitude;
  final String? locationSource; // 'gps' | 'geocoded' | 'manual'

  /// Taux d'occupation = effectif / capacité. null si capacité non renseignée.
  double? get occupancy =>
      (capacity != null && capacity! > 0) ? students / capacity! : null;

  bool get hasGps => latitude != null && longitude != null;
}

class AdminSchoolsData {
  const AdminSchoolsData({
    required this.schools,
    required this.maxSchools,
    required this.maxStudents,
    required this.planName,
    required this.totalStudents,
    required this.groupType,
  });
  final List<SchoolDetail> schools;
  final int maxSchools;
  final int maxStudents;
  final int totalStudents;
  final String planName;

  /// Secteur du groupe (`public` | `prive`). Une école en hérite : son secteur
  /// n'est jamais saisi, il suit celui du groupe (verrou en base, migration 0060).
  final String groupType;

  bool get quotaReached => maxSchools > 0 && schools.length >= maxSchools;

  static const empty = AdminSchoolsData(
    schools: [], maxSchools: 0, maxStudents: 0, planName: '—', totalStudents: 0,
    groupType: 'prive');
}

// ─── Provider liste ─────────────────────────────────────────────────────────
final adminSchoolsProvider =
    FutureProvider.autoDispose<AdminSchoolsData>((ref) async {
  ref.keepAlive();
  final client  = ref.watch(supabaseClientProvider);
  final groupId = ref.watch(authNotifierProvider).valueOrNull?.groupId;
  if (groupId == null) return AdminSchoolsData.empty;

  Timer? debounce;
  try {
    final channel = client.channel('admin_schools_$groupId');
    for (final t in ['schools', 'students', 'staff_members', 'classes']) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: t,
        filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq, column: 'group_id', value: groupId),
        callback: (_) {
          debounce?.cancel();
          debounce = Timer(const Duration(seconds: 2), () => ref.invalidateSelf());
        },
      );
    }
    // Le bandeau « X / Y écoles » compare au quota du PLAN : il doit suivre un
    // changement de plan comme un changement d'école.
    channel.watchPlanReferential(() {
      debounce?.cancel();
      debounce = Timer(const Duration(seconds: 2), () => ref.invalidateSelf());
    });
    channel.subscribe();
    ref.onDispose(() {
      debounce?.cancel();
      client.removeChannel(channel);
    });
  } catch (_) {}

  // Plan / quotas
  //  Pas de `catch` muet ici : un quota qu'on n'a pas pu lire s'affichait
  //  « Illimité », c'est-à-dire l'inverse de ce qu'il faut croire sur une
  //  plateforme vendue par paliers. Un groupe SANS plan rend légitimement
  //  `null` (`maybeSingle`) et garde les valeurs par défaut ; une requête qui
  //  ÉCHOUE, elle, doit faire échouer la page — l'écran sait le dire.
  int maxSchools = 0, maxStudents = 0;
  String planName = '—';
  String groupType = 'prive';
  final g = await client
      .from('school_groups')
      .select('group_type, subscription_plans!plan_id(name, max_schools, max_students)')
      .eq('id', groupId)
      .maybeSingle();
  groupType = g?['group_type'] as String? ?? 'prive';
  final plan = g?['subscription_plans'] as Map<String, dynamic>?;
  planName    = plan?['name'] as String? ?? '—';
  maxSchools  = (plan?['max_schools']  as int?) ?? 0;
  maxStudents = (plan?['max_students'] as int?) ?? 0;

  // ── Comptages : AGRÉGATION SERVEUR ────────────────────────────────────────
  //
  //  ⚠️ POSTGREST TRONQUE UNE LECTURE DE TABLE À 1 000 LIGNES, SANS RIEN DIRE.
  //
  //  La version précédente rapatriait une ligne par élève, par agent et par
  //  classe du groupe pour les compter en Dart. Mesuré sur la base réelle
  //  portée à 1 010 écoles et 1 775 élèves : la page annonçait « 1000 écoles »
  //  et « 1000 élèves ». Ni erreur, ni avertissement — deux chiffres faux
  //  affichés comme justes, sur la page qui sert à piloter le groupe.
  //
  //  Les RPC échappent à ce plafond (mesuré : 1 010 lignes rendues). Les
  //  comptes viennent donc d'un GROUP BY Postgres, et le total d'un `count`
  //  exact côté serveur — lequel reste juste même si la réponse était bornée,
  //  puisqu'il est lu dans l'en-tête Content-Range et non compté en Dart.
  final Map<String, int> stu = {}, sta = {}, cls = {};
  final counts = await client
      .rpc('group_school_counts', params: {'p_group_id': groupId}) as List;
  for (final r in counts) {
    final k = r['school_id'] as String? ?? '';
    stu[k] = (r['students'] as num?)?.toInt() ?? 0;
    sta[k] = (r['staff'] as num?)?.toInt() ?? 0;
    cls[k] = (r['classes'] as num?)?.toInt() ?? 0;
  }
  final totalStudents = (await client
          .from('students')
          .select('id')
          .eq('group_id', groupId)
          .eq('is_active', true)
          .count(CountOption.exact))
      .count;

  // ── Écoles ────────────────────────────────────────────────────────────────
  //  Même plafond, même remède : `fetchAllRows` pagine jusqu'à épuisement.
  //  Une page pleine ne prouve pas qu'il n'y a plus rien après elle — c'est
  //  exactement ainsi que 1 010 écoles devenaient 1 000.
  final List<SchoolDetail> schools = [];
  {
    final rows = await fetchAllRows(() => client.from('schools').select(
            'id, name, school_type, school_code, address, city, province, '
            'arrondissement, department, phone, email, website, motto, '
            'founded_year, director_id, logo_url, is_active, capacity, '
            'latitude, longitude, location_source')
        .eq('group_id', groupId)
        // ⚠️ `name` seul n'est pas un ordre TOTAL : des écoles homonymes
        // existent (« École Primaire de Kinkala » revient d'un département à
        // l'autre). Or `fetchAllRows` rejoue la requête page par page, et deux
        // requêtes successives n'ont aucune obligation de rendre les ex æquo
        // dans le même ordre. Une école pouvait donc être sautée à la frontière
        // de deux pages, ou comptée deux fois. `id` clôt le tri.
        .order('name', ascending: true)
        .order('id'));
    for (final s in rows) {
      final id = s['id'] as String;
      schools.add(SchoolDetail(
        id:             id,
        name:           s['name'] as String? ?? '—',
        type:           s['school_type'] as String? ?? 'prive',
        code:           s['school_code'] as String?,
        address:        s['address'] as String?,
        city:           s['city'] as String?,
        province:       s['province'] as String?,
        arrondissement: s['arrondissement'] as String?,
        department:     s['department'] as String?,
        phone:          s['phone'] as String?,
        email:          s['email'] as String?,
        website:        s['website'] as String?,
        motto:          s['motto'] as String?,
        foundedYear:    s['founded_year'] as int?,
        directorId:     s['director_id'] as String?,
        logoUrl:        s['logo_url'] as String?,
        capacity:       s['capacity'] as int?,
        latitude:       (s['latitude']  as num?)?.toDouble(),
        longitude:      (s['longitude'] as num?)?.toDouble(),
        locationSource: s['location_source'] as String?,
        isActive:       s['is_active'] as bool? ?? true,
        students:       stu[id] ?? 0,
        staff:          sta[id] ?? 0,
        classes:        cls[id] ?? 0,
      ));
    }
  }

  return AdminSchoolsData(
    schools: schools,
    maxSchools: maxSchools,
    maxStudents: maxStudents,
    totalStudents: totalStudents,
    planName: planName,
    groupType: groupType,
  );
});

// ─── Mutations ──────────────────────────────────────────────────────────────
class AdminSchoolsService {
  AdminSchoolsService(this._ref);
  final Ref _ref;

  // Une école touchée impacte la liste, la carte régionale et le dashboard.
  void _refreshAll() {
    _ref.invalidate(adminSchoolsProvider);
    _ref.invalidate(adminRegionalProvider);
    _ref.invalidate(adminDashboardProvider);
  }

  /// Crée une école et renvoie son identifiant (nécessaire pour enregistrer
  /// l'offre éducative — cycles/filières/niveaux — dans la foulée).
  Future<String> create({
    required String name,
    required String type,
    String? code,
    String? address,
    String? city,
    String? province,
    String? arrondissement,
    String? department,
    String? phone,
    String? email,
    String? website,
    String? motto,
    int? foundedYear,
    String? logoUrl,
    int? capacity,
  }) async {
    final client  = _ref.read(supabaseClientProvider);
    final groupId = _ref.read(authNotifierProvider).valueOrNull?.groupId;
    if (groupId == null) throw Exception('Groupe introuvable');
    final row = await client.from('schools').insert({
      'group_id': groupId,
      'name': name,
      'school_type': type,
      if (code != null && code.isNotEmpty) 'school_code': code,
      if (address != null && address.isNotEmpty) 'address': address,
      if (city != null && city.isNotEmpty) 'city': city,
      if (province != null && province.isNotEmpty) 'province': province,
      if (arrondissement != null && arrondissement.isNotEmpty) 'arrondissement': arrondissement,
      if (department != null && department.isNotEmpty) 'department': department,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (email != null && email.isNotEmpty) 'email': email,
      if (website != null && website.isNotEmpty) 'website': website,
      if (motto != null && motto.isNotEmpty) 'motto': motto,
      if (logoUrl != null && logoUrl.isNotEmpty) 'logo_url': logoUrl,
      'capacity': ?capacity,
      'founded_year': ?foundedYear,
    }).select('id').single();
    _refreshAll();
    return row['id'] as String;
  }

  Future<void> update({
    required String id,
    required String name,
    required String type,
    String? code,
    String? address,
    String? city,
    String? province,
    String? arrondissement,
    String? department,
    String? phone,
    String? email,
    String? website,
    String? motto,
    int? foundedYear,
    String? logoUrl,
    int? capacity,
  }) async {
    final client = _ref.read(supabaseClientProvider);
    await client.from('schools').update({
      'name': name,
      'school_type': type,
      'school_code': (code != null && code.isNotEmpty) ? code : null,
      'address': (address != null && address.isNotEmpty) ? address : null,
      'city': (city != null && city.isNotEmpty) ? city : null,
      'province': (province != null && province.isNotEmpty) ? province : null,
      'arrondissement': (arrondissement != null && arrondissement.isNotEmpty) ? arrondissement : null,
      'department': (department != null && department.isNotEmpty) ? department : null,
      'phone': (phone != null && phone.isNotEmpty) ? phone : null,
      'email': (email != null && email.isNotEmpty) ? email : null,
      'website': (website != null && website.isNotEmpty) ? website : null,
      'motto': (motto != null && motto.isNotEmpty) ? motto : null,
      'logo_url': (logoUrl != null && logoUrl.isNotEmpty) ? logoUrl : null,
      'founded_year': foundedYear,
      'capacity': capacity,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
    _refreshAll();
  }

  Future<void> setActive(String id, bool active) async {
    final client = _ref.read(supabaseClientProvider);
    await client.from('schools').update({
      'is_active': active,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
    _refreshAll();
  }

  /// Active/désactive plusieurs écoles en une seule requête (actions groupées).
  Future<void> setActiveBulk(List<String> ids, bool active) async {
    if (ids.isEmpty) return;
    final client = _ref.read(supabaseClientProvider);
    await client.from('schools').update({
      'is_active': active,
      'updated_at': DateTime.now().toIso8601String(),
    }).inFilter('id', ids);
    _refreshAll();
  }
}

final adminSchoolsServiceProvider =
    Provider<AdminSchoolsService>((ref) => AdminSchoolsService(ref));

// ─── Utilisateurs d'une école (profils + profil d'accès lié) ────────────────
class SchoolUser {
  const SchoolUser({
    required this.id,
    required this.fullName,
    required this.role,
    required this.isActive,
    this.accessProfileName,
  });

  factory SchoolUser.fromRow(Map<String, dynamic> r) {
    final ap = r['access_profiles'] as Map<String, dynamic>?;
    return SchoolUser(
      id:                r['id'] as String,
      fullName:          ('${r['first_name'] ?? ''} ${r['last_name'] ?? ''}').trim(),
      role:              r['role'] as String? ?? '—',
      isActive:          r['is_active'] as bool? ?? true,
      accessProfileName: ap?['name'] as String?,
    );
  }

  final String id;
  final String fullName;
  final String role;
  final bool isActive;
  final String? accessProfileName;
}

final schoolUsersProvider =
    FutureProvider.autoDispose.family<List<SchoolUser>, String>((ref, schoolId) async {
  ref.keepAlive();
  if (schoolId.isEmpty) return [];
  final client = ref.watch(supabaseClientProvider);
  try {
    final rows = await client
        .from('profiles')
        .select('id, first_name, last_name, role, is_active, access_profiles(id, name)')
        .eq('school_id', schoolId)
        .order('last_name', ascending: true) as List;
    return [for (final r in rows) SchoolUser.fromRow(r as Map<String, dynamic>)];
  } catch (_) {
    // Fallback sans join si la FK n'est pas exposée en REST
    try {
      final rows = await client
          .from('profiles')
          .select('id, first_name, last_name, role, is_active')
          .eq('school_id', schoolId)
          .order('last_name', ascending: true) as List;
      return [for (final r in rows) SchoolUser.fromRow(r as Map<String, dynamic>)];
    } catch (_) {
      return [];
    }
  }
});
