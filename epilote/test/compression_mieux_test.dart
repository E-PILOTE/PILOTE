import 'dart:typed_data';

import 'package:epilote/core/utils/media_compression.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

// ════════════════════════════════════════════════════════════════════════════
//  COMPRESSER MIEUX — trois défauts mesurés, trois gardes
//
//  Le fait que TOUT passe par la compression est gardé ailleurs
//  (`tout_octet_televerse_est_compresse_test.dart`, qui lit le code source).
//  Ici on mesure la QUALITÉ de ce que produit la compression, sur de vrais
//  octets — parce que les trois défauts corrigés étaient invisibles à la
//  lecture et n'auraient jamais fait échouer une sonde de source.
// ════════════════════════════════════════════════════════════════════════════

/// Damier noir et blanc : le pire cas pour une réduction. Avec un filtre
/// « nearest » il reste noir et blanc (crénelage) ; avec une moyenne, il vire
/// au gris — c'est la preuve que les pixels ont été moyennés.
Uint8List _damier(int cote, {int carreau = 2}) {
  final im = img.Image(width: cote, height: cote);
  for (var y = 0; y < cote; y++) {
    for (var x = 0; x < cote; x++) {
      final noir = ((x ~/ carreau) + (y ~/ carreau)).isEven;
      final v = noir ? 0 : 255;
      im.setPixelRgb(x, y, v, v, v);
    }
  }
  return Uint8List.fromList(img.encodePng(im));
}

/// Photo synthétique : dégradés + bruit, incompressible comme une vraie photo.
Uint8List _photo(int w, int h) {
  final im = img.Image(width: w, height: h);
  var graine = 12345;
  int suivant() {
    graine = (graine * 1103515245 + 12345) & 0x7FFFFFFF;
    return graine;
  }

  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final bruit = suivant() % 48;
      im.setPixelRgb(
        x,
        y,
        (x * 255 ~/ w + bruit).clamp(0, 255),
        (y * 255 ~/ h + bruit).clamp(0, 255),
        ((x + y) * 255 ~/ (w + h) + bruit).clamp(0, 255),
      );
    }
  }
  return Uint8List.fromList(img.encodeJpg(im, quality: 98));
}

/// Moyenne des canaux — sert à détecter le crénelage d'une réduction.
double _luminanceMoyenne(img.Image im) {
  var somme = 0.0;
  var n = 0;
  for (final p in im) {
    somme += (p.r + p.g + p.b) / 3;
    n++;
  }
  return somme / n;
}

void main() {
  group('1. La réduction moyenne les pixels au lieu de les jeter', () {
    test('un damier réduit devient gris, il ne reste pas crénelé', () {
      // ⚠️ LE DÉFAUT : `copyResize` interpole en « nearest » par DÉFAUT, et le
      // chemin des photos partagées — le plus utilisé — laissait ce défaut.
      // Réduire un damier en « nearest » rend un damier : les escaliers
      // restent. Les moyenner rend un gris uniforme.
      // ⚠️ Carreaux d'UN pixel, source au double de la cible : chaque pixel
      // de sortie couvre alors 2×2 pixels d'entrée, soit deux clairs et deux
      // sombres. Avec des carreaux de 2 px la réduction retomberait pile sur
      // les carreaux et rendrait un damier deux fois plus petit — le test ne
      // prouverait rien.
      final src = _damier(3200, carreau: 1);

      final out = compressImageBytes(
          bytes: src, fileName: 'damier.png', mime: 'image/png');
      final reduit = img.decodeImage(out.bytes)!;

      // La moyenne DOIT tomber vers 127 : deux pixels clairs, deux sombres.
      final moyenne = _luminanceMoyenne(reduit);
      expect(moyenne, closeTo(127, 25),
          reason: 'Luminance moyenne ${moyenne.toStringAsFixed(1)} : la '
              'réduction est repassée en « nearest », le crénelage est revenu.');

      // Et l'écart-type reste faible : pas de damier résiduel.
      var variance = 0.0;
      var n = 0;
      for (final p in reduit) {
        final l = (p.r + p.g + p.b) / 3;
        variance += (l - moyenne) * (l - moyenne);
        n++;
      }
      final variancePixels = variance / n;
      // Un gris uniforme → variance ~0. Un damier survivant (0 et 255) → ~16 000.
      expect(variancePixels, lessThan(3000),
          reason: 'Le damier survit à la réduction : les pixels ne sont pas '
              'moyennés.');
    });

    test('une image déjà à la bonne taille n’est pas ré-encodée pour rien', () {
      final petit = _damier(200, carreau: 8);
      final out = compressImageBytes(
          bytes: petit, fileName: 'petit.png', mime: 'image/png');
      expect(out.bytes, same(petit),
          reason: 'Une image légère ET petite doit ressortir identique — '
              'ré-encoder ne gagne rien et dégrade.');
    });

    test('une image LÉGÈRE mais ÉNORME est quand même réduite', () {
      // ⚠️ Le bug du seuil : un JPEG très compressé de moins de 120 Ko peut
      // mesurer plusieurs milliers de pixels de côté. Il passait tel quel, et
      // l'application décodait douze millions de pixels pour en afficher un.
      // ⚠️ 2,4 Mpx et pas 6 : même à qualité 15, chaque bloc 8×8 coûte
      // quelques octets, et une image de 6 Mpx dépasse le seuil quel que soit
      // son contenu. Ce qu'on veut ici, c'est un fichier LÉGER mais LARGE.
      final plat = img.Image(width: 2000, height: 1200);
      for (final p in plat) {
        p.setRgb(200, 200, 200); // aplat : se compresse en quelques Ko
      }
      final octets = Uint8List.fromList(img.encodeJpg(plat, quality: 15));
      expect(octets.length, lessThan(kImageCompressFloor),
          reason: 'Le cas de test ne reproduit plus le défaut visé.');

      final out = compressImageBytes(
          bytes: octets, fileName: 'plat.jpg', mime: 'image/jpeg');
      final reduit = img.decodeImage(out.bytes)!;
      expect(reduit.width, lessThanOrEqualTo(kMaxImageEdge));
    });
  });

  group('2. Les métadonnées EXIF ne partent pas sur le serveur', () {
    test('la position GPS d’une photo est retirée avant l’envoi', () {
      // ⚠️ Sur la photo d'identité d'un élève, l'EXIF d'un téléphone porte les
      // coordonnées du lieu de la prise de vue — donc, très souvent,
      // l'adresse de sa famille. Personne ne la verrait jamais partir.
      final im = img.decodeImage(_photo(2000, 1500))!;
      im.exif.imageIfd['Make'] = 'TECNO';
      im.exif.imageIfd['Model'] = 'Spark 10';
      final avec = Uint8List.fromList(img.encodeJpg(im, quality: 92));

      // Contrôle : sans notre nettoyage, l'encodeur RECOPIE bien l'EXIF.
      final relu = img.decodeImage(avec)!;
      expect(relu.exif.imageIfd.isEmpty, isFalse,
          reason: 'Le cas de test n’écrit pas d’EXIF : il ne prouve rien.');

      final out = compressImageBytes(
          bytes: avec, fileName: 'photo.jpg', mime: 'image/jpeg');
      final apres = img.decodeImage(out.bytes)!;
      expect(apres.exif.imageIfd.isEmpty, isTrue,
          reason: 'Les métadonnées de l’appareil — et avec elles la position '
              'GPS — sont reparties dans le fichier envoyé.');
    });

    test('un avatar aussi — c’est le chemin de la photo d’élève', () async {
      final im = img.decodeImage(_photo(1200, 1200))!;
      im.exif.imageIfd['Make'] = 'TECNO';
      final avec = Uint8List.fromList(img.encodeJpg(im, quality: 92));

      final out = (await compressAvatar(
              bytes: avec, fileName: 'eleve.jpg', mime: 'image/jpeg'))
          .bytes;
      final apres = img.decodeImage(out)!;
      expect(apres.exif.imageIfd.isEmpty, isTrue);
      expect(apres.width, lessThanOrEqualTo(kMaxAvatarEdge));
    });
  });

  group('3. Le poids envoyé tient dans un budget', () {
    test('une photo de téléphone descend sous la cible', () {
      // 400 Ko ≈ 8 s sur une 3G congolaise à 400 kbit/s. Au-delà, l'envoi
      // cesse d'être instantané et l'utilisateur ré-appuie — ce qui double la
      // facture de data.
      final grosse = _photo(4000, 3000);
      final out = compressImageBytes(
          bytes: grosse, fileName: 'dsc_0001.jpg', mime: 'image/jpeg');

      expect(out.bytes.length, lessThanOrEqualTo(kImageTargetBytes),
          reason: 'La photo pèse ${(out.bytes.length / 1024).round()} Ko après '
              'compression : le palier de qualité ne s’applique plus.');
      expect(out.bytes.length, lessThan(grosse.length ~/ 4),
          reason: 'Le gain est retombé sous ×4 : vérifier la réduction.');
      expect(out.mime, 'image/jpeg');
      expect(out.fileName, 'dsc_0001.jpg');
    });

    test('le 4:2:0 pèse moins que le 4:4:4, à qualité égale', () {
      // La mesure qui justifie le changement de chrominance. L'œil ne fait pas
      // la différence sur une photo ; la facture de data, si.
      final im = img.decodeImage(_photo(1600, 1200))!;
      final en444 = img.encodeJpg(im, quality: kImageJpegQuality);
      final en420 = img.encodeJpg(im,
          quality: kImageJpegQuality, chroma: img.JpegChroma.yuv420);
      expect(en420.length, lessThan(en444.length),
          reason: '4:2:0 ${en420.length} o vs 4:4:4 ${en444.length} o — le '
              'sous-échantillonnage n’apporte plus rien, revoir le réglage.');
    });

    test('la compression n’alourdit jamais', () {
      // Garde-fou historique : sur une image déjà optimale, ré-encoder peut
      // grossir. On garde alors l'original, à l'octet près.
      final deja = Uint8List.fromList(
          img.encodeJpg(img.decodeImage(_photo(1600, 1200))!, quality: 30));
      final out = compressImageBytes(
          bytes: deja, fileName: 'deja.jpg', mime: 'image/jpeg');
      expect(out.bytes.length, lessThanOrEqualTo(deja.length));
    });
  });

  group('4. Ce qui NE doit pas changer', () {
    test('un SVG traverse intact', () {
      final svg = Uint8List.fromList(
          '<svg xmlns="http://www.w3.org/2000/svg"><rect width="9" height="9"/></svg>'
              .codeUnits);
      final out = compressImageBytes(
          bytes: svg, fileName: 'logo.svg', mime: 'image/svg+xml');
      expect(out.bytes, same(svg));
      expect(out.mime, 'image/svg+xml');
    });

    test('un logo détouré garde sa transparence', () {
      // Aplatir un logo détouré sur du blanc poserait un carré blanc sur le
      // bandeau tricolore de l'en-tête officiel.
      final im = img.Image(width: 900, height: 900, numChannels: 4);
      for (final p in im) {
        p.setRgba(220, 30, 30, p.x < 450 ? 255 : 0);
      }
      final png = Uint8List.fromList(img.encodePng(im));
      final out = compressLogoBytes(
          bytes: png, fileName: 'logo.png', mime: 'image/png');
      expect(out.mime, 'image/png');
      final apres = img.decodeImage(out.bytes)!;
      expect(apres.hasAlpha, isTrue);
      expect(apres.width, lessThanOrEqualTo(kMaxLogoEdge));
    });
  });
}
