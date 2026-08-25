-- ════════════════════════════════════════════════════════════════════════════
--  0079 — LE BAC TECHNIQUE ET LE BAC PROFESSIONNEL SONT DEUX DIPLÔMES
--
--  ── CE QUI ÉTAIT FAUX ──────────────────────────────────────────────────────
--  La migration 0065 avait FUSIONNÉ `BAC_T` et `BAC_P` en un `BAC_TP` unique,
--  au motif qu'il n'existerait qu'un « baccalauréat technique et professionnel ».
--  C'était une erreur de lecture : la presse emploie ce libellé pour désigner
--  LA SESSION commune de juin, où les deux jurys siègent ensemble. Le portail
--  de résultats de la Direction des examens et concours, lui, publie deux
--  palmarès distincts — « Baccalauréat technique » et « Baccalauréat
--  professionnel ».
--
--  Le code Dart ne s'y était d'ailleurs jamais rangé : `kExamsRequiringInternship`
--  vaut toujours `{BAC_T, BAC_P}`, et `kPrerequisites` porte une entrée `BAC_T`.
--  Depuis 0065, ces deux règles ne s'appliquaient donc à AUCUN examen réel —
--  l'attestation de stage n'était plus exigée nulle part.
--
--  ── ON RENOMME, ON NE RECRÉE PAS ───────────────────────────────────────────
--  `BAC_TP` DEVIENT `BAC_T`, en gardant son identifiant. Tout ce qui y est
--  accroché — six sessions depuis 2021-2022, les chiffres proclamés par la DEC,
--  les candidats, les neuf règles d'éligibilité des séries F et G — décrit le
--  baccalauréat TECHNIQUE et reste donc à sa place. Supprimer puis recréer
--  aurait détruit des résultats proclamés pour rien.
--
--  Le baccalauréat professionnel est créé À VIDE : aucune règle d'éligibilité.
--  C'est délibéré et c'est le précédent déjà tenu pour le BEP, le BTF, le CAP
--  et le CQP (migration 0044) — faute d'un mapping spécialité → diplôme sourcé,
--  on n'en invente pas. Le ministère attache ses règles depuis
--  `/admin/referentiel-examens`, où `exam_rule_match_count()` annonce combien de
--  classes sont concernées AVANT d'enregistrer.
--
--  ── LES DIPLÔMES QUI MANQUAIENT ────────────────────────────────────────────
--  Le référentiel ignorait cinq diplômes que la DEC publie pourtant : CFEEN,
--  DCAF, DEMA, DECS et BTS. Ils sont ajoutés, eux aussi sans règle.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ── 1. Le bac technique reprend son nom ────────────────────────────────────
UPDATE national_exams SET
  code        = 'BAC_T',
  name        = 'Baccalauréat technique',
  short_name  = 'Bac T',
  order_index = 10,
  updated_at  = now()
WHERE code = 'BAC_TP';

-- ── 2. Le bac professionnel existe de nouveau ──────────────────────────────
INSERT INTO national_exams (code, name, short_name, tutelle, cycle_code, kind,
                            order_index, is_active)
VALUES ('BAC_P', 'Baccalauréat professionnel', 'Bac P', 'metp', 'lycee',
        'diplome', 11, true)
ON CONFLICT (code) DO UPDATE SET
  name = EXCLUDED.name, short_name = EXCLUDED.short_name,
  cycle_code = EXCLUDED.cycle_code, is_active = true, updated_at = now();

-- ── 3. Les cinq diplômes absents du référentiel ────────────────────────────
--  `cycle_code` reste NULL là où le cycle n'est pas établi : une valeur inventée
--  ferait matcher des règles au hasard. Sans cycle et sans règle, un examen se
--  contente d'exister — ce qui est exactement le cas.
INSERT INTO national_exams (code, name, short_name, tutelle, cycle_code, kind,
                            order_index, is_active)
VALUES
  ('CFEEN', 'Certificat de Fin d''Études des Écoles Normales', 'CFEEN',
   'metp', NULL, 'diplome', 13, true),
  ('DCAF',  'Diplôme des Carrières Administratives et Financières', 'DCAF',
   'metp', NULL, 'diplome', 14, true),
  ('DEMA',  'Diplôme d''Études Moyennes Artistiques', 'DEMA',
   'metp', NULL, 'diplome', 15, true),
  ('DECS',  'Diplôme d''Études des Carrières de la Santé', 'DECS',
   'metp', NULL, 'diplome', 16, true),
  ('BTS',   'Brevet de Technicien Supérieur', 'BTS',
   'metp', NULL, 'diplome', 17, true)
ON CONFLICT (code) DO UPDATE SET
  name = EXCLUDED.name, short_name = EXCLUDED.short_name,
  tutelle = EXCLUDED.tutelle, is_active = true, updated_at = now();

-- ── 4. Rebrancher les classes ──────────────────────────────────────────────
--  ⚠️ OBLIGATOIRE après toute écriture touchant les examens ou leurs règles :
--  le trigger `trg_classes_derive_exam` ne s'arme qu'à l'écriture d'une CLASSE.
--  Sans cet appel, une règle neuve ne touche aucune classe existante et paraît
--  morte.
SELECT recompute_class_exams();

COMMIT;

-- ── Contrôle ────────────────────────────────────────────────────────────────
SELECT code, name, short_name, cycle_code, order_index,
       (SELECT count(*) FROM exam_eligibility_rules r WHERE r.exam_id = e.id)
         AS regles,
       (SELECT count(*) FROM classes c
         WHERE COALESCE(c.exam_override_id, c.exam_id) = e.id) AS classes
FROM national_exams e
WHERE tutelle = 'metp' ORDER BY order_index;

-- Aucun BAC_TP ne doit subsister.
SELECT count(*) AS bac_tp_restant FROM national_exams WHERE code = 'BAC_TP';
