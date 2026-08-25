// Le garde-fou de l'écran « Non revenus ». Il compte plus que l'écran :
// tant que la rentrée n'est pas saisie, la requête déclarerait TOUTE l'école
// disparue. Une liste fausse ne se rattrape pas — on ne la croit plus jamais.

import 'package:epilote/features/evaluation/providers/non_revenus_provider.dart';
import 'package:flutter_test/flutter_test.dart';

EleveNonRevenu _eleve(String id, {String? genre}) => EleveNonRevenu(
      enrollmentId: id,
      studentId: 's$id',
      firstName: 'Prénom',
      lastName: 'Nom',
      className: '6e A',
      gender: genre,
    );

void main() {
  group('Garde-fou de la rentrée', () {
    test('rentrée non commencée : l\'écran se tait', () {
      // 868 élèves l'an dernier, aucun réinscrit : la requête les désigne tous.
      final b = BilanRentree(
        aUnPasse: true,
        labelPrecedent: '2025-2026',
        effectifPrecedent: 868,
        reinscritsCetteAnnee: 0,
        eleves: [for (var i = 0; i < 868; i++) _eleve('$i')],
      );
      expect(b.rentreeSaisie, isFalse);
      expect(b.avancement, 0);
    });

    test('rentrée à peine entamée : toujours muet', () {
      final b = BilanRentree(
        aUnPasse: true,
        labelPrecedent: '2025-2026',
        effectifPrecedent: 100,
        reinscritsCetteAnnee: 29,
        eleves: [for (var i = 0; i < 71; i++) _eleve('$i')],
      );
      expect(b.rentreeSaisie, isFalse);
    });

    test('au seuil exact de 30 %, la liste devient exploitable', () {
      final b = BilanRentree(
        aUnPasse: true,
        labelPrecedent: '2025-2026',
        effectifPrecedent: 100,
        reinscritsCetteAnnee: 30,
        eleves: [for (var i = 0; i < 70; i++) _eleve('$i')],
      );
      expect(b.rentreeSaisie, isTrue);
    });

    test('un effectif précédent nul ne déclenche jamais rien', () {
      // Première année de l'établissement : personne ne peut manquer.
      const b = BilanRentree(
        aUnPasse: true,
        labelPrecedent: '2025-2026',
        effectifPrecedent: 0,
        reinscritsCetteAnnee: 0,
        eleves: [],
      );
      expect(b.rentreeSaisie, isFalse);
      expect(b.avancement, 0);
      expect(b.tauxNonRetour, 0); // et surtout : pas de division par zéro
    });

    test('le bilan vide n\'a pas de passé', () {
      expect(BilanRentree.vide.aUnPasse, isFalse);
      expect(BilanRentree.vide.rentreeSaisie, isFalse);
    });
  });

  group('Taux de non-retour', () {
    test('se lit sur l\'effectif de référence, pas sur les réinscrits', () {
      final b = BilanRentree(
        aUnPasse: true,
        labelPrecedent: '2025-2026',
        effectifPrecedent: 868,
        reinscritsCetteAnnee: 700,
        eleves: [for (var i = 0; i < 168; i++) _eleve('$i')],
      );
      expect(b.rentreeSaisie, isTrue);
      expect((b.tauxNonRetour * 1000).round(), 194); // 19,4 %
    });
  });

  group('Décision du conseil', () {
    test('un élève qui devait passer se distingue d\'un redoublant', () {
      // Perdre un élève qui réussissait n'est pas la même histoire : l'écran
      // le signale en rouge, il faut donc que le libellé les sépare.
      const passe = EleveNonRevenu(
        enrollmentId: '1', studentId: 's', firstName: 'A', lastName: 'B',
        className: '6e', decision: 'passe',
      );
      const redouble = EleveNonRevenu(
        enrollmentId: '2', studentId: 's', firstName: 'A', lastName: 'B',
        className: '6e', decision: 'redouble',
      );
      const rien = EleveNonRevenu(
        enrollmentId: '3', studentId: 's', firstName: 'A', lastName: 'B',
        className: '6e',
      );
      expect(passe.decisionLabel, 'Devait passer');
      expect(redouble.decisionLabel, 'Devait redoubler');
      expect(rien.decisionLabel, 'Aucune décision');
    });

    test('le nom se lit NOM Prénom, comme sur les listes officielles', () {
      const e = EleveNonRevenu(
        enrollmentId: '1', studentId: 's', firstName: 'Léontine',
        lastName: 'Bouity', className: '6e',
      );
      expect(e.fullName, 'BOUITY Léontine');
    });
  });
}
