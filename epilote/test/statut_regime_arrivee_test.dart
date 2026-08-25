import 'package:epilote/features/staff/providers/agent_creation_provider.dart';
import 'package:epilote/features/staff/providers/staff_dossier_provider.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE STATUT DÉCIDE DU RÉGIME D'ARRIVÉE (migration 0092)
//
//  La 0091 exigeait un acte d'affectation de TOUT agent arrivant dans une
//  école publique. Or un volontaire ou un vacataire payé par l'APE n'a pas
//  d'arrêté : la moitié du personnel d'un lycée congolais serait restée hors
//  de l'application — ou aurait été enregistrée sous une référence inventée
//  pour passer l'écran, ce qui est pire.
//
//  Ces tests gardent la table Dart alignée sur le serveur. Le serveur reste
//  l'autorité (`motifs_arrivee_pour_statut`, `motif_exige_un_acte`) ; ce qui
//  est vérifié ici, c'est que l'écran ne propose jamais un chemin que le
//  serveur refusera, et surtout qu'il n'en ferme aucun qu'il accepterait.
// ════════════════════════════════════════════════════════════════════════════

ContexteCreationAgent _contexte({
  Map<String, List<String>> motifsParStatut = const {},
  Set<String> motifsAvecActe = const {},
  List<String> statuts = const [],
}) =>
    ContexteCreationAgent(
      autorise: true,
      profils: const [],
      statutsEmploi: statuts,
      motifsParStatut: motifsParStatut,
      motifsAvecActe: motifsAvecActe,
    );

void main() {
  group('quels motifs pour quel statut', () {
    test('un volontaire est RECRUTÉ par l\'établissement, jamais affecté', () {
      expect(kMotifsArriveeParStatut['volontaire'], ['recrutement'],
          reason: 'aucun arrêté ne concerne un agent payé par l\'APE');
    });

    test('un fonctionnaire n\'est JAMAIS recruté par son école', () {
      for (final statut in ['fonctionnaire']) {
        expect(kMotifsArriveeParStatut[statut], isNot(contains('recrutement')),
            reason: 'c\'est le ministère qui nomme, pas le lycée');
      }
    });

    test('un contractuel peut arriver des deux façons', () {
      // De l'État (par acte) ou de l'établissement (par recrutement) :
      // l'énumération ne distingue pas les deux, le motif tranche.
      final m = kMotifsArriveeParStatut['contractuel']!;
      expect(m, contains('recrutement'));
      expect(m, contains('mutation'));
    });

    test('tout statut de l\'énumération a au moins un motif', () {
      for (final (code, libelle) in kEmploymentStatuses) {
        expect(kMotifsArriveeParStatut[code], isNotEmpty,
            reason: '« $libelle » serait impossible à enregistrer');
      }
    });

    test('« reprise_historique » n\'est proposé à personne', () {
      // C'est une reprise de données, pas une arrivée constatée par un chef
      // d'établissement.
      for (final motifs in kMotifsArriveeParStatut.values) {
        expect(motifs, isNot(contains('reprise_historique')));
      }
    });
  });

  group('quels motifs supposent un acte', () {
    test('recrutement : aucun acte extérieur à référencer', () {
      expect(kMotifsAvecActe, isNot(contains('recrutement')));
    });

    test('mutation, détachement, mise à disposition, intérim, réintégration',
        () {
      for (final m in ['mutation', 'detachement', 'mise_a_disposition',
                       'interim', 'reintegration']) {
        expect(kMotifsAvecActe, contains(m),
            reason: '« $m » procède toujours d\'une décision écrite');
      }
    });
  });

  group('ce que l\'écran propose', () {
    test('le serveur fait autorité quand il a répondu', () {
      final c = _contexte(motifsParStatut: {'volontaire': ['mutation']});
      expect(c.motifsPour('volontaire'), ['mutation'],
          reason: 'la règle vit en base ; l\'écran la reflète, il ne la double '
              'pas');
    });

    test('sans réponse du serveur, on retombe sur la table Dart', () {
      expect(_contexte().motifsPour('volontaire'), ['recrutement']);
    });

    test('un statut inconnu ne propose RIEN', () {
      // Mieux vaut un menu vide qu'un motif inventé que le serveur refusera
      // après douze champs remplis.
      expect(_contexte().motifsPour('vacataire_imaginaire'), isEmpty);
      expect(_contexte().motifsPour(null), isEmpty);
    });

    test('aucun statut choisi : aucun motif', () {
      expect(_contexte().motifsPour(null), isEmpty);
    });
  });

  group('quand exiger la référence de l\'acte', () {
    test('mutation → oui, recrutement → non', () {
      final c = _contexte(motifsAvecActe: const {'mutation'});
      expect(c.acteExige('mutation'), isTrue);
      expect(c.acteExige('recrutement'), isFalse);
    });

    test('serveur muet : on retombe sur la table Dart, jamais sur « non »', () {
      // Retomber sur « non » laisserait naître une mutation sans référence —
      // exactement la carrière falsifiée que la 0091 corrigeait.
      final c = _contexte();
      expect(c.acteExige('mutation'), isTrue);
      expect(c.acteExige('recrutement'), isFalse);
    });

    test('aucun motif choisi : rien n\'est exigé', () {
      expect(_contexte().acteExige(null), isFalse);
    });
  });

  group('ordre d\'affichage des statuts', () {
    test('sans réponse du serveur, l\'ordre canonique reste complet', () {
      final proposables = _contexte().statutsProposables;
      expect(proposables.length, kEmploymentStatuses.length);
      for (final (code, _) in kEmploymentStatuses) {
        expect(proposables, contains(code));
      }
    });

    test('le serveur peut réordonner selon le secteur', () {
      final c = _contexte(statuts: const ['contractuel', 'fonctionnaire']);
      expect(c.statutsProposables.first, 'contractuel',
          reason: 'dans un établissement privé, on saisit surtout des '
              'contractuels');
    });
  });
}
