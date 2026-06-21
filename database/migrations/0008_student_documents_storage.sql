-- 0008_student_documents_storage.sql
-- ─────────────────────────────────────────────────────────────────────────────
-- Bucket privé pour le DOSSIER DOCUMENTAIRE de l'élève (acte de naissance,
-- certificats, bulletins…). Privé → accès par URL signée. Chemin :
--   student-documents/{school_id}/{student_id}/{type}_{fichier}
-- RLS : le personnel de l'école (auth_school_id() = 1er segment) gère ses
-- dossiers ; super_admin voit tout. Le dossier suit l'ÉLÈVE (réinscription =
-- pièces déjà présentes, rien à re-téléverser).
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'student-documents', 'student-documents', false, 10485760,
  ARRAY['image/jpeg','image/png','image/webp','application/pdf']
)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "stud_docs_select" ON storage.objects;
DROP POLICY IF EXISTS "stud_docs_insert" ON storage.objects;
DROP POLICY IF EXISTS "stud_docs_update" ON storage.objects;
DROP POLICY IF EXISTS "stud_docs_delete" ON storage.objects;

CREATE POLICY "stud_docs_select" ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id = 'student-documents'
  AND (is_super_admin() OR (storage.foldername(name))[1] = auth_school_id()::text)
);

CREATE POLICY "stud_docs_insert" ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'student-documents'
  AND (is_super_admin() OR (storage.foldername(name))[1] = auth_school_id()::text)
);

CREATE POLICY "stud_docs_update" ON storage.objects FOR UPDATE TO authenticated
USING (
  bucket_id = 'student-documents'
  AND (is_super_admin() OR (storage.foldername(name))[1] = auth_school_id()::text)
);

CREATE POLICY "stud_docs_delete" ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'student-documents'
  AND (is_super_admin() OR (storage.foldername(name))[1] = auth_school_id()::text)
);
