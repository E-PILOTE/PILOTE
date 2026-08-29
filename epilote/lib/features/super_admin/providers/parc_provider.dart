import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE RELEVÉ DU PARC — quelle version tourne où
//
//  Il répond à UNE question, celle dont dépend la migration 0146 : « peut-on
//  supprimer une colonne sans tuer la synchro d'un poste resté en arrière ? »
//
//  ── LE CHIFFRE QUI DÉCIDE N'EST PAS CELUI QU'ON REGARDE ────────────────────
//  On regarde « combien sont à jour ». Ce qui décide est « combien n'ont RIEN
//  dit ». Les builds antérieurs à la migration 0150 ne savent pas se signaler :
//  ils n'apparaîtront jamais. Un profil absent du relevé est donc soit sur une
//  version ancienne, soit jamais revenu — deux risques, et aucun moyen de les
//  distinguer.
//
//  D'où [CouvertureParc.certitude] : tant qu'un seul profil n'a rien signalé,
//  la réponse à « tout le parc a-t-il suivi ? » est NON. Pas « probablement
//  oui ».
// ════════════════════════════════════════════════════════════════════════════

/// Une ligne du relevé : un build, sur une plateforme, et combien de profils.
class LigneParc {
  const LigneParc({
    required this.buildNumber,
    required this.version,
    required this.platform,
    required this.profils,
    this.dernierSignalement,
  });

  factory LigneParc.fromMap(Map<String, dynamic> m) => LigneParc(
        buildNumber: (m['build_number'] as num?)?.toInt() ?? 0,
        version: m['version'] as String? ?? '—',
        platform: m['platform'] as String? ?? 'inconnue',
        profils: (m['profils'] as num?)?.toInt() ?? 0,
        dernierSignalement: m['dernier_signalement'] == null
            ? null
            : DateTime.tryParse(m['dernier_signalement'] as String),
      );

  final int buildNumber, profils;
  final String version, platform;
  final DateTime? dernierSignalement;
}

/// Ce que le parc permet — ou interdit — de conclure.
class CouvertureParc {
  const CouvertureParc({
    required this.aJour,
    required this.enRetard,
    required this.jamaisSignale,
    required this.totalProfils,
    required this.seuil,
    this.plusAncien,
  });

  factory CouvertureParc.fromMap(Map<String, dynamic> m, int seuil) =>
      CouvertureParc(
        aJour: (m['a_jour'] as num?)?.toInt() ?? 0,
        enRetard: (m['en_retard'] as num?)?.toInt() ?? 0,
        jamaisSignale: (m['jamais_signale'] as num?)?.toInt() ?? 0,
        totalProfils: (m['total_profils'] as num?)?.toInt() ?? 0,
        plusAncien: (m['plus_ancien'] as num?)?.toInt(),
        seuil: seuil,
      );

  final int aJour, enRetard, jamaisSignale, totalProfils, seuil;

  /// Le plus vieux build effectivement observé. `null` si personne n'a parlé.
  final int? plusAncien;

  /// Les profils qui se sont signalés, quel que soit leur build.
  int get connus => aJour + enRetard;

  /// ⚠️ La seule question qui compte, et elle se répond par oui ou non.
  ///
  /// Un seul profil en retard, ou un seul muet, et c'est non. On ne conclut
  /// pas « à 99 % » quand se tromper coupe la synchronisation d'une école en
  /// silence, sans un message à l'écran, jusqu'à ce que quelqu'un s'en
  /// aperçoive des semaines plus tard.
  bool get certitude =>
      totalProfils > 0 && enRetard == 0 && jamaisSignale == 0;

  /// Part des profils dont on connaît la version. Ce n'est PAS un taux de mise
  /// à jour : c'est un taux de connaissance.
  double get partConnue => totalProfils == 0 ? 0 : connus * 100 / totalProfils;
}

/// Le premier build qui sait à la fois **se passer des colonnes Firebase** et
/// **se signaler**. Voir `docs/DEPLOIEMENT_ORDRE.md`.
///
/// ⚠️ Ce n'est pas 21, comme l'écrivait la consigne d'origine. Les colonnes ont
/// bien quitté le schéma local au build 21 — mais 21, 22 et 23 n'ont JAMAIS été
/// distribués. Le parc passe de 20 à 24 directement.
///
/// Et 24 n'est pas seulement « le prochain » : c'est le premier build qui
/// contient le relevé. Aucun poste antérieur ne peut apparaître dans la table,
/// quelle que soit sa version. C'est pourquoi `en_retard` restera presque
/// toujours à zéro et que **le chiffre qui décide est `jamais_signale`**.
const int kBuildSansFirebase = 24;

final parcVersionsProvider = FutureProvider<List<LigneParc>>((ref) async {
  final rows = await ref.read(supabaseClientProvider).rpc('parc_versions');
  if (rows is! List) return const [];
  return [
    for (final r in rows) LigneParc.fromMap(Map<String, dynamic>.from(r as Map)),
  ];
});

final parcCouvertureProvider =
    FutureProvider.family<CouvertureParc, int>((ref, seuil) async {
  final rows = await ref
      .read(supabaseClientProvider)
      .rpc('parc_couverture', params: {'p_build_min': seuil});
  // La fonction rend toujours une ligne, même vide — mais une RPC absente ou
  // une réponse inattendue ne doit pas casser l'écran.
  if (rows is! List || rows.isEmpty) {
    return CouvertureParc(
      aJour: 0,
      enRetard: 0,
      jamaisSignale: 0,
      totalProfils: 0,
      seuil: seuil,
    );
  }
  return CouvertureParc.fromMap(
    Map<String, dynamic>.from(rows.first as Map),
    seuil,
  );
});
