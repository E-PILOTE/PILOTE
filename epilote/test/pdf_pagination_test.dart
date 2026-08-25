import 'package:epilote/core/services/official_pdf_kit.dart';
import 'package:flutter_test/flutter_test.dart';

/// Découpage des tableaux longs dans les documents officiels.
///
/// Ce garde-fou n'est pas cosmétique : `OfficialPdfKit.frame()` enveloppe son
/// contenu dans un `Padding`, qui ne sait pas se scinder entre deux pages. Une
/// table plus haute qu'une page fait boucler `MultiPage` jusqu'à
/// `TooManyPagesException` — le PDF ne sort PAS DU TOUT. C'est exactement ce
/// qui s'est produit sur l'export « Élèves du réseau » (32 lignes), et ce qui
/// attendait le palmarès en « Top 50 ».
void main() {
  List<int> seq(int n) => List.generate(n, (i) => i);

  group('OfficialPdfKit.paginate', () {
    test('une liste vide ne produit aucun bloc — pas de page fantôme', () {
      expect(OfficialPdfKit.paginate(<int>[], first: 16, next: 27), isEmpty);
    });

    test('une liste qui tient sur la première page reste en un seul bloc', () {
      final p = OfficialPdfKit.paginate(seq(12), first: 12, next: 26);
      expect(p.length, 1);
      expect(p.first.length, 12);
    });

    test('la première page est plus courte — titre et KPI l\'occupent déjà', () {
      final p = OfficialPdfKit.paginate(seq(40), first: 12, next: 26);
      expect(p.map((c) => c.length), [12, 26, 2]);
    });

    test('aucune ligne n\'est perdue ni dupliquée', () {
      for (final n in [1, 17, 43, 200]) {
        final p = OfficialPdfKit.paginate(seq(n), first: 12, next: 26);
        expect(p.expand((c) => c).toList(), seq(n),
            reason: 'une liste de $n lignes doit ressortir intacte et ordonnée');
      }
    });

    test('le plafond de recherche (200) tient en un nombre fini de blocs', () {
      final p = OfficialPdfKit.paginate(seq(200), first: 12, next: 26);
      expect(p.length, 9);
      expect(p.every((c) => c.isNotEmpty), isTrue,
          reason: 'un bloc vide produirait un cadre « (suite) » sans contenu');
    });
  });
}
