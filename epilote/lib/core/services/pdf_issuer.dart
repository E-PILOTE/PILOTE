import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;

import '../utils/media_compression.dart' show compressLogoForPdf;

import '../../features/auth/providers/auth_provider.dart';
import '../../features/structure/providers/academic_year_provider.dart';
import 'official_pdf_kit.dart';

// ════════════════════════════════════════════════════════════════════════════
//  QUI ÉMET LE DOCUMENT.
//
//  Les exports portaient le nom et l'emblème d'E-PILOTE. Or un bulletin, une
//  convocation, une fiche d'inscription sont délivrés par un ÉTABLISSEMENT :
//  c'est son nom que la famille doit lire, et c'est lui qui engage sa
//  responsabilité. Ce fichier résout cette identité et la pose une fois pour la
//  session (`OfficialPdfKit.setIssuer`).
//
//  ── Pourquoi le logo est mis en cache sur disque ───────────────────────────
//  `school_groups.name` est synchronisé par PowerSync : le NOM est donc
//  disponible hors ligne, toujours. Le LOGO, lui, n'est qu'une URL vers le
//  Storage : le fichier n'est nulle part sur l'appareil. Or une école
//  congolaise imprime justement ses documents les jours où le réseau manque.
//
//  D'où la règle : on lit d'abord le cache disque, on ne va sur le réseau que
//  si le cache est vide, et un échec réseau n'empêche JAMAIS l'export — le
//  document sort avec l'emblème de l'application. Un document sans logo reste
//  un document ; un export qui échoue faute de réseau ne l'est pas.
//
//  Le nom du fichier de cache porte l'empreinte de l'URL : changer le logo dans
//  l'espace d'administration produit une nouvelle URL, donc une nouvelle
//  entrée, sans qu'on ait à invalider quoi que ce soit.
// ════════════════════════════════════════════════════════════════════════════

/// Délai au-delà duquel on renonce au téléchargement du logo.
///
/// Court volontairement : l'utilisateur attend son PDF. Sur un réseau congolais
/// intermittent, mieux vaut un document immédiat sans logo qu'un document qui
/// se fait attendre dix secondes pour un ornement.
const _kLogoTimeout = Duration(seconds: 6);

Future<Directory> _cacheDir() async {
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory('${docs.path}/pdf-issuer-logos');
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir;
}

/// Octets du logo : cache disque d'abord, réseau ensuite, `null` si les deux
/// échouent.
Future<Uint8List?> _logoBytes(String url) async {
  if (url.trim().isEmpty) return null;
  try {
    final key = md5.convert(utf8.encode(url)).toString();
    final file = File('${(await _cacheDir()).path}/$key.img');

    if (await file.exists()) {
      final cached = await file.readAsBytes();
      if (cached.isNotEmpty) return cached;
    }

    final res = await http.get(Uri.parse(url)).timeout(_kLogoTimeout);
    if (res.statusCode != 200 || res.bodyBytes.isEmpty) return null;
    await file.writeAsBytes(res.bodyBytes, flush: true);
    return res.bodyBytes;
  } catch (e) {
    // Hors ligne, URL morte, format refusé : aucun de ces cas ne doit empêcher
    // un export. On le note pour le diagnostic et on continue sans logo.
    debugPrint('ℹ️ Logo de l\'émetteur indisponible ($e) — export sans logo.');
    return null;
  }
}

/// Décode le logo en image PDF, ou `null`.
Future<pw.MemoryImage?> _logoImage(String? url) async {
  if (url == null) return null;
  final bytes = await _logoBytes(url);
  if (bytes == null) return null;
  try {
    // ⚠️ Réduit AVANT d'entrer dans le PDF. Le logo du groupe est stocké à
    // 512 px pour l'interface ; embarqué tel quel, il coûterait quatre fois
    // plus de pixels — donc quatre fois plus d'octets — dans CHAQUE document
    // que l'école produit. Voir `kMaxPdfLogoEdge`.
    return pw.MemoryImage(await compressLogoForPdf(bytes));
  } catch (e) {
    debugPrint('ℹ️ Logo de l\'émetteur illisible ($e) — export sans logo.');
    return null;
  }
}

/// Résout l'émetteur des documents et le pose sur [OfficialPdfKit].
///
/// À surveiller depuis l'enveloppe d'écran (`AppShell`) : l'émetteur est alors
/// posé avant qu'un export soit possible, sans qu'aucun service d'export ait à
/// s'en préoccuper.
///
/// Reste `null` — donc identité E-PILOTE par défaut — pour le `super_admin`,
/// qui édite au nom de la plateforme et non d'un établissement.
final pdfIssuerProvider = FutureProvider.autoDispose<PdfIssuer?>((ref) async {
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  if (profile == null || profile.role == 'super_admin') {
    OfficialPdfKit.setIssuer(null);
    return null;
  }

  // ⚠️ admin_groupe NE CONNECTE JAMAIS POWERSYNC.
  //
  // C'est la règle centrale du projet : son espace travaille en ligne, sur
  // Supabase direct (`isStaffRole` l'exclut de `db.connect()`). Sa base SQLite
  // locale est donc VIDE, et son profil n'a pas de `school_id` — les deux
  // raisons pour lesquelles `currentSchoolProvider`, puis `currentGroupProvider`
  // qui en dérive, ne rendent rien pour lui.
  //
  // Faute de ce cas, l'émetteur restait null et TOUS les documents de l'espace
  // groupe repartaient sous l'identité par défaut : un bilan du ministère
  // déposé au ministère, signé « E-PILOTE CONGO ». `super_admin` était exclu
  // explicitement, et l'on croyait donc le reste couvert ; admin_groupe passait
  // par le trou du filet, sans erreur ni journal.
  if (profile.role == 'admin_groupe') {
    final gid = profile.groupId;
    if (gid == null || gid.isEmpty) {
      OfficialPdfKit.setIssuer(null);
      return null;
    }
    try {
      final row = await ref
          .watch(supabaseClientProvider)
          .from('school_groups')
          .select('name, logo_url')
          .eq('id', gid)
          .maybeSingle();
      final nom = (row?['name'] as String?)?.trim() ?? '';
      if (nom.isEmpty) {
        OfficialPdfKit.setIssuer(null);
        return null;
      }
      final issuer = PdfIssuer(
        name: nom,
        logo: await _logoImage(row?['logo_url'] as String?),
      );
      OfficialPdfKit.setIssuer(issuer);
      return issuer;
    } catch (e) {
      // Réseau absent au moment de la résolution : le document sort sous
      // l'identité par défaut plutôt que de ne pas sortir du tout.
      debugPrint('ℹ️ Émetteur du groupe non résolu ($e) — identité par défaut.');
      OfficialPdfKit.setIssuer(null);
      return null;
    }
  }

  final group = ref.watch(currentGroupProvider).valueOrNull;
  final school = ref.watch(currentSchoolProvider).valueOrNull;

  final groupName = (group?['name'] as String?)?.trim() ?? '';
  final schoolName = (school?['name'] as String?)?.trim() ?? '';
  if (groupName.isEmpty && schoolName.isEmpty) {
    OfficialPdfKit.setIssuer(null);
    return null;
  }

  // Le groupe en titre, l'école en sous-titre : c'est la hiérarchie réelle, et
  // elle reste lisible quand un réseau compte plusieurs établissements. Si le
  // groupe manque, l'école tient le titre — mieux vaut le nom de l'école seule
  // que le nom d'un fournisseur.
  final issuer = PdfIssuer(
    name: groupName.isNotEmpty ? groupName : schoolName,
    subtitle: groupName.isNotEmpty && schoolName.isNotEmpty ? schoolName : null,
    logo: await _logoImage(group?['logo_url'] as String?),
  );
  OfficialPdfKit.setIssuer(issuer);
  return issuer;
});
