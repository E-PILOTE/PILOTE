---
name: ecole-provisionne-ses-agents
description: "L'école crée ses propres comptes (mig 0088 creer_agent_ecole) — 4 garde-fous serveur ; un chef ne crée JAMAIS un chef ; profil d'accès obligatoire"
metadata: 
  node_type: memory
  type: project
  originSessionId: db933423-7daf-438d-9460-97e0abf9b86b
  modified: 2026-08-03T18:19:37.695Z
---

# L'établissement ouvre les comptes de son personnel (migration 0088, 2026-08-03)

## Le blocage d'échelle levé

`create_school_user` exigeait `is_admin_groupe()`. Mille écoles × ~20 agents =
**20 000 comptes par un seul guichet** qui ne connaît ni les noms ni les
arrivées de septembre. Le déploiement par vagues ne passait pas.

## Les quatre garde-fous — tous côté SERVEUR

1. **L'école n'est pas un paramètre** : `creer_agent_ecole` ne prend pas de
   `school_id`, elle écrit celui de l'appelant. Erreur d'école impossible.
2. **⚠️ UN CHEF NE CRÉE PAS UN CHEF.** `roles_provisionnables_par_ecole()`
   exclut super_admin, admin_groupe, **directeur et proviseur**. Sinon tout
   compte de direction s'en fabrique un second hors de portée de sa hiérarchie
   — élévation de privilèges classique.
3. **Profil d'accès OBLIGATOIRE** — sans lui l'agent ouvre une application
   vide ([[sidebar-modules-empty-cause]]). Sur mille écoles : mille appels au
   support le même matin.
4. **Quota d'abonnement** (`check_quota(group,'staff')`), et l'écran affiche
   les **places restantes AVANT** la saisie.

`est_chef_etablissement()` = `directeur|proviseur` actif avec `school_id` —
volontairement **plus étroit que `_isStaffRole`**.

L'affectation s'ouvre le jour même, motif `recrutement` : la carrière
([[carriere-agent-mutation]]) commence à l'embauche. Journalisé
(`CREATION_AGENT`).

## ⚠️ Seul geste EN LIGNE de l'espace école

Un identifiant de connexion vit dans `auth.users`, **hors PowerSync** : rien ne
peut le créer hors ligne. Le dialogue le DIT (« hors ligne » ≠ « vous n'avez
pas le droit » — deux messages distincts). Tout le reste de l'app continue.

Le mot de passe est **affiché en clair une fois**, à la fin, avec l'adresse :
sur un poste d'école il n'existe aucun autre canal pour le transmettre.

## Source unique

`kRolesProvisionnablesParEcole` (`features/staff/providers/agent_creation_provider.dart`)
tenu identique au tableau SQL — test garde-fou dans `agent_creation_test.dart`.

`contexte_creation_agent()` renvoie en un appel : autorisation, quota, profils
d'accès, rôles. Évite d'ouvrir un formulaire qui sera refusé.

Liens : [[carriere-agent-mutation]] · [[modules-acces-hierarchie]] ·
[[deploiement-national-octobre]] · [[role-admin-groupe]]
