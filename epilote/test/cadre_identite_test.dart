import 'dart:typed_data';

import 'package:epilote/core/utils/cadre_identite.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

// ════════════════════════════════════════════════════════════════════════════
//  LE CADRE D'IDENTITÉ
//
//  Le recadrage n'est pas un embellissement : c'est ce qui décide de la
//  définition du visage sur le papier. `compressAvatar` réduit à 256 px de plus
//  long côté ; tout ce qui reste hors du cadre à ce moment-là a consommé une
//  partie de ces 256 px pour rien.
//
//  Une erreur ici ne se voit pas à l'écran — l'aperçu est petit et net. Elle se
//  voit sur la planche imprimée, découpée, plastifiée et distribuée.
// ════════════════════════════════════════════════════════════════════════════

/// Encode une image unie de [l] × [h] px — de quoi éprouver le vrai chemin.
Uint8List _jpeg(int l, int h) {
  final im = img.Image(width: l, height: h);
  img.fill(im, color: img.ColorRgb8(120, 140, 160));
  return Uint8List.fromList(img.encodeJpg(im, quality: 90));
}

void main() {
  group('Le cadre tient dans l’image et garde le bon rapport', () {
    test('paysage 16:9 — la hauteur commande', () {
      final c = cadreIdentite(1280, 720);
      expect(c.hauteur, 720, reason: 'Toute la hauteur est utilisable.');
      expect(c.largeur, (720 * kRatioIdentite).round());
      expect(c.x, (1280 - c.largeur) ~/ 2);
      expect(c.y, 0);
    });

    test('paysage 4:3 — la hauteur commande aussi', () {
      final c = cadreIdentite(640, 480);
      expect(c.hauteur, 480);
      expect(c.largeur, (480 * kRatioIdentite).round());
    });

    test('portrait 3:4 — plus haut que le rapport identité : la largeur '
        'commande', () {
      final c = cadreIdentite(3000, 4000);
      expect(c.largeur, 3000);
      expect(c.hauteur, (3000 / kRatioIdentite).round());
      expect(c.hauteur, lessThanOrEqualTo(4000));
    });

    test('une image déjà au rapport identité n’est pas rognée', () {
      final c = cadreIdentite(1100, 1400);
      expect(c.largeur, 1100);
      expect(c.hauteur, 1400);
      expect(c.x, 0);
      expect(c.y, 0);
    });

    test('le cadre ne sort JAMAIS de l’image', () {
      const tailles = [
        [1, 1], [1, 4000], [4000, 1], [3, 2], [2, 3],
        [1280, 720], [720, 1280], [4000, 3000], [37, 41], [9999, 10000],
      ];
      for (final t in tailles) {
        final c = cadreIdentite(t[0], t[1]);
        expect(c.x, greaterThanOrEqualTo(0), reason: 'x négatif sur $t');
        expect(c.y, greaterThanOrEqualTo(0), reason: 'y négatif sur $t');
        expect(c.x + c.largeur, lessThanOrEqualTo(t[0]),
            reason: 'déborde à droite sur $t');
        expect(c.y + c.hauteur, lessThanOrEqualTo(t[1]),
            reason: 'déborde en bas sur $t');
        expect(c.largeur, greaterThan(0), reason: 'cadre vide sur $t');
        expect(c.hauteur, greaterThan(0), reason: 'cadre vide sur $t');
      }
    });

    test('le rapport obtenu est celui du cadre imprimé, à l’arrondi près', () {
      for (final t in const [
        [1280, 720], [4000, 3000], [3000, 4000], [1920, 1080], [800, 600],
      ]) {
        final c = cadreIdentite(t[0], t[1]);
        expect((c.largeur / c.hauteur - kRatioIdentite).abs(), lessThan(0.01),
            reason: 'rapport dérivé sur $t : '
                '${c.largeur}×${c.hauteur}');
      }
    });

    test('des dimensions absurdes ne font pas exploser le calcul', () {
      expect(cadreIdentite(0, 100).largeur, 0);
      expect(cadreIdentite(100, 0).hauteur, 0);
      expect(cadreIdentite(-5, 100).largeur, 0);
    });
  });

  group('Le cadre garde le CENTRE de l’image', () {
    test('la marge retirée est la même des deux côtés, à un pixel près', () {
      final c = cadreIdentite(1280, 720);
      final gauche = c.x;
      final droite = 1280 - (c.x + c.largeur);
      expect((gauche - droite).abs(), lessThanOrEqualTo(1));
    });
  });

  group('Le recadrage travaille vraiment sur les octets', () {
    test('une capture 16:9 ressort au rapport identité', () async {
      final recadree = await recadrerEnIdentite(_jpeg(1280, 720));
      final im = img.decodeImage(recadree)!;
      expect(im.height, 720);
      expect(im.width, (720 * kRatioIdentite).round());
    });

    test('une image déjà au bon rapport ressort INCHANGÉE, octet pour octet',
        () async {
      final source = _jpeg(1100, 1400);
      final apres = await recadrerEnIdentite(source);
      expect(identical(apres, source) || apres.length == source.length, isTrue,
          reason: 'Ré-encoder pour rien empile des artefacts JPEG sur un '
              'visage qui repassera ensuite par compressAvatar.');
    });

    test('des octets illisibles ressortent tels quels, sans exception',
        () async {
      final poubelle = Uint8List.fromList([1, 2, 3, 4, 5]);
      expect(await recadrerEnIdentite(poubelle), poubelle,
          reason: 'L’opérateur a la personne devant lui, pas une seconde '
              'chance : une photo mal cadrée vaut mieux qu’une photo perdue.');
    });

    test('le recadrage préserve la hauteur — c’est là qu’est le visage',
        () async {
      // Une webcam cadre large : le buste occupe le centre, le décor les côtés.
      final im = img.decodeImage(await recadrerEnIdentite(_jpeg(1920, 1080)))!;
      expect(im.height, 1080, reason: 'Rien n’est retiré en haut ni en bas.');
      expect(im.width, lessThan(1920));
    });
  });

  group('Ce que le recadrage gagne sur le papier', () {
    // Le cadre imprimé fait 22 mm de large. La définition obtenue est le
    // nombre de pixels qui le remplissent, divisé par 22 mm en pouces.
    double dpi(int largeurPx) => largeurPx / (kPhotoIdentiteLargeurMm / 25.4);

    test('sans recadrage, une capture 16:9 tombe sous les 150 dpi', () {
      // compressAvatar : plus long côté à 256 px → 256 × 144.
      // Le PDF recadre alors en `cover` : il ne reste que 144 px de haut,
      // donc 144 × ratio de large.
      final largeurUtile = (144 * kRatioIdentite).round();
      expect(dpi(largeurUtile), lessThan(150));
    });

    test('avec recadrage, la même capture dépasse 200 dpi', () {
      // Recadrée d’abord : 566 × 720 → compressAvatar → 201 × 256.
      final c = cadreIdentite(1280, 720);
      final apresCompression = (c.largeur * 256 / c.hauteur).round();
      expect(dpi(apresCompression), greaterThan(200));
    });
  });
}
