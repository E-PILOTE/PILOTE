-- ════════════════════════════════════════════════════════════════════════════
--  0107 — LE BARÈME DE PASSAGE SE RÈGLE
--
--  ── LE PROBLÈME ────────────────────────────────────────────────────────────
--  La barre de passage vivait en dur dans le code Dart : `annualAverage >= 10`,
--  écrit littéralement dans `suggestedVerdict`, sans même passer par la
--  constante `kPassingMark` qui existait pourtant à côté. Deux exemplaires du
--  même nombre, donc, dans le même dépôt.
--
--  On connaît la suite : le barème des MENTIONS a vécu en trois exemplaires,
--  deux ont dérivé de deux points, et c'est la version décalée qui s'imprimait
--  sur les bulletins — 8/20, une note d'échec, ressortait « Passable ».
--  Ici la dérive ne changerait pas une étiquette : elle changerait qui redouble.
--
--  ── CE QUE POSE CETTE MIGRATION ────────────────────────────────────────────
--  Deux nombres, réglables par le GROUPE, hérités par ses écoles :
--
--    promotion_pass_mark          la barre. Au-dessus (inclus), l'élève passe.
--    promotion_deliberation_floor le plancher. En dessous (strict), il redouble.
--
--  Entre les deux s'ouvre la ZONE DE DÉLIBÉRATION : le logiciel ne propose
--  rien, et le conseil tranche. C'est l'usage documenté dans les systèmes
--  voisins d'Afrique francophone, et c'est plus honnête qu'un redoublement
--  automatique prononcé à 9,98 de moyenne.
--
--  Plancher NULL = pas de zone : la barre fait couperet, comportement actuel.
--  C'est la valeur posée par défaut — cette migration ne change RIEN au verdict
--  d'aucun élève tant que personne n'a réglé quoi que ce soit.
--
--  ── POURQUOI SUR school_groups ET school_levels ────────────────────────────
--  Les deux tables descendent déjà en ENTIER sur les postes (`SELECT *` dans
--  `by_group`). Y ajouter des colonnes met donc le réglage entre les mains de
--  chaque école hors ligne SANS toucher aux sync-rules — dont un déploiement
--  raté coupe la synchro de mille écoles. Même chemin que
--  `subscription_alert_days` (0106) et que les colonnes dénormalisées de
--  `classes` (0010-0012).
--
--  `school_levels` porte la dérogation : un ministère peut vouloir 9,5 au
--  primaire et 10 au secondaire. NULL = on hérite du groupe. La table porte
--  déjà `notation_type`, c'est-à-dire le système de notation du niveau : la
--  barre de réussite est de la même nature, elle est à sa place ici.
--
--  ⚠️ Toute modification de ces bornes doit rester alignée avec
--  `lib/core/utils/passage_bareme.dart`, côté Dart. Le SQL et le Dart lisent la
--  même colonne, mais c'est le Dart qui décide sur le poste hors ligne : les
--  deux doivent dire la même chose. Même règle que `get_mention()` et
--  `mention.dart`.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ─── Le barème du groupe ────────────────────────────────────────────────────

ALTER TABLE public.school_groups
  ADD COLUMN IF NOT EXISTS promotion_pass_mark numeric(4,2) NOT NULL DEFAULT 10,
  ADD COLUMN IF NOT EXISTS promotion_deliberation_floor numeric(4,2);

COMMENT ON COLUMN public.school_groups.promotion_pass_mark IS
  'Barre de passage en classe supérieure, sur 20. L''élève dont la moyenne '
  'annuelle l''atteint passe. Défaut 10 : le barème METP.';

COMMENT ON COLUMN public.school_groups.promotion_deliberation_floor IS
  'Plancher de la zone de délibération, sur 20. Sous ce seuil l''élève '
  'redouble ; entre lui et la barre, le logiciel ne propose rien et le conseil '
  'tranche. NULL = pas de zone, la barre fait couperet.';

-- ─── La dérogation par niveau ───────────────────────────────────────────────

ALTER TABLE public.school_levels
  ADD COLUMN IF NOT EXISTS pass_mark numeric(4,2),
  ADD COLUMN IF NOT EXISTS deliberation_floor numeric(4,2);

COMMENT ON COLUMN public.school_levels.pass_mark IS
  'Barre de passage propre à ce niveau. NULL = hérite du groupe.';

COMMENT ON COLUMN public.school_levels.deliberation_floor IS
  'Plancher de délibération propre à ce niveau. NULL = hérite du groupe.';

-- ─── Ce qu'une note sur 20 peut être, et ne peut pas être ───────────────────
--
-- Une barre à 25 rendrait TOUTE une école redoublante, une barre négative la
-- rendrait toute passante, et un plancher au-dessus de la barre ouvrirait une
-- zone de délibération à l'envers — un élève à 11 « en délibération » et un
-- élève à 9 « admis ». Aucun de ces trois états ne se rattrape après coup :
-- les décisions sont écrites, figées, et imprimées sur un procès-verbal.

ALTER TABLE public.school_groups
  DROP CONSTRAINT IF EXISTS school_groups_bareme_passage_coherent;
ALTER TABLE public.school_groups
  ADD CONSTRAINT school_groups_bareme_passage_coherent CHECK (
    promotion_pass_mark > 0
    AND promotion_pass_mark <= 20
    AND (
      promotion_deliberation_floor IS NULL
      OR (promotion_deliberation_floor >= 0
          AND promotion_deliberation_floor < promotion_pass_mark)
    )
  );

ALTER TABLE public.school_levels
  DROP CONSTRAINT IF EXISTS school_levels_bareme_passage_coherent;
ALTER TABLE public.school_levels
  ADD CONSTRAINT school_levels_bareme_passage_coherent CHECK (
    (pass_mark IS NULL OR (pass_mark > 0 AND pass_mark <= 20))
    AND (deliberation_floor IS NULL OR deliberation_floor >= 0)
    AND (
      deliberation_floor IS NULL
      OR pass_mark IS NULL
      OR deliberation_floor < pass_mark
    )
  );

-- ─── Le verdict lu en SQL, identique à celui lu en Dart ─────────────────────
--
-- Le poste décide hors ligne, en Dart. Cette fonction sert aux lectures
-- SERVEUR — tableaux de bord du groupe, exports du ministère, contrôles. Elle
-- doit rendre EXACTEMENT ce que rend `verdictPropose()` côté Dart, sans quoi le
-- ministère et l'école liront deux vérités sur le même enfant.
--
-- Elle ne rend jamais 'reoriente' : la réorientation est un choix
-- d'orientation, pas un seuil de moyenne. Et elle rend NULL dans la zone de
-- délibération — l'absence de proposition EST la proposition.

CREATE OR REPLACE FUNCTION public.verdict_passage(
  moyenne numeric,
  barre numeric,
  plancher numeric DEFAULT NULL
) RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN moyenne IS NULL OR barre IS NULL THEN NULL
    WHEN moyenne >= barre                 THEN 'passe'
    WHEN plancher IS NULL                 THEN 'redouble'
    WHEN moyenne <  plancher              THEN 'redouble'
    ELSE NULL                             -- zone de délibération
  END;
$$;

COMMENT ON FUNCTION public.verdict_passage(numeric, numeric, numeric) IS
  'Verdict de passage proposé. NULL = aucune proposition (pas de moyenne, ou '
  'zone de délibération). Doit rester identique à verdictPropose() dans '
  'lib/core/utils/passage_bareme.dart.';

COMMIT;
