import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/structure/providers/academic_year_context.dart';
import '../../../services/powersync/powersync_service.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Données agrégées du tableau de bord — 100% offline (db.watch local).
//  Scopées école + année active.
// ════════════════════════════════════════════════════════════════════════════

/// Une part de répartition (libellé + valeur) pour les graphes.
class DashboardSlice {
  const DashboardSlice(this.label, this.value);
  final String label;
  final int value;
}

/// Répartition par genre des élèves inscrits (actifs) de l'année active.
final studentsByGenderProvider =
    StreamProvider.autoDispose<List<DashboardSlice>>((ref) {
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final yearId = ref.watch(activeYearIdProvider);
  if (profile?.schoolId == null || profile!.schoolId!.isEmpty || yearId == null) {
    return Stream.value(const []);
  }
  return db
      .watch(
        '''
        SELECT s.gender AS g, COUNT(*) AS cnt
        FROM   class_enrollments ce
        JOIN   students s ON s.id = ce.student_id
        WHERE  ce.school_id = ? AND ce.academic_year_id = ? AND ce.status = 'active'
        GROUP  BY s.gender
        ''',
        parameters: [profile.schoolId, yearId],
      )
      .map((rows) {
        final out = <DashboardSlice>[];
        for (final r in rows) {
          final g = (r['g'] as String?) ?? '';
          final label = g == 'M'
              ? 'Garçons'
              : g == 'F'
                  ? 'Filles'
                  : 'Non précisé';
          out.add(DashboardSlice(label, (r['cnt'] as int?) ?? 0));
        }
        return out;
      });
});

// ─── PERSONNEL (direction) ───────────────────────────────────────────────────

class StaffSummary {
  const StaffSummary(this.total, this.teachers, this.active);
  final int total, teachers, active;
}

/// Effectif du personnel de l'école (offline, source = `profiles`, comme
/// l'annuaire Personnel : tout profil sauf élève/parent). Le bloc qui la
/// consomme est gaté par la permission `personnel` (accès = permissions), donc
/// n'apparaît que si l'admin groupe a attribué ce module à l'agent.
final staffSummaryProvider = StreamProvider.autoDispose<StaffSummary>((ref) {
  final sid = ref.watch(authNotifierProvider).valueOrNull?.schoolId;
  if (sid == null || sid.isEmpty) return Stream.value(const StaffSummary(0, 0, 0));
  return db
      .watch(
        '''
        SELECT
          COUNT(*) AS total,
          COALESCE(SUM(CASE WHEN role = 'enseignant' THEN 1 ELSE 0 END), 0) AS teachers,
          COALESCE(SUM(CASE WHEN COALESCE(is_active, 1) <> 0
                            THEN 1 ELSE 0 END), 0)                    AS active
        FROM profiles
        WHERE school_id = ? AND role NOT IN ('eleve', 'parent')
        ''',
        parameters: [sid],
      )
      .map((rows) {
        if (rows.isEmpty) return const StaffSummary(0, 0, 0);
        final r = rows.first;
        return StaffSummary(
          (r['total'] as num?)?.toInt() ?? 0,
          (r['teachers'] as num?)?.toInt() ?? 0,
          (r['active'] as num?)?.toInt() ?? 0,
        );
      });
});

// ─── FINANCE (comptable / direction) ─────────────────────────────────────────

class PaymentsSummary {
  const PaymentsSummary(this.encaisse, this.attente);
  final int encaisse; // status = 'confirmed'
  final int attente; // status = 'pending'
}

/// Encaissements (confirmés) vs en attente — école, **scopés à l'année active**
/// (cohérent avec les Dépenses/Solde). `amount_xaf` en XAF.
///
/// Ce total lisait l'année par une jointure sur `class_enrollments`, faute de
/// colonne d'année sur le paiement (migration 0095). Deux conséquences, toutes
/// deux corrigées ici : un paiement sans inscription rattachée — les frais
/// d'examen, `savePayment` acceptant un `enrollment_id` nul — DISPARAISSAIT
/// des totaux ; et « en attente » (`<> 'confirmed'`) comptait les paiements
/// ANNULÉS comme de l'argent à venir.
final paymentsSummaryProvider =
    StreamProvider.autoDispose<PaymentsSummary>((ref) {
  final sid = ref.watch(authNotifierProvider).valueOrNull?.schoolId;
  final yearId = ref.watch(activeYearIdProvider);
  if (sid == null || sid.isEmpty || yearId == null) {
    return Stream.value(const PaymentsSummary(0, 0));
  }
  return db
      .watch(
        '''
        SELECT
          -- Net encaissé : un remboursement PARTIEL laisse la ligne
          -- `confirmed` mais n'a plus rapporté que la différence ; un
          -- remboursement TOTAL passe en `refunded` et ne rapporte rien.
          -- Compter les seules lignes `confirmed` faisait disparaître la part
          -- conservée d'un remboursement partiel (cf. `montantNet`).
          COALESCE(SUM(CASE WHEN status IN ('confirmed', 'refunded')
                            THEN MAX(amount_xaf - COALESCE(refunded_amount_xaf, 0), 0)
                            ELSE 0 END), 0) AS enc,
          COALESCE(SUM(CASE WHEN status = 'pending'   THEN amount_xaf ELSE 0 END), 0) AS att
        FROM student_payments
        WHERE school_id = ? AND academic_year_id = ?
        ''',
        parameters: [sid, yearId],
      )
      .map((rows) {
        if (rows.isEmpty) return const PaymentsSummary(0, 0);
        final r = rows.first;
        return PaymentsSummary(
          (r['enc'] as num?)?.toInt() ?? 0,
          (r['att'] as num?)?.toInt() ?? 0,
        );
      });
});

/// Total des dépenses de l'année active (école).
final expensesTotalProvider = StreamProvider.autoDispose<int>((ref) {
  final sid = ref.watch(authNotifierProvider).valueOrNull?.schoolId;
  final yearId = ref.watch(activeYearIdProvider);
  if (sid == null || sid.isEmpty || yearId == null) return Stream.value(0);
  return db
      .watch(
        'SELECT COALESCE(SUM(amount_xaf), 0) AS t FROM expenses '
        'WHERE school_id = ? AND academic_year_id = ?',
        parameters: [sid, yearId],
      )
      .map((rows) => rows.isEmpty ? 0 : ((rows.first['t'] as num?)?.toInt() ?? 0));
});

// ─── MÉDICAL (infirmier / direction) ─────────────────────────────────────────

class MedicalSummary {
  const MedicalSummary(this.month, this.total, this.followUp);
  final int month, total, followUp;
}

final medicalSummaryProvider =
    StreamProvider.autoDispose<MedicalSummary>((ref) {
  final sid = ref.watch(authNotifierProvider).valueOrNull?.schoolId;
  if (sid == null || sid.isEmpty) return Stream.value(const MedicalSummary(0, 0, 0));
  final monthStart = _monthStart();
  return db
      .watch(
        '''
        SELECT COUNT(*) AS total,
          COALESCE(SUM(CASE WHEN visit_date >= ? THEN 1 ELSE 0 END), 0) AS mois,
          COALESCE(SUM(CASE WHEN follow_up_required = 1 THEN 1 ELSE 0 END), 0) AS suivi
        FROM infirmary_visits WHERE school_id = ?
        ''',
        parameters: [monthStart, sid],
      )
      .map((rows) {
        if (rows.isEmpty) return const MedicalSummary(0, 0, 0);
        final r = rows.first;
        return MedicalSummary(
          (r['mois'] as num?)?.toInt() ?? 0,
          (r['total'] as num?)?.toInt() ?? 0,
          (r['suivi'] as num?)?.toInt() ?? 0,
        );
      });
});

// ─── DISCIPLINE (cpe / surveillant / direction) ──────────────────────────────

class DisciplineSummary {
  const DisciplineSummary(this.month, this.yearTotal, this.unnotified);
  final int month, yearTotal, unnotified;
}

final disciplineSummaryProvider =
    StreamProvider.autoDispose<DisciplineSummary>((ref) {
  final sid = ref.watch(authNotifierProvider).valueOrNull?.schoolId;
  final yearId = ref.watch(activeYearIdProvider);
  if (sid == null || sid.isEmpty || yearId == null) {
    return Stream.value(const DisciplineSummary(0, 0, 0));
  }
  final monthStart = _monthStart();
  return db
      .watch(
        '''
        SELECT COUNT(*) AS total,
          COALESCE(SUM(CASE WHEN incident_date >= ? THEN 1 ELSE 0 END), 0) AS mois,
          COALESCE(SUM(CASE WHEN parent_notified = 1 THEN 0 ELSE 1 END), 0) AS nonnotif
        FROM discipline_incidents WHERE school_id = ? AND academic_year_id = ?
        ''',
        parameters: [monthStart, sid, yearId],
      )
      .map((rows) {
        if (rows.isEmpty) return const DisciplineSummary(0, 0, 0);
        final r = rows.first;
        return DisciplineSummary(
          (r['mois'] as num?)?.toInt() ?? 0,
          (r['total'] as num?)?.toInt() ?? 0,
          (r['nonnotif'] as num?)?.toInt() ?? 0,
        );
      });
});

/// Premier jour du mois courant en ISO (yyyy-MM-dd) pour les filtres de date.
String _monthStart() {
  final n = DateTime.now();
  final m = n.month.toString().padLeft(2, '0');
  return '${n.year}-$m-01';
}

/// Nombre d'inscriptions en attente de validation (année active, école).
final pendingEnrollmentCountProvider = StreamProvider.autoDispose<int>((ref) {
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final yearId = ref.watch(activeYearIdProvider);
  if (profile?.schoolId == null || profile!.schoolId!.isEmpty || yearId == null) {
    return Stream.value(0);
  }
  return db
      .watch(
        'SELECT COUNT(*) AS cnt FROM class_enrollments '
        "WHERE school_id = ? AND academic_year_id = ? AND status = 'pending_validation'",
        parameters: [profile.schoolId, yearId],
      )
      .map((rows) => rows.isEmpty ? 0 : (rows.first['cnt'] as int? ?? 0));
});
