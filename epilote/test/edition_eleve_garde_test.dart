import 'package:flutter_test/flutter_test.dart';

import 'package:epilote/features/students/services/edition_eleve_garde.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LES GARDES DE L'ÉDITION D'UN DOSSIER
//
//  Trois de ces quatre règles existent parce qu'un dégât s'est produit en
//  production, et jusqu'ici aucune n'était vérifiable autrement qu'en rejouant
//  l'écran à la main. Elles décident si une saisie part en base — et, quand
//  elle ne part pas, sur quelle page renvoyer l'agent.
// ════════════════════════════════════════════════════════════════════════════

TuteurSaisi _t({
  String? id,
  String prenom = 'Marie',
  String nom = 'NKOUNKOU',
  String tel = '066112233',
}) =>
    (id: id, prenom: prenom, nom: nom, tel: tel);

const _groupe = '11111111-1111-1111-1111-111111111111';
const _ecole  = '22222222-2222-2222-2222-222222222222';

RefusEdition? _refus({
  String prenom = 'Aristide',
  String nom = 'NGOMA',
  String? classId = 'c1',
  List<TuteurSaisi> tuteurs = const [],
  String? groupId = _groupe,
  String? schoolId = _ecole,
}) =>
    refusEdition(
      prenom: prenom,
      nom: nom,
      classId: classId,
      tuteurs: tuteurs,
      groupId: groupId,
      schoolId: schoolId,
    );

void main() {
  group('rien ne s\'oppose', () {
    test('une saisie complète passe', () {
      expect(_refus(tuteurs: [_t(id: 'existant'), _t()]), isNull);
    });

    test('sans aucun tuteur, on peut quand même corriger', () {
      expect(_refus(), isNull);
    });

    test('une fiche neuve entièrement VIDE est ignorée, pas refusée', () {
      // C'est la ligne que l'agent a ouverte puis n'a pas remplie. La refuser
      // l'obligerait à la supprimer pour enregistrer une correction d'adresse.
      expect(_refus(tuteurs: [_t(prenom: '', nom: '', tel: '')]), isNull);
    });

    test('des espaces ne font pas une fiche entamée', () {
      expect(_refus(tuteurs: [_t(prenom: '  ', nom: ' ', tel: '   ')]), isNull);
    });
  });

  group('l\'identité de l\'élève', () {
    test('le prénom manquant renvoie à la page Élève', () {
      final r = _refus(prenom: '');
      expect(r?.etape, kEtapeEleve);
      expect(r?.message, contains('prénom'));
    });

    test('le nom manquant aussi', () {
      expect(_refus(nom: '   ')?.etape, kEtapeEleve);
    });
  });

  group('la classe', () {
    test('non choisie, elle renvoie à la page Scolarité', () {
      final r = _refus(classId: null);
      expect(r?.etape, kEtapeScolarite);
      expect(r?.message, contains('classe'));
    });

    test('une chaîne vide vaut « non choisie »', () {
      // `class_id` est NOT NULL en base : une chaîne vide serait refusée par le
      // serveur, donc perdue avec tout le lot PowerSync.
      expect(_refus(classId: '')?.etape, kEtapeScolarite);
    });
  });

  group('le group_id, et seulement quand il sert', () {
    test('un tuteur NEUF sans group_id est refusé', () {
      // Le dégât : `?? ''` écrivait une chaîne vide dans une colonne `uuid`
      // NOT NULL. SQLite l'acceptait, l'écran affichait « enregistré », puis le
      // serveur répondait 22P02 et PowerSync abandonnait le LOT ENTIER —
      // emportant l'élève et son inscription modifiés juste avant.
      final r = _refus(tuteurs: [_t()], groupId: null);
      expect(r, isNotNull);
      expect(r?.etape, kEtapeAucune,
          reason: 'aucune page ne corrige un identifiant d\'appareil');
    });

    test('une chaîne vide n\'est pas un identifiant', () {
      expect(_refus(tuteurs: [_t()], groupId: '  '), isNotNull);
    });

    test('sans ÉCOLE, un tuteur neuf est refusé', () {
      // `student_tutors.school_id` est NOT NULL depuis la migration 0110 :
      // c'est par lui que les coordonnées des familles descendent, par école.
      // Une chaîne vide y lève `22P02` et fait abandonner le lot entier.
      final r = _refus(tuteurs: [_t()], schoolId: null);
      expect(r, isNotNull);
      expect(r?.etape, kEtapeAucune);
      expect(r?.message, contains('école'));
    });

    test('le message NOMME les deux rattachements manquants', () {
      final r = _refus(tuteurs: [_t()], groupId: null, schoolId: null);
      expect(r?.message, contains('groupe'));
      expect(r?.message, contains('école'));
    });

    test('sans école mais sans tuteur NEUF, rien ne s\'oppose', () {
      // Corriger une adresse hors ligne ne doit pas se heurter à un
      // identifiant dont l'écriture n'a aucun besoin.
      expect(_refus(tuteurs: [_t(id: 'existant')], schoolId: null), isNull);
      expect(_refus(schoolId: null), isNull);
    });

    test('SANS tuteur neuf, l\'absence de group_id ne bloque rien', () {
      // ⚠️ La contrepartie qui compte : corriger une adresse hors ligne ne doit
      // pas se heurter à un identifiant dont la correction n'a aucun besoin.
      expect(_refus(tuteurs: [_t(id: 'existant')], groupId: null), isNull);
      expect(_refus(groupId: null), isNull);
    });

    test('une fiche neuve INCOMPLÈTE ne réclame pas le group_id', () {
      // Elle ne sera pas créée : c'est l'autre règle qui la traitera.
      final r = _refus(tuteurs: [_t(tel: '')], groupId: null);
      expect(r?.etape, kEtapeTuteurs, reason: 'incomplète, pas identifiant');
    });
  });

  group('les fiches de tuteur entamées mais incomplètes', () {
    test('une fiche sans téléphone est refusée', () {
      // Le dégât : elle était jetée en silence (`continue`). L'agent lisait
      // « enregistré » et repartait avec un dossier sans aucun contact
      // parental, dans une école où le tuteur est le seul canal joignable.
      final r = _refus(tuteurs: [_t(tel: '')]);
      expect(r?.etape, kEtapeTuteurs);
      expect(r?.message, contains('téléphone'));
    });

    test('le compte exact figure dans le message', () {
      final r = _refus(tuteurs: [_t(tel: ''), _t(nom: ''), _t()]);
      expect(r?.message, startsWith('2 fiche'));
    });

    test('une fiche EXISTANTE vidée n\'est pas contrôlée ici', () {
      // Elle est déjà en base ; l'effacer relève d'une suppression explicite,
      // pas d'un refus d'enregistrement qui bloquerait tout le reste.
      expect(_refus(tuteurs: [_t(id: 'existant', tel: '')]), isNull);
    });
  });

  group('l\'ordre des refus suit celui du formulaire', () {
    test('le nom manquant l\'emporte sur un tuteur incomplet', () {
      // Renvoyer l'agent aux tuteurs alors que le nom manque page 1 lui ferait
      // chercher au mauvais endroit.
      final r = _refus(nom: '', tuteurs: [_t(tel: '')]);
      expect(r?.etape, kEtapeEleve);
    });

    test('la classe l\'emporte sur un tuteur incomplet', () {
      final r = _refus(classId: null, tuteurs: [_t(tel: '')]);
      expect(r?.etape, kEtapeScolarite);
    });
  });

  testsGardeRegistre();
}

// ════════════════════════════════════════════════════════════════════════════
//  LA MÊME GARDE, AU REGISTRE
//
//  L'écran de modification de la page Élèves — celui que le secrétariat ouvre
//  le plus souvent, puisque c'est là que vivent les élèves une fois inscrits —
//  n'avait AUCUNE de ces règles. Il reproduisait donc, intacts, deux des trois
//  dégâts décrits en tête de `edition_eleve_garde.dart` : le `group_id` vide qui
//  fait perdre le lot de synchronisation, et la fiche de tuteur incomplète
//  jetée en silence.
//
//  Il n'a pas d'étape Scolarité : seul change le numéro de page où renvoyer
//  l'agent. Les règles, elles, sont les mêmes — et c'est ce que ce groupe
//  vérifie, faute de quoi les deux écrans redivergeraient.
// ════════════════════════════════════════════════════════════════════════════

RefusEdition? _refusRegistre({
  String prenom = 'Aristide',
  String nom = 'NGOMA',
  List<TuteurSaisi> tuteurs = const [],
  String? groupId = _groupe,
  String? schoolId = _ecole,
}) =>
    refusEditionRegistre(
      prenom: prenom,
      nom: nom,
      tuteurs: tuteurs,
      groupId: groupId,
      schoolId: schoolId,
    );

void testsGardeRegistre() {
  group('la garde du registre (page Élèves)', () {
    test('une saisie complète passe', () {
      expect(_refusRegistre(tuteurs: [_t(id: 'existant'), _t()]), isNull);
    });

    test('aucune classe n\'est exigée — cet écran n\'y touche pas', () {
      // Au guichet, `classId` manquant est un refus : `class_id` est NOT NULL.
      // Ici, la scolarité se change par « Changer de classe », pas en modifiant
      // une identité. Exiger une classe aurait rendu l'écran inutilisable.
      expect(_refusRegistre(), isNull);
    });

    test('le nom manquant renvoie à la page Identité (0)', () {
      final r = _refusRegistre(nom: '  ');
      expect(r?.etape, kEtapeRegistreEleve);
      expect(r?.message, contains('obligatoires'));
    });

    test('un tuteur NEUF sans group_id est refusé', () {
      // Le dégât : `?? ''` écrivait une chaîne vide dans une colonne `uuid`
      // NOT NULL. L'écran affichait « Modifications enregistrées », puis le
      // serveur répondait 22P02 et PowerSync abandonnait le LOT ENTIER —
      // emportant l'élève modifié juste avant, sans un message.
      final r = _refusRegistre(tuteurs: [_t()], groupId: null);
      expect(r, isNotNull);
      expect(r?.etape, kEtapeAucune,
          reason: 'aucune page ne corrige un identifiant d\'appareil manquant');
    });

    test('un group_id vide vaut un group_id absent', () {
      expect(_refusRegistre(tuteurs: [_t()], groupId: '   '), isNotNull);
    });

    test('sans tuteur NEUF, le group_id manquant ne bloque rien', () {
      // Corriger l'adresse d'un tuteur déjà en base est faisable hors ligne :
      // s'y opposer au nom d'un identifiant dont l'écriture n'a pas besoin
      // serait un refus gratuit.
      expect(_refusRegistre(tuteurs: [_t(id: 'existant')], groupId: null),
          isNull);
    });

    test('une fiche de tuteur entamée mais incomplète renvoie aux Tuteurs (1)', () {
      final r = _refusRegistre(tuteurs: [_t(tel: '')]);
      expect(r?.etape, kEtapeRegistreTuteurs);
      expect(r?.message, contains('incomplète'));
    });

    test('une fiche NEUVE entièrement vide est ignorée sans bruit', () {
      // L'assistant en pose une d'office : la laisser vide est un choix, pas
      // un oubli.
      expect(_refusRegistre(tuteurs: [_t(prenom: '', nom: '', tel: '')]),
          isNull);
    });

    test('une fiche EXISTANTE vidée n\'est pas contrôlée ici', () {
      // Elle est déjà en base ; la vider relève d'une suppression explicite.
      expect(_refusRegistre(tuteurs: [_t(id: 'existant', tel: '')]), isNull);
    });

    test('l\'identité passe AVANT les tuteurs', () {
      // On renvoie l'agent à la PREMIÈRE page fautive : le chercher aux
      // tuteurs alors que le nom manque à la page 1 lui ferait perdre son temps.
      final r = _refusRegistre(nom: '', tuteurs: [_t(tel: '')]);
      expect(r?.etape, kEtapeRegistreEleve);
    });

    test('les deux gardes refusent les mêmes tuteurs', () {
      // Verrou anti-divergence : c'est en laissant les deux écrans évoluer
      // séparément qu'un seul des deux avait été corrigé.
      final cas = <List<TuteurSaisi>>[
        [_t()],
        [_t(tel: '')],
        [_t(prenom: '', nom: '', tel: '')],
        [_t(id: 'existant', tel: '')],
      ];
      for (final tuteurs in cas) {
        expect(_refusRegistre(tuteurs: tuteurs) == null,
            _refus(tuteurs: tuteurs) == null,
            reason: 'divergence sur $tuteurs');
      }
    });

    test('les deux gardes exigent les mêmes identifiants', () {
      // Depuis 0110, `student_tutors.school_id` est NOT NULL : l'école
      // s'ajoute au groupe. Les deux écrans doivent l'exiger ensemble, sans
      // quoi l'un des deux réécrira la chaîne vide dans une colonne `uuid`.
      for (final (g, e) in <(String?, String?)>[
        (null, _ecole),
        (_groupe, null),
        (null, null),
        ('   ', _ecole),
        (_groupe, '   '),
      ]) {
        expect(
          _refusRegistre(tuteurs: [_t()], groupId: g, schoolId: e) == null,
          _refus(tuteurs: [_t()], groupId: g, schoolId: e) == null,
          reason: 'divergence sur (groupe: $g, école: $e)',
        );
      }
    });
  });
}
