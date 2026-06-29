-- 0023_rh_dossier.sql
-- DOSSIER RH DE L'AGENT — l'agent (personnel) EST la ligne `profiles` : tout le
-- RH (payroll, leave_requests, staff_attendance) clé déjà par `staff_id ->
-- profiles.id`. On enrichit donc `profiles` du volet carrière fonction publique
-- congolaise (statut, grade, échelon, catégorie, prise de service, spécialité)
-- et on ajoute deux journaux 1-N rattachés à l'agent :
--   • staff_career   : parcours professionnel (postes successifs)
--   • staff_diplomas : diplômes & qualifications
-- `staff_members` (overlay salaire/IBAN historique, 84 lignes anonymes) n'est PAS
-- la source d'identité et reste tel quel.

-- ── Statut de l'agent (axe employeur/financement, distinct du contract_type) ──
-- Congo : fonctionnaire (État/MEPSA-METP), contractuel (de l'État/établissement),
-- volontaire & bénévole (communautaires, payés par l'APE), prestataire/vacataire
-- (privé), stagiaire.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'employment_status') THEN
    CREATE TYPE public.employment_status AS ENUM (
      'fonctionnaire', 'contractuel', 'volontaire', 'prestataire',
      'stagiaire', 'benevole'
    );
  END IF;
END $$;

-- ── Volet carrière sur l'agent (profiles) ────────────────────────────────────
-- matricule = profiles.employee_number (déjà présent), photo = avatar_url (idem).
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS employment_status public.employment_status,
  ADD COLUMN IF NOT EXISTS grade            varchar(120),  -- corps/grade (ex. « Professeur des lycées »)
  ADD COLUMN IF NOT EXISTS echelon          varchar(40),   -- échelon (ex. « 5e échelon »)
  ADD COLUMN IF NOT EXISTS category         varchar(40),   -- catégorie (ex. « I », « A1 »)
  ADD COLUMN IF NOT EXISTS hire_date        date,          -- date de prise de service
  ADD COLUMN IF NOT EXISTS speciality       varchar(120);  -- spécialité / discipline

-- ── Parcours professionnel (1-N) ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.staff_career (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id     uuid NOT NULL REFERENCES public.school_groups(id) ON DELETE CASCADE,
  school_id    uuid NOT NULL REFERENCES public.schools(id)       ON DELETE CASCADE,
  profile_id   uuid NOT NULL REFERENCES public.profiles(id)      ON DELETE CASCADE,
  position     varchar(160) NOT NULL,           -- poste occupé
  organization varchar(200),                    -- établissement / structure
  start_date   date,
  end_date     date,                            -- NULL = poste actuel
  is_current   boolean NOT NULL DEFAULT false,
  notes        text,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now()
);

-- ── Diplômes & qualifications (1-N) ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.staff_diplomas (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id      uuid NOT NULL REFERENCES public.school_groups(id) ON DELETE CASCADE,
  school_id     uuid NOT NULL REFERENCES public.schools(id)       ON DELETE CASCADE,
  profile_id    uuid NOT NULL REFERENCES public.profiles(id)      ON DELETE CASCADE,
  title         varchar(200) NOT NULL,          -- intitulé du diplôme
  level         varchar(60),                    -- niveau (BAC, Licence, Master, CAPES, CAFOP…)
  field         varchar(160),                   -- filière / spécialité
  institution   varchar(200),                   -- établissement de délivrance
  year_obtained integer,
  file_url      text,                           -- scan (Storage), optionnel
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

-- ── RLS — sensible RH : aligné sur staff_members (capacité sync_finance) ──────
ALTER TABLE public.staff_career   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_diplomas ENABLE ROW LEVEL SECURITY;

CREATE POLICY staff_career_tenant ON public.staff_career
  FOR ALL
  USING (
    is_super_admin()
    OR (group_id = auth_group_id()
        AND (is_admin_groupe()
             OR (school_id = auth_school_id() AND auth_sync_finance())))
  )
  WITH CHECK (
    is_super_admin()
    OR (group_id = auth_group_id()
        AND (is_admin_groupe()
             OR (school_id = auth_school_id() AND auth_sync_finance())))
  );

CREATE POLICY staff_diplomas_tenant ON public.staff_diplomas
  FOR ALL
  USING (
    is_super_admin()
    OR (group_id = auth_group_id()
        AND (is_admin_groupe()
             OR (school_id = auth_school_id() AND auth_sync_finance())))
  )
  WITH CHECK (
    is_super_admin()
    OR (group_id = auth_group_id()
        AND (is_admin_groupe()
             OR (school_id = auth_school_id() AND auth_sync_finance())))
  );

CREATE INDEX IF NOT EXISTS idx_staff_career_profile   ON public.staff_career(profile_id);
CREATE INDEX IF NOT EXISTS idx_staff_career_school    ON public.staff_career(school_id);
CREATE INDEX IF NOT EXISTS idx_staff_diplomas_profile ON public.staff_diplomas(profile_id);
CREATE INDEX IF NOT EXISTS idx_staff_diplomas_school  ON public.staff_diplomas(school_id);
