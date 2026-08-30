-- ════════════════════════════════════════════════════════════════════════════
--  0155 — LE RÉFÉRENTIEL NATIONAL DES EXAMENS N'APPARTIENT PAS À TOUT LE MONDE
--
--  ── LA BRÈCHE, MESURÉE ────────────────────────────────────────────────────
--  Trois politiques d'écriture disaient `is_super_admin() OR is_admin_groupe()`
--  — SANS AUCUNE PORTÉE DE GROUPE :
--
--    • national_exams          (le référentiel des diplômes d'État)
--    • exam_sessions           (les sessions officielles)
--    • exam_eligibility_rules  (les règles d'éligibilité)
--
--  Sondé en base sous l'identité d'un admin_groupe d'un groupe PRIVÉ :
--
--    | ce qu'il a pu faire                          | lignes |
--    |----------------------------------------------|--------|
--    | modifier la règle d'éligibilité d'un AUTRE groupe |  1  |
--    | SUPPRIMER la règle d'un AUTRE groupe             |  1  |
--    | modifier le BAC national                         |  1  |
--    | modifier TOUTES les sessions d'examen d'un coup  | 35  |
--
--  Trente-cinq sessions officielles réécrites par une requête, depuis un compte
--  d'école privée. Rien dans la base ne s'y opposait.
--
--  ── CE QUE L'ÉTAT DES DONNÉES A PERMIS DE TRANCHER ────────────────────────
--  Aucun groupe n'a jamais écrit dans ce référentiel : les 17 règles sont
--  GLOBALES (`group_id IS NULL`), les 17 examens et 35 sessions sont
--  nationaux. L'ouverture était donc du risque pur, sans usage.
--
--  ── QUI DOIT POUVOIR ÉCRIRE ───────────────────────────────────────────────
--  Le ministère. Or au Congo le ministère EST un groupe de cette plateforme :
--  « MEPSA — Ministère Enseign. Primaire » et « Ministère de l'Enseignement
--  Technique et Professionnel » gèrent leurs propres écoles comme n'importe
--  quel groupe. Rien ne les distinguait d'un groupe privé — c'est précisément
--  ce manque qui laissait la porte ouverte.
--
--  On nomme donc le DROIT, pas encore l'architecture :
--  `school_groups.administre_referentiel_national`. Le nom dit ce qu'il permet
--  et rien de plus — une modélisation plus large du statut de ministère reste
--  ouverte, et ce drapeau s'y raccordera ou disparaîtra sans rien casser.
--
--  ── ⚠️ CE QUI CHANGE POUR UN GROUPE PRIVÉ, ET LE PIÈGE À NE PAS MANQUER ───
--  Ses PROPRES règles (`group_id` = son groupe) restent modifiables — ce
--  chemin-là était légitime et le reste. Le référentiel NATIONAL lui est fermé.
--
--  ⚠️ MAIS LA FERMETURE EST MUETTE POUR UPDATE ET DELETE. Un INSERT refusé par
--  un WITH CHECK lève bien 42501 ; un UPDATE ou un DELETE que le USING écarte
--  ne lève RIEN — zéro ligne, réponse 204. C'est exactement le défaut que la
--  migration 0154 vient de corriger ailleurs. Mesuré après application : les
--  trois tentatives du groupe privé rendent 0 ligne, sans une seule erreur.
--
--  La base est donc sûre, mais l'ÉCRAN mentirait. C'est pourquoi le côté
--  Flutter passe le référentiel en LECTURE SEULE pour un groupe qui ne
--  l'administre pas, plutôt que d'afficher des boutons qui ne font rien.
--
--  ── ⚠️ ORDRE : AVANT LE BUILD ─────────────────────────────────────────────
--  `administre_referentiel_national` est NOT NULL **avec défaut** : un INSERT
--  du build déployé, qui ignore la colonne, prend le défaut. Pas de 23502.
--  Et la colonne n'est PAS dans la liste blanche de 0154 — un admin_groupe qui
--  tenterait de se l'octroyer reçoit 42501.
-- ════════════════════════════════════════════════════════════════════════════

-- ── 1. Le droit, porté par le groupe ────────────────────────────────────────
ALTER TABLE public.school_groups
  ADD COLUMN IF NOT EXISTS administre_referentiel_national boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.school_groups.administre_referentiel_national IS
  'VRAI pour un groupe qui tient le referentiel national des examens de SA tutelle (les deux ministeres). Faux pour tout autre groupe. Reserve au super_admin : absent de la liste blanche de 0154.';

-- Les deux ministères, reconnus à ce qu'ils SONT — le seul groupe de leur
-- tutelle dont le nom porte « Ministère » ou le sigle de la tutelle. On ne
-- devine pas : le contrôle juste en dessous refuse la migration si le compte
-- n'est pas exactement de un par tutelle.
UPDATE public.school_groups
   SET administre_referentiel_national = true
 WHERE tutelle IS NOT NULL
   AND group_type = 'public'
   AND (name ILIKE '%ministère%' OR name ILIKE '%ministere%' OR name ILIKE 'MEPSA%');

-- ── 2. Le contrôle — AVANT de poser la moindre politique ───────────────────
--  Exactement UN groupe marqué par tutelle.
--  Si le rétro-marquage a manqué un ministère, ce ministère perdrait l'accès à
--  son propre référentiel — un dégât silencieux. On refuse plutôt d'appliquer.
DO $$
DECLARE n_mepsa int; n_metp int;
BEGIN
  SELECT count(*) INTO n_mepsa FROM public.school_groups
   WHERE administre_referentiel_national AND tutelle = 'mepsa';
  SELECT count(*) INTO n_metp FROM public.school_groups
   WHERE administre_referentiel_national AND tutelle = 'metp';
  IF n_mepsa <> 1 OR n_metp <> 1 THEN
    RAISE EXCEPTION
      'Marquage des ministeres incorrect : mepsa=%, metp=% (attendu 1 et 1). '
      'Corriger administre_referentiel_national AVANT de poser les politiques.',
      n_mepsa, n_metp;
  END IF;
END $$;

-- ── 3. Les deux fonctions d'aide ────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.auth_group_tutelle()
RETURNS public.tutelle_enum
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
  SELECT sg.tutelle FROM public.school_groups sg WHERE sg.id = public.auth_group_id()
$fn$;

COMMENT ON FUNCTION public.auth_group_tutelle() IS
  'Tutelle du groupe de l''utilisateur courant. NULL si le groupe ne la porte pas encore — et un NULL ne satisfait aucune comparaison, donc il FERME au lieu d''ouvrir.';

CREATE OR REPLACE FUNCTION public.auth_group_administre_referentiel()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
  SELECT coalesce(
    (SELECT sg.administre_referentiel_national
       FROM public.school_groups sg WHERE sg.id = public.auth_group_id()),
    false)
$fn$;

COMMENT ON FUNCTION public.auth_group_administre_referentiel() IS
  'VRAI si le groupe de l''utilisateur tient le referentiel national. `coalesce(..., false)` : l''absence de groupe FERME.';

-- ── 4. national_exams — le ministère de SA tutelle, et lui seul ─────────────
DROP POLICY IF EXISTS national_exams_write ON public.national_exams;
CREATE POLICY national_exams_write ON public.national_exams
  FOR ALL TO authenticated
  USING (
    (SELECT public.is_super_admin())
    OR ((SELECT public.is_admin_groupe())
        AND (SELECT public.auth_group_administre_referentiel())
        AND tutelle = (SELECT public.auth_group_tutelle()))
  )
  WITH CHECK (
    (SELECT public.is_super_admin())
    OR ((SELECT public.is_admin_groupe())
        AND (SELECT public.auth_group_administre_referentiel())
        AND tutelle = (SELECT public.auth_group_tutelle()))
  );

COMMENT ON POLICY national_exams_write ON public.national_exams IS
  'Le METP ne touche pas au BEPC, le MEPSA ne touche pas au BET. La tutelle de la LIGNE doit egaler celle du groupe.';

-- ── 5. exam_sessions — la tutelle se lit sur l'examen ───────────────────────
DROP POLICY IF EXISTS exam_sessions_write ON public.exam_sessions;
CREATE POLICY exam_sessions_write ON public.exam_sessions
  FOR ALL TO authenticated
  USING (
    (SELECT public.is_super_admin())
    OR ((SELECT public.is_admin_groupe())
        AND (SELECT public.auth_group_administre_referentiel())
        AND EXISTS (SELECT 1 FROM public.national_exams e
                     WHERE e.id = exam_sessions.exam_id
                       AND e.tutelle = (SELECT public.auth_group_tutelle())))
  )
  WITH CHECK (
    (SELECT public.is_super_admin())
    OR ((SELECT public.is_admin_groupe())
        AND (SELECT public.auth_group_administre_referentiel())
        AND EXISTS (SELECT 1 FROM public.national_exams e
                     WHERE e.id = exam_sessions.exam_id
                       AND e.tutelle = (SELECT public.auth_group_tutelle())))
  );

-- ── 6. exam_eligibility_rules — ses règles à soi, ou celles de sa tutelle ───
--  ⚠️ Une règle GLOBALE (`group_id IS NULL`) s'applique à toute la plateforme.
--  Seul un ministère peut y toucher, et seulement si elle concerne sa tutelle
--  ou tous (`tutelle IS NULL`, le joker). Un groupe ordinaire garde le droit
--  d'affiner SES propres règles — c'est l'usage prévu, et il ne sortait pas
--  de son périmètre.
DROP POLICY IF EXISTS exam_rules_write ON public.exam_eligibility_rules;
CREATE POLICY exam_rules_write ON public.exam_eligibility_rules
  FOR ALL TO authenticated
  USING (
    (SELECT public.is_super_admin())
    OR ((SELECT public.is_admin_groupe()) AND group_id = (SELECT public.auth_group_id()))
    OR ((SELECT public.is_admin_groupe())
        AND group_id IS NULL
        AND (SELECT public.auth_group_administre_referentiel())
        AND (tutelle IS NULL OR tutelle = (SELECT public.auth_group_tutelle())))
  )
  WITH CHECK (
    (SELECT public.is_super_admin())
    OR ((SELECT public.is_admin_groupe()) AND group_id = (SELECT public.auth_group_id()))
    OR ((SELECT public.is_admin_groupe())
        AND group_id IS NULL
        AND (SELECT public.auth_group_administre_referentiel())
        AND (tutelle IS NULL OR tutelle = (SELECT public.auth_group_tutelle())))
  );
