// ════════════════════════════════════════════════════════════════════════════
//  FRAIS D'EXAMEN — un revenu de l'école, donc du groupe scolaire.
//
//  ── La dette n'est jamais matérialisée ─────────────────────────────────────
//  Aucune ligne de paiement « en attente » n'est créée à l'inscription. Elle
//  serait plus simple à lire, et FAUSSE : ces lignes finiraient comptées comme
//  du revenu, ou devraient être purgées à chaque désinscription. La dette se
//  DÉRIVE — inscrits × montant − encaissé — et le revenu ne compte que l'argent
//  réellement reçu. Même principe que `missing_documents` : on ne stocke jamais
//  deux fois la même vérité.
//
//  ── Tout est en entiers (XAF) ──────────────────────────────────────────────
//  Le franc CFA n'a pas de subdivision en usage ; `student_payments.amount_xaf`
//  est un entier. Passer par des flottants introduirait des centimes qui
//  n'existent pas et des totaux qui ne tombent jamais juste.
// ════════════════════════════════════════════════════════════════════════════

/// Où en est UN candidat vis-à-vis de ses frais.
enum FeePaymentState {
  impaye,
  partiel,

  /// Soldé : le dû est couvert. Couvre aussi le surpaiement (appoint d'un
  /// parent) et le cas « rien à devoir » — ne rien devoir n'est pas être en
  /// dette.
  solde,
}

FeePaymentState feeStateFor({required int due, required int paid}) {
  if (paid >= due) return FeePaymentState.solde;
  return paid <= 0 ? FeePaymentState.impaye : FeePaymentState.partiel;
}

String feeStateLabel(FeePaymentState s) => switch (s) {
      FeePaymentState.impaye => 'Impayé',
      FeePaymentState.partiel => 'Partiel',
      FeePaymentState.solde => 'Soldé',
    };

/// Le recouvrement d'une session pour UNE école.
class ExamFeeSummary {
  const ExamFeeSummary({
    required this.amountPerCandidate,
    required this.candidates,
    required this.collected,
  });

  final int amountPerCandidate;
  final int candidates;
  final int collected;

  int get expected => amountPerCandidate * candidates;

  /// Jamais négatif : une dette négative n'existe pas. Un encaissement au-delà
  /// de l'attendu (appoints, arrondis) laisse simplement un reste nul.
  int get remaining {
    final r = expected - collected;
    return r < 0 ? 0 : r;
  }

  /// Taux de recouvrement, borné à 100 %. Vaut 0 quand rien n'est attendu —
  /// une école qui n'a pas fixé ses frais ne doit pas lire « 100 % recouvré ».
  double get rate {
    if (expected <= 0) return 0;
    final r = collected / expected;
    return r > 1 ? 1.0 : r;
  }
}

ExamFeeSummary summarizeExamFees({
  required int amountPerCandidate,
  required int candidates,
  required Iterable<int> payments,
}) =>
    ExamFeeSummary(
      amountPerCandidate: amountPerCandidate,
      candidates: candidates,
      collected: payments.fold(0, (a, b) => a + b),
    );
