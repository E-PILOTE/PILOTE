# Dossiers réels & fiches complètes — Examens et Stages

**Date** : 2026-07-18
**Branche** : `feat/examens-nationaux`
**Statut** : design validé

## Le problème

Le dossier d'inscription à un examen d'État est aujourd'hui une **liste de cases à
cocher**. L'agent déclare « l'acte de naissance est fourni » ; rien ne prouve qu'il
l'est. Trois conséquences, constatées à l'usage :

1. Un candidat affiché « dossier incomplet » ne peut pas être **complété** : il n'y a
   rien à faire d'autre que cocher, donc rien qui change la réalité du dossier.
2. Les **vraies pièces** (scans de l'acte, du diplôme légalisé, du certificat médical)
   n'ont nulle part où vivre côté examen, alors que le bucket et la table existent.
3. Il n'existe **aucune vue complète d'un candidat** : on ne peut pas relire une
   candidature d'un coup d'œil, ni l'imprimer pour le comptoir DEC.

Le module Stages souffre du même défaut : le dialogue ne fait que délivrer
l'attestation ; il n'y a ni fiche de stage complète, ni convention signée
attachable.

Ce n'est pas un oubli : le code le documentait déjà
(`exam_dossier_provider.dart`, l. 14-23 — « Il ne relie pas une pièce à un
FICHIER »). La présente spec ferme cet écart.

## Le principe directeur

> **Une pièce est fournie parce qu'un fichier réel y est attaché — jamais parce
> qu'un agent a coché.**

C'est la règle que le module tient déjà pour `attestation_stage`, satisfaite *par*
le module Stages et jamais cochée à la main. On l'étend à tout le dossier. Le
déclaratif ne disparaît pas : il **se replie** sur les pièces qu'aucun fichier ne
peut représenter.

## Architecture

### Les trois états d'une pièce

| État | Signification | Support en base |
|---|---|---|
| **absente** | rien n'est attaché | aucune ligne `student_documents` |
| **fournie** | un fichier est attaché | `file_url` renseigné |
| **vérifiée** | un agent a ouvert le scan et confirmé qu'il est lisible, au bon nom, et légalisé si exigé | `is_verified` + `verified_by` + `verified_at` |

Les trois colonnes existent déjà : aucune invention. La vérification est le
**pré-contrôle avant le comptoir** — sa valeur est de tracer *qui* a validé, pas
seulement *que* c'est validé.

Seul l'état **absente** compte comme manquant. Une pièce fournie mais non encore
vérifiée ne bloque pas le dépôt : exiger la double action rendrait tout dossier du
pays éternellement incomplet le jour de la clôture.

### Stockage : réutiliser `student_documents`

Le mappage est direct : **`code` de la pièce → `document_type`**.

Une seule migration, une seule colonne :

```sql
ALTER TABLE student_documents
  ADD COLUMN exam_candidate_id uuid NULL REFERENCES exam_candidates(id) ON DELETE CASCADE;
```

Elle porte toute la distinction `PieceSource` déjà modélisée :

- **`source: eleve`** (acte de naissance, diplôme, photos) → `exam_candidate_id IS NULL`.
  La pièce suit l'**élève** : à la réinscription, **rien à re-téléverser**. C'est
  littéralement l'intention de la migration 0008.
- **`source: candidature`** (certificat médical, reçu de frais) → `exam_candidate_id`
  renseigné. La pièce appartient à **cette** candidature ; la recycler d'une session
  sur l'autre serait une faute.

`student_documents` est déjà synchronisée par `SELECT *` dans les sync-rules :
**aucun redéploiement des sync-rules n'est requis**. Seule la déclaration de colonne
dans `powersync_schema.dart` doit suivre.

### Ce qui reste déclaratif — et pourquoi

Une chemise cartonnée ne sera jamais un scan.

- **`nature: physique`** (chemise, enveloppe kaki) → case à cocher, étiquetée
  « fourniture à remettre ».
- **`nature: financiere`** (frais d'inscription) → case à cocher, étiquetée
  « paiement ». Le rattachement au module Paiements est hors périmètre ici.

Prétendre dématérialiser ces pièces produirait un dossier faux. La case reste, mais
elle dit enfin ce qu'elle est.

### `missing_documents` : dérivé, plus déclaré

La colonne continue d'être écrite — tout l'aval en dépend (KPI, exports,
transmissions, `dossier_status`). Elle est désormais **calculée** :

```
missing = pièces inconditionnelles
        − pièces fichier réellement attachées
        − pièces physiques/financières cochées
        − attestation_stage si le module Stages l'a émise
```

Les pièces **conditionnelles** n'y entrent jamais (règle existante, inchangée) : nous
ne savons pas qui est inapte à l'EPS, et la DEC tranche au comptoir.

### Dépôt : figé, réouvrable par la direction

Dès que `dossier_status` vaut `depose` ou `valide`, les pièces passent en **lecture
seule** — un dossier transmis ne doit pas bouger en douce.

La réouverture existe parce que la DEC exige parfois une correction. Elle est gardée
par `canProvider((slug: 'examens', action: 'validate'))` — le même verrou que le
dépôt — et elle est **tracée** : la réouverture repasse le statut à `complet` et
journalise l'acte. Sans cette porte, une exigence de la DEC deviendrait impossible à
satisfaire dans l'app.

### Offline

Le téléversement passe par `upload_outbox` : chemin Storage calculé localement (UUID,
aucun réseau), octets écrits sur le disque, ligne `student_documents` insérée
immédiatement avec ce chemin. Au retour du réseau, le fichier monte au chemin exact.
Une école sans internet joint ses scans normalement ; la pièce « se remplit » d'elle-même.

Corollaire déjà tenu par le module : un refus serveur (RLS, MIME, quota) n'est
**jamais** remis en file — il se reproduirait à l'identique.

## Les écrans

### Fiche candidat (nouveau)

Le modal qui manquait. Une candidature relue d'un coup d'œil :

- **Identité** — photo, matricule, nom, date et lieu de naissance, sexe, nationalité.
- **Scolarité** — classe, filière, niveau, redoublant.
- **Candidature** — n° candidat, examen, session, centre, statut du dossier, dates
  d'inscription et de dépôt.
- **Dossier** — pièce par pièce, avec état, aperçu du scan, téléversement.
- **Stage lié** — si le dossier l'exige (bacs pro/technique).
- **Résultat** — mention, moyenne, source, date.
- **Historique** — parcours du candidat.

**Imprimable** en fiche d'inscription PDF (en-tête officiel République du Congo, via
`OfficialPdfKit`) : la pièce qu'on présente au comptoir.

### Dossier (refonte)

Chaque pièce devient un **emplacement** : téléverser, visualiser (URL signée),
remplacer, supprimer, marquer vérifiée. Les pièces physiques et financières gardent
leur case. La bannière de complétude et le lien Stages sont conservés tels quels.

### Fiche de stage (nouveau) + pièces

Symétrique côté Stages : élève, entreprise, tuteurs, dates, évaluation, attestation.
Pièces attachables : **convention signée scannée**, **fiche d'évaluation du tuteur**.
Les PDF déjà livrés (attestation, convention, liste) restent accessibles depuis la fiche.

## Ce que cette spec ne fait pas

- **Pas de rattachement des frais au module Paiements.** La pièce financière reste
  déclarative. Le lien mérite son propre chantier.
- **Pas d'OCR ni de contrôle automatique du contenu des scans.** L'app vérifie qu'un
  fichier est là ; c'est un humain qui atteste qu'il est le bon. Prétendre le
  contraire serait mentir sur la garantie offerte.
- **Pas de compression d'image dédiée.** Le pipeline existant est réutilisé tel quel.

## Tests

- **Dérivation de `missing_documents`** : pièce fichier attachée → non manquante ;
  pièce physique cochée → non manquante ; pièce conditionnelle → jamais manquante ;
  `attestation_stage` émise dans Stages → non manquante.
- **Portée d'une pièce** : `source: eleve` retrouvée sur une nouvelle candidature du
  même élève ; `source: candidature` **non** retrouvée.
- **Verrou de dépôt** : dossier `depose` → écritures refusées ; réouverture permise
  seulement avec l'action `validate`.
- **Offline** : téléversement sans réseau → ligne présente, entrée en file, chemin
  cohérent.
