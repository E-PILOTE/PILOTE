import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/enregistrer_csv.dart';
import '../../../data/models/subject_model.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../services/powersync/powersync_service.dart';
import 'academic_year_context.dart';

const _uuid = Uuid();

// ─── Lecture (offline-first) ────────────────────────────────────────────────

/// Matières canoniques de l'école courante, enrichies de leur empreinte
/// d'affectation (nb de classes + niveaux où elles sont dispensées). Réactif,
/// local. Le niveau/cycle/coefficient effectif vit sur `class_subjects`.
final subjectsProvider = StreamProvider.autoDispose<List<SubjectModel>>((ref) {
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final yearId = ref.watch(activeYearIdProvider);
  if (profile?.schoolId == null || profile!.schoolId!.isEmpty) {
    return Stream.value([]);
  }
  // ⚠️ LA MATIÈRE EST CANONIQUE AU GROUPE, PAS À L'ÉCOLE.
  //
  //  Cette requête filtrait `s.school_id = ?`. Or en production, **94 des 95
  //  matières ont `school_id IS NULL`** (relevé live le 2026-09-09) : le
  //  référentiel est porté par le GROUPE, et c'est cohérent — le slug
  //  d'une matière est unique par `group_id` (`_uniqueSlug`), pas par école.
  //  L'écran n'en affichait donc qu'UNE sur 95, et son état vide invitait à
  //  recréer un catalogue qui existait déjà.
  //
  //  La conséquence dépassait l'écran : sans matière, pas d'affectation de
  //  professeur, donc `teacher_subjects` gelé, donc `scopedClassIdsProvider`
  //  vide — et le périmètre `own_classes` de TOUS les modules retombait à
  //  zéro classe pour les enseignants.
  //
  //  La forme retenue est celle qu'emploie déjà `programmesProvider`
  //  (`programmes_provider.dart:102`) : celles de l'école, PLUS celles du
  //  groupe non rattachées à une école.
  //
  //  ⚠️ La sync-rule `by_group` correspondante doit être DÉPLOYÉE au dashboard
  //  PowerSync Cloud (commit `33ecf02`) — sans elle, la ligne n'est pas sur le
  //  poste et le correctif Dart ne montre rien.
  //
  // ⚠️ « Classes » et « Niveaux » COMPTAIENT TOUTES LES ANNÉES. `class_subjects`
  // ne porte pas d'année ; `classes` en porte une. Sans le filtre, l'empreinte
  // d'une matière additionnait les classes de cette année et celles de toutes
  // les précédentes : au premier renouvellement d'année, chaque matière
  // annonçait le double de classes — y compris dans l'export CSV, colonne
  // « Classes ». Un compteur qui grossit tout seul n'est pas un compteur.
  return db
      .watch(
        '''
        SELECT s.*,
               (SELECT COUNT(*) FROM class_subjects cs
                  JOIN classes c ON c.id = cs.class_id
                  WHERE cs.subject_id = s.id
                    AND c.school_id = ? AND c.academic_year_id = ?) AS class_count,
               (SELECT GROUP_CONCAT(DISTINCT c.level_code)
                  FROM class_subjects cs
                  JOIN classes c ON c.id = cs.class_id
                  WHERE cs.subject_id = s.id
                    AND c.school_id = ? AND c.academic_year_id = ?
                    AND c.level_code IS NOT NULL) AS niveaux
        FROM   subjects s
        WHERE  (s.school_id = ?
                OR (s.school_id IS NULL AND s.group_id = ?))
          AND  COALESCE(s.is_active, 1) <> 0
        ORDER  BY s.display_order, s.name
        ''',
        parameters: [
          profile.schoolId, yearId ?? '',
          profile.schoolId, yearId ?? '',
          profile.schoolId, profile.groupId ?? '',
        ],
      )
      .map((rows) => rows.map(SubjectModel.fromMap).toList());
});

// ─── Slug (anti-collision (group_id, slug)) ─────────────────────────────────

String _slugify(String name) {
  final base = name
      .toLowerCase()
      .replaceAll(RegExp(r'[àâä]'), 'a')
      .replaceAll(RegExp(r'[éèêë]'), 'e')
      .replaceAll(RegExp(r'[îï]'), 'i')
      .replaceAll(RegExp(r'[ôö]'), 'o')
      .replaceAll(RegExp(r'[ùûü]'), 'u')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return base.isEmpty ? 'matiere' : base;
}

/// Slug unique par GROUPE (une matière = une identité canonique réutilisable).
/// Pré-validé localement → évite le rejet silencieux 23505 à la synchro.
Future<String> _uniqueSlug(String groupId, String name) async {
  final base = _slugify(name);
  final rows = await db.getAll(
      'SELECT slug FROM subjects WHERE group_id = ?', [groupId]);
  final taken = rows.map((r) => r['slug'] as String?).whereType<String>().toSet();
  if (!taken.contains(base)) return base;
  var i = 2;
  while (taken.contains('$base-$i')) {
    i++;
  }
  return '$base-$i';
}

// ─── Mutations (offline-first) ──────────────────────────────────────────────

/// Crée une matière canonique. [coefficient] = coef PAR DÉFAUT (ajustable par
/// classe ensuite via le détail de la matière).
///
/// ⚠️ `school_id` EST LAISSÉ NUL — décidé le 2026-09-10, et ce n'est pas un
/// détail d'implémentation.
///
///  Une matière appartient au GROUPE, pas à une école. Trois preuves
///  concordantes, aucune n'est une opinion :
///
///   1. la clé unique de la table est `(group_id, level_id, slug)` —
///      `school_id` ne fait **pas** partie de l'identité d'une matière ;
///   2. `_uniqueSlug` calcule déjà l'unicité **sur tout le groupe**, jamais
///      sur l'école ;
///   3. en production, **94 matières sur 95** portent `school_id IS NULL`.
///      La 95ᵉ — la seule créée par cet écran — était l'exception.
///
///  Et cette exception a coûté cher : tant que la lecture filtrait sur
///  `school_id = ?`, l'écran des matières n'en montrait qu'UNE sur 95, et le
///  catalogue vide se propageait jusqu'au périmètre `own_classes` de chaque
///  enseignant. Réparer la lecture sans réparer l'écriture aurait laissé la
///  cause en place.
///
///  Conséquence assumée : une matière créée ici est visible par **toutes les
///  écoles du groupe**. C'est la sémantique de la table, et le formulaire le
///  dit à celui qui crée.
Future<String> createSubject({
  required String groupId,
  required String name,
  required int coefficient,
}) async {
  final id   = _uuid.v4();
  final now  = DateTime.now().toIso8601String();
  final slug = await _uniqueSlug(groupId, name);
  await db.execute(
    '''
    INSERT INTO subjects (
      id, group_id, school_id, name, slug,
      coefficient, is_active, display_order, created_at, updated_at
    ) VALUES (?, ?, NULL, ?, ?, ?, 1, 0, ?, ?)
    ''',
    [id, groupId, name.trim(), slug, coefficient, now, now],
  );
  return id;
}

/// Met à jour le nom et le coefficient par défaut d'une matière.
Future<void> updateSubject({
  required String id,
  required String name,
  required int coefficient,
}) async {
  await db.execute(
    'UPDATE subjects SET name = ?, coefficient = ?, updated_at = ? WHERE id = ?',
    [name.trim(), coefficient, DateTime.now().toIso8601String(), id],
  );
}

/// Archive une matière (soft delete — préserve les notes/affectations liées).
Future<void> archiveSubject(String id) async {
  await db.execute(
    'UPDATE subjects SET is_active = 0, updated_at = ? WHERE id = ?',
    [DateTime.now().toIso8601String(), id],
  );
}

/// Compose le CSV des matières (séparateur `;`, BOM UTF-8) et demande à
/// l'agent où l'enregistrer.
///
/// Retourne le chemin écrit, ou `null` s'il a fermé la fenêtre sans choisir.
Future<String?> exportSubjectsCsv(List<SubjectModel> rows) async {
  String cell(String? v) => '"${(v ?? '').replaceAll('"', '""')}"';
  final b = StringBuffer();
  b.writeln(['Matière', 'Coefficient par défaut', 'Classes', 'Niveaux']
      .map(cell)
      .join(';'));
  for (final r in rows) {
    b.writeln([
      r.name,
      '${r.coefficient}',
      '${r.classCount}',
      r.niveaux.join(' '),
    ].map(cell).join(';'));
  }
  // ⚠️ « Enregistrer sous », et non une écriture silencieuse dans Documents :
  // sous Windows ce dossier est le plus souvent redirigé vers OneDrive.
  final ts = DateTime.now().toIso8601String().substring(0, 10);
  return enregistrerCsvSous(
    nomPropose: 'matieres_$ts.csv',
    contenu: b.toString(),
    titreFenetre: 'Enregistrer la liste des matières',
  );
}
