---
name: ecole-constate-une-arrivee
description: "⚠️ RÈGLE MÉTIER : l'école CONSTATE une arrivée (note d'affectation), elle ne la DÉCIDE pas — mig 0091 ; la 0088 écrivait « recrutement » sans acte, ce qui falsifiait la carrière"
metadata: 
  node_type: memory
  type: project
  originSessionId: db933423-7daf-438d-9460-97e0abf9b86b
  modified: 2026-08-04T06:26:37.699Z
---

# L'école constate une arrivée, elle ne la décide pas (2026-08-04)

## Ce qui était faux dans la 0088

`creer_agent_ecole` inscrivait dans `staff_affectations` :
`arrival_motif = 'recrutement'`, `acte_reference = NULL`.

Dans le **public**, un enseignant n'est pas recruté par son lycée : il y est
**AFFECTÉ par note de l'autorité de tutelle**. Les colonnes `acte_reference` /
`acte_date` existaient depuis la 0083 et restaient vides. À la première
campagne de mouvement, le ministère aurait lu vingt mille agents « recrutés par
leur établissement » — carrière faussée dès l'arrivée.

**C'est le user (fonctionnaire DSIC/METP) qui l'a signalé** — sa parole prime
([[user-fonctionnaire-dsic-metp]]).

## Migration 0091 — trois portes étroites et NOMMÉES

La RLS `profiles_update` (super_admin | admin_groupe du groupe | soi-même)
reste **INCHANGÉE** : c'est elle la règle. Ces fonctions sont les seules
exceptions assumées.

| Fonction | Ce qu'elle permet |
|---|---|
| `creer_agent_ecole` | motif d'arrivée OBLIGATOIRE ; acte (réf. + date) obligatoire en public ; « recrutement » **interdit** en public |
| `corriger_fiche_agent` | liste blanche **lisible dans la SIGNATURE** : nom, tél., matricule, photo. Aucun paramètre pour `role`/`is_active`/`school_id`/`access_profile_id` |
| `annuler_enregistrement_agent` | efface une SAISIE, jamais une carrière |

### ⚠️ Le secteur commande la règle
`school_groups.group_type` = `public` | `prive` (pas de colonne `sector` sur
`schools` — [[secteur-ecole-herite-groupe]]). `groupe_est_public()` traite un
secteur inconnu comme **public** : mieux vaut exiger un acte à tort que laisser
une carrière sans acte. Privé → la direction EST l'employeur, « recrutement »
est vrai, référence de contrat facultative.

### ⚠️ L'annulation n'est PAS un DELETE naïf
**61 clés étrangères** pointent vers `profiles`, plusieurs en **CASCADE**
(`staff_career`, `staff_diplomas`, `staff_members`, `conversation_members`…).
Trois conditions cumulatives, toutes vérifiées :
jamais connecté (`profiles.last_login` **ET** `auth.users.last_sign_in_at`) +
aucun travail rattaché + enregistré par cette école (affectation unique).
Le refus **NOMME** ce qui bloque (« 1 classe dont il est professeur principal »).

## ⚠️ Pièges rencontrés

- **`audit_logs.action` est un `varchar(20)`.** `CORRECTION_FICHE_AGENT` (22) et
  `ANNULATION_ENREGISTREMENT_AGENT` (31) levaient « value too long » APRÈS la
  création de l'agent. Libellés courts obligatoires.
- **Changer le nombre d'arguments d'une fonction ne la REMPLACE pas** : ça crée
  une surcharge et rend l'appel ambigu → `DROP FUNCTION` de l'ancienne signature.
- Un `psql -c "BEGIN;" -f fichier.sql` **n'englobe pas** le fichier : celui-ci
  porte sa propre transaction et **commit**. Pas de dry-run comme ça.
- La direction ne peut pas `SELECT` la fiche d'un autre agent (RLS) : l'annuaire
  passe par PowerSync/sync-rules, pas par l'API.

## Photo de l'agent — pourquoi EN LIGNE

Bucket `avatars` (public). Un `UPDATE avatar_url` via PowerSync serait **refusé
par la RLS** → et un refus serveur **abandonne le lot ENTIER**
([[perte-silencieuse-identifiants-vides]]). Donc : upload Storage puis RPC.
Le serveur refuse toute URL hors de
`https://…/storage/v1/object/public/avatars/` — `avatar_url` s'affiche sur tous
les écrans qui montrent l'agent.

Liens : [[ecole-provisionne-ses-agents]] · [[carriere-agent-mutation]] ·
[[annuaire-filtres-partages]]
