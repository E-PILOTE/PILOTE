-- 0093_renseigner_le_statut_d_un_agent.sql
--
-- ════════════════════════════════════════════════════════════════════════════
--  RENSEIGNER UN STATUT VIDE — ce n'est pas le changer
-- ════════════════════════════════════════════════════════════════════════════
--
--  La 0092 fait remplir `employment_status` au moment de l'enregistrement d'un
--  agent. Mais les agents DÉJÀ EN PLACE — ceux repris de l'existant, arrivés
--  par `reprise_historique` — ont tous un statut nul : 342 profils sur 342.
--
--  Conséquence à l'écran, constatée le 2026-08-04 : chaque carte d'agent porte
--  « Statut à renseigner », l'axe « Répartir par ▸ Statut » ne montre qu'une
--  seule case, et le compteur « Fonctionnaires » affiche 0 — ce qui est FAUX.
--  La vérité n'est pas « aucun fonctionnaire », c'est « on ne sait pas ». Un
--  chiffre qui dit zéro là où il devrait dire « inconnu » est pire que pas de
--  chiffre du tout : le ministère le lirait comme un établissement sans aucun
--  titulaire.
--
--  ── LA RÈGLE, ET SA LIMITE ─────────────────────────────────────────────────
--  L'école peut RENSEIGNER un statut vide : elle a l'agent devant elle, elle
--  sait s'il est fonctionnaire ou payé par l'APE. C'est une constatation.
--
--  Elle ne peut pas le CHANGER une fois posé. Passer un volontaire en
--  fonctionnaire serait une titularisation, et une titularisation est un acte
--  de l'autorité de tutelle — pas une correction de fiche. D'où le garde-fou,
--  qui n'est pas dans l'interface mais ici : `WHERE employment_status IS NULL`.
--  Une erreur de saisie se corrige donc au niveau du groupe, comme les autres
--  actes de carrière.
--
--  ⚠️ `audit_logs.action` est un varchar(20). « STATUT_AGENT » en fait 12.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

CREATE OR REPLACE FUNCTION renseigner_statut_agent(
  p_profile_id        uuid,
  p_employment_status text
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_moi    profiles%ROWTYPE;
  v_agent  profiles%ROWTYPE;
BEGIN
  IF NOT est_chef_etablissement() THEN
    RAISE EXCEPTION 'Seule la direction de l''établissement peut renseigner le '
                    'statut d''un agent.';
  END IF;

  SELECT * INTO v_moi   FROM profiles WHERE id = auth.uid();
  SELECT * INTO v_agent FROM profiles WHERE id = p_profile_id;

  IF v_agent.id IS NULL THEN
    RAISE EXCEPTION 'Agent introuvable.';
  END IF;
  IF v_agent.school_id IS DISTINCT FROM v_moi.school_id THEN
    RAISE EXCEPTION 'Cet agent n''appartient pas à votre établissement.';
  END IF;

  IF p_employment_status IS NULL
     OR NOT (p_employment_status = ANY (
              ARRAY(SELECT unnest(enum_range(NULL::employment_status))::text)))
  THEN
    RAISE EXCEPTION 'Statut d''emploi inconnu.';
  END IF;

  -- Le cœur de la migration : on remplit un vide, on n'écrase rien.
  IF v_agent.employment_status IS NOT NULL THEN
    RAISE EXCEPTION 'Le statut de cet agent est déjà renseigné (%). En changer '
                    'relève de l''administration du réseau : requalifier un '
                    'agent n''est pas une correction de fiche.',
                    v_agent.employment_status;
  END IF;

  UPDATE profiles
     SET employment_status = p_employment_status::employment_status,
         updated_at        = now()
   WHERE id = p_profile_id
     AND employment_status IS NULL;   -- ceinture ET bretelles (concurrence)

  INSERT INTO audit_logs (group_id, school_id, user_id, user_role, action,
                          table_name, record_id, new_values)
  VALUES (v_moi.group_id, v_moi.school_id, auth.uid(), v_moi.role,
          'STATUT_AGENT', 'profiles', p_profile_id,
          jsonb_build_object('statut_emploi', p_employment_status));
END;
$$;

COMMENT ON FUNCTION renseigner_statut_agent(uuid, text) IS
  'Renseigne un statut d''emploi ABSENT. N''écrase jamais un statut posé : '
  'requalifier un agent est un acte de l''autorité de tutelle.';

REVOKE ALL ON FUNCTION renseigner_statut_agent(uuid, text) FROM public;
GRANT EXECUTE ON FUNCTION renseigner_statut_agent(uuid, text) TO authenticated;

COMMIT;
