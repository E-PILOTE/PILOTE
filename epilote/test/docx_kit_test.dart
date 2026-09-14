// Un `.docx` est une archive ZIP de fichiers XML. Quand il lui manque une
// pièce, Word n'annonce pas laquelle : il dit « le fichier est corrompu », et
// c'est tout. Aucun écran ne montrera jamais ce défaut — il ne se voit que
// chez le destinataire, après l'envoi.
//
// Ce test rouvre donc l'archive produite et vérifie ce qu'un lecteur Word
// vérifie : les quatre parties obligatoires, un corps qui ne se termine pas
// par un tableau, et l'échappement de ce qui casserait le XML.

import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:epilote/core/services/docx_kit.dart';
import 'package:flutter_test/flutter_test.dart';

Archive _ouvrir(List<int> octets) => ZipDecoder().decodeBytes(octets);

String _partie(Archive a, String nom) {
  final f = a.files.firstWhere(
    (x) => x.name == nom,
    orElse: () => throw StateError('Partie absente de l\'archive : $nom'),
  );
  return utf8.decode(f.content as List<int>);
}

void main() {
  group("L'archive porte tout ce qu'un lecteur Word exige", () {
    test('les quatre parties obligatoires sont présentes', () {
      final d = DocxBuilder(titre: 'Rapport')..paragraphe('Bonjour');
      final a = _ouvrir(d.construire());
      final noms = a.files.map((f) => f.name).toSet();

      // Il en manque une seule et Word annonce « fichier corrompu » sans dire
      // laquelle.
      expect(noms, contains('[Content_Types].xml'));
      expect(noms, contains('_rels/.rels'));
      expect(noms, contains('word/document.xml'));
      expect(noms, contains('word/styles.xml'));
    });

    test('le document principal est bien déclaré et relié', () {
      final a = _ouvrir((DocxBuilder(titre: 'T')..paragraphe('x')).construire());
      expect(_partie(a, '[Content_Types].xml'), contains('/word/document.xml'));
      expect(_partie(a, '_rels/.rels'), contains('Target="word/document.xml"'));
    });

    test('chaque style référencé par le corps est réellement défini', () {
      // ⚠️ Un `pStyle` qui pointe sur un style ABSENT n'est pas une erreur
      // pour Word : il l'ignore en silence et sort tout en corps de texte.
      // C'est le genre de défaut qu'on ne voit qu'à l'impression.
      final d = DocxBuilder(titre: 'T', sousTitre: 'S', etablissement: 'E')
        ..section('Une section')
        ..paragraphe('Un paragraphe')
        ..mention('Une mention');
      final a = _ouvrir(d.construire());
      final corps = _partie(a, 'word/document.xml');
      final styles = _partie(a, 'word/styles.xml');

      final references = RegExp(r'w:pStyle w:val="([A-Za-z]+)"')
          .allMatches(corps)
          .map((m) => m.group(1)!)
          .toSet();
      expect(references, isNotEmpty);
      for (final r in references) {
        expect(styles, contains('w:styleId="$r"'),
            reason: 'Le style « $r » est utilisé mais jamais défini : Word '
                'sortira ce passage en corps de texte, sans rien signaler.');
      }
    });
  });

  group('Le corps respecte ce que Word ne pardonne pas', () {
    test('un document qui finit par un tableau finit quand même par un '
        'paragraphe', () {
      // Un corps terminé par `</w:tbl>` ouvre Word en mode récupération.
      final d = DocxBuilder(titre: 'T')
        ..tableau(entetes: const ['A', 'B'], lignes: const [
          ['1', '2'],
        ]);
      final corps =
          _partie(_ouvrir(d.construire()), 'word/document.xml');
      final finCorps = corps.substring(corps.lastIndexOf('</w:tbl>'));
      expect(finCorps, contains('<w:p>'));
      expect(corps.indexOf('<w:sectPr>'), greaterThan(corps.lastIndexOf('</w:tbl>')));
    });

    test('deux tableaux consécutifs ne fusionnent pas', () {
      final d = DocxBuilder(titre: 'T')
        ..tableau(entetes: const ['A'], lignes: const [
          ['1'],
        ])
        ..tableau(entetes: const ['B'], lignes: const [
          ['2'],
        ]);
      final corps = _partie(_ouvrir(d.construire()), 'word/document.xml');
      // Entre `</w:tbl>` et le `<w:tbl>` suivant il DOIT y avoir un
      // paragraphe : sans lui, Word n'en voit qu'un seul tableau.
      final entreDeux = corps.substring(
        corps.indexOf('</w:tbl>'),
        corps.lastIndexOf('<w:tbl>'),
      );
      expect(entreDeux, contains('<w:p>'));
    });

    test('une ligne plus courte que ses en-têtes est complétée', () {
      // Une cellule manquante décale toute la table chez Word, sans erreur.
      final d = DocxBuilder(titre: 'T')
        ..tableau(entetes: const ['A', 'B', 'C'], lignes: const [
          ['1'],
        ]);
      final corps = _partie(_ouvrir(d.construire()), 'word/document.xml');
      final ligne = corps.substring(corps.lastIndexOf('<w:tr>'));
      expect('<w:tc>'.allMatches(ligne).length, 3);
    });

    test('un tableau vide devient une phrase, pas une table sans ligne', () {
      final d = DocxBuilder(titre: 'T')
        ..tableau(
          entetes: const ['A'],
          lignes: const [],
          siVide: 'Aucune sanction enregistrée.',
        );
      final corps = _partie(_ouvrir(d.construire()), 'word/document.xml');
      expect(corps, isNot(contains('<w:tbl>')));
      expect(corps, contains('Aucune sanction enregistrée.'));
    });
  });

  group("Le texte de l'école ne casse pas le XML", () {
    test('les caractères réservés sont échappés', () {
      final d = DocxBuilder(titre: 'Collège & Lycée')
        ..paragraphe('Moyenne < 10 > seuil, dit "insuffisant"');
      final corps = _partie(_ouvrir(d.construire()), 'word/document.xml');

      expect(corps, contains('Collège &amp; Lycée'));
      expect(corps, contains('&lt; 10 &gt;'));
      // Aucun « & » nu ne doit subsister : c'est ce qui rend l'archive
      // illisible d'un bout à l'autre.
      expect(RegExp(r'&(?!amp;|lt;|gt;|quot;)').hasMatch(corps), isFalse);
    });

    test('un caractère de contrôle collé depuis un autre logiciel est retiré',
        () {
      final d = DocxBuilder(titre: 'T')..paragraphe('NGOMA Aïcha');
      final corps = _partie(_ouvrir(d.construire()), 'word/document.xml');
      expect(corps, contains('NGOMA Aïcha'));
      expect(corps.contains(''), isFalse);
    });

    test('un retour à la ligne devient un saut de ligne Word', () {
      final d = DocxBuilder(titre: 'T')..paragraphe('Ligne 1\nLigne 2');
      final corps = _partie(_ouvrir(d.construire()), 'word/document.xml');
      expect(corps, contains('<w:br/>'));
      expect(corps, contains('Ligne 1'));
      expect(corps, contains('Ligne 2'));
    });

    test('les espaces de début et de fin sont préservés', () {
      // `xml:space="preserve"` : sans lui, Word mange les espaces et « Fait à
      // Brazzaville, le …… » se recolle.
      final corps = _partie(
        _ouvrir((DocxBuilder(titre: 'T')..paragraphe('  marge  ')).construire()),
        'word/document.xml',
      );
      expect(corps, contains('xml:space="preserve"'));
    });
  });

  group("L'orientation suit ce qu'on lui demande", () {
    test('le portrait est le défaut', () {
      final corps =
          _partie(_ouvrir(DocxBuilder(titre: 'T').construire()), 'word/document.xml');
      expect(corps, contains('w:w="11906"'));
      expect(corps, isNot(contains('landscape')));
    });

    test('le paysage se porte dans sectPr, pas par page', () {
      final corps = _partie(
        _ouvrir(DocxBuilder(titre: 'T', paysage: true).construire()),
        'word/document.xml',
      );
      expect(corps, contains('w:orient="landscape"'));
    });
  });

  group("L'en-tête nomme l'établissement", () {
    test("le nom de l'école figure dans le document quand il est fourni", () {
      // Une pièce qui sort de l'école doit dire de quelle école elle vient —
      // défaut déjà corrigé sur les PDF.
      final corps = _partie(
        _ouvrir(DocxBuilder(
          titre: 'Attestation',
          etablissement: 'Lycée de la Révolution',
        ).construire()),
        'word/document.xml',
      );
      expect(corps, contains('Lycée de la Révolution'));
    });
  });
}
