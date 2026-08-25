import 'package:postgrest/postgrest.dart';

// ════════════════════════════════════════════════════════════════════════════
//  RAMENER TOUTES LES LIGNES, PAS LES MILLE PREMIÈRES
//
//  ── CE QUI S'EST PASSÉ ─────────────────────────────────────────────────────
//  Le tableau de bord annonçait « 1.0 K élèves » sur une base qui en comptait
//  9 104. Le compte se faisait en RAMENANT les lignes puis en prenant leur
//  `.length` — or PostgREST plafonne une réponse à 1 000 lignes. Le chiffre
//  affiché n'était pas l'effectif national : c'était la limite de pagination,
//  présentée à un ministère comme une mesure. Et il est d'autant plus crédible
//  qu'il tombe rond.
//
//  ── QUAND UTILISER QUOI ────────────────────────────────────────────────────
//  • Un COMPTE seul → `.count(CountOption.exact)`. Une seule requête, aucun
//    transfert de lignes. C'est presque toujours ce qu'il faut.
//  • Une VENTILATION (par école, par département, par genre…) → il faut les
//    lignes, donc `fetchAllRows` ci-dessous, qui pagine jusqu'à épuisement.
//
//  À l'échelle visée — plus de 1 000 écoles — la différence n'est pas
//  cosmétique : sans pagination, tout agrégat national plafonne silencieusement.
// ════════════════════════════════════════════════════════════════════════════

/// Taille d'une page. Alignée sur le plafond usuel de PostgREST : la dépasser
/// ne sert à rien, le serveur tronquerait.
const int kPageSize = 1000;

/// Ramène TOUTES les lignes d'une requête, page après page.
///
/// [build] doit reconstruire la requête à chaque appel : un `PostgrestBuilder`
/// ne se rejoue pas une fois exécuté.
///
/// ⚠️ **La requête doit porter un ordre TOTAL.** Chaque page est une requête
/// SÉPARÉE : rien n'oblige deux exécutions à rendre les ex æquo dans le même
/// ordre. Trier sur `name` quand deux écoles sont homonymes, ou sur `fee_type`
/// que des dizaines de lignes partagent, laisse une ligne se faire sauter à la
/// frontière de deux pages — ou compter deux fois. Terminer le tri par une
/// colonne unique (`.order('id')`) suffit et ne change pas l'ordre affiché.
///
/// ```dart
/// final rows = await fetchAllRows(() => client
///     .from('students')
///     .select('school_id, gender')
///     .eq('group_id', groupId));
/// ```
Future<List<Map<String, dynamic>>> fetchAllRows(
  PostgrestTransformBuilder<PostgrestList> Function() build, {
  int pageSize = kPageSize,
}) async {
  final out = <Map<String, dynamic>>[];
  var from = 0;
  while (true) {
    final page = await build().range(from, from + pageSize - 1);
    out.addAll(page.map((r) => Map<String, dynamic>.from(r)));
    // Une page incomplète signe la fin : inutile d'aller redemander du vide.
    if (page.length < pageSize) break;
    from += pageSize;
  }
  return out;
}
