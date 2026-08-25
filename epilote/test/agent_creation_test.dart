// Provisionner un compte est le seul geste EN LIGNE de l'espace école, et le
// seul qui crée un droit d'accès. Ces tests gardent les frontières : ce qu'un
// chef d'établissement peut attribuer, et ce que l'écran doit refuser AVANT la
// saisie plutôt qu'après.

import 'package:epilote/features/staff/providers/agent_creation_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Fonctions attribuables par l\'établissement', () {
    test('recopie exactement roles_provisionnables_par_ecole() (mig 0088)', () {
      // Recopie littérale du tableau SQL. Si l'une des deux listes bouge sans
      // l'autre, l'écran propose une fonction que le serveur refuse — et
      // l'agent remplit un formulaire pour rien.
      const sql = {
        'enseignant', 'cpe', 'comptable', 'secretaire', 'surveillant',
        'infirmier', 'responsable_cantine',
      };
      expect(kRolesProvisionnablesParEcole.map((r) => r.value).toSet(), sql);
    });

    test('ni directeur ni proviseur — jamais', () {
      // Un chef d'établissement qui pourrait s'en fabriquer un second sortirait
      // de la portée de sa hiérarchie. C'est le chemin d'élévation de
      // privilèges classique, et le serveur le refuse aussi.
      final codes = kRolesProvisionnablesParEcole.map((r) => r.value);
      expect(codes, isNot(contains('directeur')));
      expect(codes, isNot(contains('proviseur')));
    });

    test('ni super_admin ni admin_groupe', () {
      final codes = kRolesProvisionnablesParEcole.map((r) => r.value);
      expect(codes, isNot(contains('super_admin')));
      expect(codes, isNot(contains('admin_groupe')));
    });

    test('aucun libellé vide, aucun doublon', () {
      final codes = kRolesProvisionnablesParEcole.map((r) => r.value).toList();
      expect(codes.toSet().length, codes.length);
      for (final r in kRolesProvisionnablesParEcole) {
        expect(r.label.trim(), isNotEmpty);
      }
    });
  });

  group('Ce qui empêche, dit avant la saisie', () {
    ContexteCreationAgent ctx({
      bool autorise = true,
      int? max = 20,
      int actuels = 5,
      bool illimite = false,
      List<ProfilAcces> profils = const [ProfilAcces('p1', 'Enseignant')],
    }) =>
        ContexteCreationAgent(
          autorise: autorise,
          maxStaff: max,
          agentsActuels: actuels,
          illimite: illimite,
          profils: profils,
        );

    test('les places restantes se comptent sur l\'abonnement', () {
      expect(ctx(max: 20, actuels: 5).placesRestantes, 15);
      expect(ctx(max: 20, actuels: 5).quotaAtteint, isFalse);
    });

    test('quota atteint, et même dépassé', () {
      expect(ctx(max: 10, actuels: 10).quotaAtteint, isTrue);
      // Un dépassement existe : le groupe a pu changer de plan à la baisse.
      expect(ctx(max: 10, actuels: 12).quotaAtteint, isTrue);
      expect(ctx(max: 10, actuels: 12).placesRestantes, -2);
    });

    test('un plan illimité ne compte rien', () {
      final c = ctx(illimite: true, max: -1, actuels: 900);
      expect(c.placesRestantes, isNull);
      expect(c.quotaAtteint, isFalse);
    });

    test('aucun profil d\'accès = on refuse d\'ouvrir le formulaire', () {
      // Le piège connu du projet : un compte sans profil ouvre une application
      // vide. Sur mille écoles, ce serait mille appels au support le même
      // matin.
      expect(ctx(profils: const []).aucunProfilDisponible, isTrue);
      expect(ctx().aucunProfilDisponible, isFalse);
    });

    test('hors ligne n\'est PAS « non autorisé »', () {
      // On ne dit pas à un directeur qu'il n'a pas le droit alors qu'il est
      // seulement sans réseau.
      const c = ContexteCreationAgent.indisponible;
      expect(c.horsLigne, isTrue);
      expect(c.autorise, isFalse);
    });
  });

  group('Lecture de la réponse serveur', () {
    test('lit le contexte complet', () {
      final c = ContexteCreationAgent.fromMap(const {
        'autorise': true,
        'max_staff': 10,
        'agents_actuels': 9,
        'illimite': false,
        'profils_acces': [
          {'id': 'a', 'name': 'Direction'},
          {'id': 'b', 'name': 'Enseignant'},
        ],
      });
      expect(c.autorise, isTrue);
      expect(c.placesRestantes, 1);
      expect(c.profils.map((p) => p.name), ['Direction', 'Enseignant']);
    });

    test('une réponse vide n\'autorise rien et ne plante pas', () {
      final c = ContexteCreationAgent.fromMap(const {});
      expect(c.autorise, isFalse);
      expect(c.profils, isEmpty);
      expect(c.quotaAtteint, isFalse); // illimité par défaut : pas de faux blocage
    });
  });
}
