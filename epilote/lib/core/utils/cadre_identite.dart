
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

// ════════════════════════════════════════════════════════════════════════════
//  LE CADRE D'UNE PHOTO D'IDENTITÉ
//
//  ── POURQUOI RECADRER AVANT, ET PAS À L'IMPRESSION ─────────────────────────
//  La carte scolaire réserve 22 × 28 mm au visage, et le PDF y pose la photo en
//  `BoxFit.cover` : il recadre donc de toute façon. Mais il recadre une image
//  déjà réduite à 256 px de plus long côté par `compressAvatar` — et ce qui est
//  jeté à ce moment-là est jeté pour de bon.
//
//  Une webcam rend du paysage (4:3, 16:9). Sur ce chemin :
//
//    capture 1280×720 → compressAvatar → 256×144 → cover 22×28 mm
//    → il reste 113 × 144 px pour remplir le cadre, soit ~130 dpi.
//
//  En recadrant AVANT la compression, les 256 px vont là où ils comptent :
//
//    capture 1280×720 → cadre 11:14 → 566×720 → compressAvatar → 201×256
//    → ~232 dpi.
//
//  Même photo, même poids de fichier, presque le double de définition sur le
//  papier. À 130 dpi un visage imprimé sur 22 mm est une tache ; à 232 dpi il
//  identifie quelqu'un — et c'est le seul travail que cette carte ait à faire.
//
//  ⚠️ Recadrer AGRANDIT le visage sans rien inventer : on retire de la marge,
//  jamais on n'invente du pixel. C'est pourquoi le cadre pris est le PLUS GRAND
//  possible au bon rapport, centré. Un cadre plus serré donnerait un meilleur
//  portrait et une moins bonne définition ; c'est à l'opérateur de cadrer avec
//  la caméra, pas au code de décider à sa place.
// ════════════════════════════════════════════════════════════════════════════

/// Le cadre photo imprimé sur la carte scolaire, en millimètres.
///
/// ⚠️ `carte_scolaire_dessin.dart` dessine le cadre à partir de ces deux
/// constantes. Les changer déplace le recadrage ET l'impression ensemble —
/// c'est voulu : deux rapports qui divergent produisent une photo rognée deux
/// fois, une fois de trop.
const double kPhotoIdentiteLargeurMm = 22;
const double kPhotoIdentiteHauteurMm = 28;

/// Le rapport largeur / hauteur d'une photo d'identité (≈ 0,786).
const double kRatioIdentite = kPhotoIdentiteLargeurMm / kPhotoIdentiteHauteurMm;

/// Le plus grand rectangle au rapport [kRatioIdentite], centré dans une image
/// de [largeur] × [hauteur] pixels.
///
/// Rend toujours un rectangle non vide et entièrement contenu dans l'image,
/// même pour des dimensions absurdes (1 px, panorama extrême).
({int x, int y, int largeur, int hauteur}) cadreIdentite(
  int largeur,
  int hauteur,
) {
  if (largeur <= 0 || hauteur <= 0) {
    return (x: 0, y: 0, largeur: 0, hauteur: 0);
  }

  // Deux façons de tenir : en gardant toute la largeur, ou toute la hauteur.
  // La bonne est celle qui reste DANS l'image.
  var l = largeur;
  var h = (largeur / kRatioIdentite).round();
  if (h > hauteur) {
    h = hauteur;
    l = (hauteur * kRatioIdentite).round();
  }

  // L'arrondi peut déborder d'un pixel sur une image minuscule.
  l = l.clamp(1, largeur);
  h = h.clamp(1, hauteur);

  return (x: (largeur - l) ~/ 2, y: (hauteur - h) ~/ 2, largeur: l, hauteur: h);
}

/// Recadre [octets] au rapport d'une photo d'identité, hors du thread UI.
///
/// Rend les octets d'origine inchangés si l'image ne se décode pas — comme
/// `compressAvatar`. Une photo mal recadrée vaut mieux qu'une photo perdue :
/// l'opérateur a la personne devant lui, pas une seconde chance.
Future<Uint8List> recadrerEnIdentite(Uint8List octets) async {
  try {
    return await compute(_recadrerIsolate, octets);
  } catch (_) {
    return octets;
  }
}

Uint8List _recadrerIsolate(Uint8List octets) {
  img.Image? source;
  try {
    source = img.decodeImage(octets);
  } catch (_) {
    source = null;
  }
  if (source == null) return octets;

  final c = cadreIdentite(source.width, source.height);
  if (c.largeur <= 0 || c.hauteur <= 0) return octets;

  // Déjà au bon rapport, à un pixel près : ne pas ré-encoder pour rien.
  if (c.largeur == source.width && c.hauteur == source.height) return octets;

  final coupe = img.copyCrop(
    source,
    x: c.x,
    y: c.y,
    width: c.largeur,
    height: c.hauteur,
  );
  // Qualité haute : cette image repasse ensuite par `compressAvatar`, qui la
  // réduira. Compresser deux fois fort empile les artefacts sur un visage.
  //
  // ⚠️ EXIF retiré ICI et pas seulement à l'étape suivante : ces octets
  // circulent entre les deux (aperçu, mise en file hors ligne) et portent les
  // coordonnées GPS de la prise de vue. Sur la photo d'identité d'un élève,
  // c'est l'adresse de sa famille.
  coupe.exif = img.ExifData();
  return Uint8List.fromList(img.encodeJpg(coupe, quality: 92));
}
