import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CHAQUE MODULE APPLIQUE SON PROPRE PÉRIMÈTRE, ET PAS CELUI D'UN AUTRE
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

    test('aucun écran n\'emprunte le périmètre du module `classes`', () {
      // ⚠️ CE MOTIF N'ÉTAIT PAS PROPRE À FINANCE. Une fois F1 corrigé, la
      // même erreur restait dans quinze autres fichiers : Évaluation, Vie
      // scolaire, Scolarité, Structure lisaient tous `classesProvider` en
      // croyant — un commentaire le disait noir sur blanc — que « le périmètre
      // est déjà appliqué ». Il l'est : celui du module `classes`, pas le leur.
      // Le `data_scope` posé sur Notes, Présences ou Cantine n'avait donc
      // aucun effet, et l'administration affichait un cadenas fermé sur rien.
      //
      // Trois exceptions, et trois seulement — chacune commentée sur place :
      // l'écran du module `classes`, et les deux blocs du tableau de bord
      // d'accueil, qui n'est pas un module et n'a pas de `data_scope` propre.
      const permis = {
        'features/classes/screens/classes_screen.dart',
        'features/user/screens/dashboard_chart_parts.dart',
        'features/user/screens/dashboard_kpi_parts.dart',
      };
      final motif = RegExp(r'(watch|read)\(\s*classesProvider\s*\)');
      final fautes = <String>[];
      for (final f in _dartsSous('lib')) {
        final chemin = f.path.replaceAll(r'\', '/');
        final relatif = chemin.substring(chemin.indexOf('lib/') + 4);
        if (permis.contains(relatif)) continue;
        if (motif.hasMatch(f.readAsStringSync())) fautes.add(relatif);
      }
      expect(fautes, isEmpty,
          reason: 'Passer par `classesForModuleProvider(<slug de cet écran>)`. '
              'Sans quoi le verrou de périmètre du module est inerte.\n\n'
              '${fautes.join('\n')}');
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

  // ══════════════════════════════════════════════════════════════════════════
  //  VIE SCOLAIRE — LE MÊME OUBLI, SUR LES DONNÉES LES PLUS SENSIBLES
  //
  //  ── TROUVÉ LE 2026-08-28 ──────────────────────────────────────────────────
  //  Trois modules sur six ne lisaient AUCUN périmètre : Discipline, Infirmerie
  //  et Bibliothèque interrogeaient l'école entière. Présences, Cantine et
  //  Orientation passaient bien par `classesForModuleProvider`. Les trois
  //  manquants étaient précisément ceux qui portent le disciplinaire et le
  //  médical de mineurs.
  //
  //  Et la fuite passait aussi par une porte de service : `vsStudentsProvider`,
  //  le SÉLECTEUR D'ÉLÈVE des formulaires Discipline, Infirmerie et
  //  Bibliothèque, listait tous les élèves de l'école — nom, matricule, classe.
  //  Un surveillant restreint à ses classes pouvait donc lire le registre
  //  complet, et ouvrir un incident disciplinaire sur n'importe quel enfant.
  //  Un provider partagé qui ignore le périmètre le fait fuir pour tous ses
  //  appelants d'un coup.
  // ══════════════════════════════════════════════════════════════════════════
  group('Vie scolaire borne ses requêtes par SON slug', () {
    const vs = 'lib/features/vie_scolaire';

    /// Occurrences du littéral `'slug'` qui ne sont pas un simple mot français
    /// échappé dans un titre (`'Journal de l\'infirmerie'`).
    int compteLitteral(String src, String slug) =>
        "'$slug'".allMatches(src).length -
        "\\'$slug'".allMatches(src).length;

    const modules = <String, String>{
      'discipline': 'discipline_provider.dart',
      'infirmerie': 'infirmerie_provider.dart',
      'cantine': 'cantine_provider.dart',
      'bibliotheque': 'biblio_provider.dart',
      'orientation': 'orientation_provider.dart',
      'presences-eleves': 'presences_provider.dart',
    };

    test('chaque provider borne ses lignes par un périmètre', () {
      final fautes = <String>[];
      for (final e in modules.entries) {
        final src = _lire('$vs/providers/${e.value}');
        final borne = src.contains('classScopeClause(') ||
            src.contains('classesForModuleProvider(');
        if (!borne) fautes.add('${e.value} (module `${e.key}`)');
      }
      expect(fautes, isEmpty,
          reason: 'Un module dont le provider ne lit aucun périmètre sert '
              'l\'école entière, et son `data_scope` est un cadenas fermé sur '
              'rien.\n\n${fautes.join('\n')}');
    });

    test('le slug de chaque module n\'est déclaré qu\'une fois', () {
      // Deux endroits à changer, un seul changé : c\'est ainsi qu\'un
      // périmètre dérive sans bruit. Cf. le même garde côté Finance.
      final fautes = <String>[];
      for (final slug in modules.keys) {
        var n = 0;
        for (final f in _dartsSous(vs)) {
          n += compteLitteral(f.readAsStringSync(), slug);
        }
        if (n != 1) fautes.add('`$slug` déclaré $n fois');
      }
      expect(fautes, isEmpty,
          reason: 'Un seul `const kSlug… = \'…\';`, dans le provider ; les '
              'écrans le lisent.\n\n${fautes.join('\n')}');
    });

    test('le sélecteur d\'élève partagé exige le slug de son appelant', () {
      final src = _lire('$vs/providers/vs_students_provider.dart');
      expect(src.contains('classScopeClause('), isTrue,
          reason: 'C\'est le formulaire qui écrit : sans périmètre ici, le '
              'verrou ne tient nulle part.');
      expect(RegExp(r'family<List<VsStudent>,\s*String>').hasMatch(src), isTrue,
          reason: 'Le périmètre appliqué doit être celui du module APPELANT — '
              'un même agent peut être `own_classes` en discipline et '
              '`own_school` en infirmerie.');

      // Aucun appel nu : `vsStudentsProvider)` sans argument ne compile plus,
      // mais le garde dit POURQUOI si quelqu\'un revient en arrière.
      final fautes = <String>[];
      for (final f in _dartsSous('lib')) {
        final chemin = f.path.replaceAll(r'\', '/');
        if (chemin.endsWith('vs_students_provider.dart')) continue;
        if (RegExp(r'vsStudentsProvider\s*\)')
            .hasMatch(f.readAsStringSync())) {
          fautes.add(chemin.substring(chemin.indexOf('lib/') + 4));
        }
      }
      expect(fautes, isEmpty, reason: fautes.join('\n'));
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  //  UNE NOTIFICATION AUX PARENTS PORTE SA DATE
  //
  //  `discipline_incidents` et `infirmary_visits` ont toutes deux une colonne
  //  `notified_at` — déclarée jusque dans le schéma SQLite local, donc
  //  synchronisée — que RIEN n'écrivait. On savait QUE les parents avaient été
  //  prévenus, jamais QUAND.
  //
  //  Dans un dossier disciplinaire, c'est la date qui fait le délai : c'est
  //  elle qu'on oppose à une famille qui conteste une sanction prise sans
  //  qu'elle ait été informée. Pour un enfant reparti de l'infirmerie après un
  //  malaise, c'est la même question, en plus urgent.
  // ══════════════════════════════════════════════════════════════════════════
  group('Une notification aux parents porte sa date', () {
    test('`parentNotified` ne s\'écrit jamais sans `notified_at`', () {
      final fautes = <String>[];
      for (final f in _dartsSous('lib')) {
        final src = f.readAsStringSync();
        // On vise l'ÉCRITURE, pas l'affichage : un écran qui montre la
        // case, un PDF qui l'imprime, n'ont pas de date à poser.
        final ecrit = src.contains('parentNotified ? 1 : 0') ||
            RegExp(r'parent_notified\s*=\s*\?').hasMatch(src);
        if (!ecrit) continue;
        if (src.contains('notified_at')) continue;
        final chemin = f.path.replaceAll(r'\', '/');
        fautes.add(chemin.substring(chemin.indexOf('lib/') + 4));
      }
      expect(fautes, isEmpty,
          reason: 'Une case cochée sans date ne prouve rien. Poser la date '
              'quand la case passe à vrai, l\'effacer quand elle repasse à '
              'faux.\n\n${fautes.join('\n')}');
    });

    test('la date se pose une fois et ne se réécrit pas', () {
      // Rouvrir un incident un mois plus tard pour corriger une faute de
      // frappe ne doit pas redater la notification aux parents.
      for (final p in const [
        'lib/features/vie_scolaire/providers/discipline_provider.dart',
        'lib/features/vie_scolaire/providers/infirmerie_provider.dart',
      ]) {
        expect(_lire(p).contains('COALESCE(notified_at, ?)'), isTrue,
            reason: '$p doit conserver la date déjà posée.');
      }
    });
  });
}
