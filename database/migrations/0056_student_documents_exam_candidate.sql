-- ════════════════════════════════════════════════════════════════════════════
-- 0056 — Rattacher une pièce du dossier d'examen à une CANDIDATURE.
--
-- Jusqu'ici une pièce du dossier d'examen n'était qu'une case cochée : rien ne
-- reliait « acte de naissance fourni » à un fichier réel. Les scans ont pourtant
-- déjà une maison — `student_documents` + le bucket privé `student-documents`.
--
-- Cette colonne porte la distinction que le modèle Dart appelle `PieceSource` :
--
--   • exam_candidate_id IS NULL  → pièce de l'ÉLÈVE (acte de naissance, diplôme).
--     Elle vaut pour toutes ses candidatures : à la réinscription, RIEN à
--     re-téléverser. C'est l'intention d'origine de la migration 0008.
--
--   • exam_candidate_id RENSEIGNÉ → pièce de CETTE candidature (certificat
--     médical de la session, reçu de frais). La recycler d'une session sur
--     l'autre serait une faute — la contrainte le rend impossible par erreur.
--
-- ON DELETE CASCADE : désinscrire un candidat retire ses pièces de candidature,
-- et LAISSE INTACTES ses pièces d'élève (elles ont exam_candidate_id NULL).
-- C'est exactement le comportement voulu — une désinscription ne doit pas
-- détruire l'acte de naissance de l'enfant.
--
-- `student_documents` est déjà synchronisée par `SELECT *` dans les sync-rules :
-- AUCUN redéploiement PowerSync n'est requis. Seule la déclaration de colonne
-- dans `powersync_schema.dart` doit suivre.
--
-- Idempotente.
-- ════════════════════════════════════════════════════════════════════════════

ALTER TABLE student_documents
  ADD COLUMN IF NOT EXISTS exam_candidate_id uuid NULL
    REFERENCES exam_candidates(id) ON DELETE CASCADE;

-- Index partiel : seules les pièces de candidature sont interrogées par
-- candidature. Les pièces d'élève (NULL, la majorité) restent hors de l'index.
CREATE INDEX IF NOT EXISTS idx_student_documents_exam_candidate
  ON student_documents (exam_candidate_id)
  WHERE exam_candidate_id IS NOT NULL;

COMMENT ON COLUMN student_documents.exam_candidate_id IS
  'NULL = pièce de l''élève, réutilisable à chaque candidature. Renseigné = pièce propre à cette candidature (certificat médical, reçu), jamais recyclée.';
