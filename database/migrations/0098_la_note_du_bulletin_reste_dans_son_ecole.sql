-- ════════════════════════════════════════════════════════════════════════════
--  0098 — LA NOTE DU BULLETIN RESTE DANS SON ÉCOLE
--
--  `bulletin_subject_lines` porte le détail matière par matière de chaque
--  bulletin : moyenne de l'élève, moyenne de classe, rang, appréciation. C'est
--  la donnée la plus nominative du produit après la note elle-même.
--
--  Elle n'avait PAS de `school_id`. Or PowerSync interdit les JOIN dans une
--  data query : sans colonne d'école sur la table, il était IMPOSSIBLE de la
--  filtrer par établissement. Elle était donc synchronisée au GROUPE entier :
--
--      - SELECT * FROM bulletin_subject_lines WHERE group_id = bucket.gid
--
--  Conséquence mesurée sur le groupe MEPSA (14 écoles, une seule année
--  scolaire ouverte) : 55 886 lignes descendaient sur CHAQUE poste. Le CEG
--  d'Ewo — 113 élèves — recevait le détail des notes des treize autres
--  établissements du ministère. Le parent (`bulletins`) était pourtant, lui,
--  correctement filtré par école : seul l'enfant fuyait.
--
--  Deux problèmes en un :
--    • CONFIDENTIALITÉ — le bulletin d'un élève de Pointe-Noire était lisible
--      dans la base locale d'un poste de Brazzaville.
--    • VOLUME — ~56 000 lignes par année et par groupe de 14 écoles. À
--      1 000 écoles et cinq ans d'historique, cette seule table sature les
--      postes ; c'est le point de rupture de la trajectoire nationale.
--
--  Cette migration donne à la table l'école qui lui manquait, ce qui rend le
--  filtrage possible côté sync-rules (déplacement de `by_group` vers
--  `by_school`, à déployer via le dashboard PowerSync).
--
--  Le TRIGGER n'est pas une ceinture de sécurité décorative : le parc est
--  offline-first et hétérogène. Un poste resté sur une version antérieure
--  continuera d'insérer des lignes SANS `school_id`. Sans le trigger, ces
--  lignes seraient rejetées par le NOT NULL — l'agent perdrait ses bulletins
--  au moment de la remontée, hors ligne, sans comprendre pourquoi. Le trigger
--  déduit l'école du bulletin parent : l'ancien client continue de marcher.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ─── 1. La colonne ───────────────────────────────────────────────────────────
ALTER TABLE bulletin_subject_lines
  ADD COLUMN IF NOT EXISTS school_id uuid REFERENCES schools(id);

-- ─── 2. Reprise : l'école se lit sur le bulletin parent ──────────────────────
--  `bulletins.school_id` est NOT NULL et `bulletin_id` l'est aussi ; aucune
--  ligne orpheline n'existe (vérifié : 143 569 lignes, 0 orphelin). La reprise
--  est donc totale et le NOT NULL de l'étape 4 ne peut pas échouer.
UPDATE bulletin_subject_lines l
   SET school_id = b.school_id
  FROM bulletins b
 WHERE b.id = l.bulletin_id
   AND l.school_id IS DISTINCT FROM b.school_id;

-- ─── 3. Le trigger qui rend la colonne infaillible ───────────────────────────
--  Renseigne `school_id` (et `group_id`, même raison) depuis le bulletin quand
--  le client ne les fournit pas. Vaut pour INSERT et pour UPDATE : un client
--  ancien qui réécrit une ligne ne doit pas pouvoir la vider de son école.
CREATE OR REPLACE FUNCTION bulletin_line_inherit_scope()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.school_id IS NULL OR NEW.group_id IS NULL THEN
    SELECT COALESCE(NEW.school_id, b.school_id),
           COALESCE(NEW.group_id,  b.group_id)
      INTO NEW.school_id, NEW.group_id
      FROM bulletins b
     WHERE b.id = NEW.bulletin_id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_bulletin_line_inherit_scope ON bulletin_subject_lines;
CREATE TRIGGER trg_bulletin_line_inherit_scope
  BEFORE INSERT OR UPDATE ON bulletin_subject_lines
  FOR EACH ROW EXECUTE FUNCTION bulletin_line_inherit_scope();

-- ─── 4. Le verrou ────────────────────────────────────────────────────────────
ALTER TABLE bulletin_subject_lines
  ALTER COLUMN school_id SET NOT NULL;

-- ─── 5. L'index de la requête de synchro ─────────────────────────────────────
--  `WHERE school_id = bucket.sid` est désormais la data query de PowerSync :
--  elle est rejouée à chaque réplication, sur la table la plus volumineuse du
--  schéma. Elle ne doit jamais faire de seq scan.
CREATE INDEX IF NOT EXISTS idx_bsl_school
  ON bulletin_subject_lines (school_id);

-- ─── 6. RLS : on resserre sans casser l'espace groupe ────────────────────────
--  La policy reste au GROUPE, volontairement : `admin_groupe` agrège les
--  résultats de tout son réseau (analytics d'année, palmarès, rapports PDF) et
--  doit continuer à lire au-delà d'une école. La séparation par établissement
--  est assurée par les sync-rules — c'est-à-dire par ce qui descend réellement
--  sur les postes — et non par la RLS.
--  Aucune modification ici : la mention est là pour que la prochaine lecture
--  n'y voie pas un oubli.

COMMIT;
