-- ════════════════════════════════════════════════════════════════════════════
--  0114 — ENCAISSER EST UN DROIT, PAS UNE APPARTENANCE À L'ÉCOLE
--
--  ── CE QUI ÉTAIT OUVERT ────────────────────────────────────────────────────
--  `payments_tenant` était une policy `FOR ALL` dont le prédicat se résumait à
--  « même groupe, même école ». Tout compte authentifié rattaché à
--  l'établissement pouvait donc LIRE, MODIFIER et SUPPRIMER n'importe quel
--  versement — par un simple appel PostgREST, sans passer par l'application.
--
--  Vérifié en production, transaction annulée, avec le compte d'un ENSEIGNANT
--  (sync_finance = false, sans le module Paiements) :
--      LECTURE  student_payments : 1 ligne
--      ECRITURE student_payments : 1 ligne MODIFIÉE
--      SUPPRESSION              : 1 ligne
--  276 comptes étaient dans ce cas : 202 enseignants, 37 surveillants,
--  37 secrétaires.
--
--  ── POURQUOI PAS `auth_sync_finance()`, QUI GARDE DÉJÀ expenses/budget ─────
--  Parce que ce drapeau se calcule depuis d'AUTRES modules :
--  `depenses, budget, personnel, presences-personnel, conges, paie`.
--  `paiements-eleves` n'y figure pas. Une école qui confierait la seule caisse
--  à un agent verrait ses écritures refusées en `42501` — code que le
--  connecteur PowerSync tient pour FATAL, qui fait abandonner la transaction
--  ENTIÈRE : les notes et les présences saisies dans la même fenêtre
--  partiraient avec l'encaissement.
--
--  ── ET POURQUOI LA LECTURE N'EST PAS RESSERRÉE ─────────────────────────────
--  Elle le mériterait, mais elle ne le peut pas aujourd'hui : la carte des
--  frais d'une INSCRIPTION lit le décompte de l'élève, et **tous** les profils
--  détiennent `inscriptions` — enseignant et vie scolaire compris. Gater la
--  lecture sur le module casserait l'inscription pour tout le monde.
--  Le périmètre par classe qui rendrait cela juste vit dans l'application
--  (verrou 4), pas dans la RLS. C'est une dette, elle est nommée ici.
--
--  Ce qui change donc : ÉCRIRE devient un droit qui s'accorde, et cesse d'être
--  une conséquence de la présence dans l'établissement.
-- ════════════════════════════════════════════════════════════════════════════

-- ── Le droit d'agir sur un module, lu depuis le profil d'accès ──────────────
-- `STABLE` + `SECURITY DEFINER` comme les autres helpers RLS du projet ; les
-- policies l'enveloppent dans un `(SELECT …)` pour qu'il soit évalué une fois
-- par requête et non une fois par ligne.
CREATE OR REPLACE FUNCTION public.auth_module_permet(p_slug text, p_action text)
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT EXISTS (
    SELECT 1
      FROM profiles pr
      JOIN profile_permissions pp ON pp.profile_id = pr.access_profile_id
      JOIN modules m              ON m.id = pp.module_id
     WHERE pr.id = auth.uid()
       AND m.slug = p_slug
       AND CASE p_action
             WHEN 'create' THEN pp.can_create
             WHEN 'update' THEN pp.can_update
             WHEN 'delete' THEN pp.can_delete
             ELSE pp.can_read
           END
  );
$$;

COMMENT ON FUNCTION public.auth_module_permet(text, text) IS
  'Le profil d''accès du compte courant accorde-t-il cette action sur ce module ? '
  'Sert la RLS là où « appartenir à l''école » ne suffit pas à autoriser un geste.';

-- ── La policy unique éclate en quatre ───────────────────────────────────────
DROP POLICY IF EXISTS payments_tenant ON public.student_payments;

-- LECTURE : inchangée. Voir l'en-tête — l'inscription en dépend.
CREATE POLICY payments_select ON public.student_payments
  FOR SELECT USING (
    group_id = (SELECT auth_group_id())
    AND ((SELECT is_admin_groupe()) OR school_id = (SELECT auth_school_id()))
  );

-- ÉCRITURES : le module `paiements-eleves` doit accorder l'action.
-- `is_admin_groupe()` reste une porte : ces comptes n'ont pas de profil
-- d'accès d'établissement, et le leur refuser les enfermerait dehors.
CREATE POLICY payments_insert ON public.student_payments
  FOR INSERT WITH CHECK (
    group_id = (SELECT auth_group_id())
    AND ((SELECT is_admin_groupe())
         OR (school_id = (SELECT auth_school_id())
             AND (SELECT auth_module_permet('paiements-eleves', 'create'))))
  );

CREATE POLICY payments_update ON public.student_payments
  FOR UPDATE USING (
    group_id = (SELECT auth_group_id())
    AND ((SELECT is_admin_groupe())
         OR (school_id = (SELECT auth_school_id())
             AND (SELECT auth_module_permet('paiements-eleves', 'update'))))
  ) WITH CHECK (
    group_id = (SELECT auth_group_id())
    AND ((SELECT is_admin_groupe()) OR school_id = (SELECT auth_school_id()))
  );

-- ⚠️ L'application ne SUPPRIME jamais un versement : elle l'annule
-- (`cancelPayment`), pour que la trace reste. Le profil Comptabilité n'a
-- d'ailleurs pas `can_delete`. Cette policy existe donc pour fermer la porte,
-- pas pour en ouvrir une.
CREATE POLICY payments_delete ON public.student_payments
  FOR DELETE USING (
    group_id = (SELECT auth_group_id())
    AND ((SELECT is_admin_groupe())
         OR (school_id = (SELECT auth_school_id())
             AND (SELECT auth_module_permet('paiements-eleves', 'delete'))))
  );
