-- 0053 — Provenance des résultats d'examen : une donnée REÇUE, jamais produite
--
-- ── LA RÈGLE (docs/superpowers/specs/2026-07-17-architecture-transmission-dec.md, §5)
-- « Un retour est une DONNÉE REÇUE, jamais une donnée que nous produisons. Elle
--   porte sa SOURCE et sa DATE DE RÉCEPTION. Si la DEC et nous divergeons, la
--   DEC a raison — l'app doit le MONTRER, pas le masquer. »
--
-- E-PILOTE n'est PAS le système d'inscription : la DEC attribue les numéros,
-- affecte les centres, proclame les résultats. `result`, `candidate_number` et
-- `center_id` sont des champs ENTRANTS. Rien dans le schéma ne le disait — un
-- résultat saisi était indiscernable d'un résultat inventé.
--
-- ── LES DEUX HORLOGES QU'ON CONFONDAIT ─────────────────────────────────────
-- `decided_at` était écrit à `now()` au moment de la saisie. C'est faux, et ça
-- détruit une information : la DEC proclame le 12 juillet, l'école saisit le
-- 20 — ce sont DEUX dates, et seule la première fait foi.
--
--   decided_at         -> PROCLAMATION par la DEC (leur horloge). Peut être NULL
--                         si l'école ne connaît pas la date officielle.
--   result_received_at -> RÉCEPTION chez nous (notre horloge). Quand l'info est
--                         entrée dans le système, par qui, comment.
--
-- ── POURQUOI CE N'EST PAS DU LUXE ──────────────────────────────────────────
-- Le jour où l'API existe (cf. spec-api-dec.md), un résultat importé écrasera-t-il
-- un résultat saisi à la main ? Sans provenance, impossible de trancher — et on
-- écraserait la donnée officielle par une frappe. Avec provenance, la règle est
-- triviale : api_dec > import_csv > saisie_manuelle.
--
-- ⚠️ Aucune contrainte NOT NULL, aucun trigger de rejet : une écriture refusée
-- par le serveur provoque la PERTE SILENCIEUSE à la synchro PowerSync (le bug
-- qui a déjà détruit une inscription complète ici). On documente, on ne bloque pas.

BEGIN;

-- ── Source du résultat ─────────────────────────────────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'result_source') THEN
    CREATE TYPE result_source AS ENUM ('saisie_manuelle', 'import_csv', 'api_dec');
  END IF;
END $$;

ALTER TABLE public.exam_candidates
  ADD COLUMN IF NOT EXISTS result_source      result_source,
  ADD COLUMN IF NOT EXISTS result_received_at timestamptz,
  ADD COLUMN IF NOT EXISTS result_recorded_by uuid REFERENCES public.profiles(id);

COMMENT ON COLUMN public.exam_candidates.result IS
  'ENTRANT — proclamé par la DEC, jamais produit par E-PILOTE. Voir result_source.';
COMMENT ON COLUMN public.exam_candidates.candidate_number IS
  'ENTRANT — attribué par la DEC. Ne jamais générer.';
COMMENT ON COLUMN public.exam_candidates.center_id IS
  'ENTRANT — centre affecté par la DEC. Ne jamais décider.';
COMMENT ON COLUMN public.exam_candidates.decided_at IS
  'Date de PROCLAMATION par la DEC (leur horloge). NULL si inconnue. '
  'Ne JAMAIS y écrire now() à la saisie : c''est result_received_at qui le fait.';
COMMENT ON COLUMN public.exam_candidates.result_source IS
  'Comment le résultat est entré : saisie_manuelle | import_csv | api_dec. '
  'Priorité en cas de conflit : api_dec > import_csv > saisie_manuelle.';
COMMENT ON COLUMN public.exam_candidates.result_received_at IS
  'Date de RÉCEPTION chez nous (notre horloge) — distincte de decided_at.';

-- ── Rattraper l'existant : les résultats déjà saisis (le cas échéant) ───────
-- `decided_at` y valait la date de saisie (bug corrigé ici). On la déplace vers
-- result_received_at — sa vraie signification — et on efface decided_at, qu'on
-- ne connaît pas. Effacer une date fausse vaut mieux que la garder : une date
-- de proclamation inventée serait opposée à la DEC un jour.
UPDATE public.exam_candidates
   SET result_received_at = COALESCE(result_received_at, decided_at),
       result_source      = COALESCE(result_source, 'saisie_manuelle'),
       decided_at         = NULL
 WHERE result <> 'en_attente' AND result_source IS NULL;

CREATE INDEX IF NOT EXISTS idx_exam_candidates_student
  ON public.exam_candidates(student_id);

COMMIT;

-- ── Vérifications ──────────────────────────────────────────────────────────
-- select column_name from information_schema.columns
--  where table_name = 'exam_candidates' and column_name like 'result_%';
-- select result, result_source, count(*) from exam_candidates group by 1,2;
