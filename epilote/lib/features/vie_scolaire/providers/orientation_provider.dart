import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../../core/utils/identite_offline.dart';
import '../../classes/providers/class_provider.dart';
import '../../structure/providers/academic_year_context.dart';
import '../widgets/vs_kit.dart';

/// Le slug de CE module, déclaré à côté des requêtes qu'il borne — le
/// littéral recopié dans deux fichiers est ce qui laisse un périmètre dériver.
const kSlugOrientation = 'orientation';

// ════════════════════════════════════════════════════════════════════════════
//  ORIENTATION (table `student_orientations`) — recommandation d'orientation par
//  élève × année × trimestre : niveau et filière cibles, recommandation,
//  consultation des parents. 100% offline.
//
//  ── ⚠️ UNE ORIENTATION QUI NE S'AGRÈGE PAS NE SERT À PERSONNE ─────────────
//  `target_level` et `target_filiere` se saisissaient en TEXTE LIBRE. Sur mille
//  écoles, « Série C », « serie C », « C » et « Scientifique » deviennent
//  quatre orientations distinctes : le MEPSA ne peut plus compter combien
//  d'élèves il envoie vers les séries scientifiques, ce qui est précisément la
//  raison d'être de ce module au niveau national.
//
//  On y écrit désormais le CODE du référentiel — `education_levels.code` et
//  `education_programs.code`, tous deux synchronisés sur le poste — et l'écran
//  en affiche le nom. Le référentiel est national (`group_id IS NULL`) ou
//  propre au groupe : une orientation vers un lycée technique qu'on ne possède
//  pas reste donc exprimable.
// ════════════════════════════════════════════════════════════════════════════

typedef OrientationArgs = ({String classId, String? trimesterId});

class OrientationOverview {
  const OrientationOverview({
    required this.rows,
    required this.oriented,
    required this.consulted,
    required this.students,
    required this.aOrienter,
  });
  final List<VsCoverageRow> rows;
  final int oriented, consulted, students;

  /// Élèves que le CONSEIL DE CLASSE a déclarés « réorienté » et pour qui
  /// aucune fiche d'orientation n'existe.
  ///
  /// ⚠️ CES ENFANTS TOMBAIENT ENTRE DEUX MODULES. Le verdict `reoriente` du
  /// conseil les écarte VOLONTAIREMENT de la réinscription en lot — « la classe
  /// d'accueil se choisit dossier par dossier », dit l'écran Passage. Mais
  /// aucun dossier ne s'ouvrait nulle part : le conseil les considérait
  /// traités, l'Orientation n'en avait jamais entendu parler, et personne ne
  /// portait le reste du travail. On ne décide rien à leur place — on les
  /// nomme, là où quelqu'un peut agir.
  final int aOrienter;

  int get classesTotal => rows.length;
}

final orientationOverviewProvider = FutureProvider.autoDispose
    .family<OrientationOverview, String?>((ref, trimesterId) async {
  ref.keepAlive();
  // Périmètre de CE module, jamais celui de `classes` : le `data_scope`
  // posé sur ce module doit produire un effet.
  final classes = ref.watch(classesForModuleProvider(kSlugOrientation)).valueOrNull;
  if (classes == null || classes.isEmpty) {
    return const OrientationOverview(
        rows: [], oriented: 0, consulted: 0, students: 0, aOrienter: 0);
  }
  final ids = [for (final c in classes) c.id];
  final ph = List.filled(ids.length, '?').join(',');
  final yearId = ref.watch(activeYearIdProvider);
  if (yearId == null) {
    return const OrientationOverview(
        rows: [], oriented: 0, consulted: 0, students: 0, aOrienter: 0);
  }
  final trimClause = trimesterId != null ? 'AND o.trimester_id = ?' : '';
  final params = <Object?>[yearId, yearId, ...ids];
  if (trimesterId != null) params.add(trimesterId);

  // ⚠️ DES ÉLÈVES, PAS DES LIGNES. Le compte additionnait les lignes
  // d'orientation : un élève dont la fiche avait été enregistrée deux fois
  // comptait pour deux, et la couverture d'une classe pouvait annoncer plus
  // d'orientés que d'inscrits. Le `DISTINCT` dit ce que le KPI prétend dire.
  // L'année est explicite : `academic_year_id` est NOT NULL, écrit depuis
  // toujours, et n'était lu NULLE PART.
  final rows = await db.getAll(
    'SELECT DISTINCT ce.class_id AS cid, o.student_id AS sid, '
    '       o.parent_consulted AS pc '
    'FROM student_orientations o '
    'JOIN class_enrollments ce ON ce.student_id = o.student_id '
    "AND ce.status = 'active' AND ce.academic_year_id = ? "
    'WHERE o.academic_year_id = ? AND ce.class_id IN ($ph) $trimClause',
    params,
  );
  final oriented = <String, int>{};
  var totalOriented = 0, consulted = 0;
  for (final r in rows) {
    final cid = r['cid'] as String;
    oriented[cid] = (oriented[cid] ?? 0) + 1;
    totalOriented++;
    if (((r['pc'] as int?) ?? 0) == 1) consulted++;
  }

  final cov = [
    for (final c in classes)
      VsCoverageRow(
        classId: c.id,
        className: c.name,
        cycleCode: c.cycleCode,
        levelCode: c.levelCode,
        levelOrder: c.levelOrder ?? 999,
        total: c.studentCount ?? 0,
        ok: oriented[c.id] ?? 0,
      ),
  ]..sort((a, b) {
      final o = a.levelOrder.compareTo(b.levelOrder);
      return o != 0 ? o : a.className.compareTo(b.className);
    });

  // Le conseil a tranché « réorienté » ; reste à dire vers quoi.
  final attente = await db.getAll(
    '''
    SELECT COUNT(*) AS n FROM class_enrollments ce
     WHERE ce.class_id IN ($ph)
       AND ce.status = 'active'
       AND ce.academic_year_id = ?
       AND ce.promotion_decision = 'reoriente'
       AND NOT EXISTS (
         SELECT 1 FROM student_orientations o
          WHERE o.student_id = ce.student_id
            AND o.academic_year_id = ce.academic_year_id)
    ''',
    [...ids, yearId],
  );

  return OrientationOverview(
    rows: cov,
    oriented: totalOriented,
    consulted: consulted,
    students: cov.fold(0, (a, c) => a + c.total),
    aOrienter: (attente.firstOrNull?['n'] as int?) ?? 0,
  );
});

class OrientationRow {
  const OrientationRow({
    required this.studentId,
    required this.studentName,
    required this.matricule,
    required this.recordId,
    required this.recommendation,
    required this.targetLevel,
    required this.targetFiliere,
    required this.parentConsulted,
    required this.verdictConseil,
  });
  final String studentId, studentName;
  final String? matricule, recordId, recommendation, targetLevel, targetFiliere;
  final bool parentConsulted;

  /// Verdict du conseil de classe sur l'inscription en cours
  /// (`class_enrollments.promotion_decision`) : passe | redouble | reoriente.
  final String? verdictConseil;

  bool get oriented => recordId != null;

  /// Le conseil l'a réorienté, et rien n'a encore été décidé de sa suite.
  bool get attendUneOrientation => verdictConseil == 'reoriente' && !oriented;
}

final classOrientationProvider = StreamProvider.autoDispose
    .family<List<OrientationRow>, OrientationArgs>((ref, args) {
  final yearId = ref.watch(activeYearIdProvider);
  if (yearId == null) return Stream.value(const []);
  final trimClause =
      args.trimesterId != null ? 'AND o2.trimester_id = ?' : '';
  final params = <Object?>[yearId];
  if (args.trimesterId != null) params.add(args.trimesterId);
  return db.watch(
    '''
    SELECT s.id AS sid, s.first_name, s.last_name, s.matricule,
           o.id AS oid, o.recommendation AS reco, o.target_level AS tl,
           o.target_filiere AS tf, o.parent_consulted AS pc,
           ce.promotion_decision AS verdict
    FROM class_enrollments ce
    JOIN students s ON s.id = ce.student_id
    -- ⚠️ UNE SEULE LIGNE PAR ÉLÈVE. La jointure directe rendait autant de
    -- lignes que l'élève avait d'orientations : le même enfant apparaissait
    -- deux fois dans la liste de sa classe, avec deux fiches contradictoires,
    -- et le compteur de couverture les additionnait. La plus récente fait foi ;
    -- les précédentes restent en base, elles ne sont simplement plus la fiche
    -- courante.
    LEFT JOIN student_orientations o ON o.id = (
      SELECT o2.id FROM student_orientations o2
       WHERE o2.student_id = s.id
         AND o2.academic_year_id = ?
         $trimClause
       ORDER BY o2.updated_at DESC
       LIMIT 1)
    WHERE ce.class_id = ? AND ce.status = 'active'
    ORDER BY s.last_name, s.first_name
    ''',
    parameters: [...params, args.classId],
  ).map((rows) => [
        for (final r in rows)
          OrientationRow(
            studentId: r['sid'] as String,
            studentName: '${(r['last_name'] as String?) ?? ''} '
                    '${(r['first_name'] as String?) ?? ''}'
                .trim(),
            matricule: r['matricule'] as String?,
            recordId: r['oid'] as String?,
            recommendation: r['reco'] as String?,
            targetLevel: r['tl'] as String?,
            targetFiliere: r['tf'] as String?,
            parentConsulted: ((r['pc'] as int?) ?? 0) == 1,
            verdictConseil: r['verdict'] as String?,
          ),
      ]);
});

// ─── Mutation ────────────────────────────────────────────────────────────────
Future<void> saveOrientation({
  String? id,
  required String groupId,
  required String schoolId,
  required String academicYearId,
  required String studentId,
  String? trimesterId,
  String? recommendation,
  String? targetLevel,
  String? targetFiliere,
  required bool parentConsulted,
  required String counselorId,
}) async {
  final now = DateTime.now().toIso8601String();

  // ⚠️ [id] vient d'un instantané du flux : ouvrir deux fois la fiche, ou
  // appuyer deux fois sur « Enregistrer », arrivait deux fois avec `null` et
  // créait DEUX orientations pour le même élève et le même trimestre. Aucune
  // contrainte en base ne l'attrape — donc rien ne prévient : la liste montre
  // l'enfant deux fois, avec deux recommandations qui peuvent se contredire.
  // On relit sur la clé métier, et l'identifiant d'une fiche neuve s'en déduit
  // pour que deux postes hors ligne écrivent la même ligne.
  final vue = await db.getAll(
    trimesterId == null
        ? 'SELECT id FROM student_orientations WHERE student_id = ? '
            'AND academic_year_id = ? AND trimester_id IS NULL LIMIT 1'
        : 'SELECT id FROM student_orientations WHERE student_id = ? '
            'AND academic_year_id = ? AND trimester_id = ? LIMIT 1',
    trimesterId == null
        ? [studentId, academicYearId]
        : [studentId, academicYearId, trimesterId],
  );
  final cible = vue.isNotEmpty ? vue.first['id'] as String : id;

  if (cible != null) {
    await db.execute(
      '''
      UPDATE student_orientations SET recommendation = ?, target_level = ?,
        target_filiere = ?, parent_consulted = ?, trimester_id = ?, updated_at = ?
      WHERE id = ?
      ''',
      [recommendation, targetLevel, targetFiliere, parentConsulted ? 1 : 0,
       trimesterId, now, cible],
    );
  } else {
    await db.execute(
      '''
      INSERT INTO student_orientations (
        id, group_id, school_id, student_id, academic_year_id, trimester_id,
        recommendation, target_level, target_filiere, counselor_id,
        parent_consulted, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [idDeterministe('student_orientation',
           [studentId, academicYearId, trimesterId ?? '']),
       groupId, schoolId, studentId, academicYearId, trimesterId,
       recommendation, targetLevel, targetFiliere, counselorId,
       parentConsulted ? 1 : 0, now, now],
    );
  }
}

Future<void> deleteOrientation(String id) async {
  await db.execute('DELETE FROM student_orientations WHERE id = ?', [id]);
}

// ═══ LES CIBLES POSSIBLES, PRISES AU RÉFÉRENTIEL ═══════════════════════════
//
// `education_levels` et `education_programs` descendent tous deux sur le poste
// (schéma PowerSync). Ils sont nationaux quand `group_id IS NULL`, propres au
// groupe sinon : la liste couvre donc les cibles qu'une école ne possède pas
// elle-même — un collège qui oriente vers un lycée technique.
typedef CibleOrientation = ({String code, String nom, String? cycle});

List<CibleOrientation> _cibles(List<Map<String, dynamic>> rows) => [
      for (final r in rows)
        (
          code: (r['code'] as String?) ?? '',
          nom: (r['name'] as String?) ?? '',
          cycle: r['cycle'] as String?,
        ),
    ];

/// Niveaux cibles : tous les niveaux actifs du référentiel, par cycle.
final niveauxCiblesProvider =
    StreamProvider.autoDispose<List<CibleOrientation>>((ref) {
  return db.watch(
    '''
    SELECT el.code, el.name, ec.name AS cycle
      FROM education_levels el
      LEFT JOIN education_cycles ec ON ec.id = el.cycle_id
     WHERE COALESCE(el.is_active, 1) <> 0
     ORDER BY COALESCE(ec.order_index, 99), COALESCE(el.order_index, 99), el.name
    ''',
  ).map(_cibles);
});

/// Filières cibles : toutes les filières actives du référentiel, par cycle.
final filieresCiblesProvider =
    StreamProvider.autoDispose<List<CibleOrientation>>((ref) {
  return db.watch(
    '''
    SELECT ep.code, ep.name, ec.name AS cycle
      FROM education_programs ep
      LEFT JOIN education_cycles ec ON ec.id = ep.cycle_id
     WHERE COALESCE(ep.is_active, 1) <> 0
     ORDER BY COALESCE(ec.order_index, 99), COALESCE(ep.order_index, 99), ep.name
    ''',
  ).map(_cibles);
});

/// Le nom lisible d'un code, ou le code lui-même s'il n'est plus au
/// référentiel — une orientation ancienne ne doit pas devenir illisible parce
/// qu'une filière a été retirée depuis.
String nomDeCible(List<CibleOrientation> cibles, String? code) {
  if (code == null || code.isEmpty) return '—';
  for (final c in cibles) {
    if (c.code == code) return c.nom;
  }
  return code;
}
