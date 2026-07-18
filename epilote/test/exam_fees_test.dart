import 'package:flutter_test/flutter_test.dart';

import 'package:epilote/features/examens/models/exam_fee.dart';

// ════════════════════════════════════════════════════════════════════════════
//  FRAIS D'EXAMEN — c'est de l'argent, et il remonte au revenu du groupe.
//
//  Une erreur ici ne produit pas un écran laid : elle produit un chiffre faux
//  dans le tableau de bord du ministère. D'où ces cas, écrits d'abord.
// ════════════════════════════════════════════════════════════════════════════

void main() {
  group('feeStateFor', () {
    test('rien versé → impayé', () {
      expect(feeStateFor(due: 15000, paid: 0), FeePaymentState.impaye);
    });

    test('versement partiel → partiel', () {
      expect(feeStateFor(due: 15000, paid: 5000), FeePaymentState.partiel);
    });

    test('montant exact → soldé', () {
      expect(feeStateFor(due: 15000, paid: 15000), FeePaymentState.solde);
    });

    // Un parent paie parfois un peu plus (appoint). Ce n'est pas une anomalie
    // à signaler : le candidat est en règle.
    test('surpaiement → soldé, jamais un état d\'erreur', () {
      expect(feeStateFor(due: 15000, paid: 20000), FeePaymentState.solde);
    });

    // Barème non configuré : ne rien devoir n'est pas être en dette.
    test('rien dû → soldé même sans versement', () {
      expect(feeStateFor(due: 0, paid: 0), FeePaymentState.solde);
    });
  });

  group('summarizeExamFees', () {
    test('attendu, encaissé et reste', () {
      final s = summarizeExamFees(
        amountPerCandidate: 15000,
        candidates: 10,
        payments: const [15000, 15000, 5000],
      );
      expect(s.expected, 150000);
      expect(s.collected, 35000);
      expect(s.remaining, 115000);
    });

    test('aucun candidat → tout à zéro, aucune division par zéro', () {
      final s = summarizeExamFees(
        amountPerCandidate: 15000,
        candidates: 0,
        payments: const [],
      );
      expect(s.expected, 0);
      expect(s.collected, 0);
      expect(s.remaining, 0);
      expect(s.rate, 0);
    });

    // Fail-soft : une école qui n'a pas encore fixé ses frais ne doit pas voir
    // l'écran planter ni un « 100 % recouvré » mensonger.
    test('barème absent (montant 0) → attendu 0, taux 0', () {
      final s = summarizeExamFees(
        amountPerCandidate: 0,
        candidates: 40,
        payments: const [],
      );
      expect(s.expected, 0);
      expect(s.rate, 0);
      expect(s.remaining, 0);
    });

    test('encaissé au-delà de l\'attendu → reste jamais négatif', () {
      final s = summarizeExamFees(
        amountPerCandidate: 1000,
        candidates: 2,
        payments: const [1000, 1000, 500],
      );
      expect(s.expected, 2000);
      expect(s.collected, 2500);
      expect(s.remaining, 0, reason: 'une dette négative n\'existe pas');
      expect(s.rate, 1.0, reason: 'le taux est plafonné à 100 %');
    });

    test('taux de recouvrement', () {
      final s = summarizeExamFees(
        amountPerCandidate: 10000,
        candidates: 10,
        payments: const [10000, 10000, 10000, 10000, 10000],
      );
      expect(s.rate, 0.5);
    });
  });
}
