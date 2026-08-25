---
name: abonnement-workflow-reel
description: Workflow abonnement/réabonnement/factures RÉEL (source = school_groups) ; mark_invoice_paid était cassé ; create_renewal_invoice ajouté
metadata: 
  node_type: memory
  type: project
  originSessionId: ffc12413-1442-4bf8-8470-d36a30e6cfe1
---

**Source de vérité = `school_groups`** (colonnes `plan_id`, `subscription_status`, `subscription_start/end`). PAS de table `subscriptions`. Enum `subscription_status` : trial, active, suspended, expired, cancelled.

**Chemin d'activation UNIQUE = `mark_invoice_paid(invoice_id, method, ref, notes)`** (SECURITY DEFINER, super_admin only) : passe la facture à `paid`, génère le reçu `REC-…`, et pose `school_groups` en `active` + `subscription_end = invoice.period_end`. Tout (ré)abonnement doit passer par une facture payée.

**Facturation :**
- `trg_auto_create_invoice` = trigger `AFTER INSERT ON school_groups` seulement (première souscription). Plan gratuit → active direct ; plan payant → facture `pending`.
- `backfill_missing_invoices()` = rattrape les groupes SANS aucune facture.
- Crons : `expire-subscriptions` (1h05, passe active/trial dépassés → expired), `subscription-reminders` (6h).
- `group_invoices.status` ∈ pending/paid/overdue/cancelled. Numéro via `generate_invoice_number()` (`INV-AAAA-NNNN`).

**⚠️ 3 défauts corrigés (migration 0039, PR #16) — cf [[abonnement-etat-reel-enforcement]] :**
1. **`mark_invoice_paid` était CASSÉ** : insérait une notif sans `recipient_id` (NOT NULL) → transaction entière rejetée → AUCUN paiement confirmable, chaîne de revenu morte. Fix = ventiler la notif par admin_groupe du groupe (`notifications` est PAR destinataire).
2. **Renouvellement sans facture** : le trigger étant INSERT-only, renouveler se faisait en éditant `subscription_end` à la main (0 facture/reçu/revenu). Fix = `create_renewal_invoice(p_group_id)` émet une facture `pending` (idempotent : facture impayée existante → renvoyée ; plan gratuit → prolonge direct).
3. **Admin_groupe ne pouvait pas se réabonner** : bouton plan courant désactivé. Fix = bouton « Renouveler mon abonnement » (carte plan, si expiré/échéance proche) → `showRenewSubscriptionDialog` → `create_renewal_invoice`. La fonction autorise super_admin OU l'admin_groupe DU groupe (cross-groupe → « Accès refusé », NULL → « Groupe non spécifié »).

**Boucle complète** : admin_groupe génère la facture de renouvellement → super_admin la marque payée (`mark_invoice_paid`) → groupe réactivé jusqu'à `period_end`.

**Anomalies CORRIGÉES (mig 0040)** : Bethel actif sans échéance → backfill + garde-fou ; super_admin ne peut plus poser `active` sans reçu payé (cf. section « Gating réel » ci-dessous).

**Période d'essai (mig 0041, PR #16)** — l'essai n'avait NI durée NI échéance : le chemin principal de création (`school_groups_screen`) posait `'trial'` sans `subscription_end` → `expire_subscriptions()` ne l'expirait jamais → essai gratuit à vie (fuite de revenu). Fix :
- `fn_set_trial_window` (BEFORE INSERT) : tout groupe `'trial'` reçoit une fenêtre datée `[aujourd'hui ; +N jours]`. Une échéance saisie à la main (formulaire Abonnements) est RESPECTÉE (condition `subscription_end IS NULL`).
- **`trial_days` = `platform_settings.data->>'trial_days'`, défaut 3** (choix user), réglable depuis Paramètres ▸ Facturation (champ « Durée d'essai », `settings_screen.dart`). Lecteur curé `fn_trial_days()`.
- Garde-fou 0040 étendu à l'INSERT (`trg_guard_active_requires_payment_ins` + `TG_OP` dans `fn_guard_active_requires_payment`) : on ne peut plus INSÉRER un groupe payant directement `'active'` sans reçu. Conséquence voulue : pour un plan payant, `'active'` est INATTEIGNABLE à l'insert (aucun reçu ne préexiste au groupe) → seul chemin = trial → facture → `mark_invoice_paid` → active.
- Backfill des essais sans échéance (datés depuis `created_at` → les vieux essais expirent au prochain cron).
- **Mig 0041 APPLIQUÉE + PROUVÉE en prod** (via `psql` direct pooler:5432, superuser postgres — MCP Supabase inutile). 5 cas prouvés en transaction annulée : trial_days=3, essai payant = fenêtre 3 j + facture 1 an pending, essai gratuit = actif 1 an, insert `active` sans reçu REFUSÉ, paiement = actif 1 an. Correctif clé (`e521984`) : `fn_auto_create_invoice` DÉCOUPLE la facture (terme 1 an) de la fenêtre d'essai (`subscription_end` court) — sinon plan gratuit actif 3 j + facture 3 j au prix annuel.

**Audit d'échelle 200+ groupes / centaines d'écoles (2026-07-15, prod) — SYSTÈME SAIN :**
- RLS factures : `invoices_write`/`invoices_update` = `is_super_admin()` SEUL → reçu payé infalsifiable par admin_groupe (garde-fou 0040/0041 inviolable). `invoices_select`/`groups_select` = super_admin OR own group.
- Fonctions RLS (`is_super_admin`, `auth_group_id`, `is_admin_groupe`, `auth_school_id`) toutes **STABLE** → évaluées 1×/requête (pas par ligne). Scale-OK.
- `generate_invoice_number()` = `NEXTVAL('seq_invoice_number')` (séquence atomique) + index unique → zéro collision concurrente.
- Index : school_groups(status,plan,department,slug), group_invoices(group_id,plan_id,invoice_number unique), schools(group_id). Suffisants au volume (200 groupes ≈ centaines/milliers de factures/an → seq scan <1ms ; pas de sur-indexation).
- Crons actifs : `expire-subscriptions` (01:05 quotidien), `subscription-reminders` (06:00). 
- Intégrité vérifiée : 0 groupe payant actif sans reçu couvrant ; 0 actif/essai sans échéance.
- Fragilité pré-existante notée (PAS un bug 0041) : `group_invoices.created_by` NOT NULL rempli via `COALESCE(NEW.created_by, auth.uid())` → un insert de groupe hors contexte JWT (seed/serveur) casserait la facture auto. En prod OK (RLS exige is_super_admin → auth.uid présent).
- Creds prod : postgres pw `‹secret — gestionnaire de mots de passe›`, pooler `aws-1-eu-central-2.pooler.supabase.com` (6543 tx / 5432 session). MCP token `sbp_a5eefa...`. cf [[supabase-credentials]].

Vitrine : `VitrineClock` lisait `DateTime.now()` → goldens cassaient chaque jour ; point d'injection `debugVitrineClock` ajouté (heure figée en test).


## Gating réel des modules (IMPORTANT — nuance offline-first)
- **Staff : modules = `plan_id` uniquement** (`activeModulesProvider` = plan_modules WHERE plan_id). AUCUN check paiement/statut. Un groupe expiré/impayé garde ses modules pour le personnel (offline PowerSync). C'est DÉLIBÉRÉ (règle C4 : ne jamais gater la synchro sur la licence ; fail-soft). La vraie coupure dure = système de licence (DORMANT).
- **admin_groupe online : `subscriptionAccessProvider`** dérive la phase (active/grace/readOnly) du statut+date. readOnly bloque seulement la CRÉATION (écoles/users), fail-soft. Ne retire pas les modules.
- Migration 0040 : trigger `fn_guard_active_requires_payment` → on ne peut ACTIVER que si plan gratuit OU reçu payé couvrant l'échéance (transition vers active seulement ; éditer un actif reste libre). Donc `active` ⟺ payé/gratuit ⟹ la phase online est désormais adossée au paiement. Prouvé 5 cas. Anomalie Bethel (actif sans échéance) corrigée.
- RLS group_invoices SAINE : INSERT/UPDATE = `is_super_admin()` only → un admin_groupe ne peut PAS forger un reçu payé (mon trigger reste sûr). `create_renewal_invoice` (SECURITY DEFINER) n'insère qu'une facture PENDING.
- Reçu (`receipt_number` REC-…) posé UNIQUEMENT par mark_invoice_paid / backfill (super_admin) → fiable. Double-paiement bloqué (« déjà réglée »).
- Recouvrement (dunning) calcule overdue par DATES (pas le statut facture). ⚠️ Mineur : aucun job ne passe pending→overdue, donc le compteur `status='overdue'` reste 0 (cosmétique ; les impayés pending sont comptés partout). Non corrigé (risque/bénéfice).
- migrations 0039 + 0040 appliquées + prouvées en prod. PR #16.
