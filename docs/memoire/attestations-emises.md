---
name: attestations-emises
description: "Les papiers que l'école ÉMET (scolarité, radiation, travail) — charpente unique AttestationKit ; le REFUS de délivrer un faux est la partie utile"
metadata: 
  node_type: memory
  type: project
  originSessionId: db933423-7daf-438d-9460-97e0abf9b86b
  modified: 2026-08-03T14:58:10.439Z
---

# Les attestations que l'école délivre (2026-08-03)

## La distinction que personne n'avait vue

Le module « Documents » (`features/students/.../documents_*`) suit les pièces
que l'école **REÇOIT** — acte de naissance, photo, certificat médical. Rien ne
lui permettait d'**ÉMETTRE**. Or c'est le travail quotidien d'un secrétariat :
certificat de scolarité pour une bourse, un transport, un visa ; attestation de
travail pour la banque d'un agent. Ces papiers se tapaient à la machine.

## Charpente unique — `core/services/attestation_kit.dart`

`AttestationKit.build()` : en-tête officiel, cartouche, corps, **bloc de
signature + espace pour le cachet**, pied. Utilisée par
`students/services/attestations_pdf_service.dart` et
`staff/services/attestation_travail_pdf_service.dart`.

⚠️ **`pw.Page`, JAMAIS `pw.MultiPage`** : une attestation dont la signature
bascule sur la page suivante n'authentifie plus rien. (À ne pas confondre avec
[[ministere-palmares-eleves-reseau]] où `frame()` ne se scinde pas.)

## Le refus est la fonctionnalité

- `peutDelivrerScolarite(status)` → **seulement `active`**.
- `peutDelivrerRadiation(status)` → **seulement `withdrawn|transferred|graduated`**.
- `peutDelivrerAttestationTravail(isActive:)`.

Un certificat de scolarité pour un élève sorti est un **faux** ; le certificat
de radiation pour un élève présent est le faux symétrique. Test : aucun statut
ne rend les deux délivrables ensemble.

## Décisions

- Le **certificat de radiation est proposé à l'instant où la sortie est
  prononcée** (`_exit` dans `eleves_drawer.dart`), pendant que la famille est au
  guichet. Il porte l'**INE** et dit à l'école d'accueil de chercher avec —
  c'est là que l'INE devient un service ([[ine-identifiant-national-eleve]]).
- **Accord en genre** (« née », « inscrite », « radiée ») : un certificat qui se
  trompe est refusé au guichet.
- **Le signataire n'est proposé que si l'agent connecté est directeur ou
  proviseur.** Un secrétaire imprime, il ne signe pas.
- **Jamais de salaire** sur une attestation de travail — ce serait un bulletin
  de paie déguisé, et la Paie a son propre document et ses propres droits.
- `serviceRendu: true` → attestation au passé pour un agent parti
  ([[carriere-agent-mutation]]).

## Cas testés parce qu'ils sont RÉELS, pas limites

Élève sans INE (saisie hors ligne), agent **sans `hire_date`** (la colonne est
vide sur toute la base), radiation sans motif, document sans signataire.

## Reste à faire

Registre matricule (le grand livre réglementaire), et le journal des
attestations délivrées (qui a délivré quoi, quand — aucune table ne le trace).

Liens : [[motifs-de-sortie-eleve]] · [[scolarite-transferts-documents-annuaire]] ·
[[staff-personnel-annuaire]]
