import 'package:epilote/features/finance/providers/paiements_provider.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  ANNULER, PAS EFFACER (spec §5.3)
//
//  `deletePayment` faisait un DELETE sec : un reçu disparaissait sans laisser
//  de trace, et la caisse ne tombait plus juste sans que personne puisse dire
//  pourquoi. Sur des fonds publics, l'annulation doit rester lisible.
// ════════════════════════════════════════════════════════════════════════════

void main() {
  group('ce qui peut être annulé', () {
    test('un paiement confirmé peut l\'être', () {
      expect(peutAnnulerPaiement('confirmed'), isTrue);
    });

    test('un paiement en attente peut l\'être', () {
      expect(peutAnnulerPaiement('pending'), isTrue);
    });

    test('un paiement DÉJÀ annulé ne se réannule pas', () {
      expect(peutAnnulerPaiement('cancelled'), isFalse);
    });

    test('un paiement remboursé ne s\'annule pas', () {
      // Le remboursement a déjà rendu l'argent : annuler par-dessus ferait
      // disparaître la trace de la restitution.
      expect(peutAnnulerPaiement('refunded'), isFalse);
    });

    test('un statut inconnu est refusé plutôt que supposé', () {
      expect(peutAnnulerPaiement(null), isFalse);
      expect(peutAnnulerPaiement('brouillon'), isFalse);
    });
  });

  group('le motif est obligatoire', () {
    test('un motif vide est refusé', () {
      expect(motifAnnulationInvalide(''), isNotNull);
      expect(motifAnnulationInvalide('   '), isNotNull);
    });

    test('un motif trop court n\'explique rien', () {
      expect(motifAnnulationInvalide('ok'), isNotNull);
    });

    test('un motif renseigné passe', () {
      expect(motifAnnulationInvalide('Erreur de saisie du montant'), isNull);
    });
  });

  group('remboursement', () {
    test('seul un paiement confirmé se rembourse', () {
      expect(peutRembourserPaiement('confirmed'), isTrue);
      // On ne rend pas un argent qu'on n'a pas encore confirmé avoir reçu.
      expect(peutRembourserPaiement('pending'), isFalse);
      expect(peutRembourserPaiement('cancelled'), isFalse);
      expect(peutRembourserPaiement('refunded'), isFalse);
      expect(peutRembourserPaiement(null), isFalse);
    });

    test('on ne rembourse jamais plus qu\'on n\'a encaissé', () {
      // Le CHECK serveur (0094) le refuse : le dire AVANT la synchro évite de
      // perdre la transaction dans le journal d'échecs.
      expect(montantRemboursementInvalide(6000, 5000), isNotNull);
      expect(montantRemboursementInvalide(0, 5000), isNotNull);
      expect(montantRemboursementInvalide(-1, 5000), isNotNull);
    });

    test('un remboursement partiel ou total passe', () {
      expect(montantRemboursementInvalide(5000, 5000), isNull);
      expect(montantRemboursementInvalide(2000, 5000), isNull);
    });
  });
}
