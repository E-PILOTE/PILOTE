// C4 — calcul du `valid_to` de la licence (2 étages). Extrait pour être testable
// (deno test) : la fonction déployée l'importe → deployé == testé, zéro drift.
//
// - paiement CONFIRMÉ  → valid_to = fin d'abonnement (ou null si perpétuel).
// - paiement NON confirmé → licence PROVISOIRE : valid_to = MIN(fin, now + N jours).
//   Ainsi un paiement qui échoue ne laisse jamais une licence pleine durée.
export function computeValidTo(
  subscriptionEnd: string | null,
  paymentConfirmed: boolean,
  now: Date,
  provisionalDays: number,
): string | null {
  const fullValidTo = subscriptionEnd
    ? new Date(subscriptionEnd + "T00:00:00Z")
    : null;
  let validTo = fullValidTo;
  if (paymentConfirmed === false) {
    const cap = new Date(now.getTime() + provisionalDays * 86400000);
    validTo = (fullValidTo && fullValidTo < cap) ? fullValidTo : cap;
  }
  return validTo ? validTo.toISOString() : null;
}
