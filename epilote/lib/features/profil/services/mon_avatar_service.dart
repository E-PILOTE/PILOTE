import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/models/profile_model.dart';
import '../../../services/powersync/avatar_upload.dart';
import '../../staff/providers/staff_photo_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  MA PHOTO — la colonne que tout le monde lisait et que personne n'écrivait
//
//  ── CE QUI MANQUAIT ───────────────────────────────────────────────────────
//  `avatar_url` s'affiche dans l'annuaire, la messagerie, le fil d'annonces et
//  le sélecteur d'agent. Elle était LUE partout, ÉCRITE nulle part par
//  l'intéressé : un super_admin pouvait poser la photo d'un administrateur,
//  une école pouvait demander celle d'un agent — personne ne pouvait poser la
//  sienne.
//
//  ── ⚠️ DEUX CHEMINS, ET CE N'EST PAS UN DÉTAIL DE CONFORT ─────────────────
//  Le personnel scolaire écrit par PowerSync. Un `UPDATE profiles` local
//  touchant `avatar_url` remonterait en `42501` dès que la ligne n'est pas
//  celle du compte de l'appareil — code que le connecteur tient pour FATAL :
//  la transaction ENTIÈRE est abandonnée, avec les notes et les paiements
//  saisis dans la même fenêtre. Sur un poste partagé, la fiche affichée EST
//  souvent celle d'un autre que le compte appareil.
//
//  On emprunte donc la porte déjà ouverte par la migration 0113 : une DEMANDE
//  dans `staff_photo_requests`, que le serveur applique par déclencheur avec
//  l'autorité exacte de `corriger_fiche_agent`. Aucun droit relâché, seul le
//  moment change — et `photo_agent_hors_ligne_test.dart` interdit toute autre
//  forme sous `lib/`.
//
//  Les deux espaces en ligne (super_admin, admin_groupe) écrivent la colonne
//  directement : leur session EST leur identité, la RLS les accepte.
//
//  ── OFFLINE-FIRST DANS LES DEUX CAS ───────────────────────────────────────
//  `queueAvatarUpload` compresse, met les octets en file et rend l'adresse
//  publique DÉFINITIVE avant que le fichier n'existe (`getPublicUrl` est une
//  concaténation). L'adresse s'écrit tout de suite ; au retour du réseau le
//  fichier monte à ce chemin exact.
// ════════════════════════════════════════════════════════════════════════════

/// Extensions acceptées — alignées sur ce que le stockage sait servir.
const kExtensionsPhotoProfil = ['jpg', 'jpeg', 'png', 'webp'];

class EchecPhotoProfil implements Exception {
  const EchecPhotoProfil(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Le dossier logique du bucket, selon l'espace de la personne.
/// Un administrateur de plateforme n'est pas rangé avec le personnel d'école.
String dossierPhoto({required bool estPersonnel}) =>
    estPersonnel ? 'staff' : 'admins';

/// Choisit une image, la met en file et la fait porter par la fiche.
///
/// Rend l'adresse VISÉE, ou `null` si le sélecteur a été refermé — ce n'est
/// pas une erreur et l'écran ne doit rien afficher dans ce cas.
///
/// [onApercu] reçoit les octets dès le choix : sur une connexion congolaise
/// l'envoi dure, et un écran qui ne montre rien pendant ce temps donne à
/// croire que le clic n'a pas pris.
Future<String?> deposerMaPhoto({
  required SupabaseClient client,
  required ProfileModel profil,
  void Function(Uint8List apercu)? onApercu,
}) async {
  final choix = await FilePicker.platform.pickFiles(
    type: FileType.image,
    allowMultiple: false,
    withData: true,
  );
  if (choix == null || choix.files.isEmpty) return null;
  final fichier = choix.files.first;
  final octets = fichier.bytes;
  if (octets == null || octets.isEmpty) {
    throw const EchecPhotoProfil(
        'Le fichier choisi est vide ou illisible. Réessayez avec une autre '
        'image.');
  }

  final ext = (fichier.extension ?? '').toLowerCase();
  if (!kExtensionsPhotoProfil.contains(ext)) {
    throw const EchecPhotoProfil(
        'Format non accepté. Choisissez une image JPG, PNG ou WEBP.');
  }

  onApercu?.call(octets);

  final url = await queueAvatarUpload(
    client: client,
    folder: dossierPhoto(estPersonnel: profil.isSchoolStaff),
    ownerId: profil.id,
    bytes: octets,
    ext: ext,
  );
  await _appliquer(client: client, profil: profil, url: url, effacer: false);
  return url;
}

/// Retire ma photo — mes initiales reprennent sa place partout.
Future<void> retirerMaPhoto({
  required SupabaseClient client,
  required ProfileModel profil,
}) =>
    _appliquer(client: client, profil: profil, url: null, effacer: true);

Future<void> _appliquer({
  required SupabaseClient client,
  required ProfileModel profil,
  required String? url,
  required bool effacer,
}) async {
  if (profil.isSchoolStaff) {
    final groupe = profil.groupId;
    final ecole = profil.schoolId;
    if (groupe == null || groupe.isEmpty || ecole == null || ecole.isEmpty) {
      // Sans rattachement, la demande n'appartiendrait à aucun périmètre : elle
      // ne se synchroniserait pas et dormirait sur le poste sans rien dire.
      throw const EchecPhotoProfil(
          'Votre compte n\'est rattaché à aucune école : la photo ne peut pas '
          'être enregistrée. Signalez-le à votre administrateur.');
    }
    await deposerDemandePhotoAgent(
      groupId: groupe,
      schoolId: ecole,
      profileId: profil.id,
      avatarUrl: url,
      requestedBy: profil.id,
      effacer: effacer,
    );
    return;
  }

  await client.from('profiles').update({
    'avatar_url': url,
    'updated_at': DateTime.now().toIso8601String(),
  }).eq('id', profil.id);
}
