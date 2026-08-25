---
name: mise-a-jour-du-parc
description: "Canal de mise à jour (mig 0087 app_releases) — comparaison sur build_number ENTIER, SHA-256 vérifié avant installation, CI prête à signer et inerte sans secret"
metadata: 
  node_type: memory
  type: project
  originSessionId: db933423-7daf-438d-9460-97e0abf9b86b
  modified: 2026-08-03T19:25:01.461Z
---

# Le parc peut être mis à jour (migration 0087, 2026-08-03)

Sans cela, tout défaut trouvé après le 2 octobre était **définitif** : mille
postes à revisiter. Voir [[deploiement-national-octobre]].

## Décisions

**`app_releases` ne porte que le pointeur et l'empreinte** — le binaire reste
sur les releases GitHub publiées par la CI. Pas de serveur de fichiers de plus
à maintenir et à expliquer à la DSIC.

**⚠️ La comparaison porte sur `build_number` (entier monotone), JAMAIS sur la
chaîne de version.** « 3.10.0 » < « 3.9.0 » en comparaison de texte : le jour
où ça arrive, tout le parc se croit à jour.

**⚠️ `buildInstalle == 0` (build illisible) ⇒ le provider se TAIT.** Sinon
toute version publiée paraît plus récente et l'écran réclame en boucle.

**RLS : lecture ouverte à tous (`USING (true)`)** — un poste doit apprendre
qu'il est en retard quel que soit son rôle ; un numéro de version n'est pas
confidentiel. Écriture `is_super_admin()` seulement.

**Le SHA-256 est vérifié AVANT que le fichier prenne son nom définitif**, en
flux (`AccumulatorSink` du paquet `convert` — ajouté pour ça ; 34 Mo ne se
chargent pas en mémoire sur un poste à 4 Go). Un écart **annule**, ce n'est
jamais un avertissement contournable. Fichier `.part` supprimé en cas d'échec.

**Trois règles de comportement** : silencieux en cas d'échec (hors ligne = cas
NORMAL) ; une vérification par session (`keepAlive`) ; **jamais automatique**.
La bannière se ferme pour la session — sauf `is_mandatory` / `min_build`, qui
n'est pas de l'insistance mais un avertissement d'intégrité.

⚠️ `miseAJourProvider` appelle **Supabase depuis l'espace école** : légitime,
une version publiée n'est pas une donnée d'établissement et télécharger exige
le réseau. Même raisonnement que le guichet national
([[ine-identifiant-national-eleve]]).

## Où c'est branché

- Bannière : `core/widgets/app_shell.dart`, **en dernier**, sous les bannières
  d'état — une mise à jour ne passe jamais devant un échec de synchro.
- Téléchargement : `localDataDir()/mises_a_jour/`, **jamais Documents**
  ([[base-hors-ligne-hors-documents]]).
- `CloseApplications=yes` + `RestartApplications=no` dans l'`.iss` : sur un
  poste partagé, une application qui réapparaît seule laisse une session
  ouverte à qui passe.

## Signature de code — état réel

**Le certificat n'existe pas et est à CRÉER** (user 2026-08-03 : « le Congo
n'a pas ce système, nous innovons tout »). L'étape de signature est **écrite et
inerte** : secrets `WINDOWS_CERT_PFX` (base64) + `WINDOWS_CERT_PASSWORD`. Le
jour venu, un secret à poser, aucun code à écrire.

**Plan B en vigueur** : la CI publie l'**empreinte SHA-256** et un
`manifest.json` (la ligne à insérer dans `app_releases`). L'empreinte est le
seul moyen, sans signature, de prouver qu'un installateur reçu par clé USB est
bien celui qui a été publié.

## ✅ Publier une version (2026-08-03)

`super_admin/screens/releases_screen.dart` + `release_form_dialog.dart` +
`providers/releases_provider.dart`, route `/super/versions` (section
PLATEFORME). Le formulaire **lit le `manifest.json` collé** et remplit les
champs : une empreinte SHA-256 retapée est fausse une fois sur deux, et un
poste qui refuse l'installation laisse une école bloquée sans comprendre.

`ControleRelease.verifier()` refuse AVANT l'envoi (12 tests) :
- build **non entier / ≤ 0 / égal / INFÉRIEUR** au dernier de la même
  `(platform, channel)` → la comparaison poste étant entière, un build qui
  recule rend la correction invisible pour tout le parc, en silence ;
- SHA-256 ≠ 64 hexa (majuscules acceptées, on minuscule) ;
- URL non `https://` ;
- `min_build > build publié` → postes sommés de passer à une version
  inexistante.

⚠️ Le retrait d'une version **ne désinstalle rien** — la modale le dit :
« pour corriger, publiez un build supérieur ».

⚠️ `derniere_version()` renvoie un **enregistrement NULL** (pas 0 ligne) quand
rien ne correspond — vérifié ; le garde `row is! Map` côté Dart tient.

Reste : canal `beta` inutilisé.

Liens : [[chaine-livraison-windows]] · [[deploiement-national-octobre]] ·
[[plateformes-cibles-windows-mac]]
