---
name: powersync-is-active-egalite-stricte
description: "⚠️ `is_active = 1` ne retrouve pas les lignes créées localement par l'app dans une vue PowerSync — utiliser `COALESCE(is_active, 1) <> 0`"
metadata: 
  node_type: memory
  type: project
  originSessionId: db933423-7daf-438d-9460-97e0abf9b86b
  modified: 2026-08-01T06:26:27.500Z
---

Dans une requête sur une **vue PowerSync locale**, `WHERE is_active = 1` retrouve
les lignes venues du **serveur** mais **PAS** celles que l'application vient
d'**insérer elle-même** hors ligne — alors que les deux stockent la même valeur
dans le blob `data` (constaté sur `ps_data__classes`, août 2026).

**Why:** la vue expose `CAST(json_extract(data,'$.is_active') AS INTEGER)` ; la
sérialisation d'une écriture locale ne redonne pas un entier qui s'égale
strictement à 1. Diagnostiqué sur `rolloverClasses` (reconduction des classes) :
l'écran Passage annonçait « les classes de 2026-2027 n'existent pas encore »
**juste après les avoir créées**, et « Réinscrire » restait grisé pour toujours.
Le même filtre cassait la clôture des classes d'examen. Reproduit puis levé en
retirant le filtre. ⚠️ Requêter le fichier `~/Documents/epilote_v3.db` en
sqlite3/python **ne reproduit pas** le bug : c'est le moteur SQLite de PowerSync
qui diverge — ne pas conclure « la donnée est bonne donc le code est bon ».

**How to apply:** dans toute requête offline, écrire
`AND COALESCE(is_active, 1) <> 0` — jamais `= 1`. Vaut pour tout booléen
susceptible d'être écrit par l'app (`is_active`, `is_repeating`, `is_published`…).
Corrigé dans `passage_provider._classAt` et `cloture_examen_provider`
(commit fdb514d) ; **d'autres écrans utilisent encore `= 1`** sur des tables que
l'app écrit — à auditer. Voir [[cloture-examen-classes]],
[[type-local-suit-type-serveur]] (même famille : le type local doit suivre le
type serveur).
