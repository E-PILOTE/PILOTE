import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

// ════════════════════════════════════════════════════════════════════════════
//  ÉCRIRE UN CSV LÀ OÙ L'AGENT LE DEMANDE — pas là où nous, nous le décidons
//
//  ── LE DÉFAUT QUE CE FICHIER CORRIGE ───────────────────────────────────────
//  ⚠️ Nos exports CSV écrivaient dans `getApplicationDocumentsDirectory()`
//  sans rien demander. Sous Windows — la plateforme de déploiement — ce dossier
//  « Documents » est le plus souvent REDIRIGÉ VERS ONEDRIVE : le fichier part
//  donc dans le nuage du compte Microsoft du poste, et non dans les
//  téléchargements de l'agent. Trois conséquences, toutes vues en école :
//
//   1. L'agent clique « Télécharger », rien ne s'ouvre, et il ne trouve pas son
//      fichier — il le cherche dans « Téléchargements », où il n'est pas.
//   2. Sur un poste partagé d'établissement, la liste nominative des élèves
//      est téléversée dans un espace personnel qui n'est pas celui de l'école.
//   3. Hors ligne — le cas normal ici — OneDrive garde le fichier en attente
//      de synchronisation, avec les surprises d'usage que cela suppose.
//
//  La règle est donc : TOUT fichier destiné à l'agent passe par « Enregistrer
//  sous ». C'est déjà ce que font tous nos exports PDF
//  (`FilePicker.platform.saveFile`) ; les CSV étaient les seuls à trancher à la
//  place de l'utilisateur. Ne pas confondre avec la BASE LOCALE, qui elle doit
//  au contraire rester invisible et hors OneDrive
//  (`services/powersync/local_storage_dir.dart`).
//
//  ── POURQUOI ON RÉÉCRIT APRÈS LE SÉLECTEUR ─────────────────────────────────
//  ⚠️ `saveFile` reçoit déjà les octets, mais la fenêtre « Enregistrer sous »
//  de Windows ne CRÉE pas le fichier : elle rend un chemin. Selon la
//  plateforme, file_picker écrit ou n'écrit pas. On réécrit donc toujours
//  nous-mêmes — sans quoi, en écrasant un export plus ancien du même nom,
//  l'agent repartirait avec l'ANCIEN contenu en croyant tenir le nouveau.
//
//  ── ENCODAGE ───────────────────────────────────────────────────────────────
//  ⚠️ BOM UTF-8 en tête, séparateur « ; » côté appelant. Sans le BOM, Excel en
//  configuration française rend « Ngoué » en « NgouÃ© ».
// ════════════════════════════════════════════════════════════════════════════

/// Marque d'ordre des octets UTF-8 — ce qui dit à Excel FR de lire nos accents.
const String kBomUtf8 = '\u{FEFF}';

/// Ouvre « Enregistrer sous » puis écrit [contenu] au chemin choisi.
///
/// Retourne le chemin écrit, ou `null` si l'agent a fermé la fenêtre — une
/// annulation n'est pas une erreur et ne doit jamais s'afficher comme telle.
Future<String?> enregistrerCsvSous({
  required String nomPropose,
  required String contenu,
  required String titreFenetre,
}) async {
  final octets = _octets(contenu);
  final chemin = await FilePicker.platform.saveFile(
    dialogTitle: titreFenetre,
    fileName: nomPropose,
    type: FileType.custom,
    allowedExtensions: const ['csv'],
    bytes: octets,
  );
  if (chemin == null) return null;
  await File(chemin).writeAsBytes(octets, flush: true);
  return chemin;
}

/// Écrit [contenu] à [chemin] sans rien demander.
///
/// Réservé aux fichiers qui ACCOMPAGNENT un fichier déjà placé par l'agent —
/// la liste des classes déposée à côté du modèle d'import, par exemple. Deux
/// fenêtres pour un seul geste seraient une fenêtre de trop.
Future<void> ecrireCsvA(String chemin, String contenu) =>
    File(chemin).writeAsBytes(_octets(contenu), flush: true);

Uint8List _octets(String contenu) =>
    Uint8List.fromList(utf8.encode('$kBomUtf8$contenu'));
