---
name: examens-stages-dossiers-reels
description: "Dossiers d'examen et de stage avec vrais fichiers téléversables + fiches complètes ; règle \"attaché OU déclaré\" et rattachement par migrations 0056/0057"
metadata: 
  node_type: memory
  type: project
  originSessionId: 3dd519ee-785a-464e-a27d-95c1a6fbc266
  modified: 2026-07-18T14:28:01.178Z
---

Livré le 2026-07-18 (branche `feat/examens-nationaux`, 7 commits `8c6a555`→`8f2efac`).
Le dossier d'examen n'était qu'une **liste de cases à cocher** ; il accepte
désormais les **scans réels**, et une **fiche complète** existe des deux côtés.

**Règle centrale — une pièce est couverte si ATTACHÉE ou DÉCLARÉE.** Le scan est
une preuve *plus forte*, jamais une condition nouvelle. Deux raisons non
négociables : (1) exiger un fichier rendrait incomplets d'un coup tous les
dossiers déjà cochés du pays à la veille d'une clôture ; (2) une chemise
cartonnée / une enveloppe / des frais (`nature` physique/financière) ne seront
JAMAIS un fichier. 4 états : absente → déclarée → fournie → vérifiée.

**Les déclarations n'ont PAS de colonne dédiée** : `déclaré = exigé − manquant −
attaché`, l'inverse exact de la règle d'écriture (`recoverDeclared()` dans
`models/dossier_piece_state.dart`, verrouillé par 4 tests d'aller-retour — une
recomposition ne doit jamais perdre une case cochée).

**Migrations 0056 / 0057** (appliquées prod) ajoutent à `student_documents` :
- `exam_candidate_id` NULL = pièce de l'ÉLÈVE, réutilisée à chaque candidature
  (rien à re-téléverser en réinscription) ; renseigné = pièce de CETTE
  candidature. Pilote par `PieceSource` (eleve / candidature).
- `internship_id` = pièce propre à CE stage (convention signée, fiche
  d'évaluation) — un élève peut avoir plusieurs stages.
⚠️ `student_documents` est synchronisée par `SELECT *` → **aucun redéploiement
de sync-rules**, seulement la colonne dans `powersync_schema.dart`.

**Chemin de téléversement UNIQUE** : `attachStudentDocumentOffline()` dans
`lib/services/powersync/student_document_upload.dart`, utilisé par Examens ET
Stages. Offline-first via `upload_outbox`. Dupliquer cette séquence = deux fois
le risque d'oublier une colonne NOT NULL, et un rejet serveur abandonne le lot
PowerSync entier, silencieusement. Voir [[upload-outbox-fichiers]].

**Dossier figé après dépôt** (`depose`/`valide`), réouverture gardée par
l'action `validate` — la DEC exige parfois une rectification après dépôt.
Garde `_assertWritable` posée dans les ACTIONS, pas seulement dans l'UI.

**Fiches** : `candidate_file_dialog.dart` (identité/scolarité/candidature/
dossier/résultat + PDF officiel, accessible SANS droit d'écriture car c'est une
lecture) et `stage_file_dialog.dart`. La fiche candidat signale la **date de
naissance absente** — cause historique de perte silencieuse, cf.
[[inscription-validation-effectif-a-verifier]].

⚠️ **La table `levels` N'EXISTE PAS** — le niveau vient de `classes.level_code`.

État : analyze 0, 334 tests, build release OK, `.deb` 3.0.2 reconstruit.
**Non vérifié en GUI** (pilote GPU Nouveau instable sur le poste de dev) — à
tester sur Windows/Mac. Voir [[examens-nationaux-socle]], [[gui-testing-linux]].
