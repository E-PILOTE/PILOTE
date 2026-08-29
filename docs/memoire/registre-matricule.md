---
name: registre-matricule
description: "📖 Registre matricule — le grand livre réglementaire (2026-08-29) ; ⚠️ le filtre `is_active` des sync-rules faisait DISPARAÎTRE les archivés de tous les postes ; le registre compte ses LACUNES et les imprime"
metadata:
  node_type: memory
  type: project
---

# Le registre matricule (2026-08-29)

Le grand livre que l'inspection demande : **tous** les élèves inscrits depuis
l'ouverture, dans l'ordre des matricules, avec état civil, tuteur, date
d'entrée, date et motif de sortie. À ne pas confondre avec
[[registre-documents-delivres]] (les papiers émis) ni avec l'écran Élèves (qui
montre qui est *là*).

Aucune table nouvelle : le registre se recompose à chaque édition depuis
`students` + `class_enrollments` + `student_tutors`.

## ⚠️ La fuite trouvée en le construisant

Les sync-rules descendaient `students` avec **`AND is_active = true`**. Or
`deactivateStudent` met `is_active = 0` : l'élève **sortait du bucket et
disparaissait de tous les postes**, dossier compris. Le grand livre aurait perdu
sa ligne — et l'école ne s'en serait aperçue qu'à l'inspection.

Le filtre est **retiré** (`SELECT * FROM students WHERE school_id = bucket.sid`).
Coût nul aujourd'hui (0 archivé sur 9 106), négligeable ensuite. Les écrans
filtrent déjà `is_active` dans leurs propres requêtes : un archivé ne réapparaît
nulle part sauf là où on le demande. **Exige un déploiement des sync-rules**,
comme [[registre-documents-delivres]] — un seul déploiement pour les deux.

## Un registre qui connaît ses trous

Tant que le déploiement n'a pas eu lieu (et pour tout autre défaut de synchro),
le registre **compte ses lacunes** : une inscription dont l'élève est
introuvable en local est la *signature* d'une ligne manquante. Le compte est
affiché **en rouge, au-dessus du bouton**, et écrit sur le PDF — en tête et dans
l'arrêté.

> Une pièce réglementaire qui se prétend complète sans l'être est pire qu'une
> pièce qui déclare sa limite : la seconde se complète, la première trompe.

## Les deux défauts qui échouent en silence

1. **L'ORDRE.** Un tri de chaînes place `M-10` avant `M-9`. Sur un grand livre,
   cela déplace des lignes de plusieurs pages et fait échouer la recherche d'une
   inscription précise — le geste même pour lequel on ouvre le registre. D'où
   `compareMatricule`, qui compare segment par segment et lit les suites de
   chiffres comme des nombres. Fonction pure, testée.
2. **LA GÉOMÉTRIE.** Douze colonnes en A4 paysage. Un débordement ne se voit pas
   à l'aperçu de la première page, mais à la centième — le registre est alors
   déjà relié. La somme des largeurs est **vérifiée par un test**
   (`kColonnesRegistre` ≤ 786 pt), ainsi que l'appariement en-têtes/colonnes.

## Décisions

- **`pw.MultiPage`, et c'est correct ici.** `AttestationKit` impose `pw.Page`
  (une signature qui bascule n'authentifie plus rien) ; un registre est fait
  pour courir sur cent pages. Les deux règles coexistent.
- **Le nombre d'inscrits n'est PAS écrit en toutes lettres.** La formule
  traditionnelle le fait parce que sur papier un chiffre se rature. Ici le
  document se régénère depuis la base : la protection n'a plus d'objet, et un
  nombre épelé à moitié juste vaudrait moins que le chiffre.
- **Route sous `documents`, pas sous `eleves`** : `/user/eleves/:id` capterait
  `/user/eleves/registre-matricule` comme un identifiant d'élève. Le
  rattachement est de toute façon juste — même verrou, mêmes mains.
- **L'archivé est marqué « (archivé) »** sur sa ligne, pas retiré.

## Où c'est

`students/providers/registre_matricule_provider.dart` (assemblage en trois
lectures locales plutôt qu'une jointure de trente lignes illisible) ·
`students/services/registre_matricule_pdf_service.dart` ·
`students/screens/registre_matricule_screen.dart` ·
route `/user/documents/registre-matricule`, atteinte depuis l'écran Documents.

Garde : `test/registre_matricule_test.dart` — 21 tests, dont **trois qui
fabriquent réellement le PDF** (120 lignes, donc plusieurs pages : le vrai
risque d'un tableau paginé n'est pas la première page, c'est la rupture).

Liens : [[registre-documents-delivres]] · [[attestations-emises]] ·
[[carte-scolaire-module]] · [[ine-identifiant-national-eleve]]
