import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/mention.dart';
import '../../../core/utils/rang.dart';
import '../../../core/utils/identite_offline.dart';
import '../../../services/powersync/powersync_service.dart';

// Le barème des mentions vit dans `core/utils/mention.dart` — une seule copie,
// l'unique autorité du barème (la fonction SQL `get_mention()` a été
// supprimée en 0117, faute d'appelant). Il en existait ici une
// version décalée de deux points : 8/20 ressortait « Passable » sur les
// bulletins. On le ré-exporte pour ne pas casser les écrans qui l'importent
// depuis ce provider.
export '../../../core/utils/mention.dart' show mentionFor;

// ════════════════════════════════════════════════════════════════════════════
//  BULLETINS (tables `bulletins` + `bulletin_subject_lines`) — relevés de notes
//  par élève × trimestre. Calculés à partir des `grades` : moyenne par matière
//  (notes /20 pondérées par le coefficient de l'évaluation), moyenne générale
//  (pondérée par le coefficient de la matière), rang, mention. Le calcul est
//  fait offline (db) ; la « génération » persiste le résultat (cycle de vie
//  draft → submitted → validated → published). 100% offline.
// ════════════════════════════════════════════════════════════════════════════


class SubjectLine {
  const SubjectLine({
    required this.subjectId,
    required this.subjectName,
    required this.coefficient,
    required this.average,
    required this.classAverage,
    required this.rank,
  });
  final String subjectId, subjectName;
  final int coefficient;
  final double? average; // /20, null si aucune note
  final double? classAverage;
  final int? rank;

  double? get weighted => average == null ? null : average! * coefficient;
}

class StudentBulletin {
  const StudentBulletin({
    required this.enrollmentId,
    required this.studentId,
    required this.studentName,
    required this.matricule,
    required this.overallAverage,
    required this.rank,
    required this.totalStudents,
    required this.lines,
    required this.persisted,
    required this.status,
    required this.absences,
    required this.retards,
    this.decision,
    this.councilAppreciation,
    this.directorComment,
  });
  final String enrollmentId, studentId, studentName;
  final String? matricule;
  final double? overallAverage; // /20
  final int rank, totalStudents;
  final List<SubjectLine> lines;
  final bool persisted; // un bulletin existe déjà en base
  final String status; // statut du bulletin persisté (ou 'draft')
  // Assiduité comptée sur la fenêtre du trimestre depuis l'appel quotidien.
  // NULL = AUCUN appel enregistré pour cet élève : inconnu — et surtout pas
  // « aucune absence ». Le bulletin écrivait 0 en dur, ce qui affirmait sur
  // chaque enfant un fait que personne n'avait observé (migration 0122).
  final int? absences, retards;
  // Sortie du conseil de classe (délibération) — portée par le bulletin.
  final String? decision; // distinction attribuée (code, cf. conseils_provider)
  final String? councilAppreciation; // appréciation du conseil (teacher_comment)
  final String? directorComment; // synthèse / avis du chef d'établissement

  String get mention => mentionFor(overallAverage);

  /// « 3 absences · 1 retard », ou l'aveu qu'aucun appel n'a été enregistré.
  ///
  /// Écrire « 0 absence » quand personne n'a fait l'appel serait une affirmation
  /// sur un enfant que personne n'a vérifiée — sur un document que la famille
  /// garde et qu'un conseil de classe lit.
  String get assiduiteLabel {
    final a = absences, r = retards;
    if (a == null && r == null) return 'Non renseignée — aucun appel enregistré';
    final bouts = <String>[
      '${a ?? 0} absence${(a ?? 0) > 1 ? 's' : ''}',
      '${r ?? 0} retard${(r ?? 0) > 1 ? 's' : ''}',
    ];
    return bouts.join(' · ');
  }
}

class BulletinComputation {
  const BulletinComputation({
    required this.students,
    required this.classAverage,
    required this.evaluationCount,
  });
  final List<StudentBulletin> students;
  final double? classAverage; // moyenne générale de la classe
  final int evaluationCount;
}

typedef BulletinArgs = ({String classId, String? trimesterId});

/// Calcul des bulletins d'une classe pour un trimestre, depuis les `grades`.
final bulletinComputationProvider = FutureProvider.autoDispose
    .family<BulletinComputation, BulletinArgs>((ref, args) async {
  ref.keepAlive();
  final trimClause =
      args.trimesterId != null ? 'AND e.trimester_id = ?' : '';
  final evalParams = <Object?>[args.classId];
  if (args.trimesterId != null) evalParams.add(args.trimesterId);

  // 1) Évaluations de la classe (et trimestre) avec barème + coefficient.
  final evals = await db.getAll(
    'SELECT id, subject_id, coefficient, max_score FROM evaluations e '
    'WHERE e.class_id = ? $trimClause',
    evalParams,
  );
  final evalCoef = <String, int>{};
  final evalMax = <String, double>{};
  final evalSubject = <String, String>{};
  for (final e in evals) {
    final id = e['id'] as String;
    evalCoef[id] = (e['coefficient'] as int?) ?? 1;
    evalMax[id] = (e['max_score'] as num?)?.toDouble() ?? 20;
    evalSubject[id] = (e['subject_id'] as String?) ?? '';
  }

  // 2) Coefficient + nom de chaque matière de la classe.
  final subjRows = await db.getAll(
    '''
    SELECT cs.subject_id AS sid,
           COALESCE(cs.coefficient, subj.coefficient) AS coef,
           subj.name AS name
    FROM class_subjects cs
    JOIN subjects subj ON subj.id = cs.subject_id
    WHERE cs.class_id = ?
    ORDER BY subj.name
    ''',
    [args.classId],
  );
  final subjCoef = <String, int>{};
  final subjName = <String, String>{};
  for (final s in subjRows) {
    final id = s['sid'] as String;
    subjCoef[id] = (s['coef'] as num?)?.toInt() ?? 1;
    subjName[id] = (s['name'] as String?) ?? '—';
  }

  // 3) Élèves actifs de la classe.
  final studentRows = await db.getAll(
    '''
    SELECT ce.id AS enrollment_id, s.id AS student_id,
           s.first_name, s.last_name, s.matricule
    FROM class_enrollments ce
    JOIN students s ON s.id = ce.student_id
    WHERE ce.class_id = ? AND ce.status = 'active'
    ORDER BY s.last_name, s.first_name
    ''',
    [args.classId],
  );

  // 4) Toutes les notes des évaluations concernées.
  final gradeRows = await db.getAll(
    '''
    SELECT g.enrollment_id, g.evaluation_id, g.score, g.is_absent
    FROM grades g
    JOIN evaluations e ON e.id = g.evaluation_id
    WHERE e.class_id = ? $trimClause
    ''',
    evalParams,
  );
  // enrollment → subject → list of (normalized score, evalCoef)
  final byStudentSubject = <String, Map<String, List<(double, int)>>>{};
  for (final g in gradeRows) {
    if (((g['is_absent'] as int?) ?? 0) == 1) continue;
    final score = (g['score'] as num?)?.toDouble();
    if (score == null) continue;
    final evalId = g['evaluation_id'] as String;
    final subj = evalSubject[evalId] ?? '';
    final max = evalMax[evalId] ?? 20;
    final coef = evalCoef[evalId] ?? 1;
    final norm = max > 0 ? score / max * 20 : 0.0;
    final enr = g['enrollment_id'] as String;
    ((byStudentSubject[enr] ??= {})[subj] ??= []).add((norm, coef));
  }

  // 5) Persistance existante (bulletins déjà générés) pour le statut.
  final existing = await db.getAll(
    'SELECT id, enrollment_id, status, decision, teacher_comment, '
    'director_comment, overall_average, class_average, rank, total_students, '
    'total_absences, total_lates '
    'FROM bulletins WHERE '
    '${args.trimesterId != null ? 'trimester_id = ?' : '1=1'} '
    'AND enrollment_id IN (SELECT id FROM class_enrollments WHERE class_id = ?)',
    args.trimesterId != null
        ? [args.trimesterId, args.classId]
        : [args.classId],
  );
  final statusByEnr = {
    for (final r in existing)
      r['enrollment_id'] as String: (r['status'] as String?) ?? 'draft'
  };
  final councilByEnr = {
    for (final r in existing)
      r['enrollment_id'] as String: (
        decision: r['decision'] as String?,
        appreciation: r['teacher_comment'] as String?,
        director: r['director_comment'] as String?,
      )
  };

  // ── 5 bis) UN BULLETIN PUBLIÉ EST UN DOCUMENT, PAS UNE VUE ────────────────
  //
  // ⚠️ `bulletin_subject_lines` était ÉCRITE ET JAMAIS LUE — ni par cet écran,
  // ni par le PDF, ni par le conseil, ni par le passage. Tout repartait de ce
  // calcul, en direct. `generateBulletins` refusait pourtant de retoucher un
  // bulletin publié : il protégeait des lignes que personne ne regardait.
  //
  // Conséquence : corriger une note, ou changer un coefficient de matière,
  // réécrivait un bulletin DÉJÀ REMIS aux parents et déjà signé. Le même
  // trimestre réimprimé en septembre ne donnait plus les mêmes moyennes qu'en
  // juillet, ni le même rang — et rien ne le signalait. Le conseil de classe
  // délibérait sur des chiffres qui pouvaient bouger après sa décision.
  //
  // Publier FIGE. On relit le document tel qu'il a été arrêté ; seules les
  // pièces qui vivent légitimement après coup (décision du conseil,
  // appréciations) restent en direct. Les brouillons, eux, se recalculent —
  // c'est ce qu'on attend d'un brouillon.
  final publies = <String, String>{
    for (final r in existing)
      if ((r['status'] as String?) == 'published')
        r['enrollment_id'] as String: r['id'] as String
  };
  final figeByEnr = <String, Map<String, Object?>>{
    for (final r in existing)
      if ((r['status'] as String?) == 'published') r['enrollment_id'] as String: r
  };
  final lignesFigees = <String, List<SubjectLine>>{};
  if (publies.isNotEmpty) {
    final ids = publies.values.toList();
    final ph = List.filled(ids.length, '?').join(',');
    final rows = await db.getAll(
      '''
      SELECT bl.bulletin_id, bl.subject_id, bl.average, bl.class_average,
             bl.rank, bl.coefficient, s.name AS subject_name
      FROM   bulletin_subject_lines bl
      LEFT JOIN subjects s ON s.id = bl.subject_id
      WHERE  bl.bulletin_id IN ($ph)
      ''',
      ids,
    );
    final parBulletin = <String, List<SubjectLine>>{};
    for (final r in rows) {
      (parBulletin[r['bulletin_id'] as String] ??= []).add(SubjectLine(
        subjectId: (r['subject_id'] as String?) ?? '',
        // Le nom vient du référentiel ; s'il a été archivé depuis, la ligne
        // reste lisible plutôt que de disparaître du bulletin.
        subjectName: (r['subject_name'] as String?) ?? '—',
        coefficient: (r['coefficient'] as num?)?.toInt() ?? 1,
        average: (r['average'] as num?)?.toDouble(),
        classAverage: (r['class_average'] as num?)?.toDouble(),
        rank: (r['rank'] as num?)?.toInt(),
      ));
    }
    for (final e in publies.entries) {
      final l = parBulletin[e.value];
      // Un bulletin publié SANS ligne enregistrée (généré avant ce correctif,
      // ou génération interrompue) retombe sur le calcul : mieux vaut un
      // bulletin recalculé qu'un bulletin vide.
      if (l != null && l.isNotEmpty) lignesFigees[e.key] = l;
    }
  }

  // 6) Moyenne par matière par élève.
  final subjAvg = <String, Map<String, double>>{}; // enr → subj → avg/20
  for (final entry in byStudentSubject.entries) {
    for (final se in entry.value.entries) {
      var sw = 0.0;
      var wc = 0;
      for (final (n, c) in se.value) {
        sw += n * c;
        wc += c;
      }
      if (wc > 0) (subjAvg[entry.key] ??= {})[se.key] = sw / wc;
    }
  }

  // 7) Moyennes de classe par matière (pour rang matière + class_average).
  final subjClassValues = <String, List<double>>{};
  for (final m in subjAvg.values) {
    for (final e in m.entries) {
      (subjClassValues[e.key] ??= []).add(e.value);
    }
  }
  final subjClassAvg = <String, double>{
    for (final e in subjClassValues.entries)
      e.key: e.value.reduce((a, b) => a + b) / e.value.length
  };

  // 8) Construction des bulletins élève + moyenne générale.
  final tmp = <(String enr, double? overall, List<SubjectLine> lines)>[];
  for (final st in studentRows) {
    final enr = st['enrollment_id'] as String;
    final avgMap = subjAvg[enr] ?? const {};
    final lines = <SubjectLine>[];
    var weightedSum = 0.0;
    var coefSum = 0;
    for (final sid in subjCoef.keys) {
      final a = avgMap[sid];
      final coef = subjCoef[sid] ?? 1;
      lines.add(SubjectLine(
        subjectId: sid,
        subjectName: subjName[sid] ?? '—',
        coefficient: coef,
        average: a,
        classAverage: subjClassAvg[sid],
        rank: null, // calculé ci-dessous
      ));
      if (a != null) {
        weightedSum += a * coef;
        coefSum += coef;
      }
    }
    final overall = coefSum > 0 ? weightedSum / coefSum : null;
    tmp.add((enr, overall, lines));
  }

  // 9) Rang par matière.
  // ⚠️ Le rang se COMPTE (cf. `rangDeCompetition`), il ne se lit pas dans une
  // liste triée : deux élèves à la même moyenne partagent le rang, et l'ordre
  // d'un tri instable ne décide plus lequel passe devant.
  final subjRankMap = <String, Map<String, int>>{}; // subj → enr → rank
  for (final sid in subjCoef.keys) {
    final pairs = <(String, double)>[];
    for (final t in tmp) {
      final a = (subjAvg[t.$1] ?? const {})[sid];
      if (a != null) pairs.add((t.$1, a));
    }
    final valeurs = [for (final p in pairs) p.$2];
    for (final p in pairs) {
      (subjRankMap[sid] ??= {})[p.$1] = rangDeCompetition(p.$2, valeurs);
    }
  }

  // 10) Rang général.
  // Un élève sans aucune note n'a pas de rang — il n'est pas dernier : il n'est
  // pas classé. Le compter parmi les autres ferait reculer tout le monde d'un
  // cran, et l'accuserait d'un résultat qu'il n'a pas eu.
  final notes = [for (final t in tmp) if (t.$2 != null) t.$2!];
  final overallRank = <String, int>{
    for (final t in tmp)
      if (t.$2 != null) t.$1: rangDeCompetition(t.$2!, notes),
  };

  // 10 bis) Assiduité — comptée sur la FENÊTRE DU TRIMESTRE, depuis l'appel
  // quotidien (`presences-eleves`). Un élève sans aucune entrée sur la période
  // n'a pas « zéro absence » : on n'en sait rien, et le bulletin le dira.
  final assiduite = <String, (int, int)>{};
  if (args.trimesterId != null) {
    final bornes = await db.getAll(
      'SELECT start_date, end_date FROM trimesters WHERE id = ?',
      [args.trimesterId],
    );
    if (bornes.isNotEmpty) {
      final debut = bornes.first['start_date'] as String?;
      final fin = bornes.first['end_date'] as String?;
      final ids = [for (final st in studentRows) st['student_id'] as String];
      if (debut != null && fin != null && ids.isNotEmpty) {
        final ph = List.filled(ids.length, '?').join(',');
        final compte = await db.getAll(
          '''
          SELECT e.student_id AS sid,
                 SUM(CASE WHEN e.status = 'absent' THEN 1 ELSE 0 END) AS abs,
                 SUM(CASE WHEN e.status = 'late'   THEN 1 ELSE 0 END) AS ret
          FROM   attendance_entries e
          JOIN   attendance_records r ON r.id = e.attendance_record_id
          WHERE  e.student_id IN ($ph)
            AND  r.record_date >= ? AND r.record_date <= ?
          GROUP  BY e.student_id
          ''',
          [...ids, debut, fin],
        );
        for (final r in compte) {
          assiduite[r['sid'] as String] =
              ((r['abs'] as int?) ?? 0, (r['ret'] as int?) ?? 0);
        }
      }
    }
  }

  final total = studentRows.length;
  final students = <StudentBulletin>[];
  for (final st in studentRows) {
    final enr = st['enrollment_id'] as String;
    final t = tmp.firstWhere((e) => e.$1 == enr);
    final lines = [
      for (final l in t.$3)
        SubjectLine(
          subjectId: l.subjectId,
          subjectName: l.subjectName,
          coefficient: l.coefficient,
          average: l.average,
          classAverage: l.classAverage,
          rank: subjRankMap[l.subjectId]?[enr],
        ),
    ];
    // Publié ⇒ on rend le document arrêté, pas le recalcul du jour.
    final fige = figeByEnr[enr];
    students.add(StudentBulletin(
      enrollmentId: enr,
      studentId: st['student_id'] as String,
      studentName: '${(st['last_name'] as String?) ?? ''} '
              '${(st['first_name'] as String?) ?? ''}'
          .trim(),
      matricule: st['matricule'] as String?,
      overallAverage:
          (fige?['overall_average'] as num?)?.toDouble() ?? t.$2,
      rank: (fige?['rank'] as num?)?.toInt() ?? (overallRank[enr] ?? 0),
      totalStudents:
          (fige?['total_students'] as num?)?.toInt() ?? total,
      lines: lignesFigees[enr] ?? lines,
      persisted: statusByEnr.containsKey(enr),
      status: statusByEnr[enr] ?? 'draft',
      absences: (fige?['total_absences'] as num?)?.toInt() ??
          assiduite[st['student_id'] as String]?.$1,
      retards: (fige?['total_lates'] as num?)?.toInt() ??
          assiduite[st['student_id'] as String]?.$2,
      decision: councilByEnr[enr]?.decision,
      councilAppreciation: councilByEnr[enr]?.appreciation,
      directorComment: councilByEnr[enr]?.director,
    ));
  }
  students.sort((a, b) {
    if (a.rank == 0 && b.rank == 0) return 0;
    if (a.rank == 0) return 1;
    if (b.rank == 0) return -1;
    return a.rank.compareTo(b.rank);
  });

  final classVals = [
    for (final s in students)
      if (s.overallAverage != null) s.overallAverage!
  ];
  // La moyenne de classe imprimée sur un bulletin publié est celle qui y
  // figure. `setBulletinsStatus` publie la classe ENTIÈRE d'un trimestre :
  // dès qu'un bulletin est publié, ils le sont tous, et le document porte sa
  // propre moyenne de classe.
  final figeeClasse = figeByEnr.values
      .map((r) => (r['class_average'] as num?)?.toDouble())
      .whereType<double>()
      .firstOrNull;
  final classAvg = figeeClasse ??
      (classVals.isEmpty
          ? null
          : classVals.reduce((a, b) => a + b) / classVals.length);

  return BulletinComputation(
    students: students,
    classAverage: classAvg,
    evaluationCount: evals.length,
  );
});

// ─── Génération / persistance (offline-first) ────────────────────────────────

/// Ce qu'une génération a fait : les bulletins (re)calculés, et ceux qu'elle a
/// refusé de toucher parce qu'ils étaient déjà publiés.
class GenerationBulletins {
  const GenerationBulletins({
    required this.calcules,
    required this.publiesIntacts,
  });
  final int calcules;
  final int publiesIntacts;

  bool get aLaisseIntact => publiesIntacts > 0;
}

/// Persiste (ou met à jour) les bulletins calculés d'une classe pour un
/// trimestre, avec leurs lignes-matières. Statut initial 'draft'.
///
/// ⚠️ UN BULLETIN PUBLIÉ N'EST JAMAIS RECALCULÉ. Deux raisons, et la première
/// suffirait :
///
///  1. C'est un document remis aux familles. Le réécrire sous elles — moyenne,
///     rang, mention — sans qu'aucune trace ne le dise est une falsification
///     silencieuse. Pour le refaire, il faut d'abord le DÉPUBLIER : le geste
///     existe, et il est réservé à qui peut publier.
///
///  2. La base refuse cette écriture à qui n'a pas `validate` (RLS `bulletins`,
///     migration 0118) — et un refus 42501 est FATAL pour le connecteur
///     PowerSync : il jette le LOT ENTIER en attente. Un enseignant qui
///     appuyait sur « Recalculer » perdait donc, sans un mot, toutes ses
///     saisies hors ligne du moment. Mesuré en production le 2026-08-27 :
///     474 bulletins publiés dans l'école témoin, refus confirmé.
Future<GenerationBulletins> generateBulletins({
  required String groupId,
  required String schoolId,
  required String academicYearId,
  required String trimesterId,
  required BulletinComputation comp,
}) async {
  final now = DateTime.now().toIso8601String();
  var count = 0;
  var publies = 0;
  for (final s in comp.students) {
    // Bulletin existant ?
    final ex = await db.getAll(
      'SELECT id, status FROM bulletins '
      // ⚠️ SUR LA CLÉ DE LA CONTRAINTE, pas sur l'inscription. La base tient
      // `UNIQUE (student_id, trimester_id)` ; chercher par `enrollment_id`
      // manquait le bulletin d'un élève ayant changé de classe en cours
      // d'année — deux inscriptions, deux bulletins tentés, 23505 fatal.
      'WHERE student_id = ? AND trimester_id = ?',
      [s.studentId, trimesterId],
    );
    if (ex.isNotEmpty && (ex.first['status'] as String?) == 'published') {
      publies++;
      continue;
    }
    final mention = mentionFor(s.overallAverage);
    String bulletinId;
    if (ex.isNotEmpty) {
      bulletinId = ex.first['id'] as String;
      await db.execute(
        '''
        UPDATE bulletins SET overall_average = ?, class_average = ?, rank = ?,
          total_students = ?, mention = ?, total_absences = ?, total_lates = ?,
          updated_at = ?
        WHERE id = ?
        ''',
        [s.overallAverage, comp.classAverage, s.rank == 0 ? null : s.rank,
         s.totalStudents, mention, s.absences, s.retards, now, bulletinId],
      );
      await db.execute(
          'DELETE FROM bulletin_subject_lines WHERE bulletin_id = ?',
          [bulletinId]);
    } else {
      // Déduit de la clé : deux postes qui génèrent le même trimestre hors
      // ligne écrivent la même ligne, au lieu d'en créer deux que le serveur
      // refuserait en 23505 — code fatal, lot entier jeté.
      bulletinId = idDeterministe('bulletin', [s.studentId, trimesterId]);
      await db.execute(
        '''
        INSERT INTO bulletins (
          id, group_id, school_id, student_id, enrollment_id, academic_year_id,
          trimester_id, overall_average, class_average, rank, total_students,
          mention, total_absences, total_lates, status, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'draft', ?, ?)
        ''',
        [bulletinId, groupId, schoolId, s.studentId, s.enrollmentId,
         academicYearId, trimesterId, s.overallAverage, comp.classAverage,
         s.rank == 0 ? null : s.rank, s.totalStudents, mention,
         s.absences, s.retards, now, now],
      );
    }
    for (final l in s.lines) {
      await db.execute(
        '''
        INSERT INTO bulletin_subject_lines (
          id, bulletin_id, subject_id, group_id, school_id, average,
          class_average, rank, coefficient, weighted_average,
          created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [idDeterministe('bulletin_subject_line', [bulletinId, l.subjectId]),
         bulletinId, l.subjectId, groupId, schoolId, l.average,
         l.classAverage, l.rank, l.coefficient, l.weighted, now, now],
      );
    }
    count++;
  }
  return GenerationBulletins(calcules: count, publiesIntacts: publies);
}

/// Change le statut de tous les bulletins d'une classe×trimestre.
Future<void> setBulletinsStatus({
  required String classId,
  required String trimesterId,
  required String status,
  String? actorId,
}) async {
  final now = DateTime.now().toIso8601String();
  final col = switch (status) {
    'published' => 'published_at',
    'validated' => 'validated_at',
    'submitted' => 'submitted_at',
    _ => null,
  };
  final actorCol = switch (status) {
    'published' => null,
    'validated' => 'validated_by',
    'submitted' => 'submitted_by',
    _ => null,
  };
  final sets = <String>['status = ?', 'updated_at = ?'];
  final params = <Object?>[status, now];
  if (col != null) {
    sets.add('$col = ?');
    params.add(now);
  }
  if (actorCol != null) {
    sets.add('$actorCol = ?');
    params.add(actorId);
  }
  params.addAll([trimesterId, classId]);
  await db.execute(
    'UPDATE bulletins SET ${sets.join(', ')} WHERE trimester_id = ? '
    'AND enrollment_id IN (SELECT id FROM class_enrollments WHERE class_id = ?)',
    params,
  );
}
