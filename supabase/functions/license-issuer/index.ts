// ============================================================================
// Edge Function : license-issuer
// ----------------------------------------------------------------------------
// ⚠️ STATUT : ARTEFACT REVU, **NON DÉPLOYÉ**, non vérifié end-to-end.
//    Déploiement = acte de PRODUCTION délibéré (allume l'enforcement). Voir la
//    procédure de go-live pilote : docs/LICENCE_GOLIVE.md.
//
// Rôle : émettre une LICENCE signée Ed25519 (JWS compact) pour le GROUPE du
// personnel authentifié, projection de son abonnement (cf. ADR-0001/0002/0003).
// La clé PRIVÉE ne vit QUE dans les secrets de cette fonction (jamais dans l'app).
//
// Secrets attendus (supabase secrets set) :
//   LICENSE_PRIVATE_KEY_PKCS8_B64  base64 du PKCS8 de la clé privée Ed25519
//   LICENSE_KID                    identifiant de clé (ex. "2026-07")
//   LICENSE_OFFLINE_WINDOW_DAYS    fenêtre de confiance (déf. 30)
// ============================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { computeValidTo, computeOfflineWindowSeconds } from "./_valid_to.ts";

const b64uEncode = (bytes: Uint8Array): string =>
  btoa(String.fromCharCode(...bytes)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

const b64Decode = (s: string): Uint8Array =>
  Uint8Array.from(atob(s), (c) => c.charCodeAt(0));

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ error: "unauthenticated" }, 401);

    const url = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    // 1) Identifier l'appelant à partir de SON jeton (jamais un group_id client).
    const asUser = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userRes, error: userErr } = await asUser.auth.getUser();
    if (userErr || !userRes.user) return json({ error: "unauthenticated" }, 401);
    const uid = userRes.user.id;

    // 2) Lire (service role) le groupe du profil + son plan/abonnement.
    const admin = createClient(url, serviceKey);
    const { data: profile } = await admin
      .from("profiles").select("group_id").eq("id", uid).maybeSingle();
    const groupId = profile?.group_id as string | undefined;
    if (!groupId) return json({ error: "no_group" }, 403);

    // GARDE-PILOTE : si LICENSE_PILOT_GROUP_IDS est DÉFINIE (même vide), on
    // n'émet QUE pour les groupes listés → rollout contrôlé (déploiement sûr :
    // liste vide = personne). Retirer complètement la variable = fleet-wide.
    const pilotEnv = Deno.env.get("LICENSE_PILOT_GROUP_IDS");
    if (pilotEnv !== undefined) {
      const allow = pilotEnv.split(",").map((s) => s.trim()).filter(Boolean);
      if (!allow.includes(groupId)) return json({ error: "not_in_pilot" }, 403);
    }

    const { data: group } = await admin
      .from("school_groups")
      .select("plan_id, subscription_status, subscription_end, payment_confirmed, offline_window_days, updated_at")
      .eq("id", groupId).maybeSingle();
    if (!group) return json({ error: "no_group" }, 404);

    // 3) Modules accordés = plan_modules du plan courant (miroir de l'existant :
    //    un groupe ACTIF ne perd rien ; seul un groupe échu se dégrade).
    const { data: pm } = await admin
      .from("plan_modules")
      .select("modules(slug, is_active)")
      .eq("plan_id", group.plan_id);
    const modules = (pm ?? [])
      .map((r: any) => r.modules)
      .filter((m: any) => m && m.is_active)
      .map((m: any) => m.slug);

    // 4) Construire les claims. `version` = compteur monotone autoritaire
    //    (mig 0026 : next_license_version), incrémenté à chaque émission.
    const nowIso = new Date().toISOString();
    const defaultOfflineDays = parseInt(Deno.env.get("LICENSE_OFFLINE_WINDOW_DAYS") ?? "30", 10);
    const { data: version, error: verErr } = await admin.rpc(
      "next_license_version", { p_group: groupId });
    if (verErr || version == null) return json({ error: "version_failed" }, 500);

    // C4 — 2 étages (logique extraite/testée dans _valid_to.ts).
    const provisionalDays = parseInt(Deno.env.get("LICENSE_PROVISIONAL_DAYS") ?? "7", 10);
    const validToIso = computeValidTo(
      group.subscription_end, group.payment_confirmed, new Date(), provisionalDays);

    const payload = {
      group_id: groupId,
      plan: group.plan_id,
      modules,
      quotas: {},
      valid_from: nowIso,
      valid_to: validToIso,
      offline_window: computeOfflineWindowSeconds(
        group.offline_window_days, group.payment_confirmed,
        defaultOfflineDays, provisionalDays),
      version,
      issued_at: nowIso,
      provisional: group.payment_confirmed === false, // trace (audit/debug)
      // NB : un groupe suspendu/expiré peut se voir émettre une licence à
      // modules vides ou valid_to passé → l'app dégrade en douceur (fail-soft).
    };

    // 5) Signer Ed25519 (JWS compact).
    const header = { alg: "EdDSA", kid: Deno.env.get("LICENSE_KID") ?? "default" };
    const enc = new TextEncoder();
    const signingInput =
      `${b64uEncode(enc.encode(JSON.stringify(header)))}.${b64uEncode(enc.encode(JSON.stringify(payload)))}`;

    const key = await crypto.subtle.importKey(
      "pkcs8", b64Decode(Deno.env.get("LICENSE_PRIVATE_KEY_PKCS8_B64")!),
      { name: "Ed25519" }, false, ["sign"]);
    const sig = new Uint8Array(
      await crypto.subtle.sign({ name: "Ed25519" }, key, enc.encode(signingInput)));

    const token = `${signingInput}.${b64uEncode(sig)}`;
    return json({ token }, 200);
  } catch (e) {
    return json({ error: `${e}` }, 500);
  }
});

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
