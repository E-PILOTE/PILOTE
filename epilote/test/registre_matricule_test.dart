import 'dart:io';

import 'package:epilote/features/students/providers/registre_matricule_provider.dart';
import 'package:epilote/features/students/services/registre_matricule_pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE REGISTRE MATRICULE
//
//  Un registre réglementaire a deux propriétés, et les deux échouent en
//  silence :
//
//   1. **L'ORDRE.** Un tri de chaînes place « M-10 » avant « M-9 ». Sur un
//      grand livre, cela déplace des lignes de plusieurs pages et fait échouer
//      la recherche d'une inscription précise — le geste même pour lequel on
//      ouvre le registre. Rien ne le signale : le document a l'air normal.
//
//   2. **L'EXHAUSTIVITÉ.** Une ligne manquante ne laisse pas de trou visible :
//      la suivante prend simplement sa place. C'est pourquoi le registre compte
//      ses LACUNES et les écrit sur le document, plutôt que de se prétendre
//      complet.
//
//  S'y ajoute la géométrie : douze colonnes qui débordent ne se voient pas à la
//  première page, mais à la centième — le registre est alors déjà relié.
// ════════════════════════════════════════════════════════════════════════════

void main() {
  // Les polices officielles sont embarquées et se chargent par `rootBundle`.
  TestWidgetsFlutterBinding.ensureInitialized();
  // Les dates du document sont en français ; hors application, les données de
  // locale ne sont pas chargées.
  setUpAll(() => initializeDateFormatting('fr'));

  group('Le grand livre se fabrique vraiment', () {
    LigneRegistre ligne(int i) => LigneRegistre(
          studentId: '$i',
          matricule: 'M-2024/$i',
          lastName: 'NGOMA-MBEMBA',
          firstName: 'Jean-Baptiste Rachël',
          ine: '1234567890$i',
          gender: i.isEven ? 'F' : 'M',
          dateOfBirth: DateTime(2012, 3, 14),
          placeOfBirth: 'Brazzaville, Poto-Poto',
          tuteur: 'KOUMBA Alice-Georgette',
          entreeLe: DateTime(2024, 9, 15),
          classeEntree: '6ème A',
          sortieLe: i % 7 == 0 ? DateTime(2026, 6, 30) : null,
          motifSortie: i % 7 == 0 ? 'transfert' : null,
          archive: i % 11 == 0,
        );

    test('cent-vingt lignes tiennent sur plusieurs pages sans exploser',
        () async {
      // Le vrai risque d'un tableau paginé n'est pas la première page : c'est
      // la rupture. On force donc plusieurs pages, avec des valeurs longues.
      final octets = await RegistreMatriculePdfService.build(
        registre: Registre(
          lignes: [for (var i = 1; i <= 120; i++) ligne(i)],
          lacunes: 0,
        ),
        schoolName: 'Lycée technique de la Révolution',
        city: 'Brazzaville',
        yearLabel: '2025-2026',
      );
      expect(String.fromCharCodes(octets.take(5)), '%PDF-');
      expect(octets.length, greaterThan(5000));
    });

    test('un registre incomplet se fabrique aussi — il porte son alerte',
        () async {
      final octets = await RegistreMatriculePdfService.build(
        registre: Registre(lignes: [ligne(1)], lacunes: 3),
        schoolName: 'CEG Moungali',
      );
      expect(String.fromCharCodes(octets.take(5)), '%PDF-');
    });

    test('un registre vide ne fait pas planter l’édition', () async {
      final octets = await RegistreMatriculePdfService.build(
        registre: const Registre(lignes: [], lacunes: 0),
        schoolName: 'École',
      );
      expect(String.fromCharCodes(octets.take(5)), '%PDF-');
    });
  });

  group('L’ordre du grand livre est celui d’un humain', () {
    test('9 vient avant 10, pas après', () {
      final m = ['M-10', 'M-9', 'M-100', 'M-2']..sort(compareMatricule);
      expect(m, ['M-2', 'M-9', 'M-10', 'M-100']);
    });

    test('les segments alphabétiques comptent aussi', () {
      final m = ['B-1', 'A-10', 'A-2']..sort(compareMatricule);
      expect(m, ['A-2', 'A-10', 'B-1']);
    });

    test('les séparateurs ne changent pas l’ordre des nombres', () {
      final m = ['2024/10', '2024/9', '2023/99']..sort(compareMatricule);
      expect(m, ['2023/99', '2024/9', '2024/10']);
    });

    test('la casse n’entre pas en jeu', () {
      expect(compareMatricule('m-1', 'M-1'), 0);
    });

    test('un matricule vide ne fait pas planter le tri', () {
      final m = ['', 'M-1', '']..sort(compareMatricule);
      expect(m.length, 3);
      expect(m.first, '');
    });

    test('le tri est total : jamais deux éléments « égaux » par accident', () {
      // Deux matricules différents doivent toujours se départager, sinon
      // l'ordre du registre dépend de l'ordre d'arrivée des lignes — donc du
      // hasard de la synchronisation.
      expect(compareMatricule('M-1', 'M-1A'), isNot(0));
      expect(compareMatricule('M-1A', 'M-1'), isNot(0));
    });
  });

  group('La géométrie du document tient sur le papier', () {
    test('les douze colonnes entrent dans une A4 paysage', () {
      final somme = kColonnesRegistre.reduce((a, b) => a + b);
      expect(somme, lessThanOrEqualTo(kLargeurUtileRegistre),
          reason: 'Le tableau déborde de la page : le défaut ne se voit pas à '
              'l’aperçu de la première page, mais à la centième.');
    });

    test('il y a autant d’en-têtes que de colonnes', () {
      expect(kEntetesRegistre.length, kColonnesRegistre.length,
          reason: 'Une colonne sans titre, ou un titre sans colonne, décale '
              'tout le tableau.');
    });

    test('aucune colonne n’est trop étroite pour son titre', () {
      // ~3,6 pt par caractère à 6,5 pt, plus 6 pt de marges internes. En
      // dessous, l'en-tête se tronque et la colonne devient illisible.
      for (var i = 0; i < kEntetesRegistre.length; i++) {
        final besoin = kEntetesRegistre[i].length * 3.6 + 6;
        // Les titres longs se replient sur deux lignes : on tolère la moitié.
        expect(kColonnesRegistre[i], greaterThanOrEqualTo(besoin / 2),
            reason: 'Colonne « ${kEntetesRegistre[i]} » trop étroite.');
      }
    });
  });

  group('Un registre incomplet le DIT', () {
    test('sans lacune, il se déclare complet', () {
      const r = Registre(lignes: [], lacunes: 0);
      expect(r.complet, isTrue);
    });

    test('une seule lacune suffit à le déclarer incomplet', () {
      const r = Registre(lignes: [], lacunes: 1);
      expect(r.complet, isFalse,
          reason: 'Il n’y a pas de « presque complet » pour une pièce '
              'réglementaire.');
    });

    test('le document imprime l’avertissement quand il y a des lacunes', () {
      final src = File(
              'lib/features/students/services/registre_matricule_pdf_service.dart')
          .readAsStringSync().replaceAll('\r\n', '\n');
      expect(src.contains('REGISTRE INCOMPLET'), isTrue);
      expect(src.contains('if (!registre.complet)'), isTrue,
          reason: 'Un registre qui se prétend complet sans l’être est pire '
              'qu’un registre qui déclare sa limite : la seconde se complète, '
              'la première trompe.');
    });

    test('l’écran met l’alerte AVANT le bouton d’impression', () {
      final src =
          File('lib/features/students/screens/registre_matricule_screen.dart')
              .readAsStringSync().replaceAll('\r\n', '\n');
      final iAlerte = src.indexOf('_AlerteLacunes(lacunes:');
      final iEntete = src.indexOf('_Entete(');
      expect(iAlerte, greaterThan(-1));
      expect(iAlerte, lessThan(iEntete),
          reason: 'Un registre incomplet imprimé de bonne foi est le pire '
              'résultat : il porte l’en-tête d’un document réglementaire, et '
              'il ment.');
    });
  });

  group('Une ligne sortie est reconnue comme telle', () {
    LigneRegistre l({DateTime? sortie, String? motif}) => LigneRegistre(
          studentId: '1',
          matricule: 'M-1',
          lastName: 'NGOMA',
          firstName: 'Jean',
          sortieLe: sortie,
          motifSortie: motif,
        );

    test('une date de sortie suffit', () {
      expect(l(sortie: DateTime(2026, 6, 30)).sorti, isTrue);
    });

    test('un motif sans date suffit aussi — la date manque souvent', () {
      expect(l(motif: 'transfert').sorti, isTrue);
    });

    test('ni l’un ni l’autre : l’élève est présent', () {
      expect(l().sorti, isFalse);
      expect(l(motif: '').sorti, isFalse);
    });
  });

  group('L’élève archivé reste au grand livre', () {
    test('les sync-rules ne filtrent plus `is_active` sur students', () {
      final rules =
          File('../powersync/config/sync-rules.yaml').readAsStringSync().replaceAll('\r\n', '\n');
      expect(
        rules.contains(
            'SELECT * FROM students WHERE school_id = bucket.sid AND is_active = true'),
        isFalse,
        reason: '`deactivateStudent` met is_active = 0 : avec ce filtre, '
            'l’élève sort du bucket et DISPARAÎT de tous les postes, dossier '
            'compris. Le registre matricule perdrait sa ligne, et l’école ne '
            's’en apercevrait qu’à l’inspection.',
      );
      expect(
        rules.contains('SELECT * FROM students WHERE school_id = bucket.sid'),
        isTrue,
        reason: 'Les élèves doivent continuer de descendre par école.',
      );
    });

    test('le document marque l’archivé plutôt que de le taire', () {
      final src = File(
              'lib/features/students/services/registre_matricule_pdf_service.dart')
          .readAsStringSync().replaceAll('\r\n', '\n');
      expect(src.contains('(archivé)'), isTrue);
    });
  });
}
