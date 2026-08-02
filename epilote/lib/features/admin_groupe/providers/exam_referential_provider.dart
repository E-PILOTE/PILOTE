import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  RÉFÉRENTIEL DES EXAMENS — le catalogue ET les règles qui le branchent.
//
//  ── LE TROU QUE ÇA COMBLE ──────────────────────────────────────────────────
//  Créer un examen ne suffit PAS à ce qu'une école le voie. Ce qui relie une
//  classe à un examen, c'est `exam_eligibility_rules` (migration 0044) : sans
//  règle, `classes.exam_id` reste NULL et toutes les classes s'affichent
//  « à qualifier ». Or aucun écran ne permettait d'écrire une règle — une
//  réforme METP aurait exigé du SQL en production.
//
//  ── LA CHAÎNE COMPLÈTE ─────────────────────────────────────────────────────
//    examen (national_exams)
//      → règle d'éligibilité (cycle · niveau · filière · tutelle · validité)
//      → `resolve_class_exam()` dérive `classes.exam_id` par trigger
//      → session ouverte (exam_sessions)
//      → l'école inscrit ses candidats.
//  Les trois premières marches vivent ici ; la quatrième dans
//  `exam_sessions_admin_provider.dart`.
//
//  ── ARCHITECTURE (NON NÉGOCIABLE) ──────────────────────────────────────────
//  super_admin = ONLINE, `supabase.from()` direct. JAMAIS `db.watch()`. Le
//  référentiel redescend vers les écoles par le bucket PowerSync
//  `global_catalog` (sync-rules : `national_exams WHERE is_active`).
// ════════════════════════════════════════════════════════════════════════════

class NationalExamRow {
  const NationalExamRow({
    required this.id,
    required this.code,
    required this.name,
    required this.shortName,
    required this.tutelle,
    required this.kind,
    required this.cycleCode,
    required this.minAverage,
    required this.orderIndex,
    required this.isActive,
    required this.ruleCount,
    required this.sessionCount,
  });

  final String id;
  final String code;
  final String name;
  final String shortName;
  final String tutelle;

  /// `diplome` | `concours`.
  final String kind;
  final String? cycleCode;
  final double? minAverage;
  final int? orderIndex;
  final bool isActive;
  final int ruleCount;
  final int sessionCount;

  bool get isDiplome => kind == 'diplome';

  /// Un CONCOURS ne qualifie jamais une classe : s'y présenter est un choix de
  /// l'élève, pas une propriété de la classe (`resolve_class_exam` filtre sur
  /// `kind = 'diplome'`). Il n'a donc pas besoin de règle, et ne pas le dire
  /// ferait passer le concours d'entrée en Seconde pour un examen mal câblé.
  bool get needsRules => isDiplome;

  /// Diplôme actif SANS règle = examen inerte. Il existe, il peut avoir une
  /// session ouverte, et pourtant aucune classe du pays ne s'y rattachera.
  /// C'est le défaut le plus coûteux du module, et le plus silencieux.
  bool get isInert => isActive && needsRules && ruleCount == 0;

  /// Un examen sans session ne peut recevoir aucun candidat cette année.
  bool get hasNoSession => isActive && sessionCount == 0;

  /// Ni règle, ni session, ni classe : rien ne s'y accroche, on peut effacer.
  /// (La vérification des classes se fait côté serveur dans [deleteNationalExam].)
  bool get looksDeletable => ruleCount == 0 && sessionCount == 0;
}

class ExamRuleRow {
  const ExamRuleRow({
    required this.id,
    required this.examId,
    required this.cycleCode,
    required this.levelCode,
    required this.programCode,
    required this.tutelle,
    required this.validFrom,
    required this.validTo,
    required this.groupId,
    required this.note,
    required this.isActive,
  });

  final String id;
  final String examId;
  final String cycleCode;
  final String levelCode;

  /// Filière. `null` = joker (toutes filières).
  final String? programCode;

  /// `null` = joker (toutes tutelles).
  final String? tutelle;
  final DateTime? validFrom;
  final DateTime? validTo;

  /// `null` = règle NATIONALE. Sinon, surcharge propre à un groupe scolaire.
  final String? groupId;
  final String? note;
  final bool isActive;

  bool get isNational => groupId == null;

  /// Poids de spécificité, identique à l'`ORDER BY` de `resolve_class_exam` :
  /// groupe (4) > filière (2) > tutelle (1). Affiché pour que l'administrateur
  /// voie LAQUELLE de ses règles l'emportera, sans avoir à lire le SQL.
  int get specificity =>
      (groupId != null ? 4 : 0) +
      (programCode != null ? 2 : 0) +
      (tutelle != null ? 1 : 0);

  /// En vigueur à la date du jour ? Une règle datée qui n'a pas encore pris
  /// effet — ou qui est déjà close — ne dérive rien, alors qu'elle s'affiche.
  bool isInForceOn(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    if (validFrom != null && d.isBefore(validFrom!)) return false;
    if (validTo != null && d.isAfter(validTo!)) return false;
    return isActive;
  }
}

class ExamReferentialData {
  const ExamReferentialData({required this.exams, required this.rules});

  final List<NationalExamRow> exams;

  /// Toutes les règles, indexées par examen. Chargées d'un bloc : elles sont
  /// une quinzaine, et la vue d'un examen a besoin des autres pour signaler
  /// un chevauchement.
  final Map<String, List<ExamRuleRow>> rules;

  List<ExamRuleRow> rulesOf(String examId) => rules[examId] ?? const [];

  /// Les diplômes actifs qu'aucune règle ne branche — l'alerte de l'écran.
  List<NationalExamRow> get inertExams =>
      exams.where((e) => e.isInert).toList();
}

double? _num(Object? v) => switch (v) {
      null => null,
      final num n => n.toDouble(),
      final String s => double.tryParse(s),
      _ => null,
    };

DateTime? _date(Object? v) =>
    v == null ? null : DateTime.tryParse(v as String);

// ─── Lecture ────────────────────────────────────────────────────────────────

/// Le référentiel complet : examens (actifs ET désactivés) + règles + nombre
/// de sessions.
///
/// Trois requêtes légères plutôt qu'un agrégat imbriqué PostgREST : le volume
/// est minuscule (une douzaine d'examens, une quinzaine de règles) et le
/// comptage en Dart reste lisible et testable.
final examReferentialProvider =
    FutureProvider.autoDispose<ExamReferentialData>((ref) async {
  final client = ref.watch(supabaseClientProvider);

  final examRows = await client
      .from('national_exams')
      .select('id, code, name, short_name, tutelle, kind, cycle_code, '
          'min_average, order_index, is_active')
      .order('order_index', ascending: true, nullsFirst: false)
      .order('code', ascending: true);

  final ruleRows = await client
      .from('exam_eligibility_rules')
      .select('id, exam_id, cycle_code, level_code, program_code, tutelle, '
          'valid_from, valid_to, group_id, note, is_active');

  final sessionRows =
      await client.from('exam_sessions').select('id, exam_id');

  final ruleCount = <String, int>{};
  final sessionCount = <String, int>{};
  final rules = <String, List<ExamRuleRow>>{};

  for (final r in ruleRows) {
    final examId = r['exam_id'] as String;
    ruleCount[examId] = (ruleCount[examId] ?? 0) + 1;
    (rules[examId] ??= []).add(ExamRuleRow(
      id: r['id'] as String,
      examId: examId,
      cycleCode: (r['cycle_code'] as String?) ?? '',
      levelCode: (r['level_code'] as String?) ?? '',
      programCode: r['program_code'] as String?,
      tutelle: r['tutelle'] as String?,
      validFrom: _date(r['valid_from']),
      validTo: _date(r['valid_to']),
      groupId: r['group_id'] as String?,
      note: r['note'] as String?,
      isActive: (r['is_active'] as bool?) ?? true,
    ));
  }
  for (final s in sessionRows) {
    final examId = s['exam_id'] as String?;
    if (examId != null) {
      sessionCount[examId] = (sessionCount[examId] ?? 0) + 1;
    }
  }
  // La plus spécifique d'abord : c'est l'ordre dans lequel le serveur les
  // départage, donc celui dans lequel elles doivent se lire.
  for (final list in rules.values) {
    list.sort((a, b) => b.specificity.compareTo(a.specificity));
  }

  return ExamReferentialData(
    exams: [
      for (final e in examRows)
        NationalExamRow(
          id: e['id'] as String,
          code: e['code'] as String,
          name: (e['name'] as String?) ?? e['code'] as String,
          shortName: (e['short_name'] as String?) ?? e['code'] as String,
          tutelle: (e['tutelle'] as String?) ?? 'mepsa',
          kind: (e['kind'] as String?) ?? 'diplome',
          cycleCode: e['cycle_code'] as String?,
          minAverage: _num(e['min_average']),
          orderIndex: (e['order_index'] as num?)?.toInt(),
          isActive: (e['is_active'] as bool?) ?? true,
          ruleCount: ruleCount[e['id']] ?? 0,
          sessionCount: sessionCount[e['id']] ?? 0,
        ),
    ],
    rules: rules,
  );
});

// ─── Écritures : examens ────────────────────────────────────────────────────

/// Modifier un examen existant. Le CODE reste modifiable (une réforme peut
/// renommer un diplôme — `BAC_TP` est redevenu `BAC_T` par la migration 0079),
/// mais il porte les rattachements : `kBacProInternship` et les publications
/// archivées s'y adossent. L'écran le dit avant de laisser faire.
Future<void> updateNationalExam(
  SupabaseClient client, {
  required String id,
  required String code,
  required String name,
  String? shortName,
  required String tutelle,
  required String kind,
  String? cycleCode,
  num? minAverage,
}) async {
  await client.from('national_exams').update({
    'code': code.trim().toUpperCase(),
    'name': name.trim(),
    'short_name': (shortName?.trim().isEmpty ?? true) ? null : shortName!.trim(),
    'tutelle': tutelle,
    'kind': kind,
    'cycle_code': (cycleCode?.trim().isEmpty ?? true) ? null : cycleCode!.trim(),
    'min_average': minAverage,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  }).eq('id', id);
}

/// Activer / désactiver. C'est le geste de retrait NORMAL : les sync-rules ne
/// diffusent que `is_active = true`, donc l'examen disparaît des écoles à la
/// prochaine synchro, sans rien détruire de l'historique (les sessions et les
/// résultats déjà proclamés restent rattachés).
Future<void> setNationalExamActive(
  SupabaseClient client,
  String id, {
  required bool active,
}) =>
    client.from('national_exams').update({
      'is_active': active,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);

/// Supprimer un examen — réservé à la coquille vide (faute de frappe le jour
/// même). Une session ou une classe qui s'y rattache le rend indestructible :
/// on désactive à la place. La FK `exam_eligibility_rules.exam_id` est
/// `ON DELETE CASCADE`, donc une règle orpheline ne bloque pas, mais on la
/// compte quand même pour ne jamais effacer un paramétrage sans le dire.
Future<void> deleteNationalExam(SupabaseClient client, String id) async {
  final sessions =
      await client.from('exam_sessions').select('id').eq('exam_id', id).limit(1);
  if (sessions.isNotEmpty) {
    throw Exception(
        'Examen non supprimable : une session lui est rattachée. Désactivez-le.');
  }
  // ⚠️ Ce contrôle ne voit que les classes VISIBLES de l'appelant : un
  // administrateur de groupe ne voit pas le parc des autres. Il reste utile
  // (il donne un message clair dans le cas courant) mais ce n'est pas lui qui
  // garantit l'intégrité — c'est la clé étrangère `classes.exam_id`, sans
  // ON DELETE, qui refuse la suppression côté serveur. D'où le rattrapage.
  final classes = await client
      .from('classes')
      .select('id')
      .or('exam_id.eq.$id,exam_override_id.eq.$id')
      .limit(1);
  if (classes.isNotEmpty) {
    throw Exception(
        'Examen non supprimable : des classes y sont rattachées. Désactivez-le.');
  }
  try {
    await client.from('national_exams').delete().eq('id', id);
  } catch (e) {
    final msg = '$e';
    if (msg.contains('foreign key') || msg.contains('violates')) {
      throw Exception('Examen non supprimable : des données y sont rattachées '
          '(classes, candidatures ou résultats). Désactivez-le.');
    }
    rethrow;
  }
}

// ─── Écritures : règles d'éligibilité ───────────────────────────────────────

/// Créer ou modifier une règle. `id == null` → création.
///
/// Aucune règle n'est écrite « au passage » : c'est l'appelant qui déclenche
/// ensuite [recomputeClassExams] et qui montre à l'administrateur combien de
/// classes ont changé d'examen. Une règle dont on ne voit pas l'effet est une
/// règle qu'on croit fausse.
Future<void> upsertExamRule(
  SupabaseClient client, {
  String? id,
  required String examId,
  required String cycleCode,
  required String levelCode,
  String? programCode,
  String? tutelle,
  DateTime? validFrom,
  DateTime? validTo,
  String? groupId,
  String? note,
  bool isActive = true,
}) async {
  final payload = <String, dynamic>{
    'exam_id': examId,
    'cycle_code': cycleCode.trim(),
    'level_code': levelCode.trim(),
    'program_code':
        (programCode?.trim().isEmpty ?? true) ? null : programCode!.trim(),
    'tutelle': tutelle,
    'valid_from': validFrom?.toIso8601String().split('T').first,
    'valid_to': validTo?.toIso8601String().split('T').first,
    'group_id': groupId,
    'note': (note?.trim().isEmpty ?? true) ? null : note!.trim(),
    'is_active': isActive,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };

  if (id == null) {
    await client.from('exam_eligibility_rules').insert(payload);
  } else {
    await client.from('exam_eligibility_rules').update(payload).eq('id', id);
  }
}

/// Supprimer une règle. Rien ne se perd d'irremplaçable — `classes.exam_id`
/// est DÉRIVÉ, il se recalcule. Mais les classes concernées retomberont
/// « à qualifier », donc l'appelant recalcule et l'annonce.
Future<void> deleteExamRule(SupabaseClient client, String id) =>
    client.from('exam_eligibility_rules').delete().eq('id', id);

/// Recalcule `classes.exam_id` sur TOUT le parc et renvoie le nombre de
/// classes dont l'examen a changé.
///
/// ⚠️ Indispensable après toute écriture de règle : le trigger
/// `classes_derive_exam` ne se déclenche qu'à l'écriture d'une CLASSE. Une
/// règle ajoutée aujourd'hui ne toucherait donc aucune classe existante — le
/// paramétrage paraîtrait sans effet, et on le croirait cassé.
Future<int> recomputeClassExams(SupabaseClient client) async {
  final res = await client.rpc<dynamic>('recompute_class_exams');
  return (res as num?)?.toInt() ?? 0;
}
