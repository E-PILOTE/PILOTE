import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/identite_offline.dart';
import '../../../services/powersync/powersync_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/utils/erreur_metier.dart';

const _uuid = Uuid();

// ════════════════════════════════════════════════════════════════════════════
//  PAIE (table `payroll`, staff_id -> profiles.id, SENSIBLE sync_finance).
//  Bulletins par période (mois/année) : base + primes − retenues = net.
//  Statut de paiement (enum payment_status). 100% offline.
// ════════════════════════════════════════════════════════════════════════════

const kPayMethods = <(String, String)>[
  ('especes', 'Espèces'),
  ('mtn_money', 'MTN Money'),
  ('airtel_money', 'Airtel Money'),
  ('visa', 'Carte Visa'),
];

const kPayStatuses = <(String, String)>[
  ('pending', 'En attente'),
  ('confirmed', 'Payé'),
  ('cancelled', 'Annulé'),
  ('refunded', 'Remboursé'),
];

String payMethodLabel(String? m) =>
    kPayMethods.firstWhere((e) => e.$1 == m, orElse: () => ('especes', 'Espèces')).$2;
String payStatusLabel(String? s) =>
    kPayStatuses.firstWhere((e) => e.$1 == s, orElse: () => ('pending', 'En attente')).$2;

const kMonthNames = <String>[
  'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', 'Juillet', 'Août',
  'Septembre', 'Octobre', 'Novembre', 'Décembre',
];

class PayrollLine {
  const PayrollLine({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.base,
    required this.bonuses,
    required this.deductions,
    required this.net,
    required this.status,
    this.method,
    this.reference,
  });
  final String id, staffId, staffName, status;
  final int base, bonuses, deductions, net;
  final String? method, reference;
}

/// Bulletins d'une période (clé "YYYY-MM").
final payrollProvider =
    StreamProvider.autoDispose.family<List<PayrollLine>, String>((ref, periodKey) {
  ref.keepAlive();
  final schoolId = ref.watch(authNotifierProvider).valueOrNull?.schoolId;
  if (schoolId == null || schoolId.isEmpty) return Stream.value(const []);
  final parts = periodKey.split('-');
  final year = int.tryParse(parts.first) ?? DateTime.now().year;
  final month = int.tryParse(parts.last) ?? DateTime.now().month;
  return db.watch(
    '''
    SELECT pr.*, p.first_name, p.last_name
    FROM payroll pr
    LEFT JOIN profiles p ON p.id = pr.staff_id
    WHERE pr.school_id = ? AND pr.period_year = ? AND pr.period_month = ?
    ORDER BY p.last_name, p.first_name
    ''',
    parameters: [schoolId, year, month],
  ).map((rows) => [
        for (final r in rows)
          PayrollLine(
            id: r['id'] as String,
            staffId: (r['staff_id'] as String?) ?? '',
            staffName: '${(r['last_name'] as String?) ?? ''} '
                    '${(r['first_name'] as String?) ?? ''}'
                .trim(),
            base: (r['base_salary_xaf'] as num?)?.round() ?? 0,
            bonuses: (r['bonuses_xaf'] as num?)?.round() ?? 0,
            deductions: (r['deductions_xaf'] as num?)?.round() ?? 0,
            net: (r['net_salary_xaf'] as num?)?.round() ?? 0,
            status: (r['status'] as String?) ?? 'pending',
            method: r['payment_method'] as String?,
            reference: r['payment_reference'] as String?,
          ),
      ]);
});

// ─── Mutations ───────────────────────────────────────────────────────────────
Future<void> savePayroll({
  String? id,
  required String groupId,
  required String schoolId,
  required String staffId,
  required int month,
  required int year,
  required int base,
  required int bonuses,
  required int deductions,
  required String method,
  required String status,
  String? reference,
  String? notes,
  required String createdBy,
}) async {
  final now = DateTime.now().toIso8601String();
  final net = base + bonuses - deductions;
  final payDate = status == 'confirmed' ? now.substring(0, 10) : null;

  // ⚠️ `UNIQUE (staff_id, period_month, period_year)` : une seule fiche de paie
  // par agent et par mois. Deux créations pour le même mois — deux appuis, ou
  // deux postes hors ligne — se font refuser en 23505, code FATAL : le
  // connecteur jette le LOT ENTIER en attente. De l'argent, et pas seulement
  // celui-là.
  final vue = await db.getAll(
    'SELECT id FROM payroll WHERE staff_id = ? AND period_month = ? '
    'AND period_year = ? LIMIT 1',
    [staffId, month, year],
  );
  final occupe = vue.isNotEmpty ? vue.first['id'] as String : null;

  // Déplacer une fiche EXISTANTE sur un mois déjà occupé par une autre : la
  // base refuserait, et le refus coûterait le lot. On le dit ici, en clair —
  // `runModuleWrite` affiche le message.
  if (id != null && occupe != null && occupe != id) {
    throw ErreurMetier(
        'Une fiche de paie existe déjà pour cet agent sur $month/$year.');
  }

  // Création alors que la fiche existe déjà (le flux n'avait pas rafraîchi) :
  // on met à jour celle qui est là plutôt que d'en créer une seconde.
  if (id == null && occupe != null) {
    await db.execute(
      'UPDATE payroll SET base_salary_xaf = ?, bonuses_xaf = ?, '
      'deductions_xaf = ?, net_salary_xaf = ?, payment_method = ?, '
      'status = ?, payment_reference = ?, notes = ?, updated_at = ? '
      'WHERE id = ?',
      [base, bonuses, deductions, net, method, status, reference, notes,
       now, occupe],
    );
    return;
  }

  if (id != null) {
    await db.execute(
      'UPDATE payroll SET staff_id = ?, period_month = ?, period_year = ?, '
      'base_salary_xaf = ?, bonuses_xaf = ?, deductions_xaf = ?, '
      'net_salary_xaf = ?, payment_method = ?, status = ?, '
      'payment_reference = ?, notes = ?, updated_at = ? WHERE id = ?',
      [staffId, month, year, base, bonuses, deductions, net, method, status,
       reference, notes, now, id],
    );
  } else {
    await db.execute(
      '''
      INSERT INTO payroll (
        id, group_id, school_id, staff_id, period_month, period_year,
        base_salary_xaf, bonuses_xaf, deductions_xaf, net_salary_xaf,
        payment_date, payment_method, payment_reference, status, notes,
        created_by, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [idDeterministe('payroll', [staffId, '$month', '$year']),
       groupId, schoolId, staffId, month, year, base, bonuses,
       deductions, net, payDate, method, reference, status, notes, createdBy,
       now, now],
    );
  }
}

Future<void> confirmPayroll(String id) async {
  final now = DateTime.now().toIso8601String();
  await db.execute(
    "UPDATE payroll SET status = 'confirmed', payment_date = ?, updated_at = ? "
    'WHERE id = ?',
    [now.substring(0, 10), now, id],
  );
}

Future<void> deletePayroll(String id) async {
  await db.execute('DELETE FROM payroll WHERE id = ?', [id]);
}

/// Action groupée : reporter les bulletins d'un mois sur un autre (mêmes agents,
/// mêmes montants, statut remis à « en attente »). N'ajoute QUE les agents
/// absents de la période cible (pas de doublon).
Future<int> carryOverPayroll({
  required String groupId,
  required String schoolId,
  required int fromMonth,
  required int fromYear,
  required int toMonth,
  required int toYear,
  required String createdBy,
}) async {
  final src = await db.getAll(
    'SELECT * FROM payroll WHERE school_id = ? AND period_year = ? '
    'AND period_month = ?',
    [schoolId, fromYear, fromMonth],
  );
  if (src.isEmpty) return 0;
  final dst = await db.getAll(
    'SELECT staff_id FROM payroll WHERE school_id = ? AND period_year = ? '
    'AND period_month = ?',
    [schoolId, toYear, toMonth],
  );
  final already = {for (final r in dst) r['staff_id'] as String?};
  final now = DateTime.now().toIso8601String();
  var added = 0;
  await db.writeTransaction((tx) async {
    for (final r in src) {
      final sid = r['staff_id'] as String?;
      if (sid == null || already.contains(sid)) continue;
      await tx.execute(
        '''
        INSERT INTO payroll (
          id, group_id, school_id, staff_id, period_month, period_year,
          base_salary_xaf, bonuses_xaf, deductions_xaf, net_salary_xaf,
          payment_method, status, notes, created_by, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', ?, ?, ?, ?)
        ''',
        [_uuid.v4(), groupId, schoolId, sid, toMonth, toYear,
         (r['base_salary_xaf'] as num?)?.round() ?? 0,
         (r['bonuses_xaf'] as num?)?.round() ?? 0,
         (r['deductions_xaf'] as num?)?.round() ?? 0,
         (r['net_salary_xaf'] as num?)?.round() ?? 0,
         r['payment_method'], r['notes'], createdBy, now, now],
      );
      added++;
    }
  });
  return added;
}

/// Action groupée : marquer payés tous les bulletins « en attente » d'une liste.
Future<void> confirmPayrollBulk(List<String> ids) async {
  if (ids.isEmpty) return;
  final now = DateTime.now().toIso8601String();
  final ph = List.filled(ids.length, '?').join(',');
  await db.execute(
    "UPDATE payroll SET status = 'confirmed', payment_date = ?, updated_at = ? "
    "WHERE id IN ($ph) AND status = 'pending'",
    [now.substring(0, 10), now, ...ids],
  );
}
