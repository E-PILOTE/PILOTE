-- ════════════════════════════════════════════════════════════════════════════
--  « DERNIÈRE CONNEXION : JAMAIS » — sur 345 profils, y compris le vôtre
--
--  ── CE QUI A ÉTÉ VU À L'ÉCRAN (2026-09-04) ─────────────────────────────────
--  La nouvelle page « Mon profil » affichait « Dernière connexion : Jamais »
--  pour un compte ouvert deux heures plus tôt. Relevé en base : 345 lignes
--  dans `profiles`, **ZÉRO `last_login` renseigné**, alors que 13 comptes ont
--  réellement ouvert une session (`auth.users.last_sign_in_at`).
--
--  La colonne est LUE à quatre endroits — « Mon profil », le panneau
--  « Connexions récentes » des paramètres admin_groupe, l'annuaire du
--  personnel, les paramètres du personnel — et ÉCRITE nulle part dans
--  l'application. Le panneau du fondateur est donc vide depuis toujours, sans
--  que rien ne le signale : il ressemble à « personne ne s'est connecté ».
--
--  C'est la même famille de défaut que la carte « Sécurité » faite de
--  constantes, corrigée le même jour : un champ qui a l'air d'être une
--  information, et qui n'en est pas une.
--
--  ── POURQUOI EN BASE, ET PAS DANS L'APPLICATION ────────────────────────────
--  La vérité EXISTE déjà : Supabase tient `auth.users.last_sign_in_at`. La
--  recopier depuis l'application demanderait une écriture de plus à chaque
--  connexion, sur un chemin — celui du personnel scolaire — qui n'écrit jamais
--  en direct vers Supabase, et ne corrigerait que les postes mis à jour. Un
--  déclencheur la reflète pour tout le monde, y compris pour les connexions
--  déjà passées.
--
--  ── ⚠️ CE DÉCLENCHEUR NE DOIT JAMAIS LEVER ─────────────────────────────────
--  Il est posé sur `auth.users` : une exception ici ferait échouer la
--  CONNEXION elle-même, pour tout le parc. D'où le bloc `EXCEPTION WHEN
--  OTHERS` qui avale tout. Une date de dernière connexion manquante est un
--  désagrément ; un parc qui ne peut plus se connecter est un arrêt de service.
--  Le rapport entre les deux ne se discute pas.
--
--  ── CE QUE ÇA REND POSSIBLE ────────────────────────────────────────────────
--  « Quelqu'un s'est-il connecté avec mon compte ? » devient une question à
--  laquelle la page de profil répond. Sur un poste partagé, c'est la seule
--  vérification qu'un agent peut faire lui-même.
-- ════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.suivre_derniere_connexion()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
begin
  if new.last_sign_in_at is distinct from old.last_sign_in_at
     and new.last_sign_in_at is not null then
    begin
      update public.profiles
         set last_login = new.last_sign_in_at
       where id = new.id;
    exception when others then
      -- Voir l'en-tête : lever ici casserait la connexion de tout le monde.
      null;
    end;
  end if;
  return new;
end;
$function$;

DROP TRIGGER IF EXISTS trg_suivre_derniere_connexion ON auth.users;
CREATE TRIGGER trg_suivre_derniere_connexion
AFTER UPDATE OF last_sign_in_at ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.suivre_derniere_connexion();

-- Les connexions déjà survenues : l'écran cesse de dire « Jamais » à des gens
-- qui se connectent depuis des mois. 13 lignes au moment de la migration.
UPDATE public.profiles p
   SET last_login = u.last_sign_in_at
  FROM auth.users u
 WHERE u.id = p.id
   AND u.last_sign_in_at IS NOT NULL
   AND p.last_login IS DISTINCT FROM u.last_sign_in_at;

REVOKE EXECUTE ON FUNCTION public.suivre_derniere_connexion()
  FROM PUBLIC, anon, authenticated;
