import 'package:epilote/features/admin_groupe/providers/admin_fees_provider.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  PAS DE MENSUALITÉ DANS LE PUBLIC (migration 0100)
//
//  Le 2026-08-12, une mensualité RÉSEAU de 21 000 F a été publiée dans un
//  groupe `public` de 12 écoles et 1 775 élèves. L'écran ne l'a ni refusée ni
//  signalée. Or la loi 25-95 (art. 1) pose que l'enseignement public est
//  gratuit : la mensualité y est illégale.
//
//  Le serveur la refuse désormais. Ces tests couvrent l'autre moitié du verrou :
//  le choix ne doit même pas être PROPOSÉ — « l'absence de bouton est la vraie
//  protection, la règle serveur n'est que le filet ».
// ════════════════════════════════════════════════════════════════════════════

void main() {
  group('types de frais proposables', () {
    test('dans le PRIVÉ, les cinq types restent proposés', () {
      final t = typesDeFraisProposables(groupePublic: false);
      expect(t.keys, containsAll(kAdminFeeTypes.keys));
      expect(t.containsKey('mensualite'), isTrue);
    });

    test('dans le PUBLIC, la mensualité disparaît du choix', () {
      final t = typesDeFraisProposables(groupePublic: true);
      expect(t.containsKey('mensualite'), isFalse);
    });

    test('dans le PUBLIC, tout le reste demeure', () {
      final t = typesDeFraisProposables(groupePublic: true);
      // L'inscription est payante en public depuis ~2022, les frais d'examen
      // sont un tarif d'État, la cotisation APE n'est pas une mensualité.
      expect(t.keys,
          containsAll(['inscription', 'frais_examens', 'cotisation_ape', 'autre']));
      expect(t.length, kAdminFeeTypes.length - 1);
    });

    test('secteur INCONNU : on ne présume rien, le serveur tranchera', () {
      // Interdire pendant le chargement punirait un groupe privé légitime ;
      // le trigger refuse de toute façon, avec un message explicite.
      final t = typesDeFraisProposables(groupePublic: null);
      expect(t.containsKey('mensualite'), isTrue);
    });

    test(
        'une mensualité HÉRITÉE reste dans la liste — sinon on ne peut plus la '
        'retirer', () {
      // Un groupe basculé en public, ou une ligne publiée avant le verrou :
      // la boîte doit pouvoir s'ouvrir sur elle. Un DropdownButtonFormField
      // dont la `value` est absente des `items` lève une assertion, et sans
      // cette réintroduction l'écran virerait au rouge à l'ouverture.
      final t = typesDeFraisProposables(
          groupePublic: true, typeActuel: 'mensualite');
      expect(t.containsKey('mensualite'), isTrue);
      expect(t.length, kAdminFeeTypes.length);
    });

    test('un autre type courant ne réintroduit pas la mensualité', () {
      final t = typesDeFraisProposables(
          groupePublic: true, typeActuel: 'inscription');
      expect(t.containsKey('mensualite'), isFalse);
    });

    test('les libellés ne sont pas réécrits au passage', () {
      final t = typesDeFraisProposables(groupePublic: true);
      for (final e in t.entries) {
        expect(e.value, kAdminFeeTypes[e.key]);
      }
    });
  });
}
