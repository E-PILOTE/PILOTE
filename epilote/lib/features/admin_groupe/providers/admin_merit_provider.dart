import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show CountOption;

import '../../../core/utils/mention.dart';
import '../../auth/providers/auth_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  PALMARÈS NATIONAL — les meilleurs lauréats du réseau (espace ministère).
//
//  ── POURQUOI SUR L'EXAMEN D'ÉTAT, ET PAS SUR LA MOYENNE DE CLASSE ──────────
//  Un ministère classe des élèves pour une raison précise : attribuer une
//  bourse, une distinction, une affectation. La décision doit être défendable
//  devant un parent qui conteste.
//
//  Or une moyenne de bulletin n'est PAS comparable d'un établissement à
//  l'autre : professeurs différents, exigences différentes, coefficients
//  différents. Classer 14 écoles sur cette base reviendrait à récompenser
//  l'indulgence d'un correcteur. L'examen d'État, lui, est la seule épreuve
//  COMMUNE : même sujet, même jury, même barème. C'est le seul socle
//  comparable, donc le seul opposable.
//
//  Le contrôle continu garde sa valeur — mais comme signal interne à un
//  établissement, jamais comme classement inter-écoles. L'écran l'affiche
//  séparément et le dit.
//
//  ── QUI ENTRE AU PALMARÈS ───────────────────────────────────────────────────
//  Les candidats ADMIS dont la moyenne est connue. Un ajourné n'est pas un
//  lauréat ; un admis sans moyenne saisie ne peut pas être classé sans
//  inventer son rang — il est compté à part (`unranked`) et signalé, jamais
//  glissé en bas de liste comme s'il était le dernier.
// ════════════════════════════════════════════════════════════════════════════

/// Un lauréat classé.
class MeritEntry {
  const MeritEntry({
    required this.studentId,
    required this.fullName,
    required this.schoolId,
    required this.schoolName,
    required this.average,
    this.gender,
    this.department,
    this.filiere,
    this.examShortName,
    this.candidateNumber,
    this.hasScholarship = false,
  });

  final String studentId;
  final String fullName;
  final String schoolId;
  final String schoolName;
  final double average;
  final String? gender; // 'F' | 'M'
  final String? department;
  final String? filiere;
  final String? examShortName;
  final String? candidateNumber;

  /// Déjà boursier : une commission ne réattribue pas deux fois.
  final bool hasScholarship;

  /// Mention recalculée depuis la moyenne par la source unique `mentionFor`,
  /// jamais relue de la base : c'est la garantie que l'écran et le bulletin
  /// disent la même chose (cf. migration 0059).
  String get mention => mentionFor(average);

  bool get isFemale => gender == 'F';
}

/// Un lauréat classé, avec son rang dans la vue courante.
class RankedMerit {
  const RankedMerit(this.rank, this.entry, {this.exAequo = false});
  final int rank;
  final MeritEntry entry;

  /// Vrai si ce rang est partagé avec au moins un autre lauréat.
  final bool exAequo;
}

class MeritData {
  const MeritData({
    required this.entries,
    required this.unranked,
    required this.exams,
    required this.filieres,
    required this.departments,
    required this.yearLabel,
    required this.admittedTotal,
  });

  /// Lauréats classables, déjà triés par moyenne décroissante.
  final List<MeritEntry> entries;

  /// Admis SANS moyenne saisie : hors classement, mais jamais oubliés.
  final int unranked;

  final List<String> exams;
  final List<String> filieres;
  final List<String> departments;
  final String? yearLabel;

  /// Total des admis du réseau — l'assiette du palmarès.
  final int admittedTotal;

  static const empty = MeritData(
    entries: [],
    unranked: 0,
    exams: [],
    filieres: [],
    departments: [],
    yearLabel: null,
    admittedTotal: 0,
  );
}

/// Critères de sélection du palmarès. `null` = pas de restriction — SAUF pour
/// l'examen, qui doit toujours être choisi (cf. [exam]).
class MeritFilter {
  const MeritFilter({
    this.exam,
    this.filiere,
    this.department,
    this.gender,
    this.topN = 10,
  });

  /// Examen classé. **Un palmarès porte sur UN examen, jamais sur plusieurs.**
  ///
  /// C'est le même principe que celui qui exclut les bulletins : deux épreuves
  /// différentes ne sont pas comparables. 18,60 au CEPE (fin de primaire) et
  /// 18,60 au Baccalauréat ne mesurent pas la même chose ; les aligner dans un
  /// classement unique produirait un palmarès qui distingue surtout l'examen le
  /// plus indulgent. Tant qu'un seul examen a des résultats, le mélange ne se
  /// voit pas — c'est précisément pourquoi il fallait le fermer avant.
  ///
  /// `null` ne signifie donc pas « tous les examens » mais « pas encore
  /// déterminé » : l'écran le résout immédiatement (cf. [resolveExam]).
  final String? exam;
  final String? filiere;
  final String? department;
  final String? gender;
  final int topN;

  bool get isDefault =>
      exam == null && filiere == null && department == null && gender == null;

  MeritFilter copyWith({
    Object? exam = _keep,
    Object? filiere = _keep,
    Object? department = _keep,
    Object? gender = _keep,
    int? topN,
  }) =>
      MeritFilter(
        exam: identical(exam, _keep) ? this.exam : exam as String?,
        filiere: identical(filiere, _keep) ? this.filiere : filiere as String?,
        department:
            identical(department, _keep) ? this.department : department as String?,
        gender: identical(gender, _keep) ? this.gender : gender as String?,
        topN: topN ?? this.topN,
      );

  static const Object _keep = Object();

  /// Libellé du périmètre, tel qu'il doit apparaître en tête du document
  /// officiel : un palmarès sans son périmètre n'est pas opposable.
  String get scopeLabel {
    final parts = <String>[
      exam ?? 'examen non déterminé',
      if (filiere != null) 'filière $filiere',
      if (department != null) 'département $department',
      if (gender != null) (gender == 'F' ? 'filles' : 'garçons'),
    ];
    return parts.join(' · ');
  }
}

/// Examen à classer : celui déjà choisi s'il a des lauréats, sinon celui qui en
/// compte le plus. On ne laisse jamais l'écran sur « aucun examen » alors que
/// des résultats existent, et on ne garde jamais un examen devenu vide après un
/// changement de filtre — dans les deux cas l'utilisateur verrait une page vide
/// sans comprendre pourquoi.
String? resolveExam(MeritData data, String? current) {
  if (data.entries.isEmpty) return null;
  final counts = <String, int>{};
  for (final e in data.entries) {
    final name = e.examShortName;
    if (name != null) counts[name] = (counts[name] ?? 0) + 1;
  }
  if (counts.isEmpty) return null;
  if (current != null && counts.containsKey(current)) return current;
  final best = counts.entries.reduce((a, b) {
    if (a.value != b.value) return a.value > b.value ? a : b;
    // Départage alphabétique : l'examen retenu par défaut ne doit pas changer
    // d'une consultation à l'autre.
    return a.key.compareTo(b.key) <= 0 ? a : b;
  });
  return best.key;
}

final meritFilterProvider =
    StateProvider.autoDispose<MeritFilter>((ref) => const MeritFilter());

/// Applique les critères puis attribue les rangs — **ex æquo compris**.
///
/// Deux moyennes identiques donnent le MÊME rang (1, 2, 2, 4). Départager deux
/// élèves à 17,70 par l'ordre alphabétique ou l'ordre de la base serait
/// arbitraire : sur une liste de bourses, l'arbitraire est exactement ce qui
/// se conteste. On assume l'ex æquo et on l'affiche.
List<RankedMerit> rankMerit(List<MeritEntry> all, MeritFilter f) {
  final kept = all.where((e) {
    if (f.exam != null && e.examShortName != f.exam) return false;
    if (f.filiere != null && e.filiere != f.filiere) return false;
    if (f.department != null && e.department != f.department) return false;
    if (f.gender != null && e.gender != f.gender) return false;
    return true;
  }).toList();

  final out = <RankedMerit>[];
  var rank = 0;
  double? previous;
  for (var i = 0; i < kept.length; i++) {
    if (previous == null || kept[i].average != previous) {
      rank = i + 1;
      previous = kept[i].average;
    }
    out.add(RankedMerit(rank, kept[i]));
  }

  // Le palmarès s'arrête à topN, mais ne coupe JAMAIS un groupe d'ex æquo en
  // deux : si le 10ᵉ et le 11ᵉ ont la même moyenne, les deux entrent. Exclure
  // l'un des deux serait indéfendable devant une commission.
  final limited = <RankedMerit>[];
  for (final r in out) {
    if (limited.length >= f.topN && r.rank > f.topN) break;
    limited.add(r);
  }

  // Marque les rangs partagés une fois la liste arrêtée.
  final counts = <int, int>{};
  for (final r in limited) {
    counts[r.rank] = (counts[r.rank] ?? 0) + 1;
  }
  return [
    for (final r in limited)
      RankedMerit(r.rank, r.entry, exAequo: (counts[r.rank] ?? 0) > 1),
  ];
}

/// Part de filles dans une sélection. `null` si la sélection est vide — une
/// parité de 0 % sur une liste vide serait un contresens.
double? femaleShare(List<RankedMerit> rows) {
  if (rows.isEmpty) return null;
  final f = rows.where((r) => r.entry.isFemale).length;
  return f / rows.length * 100;
}

final adminMeritProvider =
    FutureProvider.autoDispose<MeritData>((ref) async {
  ref.keepAlive();
  final client = ref.watch(supabaseClientProvider);
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final groupId = profile?.groupId;
  if (groupId == null) return MeritData.empty;

  // La RLS borne déjà au groupe (`exam_candidates_select`) ; le filtre explicite
  // documente l'intention et protège d'un élargissement futur de la policy.
  final rows = await client
      .from('exam_candidates')
      .select('student_id, school_id, average, candidate_number, result, '
          'students!inner(first_name, last_name, gender, has_scholarship), '
          'schools!inner(name, department), '
          'classes(filiere_label), '
          'exam_sessions!inner(year_label, '
          'national_exams!inner(short_name))')
      .eq('group_id', groupId)
      .eq('result', 'admis');

  final entries = <MeritEntry>[];
  final exams = <String>{};
  final filieres = <String>{};
  final departments = <String>{};
  var unranked = 0;
  String? year;

  for (final r in (rows as List)) {
    final student = r['students'] as Map<String, dynamic>?;
    final school = r['schools'] as Map<String, dynamic>?;
    final session = r['exam_sessions'] as Map<String, dynamic>?;
    final exam = session?['national_exams'] as Map<String, dynamic>?;
    year ??= session?['year_label'] as String?;

    final avg = (r['average'] as num?)?.toDouble();
    if (avg == null) {
      unranked++;
      continue;
    }

    final first = (student?['first_name'] as String?)?.trim() ?? '';
    final last = (student?['last_name'] as String?)?.trim() ?? '';
    final name = '$first $last'.trim();

    final examName = exam?['short_name'] as String?;
    final filiere = r['classes']?['filiere_label'] as String?;
    final dept = school?['department'] as String?;
    if (examName != null) exams.add(examName);
    if (filiere != null && filiere.isNotEmpty) filieres.add(filiere);
    if (dept != null && dept.isNotEmpty) departments.add(dept);

    entries.add(MeritEntry(
      studentId: r['student_id'] as String? ?? '',
      fullName: name.isEmpty ? 'Élève sans nom' : name,
      schoolId: r['school_id'] as String? ?? '',
      schoolName: (school?['name'] as String?) ?? '—',
      average: avg,
      gender: student?['gender'] as String?,
      department: dept,
      filiere: filiere,
      examShortName: examName,
      candidateNumber: r['candidate_number'] as String?,
      hasScholarship: student?['has_scholarship'] == true,
    ));
  }

  entries.sort((a, b) => b.average.compareTo(a.average));

  return MeritData(
    entries: entries,
    unranked: unranked,
    exams: exams.toList()..sort(),
    filieres: filieres.toList()..sort(),
    departments: departments.toList()..sort(),
    yearLabel: year,
    admittedTotal: entries.length + unranked,
  );
});

/// Nombre de bulletins PUBLIÉS sur le réseau.
///
/// Sert uniquement à dire l'état du contrôle continu — jamais à en tirer un
/// classement entre établissements. Un bulletin en brouillon ou en attente de
/// validation ne compte pas : tant que le conseil de classe n'a pas tranché,
/// la moyenne peut encore changer.
final publishedBulletinsCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  ref.keepAlive();
  final client = ref.watch(supabaseClientProvider);
  final groupId = ref.watch(authNotifierProvider).valueOrNull?.groupId;
  if (groupId == null) return 0;

  final res = await client
      .from('bulletins')
      .count(CountOption.exact)
      .eq('group_id', groupId)
      .eq('status', 'published');
  return res;
});
