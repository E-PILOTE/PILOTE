import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/subject_model.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../services/powersync/powersync_service.dart';

const _uuid = Uuid();

// ─── Lecture (offline-first) ────────────────────────────────────────────────

/// Matières canoniques de l'école courante, enrichies de leur empreinte
/// d'affectation (nb de classes + niveaux où elles sont dispensées). Réactif,
/// local. Le niveau/cycle/coefficient effectif vit sur `class_subjects`.
final subjectsProvider = StreamProvider.autoDispose<List<SubjectModel>>((ref) {
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  if (profile?.schoolId == null || profile!.schoolId!.isEmpty) {
    return Stream.value([]);
  }
  return db
      .watch(
        '''
        SELECT s.*,
               (SELECT COUNT(*) FROM class_subjects cs
                  WHERE cs.subject_id = s.id) AS class_count,
               (SELECT GROUP_CONCAT(DISTINCT c.level_code)
                  FROM class_subjects cs
                  JOIN classes c ON c.id = cs.class_id
                  WHERE cs.subject_id = s.id
                    AND c.level_code IS NOT NULL) AS niveaux
        FROM   subjects s
        WHERE  s.school_id = ? AND s.is_active = 1
        ORDER  BY s.display_order, s.name
        ''',
        parameters: [profile.schoolId],
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
Future<String> createSubject({
  required String groupId,
  required String schoolId,
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
    ) VALUES (?, ?, ?, ?, ?, ?, 1, 0, ?, ?)
    ''',
    [id, groupId, schoolId, name.trim(), slug, coefficient, now, now],
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

/// Export CSV des matières (séparateur `;`, BOM UTF-8). Retourne le chemin.
Future<String> exportSubjectsCsv(List<SubjectModel> rows) async {
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
  final dir = await getApplicationDocumentsDirectory();
  final ts = DateTime.now().toIso8601String().substring(0, 10);
  final file = File('${dir.path}/matieres_$ts.csv');
  await file.writeAsString('﻿${b.toString()}');
  return file.path;
}
