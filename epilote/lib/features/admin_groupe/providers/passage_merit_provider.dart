import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/mention.dart';
import '../../auth/providers/auth_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  MEILLEURS ÉLÈVES DES CLASSES DE PASSAGE — le palmarès que la plateforme
//  produit à partir de SES PROPRES données.
//
//  ── LE PARTAGE DES RÔLES, QUI COMMANDE TOUT CET ÉCRAN ───────────────────────
//  Pour les CLASSES D'EXAMEN (CM2 → CEPE, 3e → BET, Tle → Bac), la plateforme
//  ne calcule rien : elle produit la LISTE DES CANDIDATS transmise à la DEC,
//  qui organise l'épreuve et proclame les résultats. Un classement bâti là
//  dessus supposerait des résultats que la plateforme ne détient pas.
//
//  Pour les CLASSES DE PASSAGE — celles dont le passage au niveau supérieur se
//  décide sur le travail de l'année — c'est l'inverse : la plateforme détient
//  et calcule les moyennes. C'est donc là, et seulement là, qu'elle peut
//  désigner les meilleurs élèves du réseau.
//
//  Dans le réseau METP : 81 élèves en classes d'examen, 216 en classes de
//  passage. Ne classer que les premiers laissait de côté les trois quarts du
//  réseau — précisément ceux dont on a les notes.
//
//  ── LE TRIMESTRE N'EST PAS UN FILTRE, C'EST L'UNITÉ ─────────────────────────
//  Une moyenne n'existe pas « dans l'absolu » : elle est trimestrielle. Un
//  palmarès sans trimestre indiqué mélangerait des périodes et ne se rejouerait
//  pas deux fois pareil. On classe donc toujours SUR UN TRIMESTRE (ou sur
//  l'année entière, dit explicitement).
//
//  Le calcul vit dans `get_passage_merit` (migration 0061) : agréger côté
//  serveur est la seule option tenable à l'échelle nationale — rapatrier les
//  notes de 1 000 écoles pour les moyenner sur le poste serait intenable.
// ════════════════════════════════════════════════════════════════════════════

class PassageEntry {
  const PassageEntry({
    required this.studentId,
    required this.fullName,
    required this.schoolName,
    required this.className,
    required this.average,
    required this.subjectCount,
    this.gender,
    this.department,
    this.levelCode,
    this.cycleCode,
    this.filiere,
    this.classAverage,
  });

  final String studentId;
  final String fullName;
  final String schoolName;
  final String className;
  final double average;

  /// Nombre de matières ayant servi au calcul — une moyenne sur 2 matières
  /// n'a pas le poids d'une moyenne sur 12, et l'écran doit pouvoir le dire.
  final int subjectCount;

  final String? gender;
  final String? department;
  final String? levelCode;
  final String? cycleCode;
  final String? filiere;

  /// Moyenne de la classe : sans elle, 16/20 ne se lit pas.
  final double? classAverage;

  bool get isFemale => gender == 'F';

  /// Mention par la source unique (cf. `core/utils/mention.dart`).
  String get mention => mentionFor(average);

  double? get delta => classAverage == null ? null : average - classAverage!;
}

/// Trimestre du palmarès. `null` = année entière.
class Trimester {
  const Trimester({
    required this.id,
    required this.label,
    required this.number,
    required this.isCurrent,
  });

  final String id;
  final String label;
  final int number;
  final bool isCurrent;
}

final trimestersProvider =
    FutureProvider.autoDispose<List<Trimester>>((ref) async {
  ref.keepAlive();
  final client = ref.watch(supabaseClientProvider);
  final groupId = ref.watch(authNotifierProvider).valueOrNull?.groupId;
  if (groupId == null) return const [];

  final rows = await client
      .from('trimesters')
      .select('id, label, trimester_number, is_current')
      .eq('group_id', groupId)
      // ⚠️ `ascending: true` EXPLICITE : `.order()` de supabase-dart trie en
      // DESCENDANT par défaut. Sans lui, les périodes se présentaient
      // « 3e, 2e, 1er trimestre » — l'année scolaire à l'envers.
      .order('trimester_number', ascending: true);

  return [
    for (final r in rows as List)
      Trimester(
        id: r['id'] as String,
        label: (r['label'] as String?) ?? 'Trimestre ${r['trimester_number']}',
        number: (r['trimester_number'] as num?)?.toInt() ?? 0,
        isCurrent: r['is_current'] == true,
      ),
  ];
});

/// Critères du palmarès des classes de passage.
class PassageFilter {
  const PassageFilter({
    this.trimesterId,
    this.levelCode,
    this.department,
    this.filiere,
    this.topN = 10,
  });

  /// `null` = année entière. Ce n'est PAS « pas de filtre » : c'est un choix
  /// que le document doit énoncer.
  final String? trimesterId;
  final String? levelCode;

  /// Territoire — une commission de bourses attribue par département, pas sur
  /// un classement national qu'un seul chef-lieu occuperait.
  final String? department;

  /// Filière technique — l'axe de pilotage propre au METP.
  final String? filiere;

  final int topN;

  PassageFilter copyWith({
    Object? trimesterId = _keep,
    Object? levelCode = _keep,
    Object? department = _keep,
    Object? filiere = _keep,
    int? topN,
  }) =>
      PassageFilter(
        trimesterId: identical(trimesterId, _keep)
            ? this.trimesterId
            : trimesterId as String?,
        levelCode:
            identical(levelCode, _keep) ? this.levelCode : levelCode as String?,
        department: identical(department, _keep)
            ? this.department
            : department as String?,
        filiere: identical(filiere, _keep) ? this.filiere : filiere as String?,
        topN: topN ?? this.topN,
      );

  static const Object _keep = Object();

  /// Périmètre écrit en toutes lettres — il accompagne le classement partout,
  /// à l'écran comme dans le PDF : un 1ᵉʳ filtré sur une filière n'est pas un
  /// 1ᵉʳ national, et un document qui l'omet n'est pas opposable.
  String scopeLabel(String periodLabel) => [
        periodLabel,
        if (department != null) 'département $department',
        ?filiere,
        if (levelCode != null) 'niveau $levelCode',
      ].join(' · ');

  @override
  bool operator ==(Object other) =>
      other is PassageFilter &&
      other.trimesterId == trimesterId &&
      other.levelCode == levelCode &&
      other.department == department &&
      other.filiere == filiere &&
      other.topN == topN;

  @override
  int get hashCode =>
      Object.hash(trimesterId, levelCode, department, filiere, topN);
}

final passageFilterProvider =
    StateProvider.autoDispose<PassageFilter>((ref) => const PassageFilter());

/// Rang dense, ex æquo compris — même règle que le palmarès des examens :
/// deux moyennes identiques donnent le MÊME rang, et le `topN` ne coupe jamais
/// un groupe d'égalité en deux.
class RankedPassage {
  const RankedPassage(this.rank, this.entry, {this.exAequo = false});
  final int rank;
  final PassageEntry entry;
  final bool exAequo;
}

List<RankedPassage> rankPassage(List<PassageEntry> sorted, int topN) {
  final out = <RankedPassage>[];
  var rank = 0;
  double? previous;
  for (var i = 0; i < sorted.length; i++) {
    if (previous == null || sorted[i].average != previous) {
      rank = i + 1;
      previous = sorted[i].average;
    }
    out.add(RankedPassage(rank, sorted[i]));
  }

  final limited = <RankedPassage>[];
  for (final r in out) {
    if (limited.length >= topN && r.rank > topN) break;
    limited.add(r);
  }

  final counts = <int, int>{};
  for (final r in limited) {
    counts[r.rank] = (counts[r.rank] ?? 0) + 1;
  }
  return [
    for (final r in limited)
      RankedPassage(r.rank, r.entry, exAequo: (counts[r.rank] ?? 0) > 1),
  ];
}

class PassageData {
  const PassageData({
    required this.entries,
    required this.levels,
    this.departments = const [],
    this.filieres = const [],
  });

  final List<PassageEntry> entries;

  /// Niveaux présents — comparer une 6e à une Terminale n'aurait pas de sens,
  /// l'écran doit pouvoir restreindre.
  final List<String> levels;

  /// Territoires et filières RÉELLEMENT classés. Jamais une nomenclature
  /// théorique : un filtre qui ne renvoie jamais rien use la confiance.
  final List<String> departments;
  final List<String> filieres;

  static const empty = PassageData(entries: [], levels: []);
}

final passageMeritProvider =
    FutureProvider.autoDispose<PassageData>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final groupId = ref.watch(authNotifierProvider).valueOrNull?.groupId;
  if (groupId == null) return PassageData.empty;

  final filter = ref.watch(passageFilterProvider);

  final years = await client
      .from('academic_years')
      .select('id')
      .eq('group_id', groupId)
      .eq('is_current', true)
      .limit(1);
  final yearList = years as List;
  if (yearList.isEmpty) return PassageData.empty;
  final yearId = (yearList.first as Map<String, dynamic>)['id'] as String;

  // On demande large et on rogne côté client : le `topN` ne doit jamais couper
  // un groupe d'ex æquo, ce qui suppose de voir un peu au-delà du plafond.
  final rows = await client.rpc('get_passage_merit', params: {
    'p_group_id': groupId,
    'p_academic_year_id': yearId,
    'p_trimester_id': filter.trimesterId,
    'p_level_code': filter.levelCode,
    'p_limit': 200,
    // ⚠️ Territoire et filière filtrent EN BASE, avant la coupe du classement
    // (migration 0064). Les appliquer côté client donnerait « les meilleurs du
    // Niari parmi les 200 meilleurs du pays » — faux sans le dire.
    'p_department': filter.department,
    'p_filiere_label': filter.filiere,
  });

  final entries = [
    for (final r in (rows as List? ?? const []))
      _toEntry(r as Map<String, dynamic>),
  ];

  // Niveaux proposés : ceux réellement classés, jamais une nomenclature
  // théorique qui offrirait un filtre toujours vide.
  final levels = <String>{
    for (final e in entries)
      if ((e.levelCode ?? '').isNotEmpty) e.levelCode!,
  }.toList()
    ..sort();

  // Les options des filtres se lisent sur le classement NON restreint : sinon
  // choisir « Niari » ferait disparaître tous les autres départements de la
  // liste déroulante, et on ne pourrait plus en sortir.
  final unfiltered = filter.department == null && filter.filiere == null
      ? entries
      : [
          for (final r in (await client.rpc('get_passage_merit', params: {
                'p_group_id': groupId,
                'p_academic_year_id': yearId,
                'p_trimester_id': filter.trimesterId,
                'p_level_code': filter.levelCode,
                'p_limit': 200,
              }) as List? ??
              const []))
            _toEntry(r as Map<String, dynamic>),
        ];

  return PassageData(
    entries: entries,
    levels: levels,
    departments: _distinct(unfiltered.map((e) => e.department)),
    filieres: _distinct(unfiltered.map((e) => e.filiere)),
  );
});

List<String> _distinct(Iterable<String?> values) => (<String>{
      for (final v in values)
        if ((v ?? '').trim().isNotEmpty) v!.trim(),
    }.toList()
      ..sort());

PassageEntry _toEntry(Map<String, dynamic> r) => PassageEntry(
      studentId: r['student_id'] as String? ?? '',
      fullName: (r['full_name'] as String?)?.trim().isNotEmpty == true
          ? (r['full_name'] as String).trim()
          : 'Élève sans nom',
      schoolName: (r['school_name'] as String?) ?? '—',
      className: (r['class_name'] as String?) ?? '—',
      average: (r['average'] as num?)?.toDouble() ?? 0,
      subjectCount: (r['subject_count'] as num?)?.toInt() ?? 0,
      gender: r['gender'] as String?,
      department: r['department'] as String?,
      levelCode: r['level_code'] as String?,
      cycleCode: r['cycle_code'] as String?,
      filiere: r['filiere_label'] as String?,
      classAverage: (r['class_average'] as num?)?.toDouble(),
    );

/// Part de filles du palmarès. `null` sur sélection vide — 0 % dirait
/// « aucune fille » là où il n'y a personne à compter.
double? passageFemaleShare(List<RankedPassage> rows) {
  if (rows.isEmpty) return null;
  return rows.where((r) => r.entry.isFemale).length / rows.length * 100;
}
