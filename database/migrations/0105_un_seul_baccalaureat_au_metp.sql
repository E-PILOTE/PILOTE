-- ═══════════════════════════════════════════════════════════════════════════
-- 0105 — UN SEUL BACCALAURÉAT AU METP
--
--  ── CE QUI CHANGE ─────────────────────────────────────────────────────────
--  Le référentiel national portait DEUX baccalauréats sous la tutelle METP :
--  « Baccalauréat technique » (BAC_T) et « Baccalauréat professionnel »
--  (BAC_P). Le ministère a tranché le 13/08/2026 : il n'y en a qu'UN.
--
--      BAC_T  →  code BAC · « Baccalauréat » · abrégé « Bac »
--      BAC_P  →  SUPPRIMÉ
--
--  ── POURQUOI (et pourquoi ce n'est PAS la 0065 qui revient) ───────────────
--  La migration 0065 avait fusionné les deux bacs en un « BAC_TP » sur la foi
--  d'un titre de presse ; la 0079 l'avait défaite, à raison : la DEC publie
--  bien deux palmarès. Ce n'est pas de cela qu'il s'agit ici.
--
--  Ce qui distingue un « bac technique » d'un « bac professionnel », dans la
--  bouche du ministère, c'est la FILIÈRE du candidat — pas le diplôme. Or la
--  filière n'appartient pas au référentiel national : elle est saisie par
--  l'ÉCOLE, sur la classe et sur la candidature (`exam_candidates`,
--  `classes.filiere_*`). Le référentiel, lui, ne sert qu'à porter ce qui est
--  commun à tout le pays — et surtout ce à quoi s'accrochent les FRAIS et les
--  BARÈMES (`fee_structures.applies_to_exam_id`, mig. 0103).
--
--  Deux entrées obligeaient donc à saisir DEUX fois le même tarif d'État pour
--  le même diplôme, avec le risque permanent qu'ils divergent. C'est ce
--  doublon-là qu'on supprime — pas les palmarès de la DEC, qui restent
--  ventilables par filière côté école.
--
--  ── SÛRETÉ ────────────────────────────────────────────────────────────────
--  BAC_P n'était référencé NULLE PART (0 session, 0 candidat, 0 classe,
--  0 règle d'éligibilité, 0 tarif) — vérifié le 13/08/2026, et re-vérifié ici
--  par le bloc de garde : la migration AVORTE plutôt que de casser un lien.
--  BAC_T conserve tout : 6 sessions, 533 candidatures, 26 classes, 9 règles,
--  1 tarif. Le renommage ne touche qu'une ligne de libellé.
--
--  ⚠️ Ne touche PAS `exam_official_results.source_label`, qui CITE la
--  publication réelle de la DEC (« Jurys du bac technique et professionnel,
--  session de juin 2025 »). On ne réécrit pas une source.
--
--  ⚠️ MEPSA garde son « Baccalauréat général » (BAC_G) : autre tutelle, autre
--  diplôme. La fusion est interne au METP.
-- ═══════════════════════════════════════════════════════════════════════════

DO $$
DECLARE
  v_bac_p uuid;
  v_bac_t uuid;
  v_liens int;
BEGIN
  SELECT id INTO v_bac_t FROM public.national_exams WHERE code = 'BAC_T';
  SELECT id INTO v_bac_p FROM public.national_exams WHERE code = 'BAC_P';

  -- ── 1. Le baccalauréat professionnel disparaît, s'il est bien vide ───────
  IF v_bac_p IS NOT NULL THEN
    SELECT (SELECT count(*) FROM public.exam_sessions          WHERE exam_id = v_bac_p)
         + (SELECT count(*) FROM public.exam_eligibility_rules WHERE exam_id = v_bac_p)
         + (SELECT count(*) FROM public.classes                WHERE exam_id = v_bac_p)
         + (SELECT count(*) FROM public.classes                WHERE exam_override_id = v_bac_p)
         + (SELECT count(*) FROM public.fee_structures         WHERE applies_to_exam_id = v_bac_p)
      INTO v_liens;

    IF v_liens > 0 THEN
      RAISE EXCEPTION
        'BAC_P porte % rattachement(s) : la fusion est ANNULÉE. Reventiler ces lignes sur le baccalauréat unique avant de rejouer 0105.',
        v_liens;
    END IF;

    DELETE FROM public.national_exams WHERE id = v_bac_p;
    RAISE NOTICE 'BAC_P supprimé (aucun rattachement).';
  ELSE
    RAISE NOTICE 'BAC_P absent — déjà fusionné.';
  END IF;

  -- ── 2. Le baccalauréat technique DEVIENT le baccalauréat ────────────────
  IF v_bac_t IS NOT NULL THEN
    UPDATE public.national_exams
       SET code       = 'BAC',
           name       = 'Baccalauréat',
           short_name = 'Bac',
           updated_at = now()
     WHERE id = v_bac_t;
    RAISE NOTICE 'BAC_T renommé en BAC / Baccalauréat.';
  ELSE
    RAISE NOTICE 'BAC_T absent — déjà renommé.';
  END IF;
END $$;

-- ── 3. Le tarif de démonstration suit le libellé ───────────────────────────
UPDATE public.fee_structures f
   SET name = 'Frais d''examen — Baccalauréat'
  FROM public.national_exams e
 WHERE e.id = f.applies_to_exam_id
   AND e.code = 'BAC'
   AND f.name <> 'Frais d''examen — Baccalauréat';
