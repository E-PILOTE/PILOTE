import 'dart:io' show File, Platform;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:video_compress/video_compress.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Compression média AVANT upload — l'« effet WhatsApp ».
//  • Images  : pur Dart (`image`) → marche partout (mobile, desktop, web, Linux
//    dev). Redimensionne au plus long côté ≤ kMaxImageEdge, ré-encode JPEG.
//  • Vidéos  : `video_compress` → mobile uniquement (Android/iOS). Ailleurs on
//    renvoie l'original inchangé (les admins desktop ont une bonne connexion).
//  Objectif : diviser par 10-30 le poids transféré, économiser la data des
//  utilisateurs (Congo, connexions lentes) et tenir sous la limite de 25 Mo.
//
//  ── ⚠️ TROIS DÉFAUTS CORRIGÉS, TOUS INVISIBLES À LA LECTURE ───────────────
//
//  1. `copyResize` INTERPOLE EN « NEAREST » PAR DÉFAUT (image 4.8). C'est le
//     pire filtre possible pour RÉDUIRE : il jette les pixels au lieu de les
//     moyenner, et une photo divisée par trois en ressort crénelée — escaliers
//     sur les visages, moirage sur un tableau, texte d'un document illisible.
//     Deux fonctions de ce fichier passaient `Interpolation.average`, la
//     troisième — celle des photos partagées, la plus utilisée — non. Tout
//     passe désormais par `_reduire`, qui l'impose.
//
//  2. LES MÉTADONNÉES EXIF ÉTAIENT RECOPIÉES dans le fichier envoyé
//     (`_writeExif` de l'encodeur). Une photo prise au téléphone y porte le
//     modèle de l'appareil, l'heure exacte, et surtout les COORDONNÉES GPS.
//     Sur la photo d'identité d'un élève, c'est l'adresse où elle a été prise
//     qui part sur le serveur. On les retire : quelques kilo-octets de moins,
//     et une donnée personnelle qui ne quitte plus l'appareil.
//
//  3. LE SOUS-ÉCHANTILLONNAGE DE CHROMINANCE ÉTAIT DÉSACTIVÉ. `encodeJpg`
//     encode en 4:4:4 par défaut — chaque pixel garde sa couleur pleine. L'œil
//     ne distingue pas le 4:2:0 sur une photo, qui pèse 20 à 30 % de moins.
//     Les PHOTOS y passent ; les LOGOS restent en 4:4:4, parce qu'un aplat de
//     couleur et un texte fin y gagnent des franges visibles.
//
//  ⚠️ Ce qui NE change pas : une pièce d'archive d'examen n'est jamais
//  compressée (`exam_archives_provider`) — ré-encoder son scan changerait son
//  empreinte SHA-256, donc sa valeur probante.
// ════════════════════════════════════════════════════════════════════════════

/// Plus long côté (px) cible pour une image partagée.
const int kMaxImageEdge = 1600;

/// Qualité JPEG (0-100) après redimensionnement.
const int kImageJpegQuality = 80;

/// En dessous de ce poids, une image n'est pas recompressée (déjà légère).
///
/// ⚠️ Ce seuil ne suffit PAS à lui seul, et c'était un bug : un JPEG très
/// compressé de 100 Ko peut mesurer 4 000 × 3 000. Il passait donc tel quel,
/// et l'application décodait douze millions de pixels en mémoire pour en
/// afficher un million. On exige désormais les DEUX conditions — léger ET pas
/// plus grand que la cible (cf. `_dejaAssezLeger`).
const int kImageCompressFloor = 120 * 1024; // 120 Ko

/// Poids visé pour une image partagée. Au-dessus, la qualité redescend d'un
/// palier et on ré-encode — jusqu'à [kImageJpegQualityMin].
///
/// 400 Ko, c'est ~8 secondes sur une 3G congolaise à 400 kbit/s. Au-delà,
/// l'envoi d'une photo dans une conversation cesse d'être instantané et
/// l'utilisateur ré-appuie, ce qui double la facture.
const int kImageTargetBytes = 400 * 1024;

/// Plancher de qualité : en dessous, les artefacts se voient sur un visage.
const int kImageJpegQualityMin = 62;

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

// ─── Les deux gestes que TOUT passage par ce fichier doit faire ────────────

/// Réduit [src] pour que son plus long côté tienne dans [maxEdge].
///
/// ⚠️ `Interpolation.average` n'est pas un réglage de confort : c'est la
/// différence entre une réduction propre et une image crénelée. Le défaut du
/// paquet (`nearest`) jette les pixels au lieu de les moyenner — visible dès
/// qu'on divise par deux, insupportable au-delà. Ne jamais appeler
/// `copyResize` directement ailleurs dans le dépôt.
img.Image _reduire(img.Image src, int maxEdge) {
  final longest = src.width > src.height ? src.width : src.height;
  if (longest <= maxEdge) return src;
  return src.width >= src.height
      ? img.copyResize(src, width: maxEdge, interpolation: img.Interpolation.average)
      : img.copyResize(src, height: maxEdge, interpolation: img.Interpolation.average);
}

/// Retire les métadonnées EXIF avant ré-encodage.
///
/// ⚠️ Sur la photo d'identité d'un élève, l'EXIF d'un téléphone porte les
/// COORDONNÉES GPS du lieu de la prise de vue — donc, très souvent, l'adresse
/// de sa famille. Elle n'a rien à faire sur le serveur, et personne ne la
/// verrait jamais partir. Accessoirement, c'est aussi quelques kilo-octets par
/// image, et l'orientation est déjà appliquée aux pixels par le décodeur.
img.Image _sansMetadonnees(img.Image im) => im..exif = img.ExifData();

/// Vrai si l'image est déjà légère ET déjà à la bonne taille.
///
/// ⚠️ Les DEUX conditions. Ne regarder que le poids laissait passer des images
/// de très grande dimension mais fortement compressées.
bool _dejaAssezLeger(Uint8List bytes, int maxEdge) {
  if (bytes.length >= kImageCompressFloor) return false;
  final t = _dimensions(bytes);
  if (t == null) return true; // indécodable : on n'y touche pas
  final longest = t.$1 > t.$2 ? t.$1 : t.$2;
  return longest <= maxEdge;
}

/// Largeur/hauteur sans décoder tous les pixels quand c'est possible.
(int, int)? _dimensions(Uint8List bytes) {
  try {
    final im = img.decodeImage(bytes);
    return im == null ? null : (im.width, im.height);
  } catch (_) {
    return null;
  }
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
  if (!mime.startsWith('image/') || mime.contains('svg')) {
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
  if (!mime.startsWith('image/') ||
      mime.contains('svg') ||
      _dejaAssezLeger(bytes, kMaxImageEdge)) {
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

  final out = _sansMetadonnees(_reduire(decoded, kMaxImageEdge));

  // Un palier de qualité à la fois, tant qu'on dépasse le budget. Trois essais
  // au plus : q80 → q71 → q62. Au-delà les artefacts se voient sur un visage,
  // et une image un peu lourde vaut mieux qu'une image abîmée.
  //
  // ⚠️ Le ré-encodage porte sur l'image DÉJÀ réduite, en mémoire : on ne
  // redécode rien. Chaque tour coûte l'encodage seul, pas le décodage.
  var q = kImageJpegQuality;
  var jpg = img.encodeJpg(out, quality: q, chroma: img.JpegChroma.yuv420);
  while (jpg.length > kImageTargetBytes && q > kImageJpegQualityMin) {
    q = (q - 9).clamp(kImageJpegQualityMin, kImageJpegQuality);
    jpg = img.encodeJpg(out, quality: q, chroma: img.JpegChroma.yuv420);
  }

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

  final out = _sansMetadonnees(_reduire(decoded, kMaxLogoEdge));

  final detoure = out.hasAlpha && _hasTransparency(out);
  // ⚠️ 4:4:4 ici, et NON 4:2:0 comme pour les photos. Un logo, ce sont des
  // aplats et du texte fin : sous-échantillonner la chrominance y laisse des
  // franges colorées sur les bords nets, très visibles à 512 px.
  final encoded = detoure
      ? img.encodePng(out, level: 9)
      : img.encodeJpg(out, quality: kLogoJpegQuality);
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

  final out = _sansMetadonnees(_reduire(decoded, kMaxPdfLogoEdge));

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

  final out = _sansMetadonnees(_reduire(decoded, maxEdge));

  final alpha = keepAlpha && out.hasAlpha && _hasTransparency(out);
  // Un avatar est une PHOTO : 4:2:0, comme les images partagées. À 256 px, la
  // chrominance réduite est invisible sur un visage et pèse un quart de moins.
  final encoded = alpha
      ? img.encodePng(out, level: 9)
      : img.encodeJpg(out, quality: quality, chroma: img.JpegChroma.yuv420);
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
