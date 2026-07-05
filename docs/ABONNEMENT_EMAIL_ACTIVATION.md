# Activation du canal email des rappels d'échéance (Cloudflare Email Service)

Le canal in-app (cloche) est en production. L'**email** double le canal pour atteindre
le payeur qui n'ouvre pas l'app. Code : `supabase/functions/subscription-reminder-emailer/`.
Il reste **dormant** (aucun envoi) tant que `CF_EMAIL_API_TOKEN` + `CF_ACCOUNT_ID` ne sont pas posés.

**Fournisseur : Cloudflare Email Service** (le domaine `epilote.org` est déjà géré par
Cloudflare ; Email Routing activé ; sous-domaine `mail.epilote.org` ; SPF/DKIM en place).
Endpoint réel vérifié : `POST https://api.cloudflare.com/client/v4/accounts/{account_id}/email/sending/send`
(Bearer token, supporte les destinataires arbitraires).

## Pré-requis (côté propriétaire)

1. **Un token API Cloudflare VALIDE** avec la permission **« Email Sending: Edit »**
   → https://dash.cloudflare.com/profile/api-tokens (créer un *API Token*, PAS une Global Key).
   ⚠️ Le token fourni le 2026-07-05 (`cfk_…`) est **INVALIDE** (rejeté : « Invalid API Token »).
2. **L'Account ID Cloudflare** (dashboard → n'importe quel domaine → colonne de droite « Account ID »).
3. Expéditeur : `noreply@mail.epilote.org` (déjà configuré).

## Étapes d'activation (une fois le token valide obtenu)

### 1. Poser les secrets de la fonction
```bash
supabase secrets set \
  CF_EMAIL_API_TOKEN=<token_valide> \
  CF_ACCOUNT_ID=<account_id> \
  CF_EMAIL_FROM="E-PILOTE CONGO <noreply@mail.epilote.org>"
```
(ou via Management API `POST /v1/projects/{ref}/secrets`.)

### 2. La fonction est déjà déployée
`subscription-reminder-emailer` (verify_jwt = true). Elle passe automatiquement de
« dormant » à active dès que les secrets sont présents (lecture au runtime, pas de
redéploiement nécessaire).

### 3. Planifier le déclenchement quotidien (pg_cron → pg_net)
Peu après le cron de génération (06:00 UTC), donc **06:05 UTC**. Le `service_role`
n'est PAS écrit en clair : on le range dans **Vault**.

```sql
create extension if not exists pg_net;
select vault.create_secret('<SERVICE_ROLE_JWT>', 'service_role_key');

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
- Appel manuel de la fonction → `{status:"ok", provider:"cloudflare", sent, skipped, failed}`.
- Sur un groupe témoin à J-7, après un run du cron de génération : un email part, et
  `notifications.data->>'emailed'` passe à `true`.
- 2ᵉ run : `skipped` (idempotence).

## Garanties

- **Idempotent** : `data.emailed = true` posé après envoi réussi ; un échec ne le pose
  pas → réessai au run suivant.
- **Fail-soft / dormant** : sans token/compte Cloudflare, la fonction renvoie `dormant`.
- **Sécurité** : `verify_jwt = true` ; token Cloudflare **server-side uniquement**
  (jamais dans l'app Flutter) ; `service_role` en Vault.
- **Pas de fuite** : ne traite que les notifications `type='subscription'` (destinataires admin_groupe).
