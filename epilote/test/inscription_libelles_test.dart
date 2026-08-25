// Le récapitulatif de l'assistant est le dernier écran lu avant d'enregistrer.
// Il affichait « monoparentale_pere » — le code de base — parce que la table
// des libellés vivait à l'intérieur du widget de saisie, invisible à qui écrit
// l'écran de relecture. Exactement le défaut déjà corrigé pour le lien de
// parenté, qui donnait « (mere) » au même endroit.
//
// Ces tests verrouillent la source unique.

import 'package:epilote/features/students/models/eleve_libelles.dart';
import 'package:epilote/features/students/models/tutor_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('situationFamilialeLabel', () {
    test('traduit chaque code proposé à la saisie', () {
      // La liste déroulante et le récapitulatif lisent la MÊME table : aucun
      // code proposé ne peut donc ressortir non traduit.
      for (final code in kSituationsFamiliales.keys) {
        final libelle = situationFamilialeLabel(code);
        expect(libelle, isNot(code),
            reason: '« $code » ressort brut au récapitulatif');
        expect(libelle, kSituationsFamiliales[code]);
      }
    });

    test('le cas qui a produit le défaut', () {
      expect(situationFamilialeLabel('monoparentale_pere'),
          'Monoparentale (père)');
    });

    test('un champ vide donne un tiret, pas une chaîne vide', () {
      expect(situationFamilialeLabel(null), '—');
      expect(situationFamilialeLabel(''), '—');
      expect(situationFamilialeLabel('   '), '—');
    });

    test('un code inconnu se montre au lieu de disparaître', () {
      // Si la base porte un jour une valeur que l'application ignore, la voir
      // vaut mieux que lire un tiret et croire le champ vide.
      expect(situationFamilialeLabel('garde_alternee'), 'garde_alternee');
    });
  });

  group('Le contact principal est unique', () {
    // ⚠️ La case « Contact principal » se posait sur une seconde fiche sans
    // retirer la première : deux tuteurs partaient en base avec
    // `is_primary_contact`, et plus rien ne disait lequel l'école devait
    // appeler. Elle disparaissait ensuite de l'écran, donc le choix ne pouvait
    // pas être défait.
    //
    // La promotion appartient désormais à la liste. On reproduit sa règle ici :
    // c'est elle qui doit rester vraie.
    void promouvoir(List<TutorDraft> tuteurs, TutorDraft cible) {
      for (final t in tuteurs) {
        t.isPrimary = identical(t, cible);
      }
    }

    test('promouvoir une fiche retire le titre à l\'autre', () {
      final a = TutorDraft(isPrimary: true);
      final b = TutorDraft();
      final tuteurs = [a, b];

      promouvoir(tuteurs, b);

      expect(b.isPrimary, isTrue);
      expect(a.isPrimary, isFalse);
      expect(tuteurs.where((t) => t.isPrimary), hasLength(1));
    });

    test('jamais deux principaux, quel que soit le nombre de fiches', () {
      final tuteurs = [
        TutorDraft(isPrimary: true),
        TutorDraft(),
        TutorDraft(),
      ];

      for (final cible in tuteurs) {
        promouvoir(tuteurs, cible);
        expect(tuteurs.where((t) => t.isPrimary), hasLength(1),
            reason: 'un seul numéro doit rester celui que l\'école appelle');
      }
    });

    test('promouvoir la fiche déjà principale ne retire le titre à personne', () {
      // La case reste affichée sur la fiche principale : la recocher doit être
      // sans effet, jamais laisser l'élève sans contact principal.
      final a = TutorDraft(isPrimary: true);
      final tuteurs = [a, TutorDraft()];

      promouvoir(tuteurs, a);

      expect(a.isPrimary, isTrue);
      expect(tuteurs.where((t) => t.isPrimary), hasLength(1));
    });
  });
}
