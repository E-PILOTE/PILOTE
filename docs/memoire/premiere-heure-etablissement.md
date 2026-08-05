---
name: premiere-heure-etablissement
description: "Parcours de démarrage d'une école + ⚠️ BUG CORRIGÉ : school_levels joint sur group_id seul montrait 42 niveaux au lieu de 6"
metadata: 
  node_type: memory
  type: project
  originSessionId: db933423-7daf-438d-9460-97e0abf9b86b
  modified: 2026-08-03T19:13:15.120Z
---

# La première heure d'un établissement (2026-08-03)

## ⚠️ Le bug trouvé au passage — 42 niveaux au lieu de 6

`academicStructureProvider` joignait `school_levels` sur le seul `group_id`.
**La table porte pourtant un `school_id`** : le filtre manquant laissait entrer
les catalogues de toutes les écoles voisines. Une école primaire affichait sept
copies de CP1, CE1, CM2.

C'est l'écran de structure — celui qu'un établissement ouvre le premier matin,
et celui qu'une présentation ministérielle ouvre en premier. Corrigé sur
données réelles : 6 niveaux pour un CEG, 10 pour un complexe.

Au passage, deux `is_active = 1` → `COALESCE(is_active, 1) <> 0`
([[powersync-is-active-egalite-stricte]]) : un niveau créé le matin
disparaissait l'après-midi.

## Le modèle de structure, en vrai

- `education_cycles` (5, global) et `education_levels` (79, référence
  nationale complète) = **référentiel**.
- `school_cycles` (quels cycles une école offre) et `school_levels`
  (**par école**, avec `school_id`) = ce que l'école possède.
- `school_education_levels` = table **morte** (0 ligne).
- ⚠️ Les deux sont gouvernées par `admin_groupe` (RLS) : **l'école ne peut pas
  créer ses niveaux**, elle les reçoit. Idem pour l'année scolaire
  (`academic_years.school_id` est NULL = portée GROUPE,
  [[non-revenus-et-exclusion]]).

## Le parcours de démarrage

`features/structure/providers/demarrage_provider.dart` +
`widgets/demarrage_card.dart`, posé en tête du tableau de bord école.

Cinq étapes dans l'ordre de leurs **dépendances** (année → structure → classes
→ personnel → élèves). Décisions :

- Chaque étape dit ce que son absence **BLOQUE**, pas seulement qu'elle manque.
- **Une seule action mise en avant**, la première non faite. Proposer cinq
  choses à qui n'en a jamais fait aucune, c'est n'en proposer aucune.
- `parLeReseau: true` sur année et structure → bouton « **Voir** », pas
  « Commencer ». Envoyer chercher un bouton inexistant fait croire que
  l'application est cassée.
- **La carte s'efface quand tout est fait** — sinon elle devient du mobilier.
- Une seule requête à cinq sous-requêtes, pas cinq `db.watch`.

## ✅ Suite livrée le 2026-08-03

Modèles de structure + réparation d'un bug bien plus grave : l'écran écrivait
les niveaux dans une table morte → **une école créée depuis l'interface
n'avait aucun niveau**. Voir [[structure-ecole-table-morte]].

Liens : [[deploiement-national-octobre]] · [[structure-academique-livree]] ·
[[espace-ecole-coquille]] · [[ecole-provisionne-ses-agents]]
