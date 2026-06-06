import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/academic_year_model.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../services/powersync/powersync_service.dart';

// ─── Année académique courante ────────────────────────────────────────────────

/// Année académique active pour l'école / le groupe de l'utilisateur.
/// Lit depuis SQLite PowerSync (offline-first).
final currentAcademicYearProvider =
    StreamProvider.autoDispose<AcademicYearModel?>((ref) {
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  if (profile == null) return Stream.value(null);

  if (profile.schoolId != null && profile.schoolId!.isNotEmpty) {
    return db
        .watch(
          'SELECT * FROM academic_years WHERE school_id = ? AND is_current = 1 LIMIT 1',
          parameters: [profile.schoolId],
        )
        .map((rows) =>
            rows.isEmpty ? null : AcademicYearModel.fromMap(rows.first));
  }

  if (profile.groupId != null && profile.groupId!.isNotEmpty) {
    return db
        .watch(
          'SELECT * FROM academic_years WHERE group_id = ? AND is_current = 1 LIMIT 1',
          parameters: [profile.groupId],
        )
        .map((rows) =>
            rows.isEmpty ? null : AcademicYearModel.fromMap(rows.first));
  }

  return Stream.value(null);
});

/// Toutes les années académiques pour l'école / le groupe.
final academicYearsProvider =
    StreamProvider.autoDispose<List<AcademicYearModel>>((ref) {
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  if (profile == null) return Stream.value([]);

  if (profile.schoolId != null && profile.schoolId!.isNotEmpty) {
    return db
        .watch(
          'SELECT * FROM academic_years WHERE school_id = ? ORDER BY start_date DESC',
          parameters: [profile.schoolId],
        )
        .map((rows) => rows.map(AcademicYearModel.fromMap).toList());
  }

  if (profile.groupId != null && profile.groupId!.isNotEmpty) {
    return db
        .watch(
          'SELECT * FROM academic_years WHERE group_id = ? ORDER BY start_date DESC',
          parameters: [profile.groupId],
        )
        .map((rows) => rows.map(AcademicYearModel.fromMap).toList());
  }

  return Stream.value([]);
});

// ─── Trimestres ───────────────────────────────────────────────────────────────

/// Trimestres d'une année académique donnée.
final trimestersProvider = StreamProvider.autoDispose
    .family<List<TrimesterModel>, String>((ref, academicYearId) {
  return db
      .watch(
        'SELECT * FROM trimesters WHERE academic_year_id = ? ORDER BY trimester_number',
        parameters: [academicYearId],
      )
      .map((rows) => rows.map(TrimesterModel.fromMap).toList());
});

/// Trimestre courant pour une année académique donnée.
final currentTrimesterProvider = StreamProvider.autoDispose
    .family<TrimesterModel?, String>((ref, academicYearId) {
  return db
      .watch(
        'SELECT * FROM trimesters WHERE academic_year_id = ? AND is_current = 1 LIMIT 1',
        parameters: [academicYearId],
      )
      .map((rows) =>
          rows.isEmpty ? null : TrimesterModel.fromMap(rows.first));
});

// ─── Séquences ────────────────────────────────────────────────────────────────

/// Séquences d'un trimestre donné.
final sequencesProvider = StreamProvider.autoDispose
    .family<List<SequenceModel>, String>((ref, trimesterId) {
  return db
      .watch(
        'SELECT * FROM sequences WHERE trimester_id = ? ORDER BY sequence_number',
        parameters: [trimesterId],
      )
      .map((rows) => rows.map(SequenceModel.fromMap).toList());
});

/// Séquence courante pour un trimestre donné.
final currentSequenceProvider = StreamProvider.autoDispose
    .family<SequenceModel?, String>((ref, trimesterId) {
  return db
      .watch(
        'SELECT * FROM sequences WHERE trimester_id = ? AND is_current = 1 LIMIT 1',
        parameters: [trimesterId],
      )
      .map((rows) =>
          rows.isEmpty ? null : SequenceModel.fromMap(rows.first));
});

// ─── École courante ──────────────────────────────────────────────────────────

/// École de l'utilisateur connecté (depuis SQLite PowerSync).
final currentSchoolProvider =
    StreamProvider.autoDispose<Map<String, dynamic>?>((ref) {
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  if (profile?.schoolId == null || profile!.schoolId!.isEmpty) {
    return Stream.value(null);
  }
  return db
      .watch(
        'SELECT * FROM schools WHERE id = ? LIMIT 1',
        parameters: [profile.schoolId],
      )
      .map((rows) => rows.isEmpty ? null : rows.first);
});
