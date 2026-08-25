---
name: structure-ecole-table-morte
description: "⚠️ L'écran Offre éducative écrivait dans school_education_levels (0 ligne, 0 lecteur) — une école créée depuis l'UI n'avait AUCUN niveau ; mig 0089 + appliquer_structure_ecole()"
metadata: 
  node_type: memory
  type: project
  originSessionId: db933423-7daf-438d-9460-97e0abf9b86b
  modified: 2026-08-04T00:13:07.023Z
---

# La structure d'une école partait dans une table morte (2026-08-03)

## Le bug

`education_provider.saveSchoolEducation()` enregistrait les niveaux cochés
dans **`school_education_levels`** et `school_education_programs`.
**Ces deux tables ont 0 ligne et AUCUN lecteur** — ni Dart, ni sync-rules,
ni vue. Toute l'application lit **`school_levels`** (175 lignes,
494 classes rattachées par `classes.level_id`).

Conséquence : une école créée depuis l'interface recevait ses `school_cycles`
mais **pas un seul niveau** → aucune classe possible → aucune inscription.
Mort-née, sans message d'erreur. Les 37 écoles existantes ne le montraient
pas : leurs niveaux viennent du seed. L'onglet « Cycles » du modal détail
affichait « Aucun niveau sélectionné » pour **toutes**.

⚠️ Les tables mortes ne sont pas supprimées (commentaire `MORTE` en base) :
une migration de correctif ne doit pas emporter des tables si on l'annule.

## Migration 0089

- `school_levels.education_level_id` → `education_levels(id)`. Le lien
  existait de fait (175/175 appariés sur `cycle_id` + `code` + `program_id`)
  mais restait implicite. **Index unique partiel `(school_id,
  education_level_id)`** : la famille de bugs « 42 niveaux au lieu de 6 »
  ([[premiere-heure-etablissement]]) est désormais interdite en base.
- `appliquer_structure_ecole(school, cycles[], levels[]) → jsonb`,
  SECURITY DEFINER + `SET search_path`. Idempotente.
- Helpers : `unaccent_simple()`, `epilote_slugifier()` (slug =
  UNIQUE(group_id, slug), NOT NULL, dérivé jamais saisi),
  `notation_du_cycle()` (préscolaire → `competences`, sinon
  `numeric_with_coef`, conforme aux 175 lignes existantes).

## ⚠️ LA RÈGLE : on n'efface jamais un niveau qui porte des classes

Ni suppression **ni désactivation** : la sync-rule est
`SELECT * FROM school_levels WHERE group_id = bucket.gid AND is_active = true`
→ un niveau désactivé **disparaît des appareils** et ses classes deviennent
illisibles hors ligne.

Un décochage qui emporterait des classes → `{ok:false, bloquants:[…]}`,
**rien n'est modifié**, et le message dit quoi fermer d'abord
(`StructureRefusee` côté Dart). Même ligne de conception que le refus
d'attestation ([[attestations-emises]]).

## Modèles d'établissement

`admin_groupe/providers/structure_modeles.dart` — EPP / maternelle / complexe
/ CEG / lycée / lycée+collège / lycée technique.

⚠️ **Un modèle ne désigne que des CYCLES, jamais des niveaux.** Recopier
« CP1, CE1… » dans l'app créerait une 2ᵉ source de vérité qui divergerait de
la base. Cocher un cycle coche ses niveaux (`activeGeneralLevelsOf`) — sauf
`formation_pro` : 63 niveaux au référentiel, aucune école ne les offre tous.

Les modèles ne s'affichent que sur une offre **vide** ; sur une école déjà
configurée on nomme seulement la forme reconnue (`modelePour`), sinon un clic
détruirait la sélection à l'écran.

## ⚠️ Mig 0090 — le refus redevient lisible

Le contrôle bloquant écartait par `NOT (education_level_id = ANY(...))`.
**`NULL = ANY(...)` vaut NULL, `NOT NULL` vaut NULL** → un niveau sans lien au
référentiel sortait du contrôle, mais la suppression le visait. Résultat :
erreur brute `23503 classes_level_id_fkey` (pas de CASCADE, donc rien de
perdu) au lieu du message qui dit quoi fermer. Le contrôle et la suppression
partagent désormais le même prédicat. Piège dormant : 0 ligne concernée.

## Vérifié en base (école de test, transaction annulée)

création 4 niveaux → rejeu 0 changement → retrait d'un niveau libre → refus
intégral d'un retrait peuplé, 3 niveaux intacts.

Liens : [[premiere-heure-etablissement]] · [[structure-academique-livree]] ·
[[powersync-is-active-egalite-stricte]] · [[verifier-base-live-vs-schema]]
