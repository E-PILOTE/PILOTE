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
    );

void main() {
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

    test('« recrutement » existe, mais le serveur seul décide de l\'offrir',
        () {
      // Une école PUBLIQUE ne recrute pas : c'est la migration 0091 qui
      // retire ce motif de la liste, jamais ce fichier.
      expect(kMotifsArrivee['recrutement']!.aide, contains('privé'));
    });
  });
}
