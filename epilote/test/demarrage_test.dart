// Le 2 octobre, mille écoles ouvrent l'application sur du vide. Ces tests
// gardent l'ordre des étapes — il n'est pas une préférence, c'est une chaîne de
// dépendances — et le fait que la carte s'efface quand elle a servi.

import 'package:epilote/features/structure/providers/demarrage_provider.dart';
import 'package:flutter_test/flutter_test.dart';

EtapeDemarrage _etape(String titre,
        {bool faite = false, int compte = 0, bool reseau = false}) =>
    EtapeDemarrage(
      titre: titre,
      faite: faite,
      compte: compte,
      route: '/user/x',
      pourquoi: 'parce que',
      bloque: 'sinon rien',
      parLeReseau: reseau,
    );

void main() {
  group('Avancement', () {
    test('un établissement neuf n\'a rien de fait', () {
      final d = Demarrage([
        _etape('Année'), _etape('Structure'), _etape('Classes'),
      ]);
      expect(d.faites, 0);
      expect(d.avancement, 0);
      expect(d.termine, isFalse);
    });

    test('la carte s\'efface quand tout est fait', () {
      // Une liste de démarrage permanente devient du mobilier : on ne la lit
      // plus, et le tableau de bord qui la porte non plus.
      final d = Demarrage([
        _etape('Année', faite: true),
        _etape('Structure', faite: true),
      ]);
      expect(d.termine, isTrue);
      expect(d.prochaine, isNull);
      expect(d.avancement, 1.0);
    });

    test('un état vide ne s\'affiche pas non plus', () {
      // Pas d'école rattachée : on ne montre pas une carte à zéro sur zéro.
      expect(Demarrage.vide.total, 0);
      expect(Demarrage.vide.termine, isFalse);
      expect(Demarrage.vide.avancement, 0);
    });
  });

  group('La prochaine étape', () {
    test('est la PREMIÈRE non faite, jamais une autre', () {
      // L'ordre est une chaîne de dépendances : proposer « inscrire les
      // élèves » alors qu'aucune classe n'existe envoie sur un écran où rien
      // n'est possible.
      final d = Demarrage([
        _etape('Année', faite: true),
        _etape('Structure', faite: true),
        _etape('Classes'),
        _etape('Personnel'),
        _etape('Élèves'),
      ]);
      expect(d.prochaine?.titre, 'Classes');
    });

    test('une étape faite plus loin ne fait pas sauter les précédentes', () {
      // Cas réel : le réseau a livré la structure, mais l'année n'est pas
      // ouverte. Rien ne fonctionnera tant que l'année manque.
      final d = Demarrage([
        _etape('Année'),
        _etape('Structure', faite: true, compte: 6),
        _etape('Classes', faite: true, compte: 8),
      ]);
      expect(d.prochaine?.titre, 'Année');
      expect(d.faites, 2);
    });
  });

  group('Ce que l\'établissement ne peut pas faire lui-même', () {
    test('les étapes du réseau sont marquées comme telles', () {
      // L'année et la structure sont posées par l'administration du réseau.
      // Afficher « Commencer » enverrait chercher un bouton qui n'existe pas.
      final e = _etape('Structure', reseau: true);
      expect(e.parLeReseau, isTrue);
      expect(_etape('Classes').parLeReseau, isFalse);
    });

    test('chaque étape dit ce que son absence bloque', () {
      // C'est cela qui fait agir, pas une case vide.
      final d = Demarrage([_etape('Classes')]);
      expect(d.etapes.single.bloque.trim(), isNotEmpty);
      expect(d.etapes.single.pourquoi.trim(), isNotEmpty);
    });
  });
}
