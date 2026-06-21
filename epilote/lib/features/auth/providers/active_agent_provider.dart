import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

// ─── Service PIN (haché localement, jamais synchronisé) ─────────────────────
class AgentPinService {
  const AgentPinService();

  String _key(String profileId) => 'agent_pin_$profileId';

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
  }

  Future<bool> verifyPin(String profileId, String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key(profileId));
    if (stored == null) return false;
    return stored == _hash(profileId, pin);
  }

  /// Purge tous les PIN (vraie déconnexion / réinitialisation de l'appareil).
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    for (final k in prefs.getKeys().where((k) => k.startsWith('agent_pin_'))) {
      await prefs.remove(k);
    }
  }
}

final agentPinServiceProvider =
    Provider<AgentPinService>((ref) => const AgentPinService());
