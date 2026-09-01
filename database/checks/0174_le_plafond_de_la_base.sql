-- ════════════════════════════════════════════════════════════════════════════
--  LE PLAFOND DE LA BASE — à rejouer avant toute vague de déploiement.
--
--  Lecture seule.
--    psql "$DATABASE_URL" -f database/checks/0174_le_plafond_de_la_base.sql
--
--  ── POURQUOI CETTE SONDE EXISTE ──────────────────────────────────────────
--  Découvert le 2026-09-01, en répondant à « peut-on déployer sur mille
--  écoles ? » : la base pesait 465 Mo pour 37 écoles de DÉMONSTRATION, soit
--  93 % du plafond de 500 Mo du plan Supabase `free`.
--
--  ⚠️ Au-delà de ce plafond, Supabase bascule le projet en LECTURE SEULE.
--  Pas de dégradation progressive, pas d'avertissement dans l'application :
--  les écritures échouent. Sur un produit hors-ligne d'abord, ça ne se voit
--  même pas tout de suite — les postes continuent d'accepter le travail en
--  local, et c'est la REMONTÉE qui casse, silencieusement, école par école.
--
--  Personne ne surveillait ce chiffre. C'est le rôle de ce fichier.
-- ════════════════════════════════════════════════════════════════════════════

\echo '── 1. OÙ EN EST-ON DU PLAFOND ──'
SELECT
  pg_size_pretty(pg_database_size(current_database()))                    AS base,
  (pg_database_size(current_database())/1024.0/1024.0)::numeric(10,1)     AS mo,
  (500 - pg_database_size(current_database())/1024.0/1024.0)::numeric(10,1) AS marge_mo,
  ((pg_database_size(current_database())/1024.0/1024.0)/500*100)::numeric(5,1) AS pct,
  CASE
    WHEN pg_database_size(current_database())/1024.0/1024.0 > 475 THEN 'CRITIQUE — lecture seule imminente'
    WHEN pg_database_size(current_database())/1024.0/1024.0 > 400 THEN 'TENDU — planifier le passage au plan payant'
    ELSE                                                               'ok'
  END AS etat;

\echo ''
\echo '── 2. CE QUE COÛTE UNE ÉCOLE, ET CE QUE COÛTERAIT LE PARC ──'
-- ⚠️ Extrapolation LINÉAIRE, donc optimiste : elle suppose que les écoles
-- réelles ressemblent aux écoles semées (~246 élèves, une année de notes déjà
-- saisie). Elle ignore aussi tout ce qui croît avec l'USAGE et non avec le
-- nombre d'écoles — journal d'audit, notifications, pièces jointes.
WITH t AS (
  SELECT (pg_database_size(current_database())/1024.0/1024.0) AS mo,
         (SELECT count(*) FROM schools WHERE is_active)       AS n
)
SELECT n AS ecoles_actuelles,
       (mo/NULLIF(n,0))::numeric(10,1)              AS mo_par_ecole,
       ((mo/NULLIF(n,0))*100/1024)::numeric(10,2)   AS go_pour_100_ecoles,
       ((mo/NULLIF(n,0))*1000/1024)::numeric(10,2)  AS go_pour_1000_ecoles,
       (500/NULLIF(mo/NULLIF(n,0),0))::int          AS ecoles_max_plan_gratuit
  FROM t;

\echo ''
\echo '── 3. LES INDEX QUI PÈSENT PLUS QUE LEURS DONNÉES ──'
-- Un index plus gros que sa table n'est pas anormal en soi ; un index JAMAIS
-- LU qui pèse plus que sa table l'est. ⚠️ Vérifier la ligne 4 AVANT de
-- conclure : un idx_scan à 0 ne vaut que si les statistiques sont anciennes.
SELECT relname AS table_, indexrelname AS index_, idx_scan AS lectures,
       pg_size_pretty(pg_relation_size(indexrelid)) AS taille
  FROM pg_stat_user_indexes
 WHERE schemaname = 'public'
   AND pg_relation_size(indexrelid) > 2*1024*1024
   AND idx_scan < 100
 ORDER BY pg_relation_size(indexrelid) DESC;

\echo ''
\echo '── 4. DEPUIS QUAND LES STATISTIQUES COMPTENT (sans ça, la 3 ne vaut rien) ──'
SELECT to_char(stats_reset, 'DD/MM/YYYY HH24:MI') AS remises_a_zero_le,
       (now() - stats_reset)::interval            AS periode_d_observation
  FROM pg_stat_database WHERE datname = current_database();

\echo ''
\echo '── 5. LES CANDIDATS LAISSÉS EN PLACE, ET CE QU''ILS COÛTERAIENT À MILLE ÉCOLES ──'
-- Retirés le 2026-09-01 (migration 0173) parce que redondants par CONSTRUCTION :
--   idx_enrollments_student_year  (doublon exact d'une contrainte unique) 8,5 Mo
--   idx_students_ine              (préfixe strict d'une contrainte unique) 4,0 Mo
-- Ceux qui restent ne sont que « peu lus », ce qui est une preuve plus faible.
-- Leur coût projeté est le vrai argument, pas leur inutilité apparente :
SELECT i.indexrelname AS index_,
       i.idx_scan     AS lectures,
       pg_size_pretty(pg_relation_size(i.indexrelid)) AS aujourdhui,
       pg_size_pretty((pg_relation_size(i.indexrelid)::numeric
         * 1000 / NULLIF((SELECT count(*) FROM schools WHERE is_active),0))::bigint) AS a_1000_ecoles
  FROM pg_stat_user_indexes i
 WHERE i.schemaname = 'public'
   AND i.indexrelname IN ('idx_students_name',
                          'idx_grades_created_by',
                          'idx_bulletin_subject_lines_subject_id')
 ORDER BY pg_relation_size(i.indexrelid) DESC;
