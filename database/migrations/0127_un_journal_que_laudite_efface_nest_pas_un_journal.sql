-- ════════════════════════════════════════════════════════════════════════════
--  0127 — UN JOURNAL QUE L'AUDITÉ PEUT EFFACER N'EST PAS UN JOURNAL
--
--  `audit_logs` n'avait qu'une politique `FOR ALL` vérifiant l'appartenance à
--  l'école. Tout membre du personnel pouvait donc INSÉRER de fausses lignes
--  d'audit, MODIFIER celles qui le gênaient, et SUPPRIMER la trace de ses
--  propres actes. C'est une erreur de catégorie : le journal existe justement
--  pour survivre à celui qu'il enregistre.
--
--  ── AUCUNE ÉCRITURE CLIENT N'EST LÉGITIME ──────────────────────────────────
--  Relevé du code : les NEUF références à `audit_logs` dans l'application sont
--  des LECTURES (`select`, `count`). Rien n'y écrit depuis un poste.
--  Le seul écrivain réel est le déclencheur `log_fee_structure_change`, qui est
--  `SECURITY DEFINER` : son INSERT ne passe pas par RLS.
--
--  On retire l'écriture au client. Les lectures restent inchangées
--  (super_admin, admin groupe sur son groupe, personnel sur son école) pour ne
--  rien casser : l'écran d'audit et l'historique de l'emploi du temps
--  continuent de lire.
--
--  ── VÉRIFIÉ APRÈS COUP (production, transaction annulée) ───────────────────
--      Direction     insère une fausse trace : REFUSÉ   efface : non
--      Secrétariat   insère une fausse trace : REFUSÉ   efface : non
--      déclencheur SECURITY DEFINER : 19 → 20 lignes (il écrit toujours)
--
--  ⚠️ CE QUE CETTE MIGRATION NE RÉPARE PAS, ET QUI EST PLUS GRAVE : le journal
--  est presque VIDE par construction. `docs/ANALYSE.md` §9 annonce « Audit
--  logs : toutes les actions sensibles (CREATE, UPDATE, DELETE) ». Relevé le
--  2026-08-27 : UN SEUL déclencheur d'audit dans toute la base, sur
--  `fee_structures` ; 82 lignes au total, 6 tables. Ni les notes, ni les
--  bulletins, ni les paiements, ni les présences n'y laissent la moindre
--  trace. L'espace admin groupe affiche donc une page « Audit » rassurante
--  au-dessus d'un journal que presque rien n'alimente. Chantier transverse à
--  décider (volume, non-synchro vers les postes, rétention).
-- ════════════════════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS audit_logs_tenant ON audit_logs;

CREATE POLICY audit_logs_select ON audit_logs
  FOR SELECT
  USING (
    (SELECT is_super_admin())
    OR (group_id = (SELECT auth_group_id())
        AND ((SELECT is_admin_groupe()) OR school_id = (SELECT auth_school_id())))
  );

-- Pas de politique INSERT / UPDATE / DELETE : sans politique, RLS refuse.
-- Les déclencheurs SECURITY DEFINER, eux, ne passent pas par RLS.

COMMENT ON TABLE audit_logs IS
  'Journal des actions sensibles. LECTURE SEULE côté client (migration 0127) : '
  'aucun poste ne doit pouvoir écrire, modifier ou effacer une trace. Les '
  'écritures viennent exclusivement de déclencheurs SECURITY DEFINER.';
