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
//  ── LA FILIÈRE N'EST PAS UNE DONNÉE MANQUANTE ─────────────────────────────
//  `filiere_label` est nulle au primaire et au collège : la notion n'y existe
//  pas. Une classe sans filière n'est pas une classe « à compléter ». Tout ce
//  fichier tient cette distinction, parce que la confondre ferait reprocher à
//  une école primaire de ne pas avoir rempli un champ qui ne la concerne pas.
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
          reason: 'Au primaire et au collège la notion n’existe pas : une '
              'rangée vide laisserait croire à une donnée à remplir.');
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
