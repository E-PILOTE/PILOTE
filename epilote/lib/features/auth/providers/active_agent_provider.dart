import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../services/powersync/powersync_service.dart';
import 'auth_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  IDENTITÉ « AGENT ACTIF » — postes partagés hors-ligne (réalité Congo).
//
//  Modèle : l'APPAREIL s'authentifie une fois en ligne (compte direction, large)
//  → PowerSync synchronise les données de l'école et la connexion persiste,
//  utilisable des semaines hors-ligne. Au quotidien, les agents (comptable,
//  secrétaire, enseignant, directeur…) ne se reconnectent PAS via Supabase : ils
//  basculent localement via ce sélecteur + un code PIN court (haché en local,
//  jamais synchronisé). L'agent actif pilote :
//    • les permissions/UI (verrou 3) — via son access_profile_id local ;
//    • l'attribution des écritures (created_by/updated_by + audit).
//
//  Sécurité : le PIN est un verrou d'ATTRIBUTION (« qui est au clavier »), pas
//  une authentification cryptographique — impossible hors-ligne. La vraie
//  frontière serveur reste la session Supabase de l'appareil + la RLS.
// ════════════════════════════════════════════════════════════════════════════

/// Agent sélectionné localement (null = on retombe sur l'utilisateur appareil).
/// En mémoire uniquement : au redémarrage, on redemande (plus sûr sur un poste
/// partagé — le suivant n'hérite pas de la session du précédent).
final selectedAgentIdProvider = StateProvider<String?>((_) => null);

/// Identité effective de l'agent au clavier : sélection locale, ou à défaut
/// l'utilisateur qui a authentifié l'appareil.
final activeAgentIdProvider = Provider<String?>((ref) {
  final selected = ref.watch(selectedAgentIdProvider);
  final deviceId = ref.watch(authNotifierProvider).valueOrNull?.id;
  return selected ?? deviceId;
});

/// Un agent sélectionnable (collègue de la même école, lu en local).
class AgentOption {
  const AgentOption({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.accessProfileId,
    this.avatarUrl,
    this.phone,
    this.dateOfBirth,
    this.employeeNumber,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String role;
  final String? accessProfileId;
  final String? avatarUrl;
  final String? phone;
  final DateTime? dateOfBirth;
  final String? employeeNumber;

  String get fullName {
    final n = '${firstName.trim()} ${lastName.trim()}'.trim();
    return n.isEmpty ? '—' : n;
  }

  String get initials {
    final f = firstName.trim();
    final l = lastName.trim();
    if (f.isNotEmpty && l.isNotEmpty) return '${f[0]}${l[0]}'.toUpperCase();
    if (f.isNotEmpty) return f[0].toUpperCase();
    return '?';
  }
}

/// Agents disponibles sur cet appareil = personnel actif de l'école synchronisée
/// localement (100% offline, db.watch sur `profiles`).
final switchableAgentsProvider =
    StreamProvider.autoDispose<List<AgentOption>>((ref) {
  final schoolId = ref.watch(authNotifierProvider).valueOrNull?.schoolId;
  if (schoolId == null || schoolId.isEmpty) return Stream.value(const []);
  return db
      .watch(
        '''
        SELECT id, first_name, last_name, role, access_profile_id, avatar_url,
               phone, date_of_birth, employee_number
        FROM   profiles
        WHERE  school_id = ? AND is_active = 1
        ORDER  BY last_name, first_name
        ''',
        parameters: [schoolId],
      )
      .map((rows) => [
            for (final r in rows)
              AgentOption(
                id:               r['id'] as String,
                firstName:        r['first_name'] as String? ?? '',
                lastName:         r['last_name'] as String? ?? '',
                role:             r['role'] as String? ?? '',
                accessProfileId:  r['access_profile_id'] as String?,
                avatarUrl:        r['avatar_url'] as String?,
                phone:            r['phone'] as String?,
                dateOfBirth: (r['date_of_birth'] as String?) != null
                    ? DateTime.tryParse(r['date_of_birth'] as String)
                    : null,
                employeeNumber:   r['employee_number'] as String?,
              ),
          ]);
});

/// access_profile_id de l'agent actif (lu en local) — pilote les permissions.
final activeAgentAccessProfileIdProvider =
    StreamProvider.autoDispose<String?>((ref) {
  final id = ref.watch(activeAgentIdProvider);
  if (id == null || id.isEmpty) return Stream.value(null);
  return db
      .watch('SELECT access_profile_id FROM profiles WHERE id = ? LIMIT 1',
          parameters: [id])
      .map((rows) =>
          rows.isEmpty ? null : rows.first['access_profile_id'] as String?);
});

/// Pause anti-force-brute selon le nombre d'échecs consécutifs (fonction pure,
/// testable). Verrou d'attribution → dissuasif mais jamais définitif : on ne
/// bloque jamais durablement un collègue légitime sur un poste partagé.
Duration pinCooldown(int failCount) {
  if (failCount < 5) return Duration.zero;
  switch (failCount) {
    case 5:
      return const Duration(seconds: 30);
    case 6:
      return const Duration(seconds: 60);
    case 7:
      return const Duration(minutes: 2);
    default:
      return const Duration(minutes: 5); // plafond
  }
}

// ─── Service PIN (haché localement, jamais synchronisé) ─────────────────────
class AgentPinService {
  const AgentPinService();

  String _key(String profileId) => 'agent_pin_$profileId';
  String _failKey(String profileId) => 'agent_fails_$profileId';
  String _untilKey(String profileId) => 'agent_lock_until_$profileId';
  String _setAtKey(String profileId) => 'agent_pin_set_at_$profileId';
  static const _recentKey = 'agent_recent_ids';

  // sha256(profileId ⊕ pin) — sel = profileId (ralentit un dictionnaire global).
  String _hash(String profileId, String pin) =>
      sha256.convert(utf8.encode('$profileId::$pin')).toString();

  Future<bool> hasPin(String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_key(profileId));
  }

  Future<void> setPin(String profileId, String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(profileId), _hash(profileId, pin));
    await prefs.setInt(
        _setAtKey(profileId), DateTime.now().millisecondsSinceEpoch);
    await prefs.remove(_failKey(profileId));
    await prefs.remove(_untilKey(profileId));
  }

  Future<bool> verifyPin(String profileId, String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key(profileId));
    if (stored == null) return false;
    return stored == _hash(profileId, pin);
  }

  /// Date de création du PIN local (sert à la réconciliation d'un reset serveur
  /// en Phase 2 : un reset plus récent invalide le PIN local).
  Future<DateTime?> pinSetAt(String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_setAtKey(profileId));
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  // ── Anti-force-brute (persisté par agent, survit au redémarrage) ──
  Future<int> failCount(String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_failKey(profileId)) ?? 0;
  }

  Future<void> recordFail(String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    final n = (prefs.getInt(_failKey(profileId)) ?? 0) + 1;
    await prefs.setInt(_failKey(profileId), n);
    final cd = pinCooldown(n);
    if (cd > Duration.zero) {
      await prefs.setInt(_untilKey(profileId),
          DateTime.now().add(cd).millisecondsSinceEpoch);
    }
  }

  /// Instant de fin de verrouillage s'il est encore actif, sinon null.
  Future<DateTime?> lockedUntil(String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_untilKey(profileId));
    if (ms == null) return null;
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return dt.isAfter(DateTime.now()) ? dt : null;
  }

  Future<void> clearFails(String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_failKey(profileId));
    await prefs.remove(_untilKey(profileId));
  }

  // ── Récemment utilisés (bascule rapide sur poste partagé) ──
  Future<List<String>> recentIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_recentKey) ?? const [];
  }

  Future<void> recordUsage(String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = [...?prefs.getStringList(_recentKey)]
      ..remove(profileId)
      ..insert(0, profileId);
    if (list.length > 8) list.removeRange(8, list.length);
    await prefs.setStringList(_recentKey, list);
  }

  /// Purge tous les PIN (vraie déconnexion / réinitialisation de l'appareil).
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    for (final k in prefs
        .getKeys()
        .where((k) => k.startsWith('agent_pin_') || k.startsWith('agent_fails_')
            || k.startsWith('agent_lock_until_'))) {
      await prefs.remove(k);
    }
  }
}

final agentPinServiceProvider =
    Provider<AgentPinService>((ref) => const AgentPinService());

// ─── Mode d'appareil : poste PARTAGÉ vs poste PERSONNEL ─────────────────────
//  Beaucoup d'écoles publiques n'ont qu'un seul ordinateur (→ partagé, verrou +
//  bascule d'agent). Là où chacun a sa machine (→ personnel), l'utilisateur
//  connecté EST l'agent : aucun verrou, aucune friction. Choix stocké par
//  appareil, demandé une fois après la connexion, modifiable dans Paramètres.
enum DeviceMode { shared, personal }

/// État du mode d'appareil : [loaded] évite d'afficher le sélecteur de mode
/// tant que la préférence n'est pas relue du disque.
class DeviceModeState {
  const DeviceModeState({required this.loaded, this.mode});
  final bool loaded;
  final DeviceMode? mode;
}

class DeviceModeNotifier extends Notifier<DeviceModeState> {
  static const _key = 'device_mode';

  @override
  DeviceModeState build() {
    _load();
    return const DeviceModeState(loaded: false);
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = DeviceModeState(loaded: true, mode: _parse(prefs.getString(_key)));
  }

  Future<void> set(DeviceMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
    state = DeviceModeState(loaded: true, mode: mode);
  }

  DeviceMode? _parse(String? v) => switch (v) {
        'shared' => DeviceMode.shared,
        'personal' => DeviceMode.personal,
        _ => null,
      };
}

final deviceModeProvider =
    NotifierProvider<DeviceModeNotifier, DeviceModeState>(
        DeviceModeNotifier.new);

/// Bascule d'agent à la demande (« Changer d'utilisateur ») même en poste
/// personnel : force le sélecteur de profils une fois, remis à false au choix.
final forceAgentPickerProvider = StateProvider<bool>((_) => false);

// ─── Verrouillage « poste partagé » ─────────────────────────────────────────
// Rôles qui NE sont PAS des agents d'un poste scolaire partagé.
const Set<String> _nonAgentRoles = {
  AppConstants.roleSuperAdmin,
  AppConstants.roleAdminGroupe,
  AppConstants.roleParent,
  AppConstants.roleEleve,
};

/// Le verrou (et le menu « Changer d'utilisateur ») s'appliquent au personnel
/// scolaire d'un poste partagé — tout rôle non vide hors [_nonAgentRoles].
bool agentLockApplies(String? role) =>
    role != null && role.isNotEmpty && !_nonAgentRoles.contains(role);

/// Décision pure : faut-il imposer l'écran-verrou ?
/// - pas de session / rôle hors public agent → non ;
/// - aucun agent encore synchronisé → non (on n'enferme jamais dehors) ;
/// - agent déjà sélectionné → non ;
/// - bascule forcée (menu) → oui ;
/// - sinon : verrou uniquement en mode POSTE PARTAGÉ.
bool computeNeedsAgentUnlock({
  required String? deviceRole,
  required bool hasAgents,
  required String? selectedAgentId,
  DeviceMode? deviceMode,
  bool forcePicker = false,
}) {
  if (!agentLockApplies(deviceRole)) return false;
  if (!hasAgents) return false;
  if (selectedAgentId != null) return false;
  if (forcePicker) return true;
  return deviceMode == DeviceMode.shared;
}

/// Décision pure : faut-il demander le mode d'appareil ? Une seule fois, quand
/// le personnel est connecté, la préférence absente et des agents synchronisés.
bool computeNeedsDeviceModeChoice({
  required String? deviceRole,
  required DeviceMode? deviceMode,
  required bool hasAgents,
}) {
  if (!agentLockApplies(deviceRole)) return false;
  if (deviceMode != null) return false;
  return hasAgents;
}

/// Câble la décision de verrou aux providers existants.
final needsAgentUnlockProvider = Provider<bool>((ref) {
  final role = ref.watch(authNotifierProvider).valueOrNull?.role;
  final agents = ref.watch(switchableAgentsProvider).valueOrNull ?? const [];
  final selected = ref.watch(selectedAgentIdProvider);
  final dm = ref.watch(deviceModeProvider);
  final force = ref.watch(forceAgentPickerProvider);
  if (!dm.loaded) return false;
  return computeNeedsAgentUnlock(
    deviceRole: role,
    hasAgents: agents.isNotEmpty,
    selectedAgentId: selected,
    deviceMode: dm.mode,
    forcePicker: force,
  );
});

/// Câble la décision « demander le mode » aux providers existants.
final needsDeviceModeChoiceProvider = Provider<bool>((ref) {
  final role = ref.watch(authNotifierProvider).valueOrNull?.role;
  final agents = ref.watch(switchableAgentsProvider).valueOrNull ?? const [];
  final dm = ref.watch(deviceModeProvider);
  if (!dm.loaded) return false;
  return computeNeedsDeviceModeChoice(
    deviceRole: role,
    deviceMode: dm.mode,
    hasAgents: agents.isNotEmpty,
  );
});
