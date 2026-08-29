// ══════════════════════════════════════════════════════════════════════════════
//  LES OCTETS D'UNE PHOTO, POUR UN DOCUMENT — hors ligne d'abord
//
//  À l'écran, une photo s'affiche par une URL : `CachedNetworkImage` s'occupe
//  du reste. Un PDF ne peut pas faire ça — il lui faut les OCTETS, tout de
//  suite, et le poste qui imprime les cartes de la rentrée est souvent celui
//  qui n'a pas de réseau ce jour-là.
//
//  ── TROIS SOURCES, DANS CET ORDRE ──────────────────────────────────────────
//   1. LA FILE D'ENVOI — la photo vient d'être prise sur ce poste et n'est pas
//      encore montée. Les octets sont sur le disque ; l'URL, elle, pointe déjà
//      sur un objet qui n'existe pas (cf. `avatar_upload.dart`). Sauter cette
//      étape ferait imprimer « photo manquante » à l'agent qui vient tout juste
//      de la prendre — le plus déroutant des messages.
//   2. LE CACHE DISQUE — la photo a été AFFICHÉE sur ce poste (registre,
//      annuaire, fiche élève), donc `flutter_cache_manager` la garde. C'est ce
//      qui rend l'impression possible sans réseau : le secrétariat a consulté
//      ses listes toute la semaine, les visages sont déjà là.
//   3. LE RÉSEAU — dernier recours, et seulement s'il est là.
//
//  ── ET SI RIEN NE RÉPOND ───────────────────────────────────────────────────
//  On rend `null`, jamais une image de remplacement. Un document officiel ne
//  doit pas inventer un visage : c'est à l'écran d'annoncer combien de cartes
//  partiront sans photo, et à l'utilisateur de décider s'il imprime quand même.
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../../services/powersync/avatar_upload.dart';

/// Octets de la photo désignée par [url], ou `null` si elle est introuvable
/// sur ce poste et hors de portée du réseau.
///
/// [enAttente] est la file d'envoi, LUE UNE FOIS par l'appelant
/// (`pendingUploadPathsProvider`) et passée telle quelle. Même raison que pour
/// [PhotoAvatar] : l'interroger par élève ferait quarante lectures là où la
/// file entière tient en mémoire — et le plus souvent elle est vide.
///
/// Ne dépend d'aucun `Ref` : la fonction est appelée aussi bien depuis un
/// provider que depuis un widget, et se teste avec une simple carte.
///
/// [reseau] permet de couper la troisième source — utile quand on sait déjà
/// qu'on est hors ligne et qu'on ne veut pas payer une attente par élève.
Future<Uint8List?> octetsPhoto(
  String? url, {
  Map<String, String>? enAttente,
  bool reseau = true,
  BaseCacheManager? cache,
}) async {
  if (url == null || url.trim().isEmpty) return null;

  // 1. En file d'envoi sur ce poste.
  final chemin = storagePathFromPublicUrl(url);
  if (chemin != null && enAttente != null) {
    final local = enAttente[chemin];
    if (local != null && local.isNotEmpty) {
      final f = File(local);
      if (f.existsSync()) return f.readAsBytes();
    }
  }

  final gestionnaire = cache ?? DefaultCacheManager();

  // 2. Déjà téléchargée pour l'affichage — aucun accès réseau.
  try {
    final info = await gestionnaire.getFileFromCache(url);
    if (info != null && await info.file.exists()) {
      return info.file.readAsBytes();
    }
  } catch (_) {
    // Un cache illisible n'est pas une raison de renoncer au réseau.
  }

  if (!reseau) return null;

  // 3. Réseau. Hors ligne, `getSingleFile` lève : c'est le cas NORMAL ici, pas
  // une anomalie à remonter.
  try {
    final f = await gestionnaire.getSingleFile(url);
    if (await f.exists()) return f.readAsBytes();
  } catch (_) {
    return null;
  }
  return null;
}
