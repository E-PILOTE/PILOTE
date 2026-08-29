import 'dart:typed_data';

import 'package:epilote/core/utils/media_compression.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// ════════════════════════════════════════════════════════════════════════════
//  LE LOGO EMBARQUÉ DANS CHAQUE DOCUMENT
//
//  ── CE QU'ON NE VOIT PAS EN REGARDANT UN PDF ───────────────────────────────
//  Un PDF n'a pas de filtre PNG. Une image PNG posée dans un document n'y est
//  donc pas rangée telle quelle : elle est DÉCODÉE en pixels bruts, puis
//  recompressée en Flate. Le poids final suit le nombre de PIXELS, pas le poids
//  du fichier source — un logo PNG de 2 Ko peut coûter 95 Ko dans le document.
//
//  Et il le coûte dans CHAQUE document que l'école produit : bulletins,
//  convocations, attestations, listes. Un logo deux fois trop grand coûte
//  quatre fois trop cher, indéfiniment.
//
//  Le plus grand emplacement de logo du dépôt fait 54 pt (en-tête officiel) :
//  256 px y valent ~340 dpi, au-dessus de ce qu'une imprimante rend. Les 512 px
//  gardés pour l'interface n'y apporteraient rien de visible.
// ════════════════════════════════════════════════════════════════════════════

/// Un dégradé — le pire cas réaliste pour la compression. Un aplat serait
/// trompeusement léger et le test ne prouverait rien.
Uint8List _pngDegrade(int cote, {bool transparent = false}) {
  final im = img.Image(width: cote, height: cote, numChannels: 4);
  for (var y = 0; y < cote; y++) {
    for (var x = 0; x < cote; x++) {
      im.setPixelRgba(x, y, x * 255 ~/ cote, y * 255 ~/ cote, 128,
          transparent && x < cote ~/ 2 ? 0 : 255);
    }
  }
  return Uint8List.fromList(img.encodePng(im));
}

Future<int> _poidsPdfAvec(Uint8List logo) async {
  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (_) => pw.SizedBox(
        width: 54,
        height: 54,
        child: pw.Image(pw.MemoryImage(logo)),
      ),
    ),
  );
  return (await doc.save()).length;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('compressLogoForPdf réduit ce qui doit l’être', () {
    test('un logo trop grand descend à kMaxPdfLogoEdge', () async {
      final reduit = await compressLogoForPdf(_pngDegrade(512));
      final im = img.decodeImage(reduit)!;
      expect(im.width, kMaxPdfLogoEdge);
      expect(im.height, kMaxPdfLogoEdge);
    });

    test('un PNG opaque part en JPEG, MÊME s’il grossit sur le disque',
        () async {
      // ⚠️ Le piège qui a fait échouer la première version de ce code : un
      // dégradé se compresse admirablement en PNG (2 Ko) et médiocrement en
      // JPEG (8 Ko). Comparer les FICHIERS conduirait à garder le PNG — et à
      // payer 95 Ko dans chaque document au lieu de 20.
      final source = _pngDegrade(512);
      final sortie = await compressLogoForPdf(source);
      expect(sortie[0], 0xFF, reason: 'Un JPEG commence par FF D8.');
      expect(sortie[1], 0xD8);
    });

    test('un JPEG déjà petit ressort INCHANGÉ, octet pour octet', () async {
      final im = img.Image(width: 128, height: 128);
      img.fill(im, color: img.ColorRgb8(30, 58, 95));
      final source = Uint8List.fromList(img.encodeJpg(im, quality: 85));
      expect(await compressLogoForPdf(source), equals(source),
          reason: 'Ré-encoder un JPEG en JPEG ne fait qu’ajouter une '
              'génération de pertes.');
    });

    test('un PNG détouré déjà petit ressort INCHANGÉ', () async {
      final source = _pngDegrade(128, transparent: true);
      expect(await compressLogoForPdf(source), equals(source));
    });

    test('des octets illisibles ressortent tels quels', () async {
      final poubelle = Uint8List.fromList([0, 1, 2, 3]);
      expect(await compressLogoForPdf(poubelle), equals(poubelle),
          reason: 'Un document sans logo vaut mieux qu’un document qui '
              'n’existe pas.');
    });
  });

  group('Un logo détouré reste détouré', () {
    test('la transparence survit à la réduction', () async {
      final reduit =
          await compressLogoForPdf(_pngDegrade(512, transparent: true));
      final im = img.decodeImage(reduit)!;
      expect(im.hasAlpha, isTrue,
          reason: 'Aplatir sur du blanc poserait un carré blanc sur le '
              'bandeau tricolore de l’en-tête officiel.');
      var transparent = false;
      for (final p in im) {
        if (p.a < 250) {
          transparent = true;
          break;
        }
      }
      expect(transparent, isTrue);
    });
  });

  group('Le gain se voit sur le document produit', () {
    test('le même logo réduit allège nettement chaque PDF', () async {
      final grand = _pngDegrade(512);
      final avant = await _poidsPdfAvec(grand);
      final apres = await _poidsPdfAvec(await compressLogoForPdf(grand));

      expect(apres, lessThan(avant * 0.5),
          reason: 'Mesuré à l’écriture de ce garde : 95 Ko pour le PNG 512 px, '
              '20 Ko une fois réduit et passé en JPEG. Si ce rapport '
              's’effondre, le greffon PDF a changé sa façon de stocker les '
              'images — et le seuil de $kMaxPdfLogoEdge px mérite d’être '
              'recalculé.');
    });

    test('un logo pèse plus que la page qui le porte — d’où ce garde',
        () async {
      final vide = await (pw.Document()
            ..addPage(pw.Page(
              pageFormat: PdfPageFormat.a4,
              build: (_) => pw.SizedBox(),
            )))
          .save();
      final avecLogo = await _poidsPdfAvec(_pngDegrade(512));
      expect(avecLogo, greaterThan(vide.length * 10),
          reason: 'Ce n’est pas une micro-optimisation : l’image domine le '
              'poids du document.');
    });
  });
}
