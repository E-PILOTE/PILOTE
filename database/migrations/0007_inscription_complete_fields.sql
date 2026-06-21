-- 0007_inscription_complete_fields.sql
-- ─────────────────────────────────────────────────────────────────────────────
-- Complète le DOSSIER D'INSCRIPTION pour qu'il porte tous les champs nécessaires
-- (l'inscription est le point de saisie ; les autres modules consomment ces
-- données). Aligné sur la spec de référence `modulesElements/inscriptions_rows.sql`
-- MAIS en respectant le modèle normalisé (students + student_tutors +
-- class_enrollments), sans table `inscriptions` à plat.
--
-- NON DESTRUCTIF : uniquement des ADD COLUMN nullable (IF NOT EXISTS).
-- La FINANCE d'inscription (frais/paiement) est VOLONTAIREMENT différée à la
-- Phase 5 et sera branchée au sous-système dédié (fee_structures /
-- student_payments), pas dénormalisée ici.
-- ─────────────────────────────────────────────────────────────────────────────

-- Tuteur : adresse (spec parent_address / parent2_address)
ALTER TABLE public.student_tutors
  ADD COLUMN IF NOT EXISTS address text;

-- Inscription : motif de transfert, notes internes, attribution, filière (FP)
ALTER TABLE public.class_enrollments
  ADD COLUMN IF NOT EXISTS transfer_reason text;
ALTER TABLE public.class_enrollments
  ADD COLUMN IF NOT EXISTS notes text;
ALTER TABLE public.class_enrollments
  ADD COLUMN IF NOT EXISTS created_by uuid REFERENCES public.profiles(id);
ALTER TABLE public.class_enrollments
  ADD COLUMN IF NOT EXISTS filiere_id uuid REFERENCES public.education_programs(id);

-- Élève : région/département de résidence (spec region)
ALTER TABLE public.students
  ADD COLUMN IF NOT EXISTS region text;

-- Index sur les nouvelles FK (discipline « 0 FK non indexée » à l'échelle nationale)
CREATE INDEX IF NOT EXISTS idx_class_enrollments_created_by
  ON public.class_enrollments(created_by);
CREATE INDEX IF NOT EXISTS idx_class_enrollments_filiere_id
  ON public.class_enrollments(filiere_id);
