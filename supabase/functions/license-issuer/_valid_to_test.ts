import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { computeValidTo, computeOfflineWindowSeconds } from "./_valid_to.ts";

const now = new Date("2026-07-04T12:00:00Z");

Deno.test("confirmé + fin future → valid_to = fin d'abonnement", () => {
  assertEquals(computeValidTo("2027-01-01", true, now, 7), "2027-01-01T00:00:00.000Z");
});

Deno.test("NON confirmé + fin lointaine → plafonné à now+7j (provisoire)", () => {
  assertEquals(computeValidTo("2027-01-01", false, now, 7), "2026-07-11T12:00:00.000Z");
});

Deno.test("NON confirmé + fin proche → garde la fin (MIN)", () => {
  assertEquals(computeValidTo("2026-07-06", false, now, 7), "2026-07-06T00:00:00.000Z");
});

Deno.test("NON confirmé + pas de fin → plafonné", () => {
  assertEquals(computeValidTo(null, false, now, 7), "2026-07-11T12:00:00.000Z");
});

Deno.test("confirmé + pas de fin → null (perpétuel)", () => {
  assertEquals(computeValidTo(null, true, now, 7), null);
});

// G3 — fenêtre adaptative
Deno.test("fenêtre : défaut généreux si pas d'override", () => {
  assertEquals(computeOfflineWindowSeconds(null, true, 30, 7), 30 * 86400);
});
Deno.test("fenêtre : override par zone respecté", () => {
  assertEquals(computeOfflineWindowSeconds(60, true, 30, 7), 60 * 86400);
});
Deno.test("fenêtre : paiement non confirmé → provisoire courte (prime sur l'override)", () => {
  assertEquals(computeOfflineWindowSeconds(60, false, 30, 7), 7 * 86400);
});
Deno.test("fenêtre : override <=0 ignoré → défaut", () => {
  assertEquals(computeOfflineWindowSeconds(0, true, 30, 7), 30 * 86400);
});
