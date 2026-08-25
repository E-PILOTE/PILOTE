---
name: ine-identifiant-national-eleve
description: "L'INE — 11 chiffres avec clé de Luhn, attribué par le SERVEUR ; unicité (ine, school_id) et non ine seul ; guichet national ouvert à toute école"
metadata: 
  node_type: memory
  type: project
  originSessionId: db933423-7daf-438d-9460-97e0abf9b86b
  modified: 2026-08-03T13:21:38.671Z
---

# L'identifiant national de l'élève (migrations 0080/0081, 2026-08-03)

## Le problème qu'il règle

`students.matricule` est unique **par groupe** et `createStudent` en tire un
neuf à chaque inscription. Le transfert, lui, ne fait que **sortir** l'élève :
il ne touche pas `students.school_id` et **ne crée rien à l'arrivée**. L'école
d'accueil relance l'assistant → l'enfant devient une seconde personne.

## Les décisions, et pourquoi

**Format** : `YY` + séquence 8 chiffres + clé de Luhn = 11 chiffres, affichés
`26-00000123-4`. Tout en chiffres : un identifiant se dicte au téléphone. La
clé fait qu'un chiffre inversé est REJETÉ au lieu de désigner un autre enfant.
⚠️ Le ministère a confirmé le 2026-08-03 qu'**aucun identifiant officiel
n'existait** — celui-ci fait foi.

**Le SERVEUR attribue, jamais l'appareil.** L'app inscrit hors ligne ; un
identifiant tiré localement serait soit trop long pour être dicté, soit
séquentiel — et deux postes hors ligne d'une même école collisionneraient. Une
violation d'unicité à la remontée fait abandonner à PowerSync le **lot entier**
([[type-local-suit-type-serveur]]). Conséquence assumée : un élève inscrit hors
ligne n'a pas d'INE tant que le poste n'a pas synchronisé.

**⚠️ UNIQUE (ine, school_id), PAS UNIQUE (ine).** Une ligne `students` n'est pas
une personne, c'est une **personne DANS UNE ÉCOLE**. L'unicité globale
interdirait exactement ce qu'on cherche. Sous cette forme, `WHERE ine = ?` rend
le parcours complet école par école.

**Le trigger IGNORE toute modification** au lieu de la rejeter : un poste hors
ligne remonte la ligne entière avec `ine = NULL`. Refuser perdrait le lot.

## Le guichet national — `rechercher_eleve_national(nom, prénom, naissance)`

Décision du ministère : **toute école** peut interroger, sur identité exacte.
Restreindre au groupe aurait laissé la continuité cassée là où elle casse le
plus (public → privé). Garde-fous : trois champs exigés, projection minimale
(ni adresse, ni tuteurs, ni santé, ni paiements), **journalisation de chaque
appel** (action `RECHERCHE_NATIONALE`, ≤ 20 car. obligatoires), `search_path`
figé ([[referentiel-examens-au-ministere]] — faille déjà refermée une fois).

⚠️ `unaccent` a été installé pour ça : sans lui « Kimbembe » ne retrouve pas
« Kimbembé », et l'école crée le doublon.

⚠️ **Ce provider appelle `supabase.rpc()` depuis le code du personnel scolaire**
— pas une entorse à la règle offline-first : les élèves des autres écoles ne
sont pas sur l'appareil et ne doivent pas y être. L'assistant fonctionne sans.
Un BOUTON, pas une recherche pendant la frappe : chaque appel est journalisé.

## État

9 104 élèves ont reçu leur INE (tous distincts, clés justes, ordre chronologique
respecté). ⚠️ La séquence a des trous — la fonction volatile est évaluée deux
fois par ligne ; un INE **n'est pas un compteur d'élèves**.

Source unique côté app : `lib/core/utils/ine.dart`, à tenir identique à
`luhn_cle()` en base — même règle que [[bareme-mention-source-unique]].

**Reste à faire** : imprimer l'INE sur les documents (certificat de scolarité,
fiche, dossier ministère) ; brancher le panneau sur l'écran Transferts.

Liens : [[deploiement-national-octobre]] · [[inscription-module-logique]] ·
[[scolarite-transferts-documents-annuaire]]
