// ════════════════════════════════════════════════════════════════════════════
//  LA PHOTO D'UN AGENT
//
//  ── POURQUOI CE CHEMIN EST EN LIGNE, CONTRAIREMENT AU RESTE DE L'ÉCOLE ─────
//  Tout l'espace école écrit hors ligne, par PowerSync. Pas ceci, pour deux
//  raisons qui se cumulent :
//
//   1. la RLS `profiles_update` n'autorise que super_admin, admin_groupe du
//      groupe, ou l'agent lui-même. Une direction qui pousserait un UPDATE de
//      `avatar_url` par PowerSync le verrait REFUSÉ par le serveur — et un
//      refus abandonne le LOT ENTIER, emportant au passage les notes et les
//      paiements écrits dans la même fenêtre. C'est la panne qui a déjà coûté
//      cher à ce projet ;
//   2. les octets doivent de toute façon atteindre le stockage.
//
//  On passe donc par `corriger_fiche_agent` (migration 0091), qui est la porte
//  étroite et nommée. Hors réseau, on le DIT.
//
//  ── POURQUOI LA FILE D'ENVOI NE RÈGLE PAS CE CAS ───────────────────────────
//  `queueAvatarUpload` (`services/powersync/avatar_upload.dart`) rend la photo
//  d'ÉLÈVE déposable hors ligne, et porte même un paramètre `folder` qui
//  servirait `staff/` sans une ligne de plus. La tentation est donc réelle —
//  d'où cette note, pour qu'on ne refasse pas le raisonnement à l'envers.
//
//  Mettre les octets en file ne débloquerait RIEN. Ce qui manque hors ligne,
//  ce n'est pas le fichier : c'est l'écriture de `avatar_url`, qui ne peut
//  passer que par la RPC ci-dessus (raison 1). On aurait une photo sur le
//  disque, aucune fiche modifiée, et l'occasion d'inscrire dans un dossier
//  l'adresse d'un fichier pas encore arrivé — exactement ce que la séparation
//  octets/fiche interdit plus bas.
//
//  Le rendre vraiment hors ligne demanderait un autre chemin d'écriture pour
//  `profiles` — une table tampon synchronisée, appliquée côté serveur par
//  trigger. C'est un chantier, pas un branchement.
//
//  ── L'ADRESSE EST VÉRIFIÉE CÔTÉ SERVEUR ────────────────────────────────────
//  `avatar_url` s'affiche sur tous les écrans qui montrent cet agent. Accepter
//  une adresse quelconque reviendrait à laisser poser un mouchard sur chacun
//  d'eux. La fonction serveur n'accepte qu'une URL de notre propre stockage ;
//  ce fichier ne fabrique donc jamais d'autre forme.
// ════════════════════════════════════════════════════════════════════════════

import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/media_compression.dart';

const _uuid = Uuid();

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

/// Envoie la photo au stockage et renvoie son adresse publique.
///
/// N'écrit RIEN dans la fiche : c'est l'appelant qui passe l'adresse à
/// `corriger_fiche_agent`. Séparer les deux permet de ne jamais promettre dans
/// la fiche un fichier qui ne serait pas arrivé.
Future<String> televerserPhotoAgent({
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

  // 256 px de côté : la photo n'est jamais rendue plus grande, et un poste
  // d'école partage souvent une connexion étroite entre vingt agents.
  final media = await compressAvatar(
    bytes: bytes,
    fileName: fileName,
    mime: avatarMime(rawExt),
  );
  final ext =
      media.fileName.contains('.') ? media.fileName.split('.').last : rawExt;

  // L'UUID rend le chemin unique : remplacer une photo n'écrase pas l'ancienne
  // pendant qu'un autre poste l'affiche encore depuis son cache.
  final chemin = 'staff/$schoolId/${profileId}_${_uuid.v4().substring(0, 8)}.$ext';

  try {
    await client.storage.from(kAvatarsBucket).uploadBinary(
          chemin,
          media.bytes,
          fileOptions: FileOptions(contentType: avatarMime(ext), upsert: true),
        );
  } catch (e) {
    final s = e.toString();
    if (s.contains('SocketException') || s.contains('Failed host lookup')) {
      // ⚠️ CE MESSAGE NE PARLE PAS QUE DE LA PHOTO, et c'est délibéré.
      // Il disait « une photo doit atteindre le serveur […] : elle ne peut pas
      // être ajoutée hors ligne » — vrai, mais trompeur par omission : il
      // désignait la photo comme l'exception d'un écran qui, sans réseau, ne
      // sait RIEN enregistrer. `corriger_fiche_agent` est une RPC.
      //
      // L'agent renonçait donc à la photo, remplissait le reste, appuyait sur
      // « Enregistrer » — et se heurtait à un second échec, formulé autrement.
      // Autant le dire une fois, complètement.
      throw const EchecPhotoAgent(
          'Aucune connexion. La fiche d\'un agent se corrige sur le serveur — '
          'ni la photo ni le reste ne peuvent être enregistrés hors ligne. '
          'Reprenez cette fiche une fois connecté.');
    }
    throw EchecPhotoAgent('Envoi impossible : $e');
  }

  return client.storage.from(kAvatarsBucket).getPublicUrl(chemin);
}
