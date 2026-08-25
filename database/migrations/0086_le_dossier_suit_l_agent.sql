-- ════════════════════════════════════════════════════════════════════════════
--  0086 — LE DOSSIER PERSONNEL SUIT L'AGENT
--
--  ── LA FUITE QUE 0083 A RENDUE VISIBLE ─────────────────────────────────────
--  `staff_diplomas` et `staff_career` portent un `school_id`, et leur RLS s'y
--  appuie :
--      group_id = auth_group_id() AND (is_admin_groupe() OR school_id = auth_school_id())
--
--  Or un diplôme n'appartient pas à une école : il appartient à une PERSONNE.
--  Après une mutation, ses lignes restaient pointées sur l'établissement quitté
--  — donc INVISIBLES depuis le nouveau. Et si la mutation change de groupe,
--  invisibles de tout le monde. L'agent arrivait sans diplômes, et l'école
--  d'accueil les ressaisissait : le doublon qu'on cherche précisément à éviter.
--
--  ── POURQUOI UN DÉCLENCHEUR, ET PAS UNE LIGNE DANS `muter_agent` ───────────
--  Parce que `muter_agent` n'est pas le seul chemin. Une correction manuelle,
--  un import, une reprise de données changent aussi `school_id`. Ce projet
--  garde la trace d'un piège dormant (`role = 'utilisateur'`) qui avait tué la
--  synchro du personnel pendant des semaines : une règle qu'on peut oublier
--  d'appeler finit par être oubliée. Le déclencheur, lui, ne s'oublie pas.
--
--  ⚠️ NE DÉPLACE QUE CE QUI EST ATTACHÉ À LA PERSONNE. Les présences, les
--  paies, les congés, les cours faits appartiennent à l'établissement où ils
--  ont eu lieu : ils ne bougent pas (migration 0085, même distinction).
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

CREATE OR REPLACE FUNCTION profiles_deplacer_dossier()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NEW.school_id IS NULL THEN RETURN NEW; END IF;

  -- Un diplôme appartient à celui qui l'a obtenu, où qu'il serve.
  UPDATE staff_diplomas
     SET school_id = NEW.school_id, group_id = NEW.group_id, updated_at = now()
   WHERE profile_id = NEW.id
     AND (school_id IS DISTINCT FROM NEW.school_id
          OR group_id IS DISTINCT FROM NEW.group_id);

  -- Le parcours déclaré par l'agent : c'est son curriculum, pas celui d'une
  -- école. `staff_affectations` (0083) dit ce que la plateforme a CONSTATÉ ;
  -- `staff_career` dit ce que l'agent a DÉCLARÉ. Les deux se complètent.
  UPDATE staff_career
     SET school_id = NEW.school_id, group_id = NEW.group_id, updated_at = now()
   WHERE profile_id = NEW.id
     AND (school_id IS DISTINCT FROM NEW.school_id
          OR group_id IS DISTINCT FROM NEW.group_id);

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_profiles_deplacer_dossier ON profiles;
CREATE TRIGGER trg_profiles_deplacer_dossier
  AFTER UPDATE OF school_id, group_id ON profiles
  FOR EACH ROW
  WHEN (OLD.school_id IS DISTINCT FROM NEW.school_id
        OR OLD.group_id IS DISTINCT FROM NEW.group_id)
  EXECUTE FUNCTION profiles_deplacer_dossier();

COMMENT ON FUNCTION profiles_deplacer_dossier() IS
  'Le dossier personnel (diplômes, parcours déclaré) suit l''agent quand il '
  'change d''établissement. Ce qui a eu lieu quelque part y reste.';

-- ── Rattrapage : les dossiers déjà décrochés ────────────────────────────────
-- Aucun mouvement n'a encore eu lieu, mais une donnée importée a pu diverger.
UPDATE staff_diplomas d
   SET school_id = p.school_id, group_id = p.group_id, updated_at = now()
  FROM profiles p
 WHERE p.id = d.profile_id AND p.school_id IS NOT NULL
   AND (d.school_id IS DISTINCT FROM p.school_id
        OR d.group_id IS DISTINCT FROM p.group_id);

UPDATE staff_career c
   SET school_id = p.school_id, group_id = p.group_id, updated_at = now()
  FROM profiles p
 WHERE p.id = c.profile_id AND p.school_id IS NOT NULL
   AND (c.school_id IS DISTINCT FROM p.school_id
        OR c.group_id IS DISTINCT FROM p.group_id);

COMMIT;
