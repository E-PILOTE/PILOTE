# Certificat de signature de code — dossier de décision

> Établi le 2026-09-01. À quatre semaines du déploiement national.
> Ce document ne se substitue pas à l'achat : seul le titulaire de
> l'organisation peut fournir les pièces légales et le moyen de paiement.

## Pourquoi c'est urgent, et pourquoi ce n'est pas cosmétique

Sans signature, Windows affiche **« Éditeur inconnu »** au lancement de
l'installateur. Un chef d'établissement qui découvre cet avertissement seul,
sans y avoir été préparé, referme la fenêtre. À l'échelle d'un déploiement
national, ce n'est pas un désagrément : c'est un taux d'abandon.

Le délai d'obtention est **incompressible** — validation de l'organisation par
l'autorité de certification. C'est la seule tâche du projet qui ne s'accélère
pas en y mettant plus de travail.

## ⚠️ Ce qui invalide le plan écrit dans la CI

`.github/workflows/windows.yml` attend deux secrets — `WINDOWS_CERT_PFX`
(base64 d'un `.pfx`) et `WINDOWS_CERT_PASSWORD` — et son commentaire promet :
« le jour où le certificat arrive, il n'y a qu'un secret à poser, aucun code à
écrire ».

**Cette promesse ne peut pas être tenue.**

> Depuis le **1er juin 2023**, les exigences du CA/Browser Forum imposent que la
> clé privée d'un certificat de signature de code vive sur du matériel certifié
> **FIPS 140-2 niveau 2**, **Common Criteria EAL 4+** ou équivalent. Un
> certificat émis aujourd'hui **n'est pas exportable en `.pfx`**.

Il n'existe donc aucun fichier à mettre dans un secret GitHub. L'étape de
signature devra être **réécrite** selon la voie retenue ci-dessous — ce n'est
pas « poser un secret », c'est un petit chantier. Mieux vaut le savoir
maintenant que la veille du déploiement.

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

1. **Aujourd'hui** — demander la lettre d'opinion légale à un avocat. C'est le
   délai le plus long et il ne dépend d'aucun autre choix.
2. Réunir RCCM, statuts, adresse, ligne téléphonique.
3. Choisir l'autorité parmi celles offrant un HSM infonuagique, et vérifier
   auprès d'elle **avant de payer** qu'elle valide les organisations
   congolaises.
4. Commander un **EV** avec signature infonuagique.
5. Une fois les identifiants reçus : réécrire l'étape de signature de la CI —
   `signtool /f <pfx>` ne fonctionnera pas, il faut le mécanisme du service.
6. Retirer l'avertissement SmartScreen de `packaging/windows/INSTALL.md` et du
   dossier de pilote.

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
