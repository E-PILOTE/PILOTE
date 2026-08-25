import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../auth/providers/auth_provider.dart';

const _uuid = Uuid();

// ════════════════════════════════════════════════════════════════════════════
//  TRAME HORAIRE (table `school_periods`) — la grille de créneaux configurable
//  de l'école (auparavant codée en dur dans timetable_provider.kStdPeriods).
//  Une ligne = une bande de la journée-type : séance, récréation ou pause
//  méridienne. Devient l'ossature FIXE des grilles d'affichage. Offline-first.
// ════════════════════════════════════════════════════════════════════════════

const kPeriodKinds = <(String, String)>[
  ('cours', 'Séance de cours'),
  ('recreation', 'Récréation'),
  ('pause_meridienne', 'Pause déjeuner'),
];

String periodKindLabel(String? k) => kPeriodKinds
    .firstWhere((e) => e.$1 == k, orElse: () => ('cours', 'Séance de cours'))
    .$2;

class SchoolPeriod {
  const SchoolPeriod({
    required this.id,
    this.cycleCode,
    required this.label,
    required this.periodIndex,
    required this.kind,
    required this.startTime,
    required this.endTime,
  });

  final String id, label, kind, startTime, endTime;
  final String? cycleCode;
  final int periodIndex;

  String get hhmmStart =>
      startTime.length >= 5 ? startTime.substring(0, 5) : startTime;
  String get hhmmEnd => endTime.length >= 5 ? endTime.substring(0, 5) : endTime;
  String get timeLabel => '$hhmmStart–$hhmmEnd';
  bool get isCourse => kind == 'cours';

  int get durationMinutes {
    int m(String t) {
      final p = t.split(':');
      if (p.length < 2) return 0;
      return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
    }

    final d = m(endTime) - m(startTime);
    return d > 0 ? d : 0;
  }
}

/// Trame active de l'école, triée chronologiquement.
final schoolPeriodsProvider =
    StreamProvider.autoDispose<List<SchoolPeriod>>((ref) {
  ref.keepAlive();
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final schoolId = profile?.schoolId;
  if (schoolId == null || schoolId.isEmpty) return Stream.value(const []);
  return db.watch(
    '''
    SELECT id, cycle_code, label, period_index, kind, start_time, end_time
    FROM   school_periods
    WHERE  school_id = ? AND COALESCE(is_active, 1) <> 0
    ORDER  BY start_time, period_index
    ''',
    parameters: [schoolId],
  ).map((rows) => [
        for (final r in rows)
          SchoolPeriod(
            id: r['id'] as String,
            cycleCode: r['cycle_code'] as String?,
            label: (r['label'] as String?) ?? '',
            periodIndex: (r['period_index'] as int?) ?? 0,
            kind: (r['kind'] as String?) ?? 'cours',
            startTime: (r['start_time'] as String?) ?? '00:00',
            endTime: (r['end_time'] as String?) ?? '00:00',
          ),
      ]);
});

// ─── Mutations (offline-first) ───────────────────────────────────────────────
Future<void> createSchoolPeriod({
  required String groupId,
  required String schoolId,
  String? cycleCode,
  required String label,
  required int periodIndex,
  required String kind,
  required String startTime, // 'HH:MM'
  required String endTime,
}) async {
  final id = _uuid.v4();
  final now = DateTime.now().toIso8601String();
  await db.execute(
    '''
    INSERT INTO school_periods (id, group_id, school_id, cycle_code, label,
                                period_index, kind, start_time, end_time,
                                is_active, created_at, updated_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?)
    ''',
    [id, groupId, schoolId, cycleCode, label.trim(), periodIndex, kind,
     '$startTime:00', '$endTime:00', now, now],
  );
}

Future<void> updateSchoolPeriod({
  required String id,
  required String label,
  required String kind,
  required String startTime,
  required String endTime,
}) async {
  final now = DateTime.now().toIso8601String();
  await db.execute(
    '''
    UPDATE school_periods SET label = ?, kind = ?, start_time = ?, end_time = ?,
                              updated_at = ?
    WHERE id = ?
    ''',
    [label.trim(), kind, '$startTime:00', '$endTime:00', now, id],
  );
}

Future<void> deleteSchoolPeriod(String id) async {
  await db.execute('DELETE FROM school_periods WHERE id = ?', [id]);
}

// ─── Trames standard PAR CYCLE (réalité Congo) ───────────────────────────────
//  La trame n'est PAS universelle : le primaire/préscolaire (journées courtes,
//  séances de 60 min, après-midi allégé) diffère du secondaire (collège/lycée/
//  formation pro : séances de 55 min, 3 le matin + 3 l'après-midi). Le seed
//  choisit le gabarit selon le cycle, et chaque trame est rattachée à SON cycle.

/// Secondaire (collège, lycée, formation pro) — séances de 55 min.
const _trameSecondaire = <(String, String, String, String)>[
  ('M1', 'cours', '07:00', '07:55'),
  ('M2', 'cours', '07:55', '08:50'),
  ('M3', 'cours', '08:50', '09:45'),
  ('Récréation', 'recreation', '09:45', '10:00'),
  ('M4', 'cours', '10:00', '10:55'),
  ('M5', 'cours', '10:55', '11:50'),
  ('M6', 'cours', '11:50', '12:45'),
  ('Pause déjeuner', 'pause_meridienne', '12:45', '14:00'),
  ('S1', 'cours', '14:00', '14:55'),
  ('S2', 'cours', '14:55', '15:50'),
  ('S3', 'cours', '15:50', '16:45'),
];

/// Primaire — séances de 60 min, matin chargé, après-midi court.
const _tramePrimaire = <(String, String, String, String)>[
  ('1', 'cours', '07:30', '08:30'),
  ('2', 'cours', '08:30', '09:30'),
  ('Récréation', 'recreation', '09:30', '09:45'),
  ('3', 'cours', '09:45', '10:45'),
  ('4', 'cours', '10:45', '11:45'),
  ('Pause déjeuner', 'pause_meridienne', '11:45', '14:30'),
  ('5', 'cours', '14:30', '15:30'),
  ('6', 'cours', '15:30', '16:30'),
];

/// Préscolaire (maternelle) — demi-journée, séances courtes de 45 min.
const _tramePrescolaire = <(String, String, String, String)>[
  ('Accueil', 'cours', '07:30', '08:15'),
  ('Activité 1', 'cours', '08:15', '09:00'),
  ('Récréation', 'recreation', '09:00', '09:30'),
  ('Activité 2', 'cours', '09:30', '10:15'),
  ('Activité 3', 'cours', '10:15', '11:00'),
  ('Sortie', 'pause_meridienne', '11:00', '11:30'),
];

/// Renvoie le gabarit de trame adapté au cycle.
List<(String, String, String, String)> standardTrameFor(String? cycleCode) =>
    switch (cycleCode) {
      'prescolaire' => _tramePrescolaire,
      'primaire' => _tramePrimaire,
      _ => _trameSecondaire, // college, lycee, formation_pro
    };

/// Installe la trame standard adaptée au CYCLE [cycleCode] (rattachée à ce cycle).
Future<void> seedStandardPeriods({
  required String groupId,
  required String schoolId,
  String? cycleCode,
}) async {
  final trame = standardTrameFor(cycleCode);
  for (var i = 0; i < trame.length; i++) {
    final (label, kind, start, end) = trame[i];
    await createSchoolPeriod(
      groupId: groupId,
      schoolId: schoolId,
      cycleCode: cycleCode,
      label: label,
      periodIndex: i,
      kind: kind,
      startTime: start,
      endTime: end,
    );
  }
}
