// ════════════════════════════════════════════════════════════════════════════
//  PUBLIER UNE VERSION
//
//  Le canal de mise à jour existait déjà côté poste : l'application sait
//  demander s'il y a plus récent, télécharger, vérifier l'empreinte, installer.
//  Mais RIEN ne pouvait publier. Déclarer une version se faisait par un INSERT
//  SQL recopié à la main depuis le `manifest.json` de l'intégration continue.
//
//  Autrement dit : le 3 octobre, un défaut découvert dans une école n'aurait
//  pu être corrigé que par quelqu'un ayant un accès `psql` à la base de
//  production. Ce fichier ferme cette boucle.
//
//  ⚠️ Espace super_admin : Supabase en direct, jamais PowerSync.
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';

class ReleasePubliee {
  const ReleasePubliee({
    required this.id,
    required this.version,
    required this.buildNumber,
    required this.platform,
    required this.channel,
    required this.downloadUrl,
    required this.sha256,
    required this.isMandatory,
    this.sizeBytes,
    this.notes,
    this.minBuild,
    this.publishedAt,
  });

  factory ReleasePubliee.fromRow(Map<String, dynamic> r) => ReleasePubliee(
        id: r['id'] as String,
        version: r['version'] as String? ?? '',
        buildNumber: (r['build_number'] as num?)?.toInt() ?? 0,
        platform: r['platform'] as String? ?? 'windows',
        channel: r['channel'] as String? ?? 'stable',
        downloadUrl: r['download_url'] as String? ?? '',
        sha256: (r['sha256'] as String? ?? '').toLowerCase(),
        sizeBytes: (r['size_bytes'] as num?)?.toInt(),
        notes: r['notes'] as String?,
        minBuild: (r['min_build'] as num?)?.toInt(),
        isMandatory: r['is_mandatory'] as bool? ?? false,
        publishedAt: r['published_at'] == null
            ? null
            : DateTime.tryParse(r['published_at'] as String),
      );

  final String id, version, platform, channel, downloadUrl, sha256;
  final int buildNumber;
  final int? sizeBytes, minBuild;
  final String? notes;
  final bool isMandatory;
  final DateTime? publishedAt;

  String get taille {
    final o = sizeBytes;
    if (o == null || o <= 0) return '—';
    return '${(o / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }
}

/// Toutes les versions publiées, la plus récente d'abord.
final releasesProvider =
    FutureProvider.autoDispose<List<ReleasePubliee>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final rows = await client
      .from('app_releases')
      .select()
      .order('published_at', ascending: false) as List;
  return [
    for (final r in rows) ReleasePubliee.fromRow(r as Map<String, dynamic>),
  ];
});

/// Ce que le formulaire refuse d'envoyer, et pourquoi.
///
/// Ces contrôles existent AUSSI en base (contraintes CHECK et index unique de
/// la migration 0087). On les redouble ici non par méfiance envers le serveur,
/// mais parce qu'un message d'erreur Postgres brut n'apprend rien à celui qui
/// publie — et parce qu'une version mal déclarée ne se rattrape pas : mille
/// postes l'auront déjà lue.
class ControleRelease {
  const ControleRelease._(this.champ, this.message);
  final String champ, message;

  static const _hexa = r'^[0-9a-f]{64}$';

  /// `null` si tout va bien.
  static ControleRelease? verifier({
    required String version,
    required String build,
    required String url,
    required String sha,
    required String? minBuild,
    required List<ReleasePubliee> deja,
    required String platform,
    required String channel,
  }) {
    if (version.trim().isEmpty) {
      return const ControleRelease._('version', 'Indiquez le numéro de version.');
    }
    final b = int.tryParse(build.trim());
    if (b == null || b <= 0) {
      return const ControleRelease._(
          'build', 'Le numéro de build doit être un entier positif.');
    }

    // ⚠️ Le poste compare des ENTIERS : « 42 » est plus récent que « 9 », alors
    // que la comparaison de chaînes dirait l'inverse. Un build qui recule ou se
    // répète rendrait la mise à jour invisible pour tout le parc.
    for (final r in deja) {
      if (r.platform != platform || r.channel != channel) continue;
      if (r.buildNumber == b) {
        return ControleRelease._('build',
            'Le build $b est déjà publié pour $platform / $channel '
            '(version ${r.version}).');
      }
      if (r.buildNumber > b) {
        return ControleRelease._('build',
            'Le build $b est INFÉRIEUR au dernier publié (${r.buildNumber}). '
            'Les postes ne verraient jamais cette version.');
      }
    }

    final u = url.trim();
    if (!u.startsWith('https://')) {
      // Un installateur téléchargé en clair peut être remplacé en chemin. On
      // vérifie l'empreinte après coup, mais autant ne pas ouvrir la porte.
      return const ControleRelease._(
          'url', 'L\'adresse de téléchargement doit être en https://.');
    }

    final s = sha.trim().toLowerCase();
    if (!RegExp(_hexa).hasMatch(s)) {
      return const ControleRelease._('sha',
          'L\'empreinte SHA-256 doit faire 64 caractères hexadécimaux. '
          'Reprenez-la telle quelle depuis le manifest.json de la '
          'compilation.');
    }

    if (minBuild != null && minBuild.trim().isNotEmpty) {
      final m = int.tryParse(minBuild.trim());
      if (m == null || m <= 0) {
        return const ControleRelease._(
            'minBuild', 'Le build minimum doit être un entier positif.');
      }
      if (m > b) {
        return const ControleRelease._('minBuild',
            'Le build minimum ne peut pas dépasser celui que vous publiez : '
            'les postes seraient bloqués sur une version qui n\'existe pas.');
      }
    }
    return null;
  }
}

class ReleasesService {
  ReleasesService(this._ref);
  final Ref _ref;

  /// Déclare une version. Les postes la verront à leur prochaine ouverture.
  Future<void> publier({
    required String version,
    required int buildNumber,
    required String platform,
    required String channel,
    required String downloadUrl,
    required String sha256,
    int? sizeBytes,
    String? notes,
    int? minBuild,
    bool isMandatory = false,
  }) async {
    final client = _ref.read(supabaseClientProvider);
    await client.from('app_releases').insert({
      'version': version.trim(),
      'build_number': buildNumber,
      'platform': platform,
      'channel': channel,
      'download_url': downloadUrl.trim(),
      'sha256': sha256.trim().toLowerCase(),
      'size_bytes': sizeBytes,
      'notes': (notes?.trim().isEmpty ?? true) ? null : notes!.trim(),
      'min_build': minBuild,
      'is_mandatory': isMandatory,
      'created_by': _ref.read(authNotifierProvider).valueOrNull?.id,
    });
    _ref.invalidate(releasesProvider);
  }

  /// Retire une version publiée par erreur.
  ///
  /// On ne la « désactive » pas : la table n'a pas d'état, et un poste qui
  /// l'aurait déjà téléchargée l'a déjà. Retirer la ligne empêche seulement
  /// les suivants de la voir — c'est tout ce qu'on peut promettre, et c'est ce
  /// que l'écran doit dire.
  Future<void> retirer(String id) async {
    await _ref.read(supabaseClientProvider)
        .from('app_releases')
        .delete()
        .eq('id', id);
    _ref.invalidate(releasesProvider);
  }
}

final releasesServiceProvider =
    Provider<ReleasesService>((ref) => ReleasesService(ref));
