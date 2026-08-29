import 'dart:io' show File, Platform;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:video_compress/video_compress.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Compression média AVANT upload — l'« effet WhatsApp ».
//  • Images  : pur Dart (`image`) → marche partout (mobile, desktop, web, Linux
//    dev). Redimensionne au plus long côté ≤ kMaxImageEdge, ré-encode JPEG q80.
//  • Vidéos  : `video_compress` → mobile uniquement (Android/iOS). Ailleurs on
//    renvoie l'original inchangé (les admins desktop ont une bonne connexion).
//  Objectif : diviser par 10-30 le poids transféré, économiser la data des
//  utilisateurs (Congo, connexions lentes) et tenir sous la limite de 25 Mo.
// ════════════════════════════════════════════════════════════════════════════

/// Plus long côté (px) cible pour une image partagée.
const int kMaxImageEdge = 1600;

/// Qualité JPEG (0-100) après redimensionnement.
const int kImageJpegQuality = 80;

/// En dessous de ce poids, une image n'est pas recompressée (déjà légère).
const int kImageCompressFloor = 120 * 1024; // 120 Ko

/// Résultat d'une compression : octets prêts à l'upload + nom/MIME ajustés.
class CompressedMedia {
  const CompressedMedia({
    required this.bytes,
    required this.fileName,
    required this.mime,
  });
  final Uint8List bytes;
  final String fileName;
  final String mime;
}

/// Vrai si l'appareil sait transcoder la vidéo (plugin natif mobile).
bool get videoCompressionSupported =>
    !kIsWeb && (Platform.isAndroid || Platform.isIOS);

/// Compresse une image hors du thread UI (isolate `compute`) — décodage +
/// redimensionnement + ré-encodage JPEG sont coûteux ; on évite tout jank.
Future<CompressedMedia> compressImage({
  required Uint8List bytes,
  required String fileName,
  required String mime,
}) async {
  // Sur le web, `compute` reste sur le thread principal ; pas de gain mais OK.
  if (!mime.startsWith('image/') || bytes.length < kImageCompressFloor) {
    return CompressedMedia(bytes: bytes, fileName: fileName, mime: mime);
  }
  try {
    return await compute(
      _compressImageIsolate,
      (bytes: bytes, fileName: fileName, mime: mime),
    );
  } catch (_) {
    return CompressedMedia(bytes: bytes, fileName: fileName, mime: mime);
  }
}

CompressedMedia _compressImageIsolate(
        ({Uint8List bytes, String fileName, String mime}) a) =>
    compressImageBytes(bytes: a.bytes, fileName: a.fileName, mime: a.mime);

/// Compresse une **image** en mémoire (pur Dart). Si l'entrée n'est pas une
/// image décodable, ou déjà légère, renvoie l'original inchangé.
CompressedMedia compressImageBytes({
  required Uint8List bytes,
  required String fileName,
  required String mime,
}) {
  // PNG/JPEG/WebP… : on tente de décoder. Échec → original (ex. SVG, GIF animé).
  if (!mime.startsWith('image/') || bytes.length < kImageCompressFloor) {
    return CompressedMedia(bytes: bytes, fileName: fileName, mime: mime);
  }
  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    decoded = null;
  }
  if (decoded == null) {
    return CompressedMedia(bytes: bytes, fileName: fileName, mime: mime);
  }

  // Redimensionne si un côté dépasse la cible (en conservant le ratio).
  final longest = decoded.width > decoded.height ? decoded.width : decoded.height;
  var out = decoded;
  if (longest > kMaxImageEdge) {
    if (decoded.width >= decoded.height) {
      out = img.copyResize(decoded, width: kMaxImageEdge);
    } else {
      out = img.copyResize(decoded, height: kMaxImageEdge);
    }
  }

  final jpg = img.encodeJpg(out, quality: kImageJpegQuality);
  // Garde-fou : si la « compression » alourdit (rare), garde l'original.
  if (jpg.length >= bytes.length) {
    return CompressedMedia(bytes: bytes, fileName: fileName, mime: mime);
  }
  return CompressedMedia(
    bytes: Uint8List.fromList(jpg),
    fileName: _withExtension(fileName, 'jpg'),
    mime: 'image/jpeg',
  );
}

// ─── Logos d'établissement ──────────────────────────────────────────────────
// Un logo n'est pas une photo : il est affiché petit (88 px dans le formulaire,
// ~44 px sur un marqueur de carte) et porte souvent de la transparence.
//
// ⚠️ WebP : le paquet `image` sait LIRE le WebP mais **pas l'encoder** (aucun
// encodeur WebP en pur Dart). Encoder en WebP imposerait un plugin natif
// (`flutter_image_compress`) qui ne fonctionne QUE sur Android/iOS — donc pas
// sur le desktop Linux où tourne l'app d'administration. On garde donc un
// pipeline universel : redimensionnement + PNG (si transparence) ou JPEG.
// Le gain réel vient du redimensionnement (un logo de 3 Mo tombe à ~30 Ko).

/// Plus long côté (px) cible pour un logo (rendu ≤ 96 px, marge rétine ×4+).
const int kMaxLogoEdge = 512;

/// Qualité JPEG d'un logo opaque (un peu plus haute : aplats + texte fin).
const int kLogoJpegQuality = 85;

/// Compresse un logo hors du thread UI. SVG et formats indécodables passent
/// tels quels (fail-soft : jamais de blocage de l'upload).
Future<CompressedMedia> compressLogo({
  required Uint8List bytes,
  required String fileName,
  required String mime,
}) async {
  if (!mime.startsWith('image/') || mime.contains('svg')) {
    return CompressedMedia(bytes: bytes, fileName: fileName, mime: mime);
  }
  try {
    return await compute(
      _compressLogoIsolate,
      (bytes: bytes, fileName: fileName, mime: mime),
    );
  } catch (_) {
    return CompressedMedia(bytes: bytes, fileName: fileName, mime: mime);
  }
}

CompressedMedia _compressLogoIsolate(
        ({Uint8List bytes, String fileName, String mime}) a) =>
    compressLogoBytes(bytes: a.bytes, fileName: a.fileName, mime: a.mime);

/// Redimensionne un logo ≤ [kMaxLogoEdge] et le ré-encode dans le format le
/// plus léger qui préserve son rendu : PNG si le logo est détouré
/// (transparence), JPEG sinon. Renvoie l'original si le résultat est plus lourd.
CompressedMedia compressLogoBytes({
  required Uint8List bytes,
  required String fileName,
  required String mime,
}) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    decoded = null;
  }
  if (decoded == null) {
    return CompressedMedia(bytes: bytes, fileName: fileName, mime: mime);
  }

  var out = decoded;
  final longest =
      decoded.width > decoded.height ? decoded.width : decoded.height;
  if (longest > kMaxLogoEdge) {
    out = decoded.width >= decoded.height
        ? img.copyResize(decoded,
            width: kMaxLogoEdge, interpolation: img.Interpolation.average)
        : img.copyResize(decoded,
            height: kMaxLogoEdge, interpolation: img.Interpolation.average);
  }

  final detoure = out.hasAlpha && _hasTransparency(out);
  final encoded =
      detoure ? img.encodePng(out, level: 9) : img.encodeJpg(out, quality: kLogoJpegQuality);
  if (encoded.length >= bytes.length) {
    return CompressedMedia(bytes: bytes, fileName: fileName, mime: mime);
  }
  return CompressedMedia(
    bytes: Uint8List.fromList(encoded),
    fileName: _withExtension(fileName, detoure ? 'png' : 'jpg'),
    mime: detoure ? 'image/png' : 'image/jpeg',
  );
}

// ─── Logos EMBARQUÉS DANS UN PDF ────────────────────────────────────────────
//
//  ⚠️ POURQUOI UN SECOND SEUIL, PLUS BAS QUE `kMaxLogoEdge`
//
//  Un PDF n'a pas de filtre PNG. Une image PNG posée dans un document n'y est
//  donc PAS rangée telle quelle : le greffon la décode en pixels bruts et les
//  recompresse en Flate. Mesuré sur un dégradé 512 × 512 :
//
//    fichier PNG source :   2 Ko   →   dans le PDF :  95 Ko
//    le même en 128 px  :   0 Ko   →   dans le PDF :  34 Ko
//    un JPEG 512 px     :  19 Ko   →   dans le PDF :  20 Ko  (embarqué tel quel)
//
//  Le coût suit donc le nombre de PIXELS, pas le poids du fichier source. Un
//  logo deux fois trop grand coûte quatre fois trop cher — et il le coûte dans
//  CHAQUE document produit par la plateforme, bulletins compris.
//
//  Le plus grand emplacement de logo du dépôt fait 54 pt (en-tête officiel) ;
//  256 px y valent environ 340 dpi, au-dessus de ce qu'une imprimante rend.
//  512 px, le seuil de l'interface, n'y apporterait rien de visible.

/// Plus long côté (px) d'un logo embarqué dans un PDF.
const int kMaxPdfLogoEdge = 256;

/// Prépare un logo pour être embarqué dans un PDF : ≤ [kMaxPdfLogoEdge], et
/// dans le format qui coûte le moins **une fois dans le document**.
///
/// ⚠️ **Ne comparez pas le poids des fichiers ici.** C'est l'erreur naturelle,
/// et elle annule tout le gain : un PNG de 2 Ko coûte 95 Ko dans un PDF, un
/// JPEG de 19 Ko en coûte 20. Ce qui compte est le nombre de pixels et le
/// format d'arrivée, jamais la taille du fichier de départ.
///
/// D'où la règle : un logo **opaque** part en JPEG même s'il grossit sur le
/// disque (le PDF l'embarque alors tel quel, en DCTDecode) ; un logo **détouré**
/// reste en PNG, parce qu'aplatir sa transparence sur du blanc poserait un
/// carré blanc sur le bandeau tricolore de l'en-tête.
///
/// Rend les octets d'origine si l'image ne se décode pas, ou si elle est déjà
/// petite ET déjà au bon format — un document sans logo serait pire qu'un
/// document un peu gras.
Future<Uint8List> compressLogoForPdf(Uint8List bytes) async {
  try {
    return await compute(_compressLogoForPdfIsolate, bytes);
  } catch (_) {
    return bytes;
  }
}

/// Signature JPEG (SOI).
bool _estJpeg(Uint8List b) => b.length > 3 && b[0] == 0xFF && b[1] == 0xD8;

/// Signature PNG.
bool _estPng(Uint8List b) =>
    b.length > 8 &&
    b[0] == 0x89 &&
    b[1] == 0x50 &&
    b[2] == 0x4E &&
    b[3] == 0x47;

Uint8List _compressLogoForPdfIsolate(Uint8List bytes) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    decoded = null;
  }
  if (decoded == null) return bytes;

  final detoure = decoded.hasAlpha && _hasTransparency(decoded);
  final longest =
      decoded.width > decoded.height ? decoded.width : decoded.height;
  final dejaPetit = longest <= kMaxPdfLogoEdge;
  final dejaAuBonFormat = detoure ? _estPng(bytes) : _estJpeg(bytes);
  if (dejaPetit && dejaAuBonFormat) return bytes;

  final out = dejaPetit
      ? decoded
      : decoded.width >= decoded.height
          ? img.copyResize(decoded,
              width: kMaxPdfLogoEdge, interpolation: img.Interpolation.average)
          : img.copyResize(decoded,
              height: kMaxPdfLogoEdge,
              interpolation: img.Interpolation.average);

  final encoded = detoure
      ? img.encodePng(out, level: 9)
      : img.encodeJpg(out, quality: kLogoJpegQuality);
  return Uint8List.fromList(encoded);
}

/// Vrai dès qu'un pixel n'est pas totalement opaque (logo détouré).
bool _hasTransparency(img.Image im) {
  for (final p in im) {
    if (p.a < 250) return true;
  }
  return false;
}

// ─── Avatars ────────────────────────────────────────────────────────────────
// Une photo de profil ne s'affiche jamais au-delà de 96 px dans l'application
// (38 px dans une liste, 88 px sur une fiche). 256 px laisse la marge rétine.
// Un téléphone moderne produit des photos de 4 à 8 Mo : sans cette étape, on
// transfère 8 Mo pour afficher une pastille de 38 pixels.

/// Plus long côté (px) cible pour un avatar.
const int kMaxAvatarEdge = 256;

/// Qualité JPEG d'un avatar.
const int kAvatarJpegQuality = 82;

/// Compresse une photo de profil hors du thread UI.
Future<CompressedMedia> compressAvatar({
  required Uint8List bytes,
  required String fileName,
  required String mime,
}) async {
  if (!mime.startsWith('image/') || mime.contains('svg')) {
    return CompressedMedia(bytes: bytes, fileName: fileName, mime: mime);
  }
  try {
    return await compute(
      _compressAvatarIsolate,
      (bytes: bytes, fileName: fileName, mime: mime),
    );
  } catch (_) {
    return CompressedMedia(bytes: bytes, fileName: fileName, mime: mime);
  }
}

CompressedMedia _compressAvatarIsolate(
        ({Uint8List bytes, String fileName, String mime}) a) =>
    _resizeEncode(a.bytes, a.fileName, a.mime,
        maxEdge: kMaxAvatarEdge, quality: kAvatarJpegQuality, keepAlpha: false);

/// Redimensionne puis ré-encode. `keepAlpha` conserve la transparence en PNG
/// (logos) ; sinon tout part en JPEG (photos, où l'alpha n'a pas de sens).
CompressedMedia _resizeEncode(
  Uint8List bytes,
  String fileName,
  String mime, {
  required int maxEdge,
  required int quality,
  required bool keepAlpha,
}) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    decoded = null;
  }
  if (decoded == null) {
    return CompressedMedia(bytes: bytes, fileName: fileName, mime: mime);
  }

  var out = decoded;
  final longest =
      decoded.width > decoded.height ? decoded.width : decoded.height;
  if (longest > maxEdge) {
    out = decoded.width >= decoded.height
        ? img.copyResize(decoded,
            width: maxEdge, interpolation: img.Interpolation.average)
        : img.copyResize(decoded,
            height: maxEdge, interpolation: img.Interpolation.average);
  }

  final alpha = keepAlpha && out.hasAlpha && _hasTransparency(out);
  final encoded =
      alpha ? img.encodePng(out, level: 9) : img.encodeJpg(out, quality: quality);
  if (encoded.length >= bytes.length) {
    return CompressedMedia(bytes: bytes, fileName: fileName, mime: mime);
  }
  return CompressedMedia(
    bytes: Uint8List.fromList(encoded),
    fileName: _withExtension(fileName, alpha ? 'png' : 'jpg'),
    mime: alpha ? 'image/png' : 'image/jpeg',
  );
}

// ─── Type MIME ──────────────────────────────────────────────────────────────

/// Type MIME d'après l'extension du fichier.
///
/// ⚠️ Plusieurs écrans composaient le type à la main : `'image/$ext'`. Pour un
/// fichier `logo.jpg` cela donne `image/jpg`, qui **n'est pas un type MIME
/// valide** (c'est `image/jpeg`) ; pour un `.svg` cela donne `image/svg` au
/// lieu de `image/svg+xml`. Le navigateur et le CDN s'en accommodent souvent,
/// mais pas toujours — et le fichier finit téléchargé au lieu d'être affiché.
String mimeForImageExtension(String? ext) => switch (
    (ext ?? '').toLowerCase().replaceFirst('.', '')) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'bmp' => 'image/bmp',
      'svg' => 'image/svg+xml',
      'heic' || 'heif' => 'image/heic',
      'avif' => 'image/avif',
      final e when e.isNotEmpty => 'image/$e',
      _ => 'application/octet-stream',
    };

/// Compresse une **vidéo** (mobile uniquement). Renvoie l'original ailleurs ou
/// si le transcodage échoue. Écrit un fichier temporaire pour `video_compress`.
Future<CompressedMedia> compressVideoBytes({
  required Uint8List bytes,
  required String fileName,
  required String mime,
}) async {
  if (!videoCompressionSupported) {
    return CompressedMedia(bytes: bytes, fileName: fileName, mime: mime);
  }
  File? tmp;
  try {
    final dir = await getTemporaryDirectory();
    tmp = File('${dir.path}/raw_${DateTime.now().millisecondsSinceEpoch}_'
        '${_safe(fileName)}');
    await tmp.writeAsBytes(bytes, flush: true);

    final info = await VideoCompress.compressVideo(
      tmp.path,
      quality: VideoQuality.MediumQuality, // ~720p, bitrate maîtrisé
      deleteOrigin: false,
      includeAudio: true,
    );
    final outPath = info?.path;
    if (outPath == null) {
      return CompressedMedia(bytes: bytes, fileName: fileName, mime: mime);
    }
    final outBytes = await File(outPath).readAsBytes();
    if (outBytes.isEmpty || outBytes.length >= bytes.length) {
      return CompressedMedia(bytes: bytes, fileName: fileName, mime: mime);
    }
    return CompressedMedia(
      bytes: outBytes,
      fileName: _withExtension(fileName, 'mp4'),
      mime: 'video/mp4',
    );
  } catch (_) {
    return CompressedMedia(bytes: bytes, fileName: fileName, mime: mime);
  } finally {
    try {
      await tmp?.delete();
    } catch (_) {}
  }
}

/// Aiguillage : compresse selon le type MIME, sinon renvoie l'original.
Future<CompressedMedia> compressForUpload({
  required Uint8List bytes,
  required String fileName,
  required String mime,
}) async {
  if (mime.startsWith('image/')) {
    return compressImage(bytes: bytes, fileName: fileName, mime: mime);
  }
  if (mime.startsWith('video/')) {
    return compressVideoBytes(bytes: bytes, fileName: fileName, mime: mime);
  }
  return CompressedMedia(bytes: bytes, fileName: fileName, mime: mime);
}

String _safe(String name) => name.replaceAll(RegExp(r'[^\w\.\-]+'), '_');

String _withExtension(String fileName, String ext) {
  final dot = fileName.lastIndexOf('.');
  final base = dot > 0 ? fileName.substring(0, dot) : fileName;
  return '$base.$ext';
}
