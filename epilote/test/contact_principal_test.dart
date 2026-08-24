// LE NUMÉRO QUE L'ÉCOLE COMPOSE EN PREMIER.
//
// La case « Contact principal » posait `draft.isPrimary = v` sans regarder les
// fiches voisines. Trois conséquences, toutes silencieuses :
//  • on pouvait marquer les quatre tuteurs comme principaux — `primaryTutorProvider`
//    fait `LIMIT 1` et en désignait alors un au hasard de l'ordre SQL ;
//  • on pouvait DÉCOCHER le seul qu'il y avait, et l'élève se retrouvait sans
//    contact principal du tout ;
//  • rien à l'écran ne le signalait.
//
// Le geste correct n'est pas de cocher, c'est de DÉPLACER. La règle vit donc
// hors du widget, dans `widgets/tuteur_edit_card.dart`, et se vérifie ici.
//
// Le défaut avait été corrigé dans l'éditeur du guichet et JAMAIS reporté dans
// celui du registre — l'écran où le secrétariat modifie les tuteurs tous les
// jours. Les deux partagent désormais cette fonction ; ce test la tient.

import 'package:epilote/features/students/widgets/tuteur_edit_card.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Promouvoir un contact principal', () {
    late List<TuteurBrouillon> tuteurs;

    setUp(() {
      tuteurs = [
        TuteurBrouillon(firstName: 'Marie', lastName: 'NGOMA', isPrimary: true),
        TuteurBrouillon(firstName: 'Paul', lastName: 'NGOMA'),
        TuteurBrouillon(firstName: 'Alice', lastName: 'BOKO'),
      ];
    });

    tearDown(() {
      for (final t in tuteurs) {
        t.dispose();
      }
    });

    test('la fiche promue devient principale', () {
      promouvoirContactPrincipal(tuteurs, tuteurs[1]);
      expect(tuteurs[1].isPrimary, isTrue);
    });

    test('les autres perdent le titre — il n\'y en a jamais deux', () {
      promouvoirContactPrincipal(tuteurs, tuteurs[1]);
      expect(tuteurs.where((t) => t.isPrimary), hasLength(1));
      expect(tuteurs[0].isPrimary, isFalse);
      expect(tuteurs[2].isPrimary, isFalse);
    });

    test('promouvoir la fiche DÉJÀ principale ne la déchoit pas', () {
      // C'est le cas qui perdait le numéro : un clic sur la case cochée la
      // décochait, et l'élève n'avait plus aucun contact principal.
      promouvoirContactPrincipal(tuteurs, tuteurs[0]);
      expect(tuteurs[0].isPrimary, isTrue);
      expect(tuteurs.where((t) => t.isPrimary), hasLength(1));
    });

    test('promouvoir deux fois de suite laisse un seul principal', () {
      promouvoirContactPrincipal(tuteurs, tuteurs[1]);
      promouvoirContactPrincipal(tuteurs, tuteurs[2]);
      expect(tuteurs.where((t) => t.isPrimary), hasLength(1));
      expect(tuteurs[2].isPrimary, isTrue);
    });

    test('une liste d\'un seul tuteur garde son principal', () {
      final seul = [TuteurBrouillon(firstName: 'Marie', isPrimary: true)];
      promouvoirContactPrincipal(seul, seul.first);
      expect(seul.first.isPrimary, isTrue);
      seul.first.dispose();
    });

    test('deux fiches homonymes ne se confondent pas', () {
      // La désignation se fait par IDENTITÉ D'OBJET, pas par contenu : deux
      // frères peuvent avoir le même tuteur saisi deux fois par erreur, et
      // promouvoir l'un ne doit pas promouvoir l'autre.
      final jumelles = [
        TuteurBrouillon(firstName: 'Marie', lastName: 'NGOMA'),
        TuteurBrouillon(firstName: 'Marie', lastName: 'NGOMA'),
      ];
      promouvoirContactPrincipal(jumelles, jumelles[1]);
      expect(jumelles[0].isPrimary, isFalse);
      expect(jumelles[1].isPrimary, isTrue);
      for (final t in jumelles) {
        t.dispose();
      }
    });
  });

  group('Le brouillon rend ce que la garde d\'écriture attend', () {
    test('`saisi` porte l\'identifiant, le nom, le prénom et le téléphone', () {
      final t = TuteurBrouillon(
        id: 'tut-1',
        firstName: 'Marie',
        lastName: 'NGOMA',
        phone: '06 000 00 00',
      );
      expect(t.saisi.id, 'tut-1');
      expect(t.saisi.prenom, 'Marie');
      expect(t.saisi.nom, 'NGOMA');
      expect(t.saisi.tel, '06 000 00 00');
      t.dispose();
    });

    test('une fiche neuve se reconnaît à son identifiant nul', () {
      final t = TuteurBrouillon();
      expect(t.saisi.id, isNull);
      t.dispose();
    });

    test('`saisi` suit la frappe en cours, pas l\'état initial', () {
      // La garde lit la saisie AU MOMENT de l'enregistrement : si elle lisait
      // une copie figée à l'ouverture, elle refuserait une fiche que l'agent
      // vient précisément de compléter.
      final t = TuteurBrouillon();
      t.firstName.text = 'Paul';
      expect(t.saisi.prenom, 'Paul');
      t.dispose();
    });
  });
}
