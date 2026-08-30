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
  var src = f.readAsStringSync();
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
}
