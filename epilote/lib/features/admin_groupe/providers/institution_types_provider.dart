import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/providers/auth_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE TYPE D'ÉTABLISSEMENT — ce qu'une école EST
//
//  ⚠️ À NE PAS CONFONDRE AVEC `schools.school_type`, qui vaut `public` ou
//  `prive` : ça, c'est le STATUT JURIDIQUE. Le type d'établissement dit tout
//  autre chose — CEG, CET, lycée général, lycée technique, centre de métiers.
//  Avant la migration 0151, rien dans la base ne permettait de dire d'une école
//  qu'elle est un CET.
//
//  ⚠️ ET À NE PAS CONFONDRE AVEC UN DIPLÔME. CET ≠ CAP. CET ≠ BET. Le CET est
//  un ÉTABLISSEMENT du premier cycle ; le BET est le diplôme qu'on y prépare.
//  Ranger l'un pour l'autre rend « combien d'élèves en CET ? » insoluble.
//
//  ── LA TUTELLE FILTRE, ET C'EST TOUT L'INTÉRÊT ────────────────────────────
//  Un groupe relève d'UN ministère (migration 0153). Proposer « lycée
//  technique » à un groupe MEPSA n'aurait aucun sens administratif : chaque
//  ministère agrée SES propres établissements, par sa propre commission. La
//  liste est donc réduite à la tutelle du groupe — ce qui, accessoirement,
//  fait passer huit types à quatre et rend le choix lisible.
//
//  ── EN LIGNE, PAS HORS LIGNE ──────────────────────────────────────────────
//  Ce provider sert l'espace admin_groupe, qui lit Supabase directement.
//  `institution_types` n'est pas dans le schéma PowerSync local : aucun poste
//  école ne la lit aujourd'hui. Le jour où un document d'école devra imprimer
//  « Collège d'Enseignement Technique », il faudra l'ajouter aux sync-rules ET
//  au schéma local — pas seulement à l'un des deux.
// ════════════════════════════════════════════════════════════════════════════

class InstitutionType {
  const InstitutionType({
    required this.id,
    required this.code,
    required this.name,
    required this.statut,
    this.shortName,
    this.tutelle,
    this.cycleCode,
    this.description,
    this.dureeMin,
    this.dureeMax,
  });

  factory InstitutionType.fromRow(Map<String, dynamic> r) => InstitutionType(
        id: r['id'] as String,
        code: r['code'] as String? ?? '',
        name: r['name'] as String? ?? '—',
        shortName: r['short_name'] as String?,
        tutelle: r['tutelle'] as String?,
        cycleCode: r['cycle_code'] as String?,
        description: r['description'] as String?,
        dureeMin: (r['duree_min_annees'] as num?)?.toInt(),
        dureeMax: (r['duree_max_annees'] as num?)?.toInt(),
        statut: r['statut'] as String? ?? 'a_verifier',
      );

  final String id;
  final String code;
  final String name;
  final String? shortName;
  final String? tutelle;
  final String? cycleCode;
  final String? description;

  /// Durée du cursus. Deux bornes parce que le CET dure DEUX À TROIS ans selon
  /// la filière : une valeur unique serait fausse la moitié du temps.
  final int? dureeMin, dureeMax;

  /// `en_vigueur` | `projet_reforme` | `historique` | `a_verifier`.
  /// La réforme de janvier 2026 n'est pas promulguée : ne jamais opposer une
  /// règle `projet_reforme` à un établissement.
  final String statut;

  bool get enVigueur => statut == 'en_vigueur';

  /// « 2 à 3 ans », « 3 ans », ou `null` si la durée n'est pas établie.
  /// ⚠️ Rien n'est inventé : une durée absente reste absente.
  String? get dureeLabel {
    if (dureeMin == null) return null;
    if (dureeMax == null || dureeMax == dureeMin) return '$dureeMin ans';
    return '$dureeMin à $dureeMax ans';
  }

  String get libelleCourt => shortName ?? name;
}

/// Types d'établissement de la tutelle [tutelle].
///
/// Passer `null` rend la liste complète — utile à un écran plateforme, jamais
/// à la fiche d'une école : une école appartient à un groupe, un groupe à un
/// ministère.
final institutionTypesProvider = FutureProvider.autoDispose
    .family<List<InstitutionType>, String?>((ref, tutelle) async {
  final client = ref.watch(supabaseClientProvider);
  var q = client
      .from('institution_types')
      .select('id, code, name, short_name, tutelle, cycle_code, description, '
          'duree_min_annees, duree_max_annees, statut')
      .eq('is_active', true);
  if (tutelle != null) q = q.eq('tutelle', tutelle);
  final rows = await q.order('order_index') as List;
  return [
    for (final r in rows) InstitutionType.fromRow(r as Map<String, dynamic>),
  ];
});
