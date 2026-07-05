// ============================================================================
// Edge Function : subscription-reminder-emailer
// ----------------------------------------------------------------------------
// Canal HORS-APP des rappels d'échéance (audit national #2). Double le canal
// in-app (cloche) par un EMAIL au payeur, car l'admin_groupe n'ouvre pas l'app
// tous les jours. Envoi via Resend.
//
// Déclenchée par pg_cron (via pg_net) peu après le cron de génération des
// rappels (emit_subscription_reminders). Idempotente : chaque notification
// 'subscription' non encore envoyée par email (data.emailed != true) est traitée
// une seule fois (on repose data.emailed = true après envoi réussi).
//
// FAIL-SOFT / DORMANT : sans RESEND_API_KEY, la fonction ne fait RIEN (200
// « dormant ») — aucune erreur, aucun envoi. Activation = poser les secrets.
//
// Secrets attendus (supabase secrets set) :
//   RESEND_API_KEY   clé API Resend (obligatoire pour activer l'envoi)
//   RESEND_FROM      expéditeur vérifié (ex. "E-PILOTE <no-reply@e-pilote.cg>")
//   SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY  injectés automatiquement
// verify_jwt = true : l'appelant (pg_net) doit présenter un JWT projet valide
//   (service_role) → non appelable publiquement.
// ============================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const json = (body: unknown, status = 200): Response =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok");

  try {
    const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");
    const RESEND_FROM =
      Deno.env.get("RESEND_FROM") ?? "E-PILOTE <no-reply@e-pilote.cg>";

    // DORMANT tant que la clé n'est pas posée : aucun envoi, aucune erreur.
    if (!RESEND_API_KEY) {
      return json({ status: "dormant", reason: "RESEND_API_KEY unset" });
    }

    const url = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const admin = createClient(url, serviceKey);

    // Rappels 'subscription' des dernières 24 h non encore envoyés par email.
    const since = new Date(Date.now() - 24 * 3600 * 1000).toISOString();
    const { data: notifs, error } = await admin
      .from("notifications")
      .select("id, recipient_id, title, body, data")
      .eq("type", "subscription")
      .gte("created_at", since)
      .limit(1000);
    if (error) return json({ status: "error", error: `${error.message}` }, 500);

    let sent = 0, skipped = 0, failed = 0;

    for (const n of notifs ?? []) {
      // Idempotence : déjà envoyé pour cette notification → on saute.
      if (n.data && (n.data as Record<string, unknown>).emailed === true) {
        skipped++;
        continue;
      }

      // Résolution de l'email du destinataire (profiles n'a pas d'email → auth.users).
      const { data: u } = await admin.auth.admin.getUserById(n.recipient_id);
      const email = u?.user?.email;
      if (!email) {
        skipped++;
        continue;
      }

      const res = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${RESEND_API_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          from: RESEND_FROM,
          to: email,
          subject: n.title,
          text: `${n.body}\n\n— E-PILOTE CONGO`,
        }),
      });

      if (res.ok) {
        await admin
          .from("notifications")
          .update({
            data: { ...(n.data as Record<string, unknown> ?? {}), emailed: true },
          })
          .eq("id", n.id);
        sent++;
      } else {
        // Fail-soft : on ne marque PAS emailed → réessai au prochain run.
        failed++;
      }
    }

    return json({ status: "ok", sent, skipped, failed });
  } catch (e) {
    return json({ status: "error", error: `${e}` }, 500);
  }
});
