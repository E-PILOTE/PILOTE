-- ════════════════════════════════════════════════════════════════════════════
--  0151 — LE SYSTÈME ÉDUCATIF CONGOLAIS : TYPES D'ÉTABLISSEMENT ET PASSERELLES
--
--  ── LA DISTINCTION QUI MANQUAIT ───────────────────────────────────────────
--  « CET » désigne un ÉTABLISSEMENT — un collège d'enseignement technique,
--  établissement d'enseignement secondaire du PREMIER CYCLE. « CAP », « BET »,
--  « BEP » désignent des DIPLÔMES. Confondre les deux est la faute la plus
--  coûteuse qu'on puisse commettre sur ce référentiel, parce qu'elle rend
--  impossible toute question sensée : « combien d'élèves en CET ? » n'a pas de
--  réponse si CET est rangé comme un diplôme.
--
--  Or la plateforme n'avait AUCUN type d'établissement. `schools.school_type`
--  vaut `public` / `prive` — c'est le statut juridique, pas le type. Rien ne
--  permettait de dire d'une école qu'elle est un CET, un lycée technique ou un
--  collège d'enseignement général.
--
--  ── CE QUE CETTE MIGRATION NE FAIT PAS, ET POURQUOI ───────────────────────
--  ⚠️ ELLE NE CRÉE PAS DE TABLE `diplomas`. `national_exams` en est déjà une,
--  complète et juste : CEPE, BEPC, BET, BEP, BTF, CAP, CQP, BAC_G, BAC, BTS,
--  CFEEN, DCAF, DEMA, DECS. Elle porte `tutelle` (mepsa / metp), `cycle_code`
--  et `kind` (diplome / concours). Le BET y figure déjà au cycle `college`
--  sous tutelle `metp` — exactement le modèle attendu.
--  Une seconde table de diplômes divergerait de la première : c'est déjà
--  arrivé au barème des mentions, à quatre exemplaires, avec « Passable » pour
--  8/20 dans l'une d'elles.
--
--  ⚠️ ELLE NE CRÉE PAS DE TABLE `education_sectors`. Au Congo le secteur SE LIT
--  sur la tutelle : MEPSA = enseignement général, METP = technique et
--  professionnel. `tutelle_enum` existe déjà et porte cette information sur les
--  écoles et sur les examens. Un troisième vocabulaire pour la même idée
--  n'ajouterait que des occasions de désaccord.
--
--  ⚠️ ELLE N'INVENTE AUCUNE FILIÈRE. La nomenclature officielle est fixée par
--  ARRÊTÉ du ministre chargé de l'enseignement technique et professionnel. Les
--  sources publiques donnent son ORDRE DE GRANDEUR — 27 séries technologiques
--  au baccalauréat, 18 options de brevets techniques et professionnels, 9
--  séries professionnelles, 21 options spécialisées — mais les intitulés exacts
--  n'ont pas pu être récupérés (PDF du ministère en 404, fiche France Éducation
--  International en 403 au 2026-08-30). Les filières existantes sont donc
--  CONSERVÉES telles quelles et marquées `a_verifier` : le référentiel dira
--  lui-même ce qu'il n'a pas encore vérifié, plutôt que de présenter une
--  invention comme une nomenclature d'État.
--
--  ── SOURCES ───────────────────────────────────────────────────────────────
--   • Ministère de l'Enseignement technique et professionnel (METP)
--     https://www.enseignement-technique.gouv.cg/
--   • Décret n° 2017-149 du 10 mai 2017 fixant les conditions d'accès,
--     l'organisation et le fonctionnement des lycées techniques
--     (Journal officiel de la République du Congo N° 20-2017)
--   • Décret relatif aux collèges d'enseignement technique : « les collèges
--     d'enseignement technique sont des établissements d'enseignement
--     secondaire du premier cycle » ; l'ouverture d'un CET fait l'objet d'un
--     arrêté du ministre chargé de l'enseignement technique et professionnel.
--   • Conseil des ministres du 20 janvier 2026 (projet de réforme)
--     https://gouvernement.cg/compte-rendu-du-conseil-des-ministres-du-20-janvier-2026/
--   • France Éducation International — Congo
--     https://www.france-education-international.fr/enic-naric-bdd/127
--
--  ⚠️ ORDRE DE DÉPLOIEMENT : AVANT LE BUILD. Purement additive — aucune
--  colonne retirée, aucune valeur modifiée, aucun verbe durci. Un poste resté
--  sur un build antérieur ignore simplement ces tables.
-- ════════════════════════════════════════════════════════════════════════════

-- ── Le statut réglementaire d'une information ───────────────────────────────
--  Obligatoire, et pas décoratif : une réforme du système éducatif a été
--  examinée en Conseil des ministres le 20 janvier 2026. Présenter une
--  disposition de projet comme applicable ferait prendre à une école une
--  décision que la loi n'autorise pas encore.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'statut_reglementaire') THEN
    CREATE TYPE public.statut_reglementaire AS ENUM (
      'en_vigueur',      -- texte promulgué et applicable
      'projet_reforme',  -- adopté en conseil des ministres, non promulgué
      'historique',      -- abrogé, conservé pour lire les archives
      'a_verifier'       -- saisi sans source officielle confirmée
    );
  END IF;
END $$;

-- ── Les types d'établissement ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.institution_types (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code         text NOT NULL UNIQUE,
  name         text NOT NULL,
  short_name   text,
  tutelle      public.tutelle_enum,
  cycle_code   text,
  description  text,
  statut       public.statut_reglementaire NOT NULL DEFAULT 'en_vigueur',
  source       text,
  order_index  smallint NOT NULL DEFAULT 100,
  is_active    boolean  NOT NULL DEFAULT true,
  created_at   timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.institution_types IS
  'Type d''ETABLISSEMENT (CET, lycee technique, college general...). A ne jamais confondre avec un diplome : les diplomes vivent dans national_exams.';

INSERT INTO public.institution_types
  (code, name, short_name, tutelle, cycle_code, description, statut, source, order_index)
VALUES
  ('ECOLE_MATERNELLE', 'École préscolaire (maternelle)', 'Maternelle',
   'mepsa', 'prescolaire', 'Enseignement préscolaire.', 'en_vigueur', NULL, 10),

  ('ECOLE_PRIMAIRE', 'École primaire', 'École',
   'mepsa', 'primaire', 'Enseignement primaire, sanctionné par le CEPE.',
   'en_vigueur', NULL, 20),

  ('COLLEGE_GENERAL', 'Collège d''enseignement général', 'CEG',
   'mepsa', 'college',
   'Premier cycle du secondaire général, sanctionné par le BEPC.',
   'en_vigueur', NULL, 30),

  ('LYCEE_GENERAL', 'Lycée d''enseignement général', 'Lycée',
   'mepsa', 'lycee',
   'Second cycle du secondaire général, séries A/C/D, sanctionné par le baccalauréat général.',
   'en_vigueur', NULL, 40),

  ('CET', 'Collège d''enseignement technique', 'CET',
   'metp', 'college',
   'Établissement d''enseignement secondaire du PREMIER CYCLE. Organisé par filières, fixées par arrêté du ministre chargé de l''enseignement technique et professionnel. Mène au BET, et aux qualifications professionnelles (CAP).',
   'en_vigueur',
   'Décret relatif aux établissements de l''enseignement technique ; METP.',
   50),

  ('LYCEE_TECHNIQUE', 'Lycée technique', 'Lycée technique',
   'metp', 'lycee',
   'Second cycle technique, séries technologiques (F, G, E...), sanctionné par le baccalauréat technique.',
   'en_vigueur',
   'Décret n° 2017-149 du 10 mai 2017 (JO N° 20-2017).',
   60),

  ('LYCEE_PROFESSIONNEL', 'Lycée professionnel', 'Lycée pro.',
   'metp', 'lycee',
   'Second cycle professionnel, séries professionnelles, sanctionné par le baccalauréat professionnel.',
   'en_vigueur', NULL, 70),

  ('CENTRE_METIERS', 'Centre de métiers / centre de formation', 'Centre',
   'metp', 'formation_pro',
   'Structure de formation qualifiante : CAP, CQP, BEP et autres qualifications.',
   'en_vigueur', NULL, 80)
ON CONFLICT (code) DO NOTHING;

ALTER TABLE public.institution_types ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS institution_types_select ON public.institution_types;
CREATE POLICY institution_types_select ON public.institution_types
  FOR SELECT USING (auth.uid() IS NOT NULL);

-- ── Rattacher une école à son type ──────────────────────────────────────────
--  ⚠️ Nullable, et volontairement NON rempli. Deviner le type d'un
--  établissement d'après son nom (« CEG de Moungali » → collège général)
--  marcherait pour la plupart et se tromperait pour quelques-uns — et une
--  école mal typée remonterait ses effectifs dans la mauvaise colonne d'un état
--  ministériel. C'est à l'admin groupe de le déclarer.
ALTER TABLE public.schools
  ADD COLUMN IF NOT EXISTS institution_type_id uuid
    REFERENCES public.institution_types(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_schools_institution_type
  ON public.schools (institution_type_id);

COMMENT ON COLUMN public.schools.institution_type_id IS
  'Type d''etablissement (CET, lycee technique, CEG...). Distinct de school_type, qui est le statut juridique public/prive.';

-- ── Ce qu'une filière prépare, et dans quel type d'établissement ────────────
ALTER TABLE public.education_programs
  ADD COLUMN IF NOT EXISTS institution_type_id uuid
    REFERENCES public.institution_types(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS diploma_code text,
  ADD COLUMN IF NOT EXISTS duree_annees smallint,
  ADD COLUMN IF NOT EXISTS statut public.statut_reglementaire NOT NULL DEFAULT 'a_verifier',
  ADD COLUMN IF NOT EXISTS source text;

COMMENT ON COLUMN public.education_programs.statut IS
  'Par defaut a_verifier : la nomenclature officielle des filieres est fixee par arrete ministeriel et n''a pas encore ete confrontee ligne a ligne.';
COMMENT ON COLUMN public.education_programs.diploma_code IS
  'Code du diplome prepare, dans national_exams.code. Pas de cle etrangere : une filiere peut preparer un diplome que le referentiel des examens ne porte pas encore.';

-- Les séries du lycée général préparent le baccalauréat général ; celles du
-- lycée technique, le baccalauréat technique. C'est la seule affectation que
-- les sources publiques permettent d'établir sans deviner.
UPDATE public.education_programs p
   SET institution_type_id = (SELECT id FROM public.institution_types WHERE code = 'LYCEE_GENERAL'),
       diploma_code = 'BAC_G',
       statut = 'en_vigueur'
 WHERE p.code IN ('serie_a', 'serie_c', 'serie_d')
   AND p.institution_type_id IS NULL;

UPDATE public.education_programs p
   SET institution_type_id = (SELECT id FROM public.institution_types WHERE code = 'LYCEE_TECHNIQUE'),
       diploma_code = 'BAC',
       statut = 'en_vigueur'
 -- ⚠️ Parenthèses obligatoires : `AND` lie plus fort que `OR`, et sans elles
 -- la branche `serie_f%` échapperait au garde `IS NULL`.
 WHERE (p.code LIKE 'serie_f%'
        OR p.code IN ('serie_e', 'serie_g1', 'serie_g2', 'serie_g3'))
   AND p.institution_type_id IS NULL;

-- Le collège technique est un CET. C'est le point de départ de tout ce travail.
UPDATE public.education_programs p
   SET institution_type_id = (SELECT id FROM public.institution_types WHERE code = 'CET'),
       diploma_code = 'BET',
       statut = 'en_vigueur',
       source = 'Decret relatif aux etablissements de l''enseignement technique.'
 WHERE p.code = 'college_technique';

UPDATE public.education_programs p
   SET institution_type_id = (SELECT id FROM public.institution_types WHERE code = 'COLLEGE_GENERAL'),
       diploma_code = 'BEPC',
       statut = 'en_vigueur'
 WHERE p.code = 'college_general';

-- ── Le statut et la source d'un diplôme ─────────────────────────────────────
ALTER TABLE public.national_exams
  ADD COLUMN IF NOT EXISTS statut public.statut_reglementaire NOT NULL DEFAULT 'en_vigueur',
  ADD COLUMN IF NOT EXISTS source text;

UPDATE public.national_exams
   SET source = 'https://www.enseignement-technique.gouv.cg/'
 WHERE tutelle = 'metp' AND source IS NULL;

-- ── Les passerelles ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.education_pathways (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  depuis_diplome text NOT NULL,
  vers_diplome   text,
  vers_cycle     text,
  vers_type_etab text,
  libelle        text NOT NULL,
  obligatoire    boolean NOT NULL DEFAULT false,
  statut         public.statut_reglementaire NOT NULL DEFAULT 'a_verifier',
  source         text,
  note           text,
  order_index    smallint NOT NULL DEFAULT 100,
  created_at     timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.education_pathways IS
  'Poursuites d''etudes possibles apres un diplome. Chaque ligne porte son statut : ne JAMAIS presenter une passerelle projet_reforme comme applicable.';

INSERT INTO public.education_pathways
  (depuis_diplome, vers_diplome, vers_cycle, vers_type_etab, libelle, obligatoire, statut, source, note, order_index)
VALUES
  ('CEPE', 'BEPC', 'college', 'COLLEGE_GENERAL',
   'Entrée en 6ème — premier cycle du secondaire général', false,
   'en_vigueur', NULL, NULL, 10),

  ('CEPE', 'BET', 'college', 'CET',
   'Entrée en collège d''enseignement technique', false,
   'en_vigueur', NULL,
   'Le premier cycle technique s''entre apres le certificat d''etudes primaires.',
   20),

  ('BEPC', 'BAC_G', 'lycee', 'LYCEE_GENERAL',
   'Entrée en seconde générale', false, 'en_vigueur', NULL, NULL, 30),

  ('BET', 'BAC', 'lycee', 'LYCEE_TECHNIQUE',
   'Poursuite vers le baccalauréat technique', false,
   'projet_reforme',
   'https://gouvernement.cg/compte-rendu-du-conseil-des-ministres-du-20-janvier-2026/',
   '⚠️ Le projet de loi examine en Conseil des ministres le 20 janvier 2026 lierait la candidature au baccalaureat technique a l''obtention du BET. Tant que le texte n''est pas promulgue, cette exigence NE DOIT PAS etre opposee a un eleve.',
   40),

  ('CAP', NULL, NULL, NULL,
   'Insertion professionnelle', false, 'en_vigueur', NULL,
   'Le CAP est une qualification professionnelle : il ouvre l''emploi autant que la poursuite.',
   50),

  ('CAP', 'BEP', 'formation_pro', 'CENTRE_METIERS',
   'Poursuite en formation professionnelle', false, 'a_verifier', NULL,
   'Conditions de poursuite a confirmer sur la nomenclature officielle.',
   60)
ON CONFLICT DO NOTHING;

ALTER TABLE public.education_pathways ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS education_pathways_select ON public.education_pathways;
CREATE POLICY education_pathways_select ON public.education_pathways
  FOR SELECT USING (auth.uid() IS NOT NULL);
