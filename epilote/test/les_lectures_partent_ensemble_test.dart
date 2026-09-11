import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LES LECTURES PARTENT ENSEMBLE
//
//  ── CE QUI A ÉTÉ TROUVÉ (2026-09-06) ──────────────────────────────────────
//  Remarque du fondateur : « tout doit se charger à tout moment, l'endurance
//  vraiment ». Mesuré : les trois écrans les plus ouverts de la plateforme
//  faisaient leurs lectures en `await` SUCCESSIFS.
//
//    · tableau de bord du fondateur ......... 10 allers-retours à la file
//    · abonnement du groupe ................. 9
//    · tableau de bord du groupe ............ 8
//
//  Il n'y avait **aucun `Future.wait` dans toute l'application**. Sur une
//  liaison congolaise à 400 ms, dix allers-retours en file font quatre
//  secondes d'attente — chaque matin, sur la première page qu'on ouvre.
//
//  ── CE QUI A CHANGÉ, ET CE QUI N'A PAS CHANGÉ ─────────────────────────────
//  Aucune requête n'a été modifiée, aucun agrégat, aucun chiffre. Chaque bloc
//  a simplement été enfermé dans une fonction locale, et les fonctions partent
//  ensemble. Chacune garde son propre `catch` : un échec isolé ne fait pas
//  tomber les neuf autres, exactement comme avant.
//
//  ── POURQUOI CE FICHIER EXISTE ────────────────────────────────────────────
//  Ce gain se défait tout seul. Il suffit qu'on ajoute demain une lecture
//  `await` au milieu du provider pour remettre un aller-retour en série, sans
//  que rien ne le signale — le code marchera, il sera juste redevenu lent.
//
//  ⚠️ ET IL GARDE PLUS IMPORTANT QUE LA VITESSE : L'ORDRE. Certains calculs
//  lisent des tables que seule une des lectures remplit. Les remonter au-dessus
//  de l'attente les ferait travailler sur du vide — sans erreur, sans trace, et
//  avec des chiffres faux à l'écran. C'est le vrai danger de ce découpage, et
//  c'est ce que la seconde moitié de ce fichier surveille.
// ════════════════════════════════════════════════════════════════════════════

const _tableauGroupe =
    'lib/features/admin_groupe/providers/admin_dashboard_provider.dart';
const _tableauFondateur =
    'lib/features/super_admin/providers/super_dashboard_provider.dart';
const _abonnement =
    'lib/features/admin_groupe/providers/admin_subscription_provider.dart';

String _lire(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) fail('Fichier introuvable : $chemin — sonde aveugle.');
  return f.readAsStringSync().replaceAll('\r\n', '\n');
}

String _sansCommentaires(String source) => source
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

/// Position de la première attente groupée. -1 si le provider est redevenu
/// séquentiel.
int _premiereVague(String src) => src.indexOf('await Future.wait(');

void main() {
  group('Les trois écrans les plus ouverts lancent leurs lectures ensemble',
      () {
    for (final (nom, chemin) in [
      ('tableau de bord du groupe', _tableauGroupe),
      ('tableau de bord du fondateur', _tableauFondateur),
      ('abonnement du groupe', _abonnement),
    ]) {
      test('$nom : les lectures ne repartent pas en file', () {
        final src = _sansCommentaires(_lire(chemin));
        expect(_premiereVague(src), greaterThan(-1),
            reason: 'Plus aucune attente groupée : les lectures se sont '
                'remises en file, et la page a retrouvé ses secondes.');
      });
    }

    test('le tableau de bord du groupe garde ses deux vagues', () {
      // Les élèves et le personnel se ventilent par département, et le
      // département vient de la lecture des écoles.
      final src = _sansCommentaires(_lire(_tableauGroupe));
      expect('await Future.wait('.allMatches(src).length, 2,
          reason: 'Une seule vague ferait lire un `schoolDept` vide aux '
              'élèves et au personnel : tout le monde en « Non précisé ».');
      final vague1 = src.indexOf('lireEcoles()');
      final vague2 = src.indexOf('lireEleves()');
      expect(vague1, greaterThan(-1));
      expect(vague2, greaterThan(-1));
      expect(vague1, lessThan(vague2),
          reason: 'Les écoles doivent être lues AVANT les élèves.');
    });

    test('l’abonnement attend les familles avant les formules', () {
      final src = _sansCommentaires(_lire(_abonnement));
      final familles = src.indexOf('lireFamilles()');
      final formules = src.indexOf('await lireFormules()');
      expect(familles, greaterThan(-1));
      expect(formules, greaterThan(-1));
      expect(familles, lessThan(formules),
          reason: 'Les formules lisent `catsByPlan`, que seules les familles '
              'remplissent : lancées ensemble, le comparatif serait vide.');
    });

    test('les trois compteurs de quota partent ensemble', () {
      final src = _sansCommentaires(_lire(_abonnement));
      expect(
          src.contains(
              'Future.wait([compterEcoles(), compterEleves(), compterPersonnel()])'),
          isTrue,
          reason: 'Trois allers-retours en file pour trois jauges affichées '
              'côte à côte.');
    });
  });

  group('⚠️ Ce qui dépend d’une lecture reste APRÈS l’attente', () {
    test('tableau de bord du fondateur : les trois agrégats suivent la vague',
        () {
      final src = _sansCommentaires(_lire(_tableauFondateur));
      final vague = _premiereVague(src);
      for (final calcul in [
        'final abonnementsByStatus =', // lit statusMap
        'final planList =', //             lit planMap
        'final deptList =', //             lit deptMap
      ]) {
        final i = src.indexOf(calcul);
        expect(i, greaterThan(-1), reason: '« $calcul » a disparu.');
        expect(i, greaterThan(vague),
            reason: 'Ce calcul lit une table remplie par une des lectures. '
                'Au-dessus de l’attente, il compte sur du vide — et rien ne '
                'le dit.');
      }
    });

    test('tableau de bord du groupe : la liste des écoles suit la vague', () {
      // `schools` agrège les effectifs par école : il lui faut les élèves, le
      // personnel ET les classes.
      final src = _sansCommentaires(_lire(_tableauGroupe));
      final i = src.indexOf('final schools = schoolRows.map');
      expect(i, greaterThan(-1));
      expect(i, greaterThan(_premiereVague(src)),
          reason: 'Remonté au-dessus, chaque école afficherait 0 élève, '
              '0 agent et 0 classe — proprement, et faux.');
    });

    test('chaque lecture garde son propre filet', () {
      // Une lecture sans `catch` propre ferait tomber toute la vague : un
      // `Future.wait` remonte la PREMIÈRE erreur et abandonne le reste.
      for (final chemin in [_tableauGroupe, _tableauFondateur, _abonnement]) {
        final src = _sansCommentaires(_lire(chemin));
        final fonctions = 'Future<void> lire'.allMatches(src).length +
            'Future<void> compter'.allMatches(src).length;
        final filets = '} catch (e) {'.allMatches(src).length;
        expect(filets, greaterThanOrEqualTo(fonctions),
            reason: '$chemin : ${fonctions - filets} lecture(s) sans `catch` '
                'propre. La première qui échoue emporterait toute la vague.');
      }
    });
  });
}
