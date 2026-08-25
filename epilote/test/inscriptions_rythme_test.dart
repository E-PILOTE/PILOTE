import 'package:flutter_test/flutter_test.dart';

import 'package:epilote/features/students/providers/inscriptions_data_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE RYTHME DES INSCRIPTIONS NE DOIT PAS EFFACER LES MOIS CREUX
//
//  `GROUP BY mois` ne rend que les mois où quelque chose s'est passé. L'axe du
//  graphe étant CATÉGORIEL, un mois absent de la liste n'occupe aucune place :
//  septembre et novembre se retrouvaient collés, et la pause d'octobre — le
//  fait le plus intéressant d'une campagne d'inscription — devenait invisible.
//  Pire, la courbe de cumul reliait directement les deux, dessinant une montée
//  continue là où l'école n'avait rien inscrit pendant un mois.
//
//  Ces tests verrouillent les trois propriétés qui rendent le graphe honnête :
//  la suite des mois est continue, le cumul plafonne pendant les creux, et les
//  dossiers en attente sont comptés à part de l'effectif.
// ════════════════════════════════════════════════════════════════════════════

void main() {
  group('construireRythmeInscriptions', () {
    test('comble les mois sans inscription', () {
      final pts = construireRythmeInscriptions(
        {'2025-09': 40, '2025-11': 12},
        const {},
      );

      expect(pts.map((p) => p.label),
          ['sept. 25', 'oct. 25', 'nov. 25'],
          reason: 'octobre doit exister, à zéro');
      expect(pts.map((p) => p.count), [40, 0, 12]);
    });

    test('le cumul plafonne sur un mois creux au lieu de monter', () {
      final pts = construireRythmeInscriptions(
        {'2025-09': 40, '2025-11': 12},
        const {},
      );
      expect(pts.map((p) => p.cumul), [40, 40, 52]);
    });

    test('franchit le changement d\'année scolaire', () {
      final pts = construireRythmeInscriptions(
        {'2025-12': 3, '2026-02': 5},
        const {},
      );
      expect(pts.map((p) => p.label), ['déc. 25', 'janv. 26', 'févr. 26']);
      expect(pts.map((p) => p.cumul), [3, 3, 8]);
    });

    test('les dossiers en attente comptent à part du cumul', () {
      final pts = construireRythmeInscriptions(
        {'2025-09': 10},
        {'2025-09': 4, '2025-10': 7},
      );

      // Octobre n'a AUCUNE validation mais sept dossiers déposés : il doit
      // exister, avec une colonne haute et un cumul inchangé.
      expect(pts.map((p) => p.label), ['sept. 25', 'oct. 25']);
      expect(pts.map((p) => p.count), [10, 0]);
      expect(pts.map((p) => p.pending), [4, 7]);
      expect(pts.map((p) => p.cumul), [10, 10],
          reason: 'un dossier en attente n\'entre pas dans l\'effectif');
    });

    test('un mois isolé donne un point, pas une erreur', () {
      final pts = construireRythmeInscriptions({'2025-09': 3}, const {});
      expect(pts, hasLength(1));
      expect(pts.single.label, 'sept. 25');
      expect(pts.single.cumul, 3);
    });

    test('aucune donnée datée donne une série vide', () {
      expect(construireRythmeInscriptions(const {}, const {}), isEmpty);
    });

    test('une date aberrante ne fabrique pas mille colonnes', () {
      // Saisie fautive : « 0025-09 » au lieu de « 2025-09 ». Combler la plage
      // produirait vingt-quatre mille points et figerait la page.
      final pts = construireRythmeInscriptions(
        {'0025-09': 1, '2025-09': 40, '2025-10': 12},
        const {},
      );
      expect(pts, hasLength(3), reason: 'repli sur les seuls mois connus');
      expect(pts.map((p) => p.count), [1, 40, 12]);
    });

    test('ignore un mois mal formé sans casser la suite', () {
      final pts = construireRythmeInscriptions(
        {'2025-13': 9, '2025-09': 4, '2025-10': 6},
        const {},
      );
      expect(pts.map((p) => p.label), ['sept. 25', 'oct. 25']);
      expect(pts.map((p) => p.cumul), [4, 10]);
    });
  });
}
