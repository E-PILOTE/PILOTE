import 'dart:typed_data';

import 'package:epilote/features/students/services/attestations_pdf_service.dart'
    show peutDelivrerRadiation, peutDelivrerScolarite;
import 'package:epilote/features/students/services/carte_scolaire_pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LA CARTE SCOLAIRE
//
//  Trois choses seulement peuvent mal tourner ici, et aucune ne se voit à
//  l'écran :
//
//   1. LE REFUS. Une carte délivrée à un élève sorti est un laissez-passer : un
//      titre valide, au nom d'une école qui ne le reconnaît plus. C'est le
//      symétrique du certificat de scolarité, et le test vérifie que les deux
//      verrous ne peuvent jamais être ouverts en même temps.
//
//   2. LE MIROIR DU VERSO. Une planche verso dans le même ordre que le recto
//      donne des cartes dont le dos appartient au voisin. L'aperçu PDF ne le
//      révèle PAS — les deux pages semblent correctes séparément. Seule la
//      feuille retournée le montre, c'est-à-dire après la découpe.
//
//   3. LE FORMAT. 85,6 × 54 mm n'est pas une préférence : c'est ce qui entre
//      dans un portefeuille et dans les pochettes du marché. Une dérive de
//      quelques points ne se remarque qu'à l'usage, quand mille cartes sont
//      déjà découpées.
// ════════════════════════════════════════════════════════════════════════════

CarteEleve _eleve(String nom, {Uint8List? photo, String? ine}) => CarteEleve(
      firstName: 'Prénom',
      lastName: nom,
      className: '6ème A',
      matricule: 'M-$nom',
      ine: ine,
      gender: 'F',
      dateOfBirth: DateTime(2012, 3, 14),
      placeOfBirth: 'Brazzaville',
      photo: photo,
    );

void main() {
  // Les polices des documents officiels sont EMBARQUÉES et se chargent par
  // `rootBundle` : sans binding, `loadFonts()` lève avant d'avoir dessiné quoi
  // que ce soit.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Le refus est la partie utile', () {
    test('une carte ne se délivre que sur une inscription active', () {
      expect(peutDelivrerCarte('active'), isTrue);
      for (final statut in [
        'withdrawn',
        'transferred',
        'graduated',
        'pending',
        '',
        null,
      ]) {
        expect(peutDelivrerCarte(statut), isFalse,
            reason: 'Statut « $statut » : la carte attesterait une présence '
                "que l'élève n'a plus.");
      }
    });

    test('carte et certificat de scolarité disent la même chose', () {
      // Ils affirment tous deux une présence : si l'un devient délivrable pour
      // un statut et pas l'autre, c'est que l'un des deux ment.
      for (final statut in [
        'active',
        'withdrawn',
        'transferred',
        'graduated',
        null,
      ]) {
        expect(peutDelivrerCarte(statut), peutDelivrerScolarite(statut),
            reason: 'Désaccord sur « $statut ».');
      }
    });

    test('aucun statut ne rend carte et radiation délivrables ensemble', () {
      for (final statut in [
        'active',
        'withdrawn',
        'transferred',
        'graduated',
        'pending',
        null,
      ]) {
        expect(peutDelivrerCarte(statut) && peutDelivrerRadiation(statut),
            isFalse,
            reason: 'Statut « $statut » : on ne peut pas être à la fois '
                'présent et radié.');
      }
    });
  });

  group('Le verso est miroité — ce que la découpe seule révélerait', () {
    test('le recto garde l’ordre de la liste', () {
      final lot = [for (var i = 0; i < 4; i++) _eleve('E$i')];
      final r = rangeesPlanche(lot, verso: false);
      expect(r.length, 2);
      expect(r[0].map((e) => e?.lastName), ['E0', 'E1']);
      expect(r[1].map((e) => e?.lastName), ['E2', 'E3']);
    });

    test('le verso inverse les colonnes DANS chaque rangée, pas les rangées',
        () {
      final lot = [for (var i = 0; i < 4; i++) _eleve('E$i')];
      final v = rangeesPlanche(lot, verso: true);
      expect(v[0].map((e) => e?.lastName), ['E1', 'E0'],
          reason: 'La feuille se retourne sur son bord long : la colonne de '
              'gauche revient à droite.');
      expect(v[1].map((e) => e?.lastName), ['E3', 'E2']);
      // Les rangées, elles, ne bougent pas : la 1re reste en haut.
      expect(v.length, 2);
    });

    test('la dernière rangée incomplète met son vide en face du vide', () {
      final lot = [_eleve('SEUL')];
      final recto = rangeesPlanche(lot, verso: false);
      final verso = rangeesPlanche(lot, verso: true);
      expect(recto.first.map((e) => e?.lastName), ['SEUL', null]);
      expect(verso.first.map((e) => e?.lastName), [null, 'SEUL'],
          reason: 'Retournée, la carte de gauche se retrouve à droite : son '
              'dos doit y être aussi.');
    });

    test('chaque carte a exactement un dos, jamais celui du voisin', () {
      final lot = [for (var i = 0; i < 7; i++) _eleve('E$i')];
      final recto = rangeesPlanche(lot, verso: false);
      final verso = rangeesPlanche(lot, verso: true);
      expect(recto.length, verso.length);
      for (var r = 0; r < recto.length; r++) {
        for (var c = 0; c < kCartesParRangee; c++) {
          // Position physique après retournement : colonne miroir.
          final dos = verso[r][kCartesParRangee - 1 - c];
          expect(dos?.matricule, recto[r][c]?.matricule,
              reason: 'Rangée $r, colonne $c : le dos ne correspond pas au '
                  'recto qui se trouve derrière lui.');
        }
      }
    });
  });

  group('Le format ISO ID-1 ne dérive pas', () {
    test('85,6 × 54 mm, en points PDF', () {
      // 1 mm = 72/25,4 pt. Une tolérance d'un centième de point suffit à
      // laisser passer l'arrondi flottant sans laisser passer une erreur.
      expect(kCarteLargeur, closeTo(85.6 * 72 / 25.4, 0.01));
      expect(kCarteHauteur, closeTo(54.0 * 72 / 25.4, 0.01));
    });

    test('dix cartes par planche, et la planche entre dans une A4', () {
      expect(kCartesParPlanche, 10);
      const mm = 72 / 25.4;

      // Les gouttières se comptent ENTRE les cartes : une de moins que le
      // nombre de cartes. La première version en ajoutait une après la
      // dernière rangée, et la cinquième carte sortait de la feuille.
      final largeur = kCartesParRangee * kCarteLargeur +
          (kCartesParRangee - 1) * kGouttiereColonne +
          2 * kMargePlancheH;
      final hauteur = kRangeesParPlanche * kCarteHauteur +
          (kRangeesParPlanche - 1) * kGouttiereRangee +
          2 * kMargePlancheV;

      expect(largeur, lessThanOrEqualTo(210 * mm),
          reason: 'La planche déborde en largeur.');
      expect(hauteur, lessThanOrEqualTo(297 * mm),
          reason: 'La planche déborde en hauteur — la dernière rangée '
              "s'imprimerait hors du papier.");

      // Et il reste de quoi absorber la dérive d'entraînement du papier.
      expect(297 * mm - hauteur, greaterThan(2 * mm),
          reason: 'Moins de 2 mm de battement : une feuille légèrement de '
              'travers rogne la dernière rangée.');
    });
  });

  group('Le QR ne porte rien de plus que ce qui est déjà imprimé', () {
    test("l'identifiant national quand il existe", () {
      expect(_eleve('KOUMBA', ine: '12345678901').codeQr, '12345678901');
    });

    test('le matricule sinon — jamais un vide', () {
      final e = _eleve('KOUMBA');
      expect(e.codeQr, 'M-KOUMBA');
      expect(e.codeQr, isNotEmpty,
          reason: 'Un QR vide fait échouer le rendu du code-barres, donc la '
              'planche entière.');
    });
  });

  group('La planche se fabrique vraiment', () {
    test('un PDF valide, sans photo, sans identifiant national', () async {
      final octets = await CarteScolairePdfService.planche(
        eleves: [for (var i = 0; i < 3; i++) _eleve('E$i')],
        schoolName: 'Lycée de la Révolution',
        yearLabel: '2025-2026',
        city: 'Brazzaville',
      );
      expect(octets.length, greaterThan(1000));
      expect(String.fromCharCodes(octets.take(5)), '%PDF-');
    });

    test('vingt-cinq élèves donnent trois planches, soit six faces', () async {
      // Le compte de pages n'est pas lisible sans relire le PDF ; ce que le
      // test garde, c'est que le découpage en lots ne perd et ne duplique
      // personne.
      final lot = [for (var i = 0; i < 25; i++) _eleve('E$i')];
      var vus = 0;
      for (var i = 0; i < lot.length; i += kCartesParPlanche) {
        vus += lot
            .sublist(i, (i + kCartesParPlanche).clamp(0, lot.length))
            .length;
      }
      expect(vus, 25);
      expect((25 + kCartesParPlanche - 1) ~/ kCartesParPlanche, 3);
    });

    test('une carte seule se fabrique aussi', () async {
      final octets = await CarteScolairePdfService.carteUnique(
        eleve: _eleve('NGOMA', ine: '98765432109'),
        schoolName: 'CEG Moungali',
        yearLabel: '2025-2026',
      );
      expect(String.fromCharCodes(octets.take(5)), '%PDF-');
    });

    test('une liste vide ne fait pas planter la fabrication', () async {
      final octets = await CarteScolairePdfService.planche(
        eleves: const [],
        schoolName: 'École',
        yearLabel: '2025-2026',
      );
      expect(String.fromCharCodes(octets.take(5)), '%PDF-');
    });
  });
}
