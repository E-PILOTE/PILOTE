-- ════════════════════════════════════════════════════════════════════════════
--  0156 — FIGER `search_path` SUR NOS FONCTIONS
--
--  ── LE DÉFAUT ─────────────────────────────────────────────────────────────
--  Une fonction dont le `search_path` n'est pas figé résout ses noms d'objets
--  selon le chemin de l'APPELANT. Qui peut créer un objet homonyme dans un
--  schéma placé avant `public` détourne ce que la fonction exécute.
--
--  Relevé avant : 33 de nos fonctions étaient concernées, dont
--  `is_conversation_member` — la SEULE en `SECURITY DEFINER`, et elle sert de
--  garde RLS à la messagerie. Un détournement là ouvrait des conversations.
--
--  ── POURQUOI `ALTER FUNCTION` ET PAS UNE RÉÉCRITURE ───────────────────────
--  `ALTER FUNCTION … SET search_path` ne touche PAS le corps. Trente-trois
--  fonctions réécrites à la main, c'est trente-trois occasions de changer un
--  comportement sans le vouloir ; ici il n'y en a aucune.
--
--  ── ⚠️ CE QUI EST VOLONTAIREMENT ÉPARGNÉ ──────────────────────────────────
--  Les fonctions appartenant à une EXTENSION (`pg_trgm`, `unaccent` — 35 au
--  total). Elles ne sont pas à nous : les modifier casserait la prochaine mise
--  à jour de l'extension. Le filtre `pg_depend.deptype = 'e'` les écarte.
--
--  L'avertissement de l'analyseur les concernant restera donc affiché, et
--  c'est le bon état : le signaler vaut mieux que le faire taire.
--
--  ── VÉRIFIÉ APRÈS APPLICATION ─────────────────────────────────────────────
--    • fonctions SECURITY DEFINER sans search_path figé : 0
--    • fonctions à NOUS sans search_path figé          : 0
--    • restent 35 fonctions d'extension, hors périmètre
--
--  ── ORDRE : AVANT LE BUILD. Purement serveur, sans effet applicatif. ──────
-- ════════════════════════════════════════════════════════════════════════════

DO $$
DECLARE f record; n int := 0;
BEGIN
  FOR f IN
    SELECT p.oid::regprocedure AS sig
      FROM pg_proc p
      JOIN pg_namespace ns ON ns.oid = p.pronamespace
     WHERE ns.nspname = 'public'
       AND NOT EXISTS (
             SELECT 1 FROM pg_depend d
              WHERE d.objid = p.oid AND d.deptype = 'e')
       AND (p.proconfig IS NULL
            OR NOT EXISTS (SELECT 1 FROM unnest(p.proconfig) c
                            WHERE c LIKE 'search_path=%'))
  LOOP
    EXECUTE format('ALTER FUNCTION %s SET search_path = public, pg_temp', f.sig);
    n := n + 1;
  END LOOP;
  RAISE NOTICE 'search_path fige sur % fonction(s)', n;
END $$;
