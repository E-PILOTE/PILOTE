part of '../school_groups_screen.dart';

// ─── Le logo du groupe : choisir, compresser, téléverser ──────────────────────

/// Ouvre le sélecteur de fichier, compresse l'image choisie et la téléverse.
/// Rend l'URL publique, ou `null` si l'agent a refermé le sélecteur.
///
/// [onApercu] reçoit les octets bruts DÈS le choix, avant l'envoi : sur une
/// connexion congolaise le téléversement dure, et un formulaire qui ne montre
/// rien pendant ce temps donne à croire que le clic n'a pas pris.
///
/// ⚠️ Les erreurs REMONTENT — cette fonction ne les affiche pas. Le message à
/// l'agent appartient à l'écran, qui seul sait dans quel contexte l'envoi a
/// échoué et quel état visuel défaire.
///
/// ⚠️ Le logo partait BRUT vers le stockage : un fichier sorti d'un téléphone
/// ou d'un scanner (3 à 8 Mo) était transféré tel quel pour être affiché… en
/// 38 pixels dans la liste des groupes. Sur les connexions congolaises, cet
/// envoi pouvait ne jamais aboutir — et chaque affichage le retéléchargeait.
/// La fiche ÉCOLE compressait déjà, pas celle du GROUPE : deux formulaires
/// jumeaux, un seul des deux corrigé. Ne pas retirer `compressLogo`.
Future<String?> choisirEtEnvoyerLogoGroupe({
  required SupabaseClient client,
  required ValueChanged<Uint8List> onApercu,
}) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    allowMultiple: false,
    withData: true,
  );
  if (result == null || result.files.isEmpty) return null;
  final file = result.files.first;
  if (file.bytes == null) return null;

  onApercu(file.bytes!);

  final media = await compressLogo(
    bytes: file.bytes!,
    fileName: file.name,
    mime: mimeForImageExtension(file.extension),
  );

  final ext = media.fileName.split('.').last;
  final path = 'groups/logo_${DateTime.now().millisecondsSinceEpoch}.$ext';

  await client.storage.from('group-logos').uploadBinary(
    path,
    media.bytes,
    fileOptions: FileOptions(contentType: media.mime, upsert: true),
  );

  return client.storage.from('group-logos').getPublicUrl(path);
}
