import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../auth/providers/auth_provider.dart';
import 'academic_year_context.dart';

const _uuid = Uuid();

// ════════════════════════════════════════════════════════════════════════════
//  CALENDRIER SCOLAIRE (table `school_holidays`) — jours NON OUVRÉS de l'année :
//  vacances scolaires et jours fériés. Socle des vues calendaires (mois /
//  trimestre / semestre / annuel) de l'emploi du temps : on projette la trame
//  hebdomadaire sur le calendrier réel en EXCLUANT ces jours. Offline-first.
// ════════════════════════════════════════════════════════════════════════════

const kHolidayKinds = <(String, String)>[
  ('ferie', 'Jour férié'),
  ('vacances', 'Vacances scolaires'),
];

String holidayKindLabel(String? k) => kHolidayKinds
    .firstWhere((e) => e.$1 == k, orElse: () => ('ferie', 'Jour férié'))
    .$2;

class SchoolHoliday {
  const SchoolHoliday({
    required this.id,
    required this.label,
    required this.kind,
    required this.startDate,
    required this.endDate,
  });

  final String id, label, kind;
  final DateTime startDate, endDate;

  bool get isFerie => kind == 'ferie';
  bool get isSingleDay => _ymd(startDate) == _ymd(endDate);
  int get dayCount => endDate.difference(startDate).inDays + 1;

  /// La date [d] (jour calendaire) tombe-t-elle dans cette plage non ouvrée ?
  bool covers(DateTime d) {
    final k = DateTime(d.year, d.month, d.day);
    final a = DateTime(startDate.year, startDate.month, startDate.day);
    final b = DateTime(endDate.year, endDate.month, endDate.day);
    return !k.isBefore(a) && !k.isAfter(b);
  }

  String get rangeLabel => isSingleDay
      ? _frDate(startDate)
      : '${_frDate(startDate)} → ${_frDate(endDate)}';
}

String _ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

const _frMonths = [
  '', 'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août',
  'sept.', 'oct.', 'nov.', 'déc.'
];
String _frDate(DateTime d) => '${d.day} ${_frMonths[d.month]} ${d.year}';

DateTime? _d(Object? v) =>
    (v is String && v.isNotEmpty) ? DateTime.tryParse(v) : null;

/// Jours non ouvrés de l'école (année active), triés par date.
final schoolHolidaysProvider =
    StreamProvider.autoDispose<List<SchoolHoliday>>((ref) {
  ref.keepAlive();
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final schoolId = profile?.schoolId;
  final yearId = ref.watch(activeYearIdProvider);
  if (schoolId == null || schoolId.isEmpty) return Stream.value(const []);
  return db
      .watch(
        '''
        SELECT id, label, kind, start_date, end_date
        FROM   school_holidays
        WHERE  school_id = ? AND academic_year_id = ?
        ORDER  BY start_date
        ''',
        parameters: [schoolId, yearId ?? ''],
      )
      .map((rows) => [
            for (final r in rows)
              if (_d(r['start_date']) != null && _d(r['end_date']) != null)
                SchoolHoliday(
                  id: r['id'] as String,
                  label: (r['label'] as String?) ?? '',
                  kind: (r['kind'] as String?) ?? 'ferie',
                  startDate: _d(r['start_date'])!,
                  endDate: _d(r['end_date'])!,
                ),
          ]);
});

/// Une date [d] est-elle non ouvrée (vacances ou férié) ?
bool isNonWorkingDay(DateTime d, List<SchoolHoliday> holidays) =>
    holidays.any((h) => h.covers(d));

/// Le jour non ouvré couvrant [d], s'il existe (pour annoter une vue calendaire).
SchoolHoliday? holidayOn(DateTime d, List<SchoolHoliday> holidays) {
  for (final h in holidays) {
    if (h.covers(d)) return h;
  }
  return null;
}

// ─── Mutations (offline-first) ───────────────────────────────────────────────
Future<void> createHoliday({
  required String groupId,
  required String schoolId,
  required String academicYearId,
  required String label,
  required String kind,
  required DateTime startDate,
  required DateTime endDate,
}) async {
  final id = _uuid.v4();
  final now = DateTime.now().toIso8601String();
  await db.execute(
    '''
    INSERT INTO school_holidays (id, group_id, school_id, academic_year_id,
                                 label, kind, start_date, end_date,
                                 created_at, updated_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''',
    [id, groupId, schoolId, academicYearId, label.trim(), kind,
     _ymd(startDate), _ymd(endDate), now, now],
  );
}

Future<void> updateHoliday({
  required String id,
  required String label,
  required String kind,
  required DateTime startDate,
  required DateTime endDate,
}) async {
  final now = DateTime.now().toIso8601String();
  await db.execute(
    '''
    UPDATE school_holidays
    SET label = ?, kind = ?, start_date = ?, end_date = ?, updated_at = ?
    WHERE id = ?
    ''',
    [label.trim(), kind, _ymd(startDate), _ymd(endDate), now, id],
  );
}

Future<void> deleteHoliday(String id) async {
  await db.execute('DELETE FROM school_holidays WHERE id = ?', [id]);
}

// ─── Calendrier-type Congo (jours fériés NATIONAUX à date fixe) ───────────────
//  Réalité République du Congo. On ne sème QUE les fériés à date fixe (les
//  fériés mobiles liés à Pâques — Lundi de Pâques, Ascension, Pentecôte — se
//  calculeraient par l'algorithme de Pâques ; laissés à la saisie manuelle pour
//  ne pas induire d'erreur). Les vacances scolaires varient d'une année à
//  l'autre → ajoutées à la main par la direction.
const _congoFixedFerie = <(int, int, String)>[
  (1, 1, "Jour de l'An"),
  (5, 1, 'Fête du Travail'),
  (8, 15, "Fête de l'Indépendance"),
  (11, 1, 'Toussaint'),
  (11, 28, 'Jour de la République'),
  (12, 25, 'Noël'),
];

/// Installe les fériés nationaux congolais à date fixe qui TOMBENT dans l'année
/// scolaire [yearStart, yearEnd] (gère la bascule d'année civile : un même
/// (mois, jour) est testé sur chaque année civile couverte). N'insère pas de
/// doublon (même date + même libellé déjà présent).
Future<int> seedCongoHolidays({
  required String groupId,
  required String schoolId,
  required String academicYearId,
  required DateTime yearStart,
  required DateTime yearEnd,
  required List<SchoolHoliday> existing,
}) async {
  var added = 0;
  for (var y = yearStart.year; y <= yearEnd.year; y++) {
    for (final (m, day, label) in _congoFixedFerie) {
      final date = DateTime(y, m, day);
      if (date.isBefore(DateTime(yearStart.year, yearStart.month, yearStart.day)) ||
          date.isAfter(DateTime(yearEnd.year, yearEnd.month, yearEnd.day))) {
        continue;
      }
      final dup = existing.any((h) =>
          h.isFerie && h.isSingleDay && h.covers(date) && h.label == label);
      if (dup) continue;
      await createHoliday(
        groupId: groupId,
        schoolId: schoolId,
        academicYearId: academicYearId,
        label: label,
        kind: 'ferie',
        startDate: date,
        endDate: date,
      );
      added++;
    }
  }
  return added;
}
