import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../features/auth/providers/auth_provider.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  ESPACE ADMIN_GROUPE — Années scolaires (online / Supabase direct).
//
//  GOUVERNANCE : l'année scolaire est NATIONALE / niveau-groupe. admin_groupe
//  la crée (school_id = NULL) ; toutes les écoles l'héritent automatiquement via
//  PowerSync à leur prochaine synchro (sync progressive, offline-first préservé).
//  Chaque école « adopte » l'année en y préparant ses propres classes.
// ══════════════════════════════════════════════════════════════════════════════

const _uuid = Uuid();
String _d(DateTime d) => d.toIso8601String().substring(0, 10);

/// Une année groupe + son taux d'adoption par les écoles.
class AdminYear {
  const AdminYear({
    required this.id,
    required this.label,
    required this.startDate,
    required this.endDate,
    required this.isCurrent,
    required this.isLocked,
    required this.classes,
    required this.eleves,
    required this.schoolsAdopted,
    required this.schoolsTotal,
  });

  final String id;
  final String label;
  final DateTime startDate;
  final DateTime endDate;
  final bool isCurrent;
  final bool isLocked;
  final int classes; // classes du groupe sur cette année
  final int eleves; // inscriptions actives du groupe
  final int schoolsAdopted; // écoles ayant ≥1 classe sur cette année
  final int schoolsTotal; // écoles actives du groupe
}

/// Liste des années du groupe, avec adoption + totaux (temps réel à l'ouverture).
final adminAcademicYearsProvider =
    FutureProvider.autoDispose<List<AdminYear>>((ref) async {
  ref.keepAlive();
  final client = ref.watch(supabaseClientProvider);
  final groupId = ref.watch(authNotifierProvider).valueOrNull?.groupId;
  if (groupId == null) return [];

  final years = await client
      .from('academic_years')
      .select('id, label, start_date, end_date, is_current, is_locked')
      .eq('group_id', groupId)
      .order('start_date', ascending: false) as List;

  // Écoles actives du groupe (dénominateur d'adoption + périmètre de comptage).
  final schools = await client
      .from('schools')
      .select('id')
      .eq('group_id', groupId)
      .eq('is_active', true) as List;
  final schoolsTotal = schools.length;
  // On scope TOUT (classes/inscriptions) au réseau ACTIF pour que les KPI
  // concordent avec les ventilations (dépt/type/école) qui, elles, ne portent
  // que sur les écoles actives. Sinon des inscriptions rattachées à des écoles
  // désactivées gonflent le total sans apparaître dans le détail.
  final activeIds = {for (final s in schools) s['id'] as String};

  // Classes (année → {nb, écoles distinctes}) et inscriptions (année → nb).
  final classRows = await client
      .from('classes')
      .select('academic_year_id, school_id')
      .eq('group_id', groupId)
      .eq('is_active', true) as List;
  final enrollRows = await client
      .from('class_enrollments')
      .select('academic_year_id, school_id')
      .eq('group_id', groupId)
      .eq('status', 'active') as List;

  final classCount = <String, int>{};
  final schoolsByYear = <String, Set<String>>{};
  for (final r in classRows) {
    final y = r['academic_year_id'] as String?;
    final s = r['school_id'] as String?;
    if (y == null || s == null || !activeIds.contains(s)) continue;
    classCount[y] = (classCount[y] ?? 0) + 1;
    (schoolsByYear[y] ??= <String>{}).add(s);
  }
  final eleveCount = <String, int>{};
  for (final r in enrollRows) {
    final y = r['academic_year_id'] as String?;
    final s = r['school_id'] as String?;
    if (y == null || s == null || !activeIds.contains(s)) continue;
    eleveCount[y] = (eleveCount[y] ?? 0) + 1;
  }

  return years.map((y) {
    final id = y['id'] as String;
    return AdminYear(
      id: id,
      label: y['label'] as String,
      startDate: DateTime.parse(y['start_date'] as String),
      endDate: DateTime.parse(y['end_date'] as String),
      isCurrent: y['is_current'] == true,
      isLocked: y['is_locked'] == true,
      classes: classCount[id] ?? 0,
      eleves: eleveCount[id] ?? 0,
      schoolsAdopted: schoolsByYear[id]?.length ?? 0,
      schoolsTotal: schoolsTotal,
    );
  }).toList();
});

// ─── Calendrier d'une année : trimestres → séquences (online, group-level) ────
class AdminSequence {
  const AdminSequence({
    required this.id,
    required this.label,
    required this.number,
    required this.startDate,
    required this.endDate,
    required this.isCurrent,
  });
  final String id, label;
  final int number;
  final DateTime startDate, endDate;
  final bool isCurrent;
}

class AdminTrimester {
  const AdminTrimester({
    required this.id,
    required this.label,
    required this.number,
    required this.startDate,
    required this.endDate,
    required this.isCurrent,
    required this.sequences,
  });
  final String id, label;
  final int number;
  final DateTime startDate, endDate;
  final bool isCurrent;
  final List<AdminSequence> sequences;
}

final adminYearCalendarProvider = FutureProvider.autoDispose
    .family<List<AdminTrimester>, String>((ref, yearId) async {
  final client = ref.watch(supabaseClientProvider);
  final trims = await client
      .from('trimesters')
      .select('id, label, trimester_number, start_date, end_date, is_current')
      .eq('academic_year_id', yearId)
      .order('trimester_number', ascending: true) as List;
  final out = <AdminTrimester>[];
  for (final t in trims) {
    final seqs = await client
        .from('sequences')
        .select('id, label, sequence_number, start_date, end_date, is_current')
        .eq('trimester_id', t['id'])
        .order('sequence_number', ascending: true) as List;
    out.add(AdminTrimester(
      id: t['id'] as String,
      label: t['label'] as String,
      number: (t['trimester_number'] as num).toInt(),
      startDate: DateTime.parse(t['start_date'] as String),
      endDate: DateTime.parse(t['end_date'] as String),
      isCurrent: t['is_current'] == true,
      sequences: seqs
          .map((s) => AdminSequence(
                id: s['id'] as String,
                label: s['label'] as String,
                number: (s['sequence_number'] as num).toInt(),
                startDate: DateTime.parse(s['start_date'] as String),
                endDate: DateTime.parse(s['end_date'] as String),
                isCurrent: s['is_current'] == true,
              ))
          .toList(),
    ));
  }
  return out;
});

// ─── Mutations (online, group-level) ──────────────────────────────────────────
class AdminCalendarService {
  AdminCalendarService(this._ref);
  final Ref _ref;

  String get _groupId {
    final g = _ref.read(authNotifierProvider).valueOrNull?.groupId;
    if (g == null) throw Exception('Groupe introuvable');
    return g;
  }

  Future<void> createTrimester({
    required String yearId,
    required String label,
    required int number,
    required DateTime start,
    required DateTime end,
  }) async {
    final client = _ref.read(supabaseClientProvider);
    await client.from('trimesters').insert({
      'academic_year_id': yearId,
      'group_id': _groupId,
      'school_id': null,
      'label': label.trim(),
      'trimester_number': number,
      'start_date': _d(start),
      'end_date': _d(end),
      'is_current': false,
      'is_locked': false,
    });
  }

  Future<void> setCurrentTrimester(String id, String yearId) async {
    final client = _ref.read(supabaseClientProvider);
    await client
        .from('trimesters')
        .update({'is_current': false}).eq('academic_year_id', yearId);
    await client.from('trimesters').update({'is_current': true}).eq('id', id);
  }

  Future<void> createSequence({
    required String trimesterId,
    required String label,
    required int number,
    required DateTime start,
    required DateTime end,
  }) async {
    final client = _ref.read(supabaseClientProvider);
    await client.from('sequences').insert({
      'trimester_id': trimesterId,
      'group_id': _groupId,
      'school_id': null,
      'label': label.trim(),
      'sequence_number': number,
      'start_date': _d(start),
      'end_date': _d(end),
      'is_current': false,
    });
  }

  Future<void> setCurrentSequence(String id, String trimesterId) async {
    final client = _ref.read(supabaseClientProvider);
    await client
        .from('sequences')
        .update({'is_current': false}).eq('trimester_id', trimesterId);
    await client.from('sequences').update({'is_current': true}).eq('id', id);
  }

  Future<void> createYear({
    required String label,
    required DateTime start,
    required DateTime end,
  }) async {
    final client = _ref.read(supabaseClientProvider);
    await client.from('academic_years').insert({
      'group_id': _groupId,
      'school_id': null,
      'label': label.trim(),
      'start_date': _d(start),
      'end_date': _d(end),
      'is_current': false,
      'is_locked': false,
    });
  }

  /// Corrige une année existante (libellé + dates). Réservé au group-level
  /// (`school_id` NULL) et scopé au groupe. Ne touche PAS `is_current`/
  /// `is_locked` (gérés par leurs actions dédiées).
  Future<void> updateYear({
    required String id,
    required String label,
    required DateTime start,
    required DateTime end,
  }) async {
    final client = _ref.read(supabaseClientProvider);
    await client
        .from('academic_years')
        .update({
          'label': label.trim(),
          'start_date': _d(start),
          'end_date': _d(end),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id)
        .eq('group_id', _groupId);
  }

  /// Définit l'année courante du GROUPE (bascule progressive : chaque école
  /// suit à sa prochaine synchro).
  Future<void> setCurrentYear(String id) async {
    final client = _ref.read(supabaseClientProvider);
    await client
        .from('academic_years')
        .update({'is_current': false})
        .eq('group_id', _groupId)
        .isFilter('school_id', null);
    await client.from('academic_years').update({'is_current': true}).eq('id', id);
  }

  Future<void> setLocked(String id, bool locked) async {
    final client = _ref.read(supabaseClientProvider);
    await client.from('academic_years').update({'is_locked': locked}).eq('id', id);
  }

  /// Passage d'année : crée l'année suivante (NON courante) et reporte au
  /// besoin le squelette de calendrier (trimestres + séquences, dates décalées).
  /// Les classes restent école-level (chaque école prépare les siennes).
  Future<void> rolloverYear({
    required String sourceYearId,
    required String label,
    required DateTime start,
    required DateTime end,
    bool copyCalendar = true,
  }) async {
    final client = _ref.read(supabaseClientProvider);
    final newId = _uuid.v4();
    await client.from('academic_years').insert({
      'id': newId,
      'group_id': _groupId,
      'school_id': null,
      'label': label.trim(),
      'start_date': _d(start),
      'end_date': _d(end),
      'is_current': false,
      'is_locked': false,
    });

    if (!copyCalendar) return;

    final src = await client
        .from('academic_years')
        .select('start_date')
        .eq('id', sourceYearId)
        .maybeSingle();
    if (src == null) return;
    final srcStart = DateTime.parse(src['start_date'] as String);
    final shift = start.difference(srcStart);
    String shifted(String date) => _d(DateTime.parse(date).add(shift));

    final trims = await client
        .from('trimesters')
        .select('id, label, trimester_number, start_date, end_date')
        .eq('academic_year_id', sourceYearId)
        .order('trimester_number', ascending: true) as List;
    for (final t in trims) {
      final newTrimId = _uuid.v4();
      await client.from('trimesters').insert({
        'id': newTrimId,
        'academic_year_id': newId,
        'group_id': _groupId,
        'school_id': null,
        'label': t['label'],
        'trimester_number': t['trimester_number'],
        'start_date': shifted(t['start_date'] as String),
        'end_date': shifted(t['end_date'] as String),
        'is_current': false,
        'is_locked': false,
      });
      final seqs = await client
          .from('sequences')
          .select('label, sequence_number, start_date, end_date')
          .eq('trimester_id', t['id'])
          .order('sequence_number', ascending: true) as List;
      for (final s in seqs) {
        await client.from('sequences').insert({
          'trimester_id': newTrimId,
          'group_id': _groupId,
          'school_id': null,
          'label': s['label'],
          'sequence_number': s['sequence_number'],
          'start_date': shifted(s['start_date'] as String),
          'end_date': shifted(s['end_date'] as String),
          'is_current': false,
        });
      }
    }
  }
}

final adminCalendarServiceProvider =
    Provider<AdminCalendarService>((ref) => AdminCalendarService(ref));
