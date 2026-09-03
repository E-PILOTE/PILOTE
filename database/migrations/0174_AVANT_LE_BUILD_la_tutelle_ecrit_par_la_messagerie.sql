-- ════════════════════════════════════════════════════════════════════════════
--  0174 — LA TUTELLE ÉCRIT PAR LA MESSAGERIE, PAS PAR UN QUATRIÈME CANAL
--
--  ── CE QUE CETTE MIGRATION REMPLACE ───────────────────────────────────────
--  La circulaire de tutelle (0161/0167) ajoutait un canal de communication à
--  côté des annonces, de la messagerie et des tickets — avec ses écrans, son
--  vocabulaire et son entrée de menu. Elle n'a jamais servi : `circulaires` et
--  `circulaire_destinataires` comptent ZÉRO ligne en production.
--
--  Décision du 2026-09-02 : un ministère qui veut écrire à un groupe qu'il
--  supervise le sélectionne dans « Réseau sous tutelle » et lui envoie un
--  MESSAGE — au groupe, et/ou aux chefs des établissements qu'il choisit.
--
--  ── ⚠️ POURQUOI UNE FONCTION SUFFIT, ET POURQUOI IL EN FAUT UNE ───────────
--  Tout le reste marchait déjà, vérifié politique par politique :
--   • `msg_insert` accepte l'insertion dès lors que `group_id = auth_group_id()`
--     et `sender_id = auth.uid()` — le ministère écrit depuis SON groupe ;
--   • `msg_select` rend le message à `recipient_id = auth.uid()`, SANS
--     condition de groupe : le destinataire le lit, même dans un autre groupe ;
--   • `sendMessageToMany` écrit déjà une ligne par destinataire.
--
--  Le seul mur est `profiles_select`, qui borne un `admin_groupe` aux profils
--  de SON groupe. Le ministère ne peut donc pas DÉSIGNER ses correspondants.
--  C'est exactement le mur qui avait rendu `tutelle_ecoles` nécessaire en 0158,
--  et il se franchit de la même façon : une fonction `SECURITY DEFINER`, qui
--  décide en un endroit lisible ce qui sort.
--
--  ── ⚠️ LE CHEF SE RECONNAÎT À SON RÔLE, PAS À `schools.director_id` ───────
--  Mesuré le 2026-09-03 : `director_id` est NULL sur les ONZE écoles placées
--  sous la tutelle du MEPSA hors ministère — et pourtant chacune a exactement
--  UN chef actif, rattaché par `profiles.school_id` avec le rôle `directeur`
--  ou `proviseur`. La colonne n'est pas tenue ; les personnes existent.
--
--  `tutelle_ecoles` (0158) lit `director_id` : sa colonne « chef
--  d'établissement » est donc vide en pratique. Ce défaut lui appartient et
--  n'est PAS corrigé ici — le corriger changerait ce qu'affichent des écrans
--  et des PDF déjà livrés. Cette fonction-ci, elle, résout par le RÔLE : sinon
--  elle ne rendrait aucun destinataire, et la sélection serait toujours vide.
--
--  ── ⚠️ CE QU'ELLE REND, ET RIEN DE PLUS ──────────────────────────────────
--  De quoi ADRESSER un message : un identifiant, un nom, la fonction occupée,
--  et l'établissement concerné. Pas de courriel, pas de numéro, pas de liste
--  du personnel, aucune donnée d'élève.
--
--  ── ⚠️ DEUX GARDES, ET LES DEUX SONT NÉCESSAIRES ─────────────────────────
--  `auth_peut_superviser()` dit qu'on est un ministère ; il ne dit PAS que le
--  groupe passé en argument nous concerne. Sans le second contrôle, un
--  ministère obtiendrait les correspondants de n'importe quel groupe du pays
--  en devinant un UUID.
--
--  ── ORDRE : AVANT LE BUILD. Additive, aucune donnée touchée. ──────────────
-- ════════════════════════════════════════════════════════════════════════════

DROP FUNCTION IF EXISTS public.tutelle_interlocuteur(uuid);

CREATE OR REPLACE FUNCTION public.tutelle_destinataires(p_group_id uuid)
RETURNS TABLE (
  user_id   uuid,
  nom       text,
  fonction  text,
  school_id uuid,
  ecole     text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE v_tutelle public.tutelle_enum;
BEGIN
  IF p_group_id IS NULL THEN
    RAISE EXCEPTION 'Groupe non specifie';
  END IF;

  -- Garde 1 : suis-je une tutelle ?
  IF NOT public.auth_peut_superviser() THEN
    RAISE EXCEPTION 'Reserve a la tutelle' USING ERRCODE = '42501';
  END IF;

  -- Le super_admin n'a pas de groupe, donc pas de tutelle : il voit tout.
  v_tutelle := CASE WHEN public.is_super_admin()
                    THEN NULL ELSE public.auth_group_tutelle() END;

  -- Garde 2 : CE groupe est-il sous MA tutelle ? Sans elle, un UUID deviné
  -- rendrait les correspondants de n'importe quel groupe scolaire du pays.
  IF NOT EXISTS (
    SELECT 1 FROM public.schools s
     WHERE s.group_id = p_group_id
       AND (v_tutelle IS NULL OR s.tutelle = v_tutelle)
  ) THEN
    RAISE EXCEPTION 'Ce groupe n''est pas place sous votre tutelle'
      USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  -- L'administrateur du groupe : l'interlocuteur de la personne morale.
  -- `school_id` NULL le distingue d'un chef d'établissement.
  SELECT p.id,
         nullif(trim(coalesce(p.first_name, '') || ' ' ||
                     coalesce(p.last_name, '')), '')::text,
         'Administrateur du groupe'::text,
         NULL::uuid,
         NULL::text
    FROM public.profiles p
   WHERE p.group_id = p_group_id
     AND p.role = 'admin_groupe'
     AND p.is_active

  UNION ALL

  -- Les chefs des établissements de ce groupe placés sous MA tutelle.
  --
  -- ⚠️ Le filtre de tutelle est répété ici : un groupe pourrait un jour tenir
  -- des écoles sous deux ministères, et le ministère A n'a pas à écrire aux
  -- chefs des écoles du ministère B.
  SELECT p.id,
         nullif(trim(coalesce(p.first_name, '') || ' ' ||
                     coalesce(p.last_name, '')), '')::text,
         CASE p.role WHEN 'proviseur' THEN 'Proviseur'
                     ELSE 'Directeur' END::text,
         s.id,
         s.name::text
    FROM public.profiles p
    JOIN public.schools s ON s.id = p.school_id
   WHERE s.group_id = p_group_id
     AND (v_tutelle IS NULL OR s.tutelle = v_tutelle)
     AND s.is_active
     AND p.is_active
     AND p.role IN ('directeur', 'proviseur')
   ORDER BY 4 NULLS FIRST, 5, 2;
END;
$fn$;

COMMENT ON FUNCTION public.tutelle_destinataires(uuid) IS
  'A qui une tutelle peut ecrire dans un groupe scolaire qu''elle supervise : l''administrateur du groupe, et le chef de chaque etablissement. Rend de quoi ADRESSER un message (id, nom, fonction, ecole), rien d''autre. Le chef se reconnait a son ROLE : schools.director_id n''est pas tenu.';

REVOKE ALL ON FUNCTION public.tutelle_destinataires(uuid) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.tutelle_destinataires(uuid) TO authenticated;
