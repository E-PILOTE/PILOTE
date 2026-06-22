-- 0013_school_cycles_id.sql
-- ─────────────────────────────────────────────────────────────────────────────
-- `school_cycles` est une table de jonction (PK composite school_id+cycle_id)
-- SANS colonne `id`. PowerSync exige une colonne `id` unique par ligne pour
-- répliquer une table offline. On en ajoute une (uuid) afin de pouvoir
-- synchroniser les cycles RÉELS de chaque école sur les appareils du personnel
-- → la page Inscriptions affiche dynamiquement TOUS les cycles/niveaux
-- configurés pour l'école (même à 0 inscrit), pas seulement ceux où il y a déjà
-- des élèves. La PK composite et les inserts existants (sans `id`) restent
-- valides (DEFAULT gen_random_uuid).
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE public.school_cycles
  ADD COLUMN IF NOT EXISTS id uuid NOT NULL DEFAULT gen_random_uuid();

CREATE UNIQUE INDEX IF NOT EXISTS school_cycles_id_key
  ON public.school_cycles(id);
