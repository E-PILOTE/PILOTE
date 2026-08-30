import 'package:epilote/features/cartes/providers/cartes_filtres.dart';
import 'package:epilote/features/cartes/providers/cartes_provider.dart';
import 'package:epilote/features/students/widgets/scope_drilldown_panel.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  FILTRER LA CAMPAGNE DE CARTES
//
//  Le filtre ne sert pas à lire plus confortablement : il commande AUSSI
//  l'impression. Ce qu'il laisse passer est ce qui sortira sur la planche.
//  Une erreur ici ne produit donc pas un écran de travers, elle produit des
//  centaines de cartes qu'il faudra jeter.
//
//  ── ⚠️ LA FILIÈRE NE SE DÉDUIT PAS DU NIVEAU ──────────────────────────────
//  Une première version affirmait « au primaire et au collège la notion
//  n'existe pas ». C'est faux : le collège TECHNIQUE (CET, tutelle METP) est
//  organisé par métier dès le premier cycle et mène au CAP — le référentiel de
//  la plateforme porte `college_technique` au cycle `college`, et 12 des 37
//  écoles de la base sont sous tutelle METP.
//
//  Ces tests ne regardent donc JAMAIS le cycle pour décider d'une filière. Une
//  classe sans filière n'est pas une classe à compléter, non parce que « son
//  niveau n'en a pas », mais parce que toutes les voies n'en définissent pas.
// ════════════════════════════════════════════════════════════════════════════

CarteClasse c({
  String id = 'c1',
  String nom = '6ème A',
  String cycle = 'college',
  String? cycleCode = 'college',
  String? levelCode = '6eme',
  int levelOrder = 1,
  String? filiere,
  int eleves = 10,
  int avecPhoto = 10,
}) =>
    CarteClasse(
      classId: id,
      className: nom,
      cycleName: cycle,
      cycleCode: cycleCode,
      levelCode: levelCode,
      levelOrder: levelOrder,
      filiereLabel: filiere,
      eleves: eleves,
      avecPhoto: avecPhoto,
    );

void main() {
  group('Le filtre par état des photos', () {
    final classes = [
      c(id: 'a', eleves: 10, avecPhoto: 10),
      c(id: 'b', eleves: 10, avecPhoto: 4),
      c(id: 'v', eleves: 0, avecPhoto: 0),
    ];

    test('« Toutes » garde tout, sauf les classes vides', () {
      final r = filtrerClasses(classes, FiltreCartes.aucun);
      expect(r.map((x) => x.classId), ['a', 'b'],
          reason: 'Une classe sans élève n’a aucune carte à produire : la '
              'montrer allongerait la liste sans rien y ajouter.');
    });

    test('« Complètes » ne garde que celles où aucun visage ne manque', () {
      final r = filtrerClasses(
          classes, const FiltreCartes(photo: EtatPhoto.completes));
      expect(r.map((x) => x.classId), ['a']);
    });

    test('« Photos manquantes » est la liste du travail qui reste', () {
      final r = filtrerClasses(
          classes, const FiltreCartes(photo: EtatPhoto.incompletes));
      expect(r.map((x) => x.classId), ['b'],
          reason: 'Une classe où il manque UNE photo doit y figurer : c’est '
              'elle qu’il faut aller compléter.');
    });
  });

  group('Les critères se cumulent', () {
    final classes = [
      c(id: 'a', cycleCode: 'lycee', filiere: 'Comptabilité', avecPhoto: 10),
      c(id: 'b', cycleCode: 'lycee', filiere: 'Comptabilité', avecPhoto: 3),
      c(id: 'd', cycleCode: 'college', filiere: null, avecPhoto: 3),
    ];

    test('filière ET état des photos', () {
      final r = filtrerClasses(
        classes,
        const FiltreCartes(
            filiere: 'Comptabilité', photo: EtatPhoto.incompletes),
      );
      expect(r.map((x) => x.classId), ['b']);
    });

    test('cycle ET filière', () {
      final r = filtrerClasses(
        classes,
        const FiltreCartes(
            scope: ScopeSel(cycle: 'lycee'), filiere: 'Comptabilité'),
      );
      expect(r.map((x) => x.classId), ['a', 'b']);
    });

    test('un cycle qui ne contient pas la filière ne rend rien', () {
      final r = filtrerClasses(
        classes,
        const FiltreCartes(
            scope: ScopeSel(cycle: 'college'), filiere: 'Comptabilité'),
      );
      expect(r, isEmpty,
          reason: 'L’écran doit alors dire « aucune classe », pas retomber '
              'silencieusement sur toute l’école.');
    });
  });

  group('Les filières ne s’inventent pas', () {
    test('une école sans aucune filière n’affiche PAS la section', () {
      final r = bilansFilieres([c(id: 'a'), c(id: 'b', nom: '5ème A')]);
      expect(r, isEmpty,
          reason: 'Une rangée vide laisserait croire à une donnée à remplir. '
              '⚠️ Le déclencheur est « aucune classe n’en porte », JAMAIS le '
              'niveau : un CET a des filières au collège.');
    });

    test('dès qu’UNE classe porte une filière, le reste devient « Sans '
        'filière »', () {
      final r = bilansFilieres([
        c(id: 'a', filiere: 'Électrotechnique', eleves: 20, avecPhoto: 20),
        c(id: 'b', filiere: null, eleves: 30, avecPhoto: 10),
      ]);
      expect(r.length, 2);
      expect(r.first.libelle, 'Électrotechnique');
      expect(r.last.libelle, isNull,
          reason: '« Sans filière » ferme la marche : c’est un reste, pas une '
              'filière.');
    });

    test('les filières se classent par effectif décroissant', () {
      final r = bilansFilieres([
        c(id: 'a', filiere: 'Petite', eleves: 5),
        c(id: 'b', filiere: 'Grande', eleves: 50),
      ]);
      expect(r.map((x) => x.libelle), ['Grande', 'Petite']);
    });

    test('le bilan d’une filière additionne ses classes', () {
      final r = bilansFilieres([
        c(id: 'a', filiere: 'Compta', eleves: 20, avecPhoto: 20),
        c(id: 'b', filiere: 'Compta', eleves: 10, avecPhoto: 4),
      ]);
      expect(r.single.classes, 2);
      expect(r.single.eleves, 30);
      expect(r.single.avecPhoto, 24);
      expect(r.single.sansPhoto, 6);
      expect(r.single.complet, isFalse);
    });

    test('une classe vide ne compte dans aucune filière', () {
      final r = bilansFilieres([
        c(id: 'a', filiere: 'Compta', eleves: 20, avecPhoto: 20),
        c(id: 'v', filiere: 'Compta', eleves: 0, avecPhoto: 0),
      ]);
      expect(r.single.classes, 1);
    });
  });

  group('⚠️ Le collège TECHNIQUE a des filières (CET, tutelle METP)', () {
    // Le premier cycle technique s'entre après le CEPE, dure quatre ans et
    // mène au CAP. Il est organisé PAR MÉTIER — ce n'est pas un lycée en
    // réduction, c'est là que se forment menuisiers, maçons et électriciens.
    final cet = [
      c(id: 'm', cycleCode: 'college', levelCode: '1ere_annee',
          nom: '1ère année Menuiserie', filiere: 'Menuiserie',
          eleves: 24, avecPhoto: 24),
      c(id: 'x', cycleCode: 'college', levelCode: '1ere_annee',
          nom: '1ère année Maçonnerie', filiere: 'Maçonnerie',
          eleves: 18, avecPhoto: 5),
    ];

    test('leurs filières sont comptées comme les autres', () {
      final r = bilansFilieres(cet);
      expect(r.map((x) => x.libelle), ['Menuiserie', 'Maçonnerie'],
          reason: 'Rien dans le calcul ne doit regarder le cycle. Un CET dont '
              'les filières disparaîtraient de l’écran ne pourrait plus '
              'organiser sa campagne de cartes atelier par atelier.');
      expect(r.first.complet, isTrue);
      expect(r.last.sansPhoto, 13);
    });

    test('on peut filtrer un collège sur sa filière', () {
      final r = filtrerClasses(
        cet,
        const FiltreCartes(
            scope: ScopeSel(cycle: 'college'), filiere: 'Menuiserie'),
      );
      expect(r.map((x) => x.classId), ['m'],
          reason: 'Cycle « college » ET filière « Menuiserie » doivent pouvoir '
              'coexister : c’est la définition même d’un CET.');
    });

    test('la section des filières s’affiche pour un CET', () {
      expect(bilansFilieres(cet), isNotEmpty,
          reason: 'La croyance corrigée le 2026-08-30 : « au collège la notion '
              'n’existe pas ». Si ce test échoue, elle est revenue.');
    });
  });

  group('Les unités du panneau de répartition', () {
    test('une unité par élève, marquée selon sa photo', () {
      final u = unitesDepuisClasses([c(eleves: 5, avecPhoto: 2)]);
      expect(u.length, 5);
      expect(u.where((x) => x.ok).length, 2);
      expect(u.where((x) => !x.ok).length, 3);
    });

    test('chaque unité porte la hiérarchie de sa classe', () {
      final u = unitesDepuisClasses([
        c(cycleCode: 'lycee', levelCode: '2nde', levelOrder: 4, nom: '2nde C'),
      ]);
      expect(u.first.cycleCode, 'lycee');
      expect(u.first.levelCode, '2nde');
      expect(u.first.levelOrder, 4);
      expect(u.first.className, '2nde C');
    });

    test('une classe vide ne produit aucune unité', () {
      expect(unitesDepuisClasses([c(eleves: 0, avecPhoto: 0)]), isEmpty);
    });

    test('les totaux se recomposent sur plusieurs classes', () {
      final u = unitesDepuisClasses([
        c(id: 'a', eleves: 30, avecPhoto: 30),
        c(id: 'b', eleves: 12, avecPhoto: 0),
      ]);
      expect(u.length, 42);
      expect(u.where((x) => x.ok).length, 30);
    });
  });

  group('Le même clic ferme ce qu’il a ouvert', () {
    test('choisir « null » remet toutes les filières', () {
      const f = FiltreCartes(filiere: 'Compta');
      expect(f.avecFiliere(null).filiere, isNull);
    });

    test('le filtre se sait actif dès qu’un seul critère l’est', () {
      expect(FiltreCartes.aucun.actif, isFalse);
      expect(const FiltreCartes(filiere: 'x').actif, isTrue);
      expect(const FiltreCartes(photo: EtatPhoto.completes).actif, isTrue);
      expect(const FiltreCartes(scope: ScopeSel(cycle: 'lycee')).actif, isTrue);
    });

    test('changer un critère préserve les autres', () {
      const f = FiltreCartes(
          filiere: 'Compta', photo: EtatPhoto.incompletes);
      final g = f.avecScope(const ScopeSel(cycle: 'lycee'));
      expect(g.filiere, 'Compta');
      expect(g.photo, EtatPhoto.incompletes);
      expect(g.scope.cycle, 'lycee');
    });
  });
}
