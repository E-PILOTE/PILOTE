---
name: deploiement-national-octobre
description: "Présentation au ministère le 1er octobre 2026, déploiement national le 2 — Windows seul, par vagues ; et les ruptures de cycle de vie qui restent ouvertes"
metadata: 
  node_type: memory
  type: project
  originSessionId: db933423-7daf-438d-9460-97e0abf9b86b
  modified: 2026-08-03T15:09:06.823Z
---

# Le calendrier réel (fixé le 2026-08-03)

- **1er octobre 2026** — présentation au ministère (repoussée depuis août).
- **2 octobre 2026** — **déploiement officiel sur le territoire congolais**.

Décisions du user, prises le 2026-08-03 :
- **Windows seul** le 2 octobre. macOS reporté après.
- **Déploiement par vagues**, pas mille écoles d'un coup.

Ce n'est plus une démo : c'est une mise en production nationale. Les manques
listés ci-dessous cessent d'être théoriques.

## ✅ LES DEUX QUESTIONS SONT TRANCHÉES (user, 2026-08-03 17:07)

> « nous n'avons pas d'autres données en dehors de ce que nous savons et le
> Congo n'a pas ce système, nous innovons tout (certificat de signature de
> code etc.) »

**1. AUCUN FICHIER MINISTÉRIEL N'EXISTE.** Il n'y a rien à importer d'un
système antérieur : le Congo n'en a pas. La donnée du 2 octobre sera **saisie
par les écoles elles-mêmes**. Conséquence majeure sur la priorisation : le
chantier n'est pas « import de masse » mais **VITESSE DE SAISIE + première
heure d'une école**. Une école de 400 élèves qui met 2 min par élève y passe
13 heures.

**2. AUCUNE AUTORITÉ EXTÉRIEURE NE VALIDE RIEN.** Le user EST le ministère
(DSIC/METP) — [[user-fonctionnaire-dsic-metp]]. Les nomenclatures que j'ai
posées (11 motifs de sortie d'élève, 17 motifs de mouvement d'agent, INE 11
chiffres) **font foi**. Ne plus les présenter comme « en attente de
validation » : elles sont la référence nationale, à faire évoluer sur décision
du user seul.

**3. Le certificat de signature n'existe pas non plus** — il est à CRÉER, pas à
retrouver. Partie faisable côté technique : rendre la CI **prête à signer**
(étape pilotée par un secret, inerte s'il est absent) + **plan B** documenté
(procédure SmartScreen + empreintes SHA-256 publiées). Voir
[[chaine-livraison-windows]].

## Les ruptures de cycle de vie (analyse du 2026-08-03, base live vérifiée)

### Élève
- ⚠️ **Aucun identifiant national.** Le matricule est tiré par l'école, pour
  l'école. Un élève qui change d'établissement devient une seconde personne :
  parcours national incalculable, taux d'abandon incalculable, doublons dans
  les effectifs — donc dans les dotations. `student_match_provider.dart` existe
  déjà pour rattraper le doublon à la main.
- Le **motif de sortie** est du texte libre (`withdrawal_reason`) → aucun
  agrégat national. Il faut une nomenclature fermée (abandon, décès, exclusion,
  grossesse, départ, raisons économiques).
- Le **non-réinscrit** n'existe pas : il reste `active` sur l'année passée et
  n'a pas de ligne sur la nouvelle. Ni sorti, ni présent — invisible. C'est
  pourtant le premier signal de déperdition.
- `discipline_incidents` **ne débouche sur aucun changement d'état** de
  scolarité : une exclusion définitive ne retire pas l'élève de l'effectif.
- Le cycle n'est **jamais exercé** dans les données : 9 103 `active`, 1
  `transferred`, 0 `withdrawn`, 0 `graduated`, 0 décision de passage.

### Personnel
- ⚠️ **La sortie d'un agent n'est pas modélisée** — un seul booléen
  `profiles.is_active` pour huit situations juridiquement distinctes :
  mutation, détachement, disponibilité, retraite, démission, licenciement,
  décès, fin de contrat.
- **La mutation détruit la carrière** : muter = désactiver ici + recréer
  là-bas = nouveau `profiles.id` → ancienneté, diplômes, congés, paie coupés en
  deux. Symétrique exact du problème d'identifiant élève, et plus grave : un
  enseignant congolais est un fonctionnaire NATIONAL souvent réaffecté.
- `teacher_subjects` n'a **pas de date de fin** : un agent parti reste affecté
  à ses classes dans l'emploi du temps. Aucune notion de **suppléance**.
- L'école **ne crée pas ses agents** (`createUser` est côté `admin_groupe`).
- La table `inspections` **existe et n'a aucun module** — la notation annuelle,
  pièce maîtresse de l'avancement d'échelon, n'a pas d'écran.
- `staff_members` est une table **morte** : l'agent vit dans `profiles`.

### Plateforme
- **Aucun import de masse.** 34 générateurs PDF exportent, rien n'importe.
  Premier obstacle réel au déploiement.
- Aucune politique d'**archivage** (431 250 notes pour 9 104 élèves en un an).
- Aucune **réversibilité** (export complet d'une école) — un État l'exige.
- `employee_number` est **nullable et sans unicité**.

### Documents manquants, par nécessité réglementaire
Élève : **certificat de scolarité** (le plus demandé au guichet), **certificat
de radiation / exeat** (sans lui le module Transferts s'arrête à mi-chemin),
relevé de notes annuel, attestation de réussite, carte scolaire.
Personnel : **attestation de travail**, décision de mutation, état de services,
attestation de cessation de service, fiche de notation.
Établissement : **registre matricule** (document légal), état statistique de
rentrée.

**How to apply :** l'ordre importe. L'identité (élève + agent) doit être posée
**avant** que la donnée entre — rétro-adapter après un million d'élèves coûte
dix fois plus cher.

Liens : [[chaine-livraison-windows]] · [[plateformes-cibles-windows-mac]] ·
[[seed-demo-national-pipeline]] · [[staff-personnel-annuaire]] ·
[[cloture-examen-classes]]
