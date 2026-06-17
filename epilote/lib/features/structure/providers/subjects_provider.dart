import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/subject_model.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../services/powersync/powersync_service.dart';

const _uuid = Uuid();

// ─── Lecture (offline-first) ────────────────────────────────────────────────

/// Matières actives de l'école courante — réactif, 100% local.
final subjectsProvider = StreamProvider.autoDispose<List<SubjectModel>>((ref) {
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  if (profile?.schoolId == null || profile!.schoolId!.isEmpty) {
    return Stream.value([]);
  }
  return db
      .watch(
        '''
        SELECT * FROM subjects
        WHERE  school_id = ? AND is_active = 1
        ORDER  BY display_order, name
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

/// Génère un slug unique pour (group_id, level_id NULL) en pré-validant
/// localement → évite le rejet silencieux 23505 à la synchro.
Future<String> _uniqueSlug(String groupId, String name) async {
  final base = _slugify(name);
  final rows = await db.getAll(
    'SELECT slug FROM subjects WHERE group_id = ? AND level_id IS NULL',
    [groupId],
  );
  final taken = rows.map((r) => r['slug'] as String?).whereType<String>().toSet();
  if (!taken.contains(base)) return base;
  var i = 2;
  while (taken.contains('$base-$i')) {
    i++;
  }
  return '$base-$i';
}

// ─── Mutations (offline-first) ──────────────────────────────────────────────

/// Crée une matière dans SQLite local — PowerSync synchronise vers Supabase.
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
      id, group_id, school_id, level_id, name, slug,
      coefficient, is_active, display_order, created_at, updated_at
    ) VALUES (?, ?, ?, NULL, ?, ?, ?, 1, 0, ?, ?)
    ''',
    [id, groupId, schoolId, name.trim(), slug, coefficient, now, now],
  );
  return id;
}

/// Met à jour le nom et le coefficient d'une matière.
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
