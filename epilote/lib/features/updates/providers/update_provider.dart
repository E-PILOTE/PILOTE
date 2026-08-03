// ════════════════════════════════════════════════════════════════════════════
//  SAVOIR QU'UNE CORRECTION EXISTE
//
//  ── POURQUOI C'EST L'INFRASTRUCTURE LA PLUS IMPORTANTE DU 2 OCTOBRE ────────
//  Sans chemin de mise à jour, le moindre défaut trouvé par une école après le
//  déploiement est DÉFINITIF : il faudrait retourner physiquement sur mille
//  postes. Ce fichier est ce qui transforme une livraison unique en une
//  livraison rattrapable.
//
//  ── TROIS RÈGLES ───────────────────────────────────────────────────────────
//  1. SILENCIEUX EN CAS D'ÉCHEC. Un poste d'école est hors ligne la moitié du
//     temps : c'est le cas NORMAL, pas une erreur. Aucune alerte, aucun
//     journal bruyant — la vérification échoue et on n'en parle plus.
//  2. UNE SEULE FOIS PAR SESSION. On ne réinterroge pas le serveur à chaque
//     ouverture d'écran ; `keepAlive` suffit.
//  3. JAMAIS AUTOMATIQUE. Rien ne se télécharge ni ne s'installe sans que
//     quelqu'un l'ait demandé. Une application qui redémarre au milieu d'une
//     saisie de rentrée fait perdre le travail en cours.
//
//  ⚠️ CE PROVIDER APPELLE SUPABASE DEPUIS L'ESPACE ÉCOLE. Ce n'est pas une
//  entorse à la règle offline-first : une version publiée n'est pas une donnée
//  d'établissement, elle ne peut pas vivre dans PowerSync, et de toute façon
//  télécharger une mise à jour exige le réseau. Même raisonnement que le
//  guichet national de l'élève.
// ════════════════════════════════════════════════════════════════════════════

import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../auth/providers/auth_provider.dart';

/// Une version publiée de l'application.
class AppRelease {
  const AppRelease({
    required this.version,
    required this.buildNumber,
    required this.downloadUrl,
    required this.sha256,
    this.sizeBytes,
    this.notes,
    this.minBuild,
    this.isMandatory = false,
    this.publishedAt,
  });

  factory AppRelease.fromMap(Map<String, dynamic> m) => AppRelease(
        version:     m['version'] as String? ?? '',
        buildNumber: (m['build_number'] as num?)?.toInt() ?? 0,
        downloadUrl: m['download_url'] as String? ?? '',
        sha256:      (m['sha256'] as String? ?? '').toLowerCase(),
        sizeBytes:   (m['size_bytes'] as num?)?.toInt(),
        notes:       m['notes'] as String?,
        minBuild:    (m['min_build'] as num?)?.toInt(),
        isMandatory: m['is_mandatory'] as bool? ?? false,
        publishedAt: m['published_at'] == null
            ? null
            : DateTime.tryParse(m['published_at'] as String),
      );

  final String version, downloadUrl, sha256;
  final int buildNumber;
  final int? sizeBytes, minBuild;
  final String? notes;
  final bool isMandatory;
  final DateTime? publishedAt;

  String get tailleLisible {
    final o = sizeBytes;
    if (o == null || o <= 0) return '';
    final mo = o / (1024 * 1024);
    return '${mo.toStringAsFixed(1)} Mo';
  }
}

/// Ce que le poste doit faire de ce qu'il a appris.
class EtatMiseAJour {
  const EtatMiseAJour({
    required this.buildInstalle,
    required this.versionInstallee,
    this.disponible,
  });

  final int buildInstalle;
  final String versionInstallee;

  /// `null` quand la vérification n'a rien donné — hors ligne, table vide,
  /// serveur injoignable. Indistinguable à dessein : dans les trois cas, il n'y
  /// a rien à proposer et rien à signaler.
  final AppRelease? disponible;

  bool get aJour => disponible == null || disponible!.buildNumber <= buildInstalle;

  /// Une version plus récente existe.
  bool get enRetard => !aJour;

  /// La version installée est trop ancienne pour rester fiable — le serveur
  /// l'a déclaré, on ne le décide pas ici.
  bool get tropAncienne {
    final r = disponible;
    if (r == null) return false;
    return r.isMandatory ||
        (r.minBuild != null && buildInstalle < r.minBuild!);
  }

  static const inconnu =
      EtatMiseAJour(buildInstalle: 0, versionInstallee: '—');
}

/// Interroge le serveur une fois par session. Ne lève jamais.
final miseAJourProvider = FutureProvider<EtatMiseAJour>((ref) async {
  ref.keepAlive();

  final info = await PackageInfo.fromPlatform();
  final build = int.tryParse(info.buildNumber) ?? 0;
  final installee = info.buildNumber.isEmpty
      ? info.version
      : '${info.version} (build ${info.buildNumber})';

  // Un build inconnu (0) rendrait TOUTE version publiée « plus récente », et
  // l'écran réclamerait une mise à jour en boucle. Mieux vaut se taire.
  if (build == 0) {
    return EtatMiseAJour(buildInstalle: 0, versionInstallee: installee);
  }

  try {
    final client = ref.read(supabaseClientProvider);
    final row = await client.rpc('derniere_version', params: {
      'p_platform': plateformeCourante(),
      'p_channel': 'stable',
    });
    if (row is! Map || row.isEmpty) {
      return EtatMiseAJour(buildInstalle: build, versionInstallee: installee);
    }
    return EtatMiseAJour(
      buildInstalle: build,
      versionInstallee: installee,
      disponible: AppRelease.fromMap(Map<String, dynamic>.from(row)),
    );
  } catch (_) {
    // Hors ligne, session expirée, serveur muet : rien à dire. Voir l'en-tête.
    return EtatMiseAJour(buildInstalle: build, versionInstallee: installee);
  }
});

/// La plateforme telle que la table la nomme.
///
/// Un poste Linux de développement ne doit pas se voir proposer l'installateur
/// Windows : la table est indexée par plateforme, et une chaîne inconnue ne
/// remonte simplement rien — c'est le comportement voulu.
String plateformeCourante() {
  if (Platform.isWindows) return 'windows';
  if (Platform.isMacOS) return 'macos';
  if (Platform.isLinux) return 'linux';
  return 'inconnue';
}
