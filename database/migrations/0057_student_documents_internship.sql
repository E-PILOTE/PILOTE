-- ════════════════════════════════════════════════════════════════════════════
-- 0057 — Rattacher une pièce à un STAGE.
--
-- Symétrique de la 0056 (`exam_candidate_id`). Les pièces d'un stage — la
-- convention SIGNÉE renvoyée par l'entreprise, la fiche d'évaluation du tuteur
-- — appartiennent à CE stage, pas à l'élève en général : un élève peut en
-- accomplir plusieurs (années successives, bac professionnel en alternance).
-- Sans ce rattachement, la convention du stage de l'an dernier passerait pour
-- celle de cette année, et le dossier de bac serait faux.
--
-- ON DELETE CASCADE : supprimer un stage retire ses pièces, et laisse intactes
-- les pièces de l'élève (exam_candidate_id et internship_id tous deux NULL).
--
-- `student_documents` est déjà synchronisée par `SELECT *` : aucun
-- redéploiement des sync-rules. Colonne à déclarer dans powersync_schema.dart.
--
-- Idempotente.
-- ════════════════════════════════════════════════════════════════════════════

ALTER TABLE student_documents
  ADD COLUMN IF NOT EXISTS internship_id uuid NULL
    REFERENCES internships(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_student_documents_internship
  ON student_documents (internship_id)
  WHERE internship_id IS NOT NULL;

COMMENT ON COLUMN student_documents.internship_id IS
  'NULL = pièce hors stage. Renseigné = pièce propre à CE stage (convention signée, fiche d''évaluation du tuteur).';
