import 'package:flutter_test/flutter_test.dart';

import 'package:epilote/core/utils/write_identity.dart';

// ════════════════════════════════════════════════════════════════════════════
//  IDENTITÉ D'ÉCRITURE — le garde-fou contre la perte silencieuse.
//
//  En base, `group_id`, `school_id`, `recorded_by`… sont des colonnes `uuid`
//  NOT NULL. Le SQLite local, lui, n'impose RIEN : une chaîne vide s'y écrit
//  sans broncher. C'est au moment de la remontée que le serveur refuse
//  (`22P02 invalid input syntax for type uuid`) — et un refus abandonne le LOT
//  PowerSync ENTIER, silencieusement. Le travail d'une matinée disparaît sans
//  message.
//
//  D'où ces tests : `''` doit être traité comme une ABSENCE, jamais comme une
//  valeur. C'est exactement ce que `?? ''` faisait croire au reste du code.
// ════════════════════════════════════════════════════════════════════════════

void main() {
  group('isUsableId', () {
    test('un identifiant renseigné est utilisable', () {
      expect(isUsableId('a3f1c2e0-1111-2222-3333-444455556666'), isTrue);
    });

    test('null n\'est pas utilisable', () {
      expect(isUsableId(null), isFalse);
    });

    // Le cœur du bug : `p?.groupId ?? ''` produit exactement ceci.
    test('la chaîne vide n\'est PAS un identifiant', () {
      expect(isUsableId(''), isFalse);
    });

    test('des espaces ne sont pas un identifiant', () {
      expect(isUsableId('   '), isFalse);
    });
  });

  group('buildWriteIdentity', () {
    test('identité complète', () {
      final id = buildWriteIdentity(
        groupId: 'g1',
        schoolId: 'e1',
        actorId: 'a1',
      );
      expect(id, isNotNull);
      expect(id!.groupId, 'g1');
      expect(id.schoolId, 'e1');
      expect(id.actorId, 'a1');
    });

    test('un identifiant vide rend l\'identité inutilisable', () {
      expect(
        buildWriteIdentity(groupId: '', schoolId: 'e1', actorId: 'a1'),
        isNull,
      );
    });

    test('un identifiant nul rend l\'identité inutilisable', () {
      expect(
        buildWriteIdentity(groupId: 'g1', schoolId: null, actorId: 'a1'),
        isNull,
      );
    });

    test('les espaces sont retirés des identifiants conservés', () {
      final id = buildWriteIdentity(
        groupId: ' g1 ',
        schoolId: 'e1',
        actorId: 'a1',
      );
      expect(id!.groupId, 'g1');
    });
  });

  group('missingWriteIds — dire CE QUI manque, pas « erreur »', () {
    test('liste les identifiants absents, nommés en clair', () {
      final missing =
          missingWriteIds(groupId: '', schoolId: 'e1', actorId: null);
      expect(missing, containsAll(<String>['groupe', 'agent']));
      expect(missing, isNot(contains('école')));
    });

    test('rien ne manque quand tout est renseigné', () {
      expect(
        missingWriteIds(groupId: 'g1', schoolId: 'e1', actorId: 'a1'),
        isEmpty,
      );
    });
  });
}
