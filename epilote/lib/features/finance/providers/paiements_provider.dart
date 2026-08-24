import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../services/powersync/powersync_service.dart';
import '../../classes/providers/class_provider.dart';
import '../../structure/providers/academic_year_context.dart';
import '../../vie_scolaire/widgets/vs_kit.dart';
import '../services/bareme_applicable.dart';
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

/// Écarte les versements rattachés à un frais d'EXAMEN du recouvrement de
/// scolarité.
///
/// Contrepartie obligatoire de l'exclusion posée dans `duScolarite` : si le dû
/// ne compte plus les frais d'examen mais que le versé les compte encore, un
/// candidat ayant réglé ses 30 000 F d'examen paraît à jour d'une scolarité
/// qu'il n'a pas payée. Les deux côtés doivent bouger ensemble.
///
/// ⚠️ `COALESCE(..., '')` : un versement sans barème rattaché reste compté —
/// une comparaison à NULL l'aurait fait disparaître en silence.
///
/// L'historique des versements d'un élève, lui, n'est PAS filtré : c'est le
/// registre des reçus, il doit tout montrer.
String _horsFraisExamens(String alias) =>
    'AND COALESCE((SELECT f.fee_type FROM fee_structures f '
    "WHERE f.id = $alias.fee_structure_id), '') <> 'frais_examens'";

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
    this.duParClasse = const {},
    this.encaisseParClasse = const {},
  });
  final List<VsCoverageRow> rows;
  final int collected, confirmedCount, pendingCount, payers, students;

  /// Somme de ce que l'école devrait avoir encaissé à ce jour, et nombre
  /// d'élèves qui ont soldé leur dû. `duTotal == 0` ⇒ aucun barème applicable :
  /// afficher un taux serait mentir (cf. `EtatObligation.sansBareme`).
  final int duTotal, aJour;

  /// Le même dû et le même encaissé, ventilés par classe — indexés par
  /// `classId`. L'état de recouvrement imprimé les réclame ligne par ligne, et
  /// il doit se lire sur les MÊMES nombres que l'écran : un rapport officiel
  /// qui ne retombe pas sur le total affiché n'est pas défendable devant une
  /// direction départementale.
  final Map<String, int> duParClasse, encaisseParClasse;

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
  final calendrier = ref.watch(calendrierDuProvider);
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
    'sp.refunded_amount_xaf AS remb, sp.status AS st '
    'FROM student_payments sp '
    "JOIN class_enrollments ce ON ce.student_id = sp.student_id AND ce.status = 'active' "
    'WHERE ce.class_id IN ($ph) AND sp.academic_year_id = ? '
    '${_horsFraisExamens('sp')}',
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
    final net = montantNet(
      status: st,
      montant: (r['amt'] as num?)?.round() ?? 0,
      rembourse: (r['remb'] as num?)?.round(),
    );
    if (net > 0) {
      collected += net;
      collectedByClass[cid] = (collectedByClass[cid] ?? 0) + net;
      verseParEleve[sid] = (verseParEleve[sid] ?? 0) + net;
      confirmedCount++;
      (payersByClass[cid] ??= {}).add(sid);
      allPayers.add(sid);
    } else if (st == 'pending') {
      pendingCount++;
    }
  }

  // Le NIVEAU choisit les barèmes (un barème peut ne viser qu'un niveau), donc
  // le tarif est bien celui de la classe. Mais le MONTANT dû ne l'est plus :
  // il dépend du nombre de mois que chaque élève a réellement passés dans
  // l'école (cf. `CalendrierDu`). Un élève arrivé en mars ne doit pas ce que
  // doit son voisin présent depuis la rentrée.
  final niveauParClasse = {for (final c in classes) c.id: c.levelId};

  // Qui a soldé, et combien l'école devrait avoir encaissé : les deux se
  // comptent élève par élève. Il faut donc TOUS les inscrits, pas seulement
  // ceux qui ont payé — un élève absent de `verseParEleve` a versé zéro.
  //
  // ⚠️ `duTotal` se sommait avant en `dû de la classe × c.studentCount`. Le
  // défaut n'était PAS l'effectif — `student_count` est dérivé par
  // `classesProvider` d'un `COUNT(*)` sur les inscriptions actives, il est
  // juste. C'est le MULTIPLICANDE qui l'était devenu : depuis que le dû dépend
  // de la fenêtre de présence et de l'exonération, il n'existe plus de « dû de
  // la classe » à multiplier. Deux élèves du même rang doivent des sommes
  // différentes, et c'est voulu.
  final aJourParClasse = <String, int>{};
  final effectifParClasse = <String, int>{};
  final duParClasse = <String, int>{};
  var duTotal = 0;
  {
    // ⚠️ Cette lecture a lieu MÊME sans barème : elle sert aussi d'effectif.
    // Une école publique sans tarif posé — il y en a une trentaine — verrait
    // sinon ses classes à zéro élève sur la page Paiements.
    //
    // ⚠️ Le second filtre — `students.is_active` — n'est pas cosmétique : un
    // élève retiré du registre continuait de DEVOIR de l'argent. L'école ne le
    // voyait plus dans sa liste, ne pouvait donc plus le relancer, et son dû
    // pesait indéfiniment sur le taux de recouvrement de l'établissement.
    final inscrits = await db.getAll(
      'SELECT ce.class_id AS cid, ce.student_id AS sid, '
      'ce.enrollment_date AS entree, ce.withdrawal_date AS sortie, '
      'ce.exemption_rate AS exo '
      'FROM class_enrollments ce '
      'JOIN students s ON s.id = ce.student_id '
      "WHERE ce.class_id IN ($ph) AND ce.status = 'active' "
      'AND COALESCE(s.is_active, 1) <> 0',
      ids,
    );
    for (final e in inscrits) {
      final cid = e['cid'] as String;
      effectifParClasse[cid] = (effectifParClasse[cid] ?? 0) + 1;
      if (baremes.isEmpty) continue;
      final mois = calendrier.moisPour(
        entree: e['entree'] as String?,
        sortie: e['sortie'] as String?,
      );
      // La décision — dû après remise, état, « compte parmi les à jour » —
      // vit dans `recouvrementEleve`, verrouillée par `recouvrement_test.dart`.
      final r = recouvrementEleve(
        baremes,
        levelId: niveauParClasse[cid],
        mois: mois,
        verse: verseParEleve[e['sid'] as String] ?? 0,
        exoneration: (e['exo'] as num?)?.round(),
      );
      duTotal += r.du;
      duParClasse[cid] = (duParClasse[cid] ?? 0) + r.du;
      if (r.aJour) {
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
        // Numérateur et dénominateur comptés sur la MÊME lecture.
        //
        // `c.studentCount` donnerait aujourd'hui le même nombre : il est dérivé
        // du même `COUNT(*)` sur les inscriptions actives (`classesProvider`).
        // Le prendre ici ferait pourtant dépendre le taux de recouvrement de
        // deux requêtes que rien n'oblige à rester d'accord — et le jour où
        // l'une des deux gagne un filtre, « 12 à jour sur 9 » devient
        // affichable sans qu'aucun test ne le voie.
        total: effectifParClasse[c.id] ?? 0,
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
    duTotal: duTotal,
    aJour: aJourParClasse.values.fold(0, (a, b) => a + b),
    duParClasse: duParClasse,
    encaisseParClasse: collectedByClass,
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
    this.duAvantExoneration = 0,
    this.exoneration,
    this.motifExoneration,
  });
  final String studentId, studentName;
  final String? enrollmentId, matricule, lastDate;
  final int paid, count;

  /// Ce que cet élève doit à ce jour, tous barèmes applicables confondus —
  /// exonération DÉJÀ déduite.
  final int du;

  /// Le taux d'exonération de scolarité accordé pour cette année (%), et sa
  /// justification. `null` = aucune exonération.
  ///
  /// Portés jusqu'ici pour que l'écran puisse EXPLIQUER un dû réduit. Un
  /// montant plus bas que celui du voisin, sans raison affichée, se lit comme
  /// un bug — et se signale au support.
  final int? exoneration;
  final String? motifExoneration;

  /// Le même dû AVANT remise. Sert à distinguer « aucun tarif publié » de
  /// « tarif intégralement remis » — deux dûs nuls qui ne veulent pas dire la
  /// même chose (cf. [EtatObligation.exonere]).
  final int duAvantExoneration;

  bool get estExonere => (exoneration ?? 0) > 0;
  bool get baremeDefini => duAvantExoneration > 0;

  int get reste => (du - paid).clamp(0, du);
  EtatObligation get etat => etatObligation(
        du: du,
        verse: paid,
        exonereTotal: baremeDefini && du <= 0,
      );

  /// ⚠️ « a versé quelque chose » — ce n'est PAS « à jour ». Conservé pour les
  /// usages qui veulent seulement savoir si un mouvement existe.
  bool get hasPaid => paid > 0;
}

final classPaymentsProvider = StreamProvider.autoDispose
    .family<List<StudentPayRow>, String>((ref, classId) {
  final yearId = ref.watch(activeYearIdProvider);
  final baremes = ref.watch(baremesApplicablesProvider).valueOrNull ?? const [];
  final calendrier = ref.watch(calendrierDuProvider);
  final niveau = ref
      .watch(classesProvider)
      .valueOrNull
      ?.where((c) => c.id == classId)
      .firstOrNull
      ?.levelId;
  if (yearId == null) return Stream.value(const []);
  return db.watch(
    '''
    SELECT s.id AS sid, ce.id AS enr, s.first_name, s.last_name, s.matricule,
      ce.enrollment_date AS entree, ce.withdrawal_date AS sortie,
      ce.exemption_rate AS exo, ce.exemption_motif AS exo_motif,
      -- Net encaissé : un remboursement PARTIEL laisse la ligne `confirmed`
      -- mais n'a plus rapporté que la différence ; un remboursement TOTAL
      -- passe en `refunded` et ne rapporte rien (cf. `montantNet`).
      -- Scolarité seule : les frais d'examen relèvent du module Examens, qui
      -- connaît les candidats (cf. `_horsFraisExamens` et `duScolarite`).
      -- ⚠️ Le `MAX(…, 0)` par ligne : le `CHECK` de la migration 0094 interdit
      -- un remboursement supérieur à l'encaissé, mais SQLite local n'a pas ce
      -- `CHECK`. Une saisie hors ligne aberrante rendrait ici un net négatif
      -- qui viendrait manger un AUTRE versement du même élève. Les quatre
      -- autres requêtes de la caisse portent déjà ce garde-fou.
      (SELECT COALESCE(SUM(MAX(p.amount_xaf - COALESCE(p.refunded_amount_xaf, 0), 0)), 0)
         FROM student_payments p
        WHERE p.student_id = s.id
          AND p.status IN ('confirmed', 'refunded')
          AND p.academic_year_id = ?1
          ${_horsFraisExamens('p')}) AS paid,
      -- Le compte et la date suivent le même périmètre que le montant : sinon
      -- un élève n'ayant réglé que ses frais d'examen afficherait « 1 versement
      -- le 12/03 » en face de 0 F versé.
      (SELECT COUNT(*) FROM student_payments p
        WHERE p.student_id = s.id AND p.academic_year_id = ?1
          ${_horsFraisExamens('p')}) AS cnt,
      (SELECT MAX(payment_date) FROM student_payments p
        WHERE p.student_id = s.id AND p.academic_year_id = ?1
          ${_horsFraisExamens('p')}) AS last_d
    FROM class_enrollments ce
    JOIN students s ON s.id = ce.student_id
    -- ⚠️ Même règle que l'effectif : un élève retiré du registre actif ne
    -- figure plus au guichet. Sans ce filtre, la caisse continuait de le
    -- présenter comme débiteur d'une classe où il n'est plus compté.
    WHERE ce.class_id = ?2 AND ce.status = 'active'
      AND COALESCE(s.is_active, 1) <> 0
    ORDER BY s.last_name, s.first_name
    ''',
    parameters: [yearId, classId],
  ).map((rows) => [
        for (final r in rows) _ligneEleve(r, baremes, calendrier, niveau),
      ]);
});

/// ⚠️ Le dû se calcule ICI, élève par élève, et non une fois pour la classe :
/// deux élèves du même rang — l'un présent depuis la rentrée, l'autre arrivé en
/// mars ; l'un boursier, l'autre non — ne doivent pas la même somme.
///
/// Passe par `recouvrementEleve`, comme `paymentsOverviewProvider` : cet écran
/// affiche le détail dont l'autre affiche le total. Deux calculs séparés
/// auraient fini par se contredire à l'écran, et c'est exactement le défaut qui
/// avait produit le bug des mentions.
StudentPayRow _ligneEleve(
  Map<String, dynamic> r,
  List<LigneBareme> baremes,
  CalendrierDu calendrier,
  String? niveau,
) {
  final rec = recouvrementEleve(
    baremes,
    levelId: niveau,
    mois: calendrier.moisPour(
      entree: r['entree'] as String?,
      sortie: r['sortie'] as String?,
    ),
    verse: (r['paid'] as num?)?.round() ?? 0,
    exoneration: (r['exo'] as num?)?.round(),
  );
  return StudentPayRow(
    studentId: r['sid'] as String,
    enrollmentId: r['enr'] as String?,
    studentName: '${(r['last_name'] as String?) ?? ''} '
            '${(r['first_name'] as String?) ?? ''}'
        .trim(),
    matricule: r['matricule'] as String?,
    paid: (r['paid'] as num?)?.round() ?? 0,
    count: (r['cnt'] as num?)?.round() ?? 0,
    lastDate: r['last_d'] as String?,
    du: rec.du,
    duAvantExoneration: rec.duBrut,
    exoneration: (r['exo'] as num?)?.round(),
    motifExoneration: r['exo_motif'] as String?,
  );
}

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

/// Ce qu'un encaissement rapporte RÉELLEMENT à la caisse.
///
/// ⚠️ Un remboursement PARTIEL bascule la ligne en `refunded` alors qu'une part
/// de l'argent est restée. Compter les seules lignes `confirmed` retirait donc
/// la totalité de l'encaissement — 2 000 F disparaissaient de la recette pour
/// 1 000 F rendus, et l'élève repassait « impayé ». Constaté à l'écran le
/// 2026-08-05.
///
/// Un paiement annulé ou en attente ne rapporte rien : dans un cas l'argent
/// n'est plus là, dans l'autre il n'y est pas encore.
int montantNet({
  required String? status,
  required int montant,
  required int? rembourse,
}) {
  if (status != 'confirmed' && status != 'refunded') return 0;
  final net = montant - (rembourse ?? 0);
  return net > 0 ? net : 0;
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
  // ⚠️ `refunded` ne se pose que sur un remboursement TOTAL. Le poser sur un
  // remboursement partiel ferait mentir l'étiquette — et, tant que les lecteurs
  // s'y fiaient, faisait disparaître la part conservée (cf. `montantNet`).
  final statut = montant >= encaisse ? 'refunded' : 'confirmed';
  await db.execute(
    'UPDATE student_payments SET status = ?, refunded_amount_xaf = ?, '
    'refunded_at = ?, refunded_by = ?, refund_reason = ?, updated_at = ? '
    'WHERE id = ?',
    [statut, montant, now, actorId, m, now, id],
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
/// Enregistre un encaissement et rend son NUMÉRO DE REÇU (`null` sur une
/// modification, qui conserve le numéro d'origine).
///
/// ⚠️ Le numéro remonte parce que le reçu doit pouvoir s'imprimer dans la
/// foulée, au guichet, devant la famille. Le garder à l'intérieur obligeait à
/// ressortir de l'écran, ouvrir Paiements, retrouver l'élève — c'est-à-dire, en
/// pratique, à ne pas remettre de reçu du tout. Or au Congo le reçu EST la
/// preuve du paiement.
Future<String?> savePayment({
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
    return null;
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
    return receipt;
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
