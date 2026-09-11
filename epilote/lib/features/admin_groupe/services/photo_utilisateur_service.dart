import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/capture_webcam.dart' show extensionPhoto;
import '../../../services/powersync/avatar_upload.dart';
import '../../profil/services/mon_avatar_service.dart' show dossierPhoto;

// ════════════════════════════════════════════════════════════════════════════
//  LA PHOTO D'UN AGENT, POSÉE DEPUIS L'ESPACE DU GROUPE
//
//  ── CE QUI MANQUAIT (2026-09-05) ──────────────────────────────────────────
//  L'espace admin_groupe crée le personnel des écoles — directeurs, censeurs,
//  enseignants, secrétaires, comptables. C'était le SEUL formulaire du produit
//  qui crée une personne sans jamais demander son visage : les élèves l'ont
//  (inscriptions et fiche élève), la fiche agent de l'espace école l'a, et même
//  l'écran des administrateurs de plateforme l'avait.
//
//  Or `avatar_url` n'est pas un ornement dans ce produit. Elle est lue par
//  l'annuaire, la messagerie, le fil d'annonces — et surtout par l'ÉCRAN-VERROU
//  des postes partagés, où l'agent choisit son visage dans une grille avant de
//  travailler. Sans photo, cette grille est une liste d'initiales : dans une
//  école où trois personnes s'appellent « M. », se tromper de tuile veut dire
//  saisir des notes au nom d'un collègue.
//
//  ── QUAND LA PHOTO PART, ET POURQUOI PAS AVANT ────────────────────────────
//  Les octets ne montent QU'À la validation du formulaire, jamais au moment du
//  choix. Deux raisons, et la première est dirimante :
//    • à la CRÉATION, l'identifiant de la personne n'existe pas encore — le
//      chemin de stockage ne peut donc pas être calculé ;
//    • un formulaire abandonné ne doit pas laisser de fichier orphelin dans le
//      seau, que plus rien ne relierait jamais à personne.
//  L'aperçu, lui, s'affiche immédiatement depuis les octets en mémoire : sur
//  une connexion congolaise, un écran qui ne montre rien fait recliquer.
//
//  ── LE COMPTE VAUT PLUS QUE LA PHOTO ──────────────────────────────────────
//  Si l'envoi échoue APRÈS la création du compte, on ne défait rien et l'on ne
//  laisse pas croire à un échec : le compte existe, il faut le dire. D'où
//  [PhotoNonPosee], que l'écran présente comme un avertissement et non comme
//  une erreur — sinon l'administrateur resoumet le formulaire et se heurte à
//  « cette adresse est déjà utilisée », sans comprendre.
// ════════════════════════════════════════════════════════════════════════════

/// Le compte a bien été créé (ou modifié) : seule la photo n'est pas arrivée.
class PhotoNonPosee implements Exception {
  const PhotoNonPosee(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Envoie les octets et rend l'adresse publique DÉFINITIVE de la photo.
///
/// `queueAvatarUpload` compresse, met en file et tente l'envoi tout de suite :
/// l'adresse est calculable avant que le fichier n'existe, donc la colonne peut
/// s'écrire immédiatement même si le réseau flanche en route.
Future<String> envoyerPhotoAgent({
  required SupabaseClient client,
  required String profileId,
  required Uint8List octets,
  required String nomFichier,
}) =>
    queueAvatarUpload(
      client: client,
      // Le personnel d'école se range avec le personnel d'école, jamais avec
      // les administrateurs de la plateforme — cf. `dossierPhoto`.
      folder: dossierPhoto(estPersonnel: true),
      ownerId: profileId,
      bytes: octets,
      ext: extensionPhoto(nomFichier),
    );

/// Écrit l'adresse dans la fiche, ou l'efface quand [url] est nulle.
///
/// Écriture DIRECTE, et c'est correct ici : l'espace du groupe travaille en
/// ligne, sa session est sa propre identité, et la RLS l'autorise sur les
/// profils de son périmètre. La porte détournée par `staff_photo_requests`
/// existe pour le personnel scolaire, dont l'écriture passe par PowerSync.
Future<void> poserPhotoAgent({
  required SupabaseClient client,
  required String profileId,
  required String? url,
}) =>
    client.from('profiles').update({
      'avatar_url': url,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', profileId);
