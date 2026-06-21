-- 0006_rls_sensitive_by_capability.sql
-- ─────────────────────────────────────────────────────────────────────────────
-- BUT : durcir la RLS des tables SENSIBLES (defense-in-depth). Aujourd'hui elles
--       sont « tenant-only » : tout membre d'une école peut lire/écrire la paie,
--       les dépenses, la discipline, le médical via l'API directe — la protection
--       par capacité ne tient QUE par les sync-rules PowerSync. On aligne la RLS
--       sur les mêmes drapeaux de capacité (migration 0005) pour une défense en
--       profondeur : même un token personnel ne peut atteindre la donnée hors de
--       sa capacité.
--
-- Modèle (inchangé pour la gouvernance) :
--   • super_admin            → tout
--   • admin_groupe           → tout son groupe (gestion/rapports online) — INCHANGÉ
--   • personnel scolaire     → son école ET seulement si son PROFIL accorde la
--                              capacité (sync_finance / sync_discipline / sync_medical)
--
-- staff_members : RH/finance pure (job_title, base_salary_xaf, iban, contrat).
--   AUCUN lien profil (pas de colonne profile_id) → gating capacité finance, comme
--   payroll. NB : le périmètre own_classes ne s'appuie donc PAS sur staff_members
--   (le code Dart myStaffIdProvider qui interroge profile_id est un bug latent à
--   corriger lors de la construction de l'espace enseignant — own_classes non
--   utilisé en prod aujourd'hui).
--
-- ⚠️ Impact réel quasi nul aujourd'hui : le personnel passe par PowerSync (pas
--    l'API directe) et les modules sensibles de l'espace école ne sont pas encore
--    construits. On pose les bonnes fondations AVANT de les bâtir.
-- Réversible (voir ROLLBACK en bas).
-- ─────────────────────────────────────────────────────────────────────────────

-- 1) Helpers de capacité (lus depuis profiles par auth.uid()) ─────────────────
CREATE OR REPLACE FUNCTION public.auth_sync_finance()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT COALESCE((SELECT sync_finance FROM profiles WHERE id = auth.uid()), false);
$$;

CREATE OR REPLACE FUNCTION public.auth_sync_discipline()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT COALESCE((SELECT sync_discipline FROM profiles WHERE id = auth.uid()), false);
$$;

CREATE OR REPLACE FUNCTION public.auth_sync_medical()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT COALESCE((SELECT sync_medical FROM profiles WHERE id = auth.uid()), false);
$$;

-- 2) FINANCE/RH — payroll, expenses, budget_lines : capacité finance ──────────
DROP POLICY IF EXISTS payroll_tenant ON public.payroll;
CREATE POLICY payroll_tenant ON public.payroll FOR ALL
  USING (is_super_admin() OR (group_id = auth_group_id() AND (is_admin_groupe()
          OR (school_id = auth_school_id() AND auth_sync_finance()))))
  WITH CHECK (is_super_admin() OR (group_id = auth_group_id() AND (is_admin_groupe()
          OR (school_id = auth_school_id() AND auth_sync_finance()))));

DROP POLICY IF EXISTS expenses_tenant ON public.expenses;
CREATE POLICY expenses_tenant ON public.expenses FOR ALL
  USING (is_super_admin() OR (group_id = auth_group_id() AND (is_admin_groupe()
          OR (school_id = auth_school_id() AND auth_sync_finance()))))
  WITH CHECK (is_super_admin() OR (group_id = auth_group_id() AND (is_admin_groupe()
          OR (school_id = auth_school_id() AND auth_sync_finance()))));

DROP POLICY IF EXISTS budget_lines_tenant ON public.budget_lines;
CREATE POLICY budget_lines_tenant ON public.budget_lines FOR ALL
  USING (is_super_admin() OR (group_id = auth_group_id() AND (is_admin_groupe()
          OR (school_id = auth_school_id() AND auth_sync_finance()))))
  WITH CHECK (is_super_admin() OR (group_id = auth_group_id() AND (is_admin_groupe()
          OR (school_id = auth_school_id() AND auth_sync_finance()))));

-- 3) staff_members — capacité finance (RH/salaire/IBAN, aucun lien profil) ─────
DROP POLICY IF EXISTS staff_members_tenant ON public.staff_members;
CREATE POLICY staff_members_tenant ON public.staff_members FOR ALL
  USING (is_super_admin() OR (group_id = auth_group_id() AND (is_admin_groupe()
          OR (school_id = auth_school_id() AND auth_sync_finance()))))
  WITH CHECK (is_super_admin() OR (group_id = auth_group_id() AND (is_admin_groupe()
          OR (school_id = auth_school_id() AND auth_sync_finance()))));

-- 4) DISCIPLINE — discipline_incidents : capacité discipline ──────────────────
DROP POLICY IF EXISTS discipline_incidents_tenant ON public.discipline_incidents;
CREATE POLICY discipline_incidents_tenant ON public.discipline_incidents FOR ALL
  USING (is_super_admin() OR (group_id = auth_group_id() AND (is_admin_groupe()
          OR (school_id = auth_school_id() AND auth_sync_discipline()))))
  WITH CHECK (is_super_admin() OR (group_id = auth_group_id() AND (is_admin_groupe()
          OR (school_id = auth_school_id() AND auth_sync_discipline()))));

-- 5) MÉDICAL — infirmary_visits : capacité médical ────────────────────────────
DROP POLICY IF EXISTS infirmary_visits_tenant ON public.infirmary_visits;
CREATE POLICY infirmary_visits_tenant ON public.infirmary_visits FOR ALL
  USING (is_super_admin() OR (group_id = auth_group_id() AND (is_admin_groupe()
          OR (school_id = auth_school_id() AND auth_sync_medical()))))
  WITH CHECK (is_super_admin() OR (group_id = auth_group_id() AND (is_admin_groupe()
          OR (school_id = auth_school_id() AND auth_sync_medical()))));

-- ─────────────────────────────────────────────────────────────────────────────
-- ROLLBACK (restaure les policies tenant-only d'origine) :
--   Pour chaque table T parmi (payroll,expenses,budget_lines,staff_members,
--   discipline_incidents,infirmary_visits) :
--     DROP POLICY IF EXISTS T_tenant ON public.T;
--     CREATE POLICY T_tenant ON public.T FOR ALL
--       USING (is_super_admin() OR (group_id = auth_group_id()
--               AND (is_admin_groupe() OR (school_id = auth_school_id()))))
--       WITH CHECK (is_super_admin() OR (group_id = auth_group_id()
--               AND (is_admin_groupe() OR (school_id = auth_school_id()))));
--   DROP FUNCTION IF EXISTS public.auth_sync_finance();
--   DROP FUNCTION IF EXISTS public.auth_sync_discipline();
--   DROP FUNCTION IF EXISTS public.auth_sync_medical();
-- ─────────────────────────────────────────────────────────────────────────────
