// Le vocabulaire des mouvements d'agent est tenu identique aux contraintes
// `CHECK` de la migration 0083. Ces tests gardent les invariants qui, s'ils
// cédaient, feraient rejeter l'écriture par le serveur — ou, pire, la feraient
// passer en disant le contraire de la vérité.

import 'package:epilote/core/utils/mouvement_agent.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Motifs de départ', () {
    test('« mutation » n\'est JAMAIS un motif de départ', () {
      // C'est tout le correctif : un agent muté n'a pas quitté le service.
      // `radier_agent` lève une exception sur ce motif ; le proposer à l'écran
      // ne produirait qu'une erreur en pleine saisie.
      expect(kMotifsDepart.any((m) => m.code == 'mutation'), isFalse);
    });

    test('les codes sont uniques et non vides', () {
      final codes = kMotifsDepart.map((m) => m.code).toList();
      expect(codes.toSet().length, codes.length);
      expect(codes.any((c) => c.trim().isEmpty), isFalse);
    });

    test('révocation et décès ne se réintègrent pas', () {
      expect(departReversible('revocation'), isFalse);
      expect(departReversible('deces'), isFalse);
      expect(departReversible('retraite'), isTrue);
      expect(departReversible('detachement'), isTrue);
    });

    test('un code inconnu est réputé réversible', () {
      // Mieux vaut laisser corriger que bloquer sur une ignorance — une base
      // plus récente peut porter un motif que cette version ne connaît pas.
      expect(departReversible('motif_futur'), isTrue);
      expect(departReversible(null), isTrue);
    });

    test('chaque motif de départ existe dans la contrainte SQL', () {
      // Recopie littérale de la liste de la migration 0083
      // (`profiles_departure_motif_check`). Si l'une des deux bouge sans
      // l'autre, l'écriture est rejetée par le serveur.
      const sql = {
        'detachement', 'disponibilite', 'retraite', 'demission', 'licenciement',
        'revocation', 'abandon_de_poste', 'deces', 'fin_de_contrat',
        'fin_interim', 'autre',
      };
      expect(kMotifsDepart.map((m) => m.code).toSet(), sql);
    });
  });

  group('Motifs d\'arrivée', () {
    test('correspondent à la contrainte SQL, hors motif technique', () {
      // `reprise_historique` est écrit par la migration, jamais proposé.
      const sql = {
        'recrutement', 'mutation', 'detachement', 'mise_a_disposition',
        'interim', 'reintegration',
      };
      expect(kMotifsArrivee.map((m) => m.code).toSet(), sql);
    });
  });

  group('Libellés', () {
    test('rendent le motif technique de reprise lisible', () {
      expect(mouvementLabel('reprise_historique'), 'Reprise de l\'existant');
    });

    test('rendent le code brut plutôt que rien', () {
      expect(mouvementLabel('motif_inconnu'), 'motif_inconnu');
      expect(mouvementLabel(null), '—');
      expect(mouvementLabel(''), '—');
    });

    test('couvrent tous les motifs des deux listes', () {
      for (final m in [...kMotifsArrivee, ...kMotifsDepart]) {
        expect(mouvementLabel(m.code), m.label);
        expect(m.hint.trim(), isNotEmpty);
      }
    });
  });
}
