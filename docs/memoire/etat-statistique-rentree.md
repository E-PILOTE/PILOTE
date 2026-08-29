---
name: etat-statistique-rentree
description: "📊 État statistique de rentrée (2026-08-29) — ⚠️ l'âge se calcule à la DATE D'OUVERTURE de l'année, jamais « aujourd'hui » ; aucun élève n'est jeté ni réparti au hasard ; `schools.tutelle` ajoutée au schéma local"
metadata:
  node_type: memory
  type: project
---

# L'état statistique de rentrée (2026-08-29)

Le formulaire que chaque école remonte à sa circonscription : effectifs par
niveau et par sexe, redoublants, nouveaux inscrits, pyramide des âges,
situations particulières, personnel. C'est de là que sortent les statistiques
nationales — et les dotations.

Dernier des documents réglementaires manquants du relevé
[[deploiement-national-octobre]]. Aucune table nouvelle : tout se recompose
depuis `class_enrollments` + `classes` + `students` + `profiles`.

## ⚠️ Le défaut d'un document statistique est un chiffre faux AFFIRMÉ

Un registre qui perd une ligne se remarque ; un total faux, non — il a
exactement l'air d'un total. Trois règles en découlent :

### 1. L'âge se calcule à une DATE FIXE

`year.startDate`, l'ouverture de l'année — **jamais « aujourd'hui »**. Sinon le
même état, réédité en juin, ne donne plus les chiffres remontés en octobre, et
c'est l'administration qui découvre l'écart entre deux éditions du même
document. La date est **imprimée** sur le PDF.

`ageA(naissance, reference)` est une fonction pure, testée au jour près
(anniversaire le jour même = âge atteint ; 29 février ; le lendemain).

### 2. Personne n'est jeté ni réparti au hasard

Sexe absent, date de naissance absente, inscription sans classe ou sans
dossier : chacun est **compté à part**, dans une colonne « non renseigné » qui
**reste affichée même à zéro** — sa présence dit que la question a été posée.

⚠️ Le total INCLUT les non renseignés (sinon l'effectif est sous-déclaré), et
la **part de filles se calcule sur ce total**. Calculer 60/100 quand l'école
compte 125 élèves surestimerait la scolarisation des filles — précisément
l'indicateur que ces états servent à suivre. Une école vide rend `null`, pas
« 0 % » : un zéro est une affirmation, une absence n'en est pas une.

### 3. Le dénominateur est l'INSCRIPTION, pas l'élève

Inscriptions **actives de l'année en cours**. Un élève radié en novembre n'a pas
fait la rentrée.

## Décisions

- **`schools.tutelle` ajoutée au schéma PowerSync local.** Premier champ de la
  fiche d'identification : il décide à quelle administration l'état est remonté
  (MEPSA/METP). La colonne existe en base depuis l'origine → aucun risque de
  42703, et le poste école **n'écrit jamais `schools`** (vérifié : aucun
  `UPDATE schools` dans `lib/`), donc rien ne peut l'écraser.
- **Un niveau introuvable ne fait pas disparaître l'élève** : rangé sous « Non
  précisé », visible, total juste.
- **Un rôle de personnel inconnu s'affiche tel quel** — le taire retirerait des
  agents du total.
- **L'écran montre exactement ce que le PDF portera, dans le même ordre.** Un
  écran plus flatteur que le document remonté serait la pire des interfaces :
  celle qui rassure avant de faire signer.

## Où c'est

`students/providers/etat_rentree_provider.dart` ·
`students/services/etat_rentree_pdf_service.dart` ·
`students/screens/etat_rentree_screen.dart` ·
route `/user/documents/etat-rentree` (sous-chemin de `documents`, donc même
verrou — comme [[registre-matricule]] et [[registre-documents-delivres]]).

L'écran Documents est devenu le **hub des papiers de l'école** : trois boutons
— état de rentrée, registre matricule, documents délivrés.

Garde : `test/etat_rentree_test.dart` — 22 tests, dont deux qui fabriquent
réellement le PDF, et un qui vérifie que les tranches d'âge couvrent 0→30 sans
trou ni recouvrement.

Liens : [[registre-matricule]] · [[registre-documents-delivres]] ·
[[deploiement-national-octobre]]
