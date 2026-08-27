import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  « VALIDER » DOIT AVOIR UNE CONSÉQUENCE
//
//  ── LE DÉFAUT, TROUVÉ LE 2026-08-27 ────────────────────────────────────────
//  La règle métier §8.3 du cahier s'intitule « Validation NOTES : le directeur
//  valide avant publication ». Or la chaîne d'une évaluation
//
//      brouillon → soumise → VALIDÉE → PUBLIÉE
//
//  était gardée de bout en bout par `update` — droit que l'enseignant possède.
//  Il soumettait donc son travail, le validait lui-même, puis le publiait :
//  toute la cérémonie tenait dans une seule main.
//
//  Pire : une évaluation « validée » restait modifiable ET renotable. Le chef
//  d'établissement arrêtait les notes, l'enseignant les changeait ensuite. Le
//  mot « validée » ne voulait rien dire.
//
//  0118 avait corrigé le MÊME défaut sur les bulletins et manqué celui-ci —
//  alors que c'est celui que la règle nomme.
//
//  ── LES DEUX MOITIÉS BOUGENT ENSEMBLE ──────────────────────────────────────
//  Un refus 42501 est FATAL pour le connecteur PowerSync (lot entier jeté).
//  L'écran doit donc refuser AVANT la base : migration 0121 et ce code sont du
//  même commit. Ce fichier garde la moitié applicative.
// ════════════════════════════════════════════════════════════════════════════

const _kModele = 'lib/features/evaluation/providers/evaluations_provider.dart';
const _kListe = 'lib/features/evaluation/screens/notes_list.dart';
const _kEcran = 'lib/features/evaluation/screens/notes_screen.dart';

String _lire(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) fail('$chemin introuvable — tourner depuis `epilote/`.');
  return f.readAsStringSync();
}

/// Le fichier sans ses commentaires : l'en-tête d'un correctif cite forcément
/// la forme fautive pour l'expliquer, et cette mémoire doit rester lisible.
String _codeSeul(String chemin) => _lire(chemin)
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  group('Une évaluation validée est figée', () {
    test('le modèle sait le dire', () {
      expect(_codeSeul(_kModele).contains('bool get estFigee'), isTrue,
          reason: 'Sans ce mot, chaque écran réinvente la condition — et '
              'l\'un d\'eux l\'écrira de travers.');
    });

    test('la saisie des notes se ferme après validation', () {
      final code = _codeSeul(_kEcran);
      expect(code.contains('(!e.estFigee || canValider)'), isTrue,
          reason: 'La saisie restait ouverte sur une évaluation VALIDÉE : le '
              'directeur arrêtait les notes, l\'enseignant les changeait.');
      expect(RegExp(r'canGrade\s*=[\s\S]{0,200}!e\.isPublished;').hasMatch(code),
          isFalse,
          reason: 'Ne garder que « non publiée » laisse « validée » ouverte.');
    });
  });

  group('Valider et publier ne sont pas modifier', () {
    test('chaque transition exige son propre droit', () {
      final code = _codeSeul(_kListe);
      // La forme fautive : les trois transitions rendues par un switch nu,
      // puis offertes en bloc sous `canEdit`.
      expect(code.contains("'submitted' => canValidate ?"), isTrue,
          reason: 'Valider est réservé à qui détient `validate`.');
      expect(code.contains("'validated' => canValidate ?"), isTrue,
          reason: 'Publier aussi — c\'est le geste que §8.3 encadre.');
      expect(code.contains("'draft' => canEdit ?"), isTrue,
          reason: 'Soumettre reste à l\'enseignant : c\'est son travail.');
      expect(code.contains('if (next != null && canEdit)'), isFalse,
          reason: 'Ce garde unique donnait les trois étapes à `update`.');
    });

    test('défaire la validation exige de pouvoir valider', () {
      final code = _codeSeul(_kListe);
      expect(code.contains('final peutToucher = e.estFigee ? canValidate : canEdit;'),
          isTrue,
          reason: 'Repasser en brouillon défait l\'acte du chef '
              'd\'établissement : ce n\'est pas une modification ordinaire.');
      expect(code.contains("&& peutToucher)"), isTrue);
    });

    test('supprimer une évaluation figée aussi', () {
      expect(_codeSeul(_kListe).contains('canDelete && (!e.estFigee || canValidate)'),
          isTrue,
          reason: 'Sinon `delete` contourne tout le reste.');
    });

    test('l\'écran lit bien le droit `validate`', () {
      final code = _codeSeul(_kEcran);
      expect(code.contains("action: 'validate'"), isTrue);
      expect(code.contains('canValidate: canValider && !readOnly'), isTrue,
          reason: 'Et l\'année archivée ferme tout, comme partout.');
    });
  });
}
