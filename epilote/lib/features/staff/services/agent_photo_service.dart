// ════════════════════════════════════════════════════════════════════════════
//  LA PHOTO D'UN AGENT
//
//  ── ELLE NE S'ÉCRIT PAS, ELLE SE DEMANDE ───────────────────────────────────
//  `profiles_update` n'autorise que super_admin, admin_groupe du groupe, ou
//  l'agent lui-même. Un DIRECTEUR qui corrige la fiche d'un autre agent n'entre
//  dans aucune des trois : un UPDATE d'`avatar_url` poussé par PowerSync
//  reviendrait en `42501`, code fatal pour le connecteur, et emporterait le LOT
//  ENTIER — les notes et les paiements écrits dans la même fenêtre.
//
//  C'est pour cela que ce chemin est resté en ligne longtemps, derrière la RPC
//  `corriger_fiche_agent` (0091). Correct, mais il laissait un chef
//  d'établissement sans photo tant qu'il n'avait pas de réseau — dans un pays
//  où c'est l'état normal d'une partie des écoles.
//
//  La migration 0113 ouvre la seule porte qui ne relâche aucun droit : l'école
//  DÉPOSE UNE DEMANDE dans `staff_photo_requests`, table qui lui appartient et
//  qui se synchronise comme le reste ; le serveur l'applique par trigger, avec
//  l'autorité EXACTE de `corriger_fiche_agent`. Seul le moment change.
//
//  ── DEUX GESTES, ET C'EST VOULU ────────────────────────────────────────────
//   1. [preparerPhotoAgent] met les OCTETS en file et rend l'adresse publique
//      définitive. Aucun réseau : `getPublicUrl` est une concaténation.
//   2. `deposerDemandePhotoAgent` (staff_photo_provider) écrit la DEMANDE.
//
//  Les séparer permet de ne jamais promettre dans un dossier un fichier qui
//  n'aurait pas été mis en file.
//
//  ── L'ADRESSE EST VÉRIFIÉE CÔTÉ SERVEUR ────────────────────────────────────
//  `avatar_url` s'affiche sur tous les écrans qui montrent cet agent. Accepter
//  une adresse quelconque reviendrait à laisser poser un mouchard sur chacun
//  d'eux. Le trigger n'accepte qu'une URL de notre propre stockage — il refuse
//  sans lever, en inscrivant son motif dans la demande.
// ════════════════════════════════════════════════════════════════════════════

import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/powersync/avatar_upload.dart' show queueAvatarUpload;

/// Bucket public — une photo de profil s'affiche sans négocier d'URL signée à
/// chaque rendu de liste.
const kAvatarsBucket = 'avatars';

/// Extensions acceptées au choix du fichier.
const kAvatarExtensions = ['jpg', 'jpeg', 'png', 'webp'];

String avatarMime(String ext) => switch (ext.toLowerCase()) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };

class EchecPhotoAgent implements Exception {
  const EchecPhotoAgent(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Prépare la photo : la compresse, la met en file d'envoi, et rend l'adresse
/// publique DÉFINITIVE qu'elle portera.
///
/// N'écrit RIEN dans la fiche, et n'exige AUCUN réseau. Deux propriétés qui
/// tiennent ensemble : les octets partent par `upload_outbox`, et
/// `getPublicUrl` n'est qu'une concaténation, donc l'adresse se calcule avant
/// que le fichier n'existe. Au retour du réseau il monte à ce chemin exact.
///
/// C'est l'appelant qui décide ensuite d'en faire une DEMANDE
/// (`deposerDemandePhotoAgent`) — séparer les deux permet de ne jamais
/// promettre dans un dossier un fichier qui n'aurait pas été mis en file.
Future<String> preparerPhotoAgent({
  required SupabaseClient client,
  required String schoolId,
  required String profileId,
  required String fileName,
  required Uint8List bytes,
}) async {
  final rawExt = fileName.contains('.') ? fileName.split('.').last : 'jpg';
  if (!kAvatarExtensions.contains(rawExt.toLowerCase())) {
    throw const EchecPhotoAgent(
        'Format non accepté. Choisissez une image JPG, PNG ou WEBP.');
  }

  try {
    // 256 px de côté, et la compression a lieu AVANT la mise en file : hors
    // ligne ces octets dorment sur le disque du poste, parfois des jours.
    return await queueAvatarUpload(
      client: client,
      folder: 'staff/$schoolId',
      ownerId: profileId,
      bytes: bytes,
      ext: rawExt,
    );
  } catch (e) {
    // Il ne reste plus d'échec réseau à traduire ici : la mise en file n'en
    // produit pas. Ce qui peut encore échouer, c'est le DISQUE.
    throw EchecPhotoAgent('Photo impossible à préparer : $e');
  }
}
