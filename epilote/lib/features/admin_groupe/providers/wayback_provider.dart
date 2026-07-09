import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

// ─── Esri Wayback — imagerie satellite datée (gratuit, sans clé API) ─────────
// 195 versions datées de l'imagerie mondiale Esri (2014 → aujourd'hui), haute
// résolution, tuiles WMTS publiques. Sert à la frise datée de la Vue école
// (évolution du site / avancement des chantiers). Objectif, sans intervention
// terrain. Aucune imagerie « live » n'existe par satellite : ce sont des
// clichés datés (cf. spec cockpit-regional-satellite).

const _kWaybackConfig =
    'https://s3-us-west-2.amazonaws.com/config.maptiles.arcgis.com/waybackconfig.json';

final _dateRe = RegExp(r'(\d{4})-(\d{2})-(\d{2})');

/// Une version datée de l'imagerie mondiale Esri (Wayback).
class WaybackRelease {
  const WaybackRelease({
    required this.releaseNum,
    required this.date,
    required this.tileUrlTemplate,
  });
  final int releaseNum;
  final DateTime date;
  final String tileUrlTemplate; // format flutter_map : .../{z}/{y}/{x}
}

/// Parse le waybackconfig.json → versions triées par date décroissante.
/// Tolérant : renvoie une liste vide si le JSON est invalide/inattendu.
List<WaybackRelease> parseWaybackConfig(String json) {
  final decoded = jsonDecode(json);
  if (decoded is! Map<String, dynamic>) return const [];
  final out = <WaybackRelease>[];
  decoded.forEach((key, v) {
    if (v is! Map) return;
    final title = v['itemTitle'] as String? ?? '';
    final url = v['itemURL'] as String?;
    final m = _dateRe.firstMatch(title);
    final num = int.tryParse(key);
    if (url == null || m == null || num == null) return;
    // Esri WMTS : /tile/{release}/{level}/{row}/{col} → flutter_map {z}/{y}/{x}
    final tmpl = url
        .replaceAll('{level}', '{z}')
        .replaceAll('{row}', '{y}')
        .replaceAll('{col}', '{x}');
    out.add(WaybackRelease(
      releaseNum: num,
      date: DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!)),
      tileUrlTemplate: tmpl,
    ));
  });
  out.sort((a, b) => b.date.compareTo(a.date));
  return out;
}

/// Versions datées Esri Wayback (mise en cache ; liste vide si hors-ligne).
final waybackReleasesProvider = FutureProvider<List<WaybackRelease>>((ref) async {
  ref.keepAlive();
  try {
    final resp = await http
        .get(Uri.parse(_kWaybackConfig))
        .timeout(const Duration(seconds: 20));
    if (resp.statusCode != 200) return const [];
    return parseWaybackConfig(resp.body);
  } catch (_) {
    return const [];
  }
});
