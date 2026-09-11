import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  TOUTE PORTE DE CRÉATION SE FERME AVEC LE MÊME VERBE
//
//  ── LE DÉFAUT, TROUVÉ LE 2026-08-28 ────────────────────────────────────────
//  Les barres d'outils étaient gardées : `PermissionGate(action: 'create')` ou
//  `canProvider(create)`. Les ÉTATS VIDES ne l'étaient pas — ils n'avaient que
//  `readOnly`, quand ils avaient quelque chose.
//
//  C'est la pire moitié à oublier. L'état vide est celui d'une école qui
//  démarre : c'est donc le premier écran que TOUT LE MONDE voit, et le seul où
//  l'action est mise en avant, au centre, en gros.
//
//  Cinq portes étaient ouvertes, et elles l'étaient EN PRODUCTION, sur le build
//  déployé, atteignables par des profils du catalogue livré :
//
//    Matières      ← Secrétariat lit `matieres` sans `create`
//    Programmes    ← Secrétariat lit `programmes` sans `create`
//    Classes       ← Secrétariat lit `classes` sans `create`
//    Élèves        ← Comptabilité, Enseignant, Vie scolaire lisent `eleves`
//    Inscriptions  ← les mêmes, sur `inscriptions`
//
//  Les cinq tables (`subjects`, `school_programs`, `classes`, `students`,
//  `class_enrollments`) exigent le verbe `create` à l'INSERT depuis les
//  migrations 0129 / 0131 / 0135. Un refus est un 42501 : le connecteur
//  PowerSync appelle `transaction.complete()` et JETTE LE LOT ENTIER en
//  attente sur le poste — l'appel du matin, les paiements du guichet, les notes
//  de la journée. Sans un message.
//
//  ── CE QUE J'AVAIS MESURÉ, ET CE QUE JE N'AVAIS PAS MESURÉ ─────────────────
//  `docs/DEPLOIEMENT_ORDRE.md` concluait « rien n'est exposé aujourd'hui » à
//  partir d'une seule requête : les profils détenant `update` SANS `create`.
//  Elle était juste, et elle ne couvrait pas ce cas-ci : un profil qui LIT sans
//  pouvoir créer, devant un écran qui offre la création à quiconque sait lire.
//  Le trou n'était pas dans la base, il était dans ma façon de la sonder.
// ════════════════════════════════════════════════════════════════════════════

/// Écrans de l'espace personnel (hors ligne) dont l'état vide propose une
/// action d'écriture. `AdminEmptyState` y est le SECOND chemin vers le
/// formulaire — le premier, la barre d'outils, était déjà gardé.
const _kPortes = <String>[
  'lib/features/structure/screens/subjects_screen.dart',
  'lib/features/structure/screens/programmes_screen.dart',
  'lib/features/classes/screens/classes_screen.dart',
  'lib/features/students/screens/eleves_screen.dart',
  'lib/features/students/screens/inscriptions_screen.dart',
  'lib/features/students/screens/transferts_screen.dart',
];

String _lire(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) fail('$chemin introuvable — tourner depuis `epilote/`.');
  return f.readAsStringSync().replaceAll('\r\n', '\n');
}

/// Rend chaque bloc `AdminEmptyState( … )` du fichier, parenthèses équilibrées.
List<String> _etatsVides(String src) {
  final blocs = <String>[];
  for (var i = src.indexOf('AdminEmptyState(');
      i >= 0;
      i = src.indexOf('AdminEmptyState(', i + 1)) {
    var j = i + 'AdminEmptyState('.length;
    var profondeur = 1;
    while (j < src.length && profondeur > 0) {
      if (src[j] == '(') profondeur++;
      if (src[j] == ')') profondeur--;
      j++;
    }
    blocs.add(src.substring(i, j));
  }
  return blocs;
}

void main() {
  group('Un état vide qui propose d\'écrire lit le verbe `create`', () {
    for (final chemin in _kPortes) {
      test(chemin.split('/').last, () {
        final src = _lire(chemin);
        final offrants = _etatsVides(src)
            .where((b) => b.contains('actionLabel') && !b.contains('actionLabel: null'))
            .toList();
        expect(offrants, isNotEmpty,
            reason: 'Cet écran n\'offre plus rien depuis son état vide : '
                'retirer sa ligne de `_kPortes` plutôt que de la laisser '
                'garder un cas qui n\'existe plus.');
        for (final bloc in offrants) {
          expect(bloc.contains('canCreate'), isTrue,
              reason: 'Un `AdminEmptyState` propose une action sans lire le '
                  'verbe `create` : la RLS la refusera en 42501, et le lot '
                  'PowerSync entier partira avec.\n$bloc');
        }
        expect(src.contains("action: 'create'"), isTrue,
            reason: '`canCreate` doit venir du module, pas d\'un booléen local.');
      });
    }
  });

  group('Le verbe se compose toujours avec l\'année en lecture seule', () {
    test('aucune porte ne s\'ouvre sur une année archivée', () {
      for (final chemin in _kPortes) {
        final src = _lire(chemin);
        expect(src.contains('yearReadOnlyProvider'), isTrue,
            reason: '$chemin ne lit pas `yearReadOnlyProvider` : on pourrait '
                'créer dans une année close.');
        expect(
            RegExp(r'canCreate\s*=[\s\S]{0,200}?!\s*(readOnly|ref\.watch\(yearReadOnlyProvider\))')
                .hasMatch(src),
            isTrue,
            reason: '$chemin : `canCreate` doit composer le verbe ET '
                'l\'année. Le droit d\'écrire ne survit pas à la clôture.');
      }
    });
  });
}
