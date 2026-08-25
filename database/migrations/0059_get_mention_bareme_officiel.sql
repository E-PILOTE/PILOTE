-- ════════════════════════════════════════════════════════════════════════════
--  MENTIONS — alignement sur le barème officiel (METP, 2026-07-22).
--
--  La fonction en place décalait chaque seuil de deux points. Conséquence la
--  plus grave : 8/20 — une note d'échec — ressortait « Passable » sur le
--  bulletin, et 15/20 « Très Bien ». Le barème officiel est celui-ci :
--
--    Excellent    ≥ 18
--    Très Bien    ≥ 16
--    Bien         ≥ 14
--    Assez Bien   ≥ 12
--    Passable     ≥ 10
--    Insuffisant  < 10   ← la barre de réussite reste 10/20
--
--  Le côté client applique le même barème (`mentionFor` dans
--  `bulletins_provider.dart`, `GradeModel.mention`). Les trois doivent rester
--  identiques : une divergence produirait un bulletin dont la mention change
--  selon qu'on la lit à l'écran ou en base.
--
--  Aucune donnée à reprendre : la table `bulletins` est vide au moment de
--  cette migration (vérifié). Si des bulletins existaient, il faudrait
--  recalculer leur colonne `mention` — voir la requête en fin de fichier.
-- ════════════════════════════════════════════════════════════════════════════

-- On conserve le type de retour d'origine (`character varying`) : le changer
-- forcerait un DROP, et donc la perte silencieuse de toute dépendance future.
CREATE OR REPLACE FUNCTION get_mention(avg numeric)
RETURNS character varying
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  RETURN CASE
    WHEN avg >= 18 THEN 'Excellent'
    WHEN avg >= 16 THEN 'Très Bien'
    WHEN avg >= 14 THEN 'Bien'
    WHEN avg >= 12 THEN 'Assez Bien'
    WHEN avg >= 10 THEN 'Passable'
    ELSE                'Insuffisant'
  END;
END;
$$;

-- Reprise des bulletins déjà émis, si un jour cette migration est rejouée sur
-- une base qui en contient :
--   UPDATE bulletins
--      SET mention = get_mention(overall_average)
--    WHERE overall_average IS NOT NULL;
