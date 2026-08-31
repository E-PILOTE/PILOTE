---
name: copie-tutelle-agrement-forcee
description: "⚠️ UN SEUL écran crée un groupe (les abonnements en créaient un SANS tutelle) ; migs 0163/0164 : tutelle NOT NULL et copies FORCÉES à chaque écriture ; on pouvait ajouter un agrément mais jamais l'enlever"
metadata: 
  node_type: memory
  type: project
---

**2026-08-31.** Trois défauts d'une même famille : une copie qu'on tenait par
discipline plutôt que par contrainte.

## ⚠️ Le plus grave : DEUX écrans créaient un groupe scolaire

`super_admin/screens/subscriptions_screen.dart` avait son propre dialogue
« Créer un groupe & son abonnement », atteignable (`onAdd: () => _openForm()`),
qui n'envoyait **ni tutelle, ni agrément, ni secteur**.

Un groupe né là :
- n'apparaît dans le réseau d'**aucun** ministère (`tutelle_ecoles()`, mig 0158) ;
- ne reçoit **aucune circulaire** (mig 0161) ;
- et ses écoles héritent d'une **tutelle nulle** par le déclencheur de 0153.

C'est exactement la brèche que 0155 et 0158 avaient fermée — rouverte par un
second formulaire. **Deux formulaires de création aux champs différents, c'est
la garantie qu'un groupe naîtra un jour à moitié configuré.**

Le chemin est retiré : le bouton mène à l'écran des groupes, et le dialogue
lève un `StateError` s'il est ouvert sans `editing`. Gardé par
`test/tutelle_du_groupe_test.dart` — « un SEUL écran crée un groupe scolaire ».

## 0163 — `tutelle` NOT NULL

0 groupe et 0 école sans tutelle, et le build qui la renseigne est publié : la
contrainte de 0153 pouvait tomber.

⚠️ **Sûr côté postes** : `trg_school_herite_tutelle` est **BEFORE INSERT**, donc
un poste qui envoie une école sans tutelle la reçoit avant le contrôle.
Vérifié : insertion sans tutelle → le déclencheur pose `metp`, l'insertion passe.
Un groupe sans tutelle, lui, est refusé **23502**.

## 0164 — deux trous dans une copie censée ne pas diverger

**1. Les déclencheurs étaient en `UPDATE OF group_id`.** Écrire *directement*
`schools.tutelle` ne les réveillait donc pas : la valeur écrite restait. Seul un
commentaire de colonne l'interdisait. Une école dont la tutelle diverge sort de
`tutelle_ecoles()` et de toute circulaire — **elle reste parfaitement visible à
son propre écran, c'est son ministère qui la perd.**

**2. On pouvait AJOUTER un agrément, jamais l'ENLEVER.** Les deux fonctions ne
recopiaient que `IF agrement_numero IS NOT NULL`. Un groupe qui corrige un
numéro erroné en l'effaçant laissait ses écoles porter l'ancien —
**indéfiniment, et ce numéro s'imprime sur les attestations**. Un numéro périmé
sur un document officiel est pire que pas de numéro du tout.

Les deux déclencheurs passent en `BEFORE INSERT OR UPDATE` (toutes colonnes) et
recopient **toujours**, valeur vide comprise.

### Mesuré, transaction annulée

| | résultat |
|---|---|
| forcer `tutelle='mepsa'` sur une école METP | **reste `metp`** |
| inventer un `agrement_numero` sur une école | **revient à nul** |
| poser l'agrément sur le groupe | propagé **12 / 12** |
| **effacer** l'agrément du groupe | **0 école** garde un numéro |

## La règle, désormais tenue par la base

> **L'agrément appartient à la personne morale, donc au GROUPE.** Une école n'a
> jamais le sien propre : elle porte celui de son groupe, ou rien.

Un second garde (`test/tutelle_du_groupe_test.dart`) exige qu'un **seul** fichier
de `lib/` écrive `'agrement_*':` — le formulaire de groupe. Un écran qui
l'écrirait ailleurs afficherait « enregistré » sur une valeur que la base vient
d'écraser : le pire des deux mondes.

Voir [[tarif-par-ecole-et-couts-reels]] · [[circulaire-de-tutelle]]
