import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/passage_bareme.dart';
import '../../../core/utils/rang.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../../core/utils/identite_offline.dart';
import '../../../services/powersync/powersync_service.dart';
import '../../auth/providers/auth_provider.dart';
import 'bulletins_provider.dart';

export '../../../core/utils/passage_bareme.dart'
    show BaremePassage, PropositionPassage, propositionPour, verdictPropose;

// ════════════════════════════════════════════════════════════════════════════
//  PASSAGE EN CLASSE SUPÉRIEURE — le verdict de fin d'année.
//
//  ── CE QUE CETTE PAGE DÉCIDE, ET CE QU'ELLE NE DÉCIDE PAS ──────────────────
//  Elle ne traite QUE les classes de PASSAGE. Pour les classes d'examen (CM2,
//  3e, Terminale), c'est la DEC qui proclame : la plateforme prépare la liste
//  des candidats et n'a aucune légitimité à décider à sa place.
//
//  Conséquence heureuse : une classe de passage n'est jamais en haut de son
//  cycle (6e→5e→4e, CP1→…→CM1, 2nde→1ère). La classe d'accueil se trouve donc
//  TOUJOURS dans le même cycle, un niveau plus haut. Aucune logique de
//  franchissement de cycle à écrire — et donc aucune à faire fausser.
//
//  ── LA MOYENNE ANNUELLE EST LA MOYENNE DES TROIS TRIMESTRES ────────────────
//  L'année scolaire se délibère trois fois : le conseil de classe se réunit à
//  chaque trimestre et porte sur le bulletin une DISTINCTION (Félicitations,
//  Encouragements, Tableau d'honneur, Avertissement, Blâme — `bulletins.
//  decision`). Ces trois conseils n'orientent pas : ils apprécient. Le verdict
//  annuel, lui, se rend une seule fois, ici, et vaut pour l'année entière
//  (`class_enrollments.promotion_decision`).
//
//  La moyenne qui le fonde est donc `(MT1 + MT2 + MT3) / 3` : les trois
//  moyennes trimestrielles, à poids égal. Ce sont exactement les nombres déjà
//  imprimés sur les trois bulletins remis aux familles — une famille doit
//  pouvoir refaire le calcul avec les papiers qu'elle a chez elle.
//
//  ⚠️ Ce n'est PAS la même chose que la moyenne de toutes les notes de l'année
//  prises ensemble, ce que faisait la première version (`trimesterId: null`).
//  Mettre toutes les notes dans le même sac donne au trimestre le plus chargé
//  en évaluations un poids supérieur aux autres : un 3ᵉ trimestre court —
//  celui de la remontée, souvent — pèse alors moins que le premier. Sur les
//  données de démo l'écart est nul (chaque trimestre y porte le même nombre
//  d'évaluations), donc rien ne l'aurait révélé à l'écran ; dans une école
//  réelle il décide de qui redouble.
//
//  Chaque moyenne trimestrielle est calculée par `bulletinComputationProvider`,
//  le moteur des bulletins. Deux calculs de moyenne divergeraient un jour, et
//  ce jour-là on ne saurait plus lequel a décidé du sort d'un enfant.
//
//  ── LA DÉCISION SE FIGE, LA RÉINSCRIPTION VIENT APRÈS ──────────────────────
//  Le conseil délibère en juin, le secrétariat réinscrit en septembre. La
//  moyenne retenue ET la classe d'accueil sont donc écrites au moment du vote
//  (`class_enrollments.promotion_*`, migration 0074). Une note corrigée en
//  août ne réécrit pas une délibération de juin.
// ════════════════════════════════════════════════════════════════════════════

/// Verdict annuel. Le `code` est stocké dans `class_enrollments.promotion_decision`.
class PassageVerdict {
  const PassageVerdict(this.code, this.label, this.color, this.icon);
  final String code, label;
  final Color color;
  final IconData icon;
}

List<PassageVerdict> get passageVerdicts => [
      PassageVerdict('passe', 'Passe en classe supérieure', kGreen,
          Icons.arrow_upward_rounded),
      PassageVerdict('redouble', 'Redouble', kRed, Icons.replay_rounded),
      PassageVerdict('reoriente', 'Réorienté', kAccent, Icons.alt_route_rounded),
    ];

PassageVerdict? verdictFor(String? code) {
  if (code == null || code.isEmpty) return null;
  for (final v in passageVerdicts) {
    if (v.code == code) return v;
  }
  return null;
}

/// Décision PROPOSÉE d'après la moyenne annuelle — toujours modifiable.
///
/// ⚠️ La barre N'EST PLUS écrite ici. Elle était en dur (`>= 10`), et même pas
/// via `kPassingMark` qui existait à côté : deux exemplaires du même nombre.
/// Elle se règle désormais par groupe, avec dérogation par niveau (migration
/// 0107), et la décision vit dans `core/utils/passage_bareme.dart` — un seul
/// endroit, miroir de `verdict_passage()` en SQL.
///
/// On ne propose jamais « réorienté » : c'est un choix d'orientation, pas un
/// seuil de moyenne.
String? suggestedVerdict(double? annualAverage, BaremePassage bareme) =>
    verdictPropose(annualAverage, bareme);

/// Le barème d'une classe : celui du groupe, éventuellement dérogé par le
/// niveau de la classe.
///
/// ⚠️ En l'absence de toute ligne — poste fraîchement purgé, groupe non
/// synchronisé — on retombe sur le barème officiel (10/20, sans zone). Ne
/// jamais rendre « aucun barème » : un écran de passage sans barre ne pourrait
/// plus rien proposer, et l'école conclurait que la plateforme ne sait pas
/// délibérer alors qu'il ne lui manque qu'un réglage facultatif.
Future<BaremePassage> _baremeFor(String? groupId, String? levelId) async {
  var bareme = BaremePassage.officiel;

  if (groupId != null) {
    final g = await db.getOptional(
      'SELECT promotion_pass_mark, promotion_deliberation_floor '
      'FROM school_groups WHERE id = ?',
      [groupId],
    );
    final barre = (g?['promotion_pass_mark'] as num?)?.toDouble();
    if (barre != null && barre > 0 && barre <= 20) {
      bareme = BaremePassage(
        barre: barre,
        plancher: (g?['promotion_deliberation_floor'] as num?)?.toDouble(),
      );
    }
  }

  if (levelId != null) {
    final l = await db.getOptional(
      'SELECT pass_mark, deliberation_floor FROM school_levels WHERE id = ?',
      [levelId],
    );
    bareme = bareme.avecDerogation(
      barre: (l?['pass_mark'] as num?)?.toDouble(),
      plancher: (l?['deliberation_floor'] as num?)?.toDouble(),
    );
  }

  return bareme;
}

/// La moyenne annuelle : moyenne des moyennes trimestrielles RENSEIGNÉES.
///
/// Les trois trimestres pèsent le même poids — c'est la règle, et c'est aussi
/// la seule façon qu'une famille refasse le calcul avec ses trois bulletins.
/// Un trimestre sans note est ignoré, jamais compté zéro : un élève arrivé en
/// janvier n'a pas « eu 0 » au premier trimestre, il n'y était pas.
double? annualAverageOf(List<double?> trimesterAverages) {
  final vals = trimesterAverages.whereType<double>().toList();
  if (vals.isEmpty) return null;
  return vals.reduce((a, b) => a + b) / vals.length;
}

/// Un trimestre de l'année délibérée.
class PassageTrimester {
  const PassageTrimester({
    required this.id,
    required this.label,
    required this.number,
    required this.hasGrades,
  });
  final String id, label;
  final int number;

  /// Le trimestre porte au moins une évaluation. Un trimestre vide ne compte
  /// pas dans la moyenne annuelle — le compter reviendrait à y mettre zéro.
  final bool hasGrades;

  String get shortLabel => 'T$number';
}

/// Un élève devant le conseil de fin d'année.
class PassageEntry {
  const PassageEntry({
    required this.enrollmentId,
    required this.studentId,
    required this.studentName,
    required this.matricule,
    required this.trimesterAverages,
    required this.annualAverage,
    required this.rank,
    required this.totalStudents,
    required this.decision,
    required this.decidedAverage,
    required this.targetClassId,
    required this.reenrolled,
    required this.alreadyRepeating,
  });
  final String enrollmentId, studentId, studentName;
  final String? matricule;

  /// Les moyennes trimestrielles, dans l'ordre des trimestres de l'année.
  /// `null` là où l'élève n'a aucune note — arrivé en cours d'année, malade
  /// tout un trimestre. Le trou se voit à l'écran et sur le procès-verbal ;
  /// il n'est jamais remplacé par un zéro.
  final List<double?> trimesterAverages;

  /// Moyenne des moyennes trimestrielles renseignées. `null` si aucune.
  final double? annualAverage;
  final int rank, totalStudents;
  final String? decision; // verdict persisté
  final double? decidedAverage; // moyenne figée au vote
  final String? targetClassId;

  /// L'inscription de l'année suivante existe déjà pour cet élève.
  final bool reenrolled;

  /// L'élève REFAIT déjà ce niveau cette année.
  ///
  /// Le redoublement n'est autorisé qu'UNE FOIS par niveau. Proposer à cet
  /// élève de redoubler une seconde fois, c'est proposer une décision que
  /// l'établissement ne peut pas prendre — le conseil doit le savoir avant de
  /// voter, pas le découvrir en juillet.
  final bool alreadyRepeating;

  /// Vrai quand le verdict retenu se heurte à la limite d'un redoublement par
  /// niveau. L'écran le signale ; il ne bloque pas : c'est une délibération,
  /// et c'est au conseil, pas au logiciel, de trancher une dérogation.
  bool get repeatingTwice => alreadyRepeating && decision == 'redouble';

  bool get decided => decision != null && decision!.isNotEmpty;
}

/// La classe d'accueil résolue pour une classe donnée.
class TargetClass {
  const TargetClass({required this.id, required this.name});
  final String id, name;
}

class PassageSession {
  const PassageSession({
    required this.entries,
    required this.trimesters,
    required this.classAverage,
    required this.evaluationCount,
    required this.nextYearId,
    required this.nextYearLabel,
    required this.upperClass,
    required this.repeatClass,
    this.bareme = BaremePassage.officiel,
  });
  final List<PassageEntry> entries;

  /// La barre de passage applicable à CETTE classe : celle du groupe, dérogée
  /// par le niveau s'il en porte une. Affichée à l'écran et imprimée sur le
  /// procès-verbal — une délibération dont on ignore la règle ne se relit pas.
  final BaremePassage bareme;

  /// Ce que le barème dit de cet élève, sans rien écrire.
  PropositionPassage propositionPourEleve(PassageEntry e) =>
      propositionPour(e.annualAverage, bareme);

  /// Élèves que le barème laisse au conseil : moyenne comprise entre le
  /// plancher et la barre. Zéro quand aucune zone n'est réglée.
  List<PassageEntry> get enDeliberation => [
        for (final e in entries)
          if (!e.decided &&
              propositionPourEleve(e) == PropositionPassage.deliberation)
            e
      ];

  /// Élèves sans la moindre moyenne : rien n'a été saisi pour eux. Le conseil
  /// doit les voir — un élève sans note n'est pas un élève sans sort.
  List<PassageEntry> get sansMoyenne => [
        for (final e in entries)
          if (!e.decided &&
              propositionPourEleve(e) == PropositionPassage.sansMoyenne)
            e
      ];

  /// Les trimestres de l'année, dans l'ordre. Vide si l'établissement n'a pas
  /// découpé son année — la moyenne annuelle retombe alors sur l'ensemble des
  /// notes.
  final List<PassageTrimester> trimesters;
  final double? classAverage;
  final int evaluationCount;

  /// Année d'accueil. `null` = aucune année suivante déclarée.
  final String? nextYearId, nextYearLabel;

  /// Classe du niveau supérieur dans l'année d'accueil ; `null` si la structure
  /// de l'année suivante n'a pas encore été reconduite.
  final TargetClass? upperClass;

  /// Même niveau dans l'année d'accueil — la destination d'un redoublant.
  final TargetClass? repeatClass;

  int get decidedCount => entries.where((e) => e.decided).length;
  int get reenrolledCount => entries.where((e) => e.reenrolled).length;

  /// Trimestres déclarés mais sans la moindre note. Le conseil doit le savoir :
  /// délibérer une année dont il manque un trimestre, c'est délibérer sur une
  /// moyenne qui n'est pas celle des bulletins.
  List<PassageTrimester> get emptyTrimesters =>
      [for (final t in trimesters) if (!t.hasGrades) t];

  /// Peut-on réinscrire ? Il faut une année suivante ET les classes qui vont
  /// avec. Sans elles, la décision reste enregistrée : seule l'inscription
  /// attend.
  bool get canReenroll => nextYearId != null && upperClass != null;
}

/// Le barème du GROUPE, sans dérogation de niveau — celui qu'on annonce en tête
/// de campagne. Une classe peut porter un barème dérogatoire ; c'est la session
/// de cette classe qui fait alors foi.
final baremePassageEcoleProvider =
    FutureProvider.autoDispose<BaremePassage>((ref) async {
  final groupId = ref.watch(authNotifierProvider).valueOrNull?.groupId;
  return _baremeFor(groupId, null);
});

/// Une classe de passage dans la liste de campagne.
class PassageClass {
  const PassageClass({
    required this.classId,
    required this.className,
    required this.cycleName,
    required this.filiereLabel,
    required this.students,
    required this.decided,
    required this.reenrolled,
  });
  final String classId, className;

  /// Libellé du cycle (Primaire, Collège, Lycée…). Sert d'intertitre : sans
  /// lui la liste mélange CP1, 6ème et 2nde, car `level_order` REPART À 1 à
  /// chaque cycle — trier dessus seul entrelace les trois.
  final String cycleName;
  final String? filiereLabel;
  final int students, decided, reenrolled;
}

/// Les classes de PASSAGE de l'école pour l'année active, avec l'avancement de
/// la campagne. Les classes d'examen sont exclues à la source : leur sort se
/// décide à la DEC, pas ici.
final passageClassesProvider = FutureProvider.autoDispose
    .family<List<PassageClass>, String>((ref, yearId) async {
  ref.keepAlive();
  final next = await _nextYear(yearId);
  final rows = await db.getAll(
    '''
    SELECT c.id, c.name, c.filiere_label,
           COALESCE(ec.name, 'Autres')   AS cycle_name,
           COALESCE(ec.order_index, 9)   AS cycle_order,
           COUNT(e.id)                                            AS students,
           SUM(CASE WHEN e.promotion_decision IS NOT NULL THEN 1 ELSE 0 END) AS decided
      FROM classes c
      LEFT JOIN education_cycles ec ON ec.code = c.cycle_code
      LEFT JOIN class_enrollments e
             ON e.class_id = c.id AND e.status = 'active'
     WHERE c.academic_year_id = ? AND COALESCE(c.is_active, 1) <> 0
       AND COALESCE(c.exam_status, 'passage') = 'passage'
     GROUP BY c.id, c.name, c.filiere_label, ec.name, ec.order_index
     ORDER BY cycle_order, c.level_order, c.name
    ''',
    [yearId],
  );

  // Réinscrits : élèves de la classe qui ont déjà une inscription l'an prochain.
  final reenrolled = <String, int>{};
  if (next != null) {
    final done = await db.getAll(
      '''
      SELECT cur.class_id AS cid, COUNT(*) AS n
        FROM class_enrollments cur
        JOIN class_enrollments nxt
          ON nxt.student_id = cur.student_id AND nxt.academic_year_id = ?
       WHERE cur.academic_year_id = ?
       GROUP BY cur.class_id
      ''',
      [next.$1, yearId],
    );
    for (final r in done) {
      reenrolled[r['cid'] as String] = (r['n'] as int?) ?? 0;
    }
  }

  return [
    for (final r in rows)
      PassageClass(
        classId: r['id'] as String,
        className: r['name'] as String? ?? '—',
        cycleName: r['cycle_name'] as String? ?? 'Autres',
        filiereLabel: r['filiere_label'] as String?,
        students: (r['students'] as int?) ?? 0,
        decided: (r['decided'] as int?) ?? 0,
        reenrolled: reenrolled[r['id'] as String] ?? 0,
      ),
  ];
});

/// L'année d'accueil, telle que l'en-tête de campagne doit la présenter.
class NextYear {
  const NextYear({
    required this.id,
    required this.label,
    required this.trimesterCount,
  });
  final String id, label;

  /// Trimestres déclarés dans l'année d'accueil.
  ///
  /// Zéro n'empêche ni de délibérer ni de réinscrire, mais aucune note ne
  /// pourra y être saisie : une évaluation porte `trimester_id`. Et l'école ne
  /// peut pas y remédier elle-même — le calendrier est écrit par le groupe
  /// (RLS `trimesters_write_ministry`). Elle doit donc le SAVOIR à temps, en
  /// juin, pas le découvrir à la rentrée.
  final int trimesterCount;

  bool get hasTrimesters => trimesterCount > 0;
}

/// Année suivante de l'année active — pour l'en-tête de campagne.
final nextYearProvider =
    FutureProvider.autoDispose.family<NextYear?, String>((ref, yearId) async {
  final next = await _nextYear(yearId);
  if (next == null) return null;
  final rows = await db.getAll(
    'SELECT COUNT(*) AS n FROM trimesters WHERE academic_year_id = ?',
    [next.$1],
  );
  return NextYear(
    id: next.$1,
    label: next.$2,
    trimesterCount: (rows.first['n'] as int?) ?? 0,
  );
});

/// Délibération de fin d'année d'une classe.
final passageSessionProvider =
    FutureProvider.autoDispose.family<PassageSession, String>((ref, classId) async {
  ref.keepAlive();

  final cls = await db.getAll(
    'SELECT school_id, group_id, academic_year_id, cycle_code, level_order, '
    '       level_id, filiere_label '
    'FROM classes WHERE id = ?',
    [classId],
  );
  if (cls.isEmpty) {
    return const PassageSession(
      entries: [],
      trimesters: [],
      classAverage: null,
      evaluationCount: 0,
      nextYearId: null,
      nextYearLabel: null,
      upperClass: null,
      repeatClass: null,
    );
  }
  final c = cls.first;
  final schoolId = c['school_id'] as String?;
  final yearId = c['academic_year_id'] as String?;
  final cycle = c['cycle_code'] as String?;
  final levelOrder = (c['level_order'] as int?) ?? 0;
  final filiere = c['filiere_label'] as String?;
  final bareme =
      await _baremeFor(c['group_id'] as String?, c['level_id'] as String?);

  // ── Les trois moyennes trimestrielles, puis leur moyenne ──────────────────
  // Un calcul par trimestre, avec le moteur des bulletins : les nombres de
  // cette page sont ceux des bulletins déjà remis aux familles.
  final trimRows = yearId == null
      ? const <Map<String, Object?>>[]
      : await db.getAll(
          'SELECT id, label, trimester_number FROM trimesters '
          'WHERE academic_year_id = ? ORDER BY trimester_number',
          [yearId],
        );

  final comps = <BulletinComputation>[];
  for (final t in trimRows) {
    comps.add(await ref.watch(bulletinComputationProvider(
            (classId: classId, trimesterId: t['id'] as String))
        .future));
  }
  // Année non découpée en trimestres : on retombe sur l'ensemble des notes.
  // C'est un pis-aller assumé, pas la règle — mais mieux vaut une délibération
  // fondée sur toutes les notes que pas de délibération du tout.
  final pooled = comps.isEmpty
      ? await ref.watch(
          bulletinComputationProvider((classId: classId, trimesterId: null))
              .future)
      : null;

  final trimesters = [
    for (var i = 0; i < trimRows.length; i++)
      PassageTrimester(
        id: trimRows[i]['id'] as String,
        label: trimRows[i]['label'] as String? ??
            'Trimestre ${trimRows[i]['trimester_number']}',
        number: (trimRows[i]['trimester_number'] as num?)?.toInt() ?? i + 1,
        hasGrades: comps[i].evaluationCount > 0,
      ),
  ];

  // L'effectif est le même à chaque trimestre (il vient des inscriptions, pas
  // des notes) : n'importe quel calcul porte la liste complète.
  final roster = pooled ?? comps.first;
  final byTrimester = <String, List<double?>>{
    for (final s in roster.students)
      s.enrollmentId: List<double?>.filled(comps.length, null),
  };
  for (var i = 0; i < comps.length; i++) {
    for (final s in comps[i].students) {
      final row = byTrimester[s.enrollmentId];
      if (row != null) row[i] = s.overallAverage;
    }
  }

  final next = await _nextYear(yearId);
  final upper = next == null
      ? null
      : await _classAt(schoolId, next.$1, cycle, levelOrder + 1, filiere);
  final repeat = next == null
      ? null
      : await _classAt(schoolId, next.$1, cycle, levelOrder, filiere);

  // Décisions déjà prises + inscriptions déjà créées pour l'année suivante.
  final rows = await db.getAll(
    'SELECT id, student_id, promotion_decision, promotion_average, '
    '       promotion_target_class_id, is_repeating '
    '  FROM class_enrollments WHERE class_id = ?',
    [classId],
  );
  final decided = {for (final r in rows) r['id'] as String: r};

  final reenrolled = <String>{};
  if (next != null) {
    final done = await db.getAll(
      'SELECT student_id FROM class_enrollments WHERE academic_year_id = ? '
      'AND student_id IN (SELECT student_id FROM class_enrollments WHERE class_id = ?)',
      [next.$1, classId],
    );
    for (final r in done) {
      reenrolled.add(r['student_id'] as String);
    }
  }

  // La moyenne annuelle, puis le rang QU'ELLE donne. Reprendre le rang d'un
  // trimestre reviendrait à classer l'année sur un tiers de l'année.
  final annual = <String, double?>{
    for (final s in roster.students)
      s.enrollmentId: comps.isEmpty
          ? s.overallAverage
          : annualAverageOf(byTrimester[s.enrollmentId] ?? const []),
  };
  final values = annual.values.whereType<double>().toList();
  // ⚠️ LE RANG SE COMPTE, IL NE SE LIT PAS DANS UN TRI. Il se lisait ici par
  // position (`i + 1`) sur une liste triée — or `List.sort` n'est pas stable en
  // Dart : deux moyennes annuelles égales étaient départagées au hasard, et
  // deux postes pouvaient classer les mêmes élèves différemment. Sur la
  // décision de PASSAGE, c'est-à-dire sur le redoublement d'un enfant.
  // Même défaut que sur le bulletin (corrigé la veille) — celui-ci avait été
  // manqué, le garde ne regardant qu'un seul fichier.
  final ranks = {
    for (final s in roster.students)
      if (annual[s.enrollmentId] != null)
        s.enrollmentId: rangDeCompetition(annual[s.enrollmentId]!, values),
  };
  final entries = [
    for (final s in roster.students)
      PassageEntry(
        enrollmentId: s.enrollmentId,
        studentId: s.studentId,
        studentName: s.studentName,
        matricule: s.matricule,
        trimesterAverages: byTrimester[s.enrollmentId] ?? const [],
        annualAverage: annual[s.enrollmentId],
        rank: ranks[s.enrollmentId] ?? 0,
        totalStudents: roster.students.length,
        decision: decided[s.enrollmentId]?['promotion_decision'] as String?,
        decidedAverage:
            (decided[s.enrollmentId]?['promotion_average'] as num?)?.toDouble(),
        targetClassId:
            decided[s.enrollmentId]?['promotion_target_class_id'] as String?,
        reenrolled: reenrolled.contains(s.studentId),
        // SQLite rend le booléen en entier : 1 = l'élève refait ce niveau.
        alreadyRepeating:
            (decided[s.enrollmentId]?['is_repeating'] as int? ?? 0) == 1,
      ),
  ]..sort((a, b) {
      if (a.rank == 0 || b.rank == 0) return a.rank == b.rank ? 0 : (a.rank == 0 ? 1 : -1);
      return a.rank.compareTo(b.rank);
    });

  return PassageSession(
    entries: entries,
    trimesters: trimesters,
    classAverage: values.isEmpty
        ? null
        : values.reduce((a, b) => a + b) / values.length,
    evaluationCount: comps.isEmpty
        ? roster.evaluationCount
        : comps.fold(0, (a, c) => a + c.evaluationCount),
    nextYearId: next?.$1,
    nextYearLabel: next?.$2,
    upperClass: upper,
    repeatClass: repeat,
    bareme: bareme,
  );
});

/// Année scolaire qui suit celle-ci : la première dont la rentrée est
/// postérieure. On se fie aux DATES, pas au libellé — « 2026-2027 » se saisit
/// à la main et se tape de travers.
Future<(String, String)?> _nextYear(String? yearId) async {
  if (yearId == null) return null;
  final rows = await db.getAll(
    'SELECT y2.id, y2.label FROM academic_years y1 '
    'JOIN academic_years y2 ON y2.start_date > y1.start_date '
    'WHERE y1.id = ? ORDER BY y2.start_date LIMIT 1',
    [yearId],
  );
  if (rows.isEmpty) return null;
  return (rows.first['id'] as String, rows.first['label'] as String? ?? '');
}

/// La classe d'un niveau donné dans une année donnée. Quand plusieurs classes
/// partagent le niveau (F2, G2…), on privilégie celle de la même filière :
/// un élève de G2 ne bascule pas en électronique par défaut de tri.
Future<TargetClass?> _classAt(
  String? schoolId,
  String yearId,
  String? cycle,
  int levelOrder,
  String? filiere,
) async {
  if (schoolId == null) return null;
  final rows = await db.getAll(
    // ⚠️ `is_active = 1` — et non `<> 0` — ne retrouvait PAS les classes que
    // l'application venait elle-même de créer en reconduisant la structure :
    // la valeur écrite localement ne s'égale pas à l'entier 1 dans la vue
    // PowerSync. L'écran annonçait alors « les classes de l'an prochain
    // n'existent pas encore » juste après les avoir créées, et la
    // réinscription restait grisée pour toujours.
    'SELECT id, name, filiere_label FROM classes '
    'WHERE school_id = ? AND academic_year_id = ? AND cycle_code = ? '
    '  AND level_order = ? AND COALESCE(is_active, 1) <> 0 ORDER BY name',
    [schoolId, yearId, cycle, levelOrder],
  );
  if (rows.isEmpty) return null;
  final same = rows.where((r) => r['filiere_label'] == filiere);
  final r = same.isNotEmpty ? same.first : rows.first;
  return TargetClass(id: r['id'] as String, name: r['name'] as String? ?? '—');
}

// ─── Écritures (offline-first) ───────────────────────────────────────────────

/// Enregistre le verdict d'un élève. La moyenne et la classe d'accueil sont
/// figées ici : c'est ce qui rend la délibération relisible des mois plus tard.
Future<void> savePassageDecision({
  required String enrollmentId,
  required String? decision,
  required double? average,
  required String? targetClassId,
  required String? actorId,
}) async {
  final now = DateTime.now().toIso8601String();
  final clear = decision == null || decision.isEmpty;
  await db.execute(
    'UPDATE class_enrollments SET promotion_decision = ?, promotion_average = ?, '
    '  promotion_target_class_id = ?, promotion_decided_at = ?, '
    '  promotion_decided_by = ?, updated_at = ? WHERE id = ?',
    [
      clear ? null : decision,
      clear ? null : average,
      clear ? null : targetClassId,
      clear ? null : now,
      clear ? null : actorId,
      now,
      enrollmentId,
    ],
  );
}

/// Ce qu'une campagne de propositions a fait, et ce qu'elle n'a pas pu faire.
///
/// ⚠️ Le compte rendu n'est pas décoratif. Une campagne qui annonce « 412
/// propositions inscrites » sur une école de 460 élèves laisse 48 enfants sans
/// verdict, et personne ne saura lesquels avant le 30 juin. Nommer ce qui reste
/// est la moitié du travail — c'est la règle « pas de plafond silencieux ».
class BilanPropositions {
  const BilanPropositions({
    this.inscrites = 0,
    this.dejaDecidees = 0,
    this.enDeliberation = 0,
    this.sansMoyenne = 0,
    this.classes = 0,
  });

  /// Verdicts effectivement écrits.
  final int inscrites;

  /// Élèves déjà délibérés à la main : jamais écrasés.
  final int dejaDecidees;

  /// Élèves laissés au conseil par le barème (zone de délibération).
  final int enDeliberation;

  /// Élèves sans aucune note : rien à proposer.
  final int sansMoyenne;

  /// Classes parcourues.
  final int classes;

  int get restantes => enDeliberation + sansMoyenne;

  BilanPropositions plus(BilanPropositions o) => BilanPropositions(
        inscrites: inscrites + o.inscrites,
        dejaDecidees: dejaDecidees + o.dejaDecidees,
        enDeliberation: enDeliberation + o.enDeliberation,
        sansMoyenne: sansMoyenne + o.sansMoyenne,
        classes: classes + o.classes,
      );

  /// Le compte rendu tel qu'il se lit, en une phrase.
  String get resume {
    if (inscrites == 0 && restantes == 0) {
      return dejaDecidees == 0
          ? 'Aucun élève à délibérer.'
          : 'Tous les élèves sont déjà délibérés.';
    }
    final b = StringBuffer();
    b.write(inscrites == 0
        ? 'Aucune nouvelle proposition'
        : '$inscrites proposition(s) inscrite(s)');
    if (classes > 1) b.write(' sur $classes classes');
    final restes = <String>[
      if (enDeliberation > 0) '$enDeliberation en délibération',
      if (sansMoyenne > 0) '$sansMoyenne sans moyenne',
      if (dejaDecidees > 0) '$dejaDecidees déjà décidé(s)',
    ];
    if (restes.isNotEmpty) b.write(' · ${restes.join(', ')}');
    b.write('.');
    return b.toString();
  }
}

/// Pré-remplit les verdicts proposés pour les élèves non encore délibérés.
///
/// N'écrase JAMAIS une décision déjà prise : le conseil garde le dernier mot,
/// y compris contre la proposition du barème.
///
/// Deux catégories restent volontairement vides : les élèves de la ZONE DE
/// DÉLIBÉRATION et ceux sans aucune moyenne. Dans les deux cas, l'absence de
/// verdict est le message — un défaut prudent ferait redoubler des élèves que
/// le conseil n'a pas examinés.
Future<BilanPropositions> autofillVerdicts({
  required PassageSession session,
  required String? actorId,
}) async {
  var inscrites = 0, deja = 0, delib = 0, sansMoy = 0;

  for (final e in session.entries) {
    if (e.decided) {
      deja++;
      continue;
    }
    switch (session.propositionPourEleve(e)) {
      case PropositionPassage.deliberation:
        delib++;
      case PropositionPassage.sansMoyenne:
        sansMoy++;
      case PropositionPassage.passe:
      case PropositionPassage.redouble:
        final v = verdictPropose(e.annualAverage, session.bareme)!;
        await savePassageDecision(
          enrollmentId: e.enrollmentId,
          decision: v,
          average: e.annualAverage,
          targetClassId: v == 'passe'
              ? session.upperClass?.id
              : session.repeatClass?.id,
          actorId: actorId,
        );
        inscrites++;
    }
  }

  return BilanPropositions(
    inscrites: inscrites,
    dejaDecidees: deja,
    enDeliberation: delib,
    sansMoyenne: sansMoy,
    classes: 1,
  );
}

/// La campagne à l'échelle de l'ÉCOLE : un seul geste pour toutes les classes
/// de passage de l'année.
///
/// ── Pourquoi ce provider et pas une boucle dans l'écran ────────────────────
/// Une école de seize classes demandait seize ouvertures et seize clics, et
/// rien ne disait où l'on en était. Le conseil de fin d'année se tient une fois
/// et porte sur l'établissement entier : la commande doit avoir la même forme
/// que la décision.
///
/// Les classes d'EXAMEN sont exclues à la source, comme partout ailleurs ici :
/// la DEC proclame, l'école n'a pas à décider à sa place.
///
/// ⚠️ Séquentiel, et c'est voulu. Chaque classe recalcule trois bulletins
/// complets ; les lancer toutes de front sur un poste de bureau congolais —
/// souvent un cœur, souvent branché sur une base de 40 000 lignes — fige
/// l'interface plusieurs secondes. Une campagne qui met dix secondes en
/// affichant sa progression vaut mieux qu'une qui met huit secondes en
/// paraissant plantée.
Future<BilanPropositions> autofillEcole({
  // `WidgetRef` et non `Ref` : la campagne est déclenchée par un geste
  // d'écran, jamais par un provider qui se recalcule. C'est même une garantie
  // utile — un provider qui écrirait des décisions en se reconstruisant
  // délibérerait tout seul au moindre changement d'année.
  required WidgetRef ref,
  required String yearId,
  required String? actorId,
  void Function(int fait, int total, String classe)? onProgress,
}) async {
  final classes = await ref.read(passageClassesProvider(yearId).future);
  var bilan = const BilanPropositions();

  for (var i = 0; i < classes.length; i++) {
    final c = classes[i];
    onProgress?.call(i, classes.length, c.className);
    final session = await ref.read(passageSessionProvider(c.classId).future);
    bilan = bilan.plus(await autofillVerdicts(
      session: session,
      actorId: actorId,
    ));
    // La session vient d'être écrite : sans invalidation, la classe rouvrirait
    // sur les décisions d'avant.
    ref.invalidate(passageSessionProvider(c.classId));
  }
  ref.invalidate(passageClassesProvider(yearId));
  onProgress?.call(classes.length, classes.length, '');
  return bilan;
}

/// Réinscrit dans l'année suivante les élèves délibérés qui ne le sont pas
/// encore.
///
/// ── Pourquoi chaque champ compte ────────────────────────────────────────────
/// Une inscription à laquelle il manque `group_id`/`school_id` est refusée au
/// serveur et PowerSync abandonne le LOT ENTIER — toute la classe réinscrite
/// disparaîtrait sans message. Les identifiants sont donc exigés en paramètre,
/// jamais devinés ni remplacés par une chaîne vide.
///
/// `reoriente` n'est pas réinscrit automatiquement : la classe d'accueil est un
/// choix d'orientation qui se fait dossier par dossier, pas en lot.
Future<int> reenrollDecided({
  required PassageSession session,
  required String groupId,
  required String schoolId,
  required String? actorId,
}) async {
  final yearId = session.nextYearId;
  if (yearId == null) return 0;

  final todo = session.entries
      .where((e) => e.decided && !e.reenrolled && e.decision != 'reoriente')
      .toList();
  if (todo.isEmpty) return 0;

  final now = DateTime.now().toIso8601String();
  final today = now.substring(0, 10);
  var n = 0;

  await db.writeTransaction((tx) async {
    for (final e in todo) {
      final repeating = e.decision == 'redouble';
      final target = e.targetClassId ??
          (repeating ? session.repeatClass?.id : session.upperClass?.id);
      if (target == null) continue;

      // ⚠️ `UNIQUE (student_id, academic_year_id)` : un élève n'a qu'une
      // inscription par année. Relancer la réinscription — deux appuis, une
      // reprise après coupure, ou deux postes hors ligne — réinsérait la même
      // inscription : 23505, code FATAL, le connecteur jette le LOT ENTIER en
      // attente. On relit dans la transaction, et l'identifiant se DÉDUIT de la
      // clé pour que deux postes écrivent la même ligne au lieu d'en créer deux.
      final deja = await tx.getAll(
        'SELECT id FROM class_enrollments '
        'WHERE student_id = ? AND academic_year_id = ? LIMIT 1',
        [e.studentId, yearId],
      );
      if (deja.isNotEmpty) continue;

      final currentClass = await tx.getAll(
        'SELECT class_id FROM class_enrollments WHERE id = ?',
        [e.enrollmentId],
      );

      await tx.execute(
        'INSERT INTO class_enrollments (id, group_id, school_id, student_id, '
        '  class_id, academic_year_id, enrollment_date, status, is_repeating, '
        '  previous_class_id, inscription_type, created_by, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          idDeterministe('class_enrollment', [e.studentId, yearId]),
          groupId,
          schoolId,
          e.studentId,
          target,
          yearId,
          today,
          'active',
          repeating ? 1 : 0,
          currentClass.isEmpty ? null : currentClass.first['class_id'],
          'reinscription',
          actorId,
          now,
          now,
        ],
      );
      n++;
    }
  });
  return n;
}
