import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CE QUE LE POSTE SAIT DE LUI-MÊME QUAND LE SERVEUR L'A OUBLIÉ
//
//  ── LE JOUR OÙ ÇA ARRIVE ───────────────────────────────────────────────────
//  Constaté le 2026-08-04 sur le poste de recette : la session Supabase est
//  morte (jeton de rafraîchissement perdu), Supabase a émis `signedOut` tout
//  seul, et l'application est retombée sur l'écran e-mail + mot de passe.
//
//  Dans une école congolaise, cet écran est un mur. Les agents ne connaissent
//  que leur code à quatre chiffres ; le mot de passe du compte de
//  l'établissement a été saisi une fois, le jour de l'installation, par
//  quelqu'un qui n'est peut-être plus là. La base locale, elle, est intacte
//  juste derrière : neuf mille élèves, leurs notes, les paiements du trimestre.
//  L'établissement est enfermé dehors, devant ses propres données.
//
//  ── LES TROIS PORTES, DANS CET ORDRE ───────────────────────────────────────
//   0. REPRISE SILENCIEUSE — on garde une copie du jeton de rafraîchissement
//      dans le coffre de l'appareil. Au démarrage sans session, on le rejoue :
//      si le serveur l'accepte encore (cas le plus fréquent — stockage gotrue
//      corrompu, rotation perdue en cours de route), personne ne voit rien.
//   1. REPRISE HORS LIGNE — sinon, le poste se souvient de QUI il est et de
//      QUELLE école il porte. Un agent enrôlé rouvre le travail avec son PIN
//      et continue ; les écritures s'empilent dans `ps_crud` et partiront à la
//      prochaine connexion.
//   2. RECONNEXION ASSISTÉE — la porte du mot de passe reste ouverte, mais
//      avec l'adresse déjà remplie et la marche à suivre écrite à l'écran.
//
//  ── CE QUI N'EST PAS UN RISQUE ─────────────────────────────────────────────
//  Laisser un poste travailler hors ligne ne donne accès à rien de neuf : les
//  données SONT DÉJÀ sur la machine, lisibles dans le fichier SQLite sans
//  aucune application. La vraie frontière reste la RLS côté serveur, qu'aucune
//  écriture ne franchit sans jeton valide. Ce que ce fichier restaure, c'est le
//  comportement qui a TOUJOURS été voulu — une école travaille hors ligne des
//  semaines — que la disparition d'un objet `Session` avait cassé par accident.
//
//  ⚠️ Le jeton miroir vit dans `flutter_secure_storage`, pas dans PowerSync :
//  il doit survivre à `powersync_clear()`. Ce n'est pas un affaiblissement —
//  gotrue persiste déjà la session complète dans SharedPreferences, en clair.
// ════════════════════════════════════════════════════════════════════════════

/// Ce que le poste retient d'une session valide, pour se reconnaître plus tard.
/// Aucun secret ici : le jeton, lui, part au coffre.
class IdentitePoste {
  const IdentitePoste({
    required this.userId,
    required this.email,
    required this.vueLe,
    this.role,
    this.schoolId,
    this.groupId,
  });

  /// Compte qui a authentifié l'appareil (la direction, en général).
  final String userId;
  final String email;

  /// Dernier instant où une session serveur a été constatée valide. Sert à dire
  /// « ce poste travaille hors ligne depuis onze jours », pas à bloquer.
  final DateTime vueLe;

  final String? role;
  final String? schoolId;
  final String? groupId;

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'email': email,
        'vue_le': vueLe.toUtc().toIso8601String(),
        if (role != null) 'role': role,
        if (schoolId != null) 'school_id': schoolId,
        if (groupId != null) 'group_id': groupId,
      };

  static IdentitePoste? fromJson(Map<String, dynamic> m) {
    final id = m['user_id'] as String?;
    final mail = m['email'] as String?;
    if (id == null || id.isEmpty || mail == null) return null;
    return IdentitePoste(
      userId: id,
      email: mail,
      vueLe: DateTime.tryParse(m['vue_le'] as String? ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      role: m['role'] as String?,
      schoolId: m['school_id'] as String?,
      groupId: m['group_id'] as String?,
    );
  }

  /// Depuis combien de jours ce poste n'a plus vu le serveur.
  int joursDepuisLaDerniereSession(DateTime maintenant) =>
      maintenant.toUtc().difference(vueLe).inDays;
}

/// Ce que l'application doit faire quand elle démarre sans session serveur.
enum PorteDeReprise {
  /// Une session valide existe : rien à faire.
  aucune,

  /// Le poste se reconnaît ET ses données sont là → écran « Reprise du poste ».
  reprisePossible,

  /// Appareil neuf, ou base vidée : l'écran de connexion habituel est la
  /// bonne réponse — il n'y a rien à reprendre.
  connexionHabituelle,
}

/// Décision pure : quelle porte ouvrir au démarrage. Testable, sans effet.
///
/// Les deux conditions de la reprise sont cumulatives et c'est délibéré :
/// se souvenir d'une école sans avoir ses données ouvrirait une application
/// vide — pire qu'un écran de connexion, parce qu'elle aurait l'air cassée.
PorteDeReprise porteDeReprise({
  required bool sessionOuverte,
  required bool posteConnu,
  required bool donneesLocalesPresentes,
}) {
  if (sessionOuverte) return PorteDeReprise.aucune;
  if (posteConnu && donneesLocalesPresentes) {
    return PorteDeReprise.reprisePossible;
  }
  return PorteDeReprise.connexionHabituelle;
}

/// Faut-il exiger un code PIN pour rouvrir le travail hors ligne ?
///
/// Oui dès qu'un agent a enrôlé un code sur ce poste : c'est la seule preuve
/// vérifiable sans serveur, et elle existe.
///
/// Non si PERSONNE n'en a jamais posé — cas du poste personnel d'un directeur,
/// où le verrou d'agent ne s'affiche pas. Exiger alors un code qui n'existe pas
/// enfermerait dehors, avec certitude, l'établissement qu'on prétend protéger,
/// pour un gain de sécurité nul : qui tient la machine tient déjà le fichier
/// SQLite, application ou pas.
bool exigePinPourReprise(int agentsEnroles) => agentsEnroles > 0;

/// Garde la mémoire du poste : identité en clair, jeton au coffre.
class SessionKeeper {
  SessionKeeper({FlutterSecureStorage? coffre})
      : _coffre = coffre ?? const FlutterSecureStorage();

  static const _kIdentite = 'epilote.identite_poste';
  static const _kJeton = 'epilote_refresh_token_v1';

  final FlutterSecureStorage _coffre;

  /// À appeler à chaque session valide constatée (connexion, renouvellement).
  ///
  /// ⚠️ Les champs absents ne SUPPRIMENT rien. Un renouvellement de jeton
  /// survient souvent avant que le profil ne soit chargé : écraser alors le
  /// rôle et l'école par des `null` viderait la mémoire du poste au fil des
  /// heures, et il n'en resterait rien le jour où l'on en a besoin.
  Future<void> memoriser(Session session, {String? role, String? schoolId,
      String? groupId}) async {
    final u = session.user;
    final ancienne = await identite();
    final memePoste = ancienne?.userId == u.id;
    final identiteMaj = IdentitePoste(
      userId: u.id,
      email: u.email ?? (memePoste ? ancienne!.email : ''),
      vueLe: DateTime.now().toUtc(),
      role: role ?? (memePoste ? ancienne!.role : null),
      schoolId: schoolId ?? (memePoste ? ancienne!.schoolId : null),
      groupId: groupId ?? (memePoste ? ancienne!.groupId : null),
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kIdentite, json.encode(identiteMaj.toJson()));
    } catch (_) {/* fail-soft : la mémoire du poste est un confort, pas un dû */}
    try {
      final jeton = session.refreshToken;
      if (jeton != null && jeton.isNotEmpty) {
        await _coffre.write(key: _kJeton, value: jeton);
      }
    } catch (_) {/* coffre indisponible (libsecret absent) → tant pis */}
  }

  Future<IdentitePoste?> identite() async {
    try {
      final raw =
          (await SharedPreferences.getInstance()).getString(_kIdentite);
      if (raw == null) return null;
      return IdentitePoste.fromJson(
          Map<String, dynamic>.from(json.decode(raw) as Map));
    } catch (_) {
      return null;
    }
  }

  /// Rejoue le jeton miroir. Rend `true` si une session est revenue.
  ///
  /// ⚠️ Borné dans le temps : cet appel est fait au démarrage, et une école à
  /// mauvaise liaison ne doit pas rester devant un écran figé parce qu'un
  /// serveur ne répond pas. Échouer ici n'est jamais grave — il reste deux
  /// portes derrière.
  Future<bool> tenterRepriseSilencieuse(
    SupabaseClient client, {
    Duration limite = const Duration(seconds: 8),
  }) async {
    try {
      if (client.auth.currentSession != null) return true;
      final jeton = await _coffre.read(key: _kJeton);
      if (jeton == null || jeton.isEmpty) return false;
      final res = await client.auth.setSession(jeton).timeout(limite);
      return res.session != null;
    } catch (_) {
      return false;
    }
  }

  /// Efface la mémoire du poste. UNIQUEMENT sur une déconnexion VOLONTAIRE :
  /// c'est le seul moment où quelqu'un a dit « ce poste n'est plus le nôtre ».
  /// Une session qui expire ne doit rien effacer — c'est toute la leçon du
  /// 2026-08-04.
  Future<void> oublier() async {
    try {
      await (await SharedPreferences.getInstance()).remove(_kIdentite);
    } catch (_) {/* fail-soft */}
    try {
      await _coffre.delete(key: _kJeton);
    } catch (_) {/* fail-soft */}
  }
}

/// Instance partagée — pas de Riverpod ici : `AuthNotifier` s'en sert pendant
/// son initialisation, avant que le conteneur ne soit prêt à être lu.
final sessionKeeper = SessionKeeper();
