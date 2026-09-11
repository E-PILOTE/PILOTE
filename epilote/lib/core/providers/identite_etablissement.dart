import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../../features/admin_groupe/providers/admin_settings_provider.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/structure/providers/academic_year_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  QUI EST « CHEZ SOI » DANS CETTE FENÊTRE.
//
//  L'application affichait son propre emblème à tout le monde, sur tous les
//  écrans. Un enseignant de Dolisie ouvrait donc sa journée sur la marque de
//  son fournisseur de logiciel, jamais sur celle de son école — alors que le
//  produit connaît le nom ET le logo de l'établissement depuis la synchro.
//
//  Cette règle existait déjà en trois exemplaires : la vitrine de l'écran-
//  verrou (logo de l'école), le tableau de bord du personnel (cascade école →
//  groupe → initiales) et l'émetteur des PDF (`pdf_issuer.dart`, groupe en
//  titre). Trois copies d'une même idée finissent par diverger : le jour où
//  une école change de logo, deux écrans sur trois le montrent. On la déclare
//  ici une fois, et la barre latérale la lit.
//
//  ── LA CASCADE, ET POURQUOI ELLE S'ARRÊTE AUX INITIALES ───────────────────
//  L'école est une émanation du groupe : sans logo propre, elle hérite du sien.
//  Sans logo du tout, on écrit ses initiales — jamais l'emblème d'E-PILOTE.
//  Reprendre notre marque comme repli ferait dire à l'écran « cette école est
//  E-PILOTE », ce qui est faux, et l'école n'aurait aucun moyen de comprendre
//  qu'il lui manque simplement un fichier à déposer.
//
//  ── LE SEUL CAS OÙ LA PLATEFORME GARDE LA VEDETTE ─────────────────────────
//  `super_admin` n'appartient à aucun établissement : il administre le produit.
//  C'est exactement la frontière que trace déjà `pdf_issuer.dart` en refusant
//  de lui poser un émetteur.
//
//  ── HORS LIGNE ────────────────────────────────────────────────────────────
//  `schools` et `school_groups` sont synchronisées : le NOM est donc toujours
//  là, même sans réseau. Le logo n'est qu'une URL — les octets arrivent au
//  premier affichage en ligne, puis `CachedNetworkImage` les garde. Avant cela,
//  et sur une école sans logo, les initiales tiennent la place. C'est pourquoi
//  le nom ne dépend jamais du chargement de l'image.
// ════════════════════════════════════════════════════════════════════════════

/// L'établissement auquel appartient la personne connectée, tel qu'on l'affiche.
class IdentiteEtablissement {
  const IdentiteEtablissement({
    required this.nom,
    this.sousTitre,
    this.logoUrl,
    this.estLaPlateforme = false,
  });

  /// Ce qui prend le titre : l'école pour le personnel, le groupe pour son
  /// administrateur. Ce que la personne appellerait « chez moi ».
  final String nom;

  /// La ligne de dessous. La marque du produit dans tous les cas sauf le sien.
  final String? sousTitre;

  /// Emblème à afficher, `null` ⇒ initiales de [nom].
  final String? logoUrl;

  /// Aucun établissement : on est dans l'espace qui administre le produit.
  final bool estLaPlateforme;

  /// L'identité par défaut — celle du logiciel lui-même.
  static const plateforme = IdentiteEtablissement(
    nom: 'E-PILOTE CONGO',
    sousTitre: 'Gestion scolaire',
    estLaPlateforme: true,
  );
}

/// Vrai si cette URL a une chance d'être affichable.
///
/// Le contrôle du préfixe n'est pas de la coquetterie : `logo_url` a longtemps
/// reçu des chemins de Storage relatifs, que `CachedNetworkImage` transforme en
/// exception au lieu d'un repli propre. Publique parce que c'est une RÈGLE,
/// vérifiable seule : une adresse inutilisable doit conduire aux initiales, pas
/// à un emblème cassé au-dessus de toute la navigation.
bool logoAffichable(String? u) =>
    u != null && u.trim().isNotEmpty && u.trim().startsWith('http');

/// Mots qui ne distinguent pas un établissement d'un autre.
///
/// « Groupe Scolaire EDEC » et « Groupe Scolaire Bethel » commencent par les
/// deux mêmes mots : des initiales naïves donneraient « GS » aux deux, et la
/// pastille cesserait de dire quoi que ce soit. Ces mots-là sautent.
const Set<String> _motsGeneriques = {
  'groupe', 'scolaire', 'scolaires', 'reseau', 'réseau', 'institut',
  'complexe', 'ecole', 'école', 'lycee', 'lycée', 'college', 'collège',
  'ceg', 'cet', 'centre', 'etablissement', 'établissement',
  'de', 'du', 'des', 'la', 'le', 'les', 'et', 'and',
};

final _debutDeMot = RegExp(r'^\p{L}', unicode: true);

/// Initiales d'un ÉTABLISSEMENT — le repli quand aucun logo n'est disponible.
///
/// Volontairement distinct de `avatarInitials`, qui sert aux PERSONNES : « Jean
/// Mabiala » doit donner « JM », donc sans liste de mots à ignorer. Appliquer
/// l'une des deux règles à l'autre population dégrade forcément un des deux cas.
String initialesEtablissement(String? nom) {
  final mots = [
    for (final m in (nom ?? '').split(RegExp(r"[\s\-’']+")))
      if (m.isNotEmpty && _debutDeMot.hasMatch(m)) m,
  ];
  if (mots.isEmpty) return '?';

  // Si TOUT est générique (« Groupe Scolaire »), on garde les mots d'origine :
  // mieux vaut « GS » que rien du tout.
  final forts = [
    for (final m in mots)
      if (!_motsGeneriques.contains(m.toLowerCase())) m,
  ];
  final retenus = forts.isEmpty ? mots : forts;

  if (retenus.length >= 2) {
    return '${retenus[0][0]}${retenus[1][0]}'.toUpperCase();
  }
  final seul = retenus.first;
  return seul.substring(0, seul.length > 1 ? 2 : 1).toUpperCase();
}

String? _nettoie(Object? v) {
  final s = (v as String?)?.trim() ?? '';
  return s.isEmpty ? null : s;
}

/// Décision pure : quelle identité afficher, à partir de ce que l'on sait.
///
/// Toute la règle tient ici, sans Riverpod ni base de données — c'est ce qui la
/// rend vérifiable branche par branche, y compris les cas qu'on ne sait pas
/// reproduire à la main : le groupe pas encore chargé, l'école sans nom, le
/// `logo_url` qui contient un chemin de Storage au lieu d'une adresse.
///
/// [groupeAdministre] ne concerne que `admin_groupe` (lu en ligne) ; [ecole] et
/// [groupeDeLEcole] sont les lignes SQLite du personnel.
IdentiteEtablissement identiteEtablissementDe({
  required String? role,
  ({String? nom, String? logoUrl})? groupeAdministre,
  Map<String, dynamic>? ecole,
  Map<String, dynamic>? groupeDeLEcole,
}) {
  if (role == null || role == AppConstants.roleSuperAdmin) {
    return IdentiteEtablissement.plateforme;
  }

  if (role == AppConstants.roleAdminGroupe) {
    final nom = _nettoie(groupeAdministre?.nom);
    // « — » est le remplissage que renvoie le provider du groupe quand il n'a
    // rien pu lire : l'afficher en titre donnerait une barre latérale intitulée
    // « — » sur toute la largeur.
    if (nom == null || nom == '—') return IdentiteEtablissement.plateforme;
    return IdentiteEtablissement(
      nom: nom,
      sousTitre: IdentiteEtablissement.plateforme.nom,
      logoUrl: _siAffichable(groupeAdministre?.logoUrl),
    );
  }

  // Personnel scolaire et familles : tout vient de SQLite, donc hors ligne.
  final titre = _nettoie(ecole?['name']) ?? _nettoie(groupeDeLEcole?['name']);
  if (titre == null) return IdentiteEtablissement.plateforme;

  return IdentiteEtablissement(
    nom: titre,
    sousTitre: IdentiteEtablissement.plateforme.nom,
    logoUrl: _siAffichable(ecole?['logo_url']) ??
        _siAffichable(groupeDeLEcole?['logo_url']),
  );
}

String? _siAffichable(Object? v) {
  final u = _nettoie(v);
  return logoAffichable(u) ? u : null;
}

/// L'identité affichée dans la barre latérale (et partout où l'on doit dire au
/// nom de qui l'écran travaille). Ne fait que brancher [identiteEtablissementDe]
/// sur les deux chemins de données du projet.
final identiteEtablissementProvider = Provider<IdentiteEtablissement>((ref) {
  final role = ref.watch(authNotifierProvider).valueOrNull?.role;

  // Sortie immédiate : inutile de s'abonner à la base locale pour quelqu'un
  // qui n'a pas d'établissement — et `super_admin` n'en a pas.
  if (role == null || role == AppConstants.roleSuperAdmin) {
    return IdentiteEtablissement.plateforme;
  }

  // ⚠️ admin_groupe ne connecte JAMAIS PowerSync : sa base locale est vide et
  // son profil n'a pas de `school_id`. Son groupe se lit en ligne, par le
  // provider que son espace charge déjà (gardé en vie) — pas d'appel de plus.
  if (role == AppConstants.roleAdminGroupe) {
    final g = ref.watch(adminGroupProfileProvider).valueOrNull;
    return identiteEtablissementDe(
      role: role,
      groupeAdministre: (nom: g?.name, logoUrl: g?.logoUrl),
    );
  }

  return identiteEtablissementDe(
    role: role,
    ecole: ref.watch(currentSchoolProvider).valueOrNull,
    groupeDeLEcole: ref.watch(currentGroupProvider).valueOrNull,
  );
});
