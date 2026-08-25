import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE VOCABULAIRE D'UNE RÈGLE — lu en base, jamais figé dans le code.
//
//  Une règle d'éligibilité se saisit sur (cycle_code, level_code,
//  filiere_code). Ces codes ne vivent dans AUCUNE constante du dépôt : ils
//  sont dénormalisés sur `classes` depuis le référentiel de CHAQUE groupe
//  (`school_levels`, et non `education_levels`). Une liste écrite en dur dans
//  le Dart aurait donc produit des règles qui ne matchent rien — le pire des
//  échecs, puisqu'il est silencieux.
//
//  On rend donc les codes RÉELLEMENT portés par les classes, avec leur
//  effectif : l'administrateur choisit dans ce qui existe, et voit combien de
//  classes se cachent derrière chaque option.
// ════════════════════════════════════════════════════════════════════════════

class VocabEntry {
  const VocabEntry({
    required this.code,
    required this.label,
    required this.classCount,
  });

  final String code;
  final String label;
  final int classCount;

  /// « Tle — Terminale (128 classes) »
  String get display =>
      label == code ? '$code ($classCount)' : '$code — $label ($classCount)';
}

class ExamRuleVocabulary {
  const ExamRuleVocabulary({
    required this.cycles,
    required this.levels,
    required this.filieres,
  });

  final List<VocabEntry> cycles;
  final List<VocabEntry> levels;
  final List<VocabEntry> filieres;

  static const empty =
      ExamRuleVocabulary(cycles: [], levels: [], filieres: []);
}

/// ⚠️ Dépend de la RPC `exam_rule_vocabulary()` (migration 0070). Tant qu'elle
/// n'est pas déployée, on renvoie un vocabulaire VIDE plutôt qu'une erreur :
/// le formulaire bascule alors en saisie libre et reste utilisable. Un écran
/// mort parce qu'une migration traîne serait pire que des champs sans liste.
final examRuleVocabularyProvider =
    FutureProvider.autoDispose<ExamRuleVocabulary>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final List<dynamic> rows;
  try {
    rows = await client.rpc<List<dynamic>>('exam_rule_vocabulary');
  } catch (_) {
    return ExamRuleVocabulary.empty;
  }

  final cycles = <VocabEntry>[];
  final levels = <VocabEntry>[];
  final filieres = <VocabEntry>[];

  for (final raw in rows) {
    final r = raw as Map<String, dynamic>;
    final entry = VocabEntry(
      code: (r['code'] as String?) ?? '',
      label: (r['label'] as String?) ?? (r['code'] as String? ?? ''),
      classCount: (r['class_count'] as num?)?.toInt() ?? 0,
    );
    if (entry.code.isEmpty) continue;
    switch (r['kind'] as String?) {
      case 'cycle':
        cycles.add(entry);
      case 'level':
        levels.add(entry);
      case 'filiere':
        filieres.add(entry);
    }
  }

  // Le plus employé d'abord : c'est presque toujours celui qu'on cherche.
  for (final l in [cycles, levels, filieres]) {
    l.sort((a, b) => b.classCount.compareTo(a.classCount));
  }
  return ExamRuleVocabulary(
      cycles: cycles, levels: levels, filieres: filieres);
});

/// Combien de classes une règle candidate concernerait-elle, à blanc.
///
/// Ne dit PAS que la règle l'emportera — une règle plus spécifique peut la
/// battre (filière > tutelle > joker). Elle dit ce qu'elle CONCERNE, ce qui
/// suffit à repérer la règle qui ne matche rien, ou celle qui ratisse trop.
/// `null` = la RPC n'est pas déployée : on n'affiche simplement pas l'aperçu.
Future<int?> examRuleMatchCount(
  SupabaseClient client, {
  required String cycleCode,
  required String levelCode,
  String? programCode,
  String? tutelle,
  String? groupId,
}) async {
  try {
    final res = await client.rpc<dynamic>('exam_rule_match_count', params: {
      'p_cycle': cycleCode,
      'p_level': levelCode,
      'p_program': programCode,
      'p_tutelle': tutelle,
      'p_group': groupId,
    });
    return (res as num?)?.toInt();
  } catch (_) {
    return null;
  }
}

/// Les groupes scolaires, pour la portée d'une règle (`null` = nationale).
/// Une surcharge de groupe est le geste rare : une école pilote, une réforme
/// appliquée d'abord à un réseau. Elle prime sur la règle nationale.
final ruleScopeGroupsProvider =
    FutureProvider.autoDispose<List<(String, String)>>((ref) async {
  final rows = await ref
      .watch(supabaseClientProvider)
      .from('school_groups')
      .select('id, name')
      .order('name');
  return [
    for (final r in rows)
      (r['id'] as String, (r['name'] as String?) ?? 'Groupe sans nom'),
  ];
});
