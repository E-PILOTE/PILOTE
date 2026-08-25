---
name: statut-emploi-personnel
description: "👔 Le STATUT décide du régime d'arrivée (pas le secteur) — un volontaire payé par l'APE n'a pas d'arrêté ; ⚠️ le bucket `directory` ne projetait aucune colonne de carrière"
metadata: 
  node_type: memory
  type: project
  originSessionId: db933423-7daf-438d-9460-97e0abf9b86b
  modified: 2026-08-04T12:33:53.653Z
---

# Statut d'emploi du personnel (2026-08-04)

## Ce que la 0091 avait cassé

Elle exigeait un acte d'affectation de **toute** arrivée en école publique.
Or dans un lycée d'État congolais cohabitent deux populations :

- **fonctionnaire** (et contractuel de l'État) → nommé/muté par arrêté ;
- **volontaire, bénévole, prestataire/vacataire, stagiaire** → engagés SUR
  PLACE, souvent payés par l'**APE**. Aucun arrêté ne les concerne.

En l'état, une part considérable du corps enseignant était **impossible à
enregistrer** — ou l'aurait été sous une référence d'acte inventée.

## La règle (mig 0092)

Ce n'est pas le secteur qui décide, c'est le **statut** :
`motifs_arrivee_pour_statut(statut)` et `motif_exige_un_acte(motif)`.
Acte exigé ⟺ motif ∈ {mutation, détachement, mise à disposition, intérim,
réintégration} — indépendant du secteur (un détaché en privé a un arrêté).
`contractuel` ouvre les DEUX familles (État ou établissement).
`creer_agent_ecole` gagne `p_employment_status` (obligatoire) et remplit
enfin `profiles.employment_status` + `hire_date`.

## Renseigner l'existant (mig 0093)

342 profils avaient un statut NULL → « Fonctionnaires **0** », ce que le
ministère lirait comme « aucun titulaire ». **Zéro ≠ inconnu.**
`renseigner_statut_agent()` REMPLIT un statut vide et **n'écrase jamais** un
statut posé (requalifier = titulariser = acte de la tutelle). Champ dans la
fiche agent ; KPI d'en-tête « Statut à renseigner : N » tant qu'il en manque.

## ⚠️ LE PIÈGE — la colonne existait partout SAUF dans les sync-rules

`employment_status`, `grade`, `echelon`, `category`, `hire_date`,
`speciality`, `gender`, `birth_place`, `address` sont en base ET dans
`powersync_schema.dart`, mais le bucket **`directory` ne les projetait pas** :
elles arrivaient **NULL sur chaque poste**. D'où « Statut à renseigner »
partout quoi qu'on saisisse, et un **dossier RH vide hors ligne**.
Corrigé dans `powersync/config/sync-rules.yaml` et **DÉPLOYÉ le 2026-08-04**
en CLI (cf. [[powersync-deploiement-cli]]). Vérifié à l'écran juste après :
« Fonctionnaire 2 · Volontaire 1 · Statut à renseigner 7 ».

👉 Réflexe : une colonne lue par un provider offline doit être vérifiée dans
les TROIS endroits — base, `powersync_schema.dart`, **sync-rules**.

Liens : [[ecole-constate-une-arrivee]] · [[sync-config-divergence]] ·
[[rh-categorie]]
