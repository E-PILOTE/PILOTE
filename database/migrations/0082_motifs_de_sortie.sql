-- ════════════════════════════════════════════════════════════════════════════
--  0082 — LA NOMENCLATURE DES MOTIFS DE SORTIE
--
--  ── LE PROBLÈME ────────────────────────────────────────────────────────────
--  `class_enrollments.withdrawal_reason` est du TEXTE LIBRE, et le dialogue de
--  sortie s'en contente : à défaut de saisie, il écrit « Transfert » ou
--  « Radiation ». Un ministère ne peut rien en faire.
--
--  Or c'est précisément le chiffre qu'un ministère de l'éducation publie :
--  combien d'enfants sortent, et pourquoi. « Abandon », « décès »,
--  « exclusion », « mariage ou grossesse », « raisons économiques » ne sont pas
--  des nuances de langage — ce sont des politiques publiques différentes.
--  Aujourd'hui, tout cela est indistinct, et un abandon ne se distingue même
--  pas d'un transfert non déclaré.
--
--  ── LA FORME : UNE COLONNE FERMÉE, À CÔTÉ DU TEXTE LIBRE ───────────────────
--  `withdrawal_motif` porte la catégorie ; `withdrawal_reason` reste ce qu'il
--  était, le commentaire de l'agent. On ne remplace pas l'un par l'autre :
--  la catégorie sert à compter, le texte à comprendre un cas particulier.
--
--  Une contrainte CHECK plutôt qu'un type énuméré : amender la liste devra être
--  possible sans reconstruire un type dont dépendraient des vues et des
--  fonctions. Le ministère AJUSTERA cette liste — c'est la sienne, pas la nôtre.
--
--  ⚠️ LISTE À FAIRE VALIDER. Elle s'appuie sur les catégories usuelles des
--  statistiques de déperdition scolaire ; aucune n'a été confirmée par le
--  MEPSA ni le METP à ce jour. La modifier = une migration qui touche cette
--  contrainte ET `core/utils/sortie_motif.dart`, tenus identiques.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

ALTER TABLE class_enrollments
  ADD COLUMN IF NOT EXISTS withdrawal_motif text;

ALTER TABLE class_enrollments
  DROP CONSTRAINT IF EXISTS class_enrollments_withdrawal_motif_check;

ALTER TABLE class_enrollments
  ADD CONSTRAINT class_enrollments_withdrawal_motif_check
  CHECK (withdrawal_motif IS NULL OR withdrawal_motif IN (
    -- Sorties DÉCLARÉES : l'enfant reste scolarisé, ailleurs.
    'transfert',            -- vers un autre établissement
    'demenagement',         -- départ de la localité
    -- Sorties de scolarisation : c'est la déperdition proprement dite.
    'abandon_economique',   -- frais, travail de l'enfant
    'abandon_familial',     -- mariage, grossesse, charge familiale
    'abandon_distance',     -- éloignement de l'établissement
    'maladie',
    'deces',
    -- Sortie prononcée par l'établissement.
    'exclusion',            -- décision disciplinaire
    -- Fin normale de parcours.
    'fin_de_scolarite',     -- diplômé, ou dernier niveau atteint
    -- Ce que l'école ne sait pas.
    'non_reinscrit',        -- ne s'est pas représenté à la rentrée
    'autre'
  ));

COMMENT ON COLUMN class_enrollments.withdrawal_motif IS
  'Catégorie normalisée de la sortie — c''est elle qui se compte. '
  'Le texte libre reste dans withdrawal_reason. '
  '⚠️ Tenue identique à core/utils/sortie_motif.dart. Liste à faire valider '
  'par le MEPSA et le METP.';

-- ── Reprise de l'existant ───────────────────────────────────────────────────
-- Les sorties déjà enregistrées portent un texte libre. On ne devine pas : on
-- ne reclasse que ce qui est certain — le statut `transferred` DIT que c'est un
-- transfert, indépendamment de ce que l'agent a écrit. Tout le reste devient
-- « autre », qui est la vérité : on ne sait pas.
UPDATE class_enrollments
   SET withdrawal_motif = CASE
         WHEN status = 'transferred' THEN 'transfert'
         WHEN status = 'graduated'   THEN 'fin_de_scolarite'
         ELSE 'autre'
       END
 WHERE withdrawal_motif IS NULL
   AND status IN ('transferred', 'graduated', 'withdrawn');

-- ── Ce que le ministère pourra enfin lire ───────────────────────────────────
CREATE OR REPLACE VIEW v_sorties_par_motif AS
SELECT ce.group_id,
       ce.school_id,
       ce.academic_year_id,
       ce.withdrawal_motif      AS motif,
       count(*)                 AS effectif,
       count(*) FILTER (WHERE s.gender = 'F') AS filles
FROM   class_enrollments ce
JOIN   students s ON s.id = ce.student_id
WHERE  ce.status IN ('transferred', 'withdrawn', 'graduated')
GROUP  BY 1, 2, 3, 4;

COMMENT ON VIEW v_sorties_par_motif IS
  'Sorties agrégées par motif, école et année — avec la part de filles, que '
  'les motifs « abandon_familial » et « abandon_economique » rendent '
  'lisible pour la première fois.';

COMMIT;
