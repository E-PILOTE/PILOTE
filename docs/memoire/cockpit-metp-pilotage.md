---
name: cockpit-metp-pilotage
description: "Cockpit ministériel METP : réussite par filière + par département, choroplèthe carte par réussite, et scénario de démo écrit"
metadata: 
  node_type: memory
  type: project
  originSessionId: 3dd519ee-785a-464e-a27d-95c1a6fbc266
  modified: 2026-07-26T17:01:25.595Z
---

**2026-07-26 — Le cockpit admin_groupe porte enfin les 2 axes de pilotage d'un ministère TECHNIQUE** (commits `32d79ee` puis `5a50c0e`). Avant : le taux de réussite n'existait qu'en agrégat réseau et par école — jamais par filière ni par département, alors que ce sont précisément les deux leviers d'un METP (ajuster l'offre de formation ; équité territoriale).

**Règle du taux — SOURCE UNIQUE, partagée école ↔ ministère** (`features/examens/models/exam_stats.dart`) : calcul sur les résultats **CONNUS** (`admis|ajourne|absent|fraude`) ; `rate` vaut **`null`, jamais 0 %**, tant que rien n'est proclamé. Ajouts : `groupExamLines(rows, keyOf)` (ventilation générique), champ `department`, `isKnownExamResult()`. Ne jamais recopier une variante locale de cette règle.

**Provider** `admin_exams_provider.dart` : jointures `classes(filiere_label)` + `schools(department)` → `byFiliere` / `byDepartment`. ⚠️ La colonne est `filiere_label` (et `filiere_code`) — **`filiere_id` n'existe PAS** sur `classes`.

**UI** : `admin_groupe/widgets/admin_exams_breakdown.dart` (fichier dédié — l'écran examens dépasse 500 l.) ; barres à couleur sémantique **vert ≥70 % · ambre ≥50 % · rouge <50 %**, assiette « admis/connus » toujours affichée, « en attente » explicite si non proclamé.

**Choroplèthe carte** (`screens/regional/`) : `_DeptFill { activite, reussite }` + sélecteur « COULEUR DES DÉPARTEMENTS » dans `_LayerToggleBar` (qui vit **en bas du panneau GAUCHE**, pas dans les boutons flottants de la carte). Mêmes seuils que les cartes de ventilation. **La légende (`_MapLegend`) suit l'indicateur.** Département sans proclamation = **neutre**, jamais rouge. Appariement nom base ↔ polygone OSM vérifié **8/8** (`assets/geo/congo_adm1.json` = liste de 15 objets `{name, centroid, outer}`).

**Scénario de démo écrit** : `presentation/SCENARIO-DEMO-METP.md` (parcours minuté conseillers/DSIC 20 min puis ministre 7 min, où couper le wifi, chiffres par cœur, pièges). Voir aussi `presentation/E-PILOTE-slide-demarrage.pptx`.

⚠️ **Vérif GUI Linux limitée** : la fenêtre meurt sur `Timed out waiting for OpenGL frame … Lost connection` (pilote `nouveau`, cf. [[desktop-packaging-deb]]) — contournement utilisé : basculer temporairement la valeur PAR DÉFAUT du provider pour capturer sans interaction. Ventilations + bascule de légende constatées à l'écran. Voir [[demo-metp-seed-technique]], [[examens-nationaux-socle]].
