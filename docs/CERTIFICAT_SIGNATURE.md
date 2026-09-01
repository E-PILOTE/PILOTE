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
- Un binaire non signé est **plus exposé aux faux positifs antivirus**. Risque
  réel, imprévisible — à surveiller pendant le pilote.
- Un ministère déployant un logiciel d'« éditeur inconnu » : argument de
  crédibilité, non technique, mais réel.

## Les options libres et gratuites, examinées

| | ce que ça vaut ici |
|---|---|
| **Empreinte SHA-256 publiée + vérifiée** | ✅ **en place**, gratuit — c'est la vraie garantie d'intégrité |
| **Distribution par clé USB** | ✅ **retenu**, gratuit, supprime le bandeau bleu |
| **Auto-signé + « éditeurs approuvés »** | 🟡 gratuit et sérieux *si le parc est maîtrisé* — voir ci-dessous |
| **`osslsigncode`** (libre) | 🟡 permet de signer sans SignTool ; ne fournit PAS la confiance, seulement le geste |
| **SignPath Foundation / OSSign** (gratuit pour l'open source) | ⛔ l'« Éditeur » affiché serait *SignPath Foundation*, pas E-PILOTE CONGO |
| **Sigstore / cosign** | ⛔ ne produit pas de signature Authenticode : Windows ne la lit pas |

### 🟡 L'option auto-signée, si le parc est maîtrisé

Un certificat auto-signé **ne supprime rien par lui-même** : Windows le tient
pour inconnu. Mais si le ministère **contrôle les postes**, on peut déposer ce
certificat dans les magasins « Autorités racines de confiance » et « Éditeurs
approuvés » de chaque machine — par stratégie de groupe, ou par le script
d'installation. L'application devient alors signée **et reconnue** sur ce parc,
au nom d'E-PILOTE CONGO, gratuitement.

⚠️ **Ce n'est pas anodin.** Une racine de confiance installée sur un poste peut
valider *n'importe quel* binaire signé par elle. Sa clé privée devient un actif
à protéger sérieusement — la perdre ou la laisser fuir serait pire que de ne
rien signer.

⚠️ **Et ça ne vaut que pour les postes où on l'installe.** Une école qui
installerait le logiciel hors du dispositif verrait toujours « Éditeur
inconnu ».

À envisager si le déploiement est piloté poste par poste. Inutile sinon.

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
