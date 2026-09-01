-- ═══════════════════════════════════════════════════════════════════════════
--  0167 — LA CIRCULAIRE DESCEND JUSQU'À L'ÉCOLE, HORS LIGNE
--
--  0161 a livré la circulaire de tutelle. Sa réception s'arrête aujourd'hui à
--  l'ADMIN DE GROUPE, en ligne. Le CHEF D'ÉTABLISSEMENT — celui dont l'accusé
--  de lecture fait toute la valeur administrative de la note — ne la reçoit
--  pas : son poste travaille hors ligne, et rien ne lui descend.
--
--  ── LE PLAN NOTÉ DANS LE DÉPÔT NE POUVAIT PAS FONCTIONNER ────────────────
--  `powersync/config/sync-rules.yaml` gardait, en commentaire, un bucket dont
--  la requête de PARAMÈTRES remontait de l'école aux circulaires :
--
--      SELECT d.circulaire_id FROM circulaire_destinataires d
--      JOIN profiles p ON p.school_id = d.school_id
--      WHERE p.id = request.user_id()
--
--  ⚠️ Les Sync Rules PowerSync interdisent explicitement les JOIN, les
--  sous-requêtes et les CTE dans une requête de paramètres, et n'autorisent
--  qu'UNE SEULE table. Cette règle aurait échoué à `validate`. Le commentaire
--  disait « non vérifié contre le moteur » : vérifié le 2026-09-01, il est
--  faux. (Les JOIN existent dans les Sync Streams, en bêta, qui remplaceront
--  les Sync Rules — pas à quatre semaines du déploiement national.)
--
--  On ne contourne donc pas le JOIN : on fait qu'il n'y ait rien à joindre.
--  `circulaire_destinataires` porte DÉJÀ `school_id`, donc elle se filtre
--  seule. Il suffit qu'elle porte aussi ce qu'il y a à lire.
--
--  ── UN INSTANTANÉ, PAS UN CACHE ─────────────────────────────────────────
--  Une circulaire publiée est IMMUABLE par construction : aucune politique
--  d'UPDATE (0161), republication refusée `23505`, assiette des destinataires
--  FIGÉE à la publication. Copier un figé ne peut pas dériver. Et comme 0164,
--  la base l'impose au lieu de le demander : un déclencheur REFUSE toute
--  modification de l'instantané — il LÈVE, il ne laisse pas passer zéro ligne.
--
--  ── LE CIBLAGE EST PRÉSERVÉ, ET C'EST LE POINT ──────────────────────────
--  L'autre chemin sans JOIN était un bucket « par tutelle » : une colonne
--  `tutelle` sur `profiles`, et toutes les circulaires du ministère descendues
--  à toutes ses écoles. Moins de code — et `cible_secteur` / `cible_departement`
--  seraient devenus DÉCORATIFS : une école délibérément exclue du ciblage
--  aurait reçu le texte quand même. Une école reçoit ce qui lui est adressé.
--
--  ⚠️ COÛT ASSUMÉ : le corps est dupliqué par établissement destinataire.
--  Aujourd'hui 0 circulaire et 0 destinataire — c'est le moment le moins cher
--  possible pour changer cette forme. À l'échelle nationale : ~2 Ko × 1 000
--  écoles par circulaire côté serveur, quelques dizaines de Ko par poste et
--  par an. C'est le prix du ciblage, et il est payé une fois par circulaire.
--
--  ⚠️ NE PAS ajouter ces lignes au bucket `by_school` : modifier un bucket
--  existant en change le contenu et fait resynchroniser aux postes TOUT ce
--  qu'il porte (élèves, inscriptions, candidatures). Un bucket NEUF garantit
--  que seul le nouveau contenu descend. Voir `sync-rules.yaml`.
-- ═══════════════════════════════════════════════════════════════════════════

BEGIN;

-- ── 1. L'instantané, porté par la ligne du destinataire ──────────────────
ALTER TABLE public.circulaire_destinataires
  ADD COLUMN IF NOT EXISTS emetteur_group_id uuid,
  ADD COLUMN IF NOT EXISTS emetteur_nom      text,
  ADD COLUMN IF NOT EXISTS reference         varchar(80),
  ADD COLUMN IF NOT EXISTS objet             varchar(200),
  ADD COLUMN IF NOT EXISTS corps             text,
  ADD COLUMN IF NOT EXISTS priorite          circulaire_priorite,
  ADD COLUMN IF NOT EXISTS accuse_requis     boolean,
  ADD COLUMN IF NOT EXISTS echeance          date,
  ADD COLUMN IF NOT EXISTS publiee_le        timestamptz;

COMMENT ON COLUMN public.circulaire_destinataires.corps IS
  'INSTANTANÉ figé à la publication. Existe parce que les Sync Rules PowerSync '
  'interdisent le JOIN en requête de paramètres : sans cette copie, le chef '
  'd''établissement ne peut pas lire la circulaire hors ligne. Écrit une seule '
  'fois par circulaire_publier() ; toute modification est refusée (42501).';

-- ── 2. Reprise de l'existant ─────────────────────────────────────────────
-- 0 ligne aujourd'hui. Écrit quand même : une migration qui suppose une table
-- vide est une migration qui casse le jour où elle ne l'est plus.
UPDATE public.circulaire_destinataires d
   SET emetteur_group_id = c.emetteur_group_id,
       emetteur_nom      = g.name,
       reference         = c.reference,
       objet             = c.objet,
       corps             = c.corps,
       priorite          = c.priorite,
       accuse_requis     = c.accuse_requis,
       echeance          = c.echeance,
       publiee_le        = COALESCE(c.publiee_le, d.created_at)
  FROM public.circulaires c
  LEFT JOIN public.school_groups g ON g.id = c.emetteur_group_id
 WHERE d.circulaire_id = c.id
   AND d.objet IS NULL;

-- ── 3. Ce qui ne peut pas manquer ────────────────────────────────────────
-- Une ligne de destinataire n'existe qu'APRÈS publication (c'est la RPC qui
-- l'insère). Ces colonnes sont donc toujours renseignées, ou la ligne n'a
-- aucun sens : un destinataire sans objet ni corps est une notification vide.
ALTER TABLE public.circulaire_destinataires
  ALTER COLUMN emetteur_group_id SET NOT NULL,
  ALTER COLUMN emetteur_nom      SET NOT NULL,
  ALTER COLUMN objet             SET NOT NULL,
  ALTER COLUMN corps             SET NOT NULL,
  ALTER COLUMN priorite          SET NOT NULL,
  ALTER COLUMN accuse_requis     SET NOT NULL,
  ALTER COLUMN publiee_le        SET NOT NULL;

-- ── 4. L'instantané ne se modifie pas ────────────────────────────────────
-- ⚠️ Un déclencheur qui LÈVE, pas une politique `USING`. La table est
-- synchronisée hors ligne : un `USING` qui écarte l'écriture rendrait zéro
-- ligne côté serveur alors que le poste, lui, a DÉJÀ modifié sa copie locale.
-- L'écran afficherait « enregistré », le serveur n'aurait rien, et la valeur
-- d'origine reviendrait à la synchro suivante. Un `RAISE 42501` est au
-- contraire fatal pour le connecteur : transaction abandonnée, journalisée,
-- bandeau rouge. Voir docs/memoire/blocage-de-file-visible.md.
--
-- `lu_le` et `lu_par` restent volontairement HORS de la comparaison : ce sont
-- les seules colonnes que la vie de la circulaire fait bouger.
CREATE OR REPLACE FUNCTION public.fn_circ_dest_instantane_fige()
RETURNS trigger LANGUAGE plpgsql
SET search_path = public, pg_temp AS $fn$
BEGIN
  IF (NEW.circulaire_id, NEW.school_id, NEW.group_id, NEW.emetteur_group_id,
      NEW.emetteur_nom, NEW.reference, NEW.objet, NEW.corps, NEW.priorite,
      NEW.accuse_requis, NEW.echeance, NEW.publiee_le)
     IS DISTINCT FROM
     (OLD.circulaire_id, OLD.school_id, OLD.group_id, OLD.emetteur_group_id,
      OLD.emetteur_nom, OLD.reference, OLD.objet, OLD.corps, OLD.priorite,
      OLD.accuse_requis, OLD.echeance, OLD.publiee_le)
  THEN
    RAISE EXCEPTION
      'Une circulaire publiee ne se modifie pas. Seul l''accuse de lecture '
      'evolue ; pour corriger le texte, en emettre une nouvelle.'
      USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END; $fn$;

REVOKE EXECUTE ON FUNCTION public.fn_circ_dest_instantane_fige() FROM PUBLIC;

DROP TRIGGER IF EXISTS trg_circ_dest_instantane_fige ON public.circulaire_destinataires;
CREATE TRIGGER trg_circ_dest_instantane_fige
  BEFORE UPDATE ON public.circulaire_destinataires
  FOR EACH ROW EXECUTE FUNCTION public.fn_circ_dest_instantane_fige();

-- ── 5. La publication écrit l'instantané ─────────────────────────────────
-- Deux changements par rapport à 0161 :
--   • l'INSERT porte le contenu figé ;
--   • le chef d'établissement est notifié, et vers SA route. Sans cela il ne
--     découvre la circulaire qu'en ouvrant l'écran — or c'est de lui qu'on
--     attend l'accusé.
-- `v_now` est calculé UNE fois et sert aux deux écritures : deux `NOW()` dans
-- la même transaction renverraient la même valeur, mais l'écrire une fois dit
-- que c'est la même date, au lieu de le supposer.
CREATE OR REPLACE FUNCTION public.circulaire_publier(p_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $function$
DECLARE
  c          circulaires%ROWTYPE;
  v_n        integer;
  v_groupes  integer;
  v_now      timestamptz := NOW();
  v_emetteur text;
BEGIN
  IF p_id IS NULL THEN RAISE EXCEPTION 'Circulaire non specifiee'; END IF;
  SELECT * INTO c FROM circulaires WHERE id = p_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Circulaire introuvable'; END IF;

  IF NOT (is_super_admin()
          OR (auth_peut_superviser() AND c.emetteur_group_id = auth_group_id())) THEN
    RAISE EXCEPTION 'Acces refuse : seule la tutelle emettrice publie sa circulaire'
      USING ERRCODE = '42501';
  END IF;

  IF c.publiee_le IS NOT NULL THEN
    RAISE EXCEPTION
      'Cette circulaire est deja publiee (le %). Une circulaire publiee ne se republie pas : en emettre une nouvelle.',
      to_char(c.publiee_le, 'DD/MM/YYYY') USING ERRCODE = '23505';
  END IF;

  SELECT name INTO v_emetteur FROM school_groups WHERE id = c.emetteur_group_id;
  IF v_emetteur IS NULL THEN
    RAISE EXCEPTION 'Groupe emetteur introuvable : la circulaire n''aurait pas de signataire.';
  END IF;

  INSERT INTO circulaire_destinataires (
    circulaire_id, school_id, group_id,
    emetteur_group_id, emetteur_nom, reference, objet, corps,
    priorite, accuse_requis, echeance, publiee_le)
  SELECT c.id, s.id, s.group_id,
         c.emetteur_group_id, v_emetteur, c.reference, c.objet, c.corps,
         c.priorite, c.accuse_requis, c.echeance, v_now
    FROM schools s
   WHERE s.is_active AND s.group_id IS NOT NULL AND s.tutelle = c.tutelle
     AND (c.cible_secteur     IS NULL OR s.school_type = c.cible_secteur)
     AND (c.cible_departement IS NULL OR s.department  = c.cible_departement)
     AND (c.cible_group_ids   IS NULL OR s.group_id = ANY (c.cible_group_ids))
  ON CONFLICT (circulaire_id, school_id) DO NOTHING;
  GET DIAGNOSTICS v_n = ROW_COUNT;

  IF v_n = 0 THEN
    RAISE EXCEPTION
      'Aucun etablissement ne correspond a ce ciblage : la circulaire ne partirait a personne.'
      USING ERRCODE = '23514';
  END IF;

  UPDATE circulaires
     SET publiee_le = v_now, publiee_par = auth.uid(), updated_at = v_now
   WHERE id = c.id;

  SELECT COUNT(DISTINCT group_id) INTO v_groupes
    FROM circulaire_destinataires WHERE circulaire_id = c.id;

  -- L'administrateur de groupe : inchangé, il lit en ligne.
  INSERT INTO notifications (group_id, recipient_id, type, title, body, data, sent_at)
  SELECT DISTINCT d.group_id, p.id, 'announcement',
         CASE c.priorite WHEN 'urgente' THEN 'Circulaire URGENTE - ' ELSE 'Circulaire - ' END || c.objet,
         'Votre tutelle a publie une circulaire'
           || COALESCE(' (ref. ' || c.reference || ')', '')
           || CASE WHEN c.accuse_requis THEN '. Un accuse de lecture est attendu.' ELSE '.' END,
         jsonb_build_object('route', '/admin/circulaires', 'circulaire_id', c.id), v_now
    FROM circulaire_destinataires d
    JOIN profiles p ON p.group_id = d.group_id AND p.role = 'admin_groupe' AND p.is_active
   WHERE d.circulaire_id = c.id;

  -- Le chef d'établissement : par ÉCOLE (pas par groupe) et vers sa route.
  -- C'est de lui que l'accuse est attendu ; il doit donc l'apprendre.
  INSERT INTO notifications (group_id, recipient_id, type, title, body, data, sent_at)
  SELECT DISTINCT d.group_id, p.id, 'announcement',
         CASE c.priorite WHEN 'urgente' THEN 'Circulaire URGENTE - ' ELSE 'Circulaire - ' END || c.objet,
         'Votre tutelle a publie une circulaire'
           || COALESCE(' (ref. ' || c.reference || ')', '')
           || CASE WHEN c.accuse_requis THEN '. Un accuse de lecture est attendu.' ELSE '.' END,
         jsonb_build_object('route', '/user/circulaires', 'circulaire_id', c.id), v_now
    FROM circulaire_destinataires d
    JOIN profiles p ON p.school_id = d.school_id
                   AND p.role IN ('directeur', 'proviseur') AND p.is_active
   WHERE d.circulaire_id = c.id;

  RETURN jsonb_build_object('success', true, 'etablissements', v_n, 'groupes', v_groupes);
END; $function$;

COMMIT;
