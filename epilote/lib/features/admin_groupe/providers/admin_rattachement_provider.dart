import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/paged_fetch.dart';
import '../../auth/providers/auth_provider.dart';
import '../services/rang_niveau.dart';

// ════════════════════════════════════════════════════════════════════════════
//  RATTACHEMENT DES NIVEAUX — où pointe la 6e de chaque école ?
//
//  Un tarif de portée réseau vise une entrée du RÉFÉRENTIEL
//  (`fee_structures.applies_to_education_level_id`, migration 0101). Chaque
//  poste le traduit en son propre niveau par `school_levels.education_level_id`.
//  Toute la chaîne repose donc sur ce rattachement — et rien ne le montrait.
//
//  Deux façons de le rater, toutes deux SILENCIEUSES :
//
//   1. Le niveau d'une école n'est rattaché à rien (`education_level_id` NULL).
//      Aucun tarif réseau par niveau ne l'atteindra jamais.
//   2. Deux entrées du référentiel décrivent la même année — « Sixième (6e) »
//      au national, « 6ème » créée par le groupe — et les écoles se répartissent
//      entre les deux. Un tarif posé sur l'une manque les écoles de l'autre.
//      C'est le cas réel du METP : trois collèges d'un côté, un de l'autre.
//
//  Cet écran ne corrige rien : il MONTRE. Corriger, c'est décider si une 6e
//  technique est une 6e — et ça, seul le ministère le sait.
// ════════════════════════════════════════════════════════════════════════════

/// Le niveau d'une école, tel qu'elle l'a nommé.
typedef NiveauEcole = ({String schoolId, String schoolName, String levelName});

/// Une entrée du référentiel et les niveaux d'école qui s'y rattachent.
class EntreeReferentiel {
  const EntreeReferentiel({
    required this.id,
    required this.libelle,
    required this.cycle,
    required this.duGroupe,
    required this.rang,
    required this.ecoles,
  });

  final String id;

  /// « Cycle · Filière · Niveau ».
  final String libelle;
  final String cycle;

  /// Créée par le groupe (`education_levels.group_id` non nul).
  final bool duGroupe;

  /// L'année lue dans le libellé, `null` si illisible (cf. [rangDuNiveau]).
  final int? rang;

  final List<NiveauEcole> ecoles;
}

/// Deux entrées ou plus pour la même année, dans le même cycle, avec des écoles
/// des deux côtés. C'est la panne qu'on cherche.
class Divergence {
  const Divergence({required this.cycle, required this.entrees});

  final String cycle;
  final List<EntreeReferentiel> entrees;

  /// Écoles DISTINCTES touchées. Additionner les branches compterait deux fois
  /// celle qui figure des deux côtés — et annoncer « 4 écoles » là où il y en a
  /// trois retire toute confiance au reste de l'écran.
  int get ecolesConcernees => {
        for (final e in entrees)
          for (final s in e.ecoles) s.schoolId,
      }.length;

  /// Les écoles présentes sur PLUSIEURS entrées de la même année : elles
  /// portent deux niveaux pour la même chose, dans leur propre structure.
  ///
  /// C'est le cas le plus net — pas une divergence de doctrine entre écoles,
  /// mais un doublon interne. Souvent le reste d'un essai : le second niveau
  /// n'a aucune classe.
  List<String> get ecolesDedoublees {
    final compte = <String, ({String nom, int n})>{};
    for (final e in entrees) {
      for (final s in e.ecoles) {
        final v = compte[s.schoolId];
        compte[s.schoolId] =
            (nom: s.schoolName, n: (v?.n ?? 0) + 1);
      }
    }
    return [
      for (final v in compte.values)
        if (v.n > 1) v.nom,
    ]..sort();
  }
}

class VueRattachement {
  const VueRattachement({
    required this.entrees,
    required this.orphelins,
    required this.divergences,
  });

  static const vide =
      VueRattachement(entrees: [], orphelins: [], divergences: []);

  /// Entrées du référentiel effectivement utilisées, triées.
  final List<EntreeReferentiel> entrees;

  /// Niveaux d'école rattachés à rien.
  final List<NiveauEcole> orphelins;

  final List<Divergence> divergences;

  int get niveauxNationaux =>
      entrees.where((e) => !e.duGroupe).fold(0, (n, e) => n + e.ecoles.length);
  int get niveauxDuGroupe =>
      entrees.where((e) => e.duGroupe).fold(0, (n, e) => n + e.ecoles.length);
}

/// Vue complète du rattachement, pour le groupe courant.
///
/// ⚠️ Trois lectures paginées : à 1 000 écoles, `school_levels` dépasse
/// largement le plafond PostgREST de 1 000 lignes (180 lignes pour 38 écoles
/// aujourd'hui). Chaque tri se termine par `id` — sans ordre TOTAL, une ligne
/// peut se faire sauter entre deux pages (cf. `paged_fetch.dart`).
final adminRattachementProvider =
    FutureProvider.autoDispose<VueRattachement>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final groupId = ref.watch(authNotifierProvider).valueOrNull?.groupId;
  if (groupId == null) return VueRattachement.vide;

  final ecolesRows = await fetchAllRows(() => client
      .from('schools')
      .select('id, name')
      .eq('group_id', groupId)
      .eq('is_active', true)
      .order('name')
      .order('id'));
  final nomEcole = {
    for (final r in ecolesRows) r['id'] as String: (r['name'] as String?) ?? '—',
  };

  final niveauxRows = await fetchAllRows(() => client
      .from('school_levels')
      .select('id, name, school_id, education_level_id')
      .eq('group_id', groupId)
      .eq('is_active', true)
      .order('name')
      .order('id'));

  final refRows = await fetchAllRows(() => client
      .from('education_levels')
      .select('id, name, group_id, order_index, '
          'education_cycles(name), education_programs(name)')
      .or('group_id.is.null,group_id.eq.$groupId')
      .order('order_index')
      .order('id'));

  // ── Le référentiel, indexé ────────────────────────────────────────────────
  final refs = <String, ({String libelle, String cycle, bool duGroupe, int? rang, int ordre})>{};
  for (final r in refRows) {
    final cycle = ((r['education_cycles'] as Map?)?['name'] as String? ?? '').trim();
    final filiere =
        ((r['education_programs'] as Map?)?['name'] as String? ?? '').trim();
    final niveau = ((r['name'] as String?) ?? '—').trim();
    refs[r['id'] as String] = (
      libelle: [
        if (cycle.isNotEmpty) cycle,
        if (filiere.isNotEmpty) filiere,
        niveau,
      ].join(' · '),
      cycle: cycle,
      duGroupe: r['group_id'] != null,
      // Le rang se lit sur le NOM DU NIVEAU seul : « BTP 3 » dans la filière ne
      // doit pas transformer une 1ère année en 3ème.
      rang: rangDuNiveau(niveau),
      ordre: (r['order_index'] as num?)?.toInt() ?? 0,
    );
  }

  // ── Les niveaux d'école, rangés sous leur entrée ──────────────────────────
  final parRef = <String, List<NiveauEcole>>{};
  final orphelins = <NiveauEcole>[];
  for (final r in niveauxRows) {
    final schoolId = r['school_id'] as String?;
    // `school_id` est nullable : certaines lignes sont des modèles de groupe,
    // pas des niveaux d'une école. Elles ne concernent pas ce rattachement.
    if (schoolId == null) continue;
    final n = (
      schoolId: schoolId,
      schoolName: nomEcole[schoolId] ?? '—',
      levelName: ((r['name'] as String?) ?? '—').trim(),
    );
    final refId = r['education_level_id'] as String?;
    if (refId == null || !refs.containsKey(refId)) {
      orphelins.add(n);
    } else {
      (parRef[refId] ??= []).add(n);
    }
  }

  final entrees = [
    for (final e in parRef.entries)
      EntreeReferentiel(
        id: e.key,
        libelle: refs[e.key]!.libelle,
        cycle: refs[e.key]!.cycle,
        duGroupe: refs[e.key]!.duGroupe,
        rang: refs[e.key]!.rang,
        ecoles: e.value..sort((a, b) => a.schoolName.compareTo(b.schoolName)),
      ),
  ]..sort((a, b) {
      final c = a.cycle.compareTo(b.cycle);
      if (c != 0) return c;
      final o = refs[a.id]!.ordre.compareTo(refs[b.id]!.ordre);
      return o != 0 ? o : a.libelle.compareTo(b.libelle);
    });

  orphelins.sort((a, b) {
    final s = a.schoolName.compareTo(b.schoolName);
    return s != 0 ? s : a.levelName.compareTo(b.levelName);
  });

  return VueRattachement(
    entrees: entrees,
    orphelins: orphelins,
    divergences: chercherDivergences(entrees),
  );
});

/// Les cas où des écoles se répartissent sur plusieurs entrées pour la même
/// année, dans le même cycle.
///
/// Trois conditions, et chacune évite un faux positif :
///  - **même cycle + même rang** : « 1ère année » d'Agriculture et de BTP sont
///    deux vraies filières, pas un doublon — mais elles partagent le rang, donc
///    le cycle seul ne suffit pas… c'est la condition suivante qui tranche ;
///  - **au moins une entrée créée par le groupe** : deux entrées NATIONALES qui
///    partagent un rang relèvent du référentiel national, pas d'un écart que le
///    groupe a créé et peut corriger ;
///  - **des écoles des deux côtés** : sans cela le groupe a simplement renommé,
///    et aucun tarif ne se perd.
///
/// Publique et pure : c'est la règle qu'on veut pouvoir tester.
List<Divergence> chercherDivergences(List<EntreeReferentiel> entrees) {
  final paquets = <String, List<EntreeReferentiel>>{};
  for (final e in entrees) {
    if (e.rang == null) continue; // libellé illisible → on ne devine pas
    (paquets['${e.cycle}#${e.rang}'] ??= []).add(e);
  }

  final out = <Divergence>[];
  for (final p in paquets.values) {
    if (p.length < 2) continue;
    if (!p.any((e) => e.duGroupe)) continue;
    if (p.where((e) => e.ecoles.isNotEmpty).length < 2) continue;
    out.add(Divergence(cycle: p.first.cycle, entrees: p));
  }
  out.sort((a, b) => b.ecolesConcernees.compareTo(a.ecolesConcernees));
  return out;
}
