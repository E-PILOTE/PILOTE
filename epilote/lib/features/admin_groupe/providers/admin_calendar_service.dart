import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/utils/erreur_metier.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  ESPACE ADMIN_GROUPE — Mutations du calendrier national.
//
//  TOUT CE QUI DOIT ÊTRE ATOMIQUE PASSE PAR UNE RPC. La version précédente
//  enchaînait plusieurs requêtes REST pour une seule opération métier :
//
//    • bascule de rentrée = 2 UPDATE. Entre les deux, le groupe n'avait AUCUNE
//      année courante. Une coupure réseau — ou le `statement_timeout = 8s` du
//      rôle `authenticator` — figeait cet état, et `is_current` pilote bulletins,
//      inscriptions, notes et emplois du temps ;
//    • passage d'année = 1 + N + M insertions. Une coupure laissait une année à
//      moitié bâtie, que l'unicité (academic_year_id, trimester_number)
//      empêchait ensuite de rejouer.
//
//  Une fonction PL/pgSQL s'exécute dans une transaction unique : soit tout
//  passe, soit rien. Les RPC vérifient aussi le périmètre (admin de CE groupe)
//  et écrivent dans `audit_logs` — la bascule de rentrée d'un réseau national
//  ne peut pas rester une action anonyme.
//
//  Le CRUD simple (créer/corriger/supprimer un trimestre) reste en REST direct :
//  une seule écriture, donc déjà atomique. Les triggers en base valident les
//  bornes, les chevauchements et le gel des années archivées.
// ══════════════════════════════════════════════════════════════════════════════

String _d(DateTime d) => d.toIso8601String().substring(0, 10);

/// Ce qu'a produit un passage d'année — de quoi le confirmer précisément.
class RolloverOutcome {
  const RolloverOutcome({
    required this.yearId,
    required this.label,
    required this.trimesters,
    required this.sequences,
    required this.vacances,
    required this.feries,
  });
  final String yearId;
  final String label;
  final int trimesters;
  final int sequences;

  /// Congés scolaires REPORTÉS depuis l'année source, dates décalées.
  final int vacances;

  /// Fériés légaux RECALCULÉS pour la nouvelle année — pas reportés. Pâques est
  /// mobile : décaler la date de l'an passé la placerait à côté, et l'Ascension
  /// comme la Pentecôte, qui en dérivent, suivraient l'erreur.
  final int feries;

  String get resume {
    final parts = <String>[
      if (trimesters > 0) '$trimesters trimestre${trimesters > 1 ? 's' : ''}',
      if (sequences > 0) '$sequences séquence${sequences > 1 ? 's' : ''}',
      if (vacances > 0) '$vacances période${vacances > 1 ? 's' : ''} de vacances',
    ];
    // L'accord suit le NOMBRE D'ÉLÉMENTS, pas le nombre de catégories : « 3
    // trimestres reporté » sur une seule catégorie était faux.
    final total = trimesters + sequences + vacances;
    final base = parts.isEmpty
        ? 'Année « $label » créée.'
        : 'Année « $label » créée, ${parts.join(', ')} '
            '${total > 1 ? 'reportés' : 'reporté'}.';
    if (feries == 0) return base;
    return '$base $feries jour${feries > 1 ? 's' : ''} '
        'férié${feries > 1 ? 's' : ''} calculé${feries > 1 ? 's' : ''} '
        'pour la nouvelle année.';
  }
}

class AdminCalendarService {
  AdminCalendarService(this._ref);
  final Ref _ref;

  String get _groupId {
    final g = _ref.read(authNotifierProvider).valueOrNull?.groupId;
    if (g == null) throw const ErreurMetier('Groupe introuvable');
    return g;
  }

  // ── Années ────────────────────────────────────────────────────────────────

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

  /// Corrige une année existante (libellé + dates). Ne touche PAS
  /// `is_current`/`is_locked`, gérés par leurs actions dédiées.
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
        .eq('group_id', _groupId)
        .isFilter('school_id', null);
  }

  /// Bascule de la rentrée du groupe — atomique et tracée.
  Future<void> setCurrentYear(String id) async {
    final client = _ref.read(supabaseClientProvider);
    await client.rpc('set_current_academic_year', params: {'p_year_id': id});
  }

  /// Diffuse l'année aux écoles du groupe et notifie leurs chefs
  /// d'établissement. Renvoie le nombre de destinataires touchés.
  ///
  /// Tant qu'elle n'est pas publiée, l'année n'existe que dans l'espace groupe :
  /// la règle `by_group` des sync-rules filtre sur `published_at IS NOT NULL`.
  Future<int> publishYear(String id) async {
    final client = _ref.read(supabaseClientProvider);
    final res =
        await client.rpc('publish_academic_year', params: {'p_year_id': id});
    return (res as num?)?.toInt() ?? 0;
  }

  /// Archive / déverrouille. Refuse d'archiver l'année en cours.
  Future<void> setLocked(String id, bool locked) async {
    final client = _ref.read(supabaseClientProvider);
    await client.rpc('set_academic_year_locked',
        params: {'p_year_id': id, 'p_locked': locked});
  }

  /// Passage d'année : année + trimestres + séquences en UNE transaction.
  Future<RolloverOutcome> rolloverYear({
    required String sourceYearId,
    required String label,
    required DateTime start,
    required DateTime end,
    bool copyCalendar = true,
  }) async {
    final client = _ref.read(supabaseClientProvider);
    final res = await client.rpc('rollover_academic_year', params: {
      'p_source_year_id': sourceYearId,
      'p_label': label.trim(),
      'p_start': _d(start),
      'p_end': _d(end),
      'p_copy_calendar': copyCalendar,
    });
    final m = Map<String, dynamic>.from(res as Map);
    return RolloverOutcome(
      yearId: m['year_id'] as String,
      label: m['label'] as String,
      trimesters: (m['trimesters'] as num?)?.toInt() ?? 0,
      sequences: (m['sequences'] as num?)?.toInt() ?? 0,
      vacances: (m['vacances'] as num?)?.toInt() ?? 0,
      feries: (m['feries'] as num?)?.toInt() ?? 0,
    );
  }

  // ── Trimestres ────────────────────────────────────────────────────────────

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

  Future<void> updateTrimester({
    required String id,
    required String label,
    required int number,
    required DateTime start,
    required DateTime end,
  }) async {
    final client = _ref.read(supabaseClientProvider);
    await client
        .from('trimesters')
        .update({
          'label': label.trim(),
          'trimester_number': number,
          'start_date': _d(start),
          'end_date': _d(end),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id)
        .eq('group_id', _groupId);
  }

  /// Les séquences suivent par `ON DELETE CASCADE`.
  Future<void> deleteTrimester(String id) async {
    final client = _ref.read(supabaseClientProvider);
    await client.from('trimesters').delete().eq('id', id).eq('group_id', _groupId);
  }

  Future<void> setCurrentTrimester(String id) async {
    final client = _ref.read(supabaseClientProvider);
    await client.rpc('set_current_trimester', params: {'p_trimester_id': id});
  }

  // ── Séquences ─────────────────────────────────────────────────────────────

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

  Future<void> updateSequence({
    required String id,
    required String label,
    required int number,
    required DateTime start,
    required DateTime end,
  }) async {
    final client = _ref.read(supabaseClientProvider);
    await client
        .from('sequences')
        .update({
          'label': label.trim(),
          'sequence_number': number,
          'start_date': _d(start),
          'end_date': _d(end),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id)
        .eq('group_id', _groupId);
  }

  Future<void> deleteSequence(String id) async {
    final client = _ref.read(supabaseClientProvider);
    await client.from('sequences').delete().eq('id', id).eq('group_id', _groupId);
  }

  Future<void> setCurrentSequence(String id) async {
    final client = _ref.read(supabaseClientProvider);
    await client.rpc('set_current_sequence', params: {'p_sequence_id': id});
  }

  // ── Jours non ouvrés nationaux (vacances & fériés) ────────────────────────

  Future<void> createHoliday({
    required String yearId,
    required String label,
    required String kind,
    required DateTime start,
    required DateTime end,
  }) async {
    final client = _ref.read(supabaseClientProvider);
    await client.from('school_holidays').insert({
      'group_id': _groupId,
      'school_id': null, // niveau groupe → hérité par toutes les écoles
      'academic_year_id': yearId,
      'label': label.trim(),
      'kind': kind,
      'start_date': _d(start),
      'end_date': _d(end),
    });
  }

  Future<void> updateHoliday({
    required String id,
    required String label,
    required String kind,
    required DateTime start,
    required DateTime end,
  }) async {
    final client = _ref.read(supabaseClientProvider);
    await client
        .from('school_holidays')
        .update({
          'label': label.trim(),
          'kind': kind,
          'start_date': _d(start),
          'end_date': _d(end),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id)
        .eq('group_id', _groupId)
        .isFilter('school_id', null);
  }

  Future<void> deleteHoliday(String id) async {
    final client = _ref.read(supabaseClientProvider);
    await client
        .from('school_holidays')
        .delete()
        .eq('id', id)
        .eq('group_id', _groupId)
        .isFilter('school_id', null);
  }

  /// Installe les fériés légaux congolais tombant dans l'année, en une
  /// transaction et sans doublon. Renvoie le nombre de jours ajoutés.
  ///
  /// Le comput pascal vit en base (`fn_easter_sunday`) pour que le semis reste
  /// atomique ; son équivalent Dart sert au calcul local côté école.
  Future<int> seedNationalHolidays(String yearId) async {
    final client = _ref.read(supabaseClientProvider);
    final res = await client
        .rpc('seed_national_holidays', params: {'p_year_id': yearId});
    return (res as num?)?.toInt() ?? 0;
  }

  // ── Relance ───────────────────────────────────────────────────────────────

  /// Notifie les chefs des établissements sans aucune classe ouverte sur
  /// l'année. Renvoie le nombre de destinataires touchés.
  Future<int> remindPendingSchools(String yearId) async {
    final client = _ref.read(supabaseClientProvider);
    final res = await client
        .rpc('remind_schools_pending_year', params: {'p_year_id': yearId});
    return (res as num?)?.toInt() ?? 0;
  }
}

final adminCalendarServiceProvider =
    Provider<AdminCalendarService>((ref) => AdminCalendarService(ref));
