import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../auth/providers/auth_provider.dart';
import '../../../services/powersync/powersync_service.dart';
import 'academic_year_context.dart';

const _uuid = Uuid();

// ════════════════════════════════════════════════════════════════════════════
//  PROGRAMMES PÉDAGOGIQUES (table `school_programs`) — syllabus d'une matière à
//  un niveau (optionnellement par trimestre) : titre + contenu, officiel ou
//  personnalisé. 100% offline. Réutilise la matière CANONIQUE + la structure.
// ════════════════════════════════════════════════════════════════════════════

class ProgrammeRow {
  const ProgrammeRow({
    required this.id,
    required this.subjectId,
    required this.subjectName,
    required this.levelId,
    required this.levelCode,
    required this.levelName,
    required this.levelOrder,
    required this.cycleCode,
    required this.cycleName,
    required this.trimesterId,
    required this.trimesterLabel,
    required this.trimesterNumber,
    required this.title,
    required this.content,
    required this.isOfficial,
    required this.isShared,
    required this.createdAt,
  });

  final String id;
  final String subjectId;
  final String subjectName;
  final String levelId;
  final String? levelCode;
  final String? levelName;
  final int levelOrder;
  final String? cycleCode;
  final String? cycleName;
  final String? trimesterId;
  final String? trimesterLabel;
  final int? trimesterNumber;
  final String title;
  final String? content;
  final bool isOfficial;
  final bool isShared; // school_id NULL = curriculum partagé (groupe), lecture seule
  final DateTime? createdAt;

  String get levelLabel => (levelCode?.isNotEmpty ?? false)
      ? levelCode!
      : (levelName ?? '—');
  String get trimesterLabelOrAll =>
      trimesterNumber != null ? 'Trimestre $trimesterNumber' : 'Toute l\'année';
  bool get hasContent => (content ?? '').trim().isNotEmpty;
  String get preview {
    final c = (content ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
    return c.length <= 110 ? c : '${c.substring(0, 110)}…';
  }
}

DateTime? _d(Object? v) =>
    (v is String && v.isNotEmpty) ? DateTime.tryParse(v) : null;

/// Programmes de l'école (+ programmes officiels partagés du groupe), année active
/// ou pérennes (academic_year_id NULL). Réactif, local.
final programmesProvider =
    StreamProvider.autoDispose<List<ProgrammeRow>>((ref) {
  ref.keepAlive();
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final schoolId = profile?.schoolId;
  final groupId = profile?.groupId;
  final yearId = ref.watch(activeYearIdProvider);
  if (schoolId == null || schoolId.isEmpty || groupId == null) {
    return Stream.value(const []);
  }
  return db
      .watch(
        '''
        SELECT sp.*,
               s.name          AS subject_name,
               sl.code         AS level_code,
               sl.name         AS level_name,
               sl.order_index  AS level_order,
               ec.code         AS cycle_code,
               ec.name         AS cycle_name,
               t.label         AS trimester_label,
               t.trimester_number AS trimester_number
        FROM   school_programs sp
        JOIN   subjects s     ON s.id  = sp.subject_id
        JOIN   school_levels sl ON sl.id = sp.level_id
        LEFT JOIN education_cycles ec ON ec.id = sl.cycle_id
        LEFT JOIN trimesters t ON t.id = sp.trimester_id
        WHERE  (sp.school_id = ? OR (sp.school_id IS NULL AND sp.group_id = ?))
          AND  (sp.academic_year_id = ? OR sp.academic_year_id IS NULL)
        ORDER  BY sl.order_index, s.name, sp.title
        ''',
        parameters: [schoolId, groupId, yearId],
      )
      .map((rows) => [
            for (final r in rows)
              ProgrammeRow(
                id: r['id'] as String,
                subjectId: r['subject_id'] as String,
                subjectName: r['subject_name'] as String? ?? '—',
                levelId: r['level_id'] as String,
                levelCode: r['level_code'] as String?,
                levelName: r['level_name'] as String?,
                levelOrder: (r['level_order'] as num?)?.toInt() ?? 999,
                cycleCode: r['cycle_code'] as String?,
                cycleName: r['cycle_name'] as String?,
                trimesterId: r['trimester_id'] as String?,
                trimesterLabel: r['trimester_label'] as String?,
                trimesterNumber: (r['trimester_number'] as num?)?.toInt(),
                title: r['title'] as String? ?? '',
                content: r['content'] as String?,
                isOfficial: r['is_official'] == 1 || r['is_official'] == true,
                isShared: r['school_id'] == null,
                createdAt: _d(r['created_at']),
              ),
          ]);
});

// ─── Options de trimestre (année active) pour le formulaire ──────────────────
class TrimesterOption {
  const TrimesterOption(this.id, this.label, this.number);
  final String id;
  final String label;
  final int number;
}

final trimesterOptionsProvider =
    StreamProvider.autoDispose<List<TrimesterOption>>((ref) {
  final yearId = ref.watch(activeYearIdProvider);
  if (yearId == null) return Stream.value(const []);
  return db.watch(
    'SELECT id, label, trimester_number FROM trimesters '
    'WHERE academic_year_id = ? ORDER BY trimester_number',
    parameters: [yearId],
  ).map((rows) => [
        for (final r in rows)
          TrimesterOption(
            r['id'] as String,
            (r['label'] as String?)?.trim().isNotEmpty ?? false
                ? (r['label'] as String).trim()
                : 'Trimestre ${r['trimester_number']}',
            (r['trimester_number'] as num?)?.toInt() ?? 0,
          ),
      ]);
});

// ─── Agrégations (KPI / répartition) ─────────────────────────────────────────
class ProgLevelCount {
  const ProgLevelCount(this.code, this.cycleCode, this.order, this.total);
  final String code;
  final String? cycleCode;
  final int order, total;
}

class ProgrammeStats {
  const ProgrammeStats({
    required this.total,
    required this.official,
    required this.custom,
    required this.subjectsCovered,
    required this.levelsCovered,
    required this.byLevel,
  });
  final int total, official, custom, subjectsCovered, levelsCovered;
  final List<ProgLevelCount> byLevel;
}

final programmeStatsProvider = Provider.autoDispose<ProgrammeStats>((ref) {
  final rows = ref.watch(programmesProvider).valueOrNull ?? const [];
  final subjects = <String>{};
  final levels = <String>{};
  final levelMap = <String, List<int>>{}; // code → [total, order]
  final levelCycle = <String, String?>{};
  var official = 0;
  for (final r in rows) {
    subjects.add(r.subjectId);
    levels.add(r.levelId);
    if (r.isOfficial) official++;
    final lc = r.levelCode ?? r.levelName ?? '—';
    final acc = levelMap.putIfAbsent(lc, () => [0, r.levelOrder]);
    acc[0]++;
    levelCycle[lc] = r.cycleCode;
  }
  final byLevel = levelMap.entries
      .map((e) => ProgLevelCount(
          e.key, levelCycle[e.key], e.value[1], e.value[0]))
      .toList()
    ..sort((a, b) => a.order.compareTo(b.order));
  return ProgrammeStats(
    total: rows.length,
    official: official,
    custom: rows.length - official,
    subjectsCovered: subjects.length,
    levelsCovered: levels.length,
    byLevel: byLevel,
  );
});

// ─── Mutations (offline-first) ──────────────────────────────────────────────

Future<String> createProgramme({
  required String groupId,
  required String schoolId,
  required String levelId,
  required String subjectId,
  String? academicYearId,
  String? trimesterId,
  required String title,
  String? content,
  required bool isOfficial,
  String? createdBy,
}) async {
  final id = _uuid.v4();
  final now = DateTime.now().toIso8601String();
  await db.execute(
    '''
    INSERT INTO school_programs (
      id, group_id, school_id, level_id, subject_id, academic_year_id,
      trimester_id, title, content, is_official, created_by, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''',
    [id, groupId, schoolId, levelId, subjectId, academicYearId, trimesterId,
     title.trim(), content?.trim(), isOfficial ? 1 : 0, createdBy, now, now],
  );
  return id;
}

Future<void> updateProgramme({
  required String id,
  required String levelId,
  required String subjectId,
  String? trimesterId,
  required String title,
  String? content,
  required bool isOfficial,
}) async {
  await db.execute(
    '''
    UPDATE school_programs
    SET level_id = ?, subject_id = ?, trimester_id = ?, title = ?,
        content = ?, is_official = ?, updated_at = ?
    WHERE id = ?
    ''',
    [levelId, subjectId, trimesterId, title.trim(), content?.trim(),
     isOfficial ? 1 : 0, DateTime.now().toIso8601String(), id],
  );
}

Future<void> deleteProgramme(String id) async {
  await db.execute('DELETE FROM school_programs WHERE id = ?', [id]);
}

/// Export CSV (séparateur `;`, BOM UTF-8). Retourne le chemin.
Future<String> exportProgrammesCsv(List<ProgrammeRow> rows) async {
  String cell(String? v) => '"${(v ?? '').replaceAll('"', '""')}"';
  final b = StringBuffer();
  b.writeln(['Titre', 'Matière', 'Niveau', 'Trimestre', 'Type', 'Contenu']
      .map(cell)
      .join(';'));
  for (final r in rows) {
    b.writeln([
      r.title,
      r.subjectName,
      r.levelLabel,
      r.trimesterLabelOrAll,
      r.isOfficial ? 'Officiel' : 'Personnalisé',
      (r.content ?? '').replaceAll('\n', ' '),
    ].map(cell).join(';'));
  }
  final dir = await getApplicationDocumentsDirectory();
  final ts = DateTime.now().toIso8601String().substring(0, 10);
  final file = File('${dir.path}/programmes_$ts.csv');
  await file.writeAsString('﻿${b.toString()}');
  return file.path;
}
