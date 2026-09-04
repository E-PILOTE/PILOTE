import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LA TUTELLE S'ÉCRIT SUR LE GROUPE, ET NULLE PART AILLEURS
//
//  ── LE DÉFAUT QUE CE GARDE EMPÊCHE DE REVENIR ─────────────────────────────
//  `schools.tutelle` était nullable, sans défaut, et le formulaire d'école ne
//  l'écrivait JAMAIS. Les 37 écoles existantes ne la portent que parce
//  qu'elles viennent d'une migration de départ : la prochaine école créée
//  depuis l'application serait née SANS MINISTÈRE — et une école sans tutelle
//  ne remonte dans aucun état ministériel.
//
//  La migration 0153 tranche : la tutelle appartient au GROUPE, l'école en
//  hérite par déclencheur. `schools.tutelle` survit en COPIE DÉNORMALISÉE
//  (la supprimer aurait rejoué la faute 0146 : 42703, code absent de la
//  famille fatale, donc rejeu silencieux et infini du lot PowerSync).
//
//  Deux façons de casser ça, toutes deux muettes :
//   1. le formulaire de GROUPE cesse d'envoyer `tutelle` → groupes orphelins ;
//   2. un écran d'ÉCOLE se met à écrire `tutelle` → il écrit dans la copie,
//      le déclencheur la réécrira, et les deux valeurs se contrediront le
//      temps d'un rapport.
//
//  ── UNE SONDE NE PROUVE QUE CE QU'ELLE INTERROGE ──────────────────────────
//  `_lire` suit les directives `part` : le formulaire de groupe a justement
//  été sorti dans `groups/group_form_modal.dart` en même temps que ce champ
//  était ajouté. Une sonde qui ne lirait que le fichier principal aurait
//  déclaré « conforme » un formulaire qu'elle n'a pas ouvert.
// ════════════════════════════════════════════════════════════════════════════

/// Lit [chemin] ET tous les fichiers qu'il déclare en `part`.
String _lire(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) fail('Fichier introuvable : $chemin — sonde aveugle.');
  var src = f.readAsStringSync().replaceAll('\r\n', '\n');
  final dossier = chemin.substring(0, chemin.lastIndexOf('/'));
  for (final m in RegExp(r"^part\s+'([^']+)';", multiLine: true).allMatches(src)) {
    final part = File('$dossier/${m.group(1)}');
    if (part.existsSync()) src += '\n${part.readAsStringSync()}';
  }
  return src;
}

void main() {
  const formulaireGroupe =
      'lib/features/super_admin/screens/school_groups_screen.dart';
  const providerEcoles =
      'lib/features/admin_groupe/providers/admin_schools_provider.dart';
  const formulaireEcole =
      'lib/features/admin_groupe/screens/admin_schools_screen.dart';

  test('le formulaire de groupe envoie la tutelle', () {
    final src = _lire(formulaireGroupe);
    expect(src.contains("'tutelle':"), isTrue,
        reason: 'Le formulaire de GROUPE n\'écrit plus la tutelle : les '
            'groupes créés depuis l\'application naîtraient sans ministère.');
  });

  test('le formulaire de groupe la rend obligatoire', () {
    final src = _lire(formulaireGroupe);
    // La validation doit vivre dans un FormField : un contrôle posé ailleurs
    // ne serait pas vu par `Form.validate()`, et « Créer le groupe »
    // enregistrerait quand même.
    expect(src.contains('tutelleConnue('), isTrue,
        reason: 'Plus de validation de tutelle dans le formulaire de groupe.');
    expect(RegExp(r'FormField<String>').hasMatch(src), isTrue,
        reason: 'La validation de tutelle doit passer par un FormField pour '
            'que Form.validate() la voie.');
  });

  // ⚠️ LE TEST QUI COMPTE VRAIMENT.
  test('aucun écran d\'école n\'écrit la tutelle', () {
    for (final chemin in [providerEcoles, formulaireEcole]) {
      final src = _lire(chemin);
      expect(src.contains("'tutelle':"), isFalse,
          reason: '$chemin écrit `tutelle` : c\'est une COPIE tenue par '
              'déclencheur depuis le groupe (migration 0153). L\'écrire ici '
              'la fait diverger le temps d\'un rapport.');
    }
  });

  test('le formulaire d\'école transmet le type d\'établissement', () {
    final src = _lire(formulaireEcole);
    // Création ET édition : n'en câbler qu'une laisserait le type saisi à la
    // création disparaître à la première modification de la fiche.
    expect('institutionTypeId:'.allMatches(src).length, greaterThanOrEqualTo(2),
        reason: 'Le type d\'établissement doit être transmis à la création ET '
            'à l\'édition.');
    expect(src.contains('SchoolInstitutionTypeField'), isTrue,
        reason: 'Le champ de type d\'établissement a disparu de la fiche.');
  });

  test('le type d\'établissement n\'est pas confondu avec le secteur', () {
    final src = _lire(providerEcoles);
    // `school_type` (public/privé) et `institution_type_id` (CEG, CET…) sont
    // deux colonnes distinctes. Le jour où l'une remplacerait l'autre, la
    // question « combien d'élèves en CET ? » redeviendrait insoluble.
    expect(src.contains("'school_type'"), isTrue);
    expect(src.contains("'institution_type_id'"), isTrue);
  });
  test('un SEUL écran écrit l\'agrément, et c\'est celui du groupe', () {
    // L'agrément appartient à la PERSONNE MORALE, donc au groupe (0158). Les
    // écoles en héritent par déclencheur, et depuis 0164 la base FORCE la
    // copie à chaque écriture : un numéro écrit sur une école est écrasé.
    //
    // Un écran qui l'écrirait quand même afficherait donc « enregistré » sur
    // une valeur que la base vient de remplacer — le pire des deux mondes.
    final motif = RegExp(r"'agrement_(numero|type|date)'\s*:");
    final ecrivains = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (motif.hasMatch(f.readAsStringSync())) {
        ecrivains.add(f.path.replaceAll(r'\', '/'));
      }
    }
    expect(ecrivains.length, 1,
        reason: 'Écrans écrivant l\'agrément : ${ecrivains.join(", ")}. '
            'Seul le formulaire de GROUPE doit le faire.');
    expect(ecrivains.single.endsWith('group_form_modal.dart'), isTrue,
        reason: 'L\'agrément est écrit depuis ${ecrivains.single}.');
  });

  // ── LE GARDE QUI A MORDU LE 2026-08-31 ──────────────────────────────────
  test('un SEUL écran crée un groupe scolaire, et il envoie la tutelle', () {
    // ⚠️ L'écran des ABONNEMENTS en créait un second, sans `tutelle`. Un tel
    // groupe n'apparaît dans le réseau d'AUCUN ministère, et ses écoles
    // héritent d'une tutelle nulle par le déclencheur de la migration 0153 —
    // exactement la brèche que 0155 et 0158 avaient fermée.
    //
    // Deux formulaires de création aux champs différents, c'est la garantie
    // qu'un groupe naîtra un jour à moitié configuré. Il n'y en a qu'un.
    final motif = RegExp(
        r"\.from\(\s*'school_groups'\s*\)\s*(?:\r?\n\s*)?\.insert\b");
    final creent = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (motif.hasMatch(f.readAsStringSync())) {
        creent.add(f.path.replaceAll(r'\', '/'));
      }
    }

    expect(creent.length, 1,
        reason: 'Écrans créant un groupe scolaire : ${creent.join(", ")}. '
            'Il ne doit y en avoir QU\'UN — celui qui demande la tutelle.');
    expect(creent.single.endsWith('group_form_modal.dart'), isTrue,
        reason: 'La création de groupe a migré vers ${creent.single} : '
            'vérifier qu\'il demande bien la tutelle, l\'agrément et le '
            'secteur avant d\'accepter ce déplacement.');
    expect(File(creent.single).readAsStringSync().contains("'tutelle':"), isTrue,
        reason: 'Le seul écran de création n\'envoie plus la tutelle.');
  });
}
