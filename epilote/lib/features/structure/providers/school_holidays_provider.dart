import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../auth/providers/auth_provider.dart';
import 'academic_year_context.dart';

// `kHolidayKinds` / `holidayKindLabel` vivent dans
// `core/utils/jours_non_ouvres.dart` et sont ré-exportés ici : l'espace groupe
// en a besoin sans dépendre de PowerSync, et les écrans école les importaient
// déjà depuis ce fichier.
export '../../../core/utils/jours_non_ouvres.dart'
    show kHolidayKinds, holidayKindLabel;

const _uuid = Uuid();

// ════════════════════════════════════════════════════════════════════════════
//  CALENDRIER SCOLAIRE (table `school_holidays`) — jours NON OUVRÉS de l'année :
//  vacances scolaires et jours fériés. Socle des vues calendaires (mois /
//  trimestre / semestre / annuel) de l'emploi du temps : on projette la trame
//  hebdomadaire sur le calendrier réel en EXCLUANT ces jours. Offline-first.
// ════════════════════════════════════════════════════════════════════════════

class SchoolHoliday {
  const SchoolHoliday({
    required this.id,
    required this.label,
    required this.kind,
    required this.startDate,
    required this.endDate,
    this.isNational = false,
  });

  final String id, label, kind;
  final DateTime startDate, endDate;

  /// Fixé au niveau du GROUPE (`school_id IS NULL`) et hérité par toutes les
  /// écoles : l'établissement le voit mais ne le modifie pas.
  final bool isNational;

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

/// Jours non ouvrés d'une année DONNÉE, triés par date.
///
/// Paramétré plutôt que branché sur la lentille globale : la page Calendrier
/// scolaire laisse inspecter une année sans basculer l'application entière
/// dessus. Elle a donc besoin des vacances de l'année REGARDÉE, qui n'est pas
/// forcément l'année affichée.
final schoolHolidaysOfYearProvider = StreamProvider.autoDispose
    .family<List<SchoolHoliday>, String>((ref, yearId) {
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final schoolId = profile?.schoolId;
  if (schoolId == null || schoolId.isEmpty || yearId.isEmpty) {
    return Stream.value(const []);
  }
  // HÉRITAGE : `school_id IS NULL` = calendrier NATIONAL fixé par le groupe.
  // Il descend sur le poste par le bucket `by_group` des sync-rules, au même
  // titre que l'année scolaire et les trimestres. Sans le `OR school_id IS
  // NULL`, l'école téléchargerait la Toussaint sans jamais l'afficher : les
  // vues calendaires compteraient le 25 décembre comme un jour de classe.
  return db
      .watch(
        '''
        SELECT id, label, kind, start_date, end_date, school_id
        FROM   school_holidays
        WHERE  academic_year_id = ?
          AND  (school_id = ? OR school_id IS NULL)
        ORDER  BY start_date
        ''',
        parameters: [yearId, schoolId],
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
                  isNational: (r['school_id'] as String?) == null,
                ),
          ]);
});

/// Jours non ouvrés de l'école pour l'année AFFICHÉE (lentille globale).
/// Socle des vues calendaires de l'emploi du temps.
final schoolHolidaysProvider =
    Provider.autoDispose<AsyncValue<List<SchoolHoliday>>>((ref) {
  ref.keepAlive();
  final yearId = ref.watch(activeYearIdProvider);
  if (yearId == null) return const AsyncValue.data(<SchoolHoliday>[]);
  return ref.watch(schoolHolidaysOfYearProvider(yearId));
});

/// Jours de classe réellement travaillés entre [from] et [to] : les jours de
/// semaine (lundi→vendredi) desquels on retranche vacances et fériés.
///
/// C'est le seul chiffre qu'un chef d'établissement regarde vraiment sur un
/// calendrier : « combien de jours de classe me reste-t-il pour boucler le
/// programme ». Le comptage est fait ici, pas dans le widget, pour être
/// testable sans Flutter.
int countSchoolDays(DateTime from, DateTime to, List<SchoolHoliday> holidays) {
  var day = DateTime(from.year, from.month, from.day);
  final end = DateTime(to.year, to.month, to.day);
  var n = 0;
  while (!day.isAfter(end)) {
    final weekday = day.weekday;
    if (weekday != DateTime.saturday &&
        weekday != DateTime.sunday &&
        !isNonWorkingDay(day, holidays)) {
      n++;
    }
    day = day.add(const Duration(days: 1));
  }
  return n;
}

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

// ─── Fériés légaux : l'école n'en installe plus ───────────────────────────────
//  `seedCongoHolidays()` vivait ici et recalculait les fériés congolais sur le
//  poste. Supprimée : la règle vit désormais UNIQUEMENT en base
//  (`national_holidays_congo()`), l'espace groupe la sème une fois pour le
//  réseau, et l'école la reçoit par le bucket `by_group`.
//
//  Conséquence pour l'IHM : les lignes `school_id IS NULL` sont EN LECTURE
//  SEULE côté école — la politique `school_holidays_tenant` exige
//  `school_id = auth_school_id()` en écriture. Proposer un bouton « supprimer »
//  dessus ferait réussir la suppression locale puis réapparaître la ligne à la
//  synchro suivante. Voir `SchoolHoliday.isNational`.
