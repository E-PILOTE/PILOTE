# Activation du canal email des rappels d'échéance

Le canal in-app (cloche) est en production. L'**email** double le canal pour atteindre
le payeur qui n'ouvre pas l'app. Code : `supabase/functions/subscription-reminder-emailer/`.
Il reste **dormant** (aucun envoi) tant que `RESEND_API_KEY` n'est pas posé.

## Pré-requis (côté propriétaire)

1. Compte **Resend** (https://resend.com) + **domaine vérifié** (DNS SPF/DKIM), ex. `e-pilote.cg`.
2. Une **clé API Resend** (`re_...`).
3. Un expéditeur vérifié, ex. `E-PILOTE <no-reply@e-pilote.cg>`.

## Étapes d'activation

### 1. Poser les secrets de la fonction
```bash
supabase secrets set RESEND_API_KEY=re_xxx RESEND_FROM="E-PILOTE <no-reply@e-pilote.cg>"
```
(ou via Management API / Dashboard → Edge Functions → Secrets.)

### 2. Déployer l'Edge Function
`verify_jwt = true` (non appelable publiquement ; l'appelant doit présenter un JWT projet).
Déploiement via Management API (CLI npm cassée sur cet env) :
`POST /v1/projects/{ref}/functions/deploy?slug=subscription-reminder-emailer` (multipart : metadata + index.ts).

### 3. Planifier le déclenchement quotidien (pg_cron → pg_net)
Peu après le cron de génération (06:00 UTC), donc **06:05 UTC**. Le `service_role`
n'est PAS écrit en clair : on le range dans **Vault**.

```sql
create extension if not exists pg_net;

-- Ranger le service_role dans Vault (une fois).
select vault.create_secret('<SERVICE_ROLE_JWT>', 'service_role_key');

-- Planifier l'appel HTTP à la fonction.
select cron.schedule('subscription-reminder-emails', '5 6 * * *', $$
  select net.http_post(
    url     := 'https://<ref>.supabase.co/functions/v1/subscription-reminder-emailer',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name = 'service_role_key'),
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
$$);
```

### 4. Vérifier
- Appel manuel : `select net.http_post(...)` (mêmes args) → la fonction renvoie
  `{status:"ok", sent, skipped, failed}`.
- Sur un groupe témoin à J-7 (voir test d'idempotence de `0030`), après un run du
  cron de génération : un email doit partir, et `notifications.data->>'emailed'` passe à `true`.
- 2ᵉ run : `skipped` (idempotence).

## Garanties

- **Idempotent** : `data.emailed = true` posé après envoi réussi ; un échec ne le pose
  pas → réessai au run suivant.
- **Fail-soft / dormant** : sans `RESEND_API_KEY`, la fonction renvoie `dormant` et n'envoie rien.
- **Sécurité** : `verify_jwt = true` ; `service_role` en Vault (jamais en clair dans le job cron).
- **Pas de fuite** : ne traite que les notifications `type='subscription'` (destinataires admin_groupe).
