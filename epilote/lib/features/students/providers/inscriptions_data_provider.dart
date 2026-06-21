import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/structure/providers/academic_year_context.dart';
import '../../../services/powersync/powersync_service.dart';

// ════════════════════════════════════════════════════════════════════════════
//  DONNÉES DE LA PAGE INSCRIPTIONS — 100% offline (db.watch local), année active.
//  Joint class_enrollments + students + classes ; les KPI/graphes/listes sont
//  dérivés côté client (une école = quelques centaines d'inscrits au plus).
// ════════════════════════════════════════════════════════════════════════════

// ─── Classifieur de cycle (nom de classe → cycle) ────────────────────────────
// Les classes congolaises n'ont pas toujours de level_id renseigné ; le NOM de
// la classe (« 6ème A », « CP1 », « Terminale C ») est le seul lien fiable et
// 100% offline vers le cycle. Les cycles présents reflètent dynamiquement ceux
// de l'école (hérités à sa création). Ordre = ordre pédagogique (préscolaire→FP).
class InscriptionCycle {
  const InscriptionCycle(this.code, this.label, this.order);
  final String code;
  final String label;
  final int order;
}

const _cyclePrescolaire = InscriptionCycle('prescolaire', 'Préscolaire', 1);
const _cyclePrimaire    = InscriptionCycle('primaire', 'Primaire', 2);
const _cycleCollege     = InscriptionCycle('college', 'Collège', 3);
const _cycleLycee       = InscriptionCycle('lycee', 'Lycée', 4);
const _cycleFp          = InscriptionCycle('fp', 'Formation Pro.', 5);
const _cycleAutre       = InscriptionCycle('autre', 'Non classé', 9);

/// Cycle RÉEL d'une classe via son `cycle_code` (dénormalisé depuis
/// classe→niveau→cycle, migration 0010). Repli sur l'heuristique par NOM
/// uniquement si la classe n'est pas encore reliée à un niveau (cycle_code nul).
const _cycleByCode = <String, InscriptionCycle>{
  'prescolaire': _cyclePrescolaire,
  'primaire': _cyclePrimaire,
  'college': _cycleCollege,
  'lycee': _cycleLycee,
  'formation_pro': _cycleFp,
};

InscriptionCycle inscriptionCycleFromCode(String? code, String? fallbackName) {
  final c = _cycleByCode[code];
  return c ?? inscriptionCycleOf(fallbackName);
}

/// Déduit le cycle d'une classe à partir de son nom (conventions Congo).
InscriptionCycle inscriptionCycleOf(String? rawName) {
  final n = (rawName ?? '').toLowerCase().trim();
  if (n.isEmpty) return _cycleAutre;
  // Normalisation : accents → ascii, espaces/tirets retirés.
  final s = n
      .replaceAll(RegExp(r'[éèê]'), 'e')
      .replaceAll(RegExp(r'[àâ]'), 'a')
      .replaceAll(RegExp(r'[\s\-_.]'), '');
  if (s.contains('maternelle') ||
      RegExp(r'^(ps|ms|gs|creche|eveil)').hasMatch(s)) {
    return _cyclePrescolaire;
  }
  if (RegExp(r'(cp[12]?|ce[12]|cm[12])').hasMatch(s)) return _cyclePrimaire;
  if (RegExp(r'^(6|5|4|3)(e|eme|ieme)').hasMatch(s)) return _cycleCollege;
  if (RegExp(r'(2nd|2de|seconde|1er|1re|premiere|tle|tlle|terminale)')
      .hasMatch(s)) {
    return _cycleLycee;
  }
  if (RegExp(r'(cap|bep|bacpro|^bt|^fp)').hasMatch(s)) return _cycleFp;
  return _cycleAutre;
}

// ─── Ligne d'inscription (vue liste/table/cartes) ───────────────────────────
class InscriptionRow {
  const InscriptionRow({
    required this.id,
    required this.studentId,
    required this.firstName,
    required this.lastName,
    required this.matricule,
    required this.gender,
    required this.photoUrl,
    required this.className,
    required this.cycle,
    required this.inscriptionType,
    required this.status,
    required this.isRepeating,
    required this.enrollmentDate,
    required this.validatedAt,
  });

  final String id;
  final String studentId;
  final String firstName;
  final String lastName;
  final String matricule;
  final String? gender;
  final String? photoUrl;
  final String className;
  final InscriptionCycle cycle;
  final String inscriptionType; // new | reinscription | transfer
  final String status;          // active | pending_validation | rejected | …
  final bool isRepeating;
  final DateTime? enrollmentDate;
  final DateTime? validatedAt;

  String get fullName => '$firstName $lastName'.trim();
  String get lastFirst {
    final l = lastName.trim(), f = firstName.trim();
    if (l.isEmpty) return f;
    if (f.isEmpty) return l;
    return '$l $f';
  }

  String get typeLabel => switch (inscriptionType) {
        'new' => 'Nouvelle',
        'reinscription' => 'Réinscription',
        'transfer' => 'Transfert',
        _ => inscriptionType,
      };

  String get statusLabel => switch (status) {
        'active' => 'Validée',
        'pending_validation' => 'En attente',
        'rejected' => 'Rejetée',
        'withdrawn' => 'Retirée',
        'transferred' => 'Transférée',
        'graduated' => 'Diplômée',
        _ => status,
      };
}

/// Toutes les inscriptions de l'année active (tous statuts) + élève + classe.
final inscriptionsDataProvider =
    StreamProvider.autoDispose<List<InscriptionRow>>((ref) {
  ref.keepAlive();
  final schoolId = ref.watch(authNotifierProvider).valueOrNull?.schoolId;
  final yearId = ref.watch(activeYearIdProvider);
  if (schoolId == null || schoolId.isEmpty || yearId == null) {
    return Stream.value(const []);
  }
  return db
      .watch(
        '''
        SELECT ce.id, ce.student_id, ce.status, ce.inscription_type,
               ce.is_repeating, ce.enrollment_date, ce.validated_at,
               s.first_name, s.last_name, s.matricule, s.gender, s.photo_url,
               c.name AS class_name, c.cycle_code AS cycle_code
        FROM   class_enrollments ce
        JOIN   students s ON s.id = ce.student_id
        LEFT JOIN classes c ON c.id = ce.class_id
        WHERE  ce.school_id = ? AND ce.academic_year_id = ?
        ORDER  BY s.last_name, s.first_name
        ''',
        parameters: [schoolId, yearId],
      )
      .map((rows) => [
            for (final r in rows)
              InscriptionRow(
                id: r['id'] as String,
                studentId: r['student_id'] as String,
                firstName: r['first_name'] as String? ?? '',
                lastName: r['last_name'] as String? ?? '',
                matricule: r['matricule'] as String? ?? '',
                gender: r['gender'] as String?,
                photoUrl: r['photo_url'] as String?,
                className: r['class_name'] as String? ?? '—',
                cycle: inscriptionCycleFromCode(
                    r['cycle_code'] as String?, r['class_name'] as String?),
                inscriptionType: r['inscription_type'] as String? ?? 'new',
                status: r['status'] as String? ?? 'active',
                isRepeating: r['is_repeating'] == 1 || r['is_repeating'] == true,
                enrollmentDate: _d(r['enrollment_date']),
                validatedAt: _d(r['validated_at']),
              ),
          ]);
});

DateTime? _d(Object? v) =>
    (v is String && v.isNotEmpty) ? DateTime.tryParse(v) : null;

// ─── Export CSV ──────────────────────────────────────────────────────────────

String _csvCell(String? v) {
  final s = (v ?? '').replaceAll('"', '""');
  return '"$s"';
}

/// Génère un CSV (séparateur `;` — compatible Excel FR) des inscriptions filtrées
/// et l'écrit dans le dossier Documents de l'appareil. Retourne le chemin.
Future<String> exportInscriptionsCsv(List<InscriptionRow> rows) async {
  final b = StringBuffer();
  b.writeln([
    'Matricule', 'Nom', 'Prénom', 'Sexe', 'Classe', 'Cycle',
    'Type', 'Statut', 'Redoublant', 'Date inscription',
  ].map(_csvCell).join(';'));
  for (final r in rows) {
    b.writeln([
      r.matricule, r.lastName, r.firstName,
      r.gender ?? '', r.className, r.cycle.label,
      r.typeLabel, r.statusLabel, r.isRepeating ? 'Oui' : 'Non',
      r.enrollmentDate?.toIso8601String().substring(0, 10) ?? '',
    ].map(_csvCell).join(';'));
  }
  final dir = await getApplicationDocumentsDirectory();
  final ts = DateTime.now().toIso8601String().substring(0, 10);
  final file = File('${dir.path}/inscriptions_$ts.csv');
  // BOM UTF-8 pour qu'Excel lise correctement les accents.
  await file.writeAsString('﻿${b.toString()}');
  return file.path;
}

// ─── Agrégations dérivées (KPI / cycles / évolution) ─────────────────────────

class CycleCount {
  const CycleCount(this.cycle, this.total, this.boys, this.girls);
  final InscriptionCycle cycle;
  final int total, boys, girls;
}

class InscriptionStats {
  const InscriptionStats({
    required this.total,
    required this.active,
    required this.pending,
    required this.rejected,
    required this.boys,
    required this.girls,
    required this.typeNew,
    required this.reinscription,
    required this.transfer,
    required this.repeating,
    required this.byCycle,
    required this.evolution,
  });

  final int total, active, pending, rejected;
  final int boys, girls;
  final int typeNew, reinscription, transfer, repeating;
  final List<CycleCount> byCycle;        // trié ordre pédagogique
  final List<(String, int)> evolution;   // (mois « MM/yyyy », cumul) croissant
}

/// Statistiques d'inscription dérivées (mêmes données, calculées côté client).
final inscriptionStatsProvider = Provider.autoDispose<InscriptionStats>((ref) {
  final rows = ref.watch(inscriptionsDataProvider).valueOrNull ?? const [];

  var active = 0, pending = 0, rejected = 0, boys = 0, girls = 0;
  var tNew = 0, tRe = 0, tTr = 0, repeating = 0;
  final cycleMap = <String, List<int>>{}; // code → [total, boys, girls, order]
  final cycleObj = <String, InscriptionCycle>{};
  final monthCount = <String, int>{};

  for (final r in rows) {
    switch (r.status) {
      case 'active': active++;
      case 'pending_validation': pending++;
      case 'rejected': rejected++;
    }
    // KPI cycle/genre/évolution : sur les inscriptions « réelles » (hors rejet).
    if (r.status == 'rejected') continue;
    if (r.gender == 'M') {
      boys++;
    } else if (r.gender == 'F') {
      girls++;
    }
    switch (r.inscriptionType) {
      case 'new': tNew++;
      case 'reinscription': tRe++;
      case 'transfer': tTr++;
    }
    if (r.isRepeating) repeating++;

    final c = cycleMap.putIfAbsent(r.cycle.code, () => [0, 0, 0, r.cycle.order]);
    cycleObj[r.cycle.code] = r.cycle;
    c[0]++;
    if (r.gender == 'M') {
      c[1]++;
    } else if (r.gender == 'F') {
      c[2]++;
    }

    final d = r.enrollmentDate;
    if (d != null) {
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      monthCount[key] = (monthCount[key] ?? 0) + 1;
    }
  }

  final byCycle = cycleMap.entries
      .map((e) => CycleCount(cycleObj[e.key]!, e.value[0], e.value[1], e.value[2]))
      .toList()
    ..sort((a, b) => a.cycle.order.compareTo(b.cycle.order));

  // Évolution cumulée par mois (croissant).
  final months = monthCount.keys.toList()..sort();
  var cumul = 0;
  final evolution = <(String, int)>[];
  for (final m in months) {
    cumul += monthCount[m]!;
    final parts = m.split('-');
    evolution.add(('${parts[1]}/${parts[0]}', cumul));
  }

  return InscriptionStats(
    total: active + pending, // dossiers vivants (hors rejet)
    active: active,
    pending: pending,
    rejected: rejected,
    boys: boys,
    girls: girls,
    typeNew: tNew,
    reinscription: tRe,
    transfer: tTr,
    repeating: repeating,
    byCycle: byCycle,
    evolution: evolution,
  );
});
