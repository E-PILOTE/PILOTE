---
name: abonnement-referentiel-tarifaire
description: "⚠️ Realtime exige AUSSI `REPLICA IDENTITY FULL` ; le tarif d'un plan porte sa PÉRIODICITÉ (migs 0076/0077) ; quota personnel = `profiles`, pas `staff_members`"
metadata: 
  node_type: memory
  type: project
  originSessionId: db933423-7daf-438d-9460-97e0abf9b86b
  modified: 2026-08-01T19:41:39.948Z
---

**Migrations 0076 + 0077 (2026-08-01)** — le référentiel tarifaire de la
plateforme. Trois faits non devinables depuis le code :

**⚠️ Publication `supabase_realtime` NE SUFFIT PAS — il faut `REPLICA IDENTITY
FULL`.** Vérifié à l'écran : `subscription_plans` ajoutée à la publication mais
laissée en identité par défaut (`relreplident = 'd'`) → un UPDATE ne produit
AUCUN évènement, le tableau de bord reste figé. Passée en `FULL` (`'f'`), le
même UPDATE fait bouger le revenu en deux secondes. Le signe qui met sur la
piste : `school_groups`, la seule table dont le temps réel marchait, était déjà
en `'f'`. Complète [[realtime-publication-requirement]]. Ne pas généraliser aux
tables de flux (notes, présences, paiements) : chaque UPDATE écrit l'ancienne
ligne entière dans le WAL.

**Le tarif d'un plan porte sa PÉRIODICITÉ** (`subscription_plans.billing_period`
= mensuel|trimestriel|semestriel|annuel, défaut `annuel`). Avant, l'écran disait
« Prix mensuel » et `fn_auto_create_invoice` / `create_renewal_invoice`
facturaient `+ INTERVAL '1 year'` — facteur 12 sur tout revenu affiché. Les deux
espaces se contredisaient : « / an » côté admin_groupe, « / mois » côté
plateforme. Source unique : `lib/core/utils/billing_period.dart`
(`billingPeriodMonths` = miroir de `billing_period_months()` en base ; toute
modification touche le Dart **et** le SQL).
⚠️ **Un MRR se calcule sur `monthlyEquivalent`, jamais sur `price_xaf` brut.**

**Le quota de personnel porte sur `profiles`, pas `staff_members`** (table à 0
ligne, jamais écrite par l'app — cf. [[staff-personnel-annuaire]]). Il se
déclenche sur `UPDATE OF group_id` et pas seulement `INSERT` : `create_school_user`
crée le profil SANS groupe (via `fn_handle_new_user`) puis l'y rattache. Sont
hors quota : `super_admin`, `parent`, `eleve`. Exemption `auth.uid() IS NULL`
pour les écritures d'administration (service_role, seeds, console SQL).

**`module_count` est DÉRIVÉ** de `plan_modules` par trigger depuis 0076 — ne
plus l'envoyer depuis Dart. Il avait divergé (plan « pro » : 26 annoncés, 28
réels).

**Vérification en base rejouable** : `database/checks/0076_*.sql` et
`0077_*.sql`, à passer après chaque déploiement. Transaction annulée
(`ROLLBACK`), donc sans risque sur la prod. Attendu : `echecs = 0`.

**Règle côté client** : tout provider qui met un tarif ou un quota en cache
(`ref.keepAlive()`) DOIT appeler `.watchPlanReferential(...)` sur son canal —
changer un prix ne touche pas `school_groups`, donc n'émet rien qui les
réveille. `test/plan_referential_test.dart` parcourt `lib/` et fait échouer la
suite si un écran l'oublie.
