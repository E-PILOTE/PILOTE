import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE PÉRIMÈTRE DE FINANCE EST CELUI DE FINANCE
//
//  ── DEUX DÉFAUTS, TROUVÉS LE 2026-08-25, QUE RIEN N'AURAIT SIGNALÉS ─────────
//
//  F1. Le `data_scope` du module `paiements-eleves` n'était lu NULLE PART.
//      L'écran Paiements tirait ses classes de `classesProvider`, verrouillé
//      sur le module `classes` : il héritait donc du périmètre d'un AUTRE
//      module que le sien. Restreindre Paiements depuis l'administration
//      affichait une confirmation et ne changeait rien — un cadenas qui
//      annonce s'être fermé.
//
//      Le risque allait dans les deux sens, et le second est financier :
//      donner un jour `classes = own_classes` à un comptable — geste anodin,
//      pour limiter les listes qu'il parcourt — aurait rétréci son état de
//      recouvrement EN SILENCE. « Tout le monde a payé », parce que la moitié
//      des classes avait disparu du calcul.
//
//  F2. `class_provider.dart` recalculait le périmètre dans son coin, avec une
//      copie du helper canonique figée AVANT son durcissement. Il lui manquait
//      la ligne qui compte : `if (!permissionsLoaded(ref)) → AND 0 = 1`.
//      `modulePermissionProvider` rend `null` pour « module non accordé » ET
//      pour « profil pas encore lu ». Le doublon traitait les deux comme
//      « aucune restriction » : à chaque démarrage, le temps que le profil se
//      charge, un enseignant en `own_classes` voyait toute l'école.
//
//  C'est ce doublon qui a fait passer F1 inaperçu. Les deux tiennent ensemble.
// ════════════════════════════════════════════════════════════════════════════

const _kPaiements = 'lib/features/finance/providers/paiements_provider.dart';
const _kClasses = 'lib/features/classes/providers/class_provider.dart';
const _kPermissions =
    'lib/features/navigation/providers/permissions_provider.dart';

String _lire(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) fail('$chemin introuvable — tourner depuis `epilote/`.');
  return f.readAsStringSync();
}

List<File> _dartsSous(String chemin) => Directory(chemin)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList()
  ..sort((a, b) => a.path.compareTo(b.path));

void main() {
  group('Un seul calcul de périmètre, celui de permissions_provider', () {
    test('personne ne relit `scopedClassIdsProvider` en direct', () {
      // C'est la brique du helper canonique. La lire ailleurs, c'est refaire
      // le calcul — donc refaire un jour l'oubli du garde de chargement.
      final fautes = <String>[];
      for (final f in _dartsSous('lib')) {
        final chemin = f.path.replaceAll(r'\', '/');
        if (chemin.endsWith('permissions_provider.dart')) continue;
        if (f.readAsStringSync().contains('scopedClassIdsProvider(')) {
          fautes.add(chemin);
        }
      }
      expect(fautes, isEmpty,
          reason: 'Passer par `classScopeClause`, qui traite « je ne sais pas »'
              ' comme « restreint ».\n\n${fautes.join('\n')}');
    });

    test('le garde de chargement est dans le helper, et fail-closed', () {
      final src = _lire(_kPermissions);
      final i = src.indexOf('classScopeClause(');
      expect(i, greaterThan(0));
      // Le garde doit précéder toute lecture de permission dans la fonction.
      final corps = src.substring(i, i + 900);
      final gardePos = corps.indexOf('permissionsLoaded(ref)');
      final permPos = corps.indexOf('modulePermissionProvider(');
      expect(gardePos, greaterThan(0),
          reason: 'Sans ce garde, la fenêtre de chargement sert toute l\'école.');
      expect(gardePos, lessThan(permPos),
          reason: 'Le garde doit passer AVANT de lire la permission : c\'est '
              'précisément l\'ordre que le doublon de `class_provider` avait '
              'perdu.');
      expect(corps.contains('AND 0 = 1'), isTrue,
          reason: 'Le doute se traduit par « aucune ligne », jamais par '
              '« aucune restriction ».');
    });

    test('`class_provider` ne réimplémente plus rien', () {
      final src = _lire(_kClasses);
      // On vise la DÉCLARATION, pas la mention : l'en-tête du fichier raconte
      // le défaut et cite le nom du doublon, ce qui doit rester lisible.
      expect(RegExp(r'^\s*List<String>\?\s+_scope\w*\(', multiLine: true)
          .hasMatch(src), isFalse,
          reason: 'Le doublon privé est supprimé — ne pas le réintroduire.');
      // Quatre requêtes y sont bornées : classes, effectif, élèves, inscriptions.
      expect('classScopeClause('.allMatches(src).length, greaterThanOrEqualTo(4),
          reason: 'Les quatre requêtes doivent passer par le helper.');
    });
  });

  group('Finance borne ses requêtes par SON slug', () {
    test('le slug n\'est déclaré qu\'une fois dans tout Finance', () {
      // Le littéral vivait en double — provider et écran. Deux endroits à
      // changer, un seul changé, et le périmètre dérive sans bruit.
      var occurrences = 0;
      for (final f in _dartsSous('lib/features/finance')) {
        occurrences += "'paiements-eleves'".allMatches(f.readAsStringSync()).length;
      }
      expect(occurrences, 1,
          reason: 'Une seule déclaration : `kSlugPaiements`, dans le provider.');
    });

    test('les paiements demandent les classes de LEUR module', () {
      final src = _lire(_kPaiements);
      expect(src.contains('classesForModuleProvider(kSlugPaiements)'), isTrue);
      // `classesProvider` nu porterait le périmètre du module `classes`.
      expect(RegExp(r'watch\(\s*classesProvider\s*\)').hasMatch(src), isFalse,
          reason: 'C\'était exactement F1 : Finance héritait du périmètre du '
              'module `classes`, et son propre `data_scope` ne servait à rien.');
    });

    test('une classe hors périmètre ne livre pas ses élèves', () {
      // `classPaymentsProvider` est une famille : son `classId` vient de la
      // route, pas d'une liste déjà filtrée. Le SQL ne filtre que sur
      // `ce.class_id = ?2` — sans contrôle, connaître un identifiant suffisait.
      final src = _lire(_kPaiements);
      final i = src.indexOf('final classPaymentsProvider');
      expect(i, greaterThan(0));
      final corps = src.substring(i, i + 1200);
      expect(corps.contains('classesForModuleProvider(kSlugPaiements)'), isTrue);
      expect(corps.contains('if (classe == null) return Stream.value(const [])'),
          isTrue,
          reason: 'Fail-closed : une classe absente du périmètre rend une '
              'liste vide, jamais la classe demandée.');
    });
  });
}
