import 'package:flutter_test/flutter_test.dart';

import 'package:epilote/features/students/models/tutor_draft.dart';

/// ══════════════════════════════════════════════════════════════════════════
///  ÉTAPE « PARENTS » DE L'INSCRIPTION — la fiche qui disparaissait.
///
///  L'écran marque Prénom, Nom et Téléphone d'une étoile ; rien ne les
///  vérifiait. À l'enregistrement, une boucle sautait toute fiche incomplète :
///  saisir le numéro de la mère sans son nom de famille produisait un dossier
///  d'élève SANS AUCUN CONTACT, validé, sans message. Au Congo, ce numéro est
///  le seul lien entre l'école et la famille.
///
///  Aucun essai à l'écran ne montre ce défaut : le dossier se crée, l'élève
///  apparaît, tout va bien. D'où ces tests.
/// ══════════════════════════════════════════════════════════════════════════

TutorDraft _t({
  String first = '',
  String last = '',
  String phone = '',
  String? email,
  bool primary = false,
}) =>
    TutorDraft(isPrimary: primary)
      ..firstName = first
      ..lastName = last
      ..phonePrimary = phone
      ..email = email;

void main() {
  group('TutorDraft — vierge ou complète', () {
    test('la fiche posée d\'office à l\'ouverture est vierge', () {
      expect(TutorDraft(isPrimary: true).isBlank, isTrue);
    });

    test('un seul champ saisi suffit à ne plus être vierge', () {
      expect(_t(phone: '06').isBlank, isFalse);
      expect(_t(first: 'Marie').isBlank, isFalse);
      expect(_t(email: 'a@b.cg').isBlank, isFalse);
    });

    test('des espaces ne remplissent pas une fiche', () {
      expect(_t(first: '   ', last: '  ', phone: ' ').isBlank, isTrue);
    });

    test('complète = prénom + nom + téléphone', () {
      expect(_t(first: 'Marie', last: 'Nkounkou', phone: '066112233').isComplete,
          isTrue);
      expect(_t(first: 'Marie', phone: '066112233').isComplete, isFalse);
      expect(_t(first: 'Marie', last: 'Nkounkou').isComplete, isFalse);
    });
  });

  group('validateTutorDrafts — ce qui bloque et ce qui passe', () {
    test('aucune fiche remplie : refus (un élève doit avoir un contact)', () {
      final err = validateTutorDrafts([TutorDraft(isPrimary: true)]);
      expect(err, isNotNull);
      expect(err, contains('au moins un parent'));
    });

    test('LE cas du défaut : téléphone saisi, nom oublié → refus nommé', () {
      // Avant, cette fiche était silencieusement jetée et l'inscription
      // s'enregistrait sans contact.
      final err = validateTutorDrafts([
        _t(first: 'Marie', phone: '066112233', primary: true),
      ]);
      expect(err, isNotNull);
      expect(err, contains('La fiche de Marie'),
          reason: 'le message doit désigner la fiche fautive');
      expect(err, isNot(contains('incomplet :')),
          reason: 'accord neutre : on ne déduit pas le genre d\'un prénom');
      expect(err, contains('téléphone'));
    });

    test('une fiche complète passe', () {
      expect(
        validateTutorDrafts(
            [_t(first: 'Marie', last: 'Nkounkou', phone: '066112233')]),
        isNull,
      );
    });

    test('une fiche complète + une jamais touchée : passe', () {
      // Le bouton « Ajouter un tuteur » en laisse souvent une vide derrière.
      expect(
        validateTutorDrafts([
          _t(first: 'Marie', last: 'Nkounkou', phone: '066112233'),
          TutorDraft(),
        ]),
        isNull,
      );
    });

    test('une deuxième fiche entamée mais incomplète bloque aussi', () {
      final err = validateTutorDrafts([
        _t(first: 'Marie', last: 'Nkounkou', phone: '066112233'),
        _t(last: 'Loemba'),
      ]);
      expect(err, isNotNull);
      expect(err, contains('Loemba'));
    });
  });

  group('tutorsToPersist — rien ne se perd', () {
    test('n\'enregistre que les fiches remplies', () {
      final complete = _t(first: 'Marie', last: 'Nkounkou', phone: '066112233');
      final out = tutorsToPersist([complete, TutorDraft(), TutorDraft()]);
      expect(out, [complete]);
    });

    test('une fiche partielle N\'EST PAS écartée ici', () {
      // La garde est à l'étape 2. Si une fiche partielle arrivait quand même
      // jusqu'ici, elle doit être enregistrée — pas disparaître. Le filtrage
      // silencieux à cet endroit était la cause exacte de la perte.
      final partial = _t(first: 'Marie', phone: '066112233');
      expect(tutorsToPersist([partial]), [partial]);
    });
  });
}
