import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;

// ─── Fournisseur de tuiles Esri « placeholder-aware » ────────────────────────
// Esri World Imagery renvoie une tuile-placeholder « Map data not yet available »
// (image grise de 2521 octets, HTTP 200) là où l'imagerie haute-résolution
// n'existe pas — le seuil varie selon le lieu (z17 en forêt, z19 en ville).
// On détecte ce placeholder et on renvoie une tuile TRANSPARENTE : la tuile de
// zoom inférieur (conservée par flutter_map via keepBuffer) transparaît alors,
// donnant un « sur-zoom » automatique par lieu, sans jamais afficher l'erreur.

const int _kEsriPlaceholderBytes = 2521;

// PNG 1×1 entièrement transparent.
final Uint8List _kTransparentPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// Fournisseur de tuiles pour l'imagerie Esri qui masque les placeholders.
class EsriImageryTileProvider extends TileProvider {
  EsriImageryTileProvider({super.headers});

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return _EsriTileImage(getTileUrl(coordinates, options), headers);
  }
}

class _EsriTileImage extends ImageProvider<_EsriTileImage> {
  _EsriTileImage(this.url, this.headers);
  final String url;
  final Map<String, String> headers;

  @override
  Future<_EsriTileImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_EsriTileImage>(this);

  @override
  ImageStreamCompleter loadImage(
      _EsriTileImage key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _load(decode),
      scale: 1.0,
      debugLabel: url,
    );
  }

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    Uint8List bytes;
    try {
      final resp = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 20));
      bytes = (resp.statusCode == 200 &&
              resp.bodyBytes.length != _kEsriPlaceholderBytes)
          ? resp.bodyBytes
          : _kTransparentPng;
    } catch (_) {
      bytes = _kTransparentPng;
    }
    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }

  @override
  bool operator ==(Object other) =>
      other is _EsriTileImage && other.url == url;

  @override
  int get hashCode => url.hashCode;
}
