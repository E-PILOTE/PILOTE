-- ════════════════════════════════════════════════════════════════════════════
--  0081 — LA RECHERCHE NATIONALE D'UN ÉLÈVE
--
--  La migration 0080 a donné à chaque élève un identifiant qui SAIT survivre au
--  changement d'école. Elle ne l'a pas rendu utile pour autant : l'école
--  d'accueil ne peut pas connaître l'INE d'un enfant qu'elle n'a jamais vu. Sa
--  base locale ne contient que ses propres élèves — et c'est très bien ainsi.
--
--  Il faut donc un guichet EN LIGNE, et un seul : cette fonction.
--
--  ── CE QU'ELLE OUVRE, ET CE QU'ELLE NE FERME PAS ───────────────────────────
--  Décision du ministère (2026-08-03) : TOUTE école peut interroger, sur
--  identité exacte. C'est le seul périmètre qui couvre le cas réel — un enfant
--  qui passe du public au privé, ou d'un réseau à un autre. Restreindre au
--  groupe aurait laissé la continuité cassée là où elle casse le plus souvent.
--
--  En contrepartie, quatre garde-fous :
--
--   1. LES TROIS CHAMPS SONT EXIGÉS — nom, prénom, date de naissance, tous
--      exacts. On ne peut pas parcourir le registre : il faut déjà savoir qui
--      l'on cherche. C'est la différence entre confirmer une identité et
--      moissonner un fichier d'enfants.
--
--   2. LA PROJECTION EST MINIMALE. De quoi reconnaître l'enfant et voir d'où
--      il vient : identifiant, état civil, établissement, département,
--      dernière classe connue. RIEN d'autre. Ni adresse, ni tuteurs, ni
--      santé, ni paiements, ni notes — une école d'accueil n'a aucun titre à
--      les voir avant que l'enfant soit chez elle.
--
--   3. CHAQUE INTERROGATION EST JOURNALISÉE. Une école qui consulte le
--      registre national pose un acte ; il laisse une trace, avec qui, quand
--      et sur quel nom. C'est ce qui rend l'ouverture défendable.
--
--   4. `SET search_path` FIGÉ. Une fonction SECURITY DEFINER sans search_path
--      figé s'exécute avec les droits du propriétaire sur des objets que
--      l'appelant peut redéfinir. Ce projet a déjà refermé cette faille une
--      fois (migrations 0070/0071) ; on ne la rouvre pas.
--
--  ── POURQUOI `unaccent` ────────────────────────────────────────────────────
--  Les patronymes congolais sont accentués — Kimbembé, Ngoué, Békolo. Une
--  secrétaire tape « Kimbembe ». Sans repli d'accents, la recherche échouerait
--  exactement là où elle doit servir, et l'école créerait un doublon en
--  croyant l'enfant inconnu.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

CREATE EXTENSION IF NOT EXISTS unaccent;

-- Comparaison des noms : sans accents, sans casse, sans espaces superflus.
-- IMMUTABLE pour pouvoir être indexée ; `unaccent()` ne l'est pas par défaut,
-- d'où l'appel explicite au dictionnaire, qui l'est.
CREATE OR REPLACE FUNCTION nom_normalise(p_nom text)
RETURNS text
LANGUAGE sql IMMUTABLE STRICT
SET search_path = public, extensions AS $$
  SELECT lower(trim(unaccent('unaccent', p_nom)))
$$;

-- La recherche portera sur ces expressions : sans index, chaque interrogation
-- balaierait la table nationale entière.
CREATE INDEX IF NOT EXISTS idx_students_recherche_nationale
  ON students (nom_normalise(last_name), nom_normalise(first_name), date_of_birth);

CREATE OR REPLACE FUNCTION rechercher_eleve_national(
  p_last_name     text,
  p_first_name    text,
  p_date_of_birth date
)
RETURNS TABLE (
  ine               text,
  first_name        text,
  last_name         text,
  date_of_birth     date,
  gender            text,
  school_name       text,
  school_department text,
  derniere_annee    text,
  derniere_classe   text,
  statut            text,
  meme_ecole        boolean
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, extensions AS $$
DECLARE
  v_uid    uuid := auth.uid();
  v_role   user_role;
  v_school uuid;
  v_group  uuid;
  v_n      int;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentification requise.';
  END IF;

  SELECT p.role, p.school_id, p.group_id
    INTO v_role, v_school, v_group
    FROM profiles p WHERE p.id = v_uid;

  IF v_role IS NULL THEN
    RAISE EXCEPTION 'Profil introuvable.';
  END IF;

  -- Garde-fou n° 1 : on confirme une identité, on n'explore pas un fichier.
  -- Deux caractères au minimum sur chaque nom, et la date obligatoire : sans
  -- elle, « Ngoma » ramènerait des milliers d'enfants.
  IF coalesce(length(trim(p_last_name)), 0) < 2
     OR coalesce(length(trim(p_first_name)), 0) < 2
     OR p_date_of_birth IS NULL THEN
    RAISE EXCEPTION
      'Nom, prénom et date de naissance sont tous les trois requis.';
  END IF;

  RETURN QUERY
  SELECT s.ine,
         s.first_name::text,
         s.last_name::text,
         s.date_of_birth,
         s.gender::text,
         sc.name::text,
         sc.department::text,
         ay.label::text,
         c.name::text,
         ce.status::text,
         (s.school_id = v_school)
  FROM   students s
  JOIN   schools sc ON sc.id = s.school_id
  -- Dernière inscription connue, quel que soit son statut : un élève sorti
  -- est justement celui qu'on cherche ici.
  LEFT JOIN LATERAL (
    SELECT e.* FROM class_enrollments e
    WHERE  e.student_id = s.id
    ORDER  BY e.enrollment_date DESC NULLS LAST, e.created_at DESC
    LIMIT  1
  ) ce ON true
  LEFT JOIN classes c        ON c.id  = ce.class_id
  LEFT JOIN academic_years ay ON ay.id = ce.academic_year_id
  WHERE  s.ine IS NOT NULL
    AND  nom_normalise(s.last_name)  = nom_normalise(p_last_name)
    AND  nom_normalise(s.first_name) = nom_normalise(p_first_name)
    AND  s.date_of_birth = p_date_of_birth
  ORDER  BY (s.school_id = v_school) DESC, sc.name
  -- Plafond assumé : au-delà de cinq homonymes exacts, même date de naissance
  -- comprise, ce n'est plus une recherche d'identité.
  LIMIT  5;

  GET DIAGNOSTICS v_n = ROW_COUNT;

  -- Garde-fou n° 3 : la trace. On journalise la QUESTION posée, pas les
  -- enfants trouvés — le journal ne doit pas devenir lui-même un fichier.
  INSERT INTO audit_logs (
    group_id, school_id, user_id, user_role, action, table_name, new_values
  ) VALUES (
    v_group, v_school, v_uid, v_role,
    -- ⚠️ `audit_logs.action` est un varchar(20) : le libellé doit tenir.
    -- « RECHERCHE_NATIONALE » fait 19 caractères, et suit la casse des
    -- actions déjà journalisées (INSERT/UPDATE/DELETE).
    'RECHERCHE_NATIONALE', 'students',
    jsonb_build_object(
      'nom',        trim(p_last_name),
      'prenom',     trim(p_first_name),
      'naissance',  p_date_of_birth,
      'resultats',  v_n
    )
  );
END $$;

REVOKE ALL ON FUNCTION rechercher_eleve_national(text, text, date) FROM public;
GRANT EXECUTE ON FUNCTION rechercher_eleve_national(text, text, date) TO authenticated;

COMMENT ON FUNCTION rechercher_eleve_national(text, text, date) IS
  'Guichet national d''identification d''un élève. Exige les trois éléments '
  'd''identité, rend une projection minimale, journalise chaque appel. '
  'Ouvert à toute école — décision du ministère du 2026-08-03.';

COMMIT;
