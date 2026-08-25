import 'package:epilote/features/staff/providers/agent_creation_provider.dart';
import 'package:epilote/features/staff/providers/staff_directory_provider.dart';
import 'package:epilote/features/staff/screens/personnel_screen.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Le comptage des enseignants par cycle, et les motifs d'arrivée.
//
//  Le cycle d'un enseignant est DÉDUIT de ses classes : il est donc nul tant
//  que l'emploi du temps n'est pas fait. Ces tests garantissent que ces
//  enseignants-là ne disparaissent pas du compte — c'est tout l'objet de la
//  carte « Sans classe affectée ».
// ════════════════════════════════════════════════════════════════════════════

StaffMember _agent({
  required String role,
  String? cycle,
  String? statut,
  String id = 'x',
  bool actif = true,
}) =>
    StaffMember(
      id: id,
      firstName: 'A',
      lastName: 'B',
      role: role,
      isActive: actif,
      teachingCycle: cycle,
      employmentStatus: statut,
    );

void main() {
  group('personnelParStatut', () {
    test('compte tout le personnel, dans l\'ordre de l\'énumération', () {
      final r = personnelParStatut([
        _agent(role: 'enseignant', statut: 'volontaire', id: '1'),
        _agent(role: 'comptable', statut: 'fonctionnaire', id: '2'),
        _agent(role: 'enseignant', statut: 'fonctionnaire', id: '3'),
      ]);
      expect(r.map((s) => s.cle).toList(), ['fonctionnaire', 'volontaire'],
          reason: 'l\'ordre canonique met l\'agent de l\'État en premier');
      expect(r.first.n, 2);
    });

    test('les non-enseignants comptent AUSSI', () {
      // À la différence des cycles : un comptable n'appartient à aucun cycle,
      // mais il a bel et bien un employeur.
      final r = personnelParStatut([
        _agent(role: 'secretaire', statut: 'contractuel', id: '1'),
      ]);
      expect(r.single.n, 1);
    });

    test('« à renseigner » a sa carte, et elle vient en dernier', () {
      final r = personnelParStatut([
        _agent(role: 'enseignant', id: '1'),
        _agent(role: 'enseignant', statut: '', id: '2'),
        _agent(role: 'enseignant', statut: 'fonctionnaire', id: '3'),
      ]);
      expect(r.last.cle, kStatutNonRenseigne);
      expect(r.last.n, 2, reason: 'null et chaîne vide, même ignorance');
    });

    test('sans carte « à renseigner », zéro se lirait comme une vérité', () {
      // C'est LE point : dix agents sans statut ne font pas « 0 fonctionnaire ».
      final r = personnelParStatut([
        for (var i = 0; i < 10; i++) _agent(role: 'enseignant', id: '$i'),
      ]);
      expect(r.length, 1);
      expect(r.single.cle, kStatutNonRenseigne);
      expect(r.single.n, 10);
    });

    test('un statut absent n\'occupe pas de carte vide', () {
      final r = personnelParStatut([
        _agent(role: 'enseignant', statut: 'benevole', id: '1'),
      ]);
      expect(r.map((s) => s.cle).toList(), ['benevole']);
    });

    test('la somme recompose l\'effectif', () {
      final agents = [
        _agent(role: 'enseignant', statut: 'fonctionnaire', id: '1'),
        _agent(role: 'enseignant', statut: 'volontaire', id: '2'),
        _agent(role: 'cpe', id: '3'),
      ];
      expect(personnelParStatut(agents).fold(0, (a, s) => a + s.n),
          agents.length);
    });
  });

  group('enseignantsParCycle', () {
    test('compte les enseignants par cycle, dans l\'ordre scolaire', () {
      final r = enseignantsParCycle([
        _agent(role: 'enseignant', cycle: 'lycee', id: '1'),
        _agent(role: 'enseignant', cycle: 'college', id: '2'),
        _agent(role: 'enseignant', cycle: 'college', id: '3'),
        _agent(role: 'enseignant', cycle: 'primaire', id: '4'),
      ]);
      expect(r.cycles.map((c) => c.cle).toList(),
          ['primaire', 'college', 'lycee']);
      expect(r.cycles.firstWhere((c) => c.cle == 'college').n, 2);
      expect(r.sansClasse, 0);
    });

    test('un enseignant SANS classe affectée est compté à part, jamais perdu',
        () {
      final r = enseignantsParCycle([
        _agent(role: 'enseignant', cycle: 'college', id: '1'),
        _agent(role: 'enseignant', id: '2'),
        _agent(role: 'enseignant', cycle: '', id: '3'),
      ]);
      expect(r.cycles.single.n, 1);
      expect(r.sansClasse, 2,
          reason: 'null ET chaîne vide désignent la même absence');
    });

    test('la somme des cartes égale le nombre d\'enseignants', () {
      final agents = [
        for (var i = 0; i < 7; i++)
          _agent(
              role: 'enseignant',
              id: '$i',
              cycle: i < 3 ? 'college' : (i < 5 ? 'lycee' : null)),
      ];
      final r = enseignantsParCycle(agents);
      final total =
          r.cycles.fold(0, (a, c) => a + c.n) + r.sansClasse;
      expect(total, 7,
          reason: 'un chiffre qui ne se recompose pas à l\'œil fait douter '
              'de toute la page');
    });

    test('les non-enseignants ne comptent dans aucun cycle', () {
      final r = enseignantsParCycle([
        _agent(role: 'comptable', cycle: 'lycee', id: '1'),
        _agent(role: 'secretaire', id: '2'),
        _agent(role: 'enseignant', cycle: 'lycee', id: '3'),
      ]);
      expect(r.cycles.single.n, 1);
      expect(r.sansClasse, 0);
    });

    test('aucun agent : rien à afficher', () {
      final r = enseignantsParCycle(const []);
      expect(r.cycles, isEmpty);
      expect(r.sansClasse, 0);
    });
  });

  group('motifs d\'arrivée', () {
    test('chaque motif du serveur a un libellé français', () {
      // Tenu identique à motifs_arrivee_constatables() (migration 0091).
      const serveur = [
        'mutation', 'detachement', 'mise_a_disposition',
        'interim', 'reintegration', 'recrutement',
      ];
      for (final m in serveur) {
        expect(kMotifsArrivee.containsKey(m), isTrue,
            reason: '« $m » sortirait brut à l\'écran');
        expect(motifArriveeLabel(m), isNot(m));
      }
    });

    test('un motif inconnu se dégrade sans planter', () {
      expect(motifArriveeLabel('inexistant'), 'inexistant');
    });

    test('« recrutement » n\'est plus réservé au secteur privé', () {
      // La 0091 l'y avait enfermé ; la 0092 a corrigé : une école PUBLIQUE
      // recrute bel et bien ses volontaires et ses vacataires, payés par
      // l'APE. C'est le STATUT de l'agent qui décide, pas le secteur — voir
      // `statut_regime_arrivee_test.dart`.
      expect(kMotifsArrivee['recrutement']!.aide, isNot(contains('privé')),
          reason: 'ce libellé aurait fait douter une direction publique de '
              'son droit d\'enregistrer son propre personnel');
      expect(kMotifsArriveeParStatut['volontaire'], contains('recrutement'));
    });
  });
}
