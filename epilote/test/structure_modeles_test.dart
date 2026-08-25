// Une école créée depuis l'interface n'obtenait AUCUN niveau : l'écran écrivait
// dans `school_education_levels`, table à zéro ligne que personne ne lit.
// Ces tests gardent les deux règles de la réparation — le modèle ne connaît que
// des cycles, et un refus doit dire quoi fermer d'abord.

import 'package:epilote/features/admin_groupe/providers/education_provider.dart';
import 'package:epilote/features/admin_groupe/providers/structure_modeles.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Les modèles d\'établissement', () {
    test('ne contiennent AUCUN niveau en dur', () {
      // Recopier « CP1, CP2, CE1… » dans l'application créerait une deuxième
      // source de vérité, qui divergerait de la base au premier arrêté
      // ministériel. Un modèle ne désigne que des cycles.
      for (final m in kModelesEtablissement) {
        expect(m.cycles, isNotEmpty, reason: '${m.nom} ne désigne aucun cycle');
        expect(m.description.trim(), isNotEmpty);
      }
    });

    test('n\'emploient que des codes de cycle du référentiel', () {
      // Les cinq cycles réels de la base, vérifiés en production.
      const connus = {
        'prescolaire', 'primaire', 'college', 'lycee', 'formation_pro',
      };
      for (final m in kModelesEtablissement) {
        for (final c in m.cycles) {
          expect(connus, contains(c), reason: '${m.nom} → cycle inconnu « $c »');
        }
      }
    });

    test('le lycée technique laisse choisir ses filières', () {
      // La formation professionnelle compte 63 niveaux au référentiel national.
      // Aucun établissement du pays ne les offre tous : cocher le cycle ne doit
      // pas cocher les niveaux.
      final lt = kModelesEtablissement
          .firstWhere((m) => m.cycles.contains('formation_pro'));
      expect(lt.choisirFilieres, isTrue);

      for (final m in kModelesEtablissement) {
        if (!m.cycles.contains('formation_pro')) {
          expect(m.choisirFilieres, isFalse, reason: m.nom);
        }
      }
    });

    test('couvrent les formes réelles du système congolais', () {
      final noms = kModelesEtablissement.map((m) => m.nom).toList();
      expect(noms, hasLength(kModelesEtablissement.toSet().length));
      // Le primaire seul est la forme la plus répandue du pays : son absence
      // rendrait le jeu de modèles inutile pour la majorité des écoles.
      expect(kModelesEtablissement.any((m) => m.cycles.length == 1 &&
          m.cycles.single == 'primaire'), isTrue);
    });
  });

  group('Reconnaître la forme d\'une école déjà configurée', () {
    test('une combinaison exacte est nommée', () {
      expect(modelePour(['college'])?.nom, 'CEG');
      expect(modelePour(['college', 'lycee'])?.nom, 'Lycée avec collège');
      // L'ordre ne compte pas : c'est un ensemble.
      expect(modelePour(['lycee', 'college'])?.nom, 'Lycée avec collège');
    });

    test('une combinaison partielle n\'est PAS nommée', () {
      // Sinon une école primaire+collège s'annoncerait « École primaire », et
      // son directeur croirait la moitié de son établissement perdue.
      expect(modelePour(['primaire', 'college']), isNull);
      expect(modelePour(['prescolaire', 'primaire', 'college']), isNull);
    });

    test('une offre vide n\'est pas un modèle', () {
      expect(modelePour(const []), isNull);
    });
  });

  group('Le refus de retirer un niveau peuplé', () {
    test('nomme les niveaux et compte leurs classes', () {
      final e = const StructureRefusee([
        (niveau: 'Sixième (6e)', classes: 3),
        (niveau: 'Troisième (3e)', classes: 1),
      ]);
      final msg = e.toString();
      expect(msg, contains('Sixième (6e) (3 classes)'));
      expect(msg, contains('Troisième (3e) (1 classe)')); // pas de « s »
    });

    test('dit explicitement que rien n\'a été modifié', () {
      // La base refuse en bloc. Sans cette phrase, l'administrateur croit à un
      // enregistrement partiel et va vérifier école par école.
      final msg = const StructureRefusee([(niveau: 'CM2', classes: 2)]).toString();
      expect(msg.toLowerCase(), contains('rien n\'a été modifié'));
      expect(msg.toLowerCase(), contains('fermez'));
    });
  });
}
