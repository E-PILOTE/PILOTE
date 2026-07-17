-- 0051 — Filières METP : corriger ce que j'ai inventé, tracer la provenance
--
-- ── L'AVEU ─────────────────────────────────────────────────────────────────
-- Les 21 filières de `formation_pro` du référentiel NATIONAL (group_id NULL)
-- n'ont été relevées nulle part : elles ont été composées « de bon sens ». La
-- presse nationale (couverture BET/BEP/BTF 2026) cite pourtant des spécialités
-- que la liste NE CONTIENT PAS : puériculture, préscolaire, économie sociale.
--
-- Le problème n'est pas seulement qu'elles soient incomplètes. Elles sont
-- NATIONALES, donc — RLS `education_programs_write` — un admin de groupe ne peut
-- ni les renommer ni les désactiver. On impose à tous les tenants une liste
-- inventée qu'ils ne peuvent pas corriger. C'est le pire des deux mondes.
--
-- ── CE QUI EST DÉJÀ BON, ET QU'ON NE TOUCHE PAS ────────────────────────────
-- La dynamique EXISTE :
--   • `school_education_programs` (9 activations réelles) -> chaque école choisit
--     dans le catalogue les filières qu'elle enseigne réellement ;
--   • `createProgram()` (admin_groupe ▸ Écoles ▸ Filières) -> un groupe crée ses
--     PROPRES filières, group_id = le sien, modifiables par lui.
-- Le catalogue national est donc une PROPOSITION de départ, pas une contrainte.
-- Cette migration se contente de rendre cette proposition honnête.
--
-- ── CE QUE FAIT CETTE MIGRATION ────────────────────────────────────────────
-- 1. ajoute les 3 spécialités ATTESTÉES par la presse et absentes ;
-- 2. renomme « Couture » -> « Techniques d'habillement » (terme officiel employé
--    par le METP dans la couverture du BET) ;
-- 3. TRACE la provenance de chaque ligne dans `description` — pour que le
--    ministère sache, ligne par ligne, ce qui est attesté et ce qui reste à
--    confirmer. Un référentiel dont on ignore la source est un référentiel qu'on
--    n'ose pas corriger.
--
-- ⚠️ Rien n'est supprimé : 0 classe n'utilise ces filières aujourd'hui, mais
-- supprimer un référentiel national pour le reconstruire « mieux » sur des
-- sources tout aussi faibles n'améliorerait rien. On marque, on complète, et le
-- METP tranchera — c'est LEUR référentiel, pas le nôtre.

BEGIN;

-- ── 1) Spécialités ATTESTÉES (presse nationale, session BET 2026) ──────────
INSERT INTO education_programs (cycle_id, code, name, description, order_index, group_id, is_active)
SELECT c.id, v.code, v.name, v.description, v.order_index, NULL, true
  FROM education_cycles c
  CROSS JOIN (VALUES
    ('fp_puericulture',    'Puériculture',
     'ATTESTÉ — spécialité BET citée par la presse nationale (session 2026).', 22),
    ('fp_prescolaire',     'Éducation préscolaire',
     'ATTESTÉ — spécialité BET citée par la presse nationale (session 2026).', 23),
    ('fp_economie_sociale','Économie sociale',
     'ATTESTÉ — spécialité BET citée par la presse nationale (session 2026).', 24)
  ) AS v(code, name, description, order_index)
 WHERE c.code = 'formation_pro'
   AND NOT EXISTS (
     SELECT 1 FROM education_programs p
      WHERE p.cycle_id = c.id AND p.code = v.code AND p.group_id IS NULL
   );

-- ── 2) Terme officiel ──────────────────────────────────────────────────────
UPDATE education_programs p
   SET name = 'Techniques d''habillement',
       description = 'ATTESTÉ — « technique d''habillement », terme employé par le '
                     'METP (couverture BET 2026). Anciennement « Couture ».',
       updated_at = now()
  FROM education_cycles c
 WHERE c.id = p.cycle_id AND c.code = 'formation_pro'
   AND p.code = 'fp_couture' AND p.group_id IS NULL;

-- ── 3) Provenance ligne par ligne ──────────────────────────────────────────
-- Attestées par la presse.
UPDATE education_programs p
   SET description = 'ATTESTÉ — spécialité citée par la presse nationale (BET 2026).',
       updated_at = now()
  FROM education_cycles c
 WHERE c.id = p.cycle_id AND c.code = 'formation_pro' AND p.group_id IS NULL
   AND p.code IN ('fp_hotellerie', 'fp_agriculture', 'fp_menuiserie')
   AND p.description IS DISTINCT FROM 'ATTESTÉ — spécialité citée par la presse nationale (BET 2026).';

-- Toutes les autres : métiers plausibles, JAMAIS relevés auprès du METP.
UPDATE education_programs p
   SET description = 'À CONFIRMER — métier plausible, non relevé auprès du METP. '
                     'Le ministère doit valider, renommer ou désactiver cette filière.',
       updated_at = now()
  FROM education_cycles c
 WHERE c.id = p.cycle_id AND c.code = 'formation_pro' AND p.group_id IS NULL
   AND p.description IS NULL;

COMMIT;

-- ── Vérifications ──────────────────────────────────────────────────────────
-- select p.code, p.name, left(p.description, 12) as provenance
--   from education_programs p join education_cycles c on c.id = p.cycle_id
--  where c.code = 'formation_pro' order by p.order_index;
-- select left(description, 12) as provenance, count(*)
--   from education_programs p join education_cycles c on c.id = p.cycle_id
--  where c.code = 'formation_pro' group by 1;
