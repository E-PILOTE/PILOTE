# Dossiers réels & fiches complètes — Plan d'implémentation

> Exécution **inline** dans la session qui a écrit la spec
> (`docs/superpowers/specs/2026-07-18-examens-stages-dossiers-fiches-design.md`).
> Le plan fixe fichiers, interfaces et cas de test ; l'implémentation suit la spec.

**But** : lier chaque pièce du dossier d'examen à un fichier réel (téléversable,
visualisable, vérifiable), offrir une fiche candidat complète et imprimable, et
appliquer le même traitement aux Stages.

**Architecture** : réutilisation de `student_documents` (+1 colonne nullable
`exam_candidate_id`) et de `upload_outbox` pour l'offline. Aucune nouvelle table.

## Contraintes globales

- Personnel scolaire → **PowerSync uniquement** (`db.watch`/`db.execute`/`db.getAll`),
  jamais `supabase.from()`. Storage est l'exception (réseau) → passe par `upload_outbox`.
- Tout INSERT offline couvre **toutes** les colonnes NOT NULL sans défaut ;
  `id`, `created_at`, `updated_at` posés à la main.
- Dart **≤ 500 lignes** par fichier.
- `flutter analyze` doit rester à **0 issue** ; tests verts avant chaque commit.
- Jetons de thème (`kNavy`, `kGreen`…) sont **runtime** → jamais `const` sur eux.
- Un refus serveur n'est jamais remis en file (`isTransportFailure`).

---

### Tâche 1 — Migration + schéma local

**Fichiers**
- Créer : `database/migrations/0056_student_documents_exam_candidate.sql`
- Modifier : `epilote/lib/services/powersync/powersync_schema.dart` (table `student_documents`)

**Produit** : colonne `exam_candidate_id` disponible en base **et** en SQLite local.

- [ ] Migration : `ADD COLUMN exam_candidate_id uuid NULL REFERENCES exam_candidates(id) ON DELETE CASCADE` + index partiel `WHERE exam_candidate_id IS NOT NULL`. Idempotente (`IF NOT EXISTS`).
- [ ] Appliquer en prod, vérifier via `information_schema.columns`.
- [ ] Ajouter `Column.text('exam_candidate_id')` au schéma PowerSync.
- [ ] Confirmer qu'aucun changement de sync-rules n'est requis (`SELECT *` déjà en place).
- [ ] Commit.

---

### Tâche 2 — Dérivation : pièce ↔ fichier (cœur logique, TDD)

**Fichiers**
- Créer : `epilote/lib/features/examens/models/dossier_piece_state.dart`
- Créer : `epilote/test/exam_dossier_derivation_test.dart`

**Interfaces produites**

```dart
enum PieceFileState { absente, fournie, verifiee }

class AttachedPiece {
  final String documentId;      // student_documents.id
  final String code;            // = document_type
  final String fileUrl;
  final String fileName;
  final bool isVerified;
  final String? verifiedBy;
  final DateTime? verifiedAt;
  final String? examCandidateId; // null = pièce de l'élève (réutilisable)
}

/// Pièces manquantes = inconditionnelles − attachées − cochées − stage émis.
List<ExamDossierPiece> deriveMissing({
  required List<ExamDossierPiece> required_,
  required Set<String> attachedCodes,
  required Set<String> declaredCodes,   // physiques / financières cochées
  required bool stageIssued,
});
```

**Cas de test (écrits AVANT l'implémentation)**
- pièce `fichier` attachée → absente de `missing`
- pièce `fichier` non attachée → présente dans `missing`
- pièce `physique` cochée → absente ; non cochée → présente
- pièce **conditionnelle** → **jamais** dans `missing`, attachée ou non
- `attestation_stage` + `stageIssued: true` → absente de `missing`
- liste d'exigences vide → `missing` vide

- [ ] Écrire les tests, les voir échouer, implémenter, les voir passer, commit.

---

### Tâche 3 — Actions : joindre, vérifier, retirer (offline-first)

**Fichiers**
- Créer : `epilote/lib/features/examens/providers/exam_dossier_actions.dart`
- Modifier : `epilote/lib/features/examens/providers/exam_dossier_provider.dart`
  (charger les pièces attachées, produire l'état dérivé)

**Interfaces produites**

```dart
Future<void> attachDossierPiece({required String candidateId, required String studentId,
  required ExamDossierPiece piece, required String fileName, required Uint8List bytes});
Future<void> setPieceVerified(String documentId, {required bool verified});
Future<void> removeDossierPiece(String documentId);
Future<void> reopenDossier(String candidateId);   // depose/valide → complet
Future<String?> signedPieceUrl(String fileUrl);
```

Règles :
- `exam_candidate_id` = `null` si `piece.source == PieceSource.eleve`, sinon `candidateId`.
- Téléversement : `buildStoragePath` + `enqueueUpload` (bucket `student-documents`),
  puis `INSERT student_documents` avec **toutes** les colonnes NOT NULL.
- Après toute mutation : recalculer et réécrire `missing_documents` + `dossier_status`.
- Refus si le dossier est `depose`/`valide` (garde côté action, pas seulement UI).

- [ ] Implémenter, tester la portée élève/candidature et le refus si déposé, commit.

---

### Tâche 4 — Refonte du dialogue Dossier

**Fichiers**
- Modifier : `epilote/lib/features/examens/widgets/exam_dossier_dialog.dart`
- Créer si > 500 lignes : `epilote/lib/features/examens/widgets/dossier_piece_tile.dart`

Chaque pièce `fichier` devient un **emplacement** : joindre / aperçu / remplacer /
supprimer / marquer vérifiée, avec badges (`n exemplaires`, `à légaliser`, source).
Pièces `physique`/`financiere` : case, étiquetée « fourniture » / « paiement ».
Bandeau de complétude et tuile Stages conservés. Si déposé → lecture seule + bouton
**Rouvrir** gardé par `canProvider(slug:'examens', action:'validate')`.

- [ ] Implémenter, `flutter analyze` à 0, commit.

---

### Tâche 5 — Fiche candidat + PDF

**Fichiers**
- Créer : `epilote/lib/features/examens/providers/candidate_file_provider.dart`
- Créer : `epilote/lib/features/examens/widgets/candidate_file_dialog.dart`
- Modifier : `epilote/lib/features/examens/services/exam_export_service.dart`
  (+ `buildCandidateFilePdf`)
- Modifier : `exam_candidate_views.dart` / `exam_candidate_grouped.dart`
  (ouvrir la fiche au clic sur un candidat)

Sections : identité, scolarité, candidature, dossier, stage lié, résultat, historique.
PDF via `OfficialPdfKit` (en-tête République du Congo) + `showPdfPreviewDialog`.

- [ ] Implémenter, commit.

---

### Tâche 6 — Stages : fiche complète + pièces

**Fichiers**
- Créer : `epilote/lib/features/stages/widgets/stage_file_dialog.dart`
- Modifier : `epilote/lib/features/stages/providers/stage_actions.dart`
  (pièces jointes du stage : convention signée, fiche d'évaluation)
- Modifier : `epilote/lib/features/stages/widgets/stages_grouped.dart` (ouverture au clic)

Réutilise `attachDossierPiece` généralisé ou son équivalent stage, et les PDF déjà
livrés (attestation, convention, liste) accessibles depuis la fiche.

- [ ] Implémenter, commit.

---

### Tâche 7 — Vérification finale

- [ ] `flutter analyze` → 0 issue
- [ ] `flutter test` → tous verts (dont les nouveaux)
- [ ] `flutter build linux --release` → OK
- [ ] Reconstruire le `.deb`
- [ ] Commit final + rapport honnête (ce qui est vérifié GUI, ce qui ne l'est pas)
