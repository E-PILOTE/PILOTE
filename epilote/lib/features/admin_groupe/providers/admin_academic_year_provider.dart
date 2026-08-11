import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/providers/auth_provider.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  ESPACE ADMIN_GROUPE — Années scolaires (online / Supabase direct).
//
//  GOUVERNANCE : l'année scolaire est NATIONALE / niveau-groupe. admin_groupe
//  la crée (school_id = NULL) ; toutes les écoles l'héritent automatiquement via
//  PowerSync à leur prochaine synchro (sync progressive, offline-first préservé).
//  Chaque école « adopte » l'année en y préparant ses propres classes.
//
//  AGRÉGATION CÔTÉ SERVEUR : les compteurs viennent de la RPC
//  `academic_year_group_stats`. La version précédente rapatriait TOUTES les
//  lignes de `classes` et `class_enrollments` du groupe — toutes années
//  confondues — pour les compter en Dart : 9 000 lignes dès aujourd'hui,
//  plusieurs centaines de milliers à la cible de 1 000 écoles. Outre le volume
//  réseau, le plafond « Max rows » de PostgREST tronque la réponse SANS erreur :
//  les compteurs devenaient faux en silence. Le GROUP BY appartient à Postgres.
//
//  Les mutations vivent dans `admin_calendar_service.dart`.
// ══════════════════════════════════════════════════════════════════════════════

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

  int get schoolsPending => (schoolsTotal - schoolsAdopted).clamp(0, 1 << 30);

  double get adoptionRate =>
      schoolsTotal == 0 ? 0 : schoolsAdopted / schoolsTotal;

  bool get isFuture => startDate.isAfter(DateTime.now());

  /// Avancement de l'année dans le temps, 0 → 1 (0 avant la rentrée, 1 après).
  double get timeProgress {
    final total = endDate.difference(startDate).inSeconds;
    if (total <= 0) return 0;
    final done = DateTime.now().difference(startDate).inSeconds;
    return (done / total).clamp(0.0, 1.0);
  }

  /// Jours restants avant la rentrée (négatif si elle est passée).
  int get daysToStart =>
      startDate.difference(DateUtilsLite.today()).inDays;
}

/// Minuscule utilitaire de date — évite de traîner `package:intl` ici.
class DateUtilsLite {
  const DateUtilsLite._();
  static DateTime today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }
}

/// Filtre (`all` | `active` | `archived`) puis trie : année courante d'abord,
/// puis par date de début décroissante.
///
/// Renvoie TOUJOURS une liste neuve. La version précédente vivait dans le
/// widget et, sur le filtre « toutes », renvoyait la liste du provider telle
/// quelle avant de la trier EN PLACE — le cache du provider s'en trouvait
/// réordonné. Deux affichages en dépendaient et se trompaient en silence :
/// le graphe d'évolution, qui suppose un tri par date, et le calcul de la
/// variation « vs N-1 », qui prend l'élément suivant dans la liste.
///
/// Fonction pure et publique : c'est ce qui la rend testable, et le test
/// `n'altère pas la liste reçue` verrouille la correction.
List<AdminYear> filterAndSortYears(List<AdminYear> years, String filter) {
  return switch (filter) {
    'active' => years.where((y) => !y.isLocked).toList(),
    'archived' => years.where((y) => y.isLocked).toList(),
    _ => [...years],
  }..sort((a, b) {
      if (a.isCurrent != b.isCurrent) return a.isCurrent ? -1 : 1;
      return b.startDate.compareTo(a.startDate);
    });
}

/// Liste des années du groupe, avec adoption + totaux.
///
/// Deux requêtes, et deux seulement : les années, puis leurs agrégats.
/// Volontairement SANS `keepAlive()` : la version précédente gelait le cache
/// pour toute la durée de vie de l'application, et la page n'offrait aucun
/// moyen de le rafraîchir. Les requêtes sont désormais assez légères pour être
/// rejouées à chaque visite.
final adminAcademicYearsProvider =
    FutureProvider.autoDispose<List<AdminYear>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final groupId = ref.watch(authNotifierProvider).valueOrNull?.groupId;
  if (groupId == null) return const [];

  final years = await client
      .from('academic_years')
      .select('id, label, start_date, end_date, is_current, is_locked')
      .eq('group_id', groupId)
      .isFilter('school_id', null)
      .order('start_date', ascending: false) as List;

  final stats = await client.rpc('academic_year_group_stats',
      params: {'p_group_id': groupId}) as List;

  final byYear = <String, Map>{
    for (final r in stats) r['academic_year_id'] as String: r as Map,
  };

  int n(Map? r, String k) => (r?[k] as num?)?.toInt() ?? 0;

  return years.map((y) {
    final id = y['id'] as String;
    final s = byYear[id];
    return AdminYear(
      id: id,
      label: y['label'] as String,
      startDate: DateTime.parse(y['start_date'] as String),
      endDate: DateTime.parse(y['end_date'] as String),
      isCurrent: y['is_current'] == true,
      isLocked: y['is_locked'] == true,
      classes: n(s, 'classes'),
      eleves: n(s, 'eleves'),
      schoolsAdopted: n(s, 'schools_adopted'),
      schoolsTotal: n(s, 'schools_total'),
    );
  }).toList(growable: false);
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

  /// Numéros de séquence déjà pris — pour ne proposer que les libres.
  Set<int> get takenSequenceNumbers => {for (final s in sequences) s.number};
}

// ─── Jours non ouvrés NATIONAUX d'une année (vacances + fériés) ──────────────
//  `school_id IS NULL` : fixés une fois par le groupe, hérités par toutes les
//  écoles via le bucket `by_group` des sync-rules. Une école peut y ajouter ses
//  propres fermetures, qui restent chez elle.
class AdminHoliday {
  const AdminHoliday({
    required this.id,
    required this.label,
    required this.kind,
    required this.startDate,
    required this.endDate,
  });

  final String id, label, kind;
  final DateTime startDate, endDate;

  bool get isFerie => kind == 'ferie';
  bool get isSingleDay =>
      startDate.year == endDate.year &&
      startDate.month == endDate.month &&
      startDate.day == endDate.day;

  /// Bornes incluses : du lundi au vendredi de la même semaine = 5 jours.
  int get dayCount => endDate.difference(startDate).inDays + 1;
}

final adminYearHolidaysProvider = FutureProvider.autoDispose
    .family<List<AdminHoliday>, String>((ref, yearId) async {
  final client = ref.watch(supabaseClientProvider);

  final rows = await client
      .from('school_holidays')
      .select('id, label, kind, start_date, end_date')
      .eq('academic_year_id', yearId)
      .isFilter('school_id', null)
      .order('start_date', ascending: true) as List;

  return rows
      .map((h) => AdminHoliday(
            id: h['id'] as String,
            label: (h['label'] as String?) ?? '',
            kind: (h['kind'] as String?) ?? 'ferie',
            startDate: DateTime.parse(h['start_date'] as String),
            endDate: DateTime.parse(h['end_date'] as String),
          ))
      .toList(growable: false);
});

/// Calendrier complet d'une année, en UNE requête.
///
/// La version précédente faisait un N+1 : une requête pour les trimestres, puis
/// une requête de séquences PAR trimestre. L'imbrication PostgREST ramène tout
/// d'un coup ; le tri se fait ici, sans dépendre du support de `referencedTable`
/// selon la version du client.
final adminYearCalendarProvider = FutureProvider.autoDispose
    .family<List<AdminTrimester>, String>((ref, yearId) async {
  final client = ref.watch(supabaseClientProvider);

  final rows = await client
      .from('trimesters')
      .select('id, label, trimester_number, start_date, end_date, is_current, '
          'sequences(id, label, sequence_number, start_date, end_date, '
          'is_current)')
      .eq('academic_year_id', yearId) as List;

  final out = rows.map((t) {
    final seqs = (t['sequences'] as List? ?? const [])
        .map((s) => AdminSequence(
              id: s['id'] as String,
              label: s['label'] as String,
              number: (s['sequence_number'] as num).toInt(),
              startDate: DateTime.parse(s['start_date'] as String),
              endDate: DateTime.parse(s['end_date'] as String),
              isCurrent: s['is_current'] == true,
            ))
        .toList()
      ..sort((a, b) => a.number.compareTo(b.number));

    return AdminTrimester(
      id: t['id'] as String,
      label: t['label'] as String,
      number: (t['trimester_number'] as num).toInt(),
      startDate: DateTime.parse(t['start_date'] as String),
      endDate: DateTime.parse(t['end_date'] as String),
      isCurrent: t['is_current'] == true,
      sequences: seqs,
    );
  }).toList()
    ..sort((a, b) => a.number.compareTo(b.number));

  return out;
});
