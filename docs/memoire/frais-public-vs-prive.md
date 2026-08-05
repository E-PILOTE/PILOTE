---
name: frais-public-vs-prive
description: "💰 L'argent de l'école : le GROUPE définit tout barème, l'école applique ; pas de barème = pas d'encaissement ; ⚠️ l'alerte de dépassement porte sur le CUMUL versé, pas sur un versement"
metadata: 
  node_type: memory
  type: project
  originSessionId: db933423-7daf-438d-9460-97e0abf9b86b
  modified: 2026-08-04T21:25:24.454Z
---

# Frais de scolarité — public contre privé (2026-08-04)

Spéc : `docs/superpowers/specs/2026-08-04-frais-scolarite-public-prive-design.md`
Plan lot 0 : `docs/superpowers/plans/2026-08-04-finance-lot0-recu-inviolable.md`

## Le cadre réel (corrigé par le ministère, sa parole prime)

- Loi 25-95 art. 1 : « l'enseignement public est gratuit » → **mensualité
  illégale en public**.
- **Inscriptions payantes en public depuis ~2022.** ⚠️ Le web ouvert ne le
  documente NULLE PART — ne pas chercher à le vérifier en ligne.
- **Enseignants non fonctionnaires payés DIRECTEMENT par l'État** depuis
  l'accord du 16/10/2023 (bourse mensuelle, contrats 5 ans, signé METP **et**
  MEPSA). METP verse ; MEPSA accuse 10 mois d'arriérés (RNEC, 29/07/2026) →
  l'APE y comble encore le trou. ⚠️ « l'APE paie les volontaires » était vrai
  en 2018, plus en 2026.
- Frais d'examen : tarif d'État identique public/privé. BAC 5 000 · BEPC 4 000 ·
  CEPE 2 000 · concours 3 000 (officiel) ; 15 000 / 10 000 / 3 000 (libre).
  METP les fixe par **note de service** (ex. 0015/METP-CAB/DECTP-SD du 09/12/24).
- **Surfacturation massive dénoncée par l'APEEC** : 25 000–35 000 F réclamés
  pour le BAC contre 5 000. C'est l'argument de vente du module au ministre.

## Les règles gelées

1. **Un ministère est un groupe scolaire.** Pas de table « nationale ».
   Tout barème vit dans `fee_structures` avec `school_id NULL` = tout le groupe.
2. **Le groupe définit, l'école applique.** Les mutations côté école sont
   retirées — y compris `setExamFeeAmount`, qui laissait l'école fixer son
   propre frais d'examen : la surfacturation était implémentée comme une
   fonctionnalité.
3. **Un paiement est un VERSEMENT sur une obligation.** Le montant se choisit,
   l'avance partielle est normale.
4. **Pas de barème → pas d'encaissement.** Prérequis BLOQUANT du 2 octobre.
5. Le groupe définit les motifs d'exonération, l'école **constate** (même
   grammaire que [[ecole-constate-une-arrivee]]).

## ⚠️ Pièges

**L'alerte de dépassement porte sur le CUMUL versé, jamais sur un versement.**
3 × 2 000 sur un tarif de 5 000 dépassent sans qu'aucun ne dépasse seul.

**Trois couches, pas deux.** Un barème de groupe (`school_id IS NULL`) est
invisible dans les sync-rules (`WHERE school_id = bucket.sid`), dans la RLS
(`school_id = auth_school_id()`) **et** dans `feeStructuresProvider`
(`WHERE f.school_id = ?`). Les corriger ensemble ou le ministère définira des
tarifs que personne ne verra.

**`fee_type` avait `'mensualite'` pour DÉFAUT** en base — retiré : rien ne doit
devenir une mensualité par omission, surtout dans le public (30 écoles / 8 130
élèves contre 7 / 974 dans le privé).

## Lot 0 livré (2026-08-04) — migration 0094

Le numéro de reçu valait les 6 derniers chiffres de l'horloge en ms → il
recommençait **toutes les 16 min 40 s** sous une contrainte d'unicité
NATIONALE. Collision → 23505 → `_fatalResponseCodes` → transaction abandonnée,
**paiement perdu**. ~2 000 encaissements suffisaient pour 86 % de risque.
Corrigé : `REC-{code10}-{aa}-{poste6}-{seq6}`, unicité passée à
`(school_id, receipt_number)`, séquence **relue en base** (survit à une purge).

Aussi : reçu PDF (il n'en existait aucun — au Congo le reçu EST la preuve),
annulation motivée au lieu du `DELETE` sec, remboursement doté d'un contenu.

⚠️ `await showDialog` rend la main au `pop`, PAS à la fin de l'animation :
une boîte à champ texte DOIT posséder son contrôleur. Réintroduit puis
recorrigé — cf. [[reprise-du-poste]].

## Restant : lots 1 à 3

1. `academic_year_id` sur les paiements (aujourd'hui aucune requête ne borne
   l'année) · dû réel · exonérations · remboursement à l'écran.
2. Barèmes au groupe · secteur au vocabulaire · versement/avance.
3. Tarif figé à l'encaissement · écran « Écarts au tarif officiel ».

Hors périmètre : Mobile Money, comptabilité générale, **arrêté de caisse**
(rien ne dit combien il y a en caisse ce soir), transfert inter-groupe.

Liens : [[statut-emploi-personnel]] · [[finance-categorie]] ·
[[secteur-ecole-herite-groupe]] · [[premiere-heure-etablissement]]
