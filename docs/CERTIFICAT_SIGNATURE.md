# Certificat de signature de code — dossier de décision

> Établi le 2026-09-01. À quatre semaines du déploiement national.
> Ce document ne se substitue pas à l'achat : seul le titulaire de
> l'organisation peut fournir les pièces légales et le moyen de paiement.

## ⚠️ D'abord : en avons-nous vraiment besoin ?

**La première version de ce dossier disait « indispensable ». C'était trop
fort.** Mesuré le 2026-09-01 : l'avertissement bleu de SmartScreen ne dépend
pas du fichier, il dépend du **chemin par lequel il arrive sur le poste**.

Windows n'affiche « Windows a protégé votre ordinateur » que si le fichier
porte un **Mark-of-the-Web** — une marque qu'un NAVIGATEUR ajoute au
téléchargement. Elle ne survit pas à une copie sur un système de fichiers FAT32
ou exFAT, et n'est jamais posée par un programme qui écrit un fichier
lui-même.

| chemin d'arrivée | marque | ce que l'école voit |
|---|---|---|
| téléchargement depuis un **navigateur** | oui | **grand bandeau bleu**, deux clics dont un caché derrière « Informations complémentaires » |
| copie depuis une **clé USB** | **non** | rien de plus que l'invite UAC habituelle, ligne « Éditeur inconnu » |
| **mise à jour par l'application** | **non** — vérifié | idem UAC |

⚠️ **Vérification faite, pas déduite** : ni l'installateur construit localement,
ni celui retéléchargé par `curl` lors de la recette anonyme ne portaient de
Zone.Identifier. L'updater de l'application procède de la même façon
(`http.Request` + écriture de fichier), donc **une mise à jour ne déclenchera
jamais SmartScreen**. Le certificat ne concerne que la PREMIÈRE installation.

### Ce qui reste vrai sans certificat

- L'invite d'élévation UAC affiche **« Éditeur inconnu »** en orange. Plus
  discret que le bandeau bleu, mais présent à chaque installation.
- Un binaire non signé est **plus exposé aux faux positifs antivirus**. Risque
  réel et imprévisible à mille postes.
- Un ministère déployant nationalement un logiciel d'« éditeur inconnu » : ce
  n'est plus un argument technique, c'est un argument de crédibilité.

### Donc : nécessaire quand ?

> **La question à trancher n'est pas « faut-il un certificat ? » mais
> « comment l'installateur arrive-t-il dans les écoles ? ».** La seconde
> réponse détermine la première.

- **Déploiement par vagues, techniciens, clés USB** — ce que suppose déjà un
  pays à connectivité faible : le certificat devient un confort, pas un
  prérequis. On peut déployer sans, et l'acheter plus tard, calmement.
- **Les écoles téléchargent elles-mêmes depuis un lien** : là, le bandeau bleu
  frappe chaque établissement, et le certificat redevient nécessaire.

⚠️ **Ne pas engager les frais avant cette décision.** La lettre d'opinion
légale se paie, et la validation se refait tous les quinze mois (voir plus
bas) : ce sont des coûts récurrents pour un problème qui n'existe que sur un
seul des trois chemins.

⚠️ **Et le pilote n'en a pas besoin** : deux écoles installées par un
technicien, c'est le chemin USB. Ne pas attendre le certificat pour commencer.

## Si la décision est « oui » : le délai est le vrai sujet

Le délai d'obtention est **incompressible** — validation de l'organisation par
l'autorité de certification. C'est la seule tâche du projet qui ne s'accélère
pas en y mettant plus de travail.

## ⚠️ Ce qui invalide le plan écrit dans la CI

`.github/workflows/windows.yml` attendait deux secrets — `WINDOWS_CERT_PFX`
(base64 d'un `.pfx`) et `WINDOWS_CERT_PASSWORD` — et son commentaire promettait :
« le jour où le certificat arrive, il n'y a qu'un secret à poser, aucun code à
écrire ».

**Cette promesse ne pouvait pas être tenue.**

> Depuis le **1er juin 2023**, les exigences du CA/Browser Forum imposent que la
> clé privée d'un certificat de signature de code vive sur du matériel certifié
> **FIPS 140-2 niveau 2**, **Common Criteria EAL 4+** ou équivalent. Un
> certificat émis aujourd'hui **n'est pas exportable en `.pfx`**.

Il n'existe donc aucun fichier à mettre dans un secret GitHub.

✅ **L'étape a été réécrite le 2026-09-01** pour un HSM infonuagique. Elle est
désormais en deux temps, et **inerte tant que les secrets sont absents** :

| | |
|---|---|
| 1/2 — *préparer et signer l'application* | installe le client, importe le certificat **public** dans le magasin Windows, vérifie que l'empreinte y est, signe `E-PILOTE.exe` **avant l'empaquetage** |
| 2/2 — *signer l'installateur* | réutilise la même empreinte, signe et **vérifie** chaque `.exe` de `dist/` |

⚠️ **Les deux binaires sont signés, pas seulement l'installateur.** Windows
vérifie l'enveloppe qu'on double-clique *et* l'exécutable qu'elle dépose : ne
signer que la première laisserait « éditeur inconnu » au premier lancement de
l'application — juste après avoir rassuré l'école.

⚠️ **Chaque signature est VÉRIFIÉE** (`signtool verify /pa`). Une étape qui
signe sans contrôler peut publier un binaire non signé en silence, et c'est
l'école qui le découvrirait.

### Les cinq secrets à poser

| secret | ce que c'est |
|---|---|
| `SM_API_KEY` | clé d'API du service de signature |
| `SM_CLIENT_CERT_B64` | certificat d'authentification client, en base64 |
| `SM_CLIENT_CERT_PASSWORD` | son mot de passe |
| `SM_HOST` | l'hôte du service |
| `SM_CERT_THUMBPRINT` | empreinte du certificat de signature |

⚠️ **Où changer de fournisseur** : seul le bloc « préparer » de l'étape 1/2 est
spécifique à DigiCert KeyLocker. La signature passe par `signtool /sha1`,
identique pour SSL.com eSigner (via son CKA), pour tout autre KSP, ou pour un
jeton physique sur un runner auto-hébergé. Changer = réécrire une dizaine de
lignes, pas l'étape.

⚠️ **Non éprouvée contre un vrai compte** — écrite sans certificat en main.
C'est précisément pourquoi elle lève à la moindre anomalie et vérifie ce
qu'elle vient de signer : le premier essai réel dira si le raccord tient, et il
le dira bruyamment.

## Les trois voies, et ce qu'elles coûtent vraiment

| | signature en CI | réputation SmartScreen | contrainte |
|---|---|---|---|
| **Jeton USB physique** (OV ou EV) | ❌ impossible sans machine porteuse | OV : à construire · EV : immédiate | toute publication devient manuelle, sur UN poste |
| **HSM infonuagique** — DigiCert KeyLocker, SSL.com eSigner | ✅ par API/identifiants | idem | dépend de la validation de l'organisation |
| **Azure Artifact Signing** | ✅ natif | immédiate | ⛔ **indisponible en République du Congo** |

⚠️ **Azure est écarté, et c'était l'option la moins chère** (≈ 10 $/mois). Sa
liste de disponibilité publiée couvre les États-Unis, le Canada, l'UE, le
Royaume-Uni, l'Australie, la Nouvelle-Zélande, le Japon, la Corée, Singapour,
la Suisse, la Norvège et Israël. Le Congo n'y figure pas.

## ⚠️ OV ou EV — le point qui décide, à quatre semaines

- **EV** : réputation SmartScreen **immédiate**. L'avertissement disparaît dès
  la première installation.
- **OV** : la réputation se **construit** avec le nombre d'installations et le
  temps. Un certificat OV obtenu fin septembre laisserait donc l'avertissement
  visible pendant les premières vagues — c'est-à-dire exactement au moment où
  mille écoles découvrent le produit.

**Pour un déploiement le 1er-2 octobre, OV ne résout pas le problème à temps.**
La recommandation est **EV, via un HSM infonuagique**, engagé immédiatement.

## Où l'acheter — les quatre qui font EV + signature infonuagique

Relevé le 2026-09-01. Les prix bougent ; l'ordre de grandeur, non.

| fournisseur | EV, par an | service de signature | remarque |
|---|---|---|---|
| **SSL.com** | ≈ **349 $** + palier eSigner mensuel | **eSigner** | le moins cher avec HSM ; le plus souple sur la validation internationale |
| GoGetSSL (revendeur) | ≈ 369 $ | celui de l'AC d'origine | revendeur : la validation reste faite par l'AC |
| Sectigo | ≈ 536 $ (engagement 5 ans) | Sectigo Cloud Signing | |
| DigiCert | ≈ 685 $ (≈ 560 $ chez un revendeur) | **KeyLocker** | le plus strict et le plus cher — **c'est pour lui que l'étape de CI est écrite** |

⚠️ **L'étape de CI est écrite pour DigiCert KeyLocker.** Ce n'est pas un
engagement : changer pour SSL.com eSigner ne touche qu'une dizaine de lignes
du bloc « préparer » (étape 1/2). Ne pas payer DigiCert *parce que* le code
existe — payer ce qui valide l'organisation.

⚠️ **Depuis le 1er mars 2026, la validité maximale d'un certificat public est
de 460 jours (~15 mois)**, contre 39 mois auparavant. La validation de
l'organisation se refera donc environ tous les quinze mois : ce n'est pas un
achat unique, c'est un abonnement avec une formalité récurrente. À budgéter, et
à ne pas découvrir en pleine année scolaire.

### ⚠️ Les trois choses à confirmer AVANT de payer

Le prix n'est pas le risque. Le risque est qu'une AC refuse le dossier après
encaissement.

1. **« Validez-vous une organisation immatriculée en République du Congo ? »**
   À poser par écrit, à leur support, avant toute commande. C'est la question
   qui décide, et aucune page publique n'y répond.
2. **Le rappel téléphonique.** L'AC doit joindre l'organisation sur un numéro
   qu'elle a pu vérifier de façon indépendante. C'est en pratique le point le
   plus dur hors des pays à annuaires professionnels — et c'est souvent ce que
   la lettre d'opinion légale sert à couvrir.
3. **Une adresse de courriel sur le domaine de l'organisation.** Les comptes du
   projet utilisent `epilote.cg` — ⚠️ **à confirmer** : l'organisation
   contrôle-t-elle réellement ce domaine, et une boîte y reçoit-elle du
   courrier ? Un domaine qui ne sert qu'à des comptes de démonstration ne
   suffira pas.

### Comment prouver l'existence légale

Les exigences du CA/Browser Forum admettent trois voies. La première suppose un
registre que l'AC sait consulter ; les deux autres existent précisément pour
les juridictions où ce n'est pas le cas :

- un **registre public** consultable par l'AC ;
- une **source indépendante qualifiée** ;
- une **lettre d'opinion légale** d'un avocat ou d'un expert-comptable.

C'est cette troisième voie qui s'appliquera très probablement ici — d'où sa
place en tête de l'ordre des gestes.

## Ce qu'il faut réunir — la vraie longueur du chemin

L'autorité doit vérifier que **E-PILOTE CONGO existe légalement** et que le
demandeur peut l'engager. Pour une organisation congolaise, la difficulté n'est
pas le paiement : c'est la **vérifiabilité**.

| pièce | remarque |
|---|---|
| immatriculation (RCCM) et statuts | l'identité légale exacte, telle qu'elle apparaîtra dans « Éditeur » |
| adresse physique vérifiable | pas une boîte postale |
| ligne téléphonique au nom de l'organisation | l'autorité rappelle pour confirmer |
| ⚠️ **lettre d'opinion légale** | avocat ou expert-comptable, **très probablement exigée** : les registres du commerce congolais ne sont pas dans les bases que les autorités consultent automatiquement |

⚠️ **La lettre d'opinion légale est le chemin critique.** Elle se demande à un
avocat, elle a son propre délai, et rien ne commence sans elle. C'est la
première chose à lancer — avant même de choisir l'autorité.

⚠️ **Le nom de l'organisation validé deviendra le « CompanyName » affiché par
Windows.** Il doit être **identique** à `CompanyName` dans
`epilote/windows/runner/Runner.rc` (aujourd'hui `E-PILOTE CONGO`), sinon
Windows affiche « éditeur inconnu » malgré la signature.

## L'ordre des gestes

0. ⚠️ **D'abord** — trancher le mode de distribution (USB/technicien contre
   téléchargement par les écoles). Si c'est l'USB, tout ce qui suit peut
   attendre, et rien ne doit être engagé.
1. Si le certificat est retenu — demander la lettre d'opinion légale à un
   avocat. C'est ensuite le délai le plus long, et il ne dépend d'aucun autre
   choix.
2. Réunir RCCM, statuts, adresse, ligne téléphonique.
3. Choisir l'autorité parmi celles offrant un HSM infonuagique, et vérifier
   auprès d'elle **avant de payer** qu'elle valide les organisations
   congolaises.
4. Commander un **EV** avec signature infonuagique.
5. Poser les **cinq secrets** (ci-dessus) dans le dépôt. ✅ L'étape de CI est
   déjà écrite pour eux — mais elle n'a **jamais tourné contre un vrai
   compte** : prévoir que le premier essai échoue, et le faire AVANT d'en
   avoir besoin.
6. Vérifier sur un poste vierge qu'un double-clic n'affiche plus
   « éditeur inconnu ». C'est le seul contrôle qui compte, et il ne se fait pas
   depuis la CI.
7. Alors seulement, retirer l'avertissement de `packaging/windows/INSTALL.md`,
   de `docs/PILOTE.md` et du discours tenu aux écoles.

## En attendant — ce qui est déjà en place

- L'empreinte **SHA-256** est publiée avec chaque version et **vérifiée par
  l'application** avant toute installation de mise à jour. C'est, sans
  signature, le seul moyen de prouver qu'un installateur reçu par clé USB est
  bien celui qui a été publié.
- `packaging/windows/INSTALL.md` documente l'avertissement et la marche à
  suivre.
- Le dossier de pilote (`docs/PILOTE.md`) impose de **prévenir les deux écoles
  avant** le premier lancement.

Voir [[chaine-livraison-windows]] · [[mise-a-jour-du-parc]] · `docs/PILOTE.md`
