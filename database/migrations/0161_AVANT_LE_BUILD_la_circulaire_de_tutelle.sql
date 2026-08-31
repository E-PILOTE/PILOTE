-- ═══════════════════════════════════════════════════════════════════════════
--  0161 — LA CIRCULAIRE DE TUTELLE
--
--  ── CE QUE C'EST, ET CE QUE CE N'EST PAS ─────────────────────────────────
--  Un ministère doit pouvoir ÉCRIRE aux établissements de son réseau. Pas
--  bavarder : notifier. Une circulaire est DESCENDANTE, DATÉE et ACCUSÉE.
--
--  ⚠️ CE N'EST PAS UNE MESSAGERIE. Il n'y a pas de fil, pas de réponse, pas de
--  destinataire individuel. Le seul retour prévu est l'ACCUSÉ DE LECTURE — et
--  c'est tout l'intérêt : une circulaire dont on ne peut pas prouver la
--  réception n'a aucune valeur administrative. Toute la valeur du dispositif
--  est dans la colonne `lu_le`, pas dans le texte.
--
--  ⚠️ LES DESTINATAIRES SONT DES ÉTABLISSEMENTS, PAS DES PERSONNES. La chaîne
--  est ministère → groupe / chef d'établissement. Jamais l'élève, jamais le
--  parent. Ouvrir un canal par lequel l'État écrit directement aux familles
--  d'une école privée n'est pas une décision qu'on prend par commodité
--  technique — et une fois ouvert, il ne se referme plus.
--
--  ── POURQUOI LA LISTE EST FIGÉE À LA PUBLICATION ─────────────────────────
--  `circulaire_destinataires` est MATÉRIALISÉE au moment de publier, pas
--  calculée à la lecture. Une école créée le mois suivant n'a pas à apparaître
--  « en défaut de lecture » d'une circulaire envoyée avant qu'elle n'existe.
--  Un taux de lecture qui bouge tout seul est un taux dont on ne peut rien
--  conclure.
--
--  ── PORTÉE DE CETTE MIGRATION ────────────────────────────────────────────
--  Émission par le ministère et réception par les ADMINISTRATEURS DE GROUPE
--  (chemin en ligne). La réception par le chef d'établissement hors ligne
--  demande deux flux PowerSync supplémentaires : ils sont écrits dans
--  `powersync/config/sync-rules.yaml` mais NON DÉPLOYÉS — le déploiement passe
--  par le tableau de bord PowerSync Cloud et n'est pas fait ici.
-- ═══════════════════════════════════════════════════════════════════════════

BEGIN;

DO $$ BEGIN
  CREATE TYPE public.circulaire_priorite AS ENUM ('normale', 'importante', 'urgente');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS public.circulaires (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  emetteur_group_id uuid NOT NULL REFERENCES public.school_groups(id) ON DELETE CASCADE,
  tutelle           tutelle_enum NOT NULL,
  reference         varchar(80),
  objet             varchar(200) NOT NULL,
  corps             text NOT NULL,
  priorite          circulaire_priorite NOT NULL DEFAULT 'normale',
  -- Ciblage. NULL = pas de restriction sur ce critère.
  -- ⚠️ `school_type_enum`, PAS `group_type`. Deux énumérations distinctes
  -- portent les MÊMES libellés (`public` | `prive`) : l'une sur le groupe,
  -- l'autre sur l'école. Les confondre ne se voit qu'à la publication, où
  -- Postgres refuse la comparaison (42883) — donc au pire moment.
  cible_secteur     school_type_enum,
  cible_departement varchar(100),
  cible_group_ids   uuid[],
  accuse_requis     boolean NOT NULL DEFAULT true,
  echeance          date,
  publiee_le        timestamptz,
  publiee_par       uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_by        uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at        timestamptz NOT NULL DEFAULT NOW(),
  updated_at        timestamptz NOT NULL DEFAULT NOW(),
  CONSTRAINT circulaires_objet_non_vide CHECK (btrim(objet) <> ''),
  CONSTRAINT circulaires_corps_non_vide CHECK (btrim(corps) <> '')
);

CREATE INDEX IF NOT EXISTS idx_circulaires_emetteur
  ON public.circulaires (emetteur_group_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_circulaires_publiees
  ON public.circulaires (tutelle, publiee_le DESC) WHERE publiee_le IS NOT NULL;

COMMENT ON TABLE public.circulaires IS
  'Note descendante d''une tutelle vers les etablissements de son reseau. '
  'Pas une messagerie : aucun fil, aucune reponse. Le retour prevu est '
  'l''accuse de lecture (circulaire_destinataires.lu_le).';

CREATE TABLE IF NOT EXISTS public.circulaire_destinataires (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  circulaire_id  uuid NOT NULL REFERENCES public.circulaires(id) ON DELETE CASCADE,
  school_id      uuid NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  group_id       uuid NOT NULL REFERENCES public.school_groups(id) ON DELETE CASCADE,
  lu_le          timestamptz,
  lu_par         uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at     timestamptz NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_circulaire_destinataire UNIQUE (circulaire_id, school_id)
);

CREATE INDEX IF NOT EXISTS idx_circ_dest_groupe
  ON public.circulaire_destinataires (group_id, lu_le);
CREATE INDEX IF NOT EXISTS idx_circ_dest_ecole
  ON public.circulaire_destinataires (school_id, lu_le);

COMMENT ON COLUMN public.circulaire_destinataires.lu_le IS
  'Accuse de lecture. C''est la SEULE colonne qu''un destinataire peut ecrire, '
  'et la seule qui donne sa valeur administrative a la circulaire.';

ALTER TABLE public.circulaires ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.circulaire_destinataires ENABLE ROW LEVEL SECURITY;

COMMIT;

-- ═══════════════════════════════════════════════════════════════════════════
--  PARTIE 2 — QUI VOIT QUOI, ET QUI PEUT ÉCRIRE
--
--  ⚠️ AUCUNE POLITIQUE D'UPDATE N'EST POSÉE. Les deux seules écritures possibles
--  passent par des RPC `SECURITY DEFINER` : publier, et accuser réception.
--  C'est délibéré. Un UPDATE que le `USING` d'une politique écarte ne lève
--  AUCUNE erreur — il touche zéro ligne, PostgREST répond 204, et l'écran
--  affiche « enregistré ». Ce piège a été trouvé trois fois dans ce dépôt
--  le 2026-08-30 (migrations 0154, 0155, 0157). Ici, il ne peut pas se poser :
--  une RPC qui refuse LÈVE.
-- ═══════════════════════════════════════════════════════════════════════════

BEGIN;

-- Rompt la boucle : la politique de `circulaire_destinataires` a besoin de
-- connaître l'émetteur d'une circulaire, mais lire `circulaires` y appliquerait
-- SA politique, qui elle-même lit `circulaire_destinataires`. En SECURITY
-- DEFINER, la lecture échappe à la RLS et le cycle n'existe pas.
CREATE OR REPLACE FUNCTION public.circulaire_emetteur(p_id uuid)
RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp AS $fn$
  SELECT emetteur_group_id FROM circulaires WHERE id = p_id;
$fn$;

-- ── circulaires ──────────────────────────────────────────────────────────
DROP POLICY IF EXISTS circulaires_super_admin ON public.circulaires;
CREATE POLICY circulaires_super_admin ON public.circulaires
  FOR ALL TO authenticated
  USING (public.is_super_admin()) WITH CHECK (public.is_super_admin());

-- L'émetteur : une tutelle, et seulement sur SES propres circulaires.
DROP POLICY IF EXISTS circulaires_emetteur ON public.circulaires;
CREATE POLICY circulaires_emetteur ON public.circulaires
  FOR ALL TO authenticated
  USING (public.auth_peut_superviser()
         AND emetteur_group_id = public.auth_group_id())
  WITH CHECK (public.auth_peut_superviser()
         AND emetteur_group_id = public.auth_group_id());

-- Le destinataire : seulement PUBLIÉE, et seulement si son groupe figure dans
-- la liste figée à la publication. Un brouillon ne fuit pas.
DROP POLICY IF EXISTS circulaires_destinataire ON public.circulaires;
CREATE POLICY circulaires_destinataire ON public.circulaires
  FOR SELECT TO authenticated
  USING (publiee_le IS NOT NULL AND EXISTS (
    SELECT 1 FROM circulaire_destinataires d
     WHERE d.circulaire_id = circulaires.id
       AND d.group_id = public.auth_group_id()));

-- ── circulaire_destinataires ─────────────────────────────────────────────
DROP POLICY IF EXISTS circ_dest_super_admin ON public.circulaire_destinataires;
CREATE POLICY circ_dest_super_admin ON public.circulaire_destinataires
  FOR ALL TO authenticated
  USING (public.is_super_admin()) WITH CHECK (public.is_super_admin());

-- L'émetteur voit QUI A LU. C'est la raison d'être de la table.
DROP POLICY IF EXISTS circ_dest_emetteur ON public.circulaire_destinataires;
CREATE POLICY circ_dest_emetteur ON public.circulaire_destinataires
  FOR SELECT TO authenticated
  USING (public.auth_peut_superviser()
         AND public.circulaire_emetteur(circulaire_id) = public.auth_group_id());

DROP POLICY IF EXISTS circ_dest_destinataire ON public.circulaire_destinataires;
CREATE POLICY circ_dest_destinataire ON public.circulaire_destinataires
  FOR SELECT TO authenticated
  USING (group_id = public.auth_group_id());

COMMIT;

-- ═══════════════════════════════════════════════════════════════════════════
--  PARTIE 3 — PUBLIER, ET ACCUSER RÉCEPTION
-- ═══════════════════════════════════════════════════════════════════════════

BEGIN;

CREATE OR REPLACE FUNCTION public.circulaire_publier(p_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $fn$
DECLARE c circulaires%ROWTYPE; v_n integer; v_groupes integer;
BEGIN
  IF p_id IS NULL THEN RAISE EXCEPTION 'Circulaire non specifiee'; END IF;

  SELECT * INTO c FROM circulaires WHERE id = p_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Circulaire introuvable'; END IF;

  IF NOT (is_super_admin()
          OR (auth_peut_superviser() AND c.emetteur_group_id = auth_group_id())) THEN
    RAISE EXCEPTION 'Acces refuse : seule la tutelle emettrice publie sa circulaire'
      USING ERRCODE = '42501';
  END IF;

  -- Publier deux fois ajouterait les écoles créées entre-temps à une liste
  -- censée être figée, et ferait bouger le taux de lecture après coup.
  IF c.publiee_le IS NOT NULL THEN
    RAISE EXCEPTION 'Cette circulaire est deja publiee (le %). Une circulaire '
      'publiee ne se republie pas : en emettre une nouvelle.',
      to_char(c.publiee_le, 'DD/MM/YYYY') USING ERRCODE = '23505';
  END IF;

  INSERT INTO circulaire_destinataires (circulaire_id, school_id, group_id)
  SELECT c.id, s.id, s.group_id
    FROM schools s
   WHERE s.is_active
     AND s.group_id IS NOT NULL
     AND s.tutelle = c.tutelle
     AND (c.cible_secteur     IS NULL OR s.school_type = c.cible_secteur)
     AND (c.cible_departement IS NULL OR s.department  = c.cible_departement)
     AND (c.cible_group_ids   IS NULL OR s.group_id = ANY (c.cible_group_ids))
  ON CONFLICT (circulaire_id, school_id) DO NOTHING;

  GET DIAGNOSTICS v_n = ROW_COUNT;

  -- Zéro destinataire = un ciblage qui ne désigne personne. La publier
  -- laisserait croire qu'elle est partie.
  IF v_n = 0 THEN
    RAISE EXCEPTION 'Aucun etablissement ne correspond a ce ciblage : la '
      'circulaire ne partirait a personne.' USING ERRCODE = '23514';
  END IF;

  UPDATE circulaires
     SET publiee_le = NOW(), publiee_par = auth.uid(), updated_at = NOW()
   WHERE id = c.id;

  SELECT COUNT(DISTINCT group_id) INTO v_groupes
    FROM circulaire_destinataires WHERE circulaire_id = c.id;

  INSERT INTO notifications (group_id, recipient_id, type, title, body, data, sent_at)
  SELECT DISTINCT d.group_id, p.id, 'announcement',
         CASE c.priorite WHEN 'urgente' THEN 'Circulaire URGENTE - ' ELSE 'Circulaire - ' END
           || c.objet,
         'Votre tutelle a publie une circulaire'
           || COALESCE(' (ref. ' || c.reference || ')', '')
           || CASE WHEN c.accuse_requis THEN '. Un accuse de lecture est attendu.' ELSE '.' END,
         jsonb_build_object('route', '/admin/circulaires', 'circulaire_id', c.id),
         NOW()
    FROM circulaire_destinataires d
    JOIN profiles p ON p.group_id = d.group_id
                   AND p.role = 'admin_groupe' AND p.is_active
   WHERE d.circulaire_id = c.id;

  RETURN jsonb_build_object('success', true, 'etablissements', v_n, 'groupes', v_groupes);
END;
$fn$;

CREATE OR REPLACE FUNCTION public.circulaire_accuser(p_circulaire_id uuid, p_school_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $fn$
DECLARE d circulaire_destinataires%ROWTYPE;
BEGIN
  SELECT * INTO d FROM circulaire_destinataires
   WHERE circulaire_id = p_circulaire_id AND school_id = p_school_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Cet etablissement ne figure pas parmi les destinataires.'
      USING ERRCODE = '42501';
  END IF;

  IF NOT (is_super_admin()
          OR (is_admin_groupe() AND d.group_id = auth_group_id())
          OR auth_school_id() = p_school_id) THEN
    RAISE EXCEPTION 'Acces refuse' USING ERRCODE = '42501';
  END IF;

  -- Un accusé ne se réécrit pas : la première lecture est la date qui fait foi.
  -- Réappuyer sur le bouton ne doit pas repousser la preuve dans le temps.
  IF d.lu_le IS NOT NULL THEN
    RETURN jsonb_build_object('success', true, 'deja_lu', true, 'lu_le', d.lu_le);
  END IF;

  UPDATE circulaire_destinataires
     SET lu_le = NOW(), lu_par = auth.uid()
   WHERE id = d.id;

  RETURN jsonb_build_object('success', true, 'deja_lu', false);
END;
$fn$;

COMMIT;
