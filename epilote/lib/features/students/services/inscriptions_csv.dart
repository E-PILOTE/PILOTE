import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../providers/inscriptions_data_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  EXPORT CSV DU GUICHET — séparateur « ; » et BOM UTF-8.
//
//  ⚠️ Les deux ne sont pas négociables : Excel en configuration française lit
//  le point-virgule comme séparateur de colonnes, et sans BOM il rend « Ngoué »
//  en « NgouÃ© ». Une liste d'élèves illisible est une liste inutilisable — et
//  c'est le format sous lequel les écoles s'échangent réellement leurs
//  effectifs.
//
//  ── CE FICHIER DOIT POUVOIR RENTRER PAR LA PORTE D'À CÔTÉ ──────────────────
//  ⚠️ L'export ne portait ni DATE DE NAISSANCE, ni identifiant national, ni
//  lieu de naissance. Or l'import (`import_liste_eleves.dart`) tient la date de
//  naissance pour obligatoire et rejette toute ligne qui en manque : notre
//  propre export, réimporté dans E-PILOTE, était rejeté À CENT POUR CENT.
//
//  Ce n'est pas un cas d'école. C'est le geste de la fin d'année et celui du
//  transfert : une école exporte ses effectifs et les envoie à une autre, ou
//  les ressort pour les corriger dans Excel avant de les réinjecter. Les deux
//  se heurtaient à un mur, et l'écran de contrôle affichait trois cents lignes
//  rouges sans que personne comprenne pourquoi.
//
//  Les en-têtes ajoutées sont donc écrites AVEC LES LIBELLÉS QUE LE LECTEUR
//  RECONNAÎT (`_synonymes` de l'import) — « Date de naissance », « Lieu de
//  naissance », « INE », « Nationalité » — et non avec des noms de colonnes
//  choisis librement.
// ════════════════════════════════════════════════════════════════════════════


String _csvCell(String? v) {
  final s = (v ?? '').replaceAll('"', '""');
  return '"$s"';
}

/// Génère un CSV (séparateur `;` — compatible Excel FR) des inscriptions filtrées
/// et l'écrit dans le dossier Documents de l'appareil. Retourne le chemin.
Future<String> exportInscriptionsCsv(List<InscriptionRow> rows) async {
  final b = StringBuffer();
  b.writeln([
    // ⚠️ « Date de naissance » est la colonne qui rend ce fichier réutilisable :
    // sans elle, l'import rejette chaque ligne. « INE » suit le même
    // raisonnement — c'est l'identifiant qui recoud la scolarité d'un enfant
    // d'un établissement à l'autre, et l'omettre d'une liste que les écoles
    // s'échangent revient à couper ce fil au moment précis où il sert.
    'Matricule', 'INE', 'Nom', 'Prénom', 'Sexe',
    'Date de naissance', 'Lieu de naissance', 'Nationalité',
    'Classe', 'Cycle',
    'Type', 'Statut', 'Redoublant', 'Date inscription',
  ].map(_csvCell).join(';'));
  for (final r in rows) {
    b.writeln([
      r.matricule, r.ine ?? '', r.lastName, r.firstName,
      r.gender ?? '',
      // Format ISO « AAAA-MM-JJ » : le lecteur d'import l'accepte, et il ne
      // souffre pas de l'ambiguïté jour/mois d'un tableur configuré en anglais.
      r.dateOfBirth?.toIso8601String().substring(0, 10) ?? '',
      r.placeOfBirth ?? '', r.nationality ?? '',
      r.className, r.cycle.label,
      r.typeLabel, r.statusLabel, r.isRepeating ? 'Oui' : 'Non',
      r.enrollmentDate?.toIso8601String().substring(0, 10) ?? '',
    ].map(_csvCell).join(';'));
  }
  final dir = await getApplicationDocumentsDirectory();
  final ts = DateTime.now().toIso8601String().substring(0, 10);
  final file = File('${dir.path}/inscriptions_$ts.csv');
  // BOM UTF-8 pour qu'Excel lise correctement les accents.
  await file.writeAsString('﻿${b.toString()}');
  return file.path;
}
