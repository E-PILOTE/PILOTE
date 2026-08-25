-- ════════════════════════════════════════════════════════════════════════════
--  0085 — QUAND UN AGENT PART, SA CHARGE NE PART PAS AVEC LUI
--
--  ── CE QUE 0083 A LAISSÉ OUVERT ────────────────────────────────────────────
--  Muter un agent déplace désormais son affectation. Mais sa CHARGE reste :
--  il demeure professeur principal d'une classe qu'il ne verra plus, titulaire
--  de cours qu'il n'assurera pas. L'école de départ ne peut alors rien
--  réattribuer — la place est occupée par quelqu'un qui n'est plus là.
--
--  ── LA DISTINCTION QUI DÉCIDE DE TOUT ──────────────────────────────────────
--  Certaines lignes disent CE QUI EST — une affectation de cours, un professeur
--  principal, des disponibilités. Elles deviennent FAUSSES au départ de l'agent,
--  et doivent être libérées.
--
--  D'autres disent CE QUI A ÉTÉ — un cours fait, une paie versée, un congé
--  accordé, une visite à l'infirmerie, une note saisie. Elles restent VRAIES
--  après le départ. On n'y touche pas : effacer la trace d'un acte parce que
--  son auteur est parti, c'est réécrire l'histoire de l'établissement.
--
--  ── CE QU'ON NE DÉCIDE PAS À LA PLACE DE L'ÉCOLE ───────────────────────────
--  L'EMPLOI DU TEMPS N'EST PAS TOUCHÉ. `timetable_slots.staff_id` est NOT NULL :
--  on ne peut pas le vider, et supprimer les créneaux détruirait la grille de
--  l'établissement. Qui remplace un enseignant est une décision de chef
--  d'établissement, pas un effet de bord d'un arrêté. Le nombre de créneaux
--  concernés est donc REMONTÉ À L'ÉCRAN pour que l'école les réattribue — un
--  silence ici se lirait comme « tout est réglé ».
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

CREATE OR REPLACE FUNCTION liberer_charge_agent(p_profile_id uuid, p_school_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_cours     int := 0;
  v_classes   int := 0;
  v_dispos    int := 0;
  v_creneaux  int := 0;
BEGIN
  IF p_school_id IS NULL THEN RETURN '{}'::jsonb; END IF;

  -- Affectations de cours : « il enseigne les maths en 3e A ». Faux dès qu'il
  -- est parti, et bloquant pour l'école qui veut nommer son remplaçant.
  DELETE FROM teacher_subjects
   WHERE staff_id = p_profile_id AND school_id = p_school_id;
  GET DIAGNOSTICS v_cours = ROW_COUNT;

  -- Professeur principal : une classe sans titulaire est un problème visible,
  -- une classe avec un titulaire absent est un problème invisible.
  UPDATE classes SET main_teacher_id = NULL, updated_at = now()
   WHERE main_teacher_id = p_profile_id AND school_id = p_school_id;
  GET DIAGNOSTICS v_classes = ROW_COUNT;

  -- Disponibilités déclarées dans cet établissement : sans objet ailleurs.
  DELETE FROM teacher_availability
   WHERE staff_id = p_profile_id AND school_id = p_school_id;
  GET DIAGNOSTICS v_dispos = ROW_COUNT;

  -- ⚠️ COMPTÉ, JAMAIS MODIFIÉ. Voir l'en-tête.
  SELECT count(*) INTO v_creneaux FROM timetable_slots
   WHERE staff_id = p_profile_id AND school_id = p_school_id;

  RETURN jsonb_build_object(
    'cours_liberes',           v_cours,
    'classes_liberees',        v_classes,
    'disponibilites_effacees', v_dispos,
    'creneaux_a_reattribuer',  v_creneaux
  );
END;
$$;

COMMENT ON FUNCTION liberer_charge_agent(uuid, uuid) IS
  'Libère ce qui dit CE QUI EST (cours, professeur principal, disponibilités) '
  'et laisse intact ce qui dit CE QUI A ÉTÉ. L''emploi du temps est compté, '
  'jamais modifié : le remplacement est une décision de l''établissement.';

REVOKE ALL ON FUNCTION liberer_charge_agent(uuid, uuid) FROM public;

-- ── Les trois mouvements rendent désormais un compte rendu ──────────────────
-- Le type de retour change : il faut supprimer avant de recréer.
DROP FUNCTION IF EXISTS muter_agent(uuid, uuid, date, user_role, text, date, text);
DROP FUNCTION IF EXISTS radier_agent(uuid, text, date, text, date, text);
DROP FUNCTION IF EXISTS reintegrer_agent(uuid, uuid, date, user_role, text, date, text);

CREATE FUNCTION muter_agent(
  p_profile_id     uuid,
  p_school_id      uuid,
  p_effective_date date,
  p_role           user_role DEFAULT NULL,
  p_acte_reference text      DEFAULT NULL,
  p_acte_date      date      DEFAULT NULL,
  p_notes          text      DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_agent    profiles%ROWTYPE;
  v_groupe   uuid;
  v_role     user_role;
  v_nouvelle uuid;
  v_charge   jsonb;
BEGIN
  SELECT * INTO v_agent FROM profiles WHERE id = p_profile_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Agent introuvable.'; END IF;

  IF NOT _agent_mouvement_autorise(p_profile_id, p_school_id) THEN
    RAISE EXCEPTION 'Mutation non autorisée sur cet agent.';
  END IF;

  SELECT group_id INTO v_groupe FROM schools WHERE id = p_school_id AND is_active;
  IF v_groupe IS NULL THEN RAISE EXCEPTION 'École de destination introuvable.'; END IF;

  IF v_agent.school_id = p_school_id THEN
    RAISE EXCEPTION 'L''agent est déjà affecté à cet établissement.';
  END IF;

  v_role := COALESCE(p_role, v_agent.role);

  -- Le poste quitté se ferme la veille de la prise de fonction : sans cela,
  -- l'agent compterait deux fois dans les effectifs du jour de bascule.
  UPDATE staff_affectations
     SET end_date        = GREATEST(start_date, p_effective_date - 1),
         departure_motif = 'mutation',
         updated_at      = now()
   WHERE profile_id = p_profile_id AND end_date IS NULL;

  v_charge := liberer_charge_agent(p_profile_id, v_agent.school_id);

  INSERT INTO staff_affectations
    (group_id, school_id, profile_id, role, start_date, arrival_motif,
     acte_reference, acte_date, notes, created_by)
  VALUES
    (v_groupe, p_school_id, p_profile_id, v_role, p_effective_date, 'mutation',
     p_acte_reference, p_acte_date, p_notes, auth.uid())
  RETURNING id INTO v_nouvelle;

  -- L'agent RESTE ACTIF : il sert ailleurs, on l'attend à son nouveau poste.
  UPDATE profiles
     SET school_id       = p_school_id,
         group_id        = v_groupe,
         role            = v_role,
         is_active       = true,
         departure_motif = NULL,
         departure_date  = NULL,
         updated_at      = now()
   WHERE id = p_profile_id;

  INSERT INTO audit_logs (group_id, school_id, user_id, user_role, action,
                          table_name, record_id, old_values, new_values)
  VALUES (v_groupe, p_school_id, auth.uid(),
          (SELECT role FROM profiles WHERE id = auth.uid()),
          'MUTATION_AGENT', 'staff_affectations', v_nouvelle,
          jsonb_build_object('school_id', v_agent.school_id, 'role', v_agent.role),
          jsonb_build_object('school_id', p_school_id, 'role', v_role,
                             'acte', p_acte_reference, 'date', p_effective_date)
          || v_charge);

  RETURN v_charge || jsonb_build_object('affectation_id', v_nouvelle);
END;
$$;

CREATE FUNCTION radier_agent(
  p_profile_id     uuid,
  p_motif          text,
  p_effective_date date,
  p_acte_reference text DEFAULT NULL,
  p_acte_date      date DEFAULT NULL,
  p_notes          text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_agent  profiles%ROWTYPE;
  v_charge jsonb;
BEGIN
  SELECT * INTO v_agent FROM profiles WHERE id = p_profile_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Agent introuvable.'; END IF;

  IF NOT _agent_mouvement_autorise(p_profile_id, NULL) THEN
    RAISE EXCEPTION 'Radiation non autorisée sur cet agent.';
  END IF;

  IF p_motif = 'mutation' THEN
    RAISE EXCEPTION 'Une mutation n''est pas un départ : utiliser muter_agent.';
  END IF;

  UPDATE staff_affectations
     SET end_date        = GREATEST(start_date, p_effective_date),
         departure_motif = p_motif,
         acte_reference  = COALESCE(p_acte_reference, acte_reference),
         acte_date       = COALESCE(p_acte_date, acte_date),
         notes           = COALESCE(p_notes, notes),
         updated_at      = now()
   WHERE profile_id = p_profile_id AND end_date IS NULL;

  v_charge := liberer_charge_agent(p_profile_id, v_agent.school_id);

  -- On NE SUPPRIME RIEN du dossier. Il reste consultable : c'est de lui que
  -- dépendent l'attestation de service, la pension, et la traçabilité des
  -- écritures faites par l'agent.
  UPDATE profiles
     SET is_active       = false,
         departure_motif = p_motif,
         departure_date  = p_effective_date,
         updated_at      = now()
   WHERE id = p_profile_id;

  INSERT INTO audit_logs (group_id, school_id, user_id, user_role, action,
                          table_name, record_id, old_values, new_values)
  VALUES (v_agent.group_id, v_agent.school_id, auth.uid(),
          (SELECT role FROM profiles WHERE id = auth.uid()),
          'DEPART_AGENT', 'profiles', p_profile_id,
          jsonb_build_object('is_active', v_agent.is_active),
          jsonb_build_object('motif', p_motif, 'date', p_effective_date,
                             'acte', p_acte_reference) || v_charge);

  RETURN v_charge;
END;
$$;

CREATE FUNCTION reintegrer_agent(
  p_profile_id     uuid,
  p_school_id      uuid,
  p_effective_date date,
  p_role           user_role DEFAULT NULL,
  p_acte_reference text      DEFAULT NULL,
  p_acte_date      date      DEFAULT NULL,
  p_notes          text      DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_agent    profiles%ROWTYPE;
  v_groupe   uuid;
  v_role     user_role;
  v_nouvelle uuid;
  v_charge   jsonb;
BEGIN
  SELECT * INTO v_agent FROM profiles WHERE id = p_profile_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Agent introuvable.'; END IF;

  IF NOT _agent_mouvement_autorise(p_profile_id, p_school_id) THEN
    RAISE EXCEPTION 'Réintégration non autorisée sur cet agent.';
  END IF;

  -- Une révocation et un décès ne se défont pas d'un clic.
  IF v_agent.departure_motif IN ('revocation', 'deces') THEN
    RAISE EXCEPTION 'Réintégration impossible après une % : corriger le dossier d''abord.',
      v_agent.departure_motif;
  END IF;

  SELECT group_id INTO v_groupe FROM schools WHERE id = p_school_id AND is_active;
  IF v_groupe IS NULL THEN RAISE EXCEPTION 'École d''accueil introuvable.'; END IF;

  v_role := COALESCE(p_role, v_agent.role);

  UPDATE staff_affectations
     SET end_date        = GREATEST(start_date, p_effective_date - 1),
         departure_motif = COALESCE(departure_motif, 'autre'),
         updated_at      = now()
   WHERE profile_id = p_profile_id AND end_date IS NULL;

  -- Si l'agent revient AILLEURS, sa charge dans l'école précédente n'a plus
  -- lieu d'être. S'il revient au même endroit, il n'y a rien à libérer.
  IF v_agent.school_id IS DISTINCT FROM p_school_id THEN
    v_charge := liberer_charge_agent(p_profile_id, v_agent.school_id);
  ELSE
    v_charge := '{}'::jsonb;
  END IF;

  INSERT INTO staff_affectations
    (group_id, school_id, profile_id, role, start_date, arrival_motif,
     acte_reference, acte_date, notes, created_by)
  VALUES
    (v_groupe, p_school_id, p_profile_id, v_role, p_effective_date,
     'reintegration', p_acte_reference, p_acte_date, p_notes, auth.uid())
  RETURNING id INTO v_nouvelle;

  UPDATE profiles
     SET school_id       = p_school_id,
         group_id        = v_groupe,
         role            = v_role,
         is_active       = true,
         departure_motif = NULL,
         departure_date  = NULL,
         updated_at      = now()
   WHERE id = p_profile_id;

  INSERT INTO audit_logs (group_id, school_id, user_id, user_role, action,
                          table_name, record_id, old_values, new_values)
  VALUES (v_groupe, p_school_id, auth.uid(),
          (SELECT role FROM profiles WHERE id = auth.uid()),
          'REINTEGRATION', 'staff_affectations', v_nouvelle,
          jsonb_build_object('motif_sortie', v_agent.departure_motif),
          jsonb_build_object('school_id', p_school_id, 'date', p_effective_date));

  RETURN v_charge || jsonb_build_object('affectation_id', v_nouvelle);
END;
$$;

GRANT EXECUTE ON FUNCTION muter_agent(uuid, uuid, date, user_role, text, date, text) TO authenticated;
GRANT EXECUTE ON FUNCTION radier_agent(uuid, text, date, text, date, text)           TO authenticated;
GRANT EXECUTE ON FUNCTION reintegrer_agent(uuid, uuid, date, user_role, text, date, text) TO authenticated;

COMMIT;
