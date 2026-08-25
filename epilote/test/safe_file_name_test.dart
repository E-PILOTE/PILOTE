import 'package:flutter_test/flutter_test.dart';

import 'package:epilote/core/utils/safe_file_name.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Garde-fou : ces cas passent tous sous Linux, où seul « / » est interdit.
//  Ils échouent sous Windows — la plateforme de déploiement — et personne ne
//  s'en apercevrait avant qu'un agent d'établissement ne clique sur « Exporter ».
// ════════════════════════════════════════════════════════════════════════════
void main() {
  group('safeFileName — caractères interdits par Windows', () {
    test('remplace les neuf caractères refusés', () {
      expect(safeFileName(r'a<b>c:d"e/f\g|h?i*j'),
          'a-b-c-d-e-f-g-h-i-j');
    });

    test('un libellé de classe contenant une barre oblique', () {
      // Cas réel : une classe « 6ème A/B » produisait un chemin de dossier.
      expect(safeFileName('EDT_6ème A/B.pdf'), 'EDT_6ème A-B.pdf');
    });

    test('conserve les accents des noms congolais', () {
      expect(safeFileName('Fiche_Alphonsine_Kimbembé.pdf'),
          'Fiche_Alphonsine_Kimbembé.pdf');
    });

    test('supprime les caractères de contrôle', () {
      // Échappés explicitement : des caractères de contrôle littéraux
      // dans la source seraient invisibles à la relecture.
      expect(safeFileName('rapport\u0000\u001Ffinal.csv'),
          'rapport-final.csv');
    });
  });

  group('safeFileName — règles propres à Windows', () {
    test('retire les points et espaces finaux, que Windows tronque en silence',
        () {
      expect(safeFileName('Bulletin trimestre 1 ...'), 'Bulletin trimestre 1');
    });

    test('désamorce les noms réservés du DOS', () {
      expect(safeFileName('CON'), 'CON-fichier');
      expect(safeFileName('lpt1'), 'lpt1-fichier');
    });

    test('un nom réservé suivi d\'une extension reste invalide pour Windows',
        () {
      expect(safeFileName('NUL.pdf'), 'NUL-fichier.pdf');
    });
  });

  group('safeFileName — extension et longueur', () {
    test('tronque le nom sans amputer l\'extension', () {
      final r = safeFileName('${'a' * 300}.pdf');
      expect(r.endsWith('.pdf'), isTrue);
      expect(r.length, lessThanOrEqualTo(130));
    });

    test('un point isolé en milieu de nom n\'est pas pris pour une extension',
        () {
      expect(safeFileName('Rapport.2026.annuel'), 'Rapport.2026.annuel');
    });

    test('retombe sur le libellé de repli quand il ne reste rien', () {
      expect(safeFileName(r'///:::', fallback: 'export'), 'export');
    });
  });
}
