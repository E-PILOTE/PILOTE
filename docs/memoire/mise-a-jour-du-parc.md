---
name: mise-a-jour-du-parc
description: "Canal de mise à jour (mig 0087 app_releases) — comparaison sur build_number ENTIER, SHA-256 vérifié avant installation, CI prête à signer et inerte sans secret — canal ouvert le 2026-08-25 (v3.3.0 / build 20)"
metadata: 
  node_type: memory
  type: project
  originSessionId: db933423-7daf-438d-9460-97e0abf9b86b
  modified: 2026-08-25T11:45:00.000Z
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

## ✅ Le canal a servi pour la première fois — v3.3.0 / build 20 (2026-08-25)

`app_releases` était **vide** : le mécanisme entier n'avait jamais été exercé
de bout en bout. La première ligne a été écrite ce jour depuis le
`manifest.json` de la CI (run 32813066795), non par le formulaire.

| | |
|---|---|
| `platform` / `channel` | `windows` / `stable` — **le poste code `p_channel: 'stable'` en dur**, publier en `beta` serait invisible |
| `is_mandatory` | `false` |
| `min_build` | `null` |
| empreinte | vérifiée en retéléchargeant l'installateur publié : identique au manifeste, 35 769 649 o |
| `created_by` | `super@admin.cg` (compte plateforme) |

Vérifié via la RPC : `windows/stable` répond, **`linux`, `macos` et `beta` ne
répondent rien** — le cloisonnement par plateforme tient.

### ⚠️ Ce qui a rendu la décision facile : le parc n'est pas ce qu'on croit

**10 comptes se sont connectés une seule fois** (dernier : 2026-08-19), pour
37 écoles provisionnées et 344 profils. Aucun établissement n'exploite encore
l'application. Publier n'était donc PAS « un déploiement en établissement » —
la réserve des notes de version sur l'installateur non signé ne s'y appliquait
pas. Et découvrir en octobre, sur mille postes, que le canal ne fonctionne pas
aurait été le pire moment possible pour l'apprendre.

⚠️ **Ce raisonnement expire.** Dès qu'une école exploite réellement
l'application, publier redevient un acte de déploiement, et le certificat de
signature redevient bloquant.

⚠️ **`notes` EST affiché** — `update_dialog.dart:125-139`, encadré déroulant
(max 190 px), pas dans la bannière qui reste volontairement compacte. Ce champ
s'adresse donc à **l'agent qui met à jour**, jamais à l'opérateur : y consigner
un numéro de run ou un motif de correctif le donne à lire à tout le parc.
(Erreur commise le 2026-08-25 : j'avais grepé `update_banner.dart` et le
provider, pas la modale, et écrit du bavardage interne dans la ligne du build
20. Réécrit le jour même.)

### 🩸 Le premier clic a rendu 404 — le binaire vivait dans un dépôt PRIVÉ

`download_url` pointait sur les releases de `E-PILOTE/PILOTE`, **privé**. Leurs
pièces jointes exigent une authentification ; l'application télécharge par un GET
**anonyme**. Corrigé le jour même : le binaire est passé sur le dépôt public
`E-PILOTE/telechargements`, **empreinte inchangée** — seule l'adresse bouge, donc
la ligne se corrige EN PLACE, sans publier un build supérieur.

⚠️ **`app_releases.download_url` doit répondre 200 SANS authentification.** Le
vérifier depuis un poste connecté ne prouve rien. Voir le garde de recette dans
[[chaine-livraison-windows]].

### ✅ `ControleRelease.verifierAdresse()` — le HEAD anonyme (même jour)

Les douze contrôles de `verifier()` ne lisent que du TEXTE : aucun ne pouvait
voir un 404. `verifierAdresse()` est asynchrone et séparée pour cela, appelée
par `release_form_dialog.dart` **avant la moindre écriture**.

- **Client `http` NU**, jamais celui de Supabase — il porte un jeton, et s'en
  servir rejouerait le défaut par son propre remède. Un test vérifie l'absence
  de `authorization` / `cookie` / `apikey` / `x-client-info` sur la requête.
- **401/403** → message nommant l'authentification et demandant si le dépôt est
  public. **Tout autre non-200** → « exactement ce que recevrait chaque poste ».
- **`content-length` ≠ `size_bytes`** → refus : l'adresse ne désigne pas le
  fichier déclaré, écart qui ne se verrait sinon qu'à l'empreinte, sur chaque
  poste, après 35 Mo téléchargés pour rien.
- **405/501** → l'hébergeur refuse HEAD : réessai en GET d'un seul octet
  (`Range: bytes=0-0`). Un refus de méthode ne dit rien du fichier.
- ⚠️ **Réseau muet ou délai dépassé ⇒ REFUS**, pas laissez-passer. Publier une
  version qu'on n'a pas pu joindre EST la faute qu'on corrige. **Aucun bouton
  « publier quand même »** : il servirait dès la première journée pressée et
  personne ne saurait qu'il a servi.

10 tests (`MockClient`) — 22 au total dans `release_publication_test.dart`.

## 🩸 ONZE VERSIONS N'ONT JAMAIS ATTEINT LE PARC (constaté le 2026-09-05)

`app_releases` s'arrêtait au **build 27 (3.4.3, publié le 1er septembre)**.
Entre-temps, **3.5.0 → 3.5.14, builds 28 à 48**, ont été compilés, installés à
la main sur le poste de développement, et **jamais publiés**. Pendant onze
versions, tout poste demandant « existe-t-il une correction ? » s'est entendu
répondre « vous êtes à jour ».

Rien n'était cassé : la bannière, la vérification d'empreinte, le formulaire et
ses vingt-deux contrôles, le relevé du parc — tout fonctionnait. **Publier est
une étape HUMAINE qui suit la compilation, et rien ne comparait les deux.**
`ParcSection` dit ce que le parc exécute ; la liste dit ce qui est publié ;
personne ne disait ce que la machine d'en face vient de compiler. L'écart
n'avait de domicile ni dans une ligne, ni dans un écran, ni dans un test.

C'est le défaut des `catch (_) {}` déplacé d'un cran : **le silence d'un
manquement le rend invisible, pas inoffensif.**

### ✅ `VersionNonPubliee` — l'écart a désormais un domicile

`super_admin/widgets/version_non_publiee.dart`, **en tête** de `/super/versions`
(avant l'avertissement : le reste de la page explique comment publier, cet
encart signale qu'on ne l'a pas fait). Il compare le build de l'application
**qui affiche l'écran** au plus haut build publié pour la même plateforme.

- ⚠️ **`stable` en dur** : un build publié en `beta` est invisible pour les
  postes, il ne comble donc pas l'écart. Idem pour une autre plateforme.
- ⚠️ **build `0` ⇒ silence**, même règle que `miseAJourProvider`.
- ⚠️ **Il ne parle que de la machine où il s'affiche** — d'où « depuis ce
  poste ». Un super_admin sur un poste ancien verrait sinon un écart de
  livraison qui n'existe pas. Un poste EN RETARD ne déclenche rien.
- Table vide ⇒ « aucun », jamais « 0 » (qui se lirait comme un build zéro).

8 tests : `test/compiler_nest_pas_publier_test.dart`.

⚠️ **Ce que l'encart NE fait pas** : publier. L'étape reste humaine et le
restera — la publication s'adresse à tout le parc, elle ne doit pas être un
effet de bord d'une compilation.

### ✅ CANAL RÉOUVERT — 3.5.15 / build 49 (2026-09-06)

Publié à la demande explicite du fondateur. Écart comblé : 22 builds.

| | |
|---|---|
| tag / dépôt | `v3.5.15` sur `E-PILOTE/telechargements` (**PUBLIC**) |
| empreinte | `e721f450…5a1f257e` — 36 091 527 o |
| `is_mandatory` / `min_build` | `false` / `null` |
| `created_by` | Super Admin `9e706bea…` |

**Six vérifications, dans l'ordre où un poste les subit :**

1. `manifest.json` ⟷ fichier local : empreinte et taille identiques ;
2. **HEAD anonyme** sur `download_url` → 200, `content-length` = 36 091 527 ;
3. **téléchargement anonyme intégral, puis SHA-256 des octets reçus** →
   identique à la valeur déclarée. C'est le contrôle que les douze règles
   textuelles de `ControleRelease.verifier()` ne peuvent pas faire ;
4. `derniere_version('windows','stable')` → la ligne ; `linux`, `macos` et
   `beta` → **NULL**. Le cloisonnement tient ;
5. `has_function_privilege` : `anon` ET `authenticated` ont EXECUTE — un poste
   à session expirée doit pouvoir apprendre qu'un correctif existe ;
6. **appel HTTP réel avec la seule clé anon**, sans session → 200 et charge
   utile complète. C'est littéralement ce que fait `miseAJourProvider`.

⚠️ **Ce que la publication ne prouve PAS** : le chemin
téléchargement → vérification → lancement de `UpdateInstaller` n'a jamais été
parcouru de bout en bout sur un vrai poste. Il faudrait un poste en retard.

### ✅ 3.5.17 / build 51 publiée (2026-09-06, 20 h 35 UTC)

Deuxième publication du canal depuis sa réouverture. Mêmes six vérifications
que pour la 3.5.15, toutes passées : manifeste ⟷ fichier, HEAD anonyme 200 avec
`content-length` exact, **téléchargement anonyme intégral puis SHA-256 des
octets reçus** (`02a9e0ae…40e02dc1`, identique), RPC `derniere_version` rendant
la ligne, cloisonnement plateforme/canal, et appel HTTP réel avec la seule clé
anon → 200.

Contenu : les écrans d'administration cessent d'attendre en file (niveau 3) et
gardent leurs données au chaud (niveau 1). Aucun chiffre modifié.

⚠️ **Rythme à surveiller.** Trois versions publiées le même jour (3.5.15,
puis 3.5.17). Tant que le parc est composé des comptes de démonstration du
fondateur, c'est sans conséquence. **Dès les cinq premières écoles réelles,
publier redevient un acte de déploiement** : une version par correctif avéré,
pas une par séance de travail.

### ✅ `le_ruban_sait_apparaitre_test.dart` — la bannière est enfin exécutée

`update_provider_test.dart` couvrait la DÉCISION (16 tests) ; **personne
n'avait jamais fait s'afficher la bannière**. Le seul écran par lequel une
correction atteint mille postes n'était vérifié qu'en arithmétique — même
lacune que le dialogue de code PIN, refermée la veille.

6 tests, **avec les valeurs réellement publiées** (3.5.15/49, empreinte et
adresse comprises) : un poste en retard voit le ruban et y lit sa propre
version ; un poste à jour ne voit rien ; hors ligne, aucune alerte ;
« Plus tard » referme pour la session ; `is_mandatory` **et** `min_build`
retirent le bouton « Plus tard ».

### 📡 Le parc au moment de la publication

`app_installations` : **6 profils**, du build 27 au 49. Le poste du fondateur
a signalé le 49 huit minutes après la publication — la boucle
« se signaler / apprendre » tourne. **Les cinq autres sont désormais en
retard** et verront le ruban à leur prochaine ouverture. C'est la première
fois que le canal a quelqu'un à qui parler.

### ⚠️ L'installation locale n'a rien à voir avec ce canal

Le refus rencontré ce jour-là (« L'opération a été annulée par l'utilisateur »,
quatre fois) n'est PAS un défaut du produit : `epilote.iss` porte
`PrivilegesRequired=admin` + `DefaultDirName={autopf}` → Windows demande
l'élévation (UAC), et **ce dialogue est dessiné sur le bureau sécurisé, hors
d'atteinte de toute automatisation**, par construction. Lancé sans personne
devant l'écran, il expire ou est écarté.

⚠️ **La bannière intégrée aboutit au MÊME dialogue** — `UpdateInstaller.lancer`
démarre l'installateur, qui demande l'élévation. La différence n'est pas
technique : l'agent est devant son poste, il vient de cliquer « Installer », il
attend la question. **Question ouverte pour le déploiement national** : un
enseignant sans droits d'administrateur ne pourra jamais appliquer une
correction par ce chemin. `PrivilegesRequired=lowest` (installation par
utilisateur, sans UAC) est l'alternative — au prix d'un changement d'emplacement
et du risque de deux copies par poste. **À trancher avec la DSIC, pas seul.**

Liens : [[chaine-livraison-windows]] · [[deploiement-national-octobre]] ·
[[plateformes-cibles-windows-mac]]
