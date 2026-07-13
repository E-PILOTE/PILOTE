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

/// Vrai dès qu'un pixel n'est pas totalement opaque (logo détouré).
bool _hasTransparency(img.Image im) {
  for (final p in im) {
    if (p.a < 250) return true;
  }
  return false;
}

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
