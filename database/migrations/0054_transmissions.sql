-- 0054 — TRANSMISSIONS : prouver ce que l'école a déposé, et quand
--
-- ── LE TROU QUE ÇA COMBLE (architecture-transmission-dec.md §2) ────────────
-- « Mon export recalcule le PDF depuis les données VIVANTES. Conséquence : la
--   liste régénérée en juin ne correspond plus à celle déposée en février (un
--   élève parti, un ajout tardif). L'école ne peut pas prouver ce qu'elle a
--   déposé, ni quand. »
--
-- Or le dépôt ENGAGE l'établissement : c'est daté, c'est opposable, et un
-- candidat oublié perd une année.
--
-- ── LE TERRAIN (établi par l'utilisateur, fonctionnaire à la DSIC) ──────────
-- L'école est un RELAIS À DEUX SORTIES :
--   1. elle SAISIT ses candidats à la main dans l'application de la DEC ;
--   2. elle EXPÉDIE les dossiers papier à la DEC.
-- Les deux flux doivent dire LA MÊME CHOSE. S'ils divergent, la DEC le constate
-- au comptoir et renvoie l'école — après le 14 février 14h00, c'est une année
-- perdue pour l'élève.
--
-- Une transmission est donc UNE SEULE liste figée qui sert à la fois de FEUILLE
-- DE FRAPPE et de BORDEREAU D'EXPÉDITION. Les deux coïncident par construction.
--
-- ── POURQUOI UN SNAPSHOT *ET* DES ITEMS ────────────────────────────────────
-- `snapshot` garantit l'immuabilité littérale (ce qui a été imprimé/tapé).
-- `transmission_items` rend le contenu requêtable (statistiques, réconciliation)
-- sans re-parser du JSON. Les deux, pas l'un ou l'autre.
--
-- ── local_ref ──────────────────────────────────────────────────────────────
-- `EP-<code_école>-<AAAA>-<seq>`, lisible par un humain donc recopiable.
-- ⚠️ Lucidité : la DEC saisit à la main dans SON formulaire ; cette référence
-- ne reviendra PAS tant qu'il n'y a pas d'interface d'échange. Elle ne coûte
-- rien aujourd'hui et devient la clé de réconciliation exacte le jour où l'API
-- existe (spec-api-dec.md §4). On la pose, on ne bâtit rien dessus.
--
-- ── AUCUN REJET SERVEUR ────────────────────────────────────────────────────
-- Pas de trigger qui refuse une écriture : une transaction rejetée provoque la
-- PERTE SILENCIEUSE à la synchro PowerSync (le bug qui a déjà détruit une
-- inscription entière ici). L'immuabilité est une RÈGLE DE L'APPLICATION, pas
-- une contrainte qui casse la synchro.

BEGIN;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'transmission_kind') THEN
    CREATE TYPE transmission_kind AS ENUM
      ('liste_candidats', 'liste_stagiaires', 'pv_resultats', 'rectificatif');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'transmission_status') THEN
    CREATE TYPE transmission_status AS ENUM
      ('brouillon', 'transmis', 'accuse_reception', 'traite', 'rejete');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'transmission_channel') THEN
    -- `saisie_dec` est le canal NOMINAL, pas un pis-aller : c'est ce que
    -- l'école fait réellement aujourd'hui (frappe manuelle + dossiers papier).
    CREATE TYPE transmission_channel AS ENUM
      ('saisie_dec', 'depot_physique', 'csv', 'api_dec');
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.transmissions (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id            uuid NOT NULL REFERENCES public.school_groups(id) ON DELETE CASCADE,
  school_id           uuid NOT NULL REFERENCES public.schools(id)       ON DELETE CASCADE,
  kind                transmission_kind   NOT NULL DEFAULT 'liste_candidats',
  -- L'autorité destinataire : 'dec_metp' | 'dec_mepsa'. Texte et non enum —
  -- la liste des destinataires bougera avant nos migrations.
  recipient           text,
  session_id          uuid REFERENCES public.exam_sessions(id) ON DELETE SET NULL,
  -- Imprimée sur le document. Unique par école.
  reference           text NOT NULL,
  status              transmission_status NOT NULL DEFAULT 'brouillon',
  channel             transmission_channel NOT NULL DEFAULT 'saisie_dec',
  -- La liste TELLE QUE DÉPOSÉE. Figée à la transmission.
  snapshot            jsonb NOT NULL DEFAULT '[]'::jsonb,
  item_count          integer NOT NULL DEFAULT 0,
  transmitted_at      timestamptz,
  transmitted_by      uuid REFERENCES public.profiles(id),
  acknowledged_at     timestamptz,
  acknowledgment_ref  text,
  -- Un RECTIFICATIF est une nouvelle transmission LIÉE à la précédente, jamais
  -- une modification qui réécrit l'histoire.
  corrects_id         uuid REFERENCES public.transmissions(id) ON DELETE SET NULL,
  notes               text,
  created_by          uuid REFERENCES public.profiles(id),
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now()
  -- ⚠️ PAS de UNIQUE(school_id, reference). La référence est GÉNÉRÉE HORS LIGNE
  -- (`EP-<école>-<AAAA>-<seq>`, seq = compte local). Deux postes partagés d'une
  -- même école pourraient produire la même séquence ; un rejet Postgres sur une
  -- contrainte unique provoquerait la PERTE SILENCIEUSE de tout le lot à la
  -- synchro PowerSync (la leçon n°1 du projet). L'identité, c'est l'`id` UUID.
  -- La référence n'est qu'un libellé lisible pour l'humain — une collision est
  -- cosmétique, jamais corruptrice.
);

CREATE TABLE IF NOT EXISTS public.transmission_items (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  transmission_id  uuid NOT NULL REFERENCES public.transmissions(id) ON DELETE CASCADE,
  group_id         uuid NOT NULL REFERENCES public.school_groups(id) ON DELETE CASCADE,
  school_id        uuid NOT NULL REFERENCES public.schools(id)       ON DELETE CASCADE,
  -- Lien vers la vie courante — elle, elle peut évoluer. ON DELETE SET NULL :
  -- une candidature retirée ne doit PAS effacer la preuve qu'elle a été déposée.
  candidate_id     uuid REFERENCES public.exam_candidates(id) ON DELETE SET NULL,
  student_id       uuid REFERENCES public.students(id)        ON DELETE SET NULL,
  local_ref        text,
  -- Le lot : ~50 candidats, À L'INTÉRIEUR d'une classe (la filière est portée
  -- par la classe). C'est l'unité de travail de la DEC.
  lot_number       integer,
  position         integer,
  -- Nom, matricule, date de naissance, classe, filière… GELÉS à la frappe.
  payload          jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at       timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.transmissions      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transmission_items ENABLE ROW LEVEL SECURITY;

-- Garde multi-tenant standard du projet (cf. rooms, class_subjects).
CREATE POLICY transmissions_tenant ON public.transmissions
  FOR ALL
  USING (
    is_super_admin()
    OR (group_id = auth_group_id() AND (is_admin_groupe() OR school_id = auth_school_id()))
  )
  WITH CHECK (
    is_super_admin()
    OR (group_id = auth_group_id() AND (is_admin_groupe() OR school_id = auth_school_id()))
  );

CREATE POLICY transmission_items_tenant ON public.transmission_items
  FOR ALL
  USING (
    is_super_admin()
    OR (group_id = auth_group_id() AND (is_admin_groupe() OR school_id = auth_school_id()))
  )
  WITH CHECK (
    is_super_admin()
    OR (group_id = auth_group_id() AND (is_admin_groupe() OR school_id = auth_school_id()))
  );

CREATE INDEX IF NOT EXISTS idx_transmissions_school   ON public.transmissions(school_id);
CREATE INDEX IF NOT EXISTS idx_transmissions_session  ON public.transmissions(session_id);
CREATE INDEX IF NOT EXISTS idx_transmissions_group    ON public.transmissions(group_id);
CREATE INDEX IF NOT EXISTS idx_tr_items_transmission  ON public.transmission_items(transmission_id);
CREATE INDEX IF NOT EXISTS idx_tr_items_candidate     ON public.transmission_items(candidate_id);
CREATE INDEX IF NOT EXISTS idx_tr_items_school        ON public.transmission_items(school_id);

COMMENT ON TABLE public.transmissions IS
  'Dépôt OPPOSABLE à la DEC : ce que l''école a déclaré, et quand. Immuable une '
  'fois transmise (règle applicative, pas contrainte — un rejet serveur '
  'provoquerait la perte silencieuse PowerSync). Sert à la fois de feuille de '
  'frappe (saisie manuelle DEC) et de bordereau (dossiers papier).';
COMMENT ON COLUMN public.transmissions.snapshot IS
  'La liste TELLE QUE DÉPOSÉE — figée. Ne jamais recalculer depuis les données '
  'vivantes : la liste de juin ne serait plus celle de février.';
COMMENT ON COLUMN public.transmission_items.local_ref IS
  'EP-<école>-<AAAA>-<seq>. Ne revient PAS de la DEC tant que la saisie est '
  'manuelle. Coût nul aujourd''hui, clé de réconciliation exacte le jour de l''API.';

-- ── PowerSync ──────────────────────────────────────────────────────────────
-- Les transmissions sont écrites par le PERSONNEL SCOLAIRE (offline-first). La
-- publication `powersync` est `FOR ALL TABLES` : les deux tables y entrent
-- AUTOMATIQUEMENT, aucun ALTER PUBLICATION n'est nécessaire (il serait d'ailleurs
-- refusé). REPLICA IDENTITY `default` (clé primaire) suffit, comme pour les
-- autres tables synchronisées (exam_candidates, internships).
--
-- ⚠️ La REMONTÉE des écritures passe par le connecteur, indépendamment des
-- sync-rules : sans ces tables en base, une école qui « Soumet » hors ligne
-- enverrait vers une table inexistante → rejet → perte silencieuse. Cette
-- migration DOIT être appliquée avant de livrer la fonctionnalité.
-- La DESCENTE (multi-postes d'une même école) requiert en plus l'ajout des deux
-- tables au bucket by_school de sync-rules.yaml (déployé au dashboard).

COMMIT;

-- ── Vérifications ──────────────────────────────────────────────────────────
-- select tablename, policyname from pg_policies
--  where tablename in ('transmissions','transmission_items');
-- select column_name, data_type from information_schema.columns
--  where table_name='transmissions' order by ordinal_position;
