import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/powersync/powersync_service.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CE QUE L'ÉLÈVE A OBTENU — bulletins de toutes les années, notes d'une année
//
//  ── DEUX GRANULARITÉS, ET C'EST VOULU ──────────────────────────────────────
//  Les BULLETINS se lisent sur toute la scolarité : douze lignes au plus, et
//  c'est la seule vue qui montre une progression ou un décrochage.
//
//  Les NOTES, elles, sont chargées ANNÉE PAR ANNÉE, à la demande. Le relevé de
//  production le dit : une école porte déjà 38 544 notes. Tout lire pour un
//  élève reste modeste, mais la requête se rejoue à chaque tick de synchro sur
//  un portable d'entrée de gamme, hors ligne, en salle des professeurs — et
//  personne ne lit les notes de quatrième d'un élève de terminale en ouvrant
//  sa fiche. On charge l'année qu'on regarde.
//
//  ── CE PROVIDER NE CALCULE AUCUNE MOYENNE ──────────────────────────────────
//  ⚠️ `bulletins.overall_average`, `class_average`, `rank` et `mention` sont
//  ÉCRITS par le module Évaluation, qui applique le barème du niveau, les
//  coefficients et les règles de clôture. Recalculer une moyenne ici pour
//  « vérifier » produirait deux chiffres pour la même chose, dont un faux, sur
//  un document que la famille lit. La fiche RAPPORTE ; elle ne juge pas.
// ════════════════════════════════════════════════════════════════════════════

DateTime? _d(Object? v) =>
    (v is String && v.isNotEmpty) ? DateTime.tryParse(v) : null;

String _s(Object? v) => (v as String?)?.trim() ?? '';

double? _n(Object? v) =>
    v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));

int? _i(Object? v) => (v as num?)?.toInt();

/// Un bulletin, tel qu'il a été arrêté par le conseil.
class BulletinLigne {
  const BulletinLigne({
    required this.id,
    required this.anneeId,
    required this.anneeLabel,
    required this.trimestre,
    required this.trimestreNum,
    required this.moyenne,
    required this.moyenneClasse,
    required this.rang,
    required this.effectif,
    required this.mention,
    required this.decision,
    required this.absences,
    required this.retards,
    required this.statut,
    required this.appreciationProf,
    required this.appreciationDirecteur,
    required this.publieLe,
  });

  final String id, anneeId, anneeLabel, trimestre;
  final int? trimestreNum;
  final double? moyenne, moyenneClasse;
  final int? rang, effectif, absences, retards;
  final String mention, decision, statut;
  final String appreciationProf, appreciationDirecteur;
  final DateTime? publieLe;

  /// Le rang ne se lit qu'accompagné de l'effectif : « 8ᵉ » ne dit rien,
  /// « 8ᵉ sur 52 » dit tout.
  String get rangLabel => rang == null
      ? '—'
      : effectif == null || effectif == 0
          ? '$rang'
          : '$rang / $effectif';
}

/// Une note, rattachée à son évaluation et à sa matière.
class NoteLigne {
  const NoteLigne({
    required this.matiere,
    required this.trimestre,
    required this.titre,
    required this.type,
    required this.date,
    required this.note,
    required this.bareme,
    required this.coefficient,
    required this.absent,
    required this.appreciation,
  });

  final String matiere, trimestre, titre, type, appreciation;
  final DateTime? date;
  final double? note, bareme, coefficient;
  final bool absent;

  /// La note ramenée sur 20 — la seule forme comparable d'une matière à
  /// l'autre quand les barèmes diffèrent (un devoir sur 40, une interro sur 10).
  double? get sur20 {
    final n = note, b = bareme;
    if (n == null || b == null || b <= 0) return null;
    return n * 20 / b;
  }
}

/// Tous les bulletins de l'élève, du plus récent au plus ancien.
final ficheBulletinsProvider = StreamProvider.autoDispose
    .family<List<BulletinLigne>, String>((ref, studentId) {
  return db.watch(
    '''
    SELECT b.id, b.academic_year_id, b.overall_average, b.class_average,
           b.rank, b.total_students, b.mention, b.decision, b.total_absences,
           b.total_lates, b.status, b.teacher_comment, b.director_comment,
           b.published_at,
           t.label AS trimester_label, t.trimester_number,
           ay.label AS year_label, ay.start_date AS year_start
      FROM bulletins b
      LEFT JOIN trimesters     t  ON t.id  = b.trimester_id
      LEFT JOIN academic_years ay ON ay.id = b.academic_year_id
     WHERE b.student_id = ?
     ORDER BY ay.start_date DESC, t.trimester_number DESC
    ''',
    parameters: [studentId],
  ).map((rows) => [
        for (final r in rows)
          BulletinLigne(
            id: _s(r['id']),
            anneeId: _s(r['academic_year_id']),
            anneeLabel: _s(r['year_label']),
            trimestre: _s(r['trimester_label']),
            trimestreNum: _i(r['trimester_number']),
            moyenne: _n(r['overall_average']),
            moyenneClasse: _n(r['class_average']),
            rang: _i(r['rank']),
            effectif: _i(r['total_students']),
            mention: _s(r['mention']),
            decision: _s(r['decision']),
            absences: _i(r['total_absences']),
            retards: _i(r['total_lates']),
            statut: _s(r['status']),
            appreciationProf: _s(r['teacher_comment']),
            appreciationDirecteur: _s(r['director_comment']),
            publieLe: _d(r['published_at']),
          ),
      ]);
});

/// Les notes d'UNE année, groupées à l'affichage par matière.
///
/// L'année vide rend une liste vide sans interroger la base : c'est le cas
/// d'un élève dont on ouvre la fiche avant qu'une année ne soit choisie.
final ficheNotesProvider = StreamProvider.autoDispose
    .family<List<NoteLigne>, (String studentId, String anneeId)>((ref, args) {
  final (studentId, anneeId) = args;
  if (anneeId.isEmpty) return Stream.value(const []);
  return db.watch(
    '''
    SELECT g.score, g.is_absent, g.appreciation,
           e.title, e.evaluation_type, e.evaluation_date, e.max_score,
           e.coefficient,
           s.name AS subject_name,
           t.label AS trimester_label, t.trimester_number
      FROM grades g
      JOIN evaluations e ON e.id = g.evaluation_id
      LEFT JOIN subjects   s ON s.id = e.subject_id
      LEFT JOIN trimesters t ON t.id = e.trimester_id
     WHERE g.student_id = ? AND e.academic_year_id = ?
     ORDER BY s.name, t.trimester_number, e.evaluation_date
    ''',
    parameters: [studentId, anneeId],
  ).map((rows) => [
        for (final r in rows)
          NoteLigne(
            matiere: _s(r['subject_name']),
            trimestre: _s(r['trimester_label']),
            titre: _s(r['title']),
            type: _s(r['evaluation_type']),
            date: _d(r['evaluation_date']),
            note: _n(r['score']),
            bareme: _n(r['max_score']),
            coefficient: _n(r['coefficient']),
            absent: r['is_absent'] == 1 || r['is_absent'] == true,
            appreciation: _s(r['appreciation']),
          ),
      ]);
});
