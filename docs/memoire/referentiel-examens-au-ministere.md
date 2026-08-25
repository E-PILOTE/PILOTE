---
name: referentiel-examens-au-ministere
description: "Le référentiel d'examens et ses règles d'éligibilité appartiennent à admin_groupe (ministère), pas au super_admin"
metadata: 
  node_type: memory
  type: project
  originSessionId: db933423-7daf-438d-9460-97e0abf9b86b
  modified: 2026-07-29T07:05:52.160Z
---

# Référentiel des examens — chaîne complète et rattachement des rôles

**Règle de rattachement (2026-07-29, correction du user) :** `super_admin` =
OPÉRATEUR du SaaS (vend, facture, surveille l'adoption). `admin_groupe` = le
MINISTÈRE, qui connaît ses examens et reçoit les arrêtés. Faire saisir un
arrêté ministériel par l'éditeur du logiciel était une inversion. Le
référentiel ET le calendrier des sessions vivent donc dans
`features/admin_groupe/` (`/admin/referentiel-examens`, `/admin/sessions-examen`).
Ce qui RESTE au super_admin : `super_exams_section.dart` — l'adoption du
module par les groupes, qui est bien une métrique d'opérateur.

## La chaîne — et où elle cassait
```
examen (national_exams)
  → RÈGLE d'éligibilité (cycle · niveau · filière · tutelle · validité)
  → resolve_class_exam() dérive classes.exam_id par trigger
  → session ouverte (exam_sessions, statut 'open')
  → l'école inscrit ses candidats
```
**Le maillon 2 n'avait aucun écran** : un examen créé ne se branchait à rien,
toutes les classes restaient « à qualifier ». 4 diplômes actifs (BEP, BTF,
CAP, CQP) sont dans cet état — volontairement laissés sans règle par la mig
0044, faute de mapping filière→diplôme fiable.

**How to apply:**
- ⚠️ `recompute_class_exams()` est OBLIGATOIRE après toute écriture de règle :
  le trigger `classes_derive_exam` ne s'arme qu'à l'écriture d'une CLASSE.
  Sans lui, une règle neuve ne touche aucune classe existante et paraît morte.
- ⚠️ Le vocabulaire (cycle/niveau/filière) n'existe dans AUCUNE constante Dart :
  `classes.level_code` est dénormalisé depuis `school_levels` (référentiel DU
  GROUPE), pas `education_levels`. Toute liste figée côté client produit des
  règles qui ne matchent rien. → RPC `exam_rule_vocabulary()` (mig 0070) rend
  les codes réellement portés, avec effectif.
- `exam_rule_match_count()` calcule à blanc « N classes concernées » avant
  d'enregistrer. Un **zéro** est l'info la plus utile de l'écran.

## Décisions gelées
- **Portée du droit d'écriture : tout `admin_groupe`, SANS marqueur ministériel**
  (choix explicite du user, alternative « ministères seulement » écartée).
  ⚠️ Conséquence connue : un réseau privé peut modifier le référentiel national.
  Refermer = ajouter `school_groups.is_ministry` dans les 3 politiques de la
  mig 0071. Rien en base ne distingue aujourd'hui ministère et réseau privé
  (7 groupes : MEPSA, METP + 5 réseaux).
- Un **CONCOURS** n'a jamais de règle : `resolve_class_exam` filtre
  `kind = 'diplome'` (se présenter est un choix de l'élève, pas une propriété
  de la classe). L'UI l'écrit « sans objet » au lieu de le signaler en défaut.
- Retrait d'un examen = **désactiver** (les sync-rules ne diffusent que
  `is_active`), jamais supprimer : sessions et résultats proclamés restent.

## 🔴 Faille fermée au passage (mig 0070)
`recompute_class_exams()` est SECURITY DEFINER et n'avait **jamais reçu de
REVOKE** → EXECUTE par défaut à PUBLIC : tout compte authentifié (enseignant,
parent) pouvait réécrire `classes.exam_id`/`exam_status` sur le parc entier,
tous groupes confondus, en contournant la RLS. Fermée, comme les 2 fonctions
nouvelles. ⚠️ Toute fonction SECURITY DEFINER de ce dépôt doit être auditée de
la même façon — un seul `GRANT EXECUTE` existait dans toutes les migrations.
⚠️ Le garde de rôle doit laisser passer `current_user IN ('postgres',
'supabase_admin')` : les migrations 0044/0045/0067 appellent la fonction en fin
de script, sans `auth.uid()`.

Migrations **0070** (outillage + verrou) et **0071** (RLS au ministère)
APPLIQUÉES en production et vérifiées.

Liens : [[examens-nationaux-socle]] · [[cockpit-metp-pilotage]] ·
[[role-admin-groupe]] · [[modules-acces-hierarchie]]
