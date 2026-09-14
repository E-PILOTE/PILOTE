import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE BARÈME DES MENTIONS N'A QU'UN SEUL EXEMPLAIRE
//
//  Il en a eu QUATRE. Deux avaient dérivé de deux points : un bulletin
//  affichait « Passable » pour 8/20 — une note d'échec présentée comme une
//  réussite, sur un document que la famille garde.
//
//  Trois ont été unifiés dans `core/utils/mention.dart` (migration 0059). Le
//  quatrième — la fonction SQL `get_mention()` — et les constantes mortes
//  d'`AppConstants` ont été supprimés le 2026-08-25 (migration 0117) : ni l'un
//  ni les autres n'avaient d'appelant, donc aucun test, et une règle qu'on ne
//  teste pas dérive en silence.
//
//  `mention_test.dart` garde les VALEURS du barème. Ce fichier-ci garde le fait
//  qu'il n'en existe qu'un — ce qu'aucun test de valeurs ne peut voir.
// ════════════════════════════════════════════════════════════════════════════

const _kMention = 'lib/core/utils/mention.dart';
const _kConstantes = 'lib/core/constants/app_constants.dart';
const _kDialogueExamen = 'lib/features/examens/widgets/exam_result_dialog.dart';

String _lire(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) fail('$chemin introuvable — tourner depuis `epilote/`.');
  return f.readAsStringSync().replaceAll('\r\n', '\n');
}

List<File> _dartsSous(String chemin) => Directory(chemin)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList();

void main() {
  group('Un seul endroit décide d\'une mention', () {
    test('aucun fichier ne redéclare les seuils', () {
      // La forme fautive : la suite 18/16/14/12 posée ailleurs qu'ici. On ne
      // cherche pas les nombres isolés — 16 est une taille de police — mais
      // leur ENCHAÎNEMENT, qui n'appartient qu'au barème.
      final motif = RegExp(r'>=?\s*18[\s\S]{0,200}>=?\s*16[\s\S]{0,200}'
          r'>=?\s*14[\s\S]{0,200}>=?\s*12');
      final fautes = <String>[];
      for (final f in _dartsSous('lib')) {
        final chemin = f.path.replaceAll(r'\', '/');
        if (chemin.endsWith('core/utils/mention.dart')) continue;
        if (motif.hasMatch(f.readAsStringSync())) fautes.add(chemin);
      }
      expect(fautes, isEmpty,
          reason: 'Le barème vit dans `mentionFor`. Une copie ailleurs finit '
              'par dériver, et c\'est déjà arrivé.\n\n${fautes.join('\n')}');
    });

    test('les constantes mortes ne reviennent pas', () {
      // On vise la DÉCLARATION, pas la mention : l'en-tête du fichier raconte
      // la suppression et cite les noms, ce qui doit rester lisible.
      final src = _lire(_kConstantes);
      expect(RegExp(r'static\s+const\s+\w+\s+seuil\w*\s*=').hasMatch(src),
          isFalse,
          reason: 'Quatrième exemplaire du barème, sans appelant : supprimé.');
      // ⚠️ Celle-ci n'était pas seulement morte, elle était fausse : l'enum
      // `user_role` n'a jamais eu la valeur « utilisateur », et un test
      // `role == 'utilisateur'` avait tué la synchro de tout le personnel.
      expect(RegExp(r'static\s+const\s+String\s+roleUtilisateur\s*=')
          .hasMatch(src), isFalse,
          reason: 'Piège dormant retiré — ne pas le réintroduire.');
    });

    test('`mentionFor` reste l\'unique porte, et se dit telle', () {
      final src = _lire(_kMention);
      expect(src.contains('String mentionFor('), isTrue);
      expect(src.contains('SEUL'), isTrue,
          reason: 'L\'en-tête doit dire pourquoi il n\'y a qu\'un exemplaire, '
              'sinon quelqu\'un en recréera un « pour le serveur ».');
    });
  });

  group('La mention d\'un résultat d\'examen se calcule vraiment', () {
    test('elle est déduite de la moyenne au moment d\'enregistrer', () {
      // ⚠️ LE DÉFAUT DU 2026-08-25 : `setResult` était appelé SANS `mention`,
      // donc la colonne recevait NULL — pendant que l'écran promettait à
      // l'agent « la mention est calculée par la base ». Rien en base ne la
      // calculait : ni trigger, ni colonne générée. La répartition des
      // mentions du cockpit METP serait restée vide, sans un mot.
      final src = _lire(_kDialogueExamen);
      expect(src.contains('mention: avg == null ? null : mentionFor(avg)'),
          isTrue,
          reason: 'Sans cela, la mention n\'est jamais écrite.');
      expect(src.contains("import '../../../core/utils/mention.dart';"), isTrue);
    });

    test('l\'écran ne promet plus que la base la calcule', () {
      // On ignore les lignes de COMMENTAIRE : l'en-tête raconte l'ancien texte,
      // et cette mémoire doit rester lisible. Seul ce qui s'affiche compte.
      final code = _lire(_kDialogueExamen)
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      expect(code.contains('par la base'), isFalse,
          reason: 'C\'était faux, et un agent s\'y fiait.');
      expect(code.contains('barème officiel'), isTrue,
          reason: 'L\'agent doit savoir d\'où sort la mention.');
    });

    test('sans moyenne, aucune mention n\'est inventée', () {
      // Un « absent » ou une « fraude » n'a pas de moyenne. Y écrire le tiret
      // rendu par `mentionFor(null)` inscrirait « — » en base comme s'il
      // s'agissait d'une mention, et il remonterait dans les statistiques.
      final src = _lire(_kDialogueExamen);
      expect(src.contains('avg == null ? null'), isTrue);
    });
  });
}
