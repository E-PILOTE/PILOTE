import 'package:flutter_test/flutter_test.dart';

import 'package:epilote/features/user/services/rapport_effectifs.dart';

// ════════════════════════════════════════════════════════════════════════════
//  UN ÉTAT DES EFFECTIFS EST UNE DÉCLARATION, PAS UN AFFICHAGE
//
//  Ce comptage sort sur du papier à en-tête, signé par un chef d'établissement
//  et transmis à une direction départementale. L'effectif déclaré décide de
//  dotations. Un élève écarté en silence n'est donc pas un défaut d'affichage :
//  c'est une sous-déclaration que personne ne peut détecter en lisant l'état.
//
//  Ces tests portent d'abord sur les cas où un élève RISQUE de disparaître.
// ════════════════════════════════════════════════════════════════════════════

EleveCompte _e({
  String? classId = 'c1',
  String? className = '6e A',
  String? cycleCode = 'COLLEGE',
  int levelOrder = 10,
  String? statut = kStatutInscrit,
  String? sexe = 'M',
  bool interne = false,
  bool boursier = false,
}) =>
    (
      classId: classId,
      className: className,
      cycleCode: cycleCode,
      levelOrder: levelOrder,
      statut: statut,
      sexe: sexe,
      interne: interne,
      boursier: boursier,
    );

void main() {
  group('qui compte, et qui ne compte pas', () {
    test('une inscription active compte', () {
      final l = effectifsParClasse([_e()]);
      expect(l.single.total, 1);
    });

    test('un élève retiré ne gonfle pas l\'effectif déclaré', () {
      final l = effectifsParClasse([_e(), _e(statut: 'withdrawn')]);
      expect(l.single.total, 1);
    });

    test('ni un dossier en attente de validation', () {
      expect(effectifsParClasse([_e(statut: 'pending_validation')]), isEmpty);
    });

    test('ni un transféré, ni un diplômé, ni un statut nul', () {
      final l = effectifsParClasse([
        _e(),
        _e(statut: 'transferred'),
        _e(statut: 'graduated'),
        _e(statut: null),
      ]);
      expect(l.single.total, 1);
    });
  });

  group('personne ne disparaît de l\'état', () {
    test('un élève actif SANS classe obtient sa propre ligne', () {
      // ⚠️ Le cas qui sous-déclare : l'écarter ferait un état dont le total
      // est inférieur au nombre d'élèves réellement inscrits, sans que rien
      // ne le signale sur le papier.
      final l = effectifsParClasse([_e(), _e(classId: null, className: null)]);
      expect(l.length, 2);
      expect(l.map((x) => x.className), contains(kSansClasse));
      expect(cumul('Total', l).total, 2);
    });

    test('une chaîne vide vaut « sans classe »', () {
      final l = effectifsParClasse([_e(classId: '  ')]);
      expect(l.single.className, kSansClasse);
    });

    test('la ligne sans classe se range en FIN d\'état', () {
      // La première ligne d'un état officiel doit être la plus petite classe,
      // pas une anomalie de données.
      final l = effectifsParClasse([
        _e(classId: null, className: null),
        _e(classId: 'c9', className: 'Tle', levelOrder: 90),
        _e(classId: 'c1', className: '6e A', levelOrder: 10),
      ]);
      expect(l.map((x) => x.className), ['6e A', 'Tle', kSansClasse]);
    });

    test('une classe sans cycle forme son bloc au lieu d\'être écartée', () {
      final lignes = effectifsParClasse([
        _e(),
        _e(classId: 'cx', className: 'Atelier', cycleCode: null, levelOrder: 20),
      ]);
      final blocs = blocsParCycle(lignes);
      expect(blocs.map((b) => b.cycle), ['COLLEGE', kCycleNonRattache]);
      expect(blocs.fold(0, (a, b) => a + b.total.total), 2);
    });
  });

  group('le sexe non renseigné n\'est pas un garçon', () {
    test('il se compte à part', () {
      // ⚠️ Le ranger d'office chez les garçons donnerait un état où
      // filles + garçons = total : invérifiable, donc incontestable, et faux.
      final l = effectifsParClasse([
        _e(sexe: 'F'),
        _e(sexe: 'M'),
        _e(sexe: null),
        _e(sexe: ''),
      ]).single;
      expect(l.total, 4);
      expect(l.filles, 1);
      expect(l.garcons, 1);
      expect(l.sexeInconnu, 2);
      expect(l.filles + l.garcons + l.sexeInconnu, l.total);
    });

    test('la part de filles se calcule sur le TOTAL, pas sur les sexes connus',
        () {
      final l = effectifsParClasse([_e(sexe: 'F'), _e(sexe: null)]).single;
      expect(partFilles(l), 50, reason: '1 fille sur 2 inscrits');
    });

    test('une classe vide n\'affiche pas « 0 % de filles »', () {
      expect(partFilles(cumul('Total', const [])), isNull);
    });
  });

  group('le regroupement par classe', () {
    test('deux élèves de la même classe font une seule ligne', () {
      final l = effectifsParClasse([_e(), _e(sexe: 'F')]);
      expect(l.length, 1);
      expect(l.single.total, 2);
    });

    test('internes et boursiers se comptent sans s\'exclure', () {
      // Un interne boursier compte dans les deux colonnes : ce sont deux faits
      // distincts, pas deux catégories d'élèves.
      final l = effectifsParClasse([
        _e(interne: true, boursier: true),
        _e(interne: true),
        _e(),
      ]).single;
      expect(l.total, 3);
      expect(l.internes, 2);
      expect(l.boursiers, 1);
    });

    test('les classes se lisent du plus petit niveau au plus grand', () {
      final l = effectifsParClasse([
        _e(classId: 'c3', className: '4e', levelOrder: 30),
        _e(classId: 'c1', className: '6e', levelOrder: 10),
        _e(classId: 'c2', className: '5e', levelOrder: 20),
      ]);
      expect(l.map((x) => x.className), ['6e', '5e', '4e']);
    });

    test('à niveau égal, l\'ordre est alphabétique', () {
      final l = effectifsParClasse([
        _e(classId: 'b', className: '6e B'),
        _e(classId: 'a', className: '6e A'),
      ]);
      expect(l.map((x) => x.className), ['6e A', '6e B']);
    });
  });

  group('les cumuls', () {
    test('le sous-total d\'un cycle égale la somme de ses classes', () {
      final lignes = effectifsParClasse([
        _e(classId: 'a', className: '6e A', sexe: 'F'),
        _e(classId: 'a', className: '6e A', sexe: 'M', interne: true),
        _e(classId: 'b', className: '5e B', sexe: 'F', boursier: true),
      ]);
      final bloc = blocsParCycle(lignes).single;
      expect(bloc.total.total, 3);
      expect(bloc.total.filles, 2);
      expect(bloc.total.internes, 1);
      expect(bloc.total.boursiers, 1);
    });

    test('le total général égale la somme des cycles', () {
      final lignes = effectifsParClasse([
        _e(cycleCode: 'PRIMAIRE', levelOrder: 5),
        _e(classId: 'c2', className: '6e', cycleCode: 'COLLEGE'),
        _e(classId: 'c3', className: 'Tle', cycleCode: 'LYCEE', levelOrder: 90),
      ]);
      final blocs = blocsParCycle(lignes);
      final general = cumul('TOTAL ÉCOLE', lignes);
      expect(blocs.length, 3);
      expect(blocs.fold(0, (a, b) => a + b.total.total), general.total);
    });

    test('un cumul vide rend des zéros, pas une erreur', () {
      final z = cumul('TOTAL ÉCOLE', const []);
      expect(z.total, 0);
      expect(z.filles, 0);
      expect(z.className, 'TOTAL ÉCOLE');
    });

    test('les cycles se suivent dans l\'ordre de la scolarité', () {
      // L'ordre vient de la plus petite classe de chaque cycle, pas de l'ordre
      // d'arrivée des lignes.
      final lignes = effectifsParClasse([
        _e(classId: 'c3', className: 'Tle', cycleCode: 'LYCEE', levelOrder: 90),
        _e(classId: 'c1', className: 'CP', cycleCode: 'PRIMAIRE', levelOrder: 5),
        _e(classId: 'c2', className: '6e', cycleCode: 'COLLEGE', levelOrder: 10),
      ]);
      expect(blocsParCycle(lignes).map((b) => b.cycle),
          ['PRIMAIRE', 'COLLEGE', 'LYCEE']);
    });
  });
}
