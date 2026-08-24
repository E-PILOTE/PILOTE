// ════════════════════════════════════════════════════════════════════════════
//  L'ÉCOLE CONSTATE UNE ARRIVÉE, ELLE NE LA DÉCIDE PAS
//
//  ── POURQUOI CE CHEMIN EXISTE ──────────────────────────────────────────────
//  Créer un compte exigeait `admin_groupe`. Mille écoles, une vingtaine
//  d'agents chacune : vingt mille comptes par un seul guichet, qui ne connaît
//  ni les noms ni les arrivées de septembre. Le déploiement par vagues ne passe
//  pas ce goulot. Le chef d'établissement, lui, sait qui travaille chez lui.
//
//  ── MAIS L'ÉCOLE NE CHOISIT PAS TOUT SON PERSONNEL ─────────────────────────
//  Un FONCTIONNAIRE n'est pas recruté par son lycée : il y est AFFECTÉ par une
//  note de l'autorité de tutelle. Un VOLONTAIRE, un bénévole ou un vacataire,
//  eux, sont engagés sur place — souvent payés par l'APE — et aucun arrêté ne
//  les concerne. Les deux populations cohabitent dans le même établissement.
//
//  D'où la règle, posée par les migrations 0091 puis 0092 : ce n'est pas le
//  SECTEUR qui commande, c'est le STATUT D'EMPLOI.
//
//    • à l'entrée : le statut est obligatoire ; il décide des motifs d'arrivée
//      possibles, et le motif décide si la référence de l'acte est exigée
//      (mutation, détachement, mise à disposition, intérim, réintégration →
//      oui ; recrutement → non, l'école est elle-même l'employeur) ;
//    • après : l'école CORRIGE une fiche (nom mal orthographié, téléphone,
//      matricule, photo). Elle ne mute pas, ne transfère pas, ne désactive pas
//      et ne change pas la fonction — la fonction EST l'affectation ;
//    • l'erreur de saisie s'ANNULE tant qu'elle n'a rien produit ; au-delà,
//      c'est un acte de l'autorité.
//
//  ⚠️ CES OPÉRATIONS SONT EN LIGNE, ET ELLES NE PEUVENT PAS ÊTRE AUTREMENT.
//  Un compte de connexion vit dans `auth.users`, hors de PowerSync. Et la RLS
//  `profiles_update` interdit à une direction d'écrire dans la fiche d'un autre
//  agent : un UPDATE passé par PowerSync serait rejeté par le serveur et
//  emporterait le LOT ENTIER, silencieusement. Ce sont les seuls gestes de
//  l'espace école dans ce cas — d'où le soin mis à le DIRE quand le réseau
//  manque, plutôt qu'à échouer sans explication.
//
//  ── LES GARDE-FOUS SONT CÔTÉ SERVEUR ───────────────────────────────────────
//  Rôle de l'appelant, fonctions attribuables, motifs recevables, obligation
//  d'acte, profil d'accès, quota : tout est vérifié par `creer_agent_ecole`,
//  `corriger_fiche_agent` et `annuler_enregistrement_agent` (migration 0091).
//  Ce fichier les rappelle à l'écran pour éviter un aller-retour inutile, il ne
//  les remplace pas — un garde-fou qui vit dans l'interface n'en est pas un.
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import 'staff_dossier_provider.dart' show kEmploymentStatuses;

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

/// Ce que dit le statut d'emploi, en une phrase, à celui qui remplit le
/// formulaire. Le libellé, lui, vient de [employmentStatusLabel] : une seule
/// source pour toute l'application.
const Map<String, String> kAideStatutEmploi = {
  'fonctionnaire':
      'Agent de l\'État, nommé par le ministère. Il arrive par acte.',
  'contractuel':
      'Sous contrat — de l\'État (il arrive par acte) ou de l\'établissement '
          '(vous l\'avez recruté).',
  'volontaire':
      'Engagé par l\'établissement, souvent rémunéré par l\'APE. Aucun arrêté.',
  'benevole': 'Prête son concours sans rémunération de l\'État.',
  'prestataire':
      'Vacataire ou prestataire payé à la tâche, par contrat avec l\'école.',
  'stagiaire': 'Accueilli par convention de stage.',
};

/// Quels motifs d'arrivée pour quel statut.
///
/// ⚠️ Tenu identique à `motifs_arrivee_pour_statut()` (migration 0092). La
/// table qui fait foi vient du SERVEUR (`contexte_creation_agent`) ; celle-ci
/// n'est qu'un repli si la question n'a pas pu être posée.
const Map<String, List<String>> kMotifsArriveeParStatut = {
  'fonctionnaire': [
    'mutation', 'detachement', 'mise_a_disposition', 'interim', 'reintegration',
  ],
  'contractuel': [
    'mutation', 'detachement', 'mise_a_disposition', 'interim', 'reintegration',
    'recrutement',
  ],
  'volontaire': ['recrutement'],
  'benevole': ['recrutement'],
  'prestataire': ['recrutement'],
  'stagiaire': ['recrutement'],
};

/// Motifs qui procèdent d'une décision écrite de l'autorité : sa référence est
/// alors exigée. ⚠️ Tenu identique à `motif_exige_un_acte()` (migration 0092).
const Set<String> kMotifsAvecActe = {
  'mutation', 'detachement', 'mise_a_disposition', 'interim', 'reintegration',
};

/// Les motifs d'arrivée qu'une ÉCOLE peut constater.
///
/// Ne sert qu'à mettre un libellé lisible et une explication sur une clé.
const Map<String, ({String label, String aide})> kMotifsArrivee = {
  'mutation': (
    label: 'Mutation',
    aide: 'L\'agent arrive d\'un autre établissement par note d\'affectation.',
  ),
  'detachement': (
    label: 'Détachement',
    aide: 'Mis à disposition par une autre administration, pour une durée fixée.',
  ),
  'mise_a_disposition': (
    label: 'Mise à disposition',
    aide: 'Affecté sans quitter son administration d\'origine.',
  ),
  'interim': (
    label: 'Intérim',
    aide: 'Remplace un agent absent, le temps de son absence.',
  ),
  'reintegration': (
    label: 'Réintégration',
    aide: 'Reprend son service après une interruption (disponibilité, congé long).',
  ),
  'recrutement': (
    label: 'Recrutement',
    aide: 'L\'établissement est lui-même l\'employeur : aucun acte extérieur.',
  ),
};

String motifArriveeLabel(String key) => kMotifsArrivee[key]?.label ?? key;

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
    this.statutsEmploi = const [],
    this.motifsParStatut = const {},
    this.motifsAvecActe = kMotifsAvecActe,
    this.secteurPublic = true,
    this.maxStaff,
    this.agentsActuels = 0,
    this.illimite = true,
    this.horsLigne = false,
  });

  factory ContexteCreationAgent.fromMap(Map<String, dynamic> m) =>
      ContexteCreationAgent(
        autorise: m['autorise'] as bool? ?? false,
        secteurPublic: m['secteur_public'] as bool? ?? true,
        statutsEmploi: [
          for (final v in (m['statuts_emploi'] as List? ?? const []))
            v as String,
        ],
        motifsParStatut: {
          for (final e in (m['motifs_par_statut'] as Map? ?? const {}).entries)
            '${e.key}': [for (final v in (e.value as List? ?? const [])) '$v'],
        },
        motifsAvecActe: {
          for (final v in (m['motifs_avec_acte'] as List? ?? const []))
            v as String,
        },
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

  /// Les statuts d'emploi, dans l'ordre où le secteur les rend probables :
  /// fonctionnaire d'abord dans un établissement public, contractuel dans un
  /// établissement privé.
  final List<String> statutsEmploi;

  /// Quels motifs d'arrivée pour quel statut — la table qui fait foi.
  final Map<String, List<String>> motifsParStatut;

  /// Motifs qui supposent un acte écrit, dont la référence est alors exigée.
  final Set<String> motifsAvecActe;

  /// Réseau public : on y attend surtout des agents de l'État.
  final bool secteurPublic;

  final int? maxStaff;
  final int agentsActuels;
  final bool illimite;

  /// La question n'a pas pu être posée. Distinct de « non autorisé » : on ne
  /// dit pas à un directeur qu'il n'a pas le droit alors qu'il est seulement
  /// hors réseau.
  final bool horsLigne;

  /// Les statuts à proposer — repli sur l'ordre canonique si le serveur n'a
  /// pas répondu.
  List<String> get statutsProposables => statutsEmploi.isNotEmpty
      ? statutsEmploi
      : [for (final e in kEmploymentStatuses) e.$1];

  /// Les motifs recevables pour ce statut. Un statut inconnu ne propose rien :
  /// mieux vaut un menu vide qu'un motif inventé, que le serveur refusera.
  List<String> motifsPour(String? statut) {
    if (statut == null) return const [];
    return motifsParStatut[statut] ?? kMotifsArriveeParStatut[statut] ?? const [];
  }

  /// Ce motif suppose-t-il un acte écrit ? En cas de silence du serveur on
  /// retombe sur la table Dart — jamais sur « non », qui laisserait naître une
  /// mutation sans référence.
  bool acteExige(String? motif) =>
      motif != null &&
      (motifsAvecActe.isEmpty ? kMotifsAvecActe : motifsAvecActe)
          .contains(motif);

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
    required String statutEmploi,
    required String motifArrivee,
    String? acteReference,
    DateTime? acteDate,
    DateTime? priseDeService,
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
        'p_employment_status': statutEmploi,
        'p_arrival_motif':     motifArrivee,
        'p_acte_reference':    _nz(acteReference),
        'p_acte_date':         _jour(acteDate),
        'p_start_date':        _jour(priseDeService),
        'p_phone':             _nz(telephone),
        'p_employee_number':   _nz(matricule),
        'p_gender':            _nz(genre),
        'p_date_of_birth':     _jour(dateNaissance),
        'p_birth_place':       _nz(lieuNaissance),
      });
      _ref.invalidate(contexteCreationAgentProvider);
      return id as String;
    } catch (e) {
      throw EchecCreationAgent(_lisible(e, "La création d'un compte d'agent"));
    }
  }

  /// Corrige une fiche — liste blanche côté serveur (migration 0091).
  ///
  /// Ni fonction, ni activation, ni établissement : ce sont des actes de
  /// l'autorité de tutelle, et il n'existe aucun paramètre pour les porter.
  Future<void> corriger({
    required String profileId,
    String? prenom,
    String? nom,
    String? telephone,
    String? matricule,
    String? genre,
    DateTime? dateNaissance,
    String? lieuNaissance,
    String? photoUrl,
    bool effacerPhoto = false,
  }) async {
    final client = _ref.read(supabaseClientProvider);
    try {
      await client.rpc('corriger_fiche_agent', params: {
        'p_profile_id':      profileId,
        'p_first_name':      _nz(prenom),
        'p_last_name':       _nz(nom),
        'p_phone':           _nz(telephone),
        'p_employee_number': _nz(matricule),
        'p_gender':          _nz(genre),
        'p_date_of_birth':   _jour(dateNaissance),
        'p_birth_place':     _nz(lieuNaissance),
        'p_avatar_url':      _nz(photoUrl),
        'p_effacer_photo':   effacerPhoto,
      });
    } catch (e) {
      throw EchecCreationAgent(_lisible(e, "La correction d'une fiche d'agent"));
    }
  }

  /// Renseigne un statut d'emploi ABSENT (migration 0093).
  ///
  /// Le serveur refuse d'écraser un statut déjà posé : requalifier un agent —
  /// passer un volontaire en fonctionnaire — est une titularisation, donc un
  /// acte de l'autorité de tutelle, pas une correction de fiche.
  Future<void> renseignerStatut({
    required String profileId,
    required String statutEmploi,
  }) async {
    final client = _ref.read(supabaseClientProvider);
    try {
      await client.rpc('renseigner_statut_agent', params: {
        'p_profile_id':        profileId,
        'p_employment_status': statutEmploi,
      });
    } catch (e) {
      throw EchecCreationAgent(_lisible(e, "L'enregistrement d'un statut d'emploi"));
    }
  }

  /// Annule un enregistrement qui n'a rien produit.
  ///
  /// Retourne la liste de ce qui BLOQUE si l'agent porte déjà du travail —
  /// vide si l'annulation a eu lieu. Un refus muet se contourne au hasard.
  Future<List<String>> annulerEnregistrement(String profileId) async {
    final client = _ref.read(supabaseClientProvider);
    try {
      final res = await client
          .rpc('annuler_enregistrement_agent', params: {'p_profile_id': profileId});
      if (res is Map && res['ok'] == false) {
        return [
          for (final b in (res['bloquants'] as List? ?? const [])) '$b',
        ];
      }
      _ref.invalidate(contexteCreationAgentProvider);
      return const [];
    } catch (e) {
      throw EchecCreationAgent(_lisible(e, "L'annulation d'un enregistrement d'agent"));
    }
  }

  static String? _nz(String? v) =>
      (v != null && v.trim().isNotEmpty) ? v.trim() : null;

  static String? _jour(DateTime? d) => d?.toIso8601String().substring(0, 10);

  /// Les messages du serveur sont déjà écrits pour être lus ; on retire
  /// seulement l'habillage PostgREST qui les rend illisibles.
  /// Le message d'échec, dit dans les termes du GESTE qui a échoué.
  ///
  /// ⚠️ [geste] n'est pas un ornement. Les quatre appels de ce fichier
  /// partagent ce traducteur, et il ne connaissait qu'une phrase : « la
  /// création d'un compte exige le réseau : un identifiant de connexion ne peut
  /// pas être créé hors ligne ». Un chef d'établissement qui corrigeait un
  /// numéro de téléphone sans connexion lisait donc qu'il ne pouvait pas créer
  /// de compte — alors qu'il n'en créait aucun. Le message décrivait le geste
  /// voisin, et envoyait chercher la panne au mauvais endroit.
  static String _lisible(Object e, String geste) {
    final s = e.toString();
    final m = RegExp(r'message:\s*([^,\)]+)').firstMatch(s);
    if (m != null) return m.group(1)!.trim();
    if (s.contains('SocketException') || s.contains('Failed host lookup')) {
      return 'Aucune connexion. $geste passe par le serveur : ce geste ne peut '
          'pas se faire hors ligne.';
    }
    return s;
  }
}

final agentCreationServiceProvider =
    Provider<AgentCreationService>((ref) => AgentCreationService(ref));
