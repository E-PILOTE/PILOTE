// ============================================================================
// Edge Function : subscription-reminder-emailer
// ----------------------------------------------------------------------------
// Canal HORS-APP des rappels d'échéance (audit national #2). Double le canal
// in-app (cloche) par un EMAIL au payeur, car l'admin_groupe n'ouvre pas l'app
// tous les jours. Envoi via CLOUDFLARE EMAIL SERVICE (domaine epilote.org déjà
// chez Cloudflare ; supporte les destinataires arbitraires).
//
// Déclenchée par pg_cron (via pg_net) peu après le cron de génération des
// rappels (emit_subscription_reminders). Idempotente : chaque notification
// 'subscription' non encore envoyée par email (data.emailed != true) est traitée
// une seule fois (on repose data.emailed = true après envoi réussi).
//
// FAIL-SOFT / DORMANT : sans CF_EMAIL_API_TOKEN + CF_ACCOUNT_ID, la fonction ne
// fait RIEN (200 « dormant ») — aucune erreur, aucun envoi. Activation = poser
// les secrets. Le token N'EST JAMAIS exposé côté client (server-side only).
//
// Secrets attendus (supabase secrets set) :
//   CF_EMAIL_API_TOKEN  token API Cloudflare avec permission « Email Sending: Edit »
//   CF_ACCOUNT_ID       identifiant de compte Cloudflare
//   CF_EMAIL_FROM       expéditeur (déf. "E-PILOTE CONGO <noreply@mail.epilote.org>")
//   SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY  injectés automatiquement
// verify_jwt = true : l'appelant (pg_net) doit présenter un JWT projet valide.
// ============================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const json = (body: unknown, status = 200): Response =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

const escapeHtml = (s: string): string =>
  s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok");

  try {
    const CF_TOKEN = Deno.env.get("CF_EMAIL_API_TOKEN");
    const CF_ACCOUNT = Deno.env.get("CF_ACCOUNT_ID");
    const CF_FROM =
      Deno.env.get("CF_EMAIL_FROM") ?? "E-PILOTE CONGO <noreply@mail.epilote.org>";

    // DORMANT tant que les secrets ne sont pas posés : aucun envoi, aucune erreur.
    if (!CF_TOKEN || !CF_ACCOUNT) {
      return json({ status: "dormant", reason: "CF_EMAIL_API_TOKEN/CF_ACCOUNT_ID unset" });
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

    const endpoint =
      `https://api.cloudflare.com/client/v4/accounts/${CF_ACCOUNT}/email/sending/send`;

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

      const html =
        `<p>${escapeHtml(n.body)}</p>` +
        `<p style="color:#64748b;font-size:12px">— E-PILOTE CONGO</p>`;

      const res = await fetch(endpoint, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${CF_TOKEN}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          from: CF_FROM,
          to: email,
          subject: n.title,
          html,
        }),
      });

      // Cloudflare renvoie { success: true, ... } en cas de succès.
      let ok = res.ok;
      try {
        const r = await res.json();
        ok = ok && r?.success !== false;
      } catch (_) { /* corps non-JSON : on se fie au statut HTTP */ }

      if (ok) {
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

    return json({ status: "ok", provider: "cloudflare", sent, skipped, failed });
  } catch (e) {
    return json({ status: "error", error: `${e}` }, 500);
  }
});
