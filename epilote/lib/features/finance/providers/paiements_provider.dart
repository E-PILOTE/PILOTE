import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../services/powersync/powersync_service.dart';
import '../../classes/providers/class_provider.dart';
import '../../structure/providers/academic_year_context.dart';
import '../../vie_scolaire/widgets/vs_kit.dart';
import '../services/obligation.dart';
import 'obligation_provider.dart';
import '../services/poste_tag.dart';
import '../services/receipt_number.dart';

const _uuid = Uuid();

// ════════════════════════════════════════════════════════════════════════════
//  PAIEMENTS ÉLÈVES (table `student_payments`) — encaissements par élève (frais,
//  montant, méthode, statut). Recouvrement par classe + historique par élève.
//  100% offline.
// ════════════════════════════════════════════════════════════════════════════

const kPaymentMethods = <(String, String)>[
  ('especes', 'Espèces'),
  ('mtn_money', 'MTN Money'),
  ('airtel_money', 'Airtel Money'),
  ('visa', 'Carte Visa'),
];

const kPaymentStatuses = <(String, String)>[
  ('confirmed', 'Confirmé'),
  ('pending', 'En attente'),
  ('cancelled', 'Annulé'),
  ('refunded', 'Remboursé'),
];

String paymentMethodLabel(String? m) => kPaymentMethods
    .firstWhere((e) => e.$1 == m, orElse: () => ('especes', 'Espèces'))
    .$2;
String paymentStatusLabel(String? s) => kPaymentStatuses
    .firstWhere((e) => e.$1 == s, orElse: () => ('confirmed', 'Confirmé'))
    .$2;

class PaymentsOverview {
  const PaymentsOverview({
    required this.rows,
    required this.collected,
    required this.confirmedCount,
    required this.pendingCount,
    required this.payers,
    required this.students,
    this.duTotal = 0,
    this.aJour = 0,
  });
  final List<VsCoverageRow> rows;
  final int collected, confirmedCount, pendingCount, payers, students;

  /// Somme de ce que l'école devrait avoir encaissé à ce jour, et nombre
  /// d'élèves qui ont soldé leur dû. `duTotal == 0` ⇒ aucun barème applicable :
  /// afficher un taux serait mentir (cf. `EtatObligation.sansBareme`).
  final int duTotal, aJour;

  bool get sansBareme => duTotal <= 0;
  int get resteDu => (duTotal - collected).clamp(0, duTotal);
  int get classesTotal => rows.length;
}


final paymentsOverviewProvider =
    FutureProvider.autoDispose<PaymentsOverview>((ref) async {
  ref.keepAlive();
  final classes = ref.watch(classesProvider).valueOrNull;
  final yearId = ref.watch(activeYearIdProvider);
  final baremes = ref.watch(baremesApplicablesProvider).valueOrNull ?? const [];
  final mois = ref.watch(moisEcoulesProvider);
  if (classes == null || classes.isEmpty || yearId == null) {
    return const PaymentsOverview(
        rows: [], collected: 0, confirmedCount: 0, pendingCount: 0,
        payers: 0, students: 0);
  }
  final ids = [for (final c in classes) c.id];
  final ph = List.filled(ids.length, '?').join(',');

  // ⚠️ Le filtre d'année n'est pas cosmétique : sans lui, les versements de
  // l'année précédente compteraient comme payés à la rentrée suivante.
  final rows = await db.getAll(
    'SELECT ce.class_id AS cid, sp.student_id AS sid, sp.amount_xaf AS amt, '
    'sp.status AS st '
    'FROM student_payments sp '
    "JOIN class_enrollments ce ON ce.student_id = sp.student_id AND ce.status = 'active' "
    'WHERE ce.class_id IN ($ph) AND sp.academic_year_id = ?',
    [...ids, yearId],
  );
  final payersByClass = <String, Set<String>>{};
  final collectedByClass = <String, int>{};
  final verseParEleve = <String, int>{};
  var collected = 0, confirmedCount = 0, pendingCount = 0;
  final allPayers = <String>{};
  for (final r in rows) {
    final st = r['st'] as String?;
    final cid = r['cid'] as String;
    final sid = r['sid'] as String;
    if (st == 'confirmed') {
      final amt = (r['amt'] as num?)?.round() ?? 0;
      collected += amt;
      collectedByClass[cid] = (collectedByClass[cid] ?? 0) + amt;
      verseParEleve[sid] = (verseParEleve[sid] ?? 0) + amt;
      confirmedCount++;
      (payersByClass[cid] ??= {}).add(sid);
      allPayers.add(sid);
    } else if (st == 'pending') {
      pendingCount++;
    }
  }

  // Le dû se calcule par NIVEAU (un barème peut ne viser qu'un niveau), donc
  // par classe. Les élèves d'une classe partagent le même dû ; ce qui les
  // distingue est ce qu'ils ont versé.
  final duParClasse = {
    for (final c in classes) c.id: duPourNiveau(baremes, c.levelId, mois),
  };

  // Qui a soldé : il faut le versement de CHAQUE élève, pas seulement de ceux
  // qui ont payé — un élève absent de `verseParEleve` a versé zéro.
  final aJourParClasse = <String, int>{};
  if (baremes.isNotEmpty) {
    final inscrits = await db.getAll(
      'SELECT class_id AS cid, student_id AS sid FROM class_enrollments '
      "WHERE class_id IN ($ph) AND status = 'active'",
      ids,
    );
    for (final e in inscrits) {
      final cid = e['cid'] as String;
      final du = duParClasse[cid] ?? 0;
      final verse = verseParEleve[e['sid'] as String] ?? 0;
      if (etatObligation(du: du, verse: verse) == EtatObligation.aJour) {
        aJourParClasse[cid] = (aJourParClasse[cid] ?? 0) + 1;
      }
    }
  }

  final cov = [
    for (final c in classes)
      VsCoverageRow(
        classId: c.id,
        className: c.name,
        cycleCode: c.cycleCode,
        levelCode: c.levelCode,
        levelOrder: c.levelOrder ?? 999,
        total: c.studentCount ?? 0,
        ok: aJourParClasse[c.id] ?? 0,
        note: collectedByClass[c.id] != null
            ? fmtCompact(collectedByClass[c.id]!)
            : null,
      ),
  ]..sort((a, b) {
      final o = a.levelOrder.compareTo(b.levelOrder);
      return o != 0 ? o : a.className.compareTo(b.className);
    });

  return PaymentsOverview(
    rows: cov,
    collected: collected,
    confirmedCount: confirmedCount,
    pendingCount: pendingCount,
    payers: allPayers.length,
    students: cov.fold(0, (a, c) => a + c.total),
    duTotal: [
      for (final c in classes) (duParClasse[c.id] ?? 0) * (c.studentCount ?? 0),
    ].fold(0, (a, b) => a + b),
    aJour: aJourParClasse.values.fold(0, (a, b) => a + b),
  );
});

/// Une ligne élève (agrégat de ses paiements).
class StudentPayRow {
  const StudentPayRow({
    required this.studentId,
    required this.enrollmentId,
    required this.studentName,
    required this.matricule,
    required this.paid,
    required this.count,
    required this.lastDate,
    this.du = 0,
  });
  final String studentId, studentName;
  final String? enrollmentId, matricule, lastDate;
  final int paid, count;

  /// Ce que cet élève doit à ce jour, tous barèmes applicables confondus.
  final int du;

  int get reste => (du - paid).clamp(0, du);
  EtatObligation get etat => etatObligation(du: du, verse: paid);

  /// ⚠️ « a versé quelque chose » — ce n'est PAS « à jour ». Conservé pour les
  /// usages qui veulent seulement savoir si un mouvement existe.
  bool get hasPaid => paid > 0;
}

final classPaymentsProvider = StreamProvider.autoDispose
    .family<List<StudentPayRow>, String>((ref, classId) {
  final yearId = ref.watch(activeYearIdProvider);
  final baremes = ref.watch(baremesApplicablesProvider).valueOrNull ?? const [];
  final mois = ref.watch(moisEcoulesProvider);
  final niveau = ref
      .watch(classesProvider)
      .valueOrNull
      ?.where((c) => c.id == classId)
      .firstOrNull
      ?.levelId;
  final du = duPourNiveau(baremes, niveau, mois);
  if (yearId == null) return Stream.value(const []);
  return db.watch(
    '''
    SELECT s.id AS sid, ce.id AS enr, s.first_name, s.last_name, s.matricule,
      (SELECT COALESCE(SUM(amount_xaf),0) FROM student_payments p
        WHERE p.student_id = s.id AND p.status = 'confirmed'
          AND p.academic_year_id = ?1) AS paid,
      (SELECT COUNT(*) FROM student_payments p
        WHERE p.student_id = s.id AND p.academic_year_id = ?1) AS cnt,
      (SELECT MAX(payment_date) FROM student_payments p
        WHERE p.student_id = s.id AND p.academic_year_id = ?1) AS last_d
    FROM class_enrollments ce
    JOIN students s ON s.id = ce.student_id
    WHERE ce.class_id = ?2 AND ce.status = 'active'
    ORDER BY s.last_name, s.first_name
    ''',
    parameters: [yearId, classId],
  ).map((rows) => [
        for (final r in rows)
          StudentPayRow(
            studentId: r['sid'] as String,
            enrollmentId: r['enr'] as String?,
            studentName: '${(r['last_name'] as String?) ?? ''} '
                    '${(r['first_name'] as String?) ?? ''}'
                .trim(),
            matricule: r['matricule'] as String?,
            paid: (r['paid'] as num?)?.round() ?? 0,
            count: (r['cnt'] as num?)?.round() ?? 0,
            lastDate: r['last_d'] as String?,
            du: du,
          ),
      ]);
});

class PaymentRow {
  const PaymentRow({
    required this.id,
    required this.amount,
    required this.date,
    required this.method,
    required this.status,
    required this.feeName,
    required this.receipt,
    this.cancellationReason,
  });
  final String id;
  final int amount;
  final String? date, method, status, feeName, receipt;

  /// Renseigné dès qu'un encaissement a été annulé : c'est ce qui rend
  /// l'annulation lisible au dossier au lieu d'un simple statut muet.
  final String? cancellationReason;
}

final studentPaymentsProvider = StreamProvider.autoDispose
    .family<List<PaymentRow>, String>((ref, studentId) {
  final yearId = ref.watch(activeYearIdProvider);
  if (yearId == null) return Stream.value(const []);
  return db.watch(
    '''
    SELECT sp.*, f.name AS fee_name
    FROM student_payments sp
    LEFT JOIN fee_structures f ON f.id = sp.fee_structure_id
    WHERE sp.student_id = ? AND sp.academic_year_id = ?
    ORDER BY sp.payment_date DESC, sp.created_at DESC
    ''',
    parameters: [studentId, yearId],
  ).map((rows) => [
        for (final r in rows)
          PaymentRow(
            id: r['id'] as String,
            amount: (r['amount_xaf'] as num?)?.round() ?? 0,
            date: r['payment_date'] as String?,
            method: r['payment_method'] as String?,
            status: r['status'] as String?,
            feeName: r['fee_name'] as String?,
            receipt: r['receipt_number'] as String?,
            cancellationReason: r['cancellation_reason'] as String?,
          ),
      ]);
});

// ─── Annulation ──────────────────────────────────────────────────────────────

/// Statuts depuis lesquels une annulation a un sens.
///
/// Ni `cancelled` (déjà fait) ni `refunded` : rembourser puis annuler ferait
/// disparaître la trace de la restitution, et la caisse mentirait deux fois.
const _kAnnulables = {'confirmed', 'pending'};

bool peutAnnulerPaiement(String? status) => _kAnnulables.contains(status);

/// Longueur en deçà de laquelle un motif n'explique rien.
const int kMotifAnnulationMin = 5;

/// `null` si le motif convient, sinon le message à montrer à l'utilisateur.
String? motifAnnulationInvalide(String motif) {
  final m = motif.trim();
  if (m.isEmpty) return 'Le motif de l\'annulation est obligatoire';
  if (m.length < kMotifAnnulationMin) {
    return 'Motif trop court — expliquez ce qui s\'est passé';
  }
  return null;
}

// ─── Remboursement ───────────────────────────────────────────────────────────

/// On ne rend que ce qu'on a confirmé avoir reçu. Un paiement `pending` n'est
/// pas encore de l'argent en caisse ; un paiement annulé ou déjà remboursé
/// n'en est plus.
bool peutRembourserPaiement(String? status) => status == 'confirmed';

/// `null` si le montant convient, sinon le message à montrer.
///
/// Le `CHECK` serveur de la migration 0094 refuse déjà un remboursement
/// supérieur à l'encaissé — mais un refus serveur arrive APRÈS la synchro, et
/// coûte la transaction. Le dire ici, c'est le dire à temps.
String? montantRemboursementInvalide(int montant, int encaisse) {
  if (montant <= 0) return 'Le montant remboursé doit être supérieur à zéro';
  if (montant > encaisse) {
    return 'On ne rembourse pas plus que les ${encaisse.toString()} F encaissés';
  }
  return null;
}

Future<void> refundPayment({
  required String id,
  required int montant,
  required int encaisse,
  required String motif,
  required String actorId,
}) async {
  final probleme = montantRemboursementInvalide(montant, encaisse);
  if (probleme != null) throw ArgumentError(probleme);
  final m = motif.trim();
  if (m.isEmpty) throw ArgumentError('Le motif du remboursement est obligatoire');
  final now = DateTime.now().toIso8601String();
  await db.execute(
    'UPDATE student_payments SET status = ?, refunded_amount_xaf = ?, '
    'refunded_at = ?, refunded_by = ?, refund_reason = ?, updated_at = ? '
    'WHERE id = ?',
    ['refunded', montant, now, actorId, m, now, id],
  );
}

// ─── Numérotation des reçus ──────────────────────────────────────────────────

/// Le prochain numéro libre pour CE poste, dans CETTE école, pour CETTE année.
///
/// La séquence est relue dans la base locale à chaque encaissement plutôt que
/// tenue dans un compteur : après une purge du poste les paiements redescendent
/// par la synchro, et un compteur reparti à zéro rééditerait des numéros déjà
/// émis — chaque doublon coûtant un paiement (cf. `receipt_number.dart`).
///
/// Le code de l'école est relu ici, et non passé par l'appelant : l'écran est
/// un fichier `part` où `db` n'est pas en portée, et le numéroteur est de toute
/// façon le seul à en avoir besoin.
Future<String> genererNumeroRecu({
  required String schoolId,
  required DateTime quand,
}) async {
  final tag = await posteTag();
  final ecole = await db.getOptional(
      'SELECT school_code FROM schools WHERE id = ?', [schoolId]);
  final schoolCode = ecole?['school_code'] as String?;
  final prefixe =
      prefixeRecu(schoolCode: schoolCode, year: quand.year, posteTag: tag);
  final rows = await db.getAll(
    'SELECT receipt_number FROM student_payments '
    'WHERE school_id = ? AND receipt_number LIKE ?',
    [schoolId, '$prefixe%'],
  );
  final seq = prochaineSequence(
    rows.map((r) => r['receipt_number'] as String?),
    prefixe: prefixe,
  );
  return formatReceiptNumber(
    schoolCode: schoolCode,
    year: quand.year,
    posteTag: tag,
    sequence: seq,
  );
}

// ─── Mutations ───────────────────────────────────────────────────────────────
Future<void> savePayment({
  String? id,
  required String groupId,
  required String schoolId,
  required String academicYearId,
  required String studentId,
  String? enrollmentId,
  String? feeStructureId,
  required int amount,
  required String date,
  required String method,
  required String status,
  String? notes,
  required String recordedBy,
}) async {
  final now = DateTime.now().toIso8601String();
  final d = DateTime.tryParse(date) ?? DateTime.now();
  if (id != null) {
    await db.execute(
      'UPDATE student_payments SET fee_structure_id = ?, amount_xaf = ?, '
      'payment_date = ?, payment_method = ?, status = ?, notes = ?, '
      'period_month = ?, period_year = ?, updated_at = ? WHERE id = ?',
      [feeStructureId, amount, date, method, status, notes, d.month, d.year,
       now, id],
    );
  } else {
    final receipt = await genererNumeroRecu(schoolId: schoolId, quand: d);
    await db.execute(
      '''
      INSERT INTO student_payments (
        id, group_id, school_id, academic_year_id, student_id, enrollment_id,
        fee_structure_id, amount_xaf, payment_date, period_month, period_year,
        payment_method, receipt_number, recorded_by, status, notes,
        created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [_uuid.v4(), groupId, schoolId, academicYearId, studentId, enrollmentId,
       feeStructureId, amount, date, d.month, d.year, method, receipt,
       recordedBy, status, notes, now, now],
    );
  }
}

/// Annule un encaissement SANS l'effacer : la ligne reste, son auteur et son
/// motif avec elle. Un CHECK serveur (migration 0094) refuse une annulation
/// muette — la validation locale est là pour que l'utilisateur le sache avant
/// la synchro, pas à la place du serveur.
Future<void> cancelPayment({
  required String id,
  required String motif,
  required String actorId,
}) async {
  final probleme = motifAnnulationInvalide(motif);
  if (probleme != null) throw ArgumentError(probleme);
  final now = DateTime.now().toIso8601String();
  await db.execute(
    'UPDATE student_payments SET status = ?, cancelled_at = ?, '
    'cancelled_by = ?, cancellation_reason = ?, updated_at = ? WHERE id = ?',
    ['cancelled', now, actorId, motif.trim(), now, id],
  );
}
