import 'dart:typed_data';

import 'package:epilote/core/utils/media_compression.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

// ════════════════════════════════════════════════════════════════════════════
//  COMPRESSION AVANT UPLOAD
//
//  Ce que ces tests protègent : la donnée de l'utilisateur. Une compression
//  trop zélée détruit un acte de naissance ; une compression absente fait
//  transférer 8 Mo sur une connexion congolaise pour afficher 38 pixels. Les
//  deux erreurs se paient, dans des sens opposés.
// ════════════════════════════════════════════════════════════════════════════

/// Une image de [w]×[h] au contenu peu compressible.
///
/// ⚠️ Un dégradé régulier tient dans quelques kilo-octets une fois en PNG, et
/// passe alors SOUS `kImageCompressFloor` : la fonction le renvoie intact et le
/// test ne teste plus rien. On génère donc un bruit pseudo-aléatoire
/// déterministe, qui pèse comme une vraie photo.
Uint8List _png(int w, int h, {bool transparent = false}) {
  final im = img.Image(width: w, height: h, numChannels: 4);
  var seed = 12345;
  int next() {
    seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
    return (seed >> 16) & 0xFF;
  }

  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      im.setPixelRgba(x, y, next(), next(), next(),
          transparent && x < w ~/ 2 ? 0 : 255);
    }
  }
  return Uint8List.fromList(img.encodePng(im));
}

void main() {
  group('Type MIME d\'après l\'extension', () {
    test('jpg devient image/jpeg, jamais image/jpg', () {
      // `image/jpg` n'existe pas. Plusieurs écrans composaient le type à la
      // main en collant l'extension derrière « image/ ».
      expect(mimeForImageExtension('jpg'), 'image/jpeg');
      expect(mimeForImageExtension('JPEG'), 'image/jpeg');
    });

    test('svg porte son suffixe +xml', () {
      expect(mimeForImageExtension('svg'), 'image/svg+xml');
    });

    test('le point de tête est toléré', () {
      expect(mimeForImageExtension('.png'), 'image/png');
    });

    test('extension absente : type binaire générique, pas de « image/ » vide',
        () {
      expect(mimeForImageExtension(null), 'application/octet-stream');
      expect(mimeForImageExtension(''), 'application/octet-stream');
    });
  });

  group('Logo', () {
    test('un grand logo est réduit et allégé', () {
      final source = _png(2000, 2000);
      final out = compressLogoBytes(
          bytes: source, fileName: 'logo.png', mime: 'image/png');
      expect(out.bytes.length, lessThan(source.length));
      final decoded = img.decodeImage(out.bytes)!;
      expect(decoded.width, lessThanOrEqualTo(kMaxLogoEdge));
      expect(decoded.height, lessThanOrEqualTo(kMaxLogoEdge));
    });

    test('un logo détouré garde sa transparence — donc reste en PNG', () {
      // Ré-encoder un logo détouré en JPEG lui colle un fond noir : sur la
      // carte nationale, chaque marqueur deviendrait un carré.
      final source = _png(1200, 1200, transparent: true);
      final out = compressLogoBytes(
          bytes: source, fileName: 'logo.png', mime: 'image/png');
      expect(out.mime, 'image/png');
      expect(out.fileName, endsWith('.png'));
      expect(img.decodeImage(out.bytes)!.hasAlpha, isTrue);
    });

    test('un logo opaque part en JPEG, plus léger à rendu égal', () {
      final source = _png(1200, 1200);
      final out = compressLogoBytes(
          bytes: source, fileName: 'logo.png', mime: 'image/png');
      expect(out.mime, 'image/jpeg');
      expect(out.fileName, endsWith('.jpg'));
    });

    test('un fichier indécodable passe intact plutôt que de bloquer l\'envoi',
        () {
      // Un SVG, un format exotique, un fichier tronqué : on ne refuse pas
      // l'upload, on transfère tel quel.
      final junk = Uint8List.fromList(List.filled(9000, 42));
      final out = compressLogoBytes(
          bytes: junk, fileName: 'logo.svg', mime: 'image/svg+xml');
      expect(out.bytes, same(junk));
      expect(out.mime, 'image/svg+xml');
    });

    test('un logo déjà petit n\'est pas alourdi par le passage', () {
      final source = _png(64, 64);
      final out = compressLogoBytes(
          bytes: source, fileName: 'logo.png', mime: 'image/png');
      expect(out.bytes.length, lessThanOrEqualTo(source.length));
    });
  });

  group('Image de contenu', () {
    test('une photo est ramenée au plus long côté cible', () {
      final source = _png(3000, 1500);
      final out = compressImageBytes(
          bytes: source, fileName: 'scan.png', mime: 'image/png');
      final decoded = img.decodeImage(out.bytes)!;
      expect(decoded.width, kMaxImageEdge);
      // Le ratio est conservé : un document déformé devient illisible.
      expect(decoded.height, closeTo(kMaxImageEdge / 2, 2));
    });

    test('une image déjà légère n\'est pas retouchée', () {
      // En dessous du plancher, on ne dégrade pas pour rien.
      final small = Uint8List.fromList(List.filled(kImageCompressFloor - 1, 7));
      final out = compressImageBytes(
          bytes: small, fileName: 'x.jpg', mime: 'image/jpeg');
      expect(out.bytes, same(small));
    });

    test('un PDF traverse sans être touché', () {
      // `compressForUpload` n'agit que sur ce qu'il sait décoder : un dossier
      // scolaire contient autant de PDF que de photos.
      final pdf = Uint8List.fromList(List.filled(500 * 1024, 3));
      final out = compressImageBytes(
          bytes: pdf, fileName: 'acte.pdf', mime: 'application/pdf');
      expect(out.bytes, same(pdf));
      expect(out.mime, 'application/pdf');
    });
  });
}
