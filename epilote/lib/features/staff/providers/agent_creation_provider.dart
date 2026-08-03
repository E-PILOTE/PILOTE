// ════════════════════════════════════════════════════════════════════════════
//  L'ÉTABLISSEMENT OUVRE LES COMPTES DE SON PERSONNEL
//
//  ── POURQUOI CE CHEMIN EXISTE ──────────────────────────────────────────────
//  Créer un compte exigeait `admin_groupe`. Mille écoles, une vingtaine
//  d'agents chacune : vingt mille comptes par un seul guichet, qui ne connaît
//  ni les noms ni les arrivées de septembre. Le déploiement par vagues ne passe
//  pas ce goulot. Le chef d'établissement, lui, sait qui travaille chez lui.
//
//  ⚠️ CETTE OPÉRATION EST EN LIGNE, ET ELLE NE PEUT PAS ÊTRE AUTREMENT.
//  Un compte de connexion vit dans `auth.users`, hors de PowerSync : il n'y a
//  aucun moyen d'en créer un hors ligne, et un identifiant inventé localement
//  ne permettrait de se connecter nulle part. C'est le seul geste de l'espace
//  école dans ce cas — d'où le soin mis à le DIRE quand le réseau manque,
//  plutôt qu'à échouer sans explication.
//
//  ── LES GARDE-FOUS SONT CÔTÉ SERVEUR ───────────────────────────────────────
//  Rôle de l'appelant, fonctions attribuables, profil d'accès obligatoire,
//  quota d'abonnement : tout est vérifié par `creer_agent_ecole` (migration
//  0088). Ce fichier les rappelle à l'écran pour éviter un aller-retour inutile,
//  il ne les remplace pas — un garde-fou qui vit dans l'interface n'en est pas
//  un.
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';

/// Les fonctions qu'un chef d'établissement peut ouvrir lui-même.
///
/// ⚠️ Tenue identique à `roles_provisionnables_par_ecole()` (migration 0088).
/// Ni directeur ni proviseur : un chef d'établissement ne se fabrique pas un
/// pair hors de portée de sa hiérarchie. Nommer un chef reste un acte de
/// l'autorité de tutelle.
const List<({String value, String label})> kRolesProvisionnablesParEcole = [
  (value: 'enseignant',          label: 'Enseignant'),
  (value: 'secretaire',          label: 'Secrétaire'),
  (value: 'surveillant',         label: 'Surveillant'),
  (value: 'cpe',                 label: 'CPE'),
  (value: 'comptable',           label: 'Comptable'),
  (value: 'infirmier',           label: 'Infirmier'),
  (value: 'responsable_cantine', label: 'Responsable cantine'),
];

/// Un profil d'accès du réseau — ce qui décide de ce que l'agent verra.
class ProfilAcces {
  const ProfilAcces(this.id, this.name);
  final String id, name;
}

/// Ce que l'écran doit savoir AVANT d'ouvrir le formulaire.
class ContexteCreationAgent {
  const ContexteCreationAgent({
    required this.autorise,
    required this.profils,
    this.maxStaff,
    this.agentsActuels = 0,
    this.illimite = true,
    this.horsLigne = false,
  });

  factory ContexteCreationAgent.fromMap(Map<String, dynamic> m) =>
      ContexteCreationAgent(
        autorise: m['autorise'] as bool? ?? false,
        maxStaff: (m['max_staff'] as num?)?.toInt(),
        agentsActuels: (m['agents_actuels'] as num?)?.toInt() ?? 0,
        illimite: m['illimite'] as bool? ?? true,
        profils: [
          for (final p in (m['profils_acces'] as List? ?? const []))
            ProfilAcces(
              (p as Map)['id'] as String,
              p['name'] as String? ?? '—',
            ),
        ],
      );

  /// L'appelant dirige un établissement.
  final bool autorise;
  final List<ProfilAcces> profils;
  final int? maxStaff;
  final int agentsActuels;
  final bool illimite;

  /// La question n'a pas pu être posée. Distinct de « non autorisé » : on ne
  /// dit pas à un directeur qu'il n'a pas le droit alors qu'il est seulement
  /// hors réseau.
  final bool horsLigne;

  /// Places restantes sur l'abonnement, `null` si illimité.
  int? get placesRestantes =>
      (illimite || maxStaff == null) ? null : (maxStaff! - agentsActuels);

  bool get quotaAtteint {
    final r = placesRestantes;
    return r != null && r <= 0;
  }

  /// Sans profil d'accès dans le réseau, un compte créé ouvrirait une
  /// application vide. Mieux vaut le dire avant qu'après.
  bool get aucunProfilDisponible => profils.isEmpty;

  static const indisponible =
      ContexteCreationAgent(autorise: false, profils: [], horsLigne: true);
}

final contexteCreationAgentProvider =
    FutureProvider.autoDispose<ContexteCreationAgent>((ref) async {
  try {
    final client = ref.watch(supabaseClientProvider);
    final res = await client.rpc('contexte_creation_agent');
    if (res is! Map) return ContexteCreationAgent.indisponible;
    return ContexteCreationAgent.fromMap(Map<String, dynamic>.from(res));
  } catch (_) {
    return ContexteCreationAgent.indisponible;
  }
});

/// Échec de création, dit en français à celui qui le lit.
class EchecCreationAgent implements Exception {
  const EchecCreationAgent(this.message);
  final String message;
  @override
  String toString() => message;
}

class AgentCreationService {
  AgentCreationService(this._ref);
  final Ref _ref;

  Future<String> creer({
    required String email,
    required String motDePasse,
    required String prenom,
    required String nom,
    required String role,
    required String profilAccesId,
    String? telephone,
    String? matricule,
    String? genre,
    DateTime? dateNaissance,
    String? lieuNaissance,
  }) async {
    final client = _ref.read(supabaseClientProvider);
    try {
      final id = await client.rpc('creer_agent_ecole', params: {
        'p_email':             email.trim().toLowerCase(),
        'p_password':          motDePasse,
        'p_first_name':        prenom.trim(),
        'p_last_name':         nom.trim(),
        'p_role':              role,
        'p_access_profile_id': profilAccesId,
        'p_phone':             _nz(telephone),
        'p_employee_number':   _nz(matricule),
        'p_gender':            _nz(genre),
        'p_date_of_birth':     dateNaissance?.toIso8601String().substring(0, 10),
        'p_birth_place':       _nz(lieuNaissance),
      });
      _ref.invalidate(contexteCreationAgentProvider);
      return id as String;
    } catch (e) {
      throw EchecCreationAgent(_lisible(e));
    }
  }

  static String? _nz(String? v) =>
      (v != null && v.trim().isNotEmpty) ? v.trim() : null;

  /// Les messages du serveur sont déjà écrits pour être lus ; on retire
  /// seulement l'habillage PostgREST qui les rend illisibles.
  static String _lisible(Object e) {
    final s = e.toString();
    final m = RegExp(r'message:\s*([^,\)]+)').firstMatch(s);
    if (m != null) return m.group(1)!.trim();
    if (s.contains('SocketException') || s.contains('Failed host lookup')) {
      return 'Aucune connexion. La création d\'un compte exige le réseau : '
          'un identifiant de connexion ne peut pas être créé hors ligne.';
    }
    return s;
  }
}

final agentCreationServiceProvider =
    Provider<AgentCreationService>((ref) => AgentCreationService(ref));
