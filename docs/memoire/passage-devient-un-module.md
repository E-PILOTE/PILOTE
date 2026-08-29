---
name: passage-devient-un-module
description: "⚠️ 2026-08-29 — l'écran Passage n'était dans AUCUN catalogue : slug inconnu = « route native » = ZÉRO verrou (impayé, plan, profil) sur l'écriture la plus lourde de l'année. Migration 0147, AVANT le build."
metadata:
  node_type: memory
  type: project
---

# La délibération n'avait aucun verrou (2026-08-29)

## Le défaut

Le garde de routes de `app_router` commence par :

```dart
final slug = moduleSlugForLocation(loc);
if (slug != null) { ...impayé... ...plan... ...profil d'accès... }
```

**Tout tient à `_moduleRoutes`.** Une route absente rend `null`, et `null` veut
dire « route native » — la catégorie du Tableau de bord et du Profil, que rien
ne doit barrer. Le garde la laisse donc passer **sans aucun verrou**.

`/user/passage` y était tombée. C'est l'écran qui écrit
`class_enrollments.promotion_decision` — qui passe, qui redouble — et qui
réinscrit une classe entière dans l'année suivante. L'écriture la plus lourde de
conséquence de l'année scolaire était **la seule page sans verrou**, et la seule
que le mur d'impayé laissait passer.

Le droit `conseils.update` gardait le **bouton** d'entrée, au fond de l'écran
Conseils de classe. Pas la **page**. Un bouton ne garde qu'un chemin — celui
qu'on a pensé.

## ⚠️ Pourquoi le mal n'était PAS l'écriture illégitime

La RLS tenait (`enrollments_update` exige un verbe sur inscriptions / eleves /
conseils / transferts / discipline). Le défaut était plus sournois : un poste
sans ce verbe écrivait quand même **en local**, affichait le verdict au conseil
réuni, et se le faisait jeter au téléversement — **42501, code fatal**, donc le
lot entier avec. Le conseil croit avoir délibéré. Rien n'est parti, et personne
ne l'apprend. Même famille que [[bug-powersync-role-utilisateur]].

## Migration 0147 — recopie, pas invention

Elle crée le module `passage` (ÉVALUATION) et lui recopie **à l'identique** les
droits et plans de `conseils`. Vérifié ligne à ligne : 21 / 21 / 14 / 14 / 7 / 7,
mêmes plans (institutionnel, pro). Personne ne gagne ni ne perd un droit — c'est
la seule recopie qui ne change le pouvoir de personne, et la raison de la
préférer à un jeu de droits « raisonnable » écrit à la main.

⚠️ `can_write` est une colonne **GÉNÉRÉE** (résumé de create/update/delete) :
l'écrire lève un **428C9**. Ne pas la recopier.

## ⚠️ AVANT le build — l'inverse de 0139/0142/0146

| ordre | conséquence |
|---|---|
| **base d'abord** ✅ | l'ancien build gagne une entrée « Passage » menant au gîte `/user/m/passage`. Le vrai écran reste atteignable par les Conseils. Coût : une ligne redondante chez 33 écoles. |
| build d'abord ❌ | le nouveau build exige `passage.can_read` que personne n'a : « Ouvrir la délibération » renvoie tout le monde au tableau de bord. **La délibération devient impossible partout.** |

Appliquée en production le 2026-08-29. Idem pour la **0148**
([[carte-scolaire-module]]).

## Le garde surveille la CLASSE du défaut

`test/toute_page_ecole_est_un_module_test.dart` ne surveille pas `passage` : il
lit `routes.dart` à la source et exige que **toute** route `/user/*` soit un
module, ou figure dans une liste de routes natives **avec sa raison écrite**.
Un écran ajouté sans y penser fait échouer le test — au moment exact où il faut
y penser.

Vérifié au passage : les modules de communication (annonces, messagerie,
evenements) sont natifs **volontairement** — ils existent au catalogue mais dans
**aucun plan**, donc `activeModulesProvider` (qui joint `plan_modules`) ne les
rend pas. Pas de doublon dans la barre latérale.

Liens : [[evaluation-notes-bulletins]] · [[cloture-examen-classes]] ·
[[non-revenus-et-exclusion]] · [[modules-acces-hierarchie]]
