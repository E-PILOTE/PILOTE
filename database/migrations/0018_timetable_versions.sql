-- 0018_timetable_versions.sql
-- Version d'emploi du temps = porteuse du CYCLE DE VIE et de la PUBLICATION.
-- Sépare la construction (brouillon) de l'EDT officiel visible.
--   status : brouillon → en_cours → en_validation → valide → publie
--            → suspendu / archive (cf. dossier fonctionnel, §2.1).
-- MVP : une version ACTIVE (is_active) par (école, année). La structure
-- supporte d'emblée plusieurs scénarios/versions et le versionnage par
-- trimestre (trimester_id) — aucune refonte ultérieure nécessaire.

CREATE TABLE IF NOT EXISTS public.timetable_versions (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id         uuid NOT NULL REFERENCES public.school_groups(id)  ON DELETE CASCADE,
  school_id        uuid NOT NULL REFERENCES public.schools(id)        ON DELETE CASCADE,
  academic_year_id uuid NOT NULL REFERENCES public.academic_years(id) ON DELETE CASCADE,
  trimester_id     uuid REFERENCES public.trimesters(id)             ON DELETE SET NULL,
  label            varchar(60)  NOT NULL DEFAULT 'Emploi du temps',
  status           varchar(20)  NOT NULL DEFAULT 'brouillon',
  is_active        boolean      NOT NULL DEFAULT true,
  published_at     timestamptz,
  validated_by     uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_by       uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at       timestamptz  NOT NULL DEFAULT now(),
  updated_at       timestamptz  NOT NULL DEFAULT now()
);

ALTER TABLE public.timetable_versions ENABLE ROW LEVEL SECURITY;

CREATE POLICY timetable_versions_tenant ON public.timetable_versions
  FOR ALL
  USING (
    is_super_admin()
    OR (group_id = auth_group_id() AND (is_admin_groupe() OR school_id = auth_school_id()))
  )
  WITH CHECK (
    is_super_admin()
    OR (group_id = auth_group_id() AND (is_admin_groupe() OR school_id = auth_school_id()))
  );

CREATE INDEX IF NOT EXISTS idx_tt_versions_school ON public.timetable_versions(school_id);
CREATE INDEX IF NOT EXISTS idx_tt_versions_group  ON public.timetable_versions(group_id);
CREATE INDEX IF NOT EXISTS idx_tt_versions_year   ON public.timetable_versions(academic_year_id);

-- ── Rattachement des créneaux à une version + à une salle référencée ────────
ALTER TABLE public.timetable_slots
  ADD COLUMN IF NOT EXISTS version_id uuid REFERENCES public.timetable_versions(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS room_id    uuid REFERENCES public.rooms(id)              ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_timetable_slots_version ON public.timetable_slots(version_id);
CREATE INDEX IF NOT EXISTS idx_timetable_slots_room    ON public.timetable_slots(room_id);

-- ── Backfill NON DESTRUCTIF (idempotent) ────────────────────────────────────
-- Crée une version active par (école, année) ayant déjà des créneaux et rattache
-- les créneaux orphelins. Statut 'publie' : un EDT déjà en service reste visible.
INSERT INTO public.timetable_versions
  (group_id, school_id, academic_year_id, label, status, is_active, published_at)
SELECT DISTINCT t.group_id, t.school_id, t.academic_year_id,
       'Emploi du temps', 'publie', true, now()
FROM public.timetable_slots t
WHERE t.version_id IS NULL
  AND NOT EXISTS (
    SELECT 1 FROM public.timetable_versions v
    WHERE v.school_id = t.school_id
      AND v.academic_year_id = t.academic_year_id
  );

UPDATE public.timetable_slots t
SET version_id = v.id, updated_at = now()
FROM public.timetable_versions v
WHERE t.version_id IS NULL
  AND v.school_id = t.school_id
  AND v.academic_year_id = t.academic_year_id
  AND v.is_active = true;
