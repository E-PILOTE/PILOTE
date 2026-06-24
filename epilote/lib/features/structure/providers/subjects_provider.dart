import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/subject_model.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../services/powersync/powersync_service.dart';

const _uuid = Uuid();

// ─── Lecture (offline-first) ────────────────────────────────────────────────

/// Matières actives de l'école courante (avec leur niveau) — réactif, local.
final subjectsProvider = StreamProvider.autoDispose<List<SubjectModel>>((ref) {
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  if (profile?.schoolId == null || profile!.schoolId!.isEmpty) {
    return Stream.value([]);
  }
  return db
      .watch(
        '''
        SELECT s.*,
               sl.code        AS level_code,
               sl.name        AS level_name,
               sl.order_index AS level_order,
               ec.code        AS cycle_code
        FROM   subjects s
        LEFT JOIN school_levels sl ON sl.id = s.level_id
        LEFT JOIN education_cycles ec ON ec.id = sl.cycle_id
        WHERE  s.school_id = ? AND s.is_active = 1
        ORDER  BY COALESCE(sl.order_index, -1), s.display_order, s.name
        ''',
        parameters: [profile.schoolId],
      )
      .map((rows) => rows.map(SubjectModel.fromMap).toList());
});

// ─── Slug (anti-collision (group_id, level_id, slug)) ───────────────────────

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

/// Génère un slug unique pour (group_id, level_id) en pré-validant localement
/// → évite le rejet silencieux 23505 à la synchro. Une même matière peut donc
/// exister sur plusieurs niveaux (slug distinct par niveau).
Future<String> _uniqueSlug(String groupId, String? levelId, String name) async {
  final base = _slugify(name);
  final rows = levelId == null
      ? await db.getAll(
          'SELECT slug FROM subjects WHERE group_id = ? AND level_id IS NULL',
          [groupId])
      : await db.getAll(
          'SELECT slug FROM subjects WHERE group_id = ? AND level_id = ?',
          [groupId, levelId]);
  final taken = rows.map((r) => r['slug'] as String?).whereType<String>().toSet();
  if (!taken.contains(base)) return base;
  var i = 2;
  while (taken.contains('$base-$i')) {
    i++;
  }
  return '$base-$i';
}

// ─── Mutations (offline-first) ──────────────────────────────────────────────

/// Crée une matière (portée par un niveau, ou tronc commun si [levelId] NULL).
Future<String> createSubject({
  required String groupId,
  required String schoolId,
  required String name,
  required int coefficient,
  String? levelId,
}) async {
  final id   = _uuid.v4();
  final now  = DateTime.now().toIso8601String();
  final slug = await _uniqueSlug(groupId, levelId, name);
  await db.execute(
    '''
    INSERT INTO subjects (
      id, group_id, school_id, level_id, name, slug,
      coefficient, is_active, display_order, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, 1, 0, ?, ?)
    ''',
    [id, groupId, schoolId, levelId, name.trim(), slug, coefficient, now, now],
  );
  return id;
}

/// Met à jour le nom, le coefficient et le niveau d'une matière.
Future<void> updateSubject({
  required String id,
  required String name,
  required int coefficient,
  String? levelId,
  bool clearLevel = false,
}) async {
  final now = DateTime.now().toIso8601String();
  if (clearLevel) {
    await db.execute(
      'UPDATE subjects SET name = ?, coefficient = ?, level_id = NULL, updated_at = ? WHERE id = ?',
      [name.trim(), coefficient, now, id],
    );
  } else if (levelId != null) {
    await db.execute(
      'UPDATE subjects SET name = ?, coefficient = ?, level_id = ?, updated_at = ? WHERE id = ?',
      [name.trim(), coefficient, levelId, now, id],
    );
  } else {
    await db.execute(
      'UPDATE subjects SET name = ?, coefficient = ?, updated_at = ? WHERE id = ?',
      [name.trim(), coefficient, now, id],
    );
  }
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
  b.writeln(['Matière', 'Niveau', 'Coefficient'].map(cell).join(';'));
  for (final r in rows) {
    b.writeln([r.name, r.levelLabel, '${r.coefficient}'].map(cell).join(';'));
  }
  final dir = await getApplicationDocumentsDirectory();
  final ts = DateTime.now().toIso8601String().substring(0, 10);
  final file = File('${dir.path}/matieres_$ts.csv');
  await file.writeAsString('﻿${b.toString()}');
  return file.path;
}
