import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../../auth/providers/auth_provider.dart';
import '../../../core/utils/erreur_metier.dart';

// ════════════════════════════════════════════════════════════════════════════
//  SESSIONS D'EXAMEN — administration du CALENDRIER NATIONAL.
//
//  ── LE TROU QUE CET ÉCRAN COMBLE ───────────────────────────────────────────
//  Les 12 sessions 2025-2026 ont été SEMÉES PAR UNE MIGRATION (0050). Aucune
//  interface ne permettait d'en créer. Concrètement : à l'ouverture de l'année
//  2026-2027, personne n'aurait pu ouvrir une session sans qu'un développeur
//  écrive du SQL. Une bombe à retardement silencieuse.
//
//  ── POURQUOI SUPER_ADMIN, ET PAS L'ÉCOLE ───────────────────────────────────
//  Le calendrier vient d'un ARRÊTÉ MINISTÉRIEL. Une école n'invente pas la date
//  du BET. La RLS le dit déjà : `exam_sessions_write = is_super_admin()` — cet
//  écran ne fait qu'offrir le geste que la base autorisait déjà.
//
//  Ce que nous saisissons ici est une COPIE DE RÉFÉRENCE de l'arrêté, pas la
//  vérité : la DEC reste la source. Le jour où l'API existe (spec-api-dec.md),
//  ce calendrier se tirera de chez eux et cet écran deviendra un repli.
//
//  ── ARCHITECTURE (NON NÉGOCIABLE) ──────────────────────────────────────────
//  super_admin = ONLINE, `supabase.from()` direct. JAMAIS `db.watch()` : ce
//  rôle n'est pas synchronisé par PowerSync. Les sessions redescendent ensuite
//  vers les écoles par le bucket `global_catalog`.
// ════════════════════════════════════════════════════════════════════════════

class ExamRef {
  const ExamRef({
    required this.id,
    required this.code,
    required this.name,
    required this.shortName,
    required this.tutelle,
    required this.kind,
  });

  final String id;
  final String code;
  final String name;
  final String shortName;
  final String? tutelle;

  /// `diplome` | `concours` — sert au libellé du sélecteur.
  final String? kind;
}

class ExamSessionAdminRow {
  const ExamSessionAdminRow({
    required this.id,
    required this.examId,
    required this.examCode,
    required this.examShortName,
    required this.tutelle,
    required this.yearLabel,
    required this.status,
    required this.registrationOpensAt,
    required this.registrationClosesAt,
    required this.writtenFrom,
    required this.writtenTo,
    required this.practicalFrom,
    required this.practicalTo,
    required this.maxAge,
    required this.candidateCount,
    required this.notes,
  });

  final String id;
  final String examId;
  final String examCode;
  final String examShortName;
  final String? tutelle;

  /// Texte libre (« 2025-2026 ») et NON une FK vers `academic_years` : une
  /// session est nationale, alors que les années scolaires sont propres à
  /// chaque tenant. Les lier aurait rendu le calendrier national dépendant du
  /// paramétrage d'une école.
  final String? yearLabel;
  final String status;
  final DateTime? registrationOpensAt;
  final DateTime? registrationClosesAt;
  final DateTime? writtenFrom;
  final DateTime? writtenTo;
  final DateTime? practicalFrom;
  final DateTime? practicalTo;
  final int? maxAge;

  /// Nombre de candidatures déjà rattachées — un garde-fou à la suppression.
  final int candidateCount;
  final String? notes;

  bool get isOpen => status == 'open';

  /// Une session sans date d'épreuve est incomplète : l'arrêté n'était pas
  /// publié à la saisie. À compléter, pas une erreur.
  bool get missingDates => writtenFrom == null;

  /// Supprimer une session emporterait ses candidatures — donc le travail des
  /// écoles. On ne le permet que sur une session vierge.
  bool get isDeletable => candidateCount == 0;
}

DateTime? _d(Object? v) => v == null ? null : DateTime.tryParse(v as String);

/// Le catalogue des examens nationaux, pour le sélecteur du formulaire.
///
/// Trié par `order_index` (ordre PÉDAGOGIQUE : CEPE → BEPC → BET → … → Bac),
/// pas par `code` (qui donnait un ordre alphabétique dénué de sens et faisait
/// croire que « des examens manquaient »).
final examRefsProvider = FutureProvider.autoDispose<List<ExamRef>>((ref) async {
  final rows = await ref
      .watch(supabaseClientProvider)
      .from('national_exams')
      .select('id, code, name, short_name, tutelle, kind, order_index')
      .eq('is_active', true)
      .order('order_index', ascending: true, nullsFirst: false)
      .order('code', ascending: true);

  return [
    for (final r in rows)
      ExamRef(
        id: r['id'] as String,
        code: r['code'] as String,
        name: (r['name'] as String?) ?? r['code'] as String,
        shortName: (r['short_name'] as String?) ?? r['code'] as String,
        tutelle: r['tutelle'] as String?,
        kind: r['kind'] as String?,
      ),
  ];
});

final examSessionsAdminProvider =
    FutureProvider.autoDispose<List<ExamSessionAdminRow>>((ref) async {
  final rows = await ref
      .watch(supabaseClientProvider)
      .from('exam_sessions')
      .select('id, exam_id, year_label, status, registration_opens_at, '
          'registration_closes_at, written_from, written_to, practical_from, '
          'practical_to, max_age, notes, '
          'national_exams!inner(code, short_name, tutelle), '
          'exam_candidates(count)')
      .order('year_label', ascending: false);

  return [
    for (final r in rows)
      ExamSessionAdminRow(
        id: r['id'] as String,
        examId: r['exam_id'] as String,
        examCode: r['national_exams']['code'] as String,
        examShortName: (r['national_exams']['short_name'] as String?) ??
            r['national_exams']['code'] as String,
        tutelle: r['national_exams']['tutelle'] as String?,
        yearLabel: r['year_label'] as String?,
        status: (r['status'] as String?) ?? 'draft',
        registrationOpensAt: _d(r['registration_opens_at']),
        registrationClosesAt: _d(r['registration_closes_at']),
        writtenFrom: _d(r['written_from']),
        writtenTo: _d(r['written_to']),
        practicalFrom: _d(r['practical_from']),
        practicalTo: _d(r['practical_to']),
        maxAge: (r['max_age'] as num?)?.toInt(),
        candidateCount: _count(r['exam_candidates']),
        notes: r['notes'] as String?,
      ),
  ];
});

/// PostgREST rend `exam_candidates(count)` comme `[{count: n}]` — ou vide.
int _count(Object? v) {
  if (v is List && v.isNotEmpty) {
    final first = v.first;
    if (first is Map) return (first['count'] as num?)?.toInt() ?? 0;
  }
  return 0;
}

String? _day(DateTime? d) => d == null
    ? null
    : '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';

/// Crée ou met à jour une session. `id == null` -> création.
Future<void> upsertExamSession(
  SupabaseClient client, {
  String? id,
  required String examId,
  required String yearLabel,
  required String status,
  DateTime? registrationOpensAt,
  DateTime? registrationClosesAt,
  DateTime? writtenFrom,
  DateTime? writtenTo,
  DateTime? practicalFrom,
  DateTime? practicalTo,
  int? maxAge,
  String? notes,
}) async {
  final payload = {
    'exam_id': examId,
    'year_label': yearLabel.trim(),
    'status': status,
    'registration_opens_at': _day(registrationOpensAt),
    'registration_closes_at': _day(registrationClosesAt),
    'written_from': _day(writtenFrom),
    'written_to': _day(writtenTo),
    'practical_from': _day(practicalFrom),
    'practical_to': _day(practicalTo),
    'max_age': maxAge,
    'notes': notes?.trim(),
  };

  if (id == null) {
    await client.from('exam_sessions').insert(payload);
  } else {
    await client.from('exam_sessions').update(payload).eq('id', id);
  }
}

/// Crée un examen national depuis l'écran (au lieu d'une migration SQL).
///
/// ── LE TROU QUE ÇA COMBLE ────────────────────────────────────────────────
/// Les 12 examens ont été semés par une migration. Une réforme qui crée un
/// nouveau diplôme (le METP en publie régulièrement) n'aurait pu être saisie
/// sans qu'un développeur écrive du SQL — exactement la bombe des sessions.
///
/// `order_index` est calculé (max + 1) : l'examen se range à la fin de la liste
/// pédagogique sans qu'on ait à l'inventer. La RLS `is_super_admin()` gouverne
/// déjà l'écriture ; ce n'est que le geste que la base autorisait.
Future<void> createNationalExam(
  SupabaseClient client, {
  required String code,
  required String name,
  String? shortName,
  required String tutelle,
  required String kind,
  String? cycleCode,
  num? minAverage,
}) async {
  final maxRow = await client
      .from('national_exams')
      .select('order_index')
      .order('order_index', ascending: false, nullsFirst: false)
      .limit(1);
  final nextIndex = maxRow.isEmpty
      ? 1
      : ((maxRow.first['order_index'] as num?)?.toInt() ?? 0) + 1;

  await client.from('national_exams').insert({
    'code': code.trim().toUpperCase(),
    'name': name.trim(),
    'short_name': (shortName?.trim().isEmpty ?? true) ? null : shortName!.trim(),
    'tutelle': tutelle,
    'kind': kind,
    'cycle_code': (cycleCode?.trim().isEmpty ?? true) ? null : cycleCode!.trim(),
    'min_average': minAverage,
    'order_index': nextIndex,
    'is_active': true,
  });
}

/// Ne jamais supprimer une session qui porte des candidatures : ce serait
/// détruire le travail des écoles. L'appelant vérifie `isDeletable` ; ce garde-
/// fou-ci est la ceinture en plus des bretelles.
Future<void> deleteExamSession(SupabaseClient client, String id) async {
  final rows = await client
      .from('exam_candidates')
      .select('id')
      .eq('session_id', id)
      .limit(1);
  if (rows.isNotEmpty) {
    throw const ErreurMetier(
        'Session non supprimable : des candidatures y sont rattachées.');
  }
  await client.from('exam_sessions').delete().eq('id', id);
}
