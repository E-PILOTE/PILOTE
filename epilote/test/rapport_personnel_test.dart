import 'package:flutter_test/flutter_test.dart';

import 'package:epilote/features/user/services/rapport_personnel.dart';

// ════════════════════════════════════════════════════════════════════════════
//  L'ÉTAT DU PERSONNEL DÉCLARE QUI EST EN POSTE
//
//  Il se signe et se transmet, comme l'état des effectifs, et il porte deux
//  décisions que rien ne rend évidentes : un compte désactivé ne compte pas
//  dans l'effectif mais ne disparaît pas de l'état, et un statut d'emploi non
//  saisi ne devient pas « fonctionnaire » par défaut.
// ════════════════════════════════════════════════════════════════════════════

AgentCompte _a({
  String role = 'enseignant',
  bool actif = true,
  String? statut = 'fonctionnaire',
}) =>
    (role: role, actif: actif, statutEmploi: statut);

void main() {
  group('qui est en poste', () {
    test('un agent actif compte dans l\'effectif', () {
      final l = personnelParCategorie([_a()]).single;
      expect(l.enFonction, 1);
      expect(l.inactifs, 0);
    });

    test('un compte désactivé sort de l\'effectif SANS disparaître', () {
      // ⚠️ Sans la colonne « désactivés », une école qui a fermé cinq comptes
      // afficherait une baisse d'effectif que rien n'explique sur le papier.
      final l = personnelParCategorie([_a(), _a(actif: false)]).single;
      expect(l.enFonction, 1);
      expect(l.inactifs, 1);
    });

    test('le total sépare les deux jusqu\'au bout', () {
      final lignes = personnelParCategorie([
        _a(role: 'directeur'),
        _a(role: 'secretaire', actif: false),
        _a(),
        _a(),
      ]);
      final t = cumulPersonnel('TOTAL', lignes);
      expect(t.enFonction, 3);
      expect(t.inactifs, 1);
    });
  });

  group('le regroupement vient de l\'annuaire, pas d\'ici', () {
    test('chaque rôle tombe dans sa catégorie métier', () {
      final lignes = personnelParCategorie([
        _a(role: 'proviseur'),
        _a(role: 'comptable'),
        _a(role: 'enseignant'),
        _a(role: 'cpe'),
      ]);
      expect(lignes.map((l) => l.libelle),
          ['Direction', 'Administration', 'Enseignants', 'Vie scolaire']);
    });

    test('l\'ordre est celui de l\'organigramme, pas celui des données', () {
      final lignes = personnelParCategorie([
        _a(role: 'surveillant'),
        _a(role: 'enseignant'),
        _a(role: 'directeur'),
      ]);
      expect(lignes.first.libelle, 'Direction');
      expect(lignes.last.libelle, 'Vie scolaire');
    });

    test('une catégorie sans personne n\'encombre pas l\'état', () {
      final lignes = personnelParCategorie([_a(role: 'enseignant')]);
      expect(lignes.length, 1);
      expect(lignes.single.libelle, 'Enseignants');
    });

    test('un rôle inconnu ne fait pas disparaître l\'agent', () {
      // Le jour où l'enum `user_role` gagne une valeur, l'agent doit rester
      // compté quelque part plutôt que de s'évaporer de l'effectif déclaré.
      final lignes = personnelParCategorie([_a(role: 'archiviste')]);
      expect(cumulPersonnel('T', lignes).enFonction, 1);
      expect(lignes.single.libelle, 'Autres');
    });
  });

  group('le statut d\'emploi', () {
    test('les statuts se classent du plus nombreux au moins nombreux', () {
      final lignes = personnelParStatut([
        _a(statut: 'volontaire'),
        _a(statut: 'fonctionnaire'),
        _a(statut: 'fonctionnaire'),
        _a(statut: 'fonctionnaire'),
        _a(statut: 'prestataire'),
        _a(statut: 'prestataire'),
      ]);
      expect(lignes.map((l) => l.libelle),
          ['fonctionnaire', 'prestataire', 'volontaire']);
    });

    test('un statut non saisi ne devient PAS fonctionnaire', () {
      // ⚠️ Le ranger d'office dans le statut majoritaire donnerait un état où
      // la somme des statuts égale l'effectif : invérifiable, et faux.
      final lignes = personnelParStatut([_a(statut: null), _a()]);
      expect(lignes.map((l) => l.libelle),
          ['fonctionnaire', kStatutNonRenseigne]);
      expect(cumulPersonnel('T', lignes).enFonction, 2);
    });

    test('une chaîne vide vaut « non renseigné »', () {
      final lignes = personnelParStatut([_a(statut: '   ')]);
      expect(lignes.single.libelle, kStatutNonRenseigne);
    });

    test('le non-renseigné passe en DERNIER, même s\'il est majoritaire', () {
      // Sinon l'anomalie ouvre le tableau et se lit comme une catégorie.
      final lignes = personnelParStatut([
        _a(statut: null),
        _a(statut: null),
        _a(statut: null),
        _a(statut: 'fonctionnaire'),
      ]);
      expect(lignes.last.libelle, kStatutNonRenseigne);
      expect(lignes.last.enFonction, 3);
    });

    test('à effectif égal, l\'ordre est alphabétique et donc stable', () {
      final lignes = personnelParStatut([
        _a(statut: 'volontaire'),
        _a(statut: 'fonctionnaire'),
      ]);
      expect(lignes.map((l) => l.libelle), ['fonctionnaire', 'volontaire']);
    });

    test('les deux ventilations comptent le MÊME effectif', () {
      // Deux chemins vers le même total : deux occasions de diverger.
      final agents = [
        _a(role: 'directeur', statut: 'fonctionnaire'),
        _a(role: 'enseignant', statut: null),
        _a(role: 'cpe', statut: 'volontaire', actif: false),
        _a(role: 'inconnu', statut: 'prestataire'),
      ];
      final parCat = cumulPersonnel('T', personnelParCategorie(agents));
      final parStatut = cumulPersonnel('T', personnelParStatut(agents));
      expect(parCat.enFonction, parStatut.enFonction);
      expect(parCat.inactifs, parStatut.inactifs);
    });
  });

  group('une école doit avoir une direction en fonction', () {
    test('un directeur actif suffit', () {
      expect(aUneDirectionEnPoste([_a(role: 'directeur'), _a()]), isTrue);
    });

    test('un proviseur aussi', () {
      expect(aUneDirectionEnPoste([_a(role: 'proviseur')]), isTrue);
    });

    test('un directeur DÉSACTIVÉ ne signe rien', () {
      // ⚠️ Le cas qui compte : le compte existe, l'état paraît complet, et
      // personne n'est en poste pour le signer.
      expect(aUneDirectionEnPoste([_a(role: 'directeur', actif: false), _a()]),
          isFalse);
    });

    test('une école sans aucun agent n\'a pas de direction', () {
      expect(aUneDirectionEnPoste(const []), isFalse);
    });

    test('un secrétaire n\'est pas la direction', () {
      // Il relève de l'administration : c'est l'annuaire qui en décide, et
      // l'état s'y conforme au lieu d'en juger.
      expect(aUneDirectionEnPoste([_a(role: 'secretaire')]), isFalse);
    });
  });
}
