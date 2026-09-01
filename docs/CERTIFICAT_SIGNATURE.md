# Signature de code — décision : écartée

> Tranché le 2026-09-01. Ce document n'est plus une tâche en attente : c'est le
> raisonnement qui a conduit à ne pas acheter de certificat, et ce qui le
> ferait rouvrir.

## La décision

**Les binaires ne sont pas signés, et c'est un choix mesuré.**

Le bandeau bleu de SmartScreen — « Windows a protégé votre ordinateur » — ne se
déclenche que sur un fichier porteur d'un **Mark-of-the-Web**, la marque qu'un
**navigateur** ajoute au téléchargement.

| chemin d'arrivée | marque | ce que l'école voit |
|---|---|---|
| téléchargement par un navigateur | oui | **bandeau bleu**, deux clics dont un caché |
| copie depuis une **clé USB** (FAT32/exFAT) | **non** | rien de plus que l'invite UAC |
| **mise à jour par l'application** | **non** | idem |

⚠️ **Mesuré, pas déduit** : ni l'installateur construit localement ni celui
retéléchargé par `curl` lors de la recette anonyme ne portent de
`Zone.Identifier`. L'updater procède de même (`http.Request` + écriture de
fichier) — **une mise à jour ne déclenchera donc jamais SmartScreen**.

Le mode de distribution retenu — télécharger une fois, vérifier l'empreinte,
distribuer par clé — supprime le problème sur tout le parc.

## Ce qui tient lieu de garantie, et qui est déjà en place

L'intégrité ne repose pas sur une signature mais sur l'**empreinte SHA-256** :
publiée avec chaque version, **vérifiée par l'application** avant toute
installation de mise à jour, et re-contrôlée à la publication par la recette
anonyme (téléchargement sans identifiants, comparaison des octets reçus).

Pour un installateur reçu par clé, c'est une garantie **plus directe** qu'une
signature : elle prouve que ce fichier-ci est exactement celui qui a été
publié, sans dépendre d'une autorité tierce.

## Ce qu'on accepte en échange

- L'invite UAC affiche **« Éditeur inconnu »**. Discret, mais présent à chaque
  installation. À annoncer aux écoles.
- Un binaire non signé est **plus exposé aux faux positifs antivirus**. C'est le
  seul risque sérieux qui subsiste — il a désormais son filet, gratuit et sans
  clé : voir « Le risque qui reste vraiment » plus bas.
- Un ministère déployant un logiciel d'« éditeur inconnu » : argument de
  crédibilité, non technique, mais réel.

## Les options libres et gratuites, examinées

| | ce que ça vaut ici |
|---|---|
| **Empreinte SHA-256 publiée + vérifiée** | ✅ **en place**, gratuit — c'est la vraie garantie d'intégrité |
| **Distribution par clé USB** | ✅ **retenu**, gratuit, supprime le bandeau bleu |
| **Auto-signé, sans rien déposer** | ⛔ **mesuré sans effet** — Windows rejette la chaîne ; identique à non signé. Voir ci-dessous |
| **Auto-signé + racine déposée sur chaque poste** | ⛔ marche, mais fabrique une **clé maîtresse sur le parc**. Écarté |
| **Azure Trusted Signing** (Microsoft détient la clé) | 🟡 le seul chemin où l'on ne possède **aucune clé** et où le nom affiché reste le nôtre — éligibilité à vérifier |
| **`osslsigncode`** (libre) | 🟡 permet de signer sans SignTool ; ne fournit PAS la confiance, seulement le geste |
| **SignPath Foundation / OSSign** (gratuit pour l'open source) | ⛔ l'« Éditeur » affiché serait *SignPath Foundation*, pas E-PILOTE CONGO |
| **Sigstore / cosign** | ⛔ ne produit pas de signature Authenticode : Windows ne la lit pas |

### ⛔ Fabriquer notre propre certificat — mesuré, et sans effet

**Question posée le 2026-09-01 : peut-on s'en créer un nous-mêmes ?** La réponse
n'est pas une opinion, elle a été mesurée sur le vrai installateur 3.4.3.

Certificat fabriqué en une ligne (`New-SelfSignedCertificate -Type
CodeSigningCert`, sujet `CN=E-PILOTE CONGO, O=E-PILOTE CONGO, C=CG`), binaire
signé en SHA-256, puis relu par Windows :

| étape | ce que Windows répond |
|---|---|
| avant signature | `NotSigned` |
| **après signature par notre propre certificat** | **`UnknownError`** — « une chaîne de certificats a été traitée mais s'est terminée par un certificat racine qui n'est pas approuvé par le fournisseur d'approbation » |
| chaîne vérifiable (`.Verify()`) | **`False`** |

Le fichier porte bien notre nom — et Windows refuse de le croire. **Pour
l'école, le résultat est identique à celui d'un binaire non signé** : la même
invite UAC, la même mention « Éditeur inconnu ».

> Ce n'est pas un réglage à trouver, c'est le principe même. Une signature ne
> vaut pas par elle-même, elle vaut par l'autorité qui l'a émise. Se signer
> soi-même, c'est présenter une pièce d'identité qu'on a imprimée.

*(Le certificat d'essai a été détruit et le magasin vérifié vide après mesure.)*

#### Et si on déposait notre racine sur les postes ?

C'est la seule façon de rendre cette signature valide : installer notre
certificat dans « Autorités de certification racines de confiance » et
« Éditeurs approuvés » de chaque machine. Ça fonctionne, gratuitement, au nom
d'E-PILOTE CONGO. **C'est écarté quand même, pour trois raisons :**

1. ⚠️ **Un poste qui nous fait confiance comme racine fait confiance à TOUT ce
   que cette clé signe.** La clé privée devient une clé maîtresse sur le parc :
   si elle fuite, un logiciel malveillant signé avec elle est accepté sans un
   mot sur mille postes d'établissements scolaires. On échange un avertissement
   contre un risque d'une autre nature.
2. Ce geste **modifie la sécurité de l'ordinateur d'un tiers**. Il ne se décide
   pas dans un script de build ; il se décide par écrit, au niveau du ministère.
3. Il ne vaut **que sur les postes où on l'a déposée**. Toute installation hors
   du dispositif retrouve « Éditeur inconnu ».

**Bilan : une clé fabriquée par nous est soit inutile, soit dangereuse.**

## Ne posséder aucune clé — les chemins existants

| | qui détient la clé | verdict ici |
|---|---|---|
| **Ne pas signer** — état actuel | personne | ✅ **retenu**. Gratuit, rien à protéger, rien à renouveler |
| **Azure Trusted Signing** | **Microsoft**, dans son propre HSM | 🟡 le seul où l'on ne détient jamais de clé **et** où l'éditeur affiché reste E-PILOTE CONGO. ⚠️ Éligibilité à confirmer avant tout espoir : organisation vérifiée, ancienneté exigée, régions ouvertes limitées |
| **SignPath Foundation** | la fondation | ⛔ l'éditeur affiché serait la fondation |
| **Microsoft Store** | Microsoft | ⛔ impose MSIX et la mise à jour par la boutique — incompatible avec un produit hors-ligne d'abord qui porte son propre updater |

⚠️ Aucun de ces chemins n'est un préalable au pilote ni au déploiement : le
mode de distribution par clé USB les rend tous facultatifs.

## Le risque qui reste vraiment, et ce qu'on lui oppose — gratuitement

Sans signature, il ne reste qu'**un** risque sérieux : le **faux positif
antivirus**. Un binaire non signé est jugé sur son seul comportement, et le
verdict tombe sans prévenir — à l'école, devant le chef d'établissement.

**Mesuré le 2026-09-01 sur l'installateur 3.4.3** : Windows Defender, protection
nuage en mode avancé et « blocage à la première vue » actif, signatures
`1.457.442.0` du jour — **aucun signalement**. Le nuage de Microsoft a donc bien
été consulté : ce n'est pas le verdict d'une base locale figée.

Deux gestes, tous deux gratuits et sans clé :

1. ✅ **La CI scanne désormais chaque installateur avant publication**
   (`.github/workflows/windows.yml`, étape « Antivirus — juger le binaire avant
   les écoles »). Un signalement fait échouer la livraison au lieu d'atteindre
   le parc. Elle avertit sans bloquer si le moteur manque sur le runner — on ne
   fait pas tomber une livraison saine pour un outil absent.
2. **Si un antivirus signale un jour le binaire** : le soumettre au portail
   d'analyse de l'éditeur concerné (Microsoft en premier), gratuit. C'est la
   procédure normale de levée d'un faux positif, et elle ne demande aucun
   certificat.

## Ce qui ferait rouvrir la décision

- Les écoles **téléchargent elles-mêmes** depuis un lien au lieu de recevoir une
  clé : le bandeau bleu frapperait alors chaque établissement.
- Des **faux positifs antivirus** observés pendant le pilote.
- Une exigence institutionnelle explicite sur le nom de l'éditeur.

Dans ce cas, rien n'est à refaire. Le raisonnement d'achat — EV plutôt qu'OV,
HSM infonuagique, lettre d'opinion légale comme chemin critique, validité
ramenée à 460 jours depuis mars 2026, et les quatre fournisseurs comparés — est
dans l'historique de ce fichier. Et **l'implémentation complète de la CI pour un
HSM infonuagique est au commit `9db2838`** : deux étapes, avec vérification
`signtool verify`. La reprendre est un `git show`, pas une réécriture.

Voir `docs/PILOTE.md` · `packaging/windows/INSTALL.md`
