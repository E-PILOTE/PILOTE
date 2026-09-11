// Une instruction de tutelle est un ACTE ADMINISTRATIF. Ce qui est gardé ici
// n'est pas de la mise en forme : c'est ce qui rend la pièce opposable — le
// texte intégral, la date de l'envoi, et surtout la liste NOMMÉE de ceux à qui
// elle a été adressée. Un document qui dit « adressé au réseau » n'oppose rien
// à personne.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:epilote/features/tutelle/providers/tutelle_destinataires_provider.dart';
import 'package:epilote/features/tutelle/services/tutelle_instruction_pdf_service.dart';

DestinataireTutelle _admin() => const DestinataireTutelle(
      userId: 'u-admin',
      nom: 'Épiphanie Loubaki',
      fonction: 'Administrateur du groupe',
    );

DestinataireTutelle _chef(String ecole, {String? nom}) => DestinataireTutelle(
      userId: 'u-$ecole',
      nom: nom,
      fonction: 'Proviseur',
      schoolId: 's-$ecole',
      ecole: ecole,
    );

void main() {
  setUpAll(() => initializeDateFormatting('fr'));
  TestWidgetsFlutterBinding.ensureInitialized();

  final emiseLe = DateTime(2026, 9, 10, 9, 30);

  group('L\'instruction se construit — un PDF qui lève ne s\'imprime pas', () {
    test('cas ordinaire : un groupe et trois chefs d\'établissement', () async {
      final octets = await TutelleInstructionPdfService.build(
        objet: 'Rentrée scolaire 2026-2027',
        corps: 'Les établissements placés sous notre tutelle ouvriront leurs '
            'portes le 1er octobre 2026.\n\n'
            'Les effectifs définitifs seront transmis au plus tard le 15.',
        groupeNom: 'Groupe scolaire Thomas Sankara',
        destinataires: [
          _admin(),
          _chef('CEG de Kinkala', nom: 'Marcel Okemba'),
          _chef('Lycée technique', nom: 'Aline Mabiala'),
          _chef('CEG de Boko'),
        ],
        emiseLe: emiseLe,
        tutelle: 'metp',
        signataire: 'Le Directeur de Cabinet',
      );
      expect(octets.lengthInBytes, greaterThan(1000));
    });

    test('un corps LONG ne fait pas boucler la pagination', () async {
      // ⚠️ Le vrai risque de ce document. `frame()` ne sait pas se scinder
      // entre deux pages : un texte de plusieurs feuillets ferait boucler
      // `MultiPage` jusqu'à `TooManyPagesException` — et on n'obtient alors
      // AUCUN document, pas un document tronqué. D'où les paragraphes libres.
      final corps = List.generate(
        60,
        (i) => 'Article ${i + 1} — Les chefs d\'établissement veilleront à la '
            'stricte application des présentes dispositions, et rendront '
            'compte de leur exécution au plus tard à la fin du mois.',
      ).join('\n\n');

      final octets = await TutelleInstructionPdfService.build(
        objet: 'Organisation de l\'année scolaire',
        corps: corps,
        groupeNom: 'Groupe scolaire Thomas Sankara',
        destinataires: [_admin()],
        emiseLe: emiseLe,
        tutelle: 'mepsa',
      );
      expect(octets.lengthInBytes, greaterThan(1000));
    });

    test('trente destinataires tiennent — un groupe privé congolais en a autant',
        () async {
      final octets = await TutelleInstructionPdfService.build(
        objet: 'Contrôle des effectifs',
        corps: 'Transmettre les effectifs arrêtés au 30 septembre.',
        groupeNom: 'Réseau des établissements privés',
        destinataires: [
          _admin(),
          for (var i = 0; i < 30; i++) _chef('Établissement n°$i'),
        ],
        emiseLe: emiseLe,
      );
      expect(octets.lengthInBytes, greaterThan(1000));
    });

    test('les cas dégradés ne font pas échouer la pièce', () async {
      // Un corps vide, aucun destinataire, aucune tutelle, aucun signataire.
      // Le document doit SORTIR quand même : c'est au guichet qu'on
      // s'apercevrait qu'il ne s'imprime pas.
      final octets = await TutelleInstructionPdfService.build(
        objet: 'Objet',
        corps: '   ',
        groupeNom: '—',
        destinataires: const [],
        emiseLe: emiseLe,
      );
      expect(octets.lengthInBytes, greaterThan(1000));
    });
  });

  group('Ce qui fait l\'opposabilité est bien dans le code', () {
    String src() => File(
            'lib/features/tutelle/services/tutelle_instruction_pdf_service.dart')
        .readAsStringSync()
        .replaceAll('\r\n', '\n');

    test('les destinataires sont NOMMÉS, jamais comptés seulement', () {
      final s = src();
      expect(s.contains("titre: 'DESTINATAIRES'"), isTrue,
          reason: 'Sans le bloc nommant les destinataires, la pièce dit '
              '« adressé au réseau » — ce qui n\'oppose rien à personne.');
      expect(s.contains('_nomEtFonction'), isTrue);
    });

    test('la pièce ne prétend PAS valoir accusé de réception', () {
      final s = src();
      expect(s.contains('ne vaut pas accusé de réception'), isTrue,
          reason: 'La plateforme n\'établit pas la lecture d\'un message. '
              'Laisser croire le contraire sous un en-tête de la République '
              'lui ferait porter une attestation qu\'elle ne peut pas tenir.');
    });

    test('la date portée est celle de l\'ENVOI, pas de l\'impression', () {
      final s = src();
      expect(s.contains('required DateTime emiseLe'), isTrue);
      expect(s.contains('DateTime.now()'), isFalse,
          reason: 'Une réimpression trois mois plus tard doit rendre la même '
              'date : le document ne lit jamais l\'horloge lui-même.');
    });

    test('le corps n\'est pas enfermé dans un `frame()`', () {
      final s = src();
      // `frame()` ne se scinde pas entre deux pages. On n'interdit pas son
      // usage — les blocs courts l'utilisent — mais le TEXTE, lui, doit rester
      // en paragraphes libres.
      expect(s.contains('_paragraphes(corps)'), isTrue,
          reason: 'Le texte de l\'instruction doit se couper naturellement '
              'entre les pages, sinon un long acte ne sort pas du tout.');
    });

    test('la pièce est émise par le MINISTÈRE, jamais par l\'éditeur', () {
      final s = src();
      expect(s.contains('OfficialPdfKit.issuer'), isTrue);
      expect(s.contains('OfficialPdfKit.headerFor'), isTrue);
      expect(s.contains('Printing.layoutPdf('), isFalse,
          reason: 'L\'impression directe est bannie des écrans : tout passe '
              'par `showPdfPreviewDialog`.');
    });
  });

  group('L\'archive est proposée au bon moment', () {
    String dialogue() =>
        File('lib/features/tutelle/widgets/tutelle_message_dialog.dart')
            .readAsStringSync()
            .replaceAll('\r\n', '\n');

    test('elle suit l\'envoi, et passe par l\'aperçu partagé', () {
      final s = dialogue();
      expect(s.contains('_proposerArchive'), isTrue);
      expect(s.contains('showPdfPreviewDialog'), isTrue);
    });

    test('objet, corps et destinataires sont capturés AVANT le `pop`', () {
      final s = dialogue();
      final captureObjet = s.indexOf('final objet = _objet.text.trim();');
      final pop = s.indexOf('Navigator.of(context).pop();');
      expect(captureObjet, greaterThan(-1),
          reason: 'La capture a été renommée ou retirée.');
      expect(captureObjet, lessThan(pop),
          reason: '`dispose()` vide les contrôleurs dès la fermeture de la '
              'modale : lus après, l\'objet et le corps seraient vides sur la '
              'pièce, et personne ne le verrait avant l\'impression.');
    });

    test('un échec d\'archive ne se confond pas avec un échec d\'envoi', () {
      final s = dialogue();
      expect(s.contains("Message envoyé. L'archive n'a pas pu être produite"),
          isTrue,
          reason: 'Le message EST parti. Un message d\'erreur ambigu ferait '
              'renvoyer l\'instruction une seconde fois.');
    });
  });
}
