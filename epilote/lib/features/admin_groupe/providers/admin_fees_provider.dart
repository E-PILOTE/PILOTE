import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../auth/providers/auth_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  FRAIS & TARIFS DU GROUPE — le seul endroit où un montant se crée.
//
//  Un barème n'est pas une donnée de l'école : dans le public il vient d'un
//  arrêté, dans le privé du siège. L'école reçoit et applique (décision D2,
//  migration 0096). Ici, l'écriture est autorisée par la RLS
//  (`fee_structures_insert/update/delete` = `is_admin_groupe()`).
//
//  ⚠️ admin_groupe travaille EN LIGNE, sur Supabase direct. Jamais `db.watch()`.
//  C'est la règle centrale du projet.
// ════════════════════════════════════════════════════════════════════════════

const _uuid = Uuid();

/// Portée d'un barème : tout le réseau, ou une école désignée.
/// Dans les deux cas c'est le GROUPE qui écrit — `school_id` dit « s'applique
/// à », jamais « créé par ».
class AdminFee {
  const AdminFee({
    required this.id,
    required this.name,
    required this.feeType,
    required this.amount,
    required this.schoolId,
    required this.schoolName,
    required this.levelId,
    required this.levelName,
    required this.dueDay,
    required this.sourceReference,
  });

  final String id, name, feeType;
  final int amount;
  final String? schoolId, schoolName, levelId, levelName, sourceReference;
  final int? dueDay;

  bool get estReseau => schoolId == null;
}

/// Les barèmes du groupe pour une année donnée, toutes portées confondues.
final adminFeesProvider = FutureProvider.autoDispose
    .family<List<AdminFee>, String>((ref, yearId) async {
  final client = ref.watch(supabaseClientProvider);
  final groupId = ref.watch(authNotifierProvider).valueOrNull?.groupId;
  if (groupId == null || yearId.isEmpty) return const [];

  final rows = await client
      .from('fee_structures')
      .select('id, name, fee_type, amount_xaf, school_id, applies_to_level_id, '
          'due_day_of_month, source_reference, '
          'schools(name), school_levels(name)')
      .eq('group_id', groupId)
      .eq('academic_year_id', yearId)
      .eq('is_active', true)
      .order('fee_type') as List;

  return [
    for (final r in rows)
      AdminFee(
        id: r['id'] as String,
        name: (r['name'] as String?) ?? '—',
        feeType: (r['fee_type'] as String?) ?? 'autre',
        amount: (r['amount_xaf'] as num?)?.round() ?? 0,
        schoolId: r['school_id'] as String?,
        schoolName: (r['schools'] as Map?)?['name'] as String?,
        levelId: r['applies_to_level_id'] as String?,
        levelName: (r['school_levels'] as Map?)?['name'] as String?,
        dueDay: (r['due_day_of_month'] as num?)?.round(),
        sourceReference: r['source_reference'] as String?,
      ),
  ];
});

typedef OptionRef = ({String id, String name});

/// Les écoles du groupe — choix de portée du barème.
final adminFeeSchoolsProvider =
    FutureProvider.autoDispose<List<OptionRef>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final groupId = ref.watch(authNotifierProvider).valueOrNull?.groupId;
  if (groupId == null) return const [];
  final rows = await client
      .from('schools')
      .select('id, name')
      .eq('group_id', groupId)
      .eq('is_active', true)
      .order('name') as List;
  return [
    for (final r in rows)
      (id: r['id'] as String, name: (r['name'] as String?) ?? '—'),
  ];
});

/// Les niveaux D'UNE ÉCOLE — ciblage optionnel d'un barème d'établissement.
///
/// ⚠️ **Un tarif de portée réseau ne peut pas cibler un niveau**, et c'est une
/// contrainte de fond, pas un oubli : `fee_structures.applies_to_level_id`
/// pointe sur `school_levels`, dont chaque ligne appartient à UNE école — 175
/// lignes pour 13 noms de niveau sur 37 écoles. Un tarif réseau visant « la
/// 6e de l'école A » ne matcherait jamais les élèves de l'école B, et le
/// ministère croirait avoir tarifé tout le pays.
///
/// Un tarif réseau par niveau demande le référentiel partagé
/// (`education_levels`) — c'est un travail à part, reporté au lot 2b. En
/// attendant, un tarif réseau s'applique à tous les niveaux, et le ciblage
/// n'est proposé que sur un barème d'établissement.
/// Cf. `[[premiere-heure-etablissement]]` : joindre `school_levels` sur le
/// seul `group_id` avait déjà fait remonter 42 niveaux au lieu de 6.
final adminFeeLevelsProvider = FutureProvider.autoDispose
    .family<List<OptionRef>, String>((ref, schoolId) async {
  final client = ref.watch(supabaseClientProvider);
  if (schoolId.isEmpty) return const [];
  final rows = await client
      .from('school_levels')
      .select('id, name, order_index')
      .eq('school_id', schoolId)
      .eq('is_active', true)
      .order('order_index') as List;
  return [
    for (final r in rows)
      (id: r['id'] as String, name: ((r['name'] as String?) ?? '—').trim()),
  ];
});

/// Crée ou met à jour un barème. `schoolId` nul = tarif de tout le réseau.
Future<void> saveAdminFee(
  SupabaseClient client, {
  String? id,
  required String groupId,
  required String academicYearId,
  required String name,
  required String feeType,
  required int amount,
  String? schoolId,
  String? levelId,
  int? dueDay,
  required String sourceReference,
}) async {
  final now = DateTime.now().toIso8601String();
  final payload = <String, dynamic>{
    'group_id': groupId,
    'school_id': schoolId,
    'academic_year_id': academicYearId,
    'name': name,
    'fee_type': feeType,
    'amount_xaf': amount,
    'applies_to_level_id': levelId,
    'due_day_of_month': dueDay,
    'source_reference': sourceReference,
    'is_active': true,
    'updated_at': now,
  };
  if (id != null) {
    await client.from('fee_structures').update(payload).eq('id', id);
  } else {
    await client.from('fee_structures').insert({
      ...payload,
      'id': _uuid.v4(),
      'created_at': now,
    });
  }
}

/// Retrait LOGIQUE. Un tarif qui a servi à des encaissements ne disparaît pas
/// de l'histoire : il cesse simplement de s'appliquer. Le supprimer vraiment
/// laisserait des reçus se référant à un barème introuvable.
Future<void> deactivateAdminFee(SupabaseClient client, String id) =>
    client.from('fee_structures').update({
      'is_active': false,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
