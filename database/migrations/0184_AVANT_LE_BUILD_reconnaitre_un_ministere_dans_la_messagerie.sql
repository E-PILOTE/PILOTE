-- ════════════════════════════════════════════════════════════════════════════
--  0184 — RECONNAÎTRE UN MINISTÈRE DANS LA MESSAGERIE
--
--  ── LA DEMANDE ────────────────────────────────────────────────────────────
--  « Il faut que ça se distingue des autres groupes scolaires simples, même
--    dans les messages. » Un ministère de tutelle se reconnaît partout ailleurs
--    depuis 0178-0183 : pastille pleine, icône d'institution, nom d'usage. Pas
--    dans la messagerie — et c'est précisément là que ça compte, parce qu'un
--    message d'une administration de tutelle n'a pas le même poids qu'un
--    message d'un confrère. Une circulaire déguisée en conversation ordinaire
--    se lit et se range comme une conversation ordinaire.
--
--  ── POURQUOI IL FAUT UNE FONCTION, ET PAS UNE JOINTURE ────────────────────
--  L'écran connaît l'identifiant de l'interlocuteur, jamais son GROUPE. La
--  jointure naturelle — `profiles → school_groups` — ne rend RIEN : la RLS de
--  `school_groups` borne chaque admin de groupe à SON groupe. Un directeur
--  d'école privée qui reçoit un message du MEPSA lit donc une ligne vide au
--  lieu du nom du ministère, sans la moindre erreur pour le signaler (un refus
--  de RLS en SELECT est muet : il écarte la ligne, il ne lève rien).
--
--  Élargir cette RLS serait la mauvaise réponse : elle exposerait le nom, le
--  plan, l'effectif et le tarif négocié de tous les groupes du pays à tous les
--  groupes du pays. On passe donc par une fonction SECURITY DEFINER, et on lui
--  fait rendre le MINIMUM.
--
--  ── CE QU'ELLE REND, ET CE QU'ELLE NE REND PAS ────────────────────────────
--  Elle rend UNIQUEMENT les correspondants qui appartiennent à un ministère de
--  tutelle — deux groupes sur tout le pays. Pour tous les autres, elle ne rend
--  rien : l'écran n'apprend donc RIEN sur les groupes ordinaires, pas même
--  qu'ils existent. C'est exactement l'information qui manque à l'affichage,
--  et rien de plus.
--
--  ⚠️ ET SEULEMENT DES CORRESPONDANTS. Un appelant ne peut pas énumérer les
--  agents d'un ministère : il faut avoir échangé un message avec la personne,
--  ou partager une conversation de groupe avec elle. Sans ce filtre, la
--  fonction serait un annuaire du personnel ministériel ouvert à toute la
--  plateforme.
--
--  ── ORDRE : AVANT LE BUILD ────────────────────────────────────────────────
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

CREATE OR REPLACE FUNCTION public.correspondants_ministere()
RETURNS TABLE (
  profile_id uuid,
  group_id   uuid,
  group_name text,
  tutelle    text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
  WITH moi AS (SELECT auth.uid() AS uid),
  -- Les personnes avec qui l'appelant a échangé en tête-à-tête.
  direct AS (
    SELECT CASE WHEN m.sender_id = moi.uid THEN m.recipient_id
                ELSE m.sender_id END AS pid
      FROM public.messages m
      CROSS JOIN moi
     WHERE moi.uid IS NOT NULL
       AND m.conversation_id IS NULL
       AND (m.sender_id = moi.uid OR m.recipient_id = moi.uid)
  ),
  -- Les personnes présentes dans une conversation de groupe de l'appelant.
  collectif AS (
    -- ⚠️ CROSS JOIN explicite, pas une virgule : `FROM a, moi JOIN b ON …`
    -- rattache le JOIN à `moi` et non à `a` (42P01).
    SELECT autres.user_id AS pid
      FROM public.conversation_members miens
      JOIN public.conversation_members autres
        ON autres.conversation_id = miens.conversation_id
      CROSS JOIN moi
     WHERE moi.uid IS NOT NULL
       AND miens.user_id = moi.uid
  ),
  correspondants AS (
    SELECT pid FROM direct
    UNION
    SELECT pid FROM collectif
  )
  SELECT p.id, g.id, g.name::text, g.tutelle::text
    FROM correspondants c
    JOIN public.profiles p ON p.id = c.pid
    JOIN public.school_groups g
      ON g.id = p.group_id
     AND g.administre_referentiel_national
   WHERE c.pid IS NOT NULL
     AND c.pid <> auth.uid();
$fn$;

COMMENT ON FUNCTION public.correspondants_ministere() IS
  'Parmi les correspondants de l''appelant (messages 1-a-1 + membres de ses '
  'conversations), ceux qui appartiennent a un ministere de tutelle. Rend le '
  'MINIMUM : rien sur les groupes ordinaires, et rien sur une personne avec '
  'qui l''appelant n''a jamais echange. Existe parce que la RLS de '
  'school_groups borne chaque groupe au sien — une jointure directe rendrait '
  'une ligne vide, sans erreur pour le signaler.';

REVOKE ALL ON FUNCTION public.correspondants_ministere() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.correspondants_ministere() TO authenticated;

COMMIT;
