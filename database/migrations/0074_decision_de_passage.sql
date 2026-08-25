-- ════════════════════════════════════════════════════════════════════════════
--  0074 — LA DÉCISION DE FIN D'ANNÉE : PASSE, REDOUBLE, RÉORIENTÉ
--
--  ── CE QUI MANQUAIT ────────────────────────────────────────────────────────
--  La plateforme savait tout calculer — notes, moyennes, bulletins, palmarès —
--  et ne savait pas CONCLURE. Le conseil de classe ne décernait que des
--  distinctions (`bulletins.decision` : Félicitations … Blâme), qui sont des
--  appréciations trimestrielles. Le verdict annuel, celui qui décide de la
--  scolarité d'un enfant, n'existait nulle part. `is_repeating` ne le portait
--  pas non plus : c'est une case cochée À LA MAIN au moment de l'inscription,
--  une déclaration d'entrée, pas le résultat d'une délibération.
--
--  Pour les classes d'EXAMEN (CM2, 3e, Tle), la question ne se pose pas : la
--  DEC proclame. Pour les classes de PASSAGE — les trois quarts du réseau —
--  c'est l'établissement qui décide, et il le faisait hors de l'outil.
--
--  ── OÙ ÇA VIT, ET POURQUOI PAS AILLEURS ────────────────────────────────────
--  Sur `class_enrollments`, pas dans une table neuve. L'inscription EST l'élève
--  dans une classe pour une année : la décision de fin d'année la clôt. Deux
--  conséquences pratiques :
--    • le bucket PowerSync `class_enrollments` existe déjà et descend en
--      `SELECT *` — aucune sync-rule à redéployer, donc aucun risque sur la
--      synchro en production ;
--    • l'unicité (student_id, academic_year_id) garantit déjà UNE décision par
--      élève et par année. Rien à réinventer.
--
--  ── LA DESTINATION EST STOCKÉE AVEC LA DÉCISION ────────────────────────────
--  Le conseil délibère en juin ; le secrétariat réinscrit en septembre. Entre
--  les deux, la classe d'accueil doit rester celle qu'on a décidée, pas celle
--  qu'un algorithme recalculera trois mois plus tard sur une structure qui
--  aura changé. D'où `promotion_target_class_id`, écrit au moment du verdict.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

ALTER TABLE class_enrollments
  ADD COLUMN IF NOT EXISTS promotion_decision        text,
  ADD COLUMN IF NOT EXISTS promotion_average         numeric(5,2),
  ADD COLUMN IF NOT EXISTS promotion_target_class_id uuid,
  ADD COLUMN IF NOT EXISTS promotion_decided_at      timestamptz,
  ADD COLUMN IF NOT EXISTS promotion_decided_by      uuid;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint
                  WHERE conrelid = 'class_enrollments'::regclass
                    AND conname  = 'class_enrollments_promotion_decision_check') THEN
    ALTER TABLE class_enrollments
      ADD CONSTRAINT class_enrollments_promotion_decision_check
      CHECK (promotion_decision IS NULL
             OR promotion_decision IN ('passe', 'redouble', 'reoriente'));
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint
                  WHERE conrelid = 'class_enrollments'::regclass
                    AND conname  = 'class_enrollments_promotion_target_class_id_fkey') THEN
    ALTER TABLE class_enrollments
      ADD CONSTRAINT class_enrollments_promotion_target_class_id_fkey
      FOREIGN KEY (promotion_target_class_id) REFERENCES classes(id) ON DELETE SET NULL;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint
                  WHERE conrelid = 'class_enrollments'::regclass
                    AND conname  = 'class_enrollments_promotion_decided_by_fkey') THEN
    ALTER TABLE class_enrollments
      ADD CONSTRAINT class_enrollments_promotion_decided_by_fkey
      FOREIGN KEY (promotion_decided_by) REFERENCES profiles(id) ON DELETE SET NULL;
  END IF;
END $$;

COMMENT ON COLUMN class_enrollments.promotion_decision IS
  'Verdict annuel du conseil de classe : passe | redouble | reoriente. NULL '
  'tant que la classe n''a pas été délibérée. À ne pas confondre avec '
  'bulletins.decision, qui porte les distinctions trimestrielles.';
COMMENT ON COLUMN class_enrollments.promotion_average IS
  'Moyenne annuelle retenue par le conseil (/20). Figée au moment du vote : '
  'une note corrigée après coup ne doit pas réécrire une délibération.';
COMMENT ON COLUMN class_enrollments.promotion_target_class_id IS
  'Classe d''accueil décidée. Renseignée pour passe et reoriente ; pour '
  'redouble elle vaut la classe de l''année suivante au même niveau.';

-- La délibération se lit toujours « une classe, une année ». L'index partiel
-- ne porte que sur les lignes déjà décidées : c'est la minorité tant que la
-- campagne est en cours, et c'est ce qu'on relit ensuite.
CREATE INDEX IF NOT EXISTS idx_enrollments_promotion
  ON class_enrollments(school_id, academic_year_id, promotion_decision)
  WHERE promotion_decision IS NOT NULL;

-- Réinscrire = créer l'inscription de l'année suivante en la reliant à celle
-- qui vient d'être délibérée. `previous_class_id` porte déjà ce lien ; on
-- l'indexe pour que la remontée de parcours d'un élève reste immédiate.
CREATE INDEX IF NOT EXISTS idx_enrollments_student_year
  ON class_enrollments(student_id, academic_year_id);

COMMIT;
