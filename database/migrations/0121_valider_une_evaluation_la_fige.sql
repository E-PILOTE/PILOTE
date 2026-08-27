-- ════════════════════════════════════════════════════════════════════════════
--  0121 — VALIDER UNE ÉVALUATION DOIT AVOIR UNE CONSÉQUENCE
--
--  0118 a réservé la PUBLICATION DES BULLETINS au droit `validate`. Mais la
--  règle métier §8.3 s'intitule « Validation NOTES : le directeur valide avant
--  publication » — et la chaîne des ÉVALUATIONS, elle, était restée gardée de
--  bout en bout par `update` :
--
--      brouillon --update--> soumise --update--> VALIDÉE --update--> PUBLIÉE
--
--  L'enseignant détient `update` sur `notes`. Il soumettait donc son travail,
--  le validait lui-même, puis le publiait : toute la cérémonie tenait dans une
--  seule main. Et une fois « validée », l'évaluation restait modifiable et
--  renotable — le chef d'établissement arrêtait les notes, l'enseignant les
--  changeait ensuite. Le mot « validée » ne voulait rien dire.
--
--  ── LA RÈGLE ───────────────────────────────────────────────────────────────
--  Brouillon ou soumise → elle appartient à l'enseignant   (`notes.update`).
--  Validée ou publiée   → elle appartient à la direction   (`notes.validate`),
--  et cela vaut aussi pour ses NOTES (`grades`) et pour le retour en arrière,
--  qui défait précisément l'acte du chef d'établissement.
--
--  ── PRÉCAUTIONS ────────────────────────────────────────────────────────────
--  • Un refus 42501 est FATAL pour le connecteur PowerSync : il jette le LOT
--    ENTIER en attente. L'application a donc été fermée AVANT la base, dans le
--    même commit (`notes_list.dart`, `notes_screen.dart`) : aucun geste offert
--    par l'écran ne peut être refusé ici.
--  • Le verrou d'APRÈS-validation passe par le `USING` et non par le
--    `WITH CHECK` : la ligne devient invisible à l'écriture, donc l'UPDATE
--    touche 0 ligne AU LIEU de lever 42501. C'est le mode d'échec sûr pour
--    PowerSync — rien n'est jeté.
--  • `is_admin_groupe()` conserve son passe-droit, comme partout ailleurs.
--  • Un seul écran écrit `evaluations` et `grades` (module `notes`) — vérifié
--    par relevé des appels : pas de second module à admettre, contrairement aux
--    bulletins que le conseil de classe écrit aussi (leçon 0116).
--
--  ── ÉTAT MESURÉ LE 2026-08-27 ──────────────────────────────────────────────
--  11 712 évaluations, TOUTES `published`, portant 431 250 notes. Aucune n'est
--  brouillon, soumise ni validée : cette migration verrouille donc un existant
--  déjà entièrement figé, et n'ouvre aucun chantier de reprise.
--
--  ── VÉRIFIÉ APRÈS COUP (production, transaction annulée) ───────────────────
--      ENS  noter une évaluation BROUILLON      : OUI
--      ENS  SOUMETTRE                           : OUI
--      ENS  VALIDER                             : refus 42501
--      ENS  PUBLIER                             : refus 42501
--      ENS  changer une note APRÈS validation   : bloqué (0 ligne)
--      ENS  DÉVALIDER (retour brouillon)        : bloqué (0 ligne)
--      DIR  VALIDER                             : OUI
--      DIR  PUBLIER                             : OUI
--      DIR  corriger une note après publication : OUI
-- ════════════════════════════════════════════════════════════════════════════

-- ─── evaluations : écrire, et surtout franchir les étapes ────────────────────
DROP POLICY IF EXISTS evals_update ON evaluations;
CREATE POLICY evals_update ON evaluations
  FOR UPDATE
  USING (
    group_id = (SELECT auth_group_id())
    AND (
      (SELECT is_admin_groupe())
      OR (
        school_id = (SELECT auth_school_id())
        AND (SELECT auth_module_permet(ARRAY['notes'], 'update'))
        -- Figée ⇒ il faut `validate` ne serait-ce que pour la TOUCHER.
        AND (
          status IN ('draft', 'submitted')
          OR (SELECT auth_module_permet(ARRAY['notes'], 'validate'))
        )
      )
    )
  )
  WITH CHECK (
    group_id = (SELECT auth_group_id())
    AND (
      (SELECT is_admin_groupe())
      OR (
        school_id = (SELECT auth_school_id())
        -- L'AMENER à « validée » ou « publiée » exige `validate`.
        AND (
          status NOT IN ('validated', 'published')
          OR (SELECT auth_module_permet(ARRAY['notes'], 'validate'))
        )
      )
    )
  );

DROP POLICY IF EXISTS evals_delete ON evaluations;
CREATE POLICY evals_delete ON evaluations
  FOR DELETE
  USING (
    group_id = (SELECT auth_group_id())
    AND (
      (SELECT is_admin_groupe())
      OR (
        school_id = (SELECT auth_school_id())
        AND (SELECT auth_module_permet(ARRAY['notes'], 'delete'))
        AND (
          status IN ('draft', 'submitted')
          OR (SELECT auth_module_permet(ARRAY['notes'], 'validate'))
        )
      )
    )
  );

-- ─── grades : une note suit le sort de son évaluation ────────────────────────
CREATE OR REPLACE FUNCTION public.evaluation_ouverte(p_evaluation_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
  SELECT EXISTS (
    SELECT 1 FROM evaluations e
    WHERE e.id = p_evaluation_id
      AND (
        e.status IN ('draft', 'submitted')
        OR public.auth_module_permet(ARRAY['notes'], 'validate')
      )
  );
$fn$;

GRANT EXECUTE ON FUNCTION public.evaluation_ouverte(uuid) TO authenticated;

COMMENT ON FUNCTION public.evaluation_ouverte(uuid) IS
  'Vraie si les notes de cette évaluation sont encore saisissables : elle est '
  'brouillon/soumise, ou l''appelant détient `validate` sur le module notes. '
  'Migration 0121 — « valider » doit fermer la saisie, sinon le mot ne veut '
  'rien dire.';

DROP POLICY IF EXISTS grades_insert ON grades;
CREATE POLICY grades_insert ON grades
  FOR INSERT
  WITH CHECK (
    group_id = (SELECT auth_group_id())
    AND (
      (SELECT is_admin_groupe())
      OR (
        school_id = (SELECT auth_school_id())
        AND (SELECT auth_module_permet(ARRAY['notes'], 'create'))
        AND public.evaluation_ouverte(evaluation_id)
      )
    )
  );

DROP POLICY IF EXISTS grades_update ON grades;
CREATE POLICY grades_update ON grades
  FOR UPDATE
  USING (
    group_id = (SELECT auth_group_id())
    AND (
      (SELECT is_admin_groupe())
      OR (
        school_id = (SELECT auth_school_id())
        AND (SELECT auth_module_permet(ARRAY['notes'], 'update'))
        AND public.evaluation_ouverte(evaluation_id)
      )
    )
  )
  WITH CHECK (
    group_id = (SELECT auth_group_id())
    AND (
      (SELECT is_admin_groupe())
      OR (
        school_id = (SELECT auth_school_id())
        AND public.evaluation_ouverte(evaluation_id)
      )
    )
  );

DROP POLICY IF EXISTS grades_delete ON grades;
CREATE POLICY grades_delete ON grades
  FOR DELETE
  USING (
    group_id = (SELECT auth_group_id())
    AND (
      (SELECT is_admin_groupe())
      OR (
        school_id = (SELECT auth_school_id())
        AND (SELECT auth_module_permet(ARRAY['notes'], 'delete'))
        AND public.evaluation_ouverte(evaluation_id)
      )
    )
  );
