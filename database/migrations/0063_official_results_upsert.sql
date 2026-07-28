-- ════════════════════════════════════════════════════════════════════════════
--  0063 — RELEVÉ D'UN CHIFFRE OFFICIEL : rendre l'upsert possible.
--
--  La migration 0062 protégeait l'unicité d'un relevé par un index
--  d'EXPRESSION :
--      (session_id, scope, COALESCE(department,''), COALESCE(school_id, 0…0),
--       COALESCE(filiere_label,''))
--  L'intention était juste — deux relevés pour le même périmètre sont deux
--  vérités concurrentes — mais Postgres n'infère jamais un index d'expression
--  depuis un `ON CONFLICT (colonnes)`. Toute écriture applicative partait donc
--  en 42P10 :
--      « there is no unique or exclusion constraint matching the ON CONFLICT
--        specification »
--  Conséquence en production : au dépôt d'une publication, le fichier était
--  téléversé, la pièce insérée, PUIS les chiffres relevés dessus échouaient.
--  L'archive gardait le document et perdait ses chiffres — exactement ce que
--  0062 voulait empêcher.
--
--  Correction : le même invariant, exprimé sur les colonnes elles-mêmes.
--  `NULLS NOT DISTINCT` (PG 15+, la base est en 17) donne à NULL le rôle que
--  jouait le COALESCE : deux relevés « national, sans département, sans école,
--  sans filière » entrent toujours en collision. L'unicité ne change pas ;
--  seule l'inférence redevient possible.
-- ════════════════════════════════════════════════════════════════════════════

drop index if exists public.exam_official_results_uniq;

create unique index exam_official_results_uniq
  on public.exam_official_results
     (session_id, scope, department, school_id, filiere_label)
  nulls not distinct;

comment on index public.exam_official_results_uniq is
  'Un seul relevé officiel par (session, périmètre, filière). NULLS NOT '
  'DISTINCT : indispensable pour que ON CONFLICT (colonnes) puisse l''inférer '
  '— un index d''expression ne l''est jamais (cf. migration 0063).';
