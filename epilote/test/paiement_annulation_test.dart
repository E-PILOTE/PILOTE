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

  group('ce qu\'un paiement rapporte vraiment à la caisse', () {
    test('un encaissement confirmé rapporte son montant', () {
      expect(montantNet(status: 'confirmed', montant: 5000, rembourse: null),
          5000);
    });

    test('un remboursement PARTIEL ne retire que ce qui a été rendu', () {
      // ⚠️ Le défaut constaté à l'écran : la ligne basculait en `refunded` et
      // les lecteurs, qui ne comptaient que `confirmed`, retiraient les 2 000 F
      // entiers de la recette. L'école perdait 1 000 F qu'elle avait bien
      // encaissés.
      expect(montantNet(status: 'refunded', montant: 2000, rembourse: 1000),
          1000);
      expect(montantNet(status: 'confirmed', montant: 2000, rembourse: 1000),
          1000);
    });

    test('un remboursement TOTAL ne laisse rien', () {
      expect(montantNet(status: 'refunded', montant: 2000, rembourse: 2000), 0);
    });

    test('un paiement annulé ne rapporte rien, quoi qu\'il porte', () {
      expect(montantNet(status: 'cancelled', montant: 5000, rembourse: null), 0);
    });

    test('un paiement en attente n\'est pas encore de l\'argent en caisse', () {
      expect(montantNet(status: 'pending', montant: 5000, rembourse: null), 0);
    });

    test('un net ne descend jamais sous zéro', () {
      // Ceinture : le CHECK serveur l'interdit, mais une donnée héritée d'avant
      // la migration 0094 ne doit pas produire une recette négative.
      expect(montantNet(status: 'refunded', montant: 2000, rembourse: 9999), 0);
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

// ════════════════════════════════════════════════════════════════════════════
//  LE REMBOURSEMENT PARTIEL NE DOIT PAS EFFACER TOUT L'ENCAISSEMENT
//
//  Constaté à l'écran le 5 août 2026 : rembourser 1 000 F sur 2 000 encaissés
//  basculait la ligne en `refunded`. Or tous les lecteurs de recette ne
//  comptaient que `confirmed` — les 2 000 F entiers quittaient donc la caisse,
//  alors que l'école n'avait rendu que 1 000. L'élève repassait « impayé » et
//  l'établissement perdait 1 000 F de recette enregistrée.
// ════════════════════════════════════════════════════════════════════════════
