import 'package:flutter_test/flutter_test.dart';

import 'package:epilote/features/evaluation/providers/bulletins_provider.dart';

// Vérifie la logique PURE du module Évaluation (sans base ni réseau) :
//  • les seuils de mention alignés sur la fonction SQL `get_mention` ;
//  • la pondération moyenne /20 (barème + coefficients) telle qu'appliquée par
//    le calcul des bulletins.
void main() {
  group('mentionFor — seuils alignés sur get_mention() en base', () {
    test('bornes exactes', () {
      expect(mentionFor(20), 'Excellent');
      expect(mentionFor(16), 'Excellent');
      expect(mentionFor(15.99), 'Très Bien');
      expect(mentionFor(14), 'Très Bien');
      expect(mentionFor(13.99), 'Bien');
      expect(mentionFor(12), 'Bien');
      expect(mentionFor(11.99), 'Assez Bien');
      expect(mentionFor(10), 'Assez Bien');
      expect(mentionFor(9.99), 'Passable');
      expect(mentionFor(8), 'Passable');
      expect(mentionFor(7.99), 'Insuffisant');
      expect(mentionFor(0), 'Insuffisant');
    });

    test('null → tiret', () => expect(mentionFor(null), '—'));
  });

  group('Pondération (réplique du calcul des bulletins)', () {
    // Normalisation d'une note sur le barème vers /20.
    double norm(double score, double max) => max > 0 ? score / max * 20 : 0;

    // Moyenne d'une matière = somme(note/20 × coeff_éval) / somme(coeff_éval).
    double subjectAvg(List<(double score, double max, int coef)> grades) {
      var sw = 0.0;
      var wc = 0;
      for (final (s, m, c) in grades) {
        sw += norm(s, m) * c;
        wc += c;
      }
      return sw / wc;
    }

    test('barème /10 ramené sur /20', () {
      expect(norm(8, 10), 16); // 8/10 → 16/20
      expect(norm(15, 20), 15);
    });

    test('moyenne matière pondérée par coefficient d\'évaluation', () {
      // Devoir 12/20 coeff 1 + Composition 16/20 coeff 2 → (12 + 32)/3 = 14.67
      final avg = subjectAvg([(12, 20, 1), (16, 20, 2)]);
      expect(avg, closeTo(14.6667, 0.001));
    });

    test('moyenne générale pondérée par coefficient matière', () {
      // Maths 15 (coef 4), Français 10 (coef 3) → (60 + 30)/7 = 12.857
      const mathAvg = 15.0, frAvg = 10.0;
      const mathCoef = 4, frCoef = 3;
      final overall =
          (mathAvg * mathCoef + frAvg * frCoef) / (mathCoef + frCoef);
      expect(overall, closeTo(12.857, 0.001));
      expect(mentionFor(overall), 'Bien');
    });
  });
}
