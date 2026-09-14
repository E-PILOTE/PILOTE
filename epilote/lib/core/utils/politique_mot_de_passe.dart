import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/admin_groupe/providers/admin_settings_provider.dart';
import '../../features/auth/providers/auth_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LA POLITIQUE DE MOT DE PASSE — enfin appliquée
//
//  ── CE QUI A ÉTÉ TROUVÉ (2026-09-05) ──────────────────────────────────────
//  L'onglet « Sécurité » des paramètres du groupe proposait SIX réglages :
//  longueur minimale, mot de passe robuste, double authentification, sessions
//  multiples, expiration de session, verrouillage après échecs. Les six
//  partaient bien dans `group_settings.security` — et AUCUN code Dart, AUCUNE
//  fonction en base ne les lisait. Vérifié des deux côtés.
//
//  C'est exactement le défaut que ce même écran dénonce quatre lignes plus bas
//  pour la conservation des données : « une case qui ne fait rien est pire
//  qu'une case absente : elle fait prendre une décision qui n'aura pas lieu ».
//  Pendant ce temps, les trois endroits qui posent un mot de passe exigeaient
//  six caractères, en dur, sans jamais regarder le réglage du groupe.
//
//  ── CE QUI EST DEVENU VRAI, ET CE QUI NE POUVAIT PAS L'ÊTRE ───────────────
//  Les deux règles de mot de passe s'appliquent désormais partout où un mot de
//  passe se saisit. Les quatre autres ne pouvaient pas être tenues sans mentir
//  — la double authentification n'existe nulle part dans le produit, et
//  l'expiration de session comme le verrouillage de compte se décident côté
//  serveur, pas dans une case à cocher d'application. Elles ont été retirées
//  de l'écran, qui dit maintenant ce que la plateforme protège RÉELLEMENT.
//
//  ── ⚠️ CE QUE CETTE RÈGLE N'EST PAS ───────────────────────────────────────
//  C'est une règle d'APPLICATION, pas une garantie de serveur. Elle couvre les
//  trois portes du produit (création d'un compte, réinitialisation par
//  l'administrateur, changement par l'intéressé) ; un appel direct à l'API
//  Supabase passerait outre. Le jour où cela compte vraiment, la même règle
//  devra vivre dans `create_school_user` et `set_school_user_password`.
// ════════════════════════════════════════════════════════════════════════════

class PolitiqueMotDePasse {
  const PolitiqueMotDePasse({
    required this.longueurMinimale,
    required this.exigeRobuste,
  });

  /// Ce qui s'applique quand le groupe n'a rien réglé — ou quand on ne peut pas
  /// le lire : le personnel scolaire travaille hors ligne et `group_settings`
  /// n'est pas synchronisé sur son poste. Un défaut PLUS strict que l'ancien
  /// « six caractères » codé en dur.
  static const parDefaut =
      PolitiqueMotDePasse(longueurMinimale: 8, exigeRobuste: true);

  final int longueurMinimale;
  final bool exigeRobuste;

  /// Ce qu'on demande, en une phrase, à afficher SOUS le champ.
  ///
  /// L'exigence s'annonce avant la faute : découvrir la règle en se faisant
  /// refuser trois fois est une façon de la faire contourner par le plus
  /// simple des mots de passe qui passe.
  String get exigence => exigeRobuste
      ? 'Au moins $longueurMinimale caractères, dont une majuscule, un chiffre '
          'et un caractère spécial.'
      : 'Au moins $longueurMinimale caractères.';

  /// `null` quand le mot de passe convient ; sinon le motif du refus, dit en
  /// clair — jamais « mot de passe invalide », qui n'apprend rien.
  String? refus(String? motDePasse) {
    final m = motDePasse ?? '';
    if (m.isEmpty) return 'Mot de passe requis';
    if (m.length < longueurMinimale) {
      return 'Au moins $longueurMinimale caractères';
    }
    if (!exigeRobuste) return null;

    final manque = <String>[
      if (!m.contains(RegExp(r'[A-ZÀ-ÖØ-Þ]'))) 'une majuscule',
      if (!m.contains(RegExp(r'[0-9]'))) 'un chiffre',
      // Tout ce qui n'est ni lettre ni chiffre ni espace : la liste explicite
      // aurait oublié la moitié des claviers.
      if (!m.contains(RegExp(r'[^A-Za-zÀ-ÿ0-9\s]'))) 'un caractère spécial',
    ];
    if (manque.isEmpty) return null;
    return 'Il manque ${manque.join(', ')}';
  }
}

/// La politique du groupe de la personne connectée, ou [PolitiqueMotDePasse.parDefaut].
///
/// ⚠️ Ne lit les réglages que pour `admin_groupe` : c'est le seul espace qui
/// travaille en ligne ET possède un groupe. Le `super_admin` n'appartient à
/// aucun groupe ; le personnel scolaire n'a pas `group_settings` sur son poste.
/// Dans les deux cas, le défaut s'applique — et il est plus strict que ce qui
/// existait avant.
final politiqueMotDePasseProvider = Provider<PolitiqueMotDePasse>((ref) {
  final role = ref.watch(authNotifierProvider).valueOrNull?.role;
  if (role != 'admin_groupe') return PolitiqueMotDePasse.parDefaut;

  final reglages = ref.watch(adminGroupSettingsProvider).valueOrNull;
  final s = reglages?.security;
  if (s == null) return PolitiqueMotDePasse.parDefaut;

  return PolitiqueMotDePasse(
    longueurMinimale: s.minPasswordLength,
    exigeRobuste: s.requireStrongPassword,
  );
});
