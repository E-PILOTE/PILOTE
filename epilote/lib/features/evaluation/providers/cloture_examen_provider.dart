import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/utils/identite_offline.dart';
import '../../../services/powersync/powersync_service.dart';
import 'passage_provider.dart' show TargetClass;

// ════════════════════════════════════════════════════════════════════════════
//  CLÔTURE DES CLASSES D'EXAMEN — ce que la proclamation déclenche.
//
//  ── LE TROU ────────────────────────────────────────────────────────────────
//  L'école savait inscrire des candidats, monter leurs dossiers, imprimer les
//  convocations, et ENREGISTRER le résultat proclamé par la DEC. Puis plus
//  rien. Le résultat restait une ligne dans `exam_candidates` : il ne touchait
//  pas la scolarité de l'enfant.
//
//  Concrètement, au 1ᵉʳ septembre :
//    • l'admis restait « inscrit en 3ème » pour l'éternité — le statut
//      `graduated` existe dans l'énumération depuis le premier jour et AUCUNE
//      ligne de code ne l'écrivait ;
//    • l'AJOURNÉ — le cas le plus fréquent de l'année, 62 sur 198 à la session
//      de démonstration — n'avait aucun chemin de retour. Le secrétariat devait
//      le ressaisir à la main comme un élève inconnu : identité, tuteurs,
//      pièces. Un enfant qui a passé quatre ans dans l'établissement.
//
//  L'écran de passage, lui, écarte ces classes à la source, et il a raison de
//  le faire : la DEC proclame, l'école n'a pas à décider à sa place. Mais
//  « ne pas décider » n'est pas « ne rien faire ». Il reste à TIRER LES
//  CONSÉQUENCES, et c'est ce que fait ce fichier.
//
//  ── ON NE DÉLIBÈRE PAS, ON REPORTE ─────────────────────────────────────────
//  Le verdict n'est pas calculé sur les moyennes de l'école : il est LU sur la
//  proclamation. `admis` ⇒ passe, `ajourne`/`absent` ⇒ redouble. La moyenne
//  figée est celle du diplôme quand la DEC la communique — souvent elle ne la
//  communique pas, et le champ reste vide plutôt que d'être meublé par une
//  moyenne interne qui n'a pas décidé du sort de l'élève.
//
//  `fraude` ne propose rien : l'exclusion se traite en conseil de discipline,
//  pas par un automatisme.
//
//  ── LES ÉLÈVES SANS CANDIDATURE NE SONT PAS OUBLIÉS ────────────────────────
//  Une classe d'examen contient aussi des élèves qui n'ont pas été présentés.
//  Ils n'ont pas de résultat DEC, donc pas de proposition — mais ils
//  apparaissent dans la liste et leur décision reste saisissable à la main.
//  Les faire disparaître de l'écran, c'est les faire disparaître de l'école.
//
//  ── LA SORTIE DIPLÔMÉE EST UN GESTE EXPLICITE ──────────────────────────────
//  Un admis de CM2 quitte l'école primaire ; un bachelier quitte le lycée.
//  Quand l'établissement n'accueille pas le niveau suivant, il n'y a pas de
//  réinscription : il y a une SORTIE. On l'écrit alors `graduated` sur
//  l'inscription de l'année — ce qui la retire des effectifs actifs, comme une
//  sortie en cours d'année. C'est vrai, et c'est irréversible d'un clic : on
//  ne le fait donc jamais tout seul, seulement sur demande et après
//  confirmation.
// ════════════════════════════════════════════════════════════════════════════

/// Verdict déduit d'un résultat proclamé. `null` = rien à proposer.
///
/// `absent` redouble : ne pas s'être présenté ne fait pas obtenir le diplôme.
/// `fraude` ne propose rien — c'est une affaire disciplinaire.
String? verdictFromExamResult(String? result) => switch (result) {
      'admis' => 'passe',
      'ajourne' => 'redouble',
      'absent' => 'redouble',
      _ => null,
    };

({String label, Color color, IconData icon}) examResultTone(String? r) =>
    switch (r) {
      'admis' => (
          label: 'Admis',
          color: kGreen,
          icon: Icons.workspace_premium_rounded
        ),
      'ajourne' => (label: 'Ajourné', color: kRed, icon: Icons.replay_rounded),
      'absent' => (
          label: 'Absent',
          color: kTextMuted,
          icon: Icons.person_off_rounded
        ),
      'fraude' => (label: 'Fraude', color: kAccent, icon: Icons.gavel_rounded),
      'en_attente' => (
          label: 'En attente',
          color: kTextMuted,
          icon: Icons.hourglass_empty_rounded
        ),
      _ => (
          label: 'Non présenté',
          color: kTextMuted,
          icon: Icons.remove_circle_outline_rounded
        ),
    };

/// Un élève d'une classe d'examen, après la proclamation.
class ExamClosureEntry {
  const ExamClosureEntry({
    required this.enrollmentId,
    required this.studentId,
    required this.studentName,
    required this.matricule,
    required this.candidateNumber,
    required this.result,
    required this.examAverage,
    required this.mention,
    required this.decision,
    required this.targetClassId,
    required this.reenrolled,
    required this.enrollmentStatus,
  });

  final String enrollmentId, studentId, studentName;
  final String? matricule;

  /// Numéro attribué par la DEC. Absent = l'élève n'a pas été présenté.
  final String? candidateNumber;

  /// Résultat proclamé : admis | ajourne | absent | fraude | en_attente.
  /// `null` quand l'élève n'a aucune candidature pour cette classe.
  final String? result;

  /// Moyenne du diplôme, quand la DEC la communique. Souvent absente : la
  /// proclamation congolaise donne des noms d'admis, pas des notes.
  final double? examAverage;
  final String? mention;

  final String? decision, targetClassId;
  final bool reenrolled;

  /// Statut de l'inscription de l'année. `graduated` = sortie déjà prononcée.
  final String enrollmentStatus;

  bool get presented => candidateNumber != null || result != null;
  bool get proclaimed =>
      result != null && result != 'en_attente' && result!.isNotEmpty;
  bool get admitted => result == 'admis';
  bool get decided => decision != null && decision!.isNotEmpty;
  bool get graduated => enrollmentStatus == 'graduated';

  String? get suggestion => verdictFromExamResult(result);
}

/// Une classe d'examen, prête à être close.
class ExamClosureSession {
  const ExamClosureSession({
    required this.entries,
    required this.examLabel,
    required this.nextYearId,
    required this.nextYearLabel,
    required this.nextLevelClass,
    required this.repeatClass,
    required this.nextYearHasStructure,
    required this.qualifyPending,
  });

  final List<ExamClosureEntry> entries;

  /// « BEPC — session 2026 ». Vide quand aucun élève n'a été présenté.
  final String? examLabel;
  final String? nextYearId, nextYearLabel;

  /// Classe d'accueil des ADMIS. `null` quand l'établissement n'accueille pas
  /// le niveau suivant — c'est le cas normal d'un CM2 en école primaire ou
  /// d'une Terminale : l'admis s'en va.
  final TargetClass? nextLevelClass;

  /// Même niveau l'année suivante — la destination d'un ajourné.
  final TargetClass? repeatClass;

  /// L'année suivante porte au moins une classe pour cet établissement.
  ///
  /// ⚠️ Sans cette distinction, une structure simplement PAS ENCORE RECONDUITE
  /// se lit exactement comme un établissement qui n'accueille pas le niveau
  /// suivant : `nextLevelClass` est `null` dans les deux cas. On annoncerait
  /// alors « quitte l'établissement » à toute une classe de 3ème d'un lycée
  /// qui l'accueille très bien — et, pire, on proposerait de prononcer des
  /// sorties diplômées, qui ferment l'inscription et ne se reprennent pas.
  final bool nextYearHasStructure;

  /// La classe porte `exam_status = 'a_qualifier'` : le système n'a pas su
  /// dire si elle mène à un examen. Elle n'apparaît alors NI dans le passage
  /// NI ici de plein droit ; on la montre pour qu'elle ne se perde pas.
  final bool qualifyPending;

  int get presentedCount => entries.where((e) => e.presented).length;
  int get admittedCount => entries.where((e) => e.result == 'admis').length;
  int get failedCount => entries.where((e) => e.result == 'ajourne').length;
  int get absentCount => entries.where((e) => e.result == 'absent').length;
  int get pendingCount =>
      entries.where((e) => e.presented && !e.proclaimed).length;
  int get decidedCount => entries.where((e) => e.decided).length;
  int get reenrolledCount => entries.where((e) => e.reenrolled).length;

  /// Élèves de la classe qui n'ont pas été présentés à l'examen. Leur sort
  /// reste entre les mains de l'établissement.
  int get notPresentedCount => entries.where((e) => !e.presented).length;

  /// Ce que « Reporter les résultats » écrirait : les proclamés qui portent
  /// une proposition et n'ont pas encore de décision.
  int get reportableCount => entries
      .where((e) => !e.decided && e.suggestion != null)
      .length;

  /// Les admis qui n'ont nulle part où aller dans l'établissement : ils
  /// sortent, diplôme en poche.
  ///
  /// Vide tant que l'année suivante n'est pas montée : on ne prononce pas une
  /// sortie sur une absence de données.
  List<ExamClosureEntry> get leavers => [
        if (nextYearHasStructure)
          for (final e in entries)
            if (e.admitted && !e.graduated && nextLevelClass == null) e,
      ];

  /// L'établissement n'accueille réellement pas la suite — constaté sur une
  /// structure existante, pas déduit d'un silence.
  bool get admittedLeave => nextYearHasStructure && nextLevelClass == null;

  /// Réinscriptions possibles : il faut une année d'accueil ET une classe.
  bool get canReenroll =>
      nextYearId != null && (repeatClass != null || nextLevelClass != null);
}

/// Une classe d'examen dans la liste de campagne.
class ExamClosureClass {
  const ExamClosureClass({
    required this.classId,
    required this.className,
    required this.cycleName,
    required this.filiereLabel,
    required this.students,
    required this.admitted,
    required this.failed,
    required this.pending,
    required this.decided,
    required this.reenrolled,
    required this.qualifyPending,
  });

  final String classId, className, cycleName;
  final String? filiereLabel;
  final int students, admitted, failed, pending, decided, reenrolled;
  final bool qualifyPending;

  /// Aucun résultat proclamé n'est encore arrivé : il n'y a rien à clore.
  bool get awaitingProclamation => admitted == 0 && failed == 0;
}

/// Les classes d'EXAMEN de l'école pour l'année active.
///
/// Symétrique de `passageClassesProvider`, qui ne prend que `exam_status =
/// 'passage'`. Les deux écrans réunis couvrent donc toutes les classes — y
/// compris `a_qualifier`, qui autrement n'apparaîtrait nulle part.
final examClosureClassesProvider = FutureProvider.autoDispose
    .family<List<ExamClosureClass>, String>((ref, yearId) async {
  ref.keepAlive();
  final next = await _nextYearId(yearId);

  final rows = await db.getAll(
    '''
    SELECT c.id, c.name, c.filiere_label, c.exam_status,
           COALESCE(ec.name, 'Autres') AS cycle_name,
           COALESCE(ec.order_index, 9)  AS cycle_order,
           COUNT(e.id)                                                    AS students,
           SUM(CASE WHEN e.promotion_decision IS NOT NULL THEN 1 ELSE 0 END) AS decided
      FROM classes c
      LEFT JOIN education_cycles ec ON ec.code = c.cycle_code
      LEFT JOIN class_enrollments e
             ON e.class_id = c.id AND e.status IN ('active', 'graduated')
     WHERE c.academic_year_id = ? AND COALESCE(c.is_active, 1) <> 0
       AND COALESCE(c.exam_status, 'passage') <> 'passage'
     GROUP BY c.id, c.name, c.filiere_label, c.exam_status, ec.name, ec.order_index
     ORDER BY cycle_order, c.level_order, c.name
    ''',
    [yearId],
  );
  if (rows.isEmpty) return const [];

  // Résultats par classe. Requête séparée : jointe à la précédente, une
  // candidature multiplierait les lignes d'inscription et fausserait l'effectif.
  final resRows = await db.getAll(
    '''
    SELECT x.class_id AS cid,
           SUM(CASE WHEN x.result = 'admis'   THEN 1 ELSE 0 END) AS admis,
           SUM(CASE WHEN x.result = 'ajourne' THEN 1 ELSE 0 END) AS ajournes,
           SUM(CASE WHEN x.result IS NULL OR x.result = 'en_attente'
                    THEN 1 ELSE 0 END)                           AS attente
      FROM exam_candidates x
      JOIN classes c ON c.id = x.class_id
     WHERE c.academic_year_id = ?
     GROUP BY x.class_id
    ''',
    [yearId],
  );
  final byClass = {for (final r in resRows) r['cid'] as String: r};

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
      [next, yearId],
    );
    for (final r in done) {
      reenrolled[r['cid'] as String] = (r['n'] as int?) ?? 0;
    }
  }

  return [
    for (final r in rows)
      ExamClosureClass(
        classId: r['id'] as String,
        className: r['name'] as String? ?? '—',
        cycleName: r['cycle_name'] as String? ?? 'Autres',
        filiereLabel: r['filiere_label'] as String?,
        students: (r['students'] as int?) ?? 0,
        admitted: (byClass[r['id']]?['admis'] as int?) ?? 0,
        failed: (byClass[r['id']]?['ajournes'] as int?) ?? 0,
        pending: (byClass[r['id']]?['attente'] as int?) ?? 0,
        decided: (r['decided'] as int?) ?? 0,
        reenrolled: reenrolled[r['id'] as String] ?? 0,
        qualifyPending: r['exam_status'] == 'a_qualifier',
      ),
  ];
});

/// La clôture d'une classe d'examen : élèves, résultats, destinations.
final examClosureSessionProvider = FutureProvider.autoDispose
    .family<ExamClosureSession, String>((ref, classId) async {
  ref.keepAlive();

  final cls = await db.getAll(
    'SELECT school_id, academic_year_id, cycle_code, level_order, '
    '       filiere_label, exam_status '
    'FROM classes WHERE id = ?',
    [classId],
  );
  if (cls.isEmpty) {
    return const ExamClosureSession(
      entries: [],
      examLabel: null,
      nextYearId: null,
      nextYearLabel: null,
      nextLevelClass: null,
      repeatClass: null,
      nextYearHasStructure: false,
      qualifyPending: false,
    );
  }
  final c = cls.first;
  final schoolId = c['school_id'] as String?;
  final yearId = c['academic_year_id'] as String?;
  final cycle = c['cycle_code'] as String?;
  final levelOrder = (c['level_order'] as int?) ?? 0;
  final filiere = c['filiere_label'] as String?;

  // ── Les élèves, avec leur résultat s'ils ont été présentés ────────────────
  // `graduated` reste dans la liste : une sortie déjà prononcée doit rester
  // visible, sans quoi l'écran donnerait l'impression que l'élève n'a jamais
  // existé.
  final rows = await db.getAll(
    '''
    SELECT e.id AS enrollment_id, e.student_id, e.status,
           e.promotion_decision, e.promotion_target_class_id,
           s.first_name, s.last_name, s.matricule,
           x.candidate_number, x.result, x.average, x.mention, x.session_id
      FROM class_enrollments e
      JOIN students s ON s.id = e.student_id
      LEFT JOIN exam_candidates x
             ON x.student_id = e.student_id AND x.class_id = e.class_id
     WHERE e.class_id = ? AND e.status IN ('active', 'graduated')
     ORDER BY s.last_name, s.first_name
    ''',
    [classId],
  );

  final nextYear = await _nextYear(yearId);
  final reenrolled = <String>{};
  if (nextYear != null) {
    final done = await db.getAll(
      'SELECT student_id FROM class_enrollments WHERE academic_year_id = ? '
      'AND student_id IN (SELECT student_id FROM class_enrollments WHERE class_id = ?)',
      [nextYear.$1, classId],
    );
    for (final r in done) {
      reenrolled.add(r['student_id'] as String);
    }
  }

  // Une candidature en double multiplierait la ligne de l'élève : on garde la
  // première, l'inscription étant unique par élève et par année.
  final seen = <String>{};
  final entries = <ExamClosureEntry>[];
  String? sessionId;
  for (final r in rows) {
    final id = r['enrollment_id'] as String;
    if (!seen.add(id)) continue;
    sessionId ??= r['session_id'] as String?;
    entries.add(ExamClosureEntry(
      enrollmentId: id,
      studentId: r['student_id'] as String,
      studentName:
          '${r['first_name'] ?? ''} ${r['last_name'] ?? ''}'.trim(),
      matricule: r['matricule'] as String?,
      candidateNumber: r['candidate_number'] as String?,
      result: r['result'] as String?,
      examAverage: (r['average'] as num?)?.toDouble(),
      mention: r['mention'] as String?,
      decision: r['promotion_decision'] as String?,
      targetClassId: r['promotion_target_class_id'] as String?,
      reenrolled: reenrolled.contains(r['student_id'] as String),
      enrollmentStatus: r['status'] as String? ?? 'active',
    ));
  }

  final examLabel = sessionId == null ? null : await _examLabel(sessionId);

  final nextLevel = nextYear == null
      ? null
      : await _nextLevelClass(
          schoolId, nextYear.$1, cycle, levelOrder, filiere);
  final repeat = nextYear == null
      ? null
      : await _classAt(schoolId, nextYear.$1, cycle, levelOrder, filiere);

  // La structure de l'année d'accueil existe-t-elle, ne serait-ce qu'en
  // partie ? C'est ce qui sépare « l'école n'accueille pas la suite » de
  // « personne n'a encore reconduit les classes ».
  // `is_active` n'entre PAS dans ce test : une classe désactivée reste la
  // preuve que quelqu'un a reconduit la structure. C'est la même lecture que
  // `rolloverClasses`, qui décide « déjà reconduite » sans ce filtre — deux
  // réponses divergentes sur la même question dérouteraient l'utilisateur.
  var hasStructure = false;
  if (nextYear != null && schoolId != null) {
    final n = await db.getAll(
      'SELECT COUNT(*) AS n FROM classes '
      'WHERE school_id = ? AND academic_year_id = ?',
      [schoolId, nextYear.$1],
    );
    hasStructure = ((n.first['n'] as num?)?.toInt() ?? 0) > 0;
  }

  return ExamClosureSession(
    entries: entries,
    examLabel: examLabel,
    nextYearId: nextYear?.$1,
    nextYearLabel: nextYear?.$2,
    nextLevelClass: nextLevel,
    repeatClass: repeat,
    nextYearHasStructure: hasStructure,
    qualifyPending: c['exam_status'] == 'a_qualifier',
  );
});

// ─── Résolution des destinations ─────────────────────────────────────────────

Future<String?> _nextYearId(String? yearId) async =>
    (await _nextYear(yearId))?.$1;

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

Future<String?> _examLabel(String sessionId) async {
  final rows = await db.getAll(
    'SELECT ne.short_name, ne.name, ne.code, es.year_label '
    'FROM exam_sessions es LEFT JOIN national_exams ne ON ne.id = es.exam_id '
    'WHERE es.id = ?',
    [sessionId],
  );
  if (rows.isEmpty) return null;
  final r = rows.first;
  final name = (r['short_name'] as String?)?.trim().isNotEmpty == true
      ? r['short_name'] as String
      : (r['code'] as String?) ?? (r['name'] as String?) ?? 'Examen';
  final year = (r['year_label'] as String?) ?? '';
  return year.isEmpty ? name : '$name — session $year';
}

/// La classe du même niveau l'année suivante : où redouble un ajourné.
Future<TargetClass?> _classAt(
  String? schoolId,
  String yearId,
  String? cycle,
  int levelOrder,
  String? filiere,
) async {
  if (schoolId == null) return null;
  final rows = await db.getAll(
    // `<> 0` et non `= 1` : une classe créée localement par la reconduction
    // n'est pas retrouvée par l'égalité stricte dans la vue PowerSync.
    'SELECT id, name, filiere_label FROM classes '
    'WHERE school_id = ? AND academic_year_id = ? AND cycle_code = ? '
    '  AND level_order = ? AND COALESCE(is_active, 1) <> 0 ORDER BY name',
    [schoolId, yearId, cycle, levelOrder],
  );
  return _pick(rows, filiere);
}

/// La classe qui suit une classe d'examen — et elle change souvent de CYCLE.
///
/// C'est toute la différence avec le passage : une classe de passage n'est
/// jamais en haut de son cycle, donc son successeur est toujours à côté. Une
/// classe d'examen, elle, est TOUJOURS en haut : après la 3ème vient la 2nde,
/// c'est-à-dire un autre cycle. Chercher `level_order + 1` dans le même cycle
/// ne trouverait jamais rien et l'admis n'aurait nulle part où aller.
///
/// On regarde donc d'abord le niveau suivant du même cycle — un établissement
/// peut avoir organisé sa progression autrement — puis, à défaut, le premier
/// niveau du cycle immédiatement supérieur ouvert dans l'établissement.
/// `null` est un résultat normal : l'école n'accueille pas la suite, l'admis
/// s'en va.
Future<TargetClass?> _nextLevelClass(
  String? schoolId,
  String yearId,
  String? cycle,
  int levelOrder,
  String? filiere,
) async {
  if (schoolId == null) return null;

  final same = await _classAt(schoolId, yearId, cycle, levelOrder + 1, filiere);
  if (same != null) return same;

  final rows = await db.getAll(
    '''
    SELECT c.id, c.name, c.filiere_label, c.level_order, ec.order_index
      FROM classes c
      JOIN education_cycles ec ON ec.code = c.cycle_code
     WHERE c.school_id = ? AND c.academic_year_id = ?
       AND COALESCE(c.is_active, 1) <> 0
       AND ec.order_index > (SELECT COALESCE(MAX(order_index), 0)
                               FROM education_cycles WHERE code = ?)
     ORDER BY ec.order_index, c.level_order, c.name
    ''',
    [schoolId, yearId, cycle],
  );
  if (rows.isEmpty) return null;

  // Le premier niveau du premier cycle supérieur, et lui seul : sans ce
  // filtre, une 1ère se glisserait devant une 2nde dès qu'elle est mieux
  // classée par nom.
  final firstCycle = rows.first['order_index'];
  final firstLevel = rows
      .where((r) => r['order_index'] == firstCycle)
      .map((r) => (r['level_order'] as int?) ?? 0)
      .reduce((a, b) => a < b ? a : b);
  final shortlist = rows
      .where((r) =>
          r['order_index'] == firstCycle && r['level_order'] == firstLevel)
      .toList();
  return _pick(shortlist, filiere);
}

/// À niveau égal, on reste dans sa filière : un G2 ne bascule pas en
/// électronique par défaut de tri alphabétique.
TargetClass? _pick(List<Map<String, Object?>> rows, String? filiere) {
  if (rows.isEmpty) return null;
  final same = rows.where((r) => r['filiere_label'] == filiere);
  final r = same.isNotEmpty ? same.first : rows.first;
  return TargetClass(id: r['id'] as String, name: r['name'] as String? ?? '—');
}

// ─── Écritures (offline-first) ───────────────────────────────────────────────

/// Reporte la proclamation en décisions de fin d'année.
///
/// N'écrase JAMAIS une décision déjà prise : un chef d'établissement qui a
/// tranché à la main garde le dernier mot, y compris contre la proposition.
Future<int> applyExamResults({
  required ExamClosureSession session,
  required String? actorId,
}) async {
  final now = DateTime.now().toIso8601String();
  var n = 0;
  await db.writeTransaction((tx) async {
    for (final e in session.entries) {
      if (e.decided) continue;
      final verdict = e.suggestion;
      if (verdict == null) continue;
      final target = verdict == 'passe'
          ? session.nextLevelClass?.id
          : session.repeatClass?.id;
      await tx.execute(
        'UPDATE class_enrollments SET promotion_decision = ?, '
        '  promotion_average = ?, promotion_target_class_id = ?, '
        '  promotion_decided_at = ?, promotion_decided_by = ?, updated_at = ? '
        'WHERE id = ?',
        [verdict, e.examAverage, target, now, actorId, now, e.enrollmentId],
      );
      n++;
    }
  });
  return n;
}

/// Réinscrit dans l'année suivante les élèves dont le sort est réglé et qui
/// ont une classe d'accueil dans l'établissement.
///
/// Les identifiants de rattachement sont exigés en paramètre : une inscription
/// à laquelle il manque `group_id`/`school_id` est refusée au serveur, et
/// PowerSync abandonne alors le LOT ENTIER — toute la classe disparaîtrait
/// sans message.
Future<int> reenrollAfterExam({
  required ExamClosureSession session,
  required String groupId,
  required String schoolId,
  required String? actorId,
}) async {
  final yearId = session.nextYearId;
  if (yearId == null) return 0;

  final todo = [
    for (final e in session.entries)
      if (e.decided && !e.reenrolled && !e.graduated) e,
  ];
  if (todo.isEmpty) return 0;

  final now = DateTime.now().toIso8601String();
  final today = now.substring(0, 10);
  var n = 0;

  await db.writeTransaction((tx) async {
    for (final e in todo) {
      final repeating = e.decision == 'redouble';
      final target = e.targetClassId ??
          (repeating ? session.repeatClass?.id : session.nextLevelClass?.id);
      // Pas de classe d'accueil : l'admis quitte l'établissement. Ce n'est pas
      // un échec de la réinscription, c'est la fin normale d'un cycle.
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

/// Prononce la sortie diplômée des admis qui n'ont pas de classe d'accueil.
///
/// C'est la seule écriture de l'application qui pose `graduated`. Elle retire
/// l'élève des effectifs actifs — exactement comme une sortie en cours
/// d'année — et c'est bien ce qu'on veut dire : il a fini, il est parti avec
/// son diplôme. Son dossier, ses notes, ses bulletins et sa candidature
/// restent en place ; seule l'inscription se ferme.
Future<int> graduateLeavers({
  required ExamClosureSession session,
  required String? actorId,
}) async {
  final todo = session.leavers;
  if (todo.isEmpty) return 0;
  final now = DateTime.now().toIso8601String();
  var n = 0;
  await db.writeTransaction((tx) async {
    for (final e in todo) {
      await tx.execute(
        'UPDATE class_enrollments SET status = ?, promotion_decision = ?, '
        '  promotion_target_class_id = NULL, promotion_decided_at = ?, '
        '  promotion_decided_by = ?, updated_at = ? WHERE id = ?',
        ['graduated', 'passe', now, actorId, now, e.enrollmentId],
      );
      n++;
    }
  });
  return n;
}
