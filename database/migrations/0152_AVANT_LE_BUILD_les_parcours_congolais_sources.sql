-- ════════════════════════════════════════════════════════════════════════════
--  0152 — LES PARCOURS CONGOLAIS, CORRIGÉS SUR SOURCE
--
--  La migration 0151 a posé la structure — types d'établissement, statuts,
--  passerelles — en s'appuyant sur ce que les sources publiques accessibles
--  disaient alors. La fiche « Congo — Système éducatif en bref » du Centre
--  ENIC-NARIC France (France Éducation International, juillet 2025) a pu être
--  lue depuis : elle donne les DURÉES et les CONDITIONS D'ENTRÉE, que rien
--  d'autre ne donnait. Elle corrige deux affirmations de 0151.
--
--  ── CE QUE 0151 DISAIT DE TRAVERS ─────────────────────────────────────────
--
--  1. « CEPE → entrée en collège d'enseignement technique ».
--     FAUX, ou du moins incomplet. Après le CEPE on entre dans un CENTRE DE
--     MÉTIERS (deux ans). Le CET s'intègre APRÈS ce centre — ou bien
--     directement pour qui a terminé la DEUXIÈME ANNÉE du secondaire inférieur
--     général, c'est-à-dire la CINQUIÈME.
--     Conséquence concrète : un élève sortant de CM2 ne s'inscrit pas en CET.
--     Une plateforme qui le proposerait ferait rejeter le dossier.
--
--  2. Le BET vers le baccalauréat technique était marqué `projet_reforme`.
--     FAUX. Les lycées d'enseignement technique sont « ouverts aux titulaires
--     d'un BET » — c'est le régime EN VIGUEUR. Ce que le projet de loi du
--     20 janvier 2026 changerait, c'est d'en faire une CONDITION NÉCESSAIRE de
--     candidature au baccalauréat technique. La passerelle est donc en vigueur,
--     et c'est son caractère OBLIGATOIRE qui relève du projet.
--     Nuance décisive : marquer toute la passerelle « projet » aurait empêché
--     d'orienter un élève vers une voie qui lui est ouverte aujourd'hui.
--
--  ── CE QUE 0151 IGNORAIT ──────────────────────────────────────────────────
--  Le BEPC ouvre AUSSI le lycée d'enseignement technique, pas seulement le
--  lycée général. Un élève du secondaire général peut donc basculer vers le
--  technique à la fin du premier cycle — c'est la passerelle la plus utile à
--  l'orientation, et elle manquait.
--
--  ── SOURCE ────────────────────────────────────────────────────────────────
--  Centre ENIC-NARIC France / France Éducation International,
--  « Congo — Système éducatif en bref », juillet 2025.
--  https://www.france-education-international.fr/system/files/medias/fichiers/2025/08/Congo.pdf
--
--  ⚠️ Cette fiche est une source de SYNTHÈSE, pas un texte congolais. Les
--  durées et conditions qu'elle donne sont marquées `en_vigueur` parce
--  qu'elles décrivent le régime appliqué, mais une règle juridique opposable à
--  une famille doit être confirmée sur le texte congolais lui-même. C'est à
--  cela que sert la colonne `source` : elle dit d'où vient ce qu'on affirme.
--
--  ⚠️ ORDRE : AVANT LE BUILD. Additive et corrective de données seulement.
-- ════════════════════════════════════════════════════════════════════════════

-- ── Combien de temps dure un cycle ──────────────────────────────────────────
ALTER TABLE public.institution_types
  ADD COLUMN IF NOT EXISTS duree_min_annees smallint,
  ADD COLUMN IF NOT EXISTS duree_max_annees smallint;

COMMENT ON COLUMN public.institution_types.duree_min_annees IS
  'Duree du cursus, en annees. Deux bornes parce que le CET dure DEUX A TROIS ans selon la filiere : une valeur unique serait fausse la moitie du temps.';

UPDATE public.institution_types SET
  duree_min_annees = 2, duree_max_annees = 2,
  description = 'Structure de formation ouverte après le CEPE. Cursus de deux ans qui ne confère généralement PAS de qualification finale : l''achèvement est souvent certifié par une simple attestation. Elle ouvre l''entrée en CET.',
  source = 'France Éducation International, « Congo — Système éducatif en bref », juillet 2025.'
 WHERE code = 'CENTRE_METIERS';

UPDATE public.institution_types SET
  duree_min_annees = 2, duree_max_annees = 3,
  description = 'Établissement d''enseignement secondaire du PREMIER CYCLE. S''intègre après un centre de métiers, ou pour qui a terminé la 5ème du secondaire général. Deux à trois ans, jusqu''au BET. Filières fixées par arrêté du ministre chargé de l''enseignement technique et professionnel.',
  source = 'Décret relatif aux établissements de l''enseignement technique ; France Éducation International, juillet 2025.'
 WHERE code = 'CET';

UPDATE public.institution_types SET
  duree_min_annees = 3, duree_max_annees = 3,
  description = 'Lycée d''enseignement technique (LET). Ouvert aux titulaires du BET ET à ceux qui ont achevé le premier cycle général avec le BEPC. Trois ans, délivre le baccalauréat technique.',
  source = 'Décret n° 2017-149 du 10 mai 2017 (JO N° 20-2017) ; France Éducation International, juillet 2025.'
 WHERE code = 'LYCEE_TECHNIQUE';

-- ── Le Brevet de Technicien manquait au référentiel des diplômes ───────────
INSERT INTO public.national_exams
  (code, name, short_name, tutelle, cycle_code, kind, order_index, is_active, statut, source)
SELECT 'BT', 'Brevet de Technicien', 'BT', 'metp'::public.tutelle_enum, 'lycee',
       'diplome'::public.exam_kind, 45::smallint, true, 'en_vigueur'::public.statut_reglementaire,
       'France Éducation International, « Congo — Système éducatif en bref », juillet 2025.'
WHERE NOT EXISTS (SELECT 1 FROM public.national_exams WHERE code = 'BT');

-- ── Les passerelles, réécrites sur la source ───────────────────────────────
--  On repart de zéro plutôt que de rapiécer : six lignes, dont deux fausses,
--  ne se corrigent pas par retouches sans laisser un doute sur les quatre
--  autres.
DELETE FROM public.education_pathways;

INSERT INTO public.education_pathways
  (depuis_diplome, vers_diplome, vers_cycle, vers_type_etab, libelle,
   obligatoire, statut, source, note, order_index)
VALUES
  ('CEPE', 'BEPC', 'college', 'COLLEGE_GENERAL',
   'Entrée en 6ème — premier cycle du secondaire général',
   false, 'en_vigueur', NULL, NULL, 10),

  ('CEPE', NULL, 'formation_pro', 'CENTRE_METIERS',
   'Entrée en centre de métiers (2 ans)',
   false, 'en_vigueur',
   'France Éducation International, juillet 2025.',
   'Ce cursus ne confère généralement pas de qualification finale : l''achèvement est souvent certifié par une attestation. Ne pas le présenter comme un diplôme.',
   20),

  ('CEPE', 'BET', 'college', 'CET',
   'Entrée en CET, APRÈS un centre de métiers',
   false, 'en_vigueur',
   'France Éducation International, juillet 2025.',
   '⚠️ Pas directement après le CEPE : le CET s''intègre après un centre de métiers, ou depuis la 5ème générale. Proposer l''entrée en CET à un sortant de CM2 ferait rejeter son dossier.',
   30),

  ('BEPC', 'BAC_G', 'lycee', 'LYCEE_GENERAL',
   'Entrée en seconde générale',
   false, 'en_vigueur', NULL, NULL, 40),

  ('BEPC', 'BAC', 'lycee', 'LYCEE_TECHNIQUE',
   'Entrée en lycée d''enseignement technique',
   false, 'en_vigueur',
   'France Éducation International, juillet 2025.',
   'Les LET sont ouverts au BET ET au BEPC. C''est la passerelle du général vers le technique à la fin du premier cycle — la plus utile à l''orientation.',
   50),

  ('BET', 'BAC', 'lycee', 'LYCEE_TECHNIQUE',
   'Poursuite vers le baccalauréat technique',
   false, 'en_vigueur',
   'France Éducation International, juillet 2025.',
   '⚠️ EN VIGUEUR : les LET sont ouverts aux titulaires d''un BET. Le projet de loi du 20 janvier 2026 en ferait une condition NÉCESSAIRE de candidature au baccalauréat technique — voir la ligne suivante. Tant qu''il n''est pas promulgué, ne rien opposer à un élève sur ce fondement.',
   60),

  ('BET', 'BAC', 'lycee', 'LYCEE_TECHNIQUE',
   'BET exigé pour candidater au baccalauréat technique',
   true, 'projet_reforme',
   'https://gouvernement.cg/compte-rendu-du-conseil-des-ministres-du-20-janvier-2026/',
   'Projet de loi adopté en Conseil des ministres le 20 janvier 2026, transmis au Parlement. NON PROMULGUÉ : ne jamais bloquer une candidature sur cette règle.',
   70),

  ('CAP', NULL, NULL, NULL,
   'Insertion professionnelle',
   false, 'en_vigueur', NULL,
   'Le CAP est une qualification professionnelle : il ouvre l''emploi autant que la poursuite.',
   80),

  ('BAC', 'BTS', NULL, NULL,
   'Poursuite vers le BTS ou le DUT (2 ans post-secondaire)',
   false, 'en_vigueur',
   'France Éducation International, juillet 2025.',
   NULL, 90);
