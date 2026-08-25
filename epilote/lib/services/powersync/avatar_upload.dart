import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/media_compression.dart';
import 'upload_outbox.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LA PHOTO D'UNE PERSONNE — offline-first, comme les pièces du dossier.
//
//  ── CE QUI NE MARCHAIT PAS ─────────────────────────────────────────────────
//  La photo partait vers Supabase Storage en DIRECT. Sans réseau, l'écran
//  répondait « la photo n'a pas pu être envoyée, reprenez-la plus tard » — et
//  la reprise, dans une école congolaise, veut souvent dire jamais. Le reste
//  de la fiche s'enregistrait pourtant très bien hors ligne : seule la photo
//  exigeait le réseau.
//
//  ── POURQUOI C'EST SÉPARÉ DES PIÈCES DU DOSSIER ────────────────────────────
//  `student_document_upload.dart` sert le bucket PRIVÉ `student-documents` :
//  il écrit une LIGNE (`student_documents`) dont `file_url` porte le CHEMIN, et
//  la lecture passe par une URL signée.
//
//  Ici le bucket est PUBLIC (`avatars`) et il n'y a pas de ligne à écrire : la
//  photo est une COLONNE (`students.photo_url`, `profiles.avatar_url`) qui
//  porte une URL publique complète. Deux formes de stockage, deux chemins.
//
//  ── CE QUI REND L'OFFLINE POSSIBLE ─────────────────────────────────────────
//  `getPublicUrl` ne touche pas le réseau : c'est une concaténation
//  (`{base}/storage/v1/object/public/{bucket}/{chemin}`). L'URL définitive se
//  calcule donc AVANT que le fichier n'existe. On l'écrit tout de suite dans la
//  colonne, les octets partent en file, et au retour du réseau le fichier monte
//  à ce chemin exact : l'URL déjà synchronisée devient valide d'elle-même, sans
//  qu'aucune ligne n'ait à être corrigée.
//
//  Entre-temps, l'URL pointe sur un objet qui n'existe pas encore. C'est à quoi
//  sert [storagePathFromPublicUrl] : elle rend le chemin que la file d'envoi
//  indexe, et `fichierLocalEnAttente` (core/widgets/photo_avatar.dart) montre
//  alors la photo depuis le disque, sur le poste qui vient de la prendre.
// ════════════════════════════════════════════════════════════════════════════

const _uuid = Uuid();
const kAvatarsBucket = 'avatars';

/// Met une photo en file et rend son URL publique DÉFINITIVE.
///
/// [folder] est le dossier logique du bucket (`students`, `staff`, `admins`).
/// [ownerId] rend le chemin lisible ; l'UUID le rend unique — remplacer une
/// photo n'écrase pas l'ancienne pendant qu'un autre poste l'affiche encore
/// depuis son cache.
///
/// La compression a lieu AVANT la mise en file : hors ligne, ces octets dorment
/// sur le disque du poste, parfois des jours. Une photo sortie d'un téléphone
/// pèse 4 à 8 Mo pour une pastille de 38 pixels dans l'annuaire ; sur une école
/// qui inscrit six cents élèves, c'est plusieurs gigaoctets épargnés au disque
/// comme au transfert.
Future<String> queueAvatarUpload({
  required SupabaseClient client,
  required String folder,
  required String ownerId,
  required Uint8List bytes,
  required String ext,
}) async {
  final media = await compressAvatar(
    bytes: bytes,
    fileName: 'photo.$ext',
    mime: mimeForImageExtension(ext),
  );
  final e = media.fileName.contains('.')
      ? media.fileName.split('.').last
      : ext;
  final chemin = '$folder/${ownerId}_${_uuid.v4().substring(0, 8)}.$e';

  await enqueueUpload(
    bucket: kAvatarsBucket,
    storagePath: chemin,
    bytes: media.bytes,
    mime: media.mime,
    fileName: media.fileName,
  );

  // Envoi immédiat si le réseau est là ; sinon la file part à son retour.
  unawaited(flushUploadOutbox(client));
  return client.storage.from(kAvatarsBucket).getPublicUrl(chemin);
}

/// Le CHEMIN Storage porté par une URL publique Supabase, ou `null`.
///
/// Forme attendue :
/// `https://<ref>.supabase.co/storage/v1/object/public/<bucket>/<chemin>`
///
/// ── POURQUOI C'EST UNE FONCTION À PART ─────────────────────────────────────
/// C'est la pièce fragile de tout le mécanisme : `upload_outbox` indexe par
/// CHEMIN, la colonne porte une URL, et rien ne relie les deux qu'un découpage
/// de chaîne. S'il se trompe d'un caractère, la recherche ne rend rien — pas
/// d'erreur, pas de trace : simplement une photo qui reste cassée jusqu'au
/// retour du réseau, exactement le défaut qu'on voulait corriger.
///
/// Isolée du disque et de la base, elle se teste pour ce qu'elle est : du
/// texte vers du texte.
String? storagePathFromPublicUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  const marqueur = '/storage/v1/object/public/';
  final i = url.indexOf(marqueur);
  if (i < 0) return null;
  var reste = url.substring(i + marqueur.length);
  // `getPublicUrl` peut suffixer une requête (paramètres de transformation).
  for (final coupe in ['?', '#']) {
    final k = reste.indexOf(coupe);
    if (k >= 0) reste = reste.substring(0, k);
  }
  // `reste` vaut « bucket/chemin » : on rend le chemin seul.
  final slash = reste.indexOf('/');
  if (slash <= 0 || slash == reste.length - 1) return null;
  return reste.substring(slash + 1);
}
