# Interface d'échange DEC ↔ logiciels d'établissement — proposition

**Date** : 2026-07-17 · **Statut** : proposition à porter au METP (25 août 2026)
**Destinataire** : Ministre de l'Enseignement Technique et Professionnel · DSIC · DEC
**Nature** : **norme d'échange ouverte** — accessible à tout éditeur de logiciel scolaire.

---

## 1. Le problème, en un paragraphe

Aujourd'hui, l'établissement détient déjà l'identité de ses élèves — nom, prénoms, date de
naissance, filière, spécialité — **saisie une fois depuis l'acte de naissance**. À l'ouverture
des inscriptions, un agent de ce même établissement ouvre l'application de la DEC et **retape
tout à la main**, candidat par candidat.

**Pour le seul BET : 6 867 candidats retapés à la main dans le pays.**

Ce n'est pas d'abord une perte de temps. **C'est là que le nom se casse.** L'application de la
DEC est le système de référence : ce qui y est tapé **devient le diplôme**. Une lettre de
travers, une date inversée à 23 h 50 la veille de la clôture — et l'élève reçoit un diplôme qui
ne correspond pas à son acte de naissance. Cet écart le poursuit à chaque démarche
administrative, à vie.

> **Ce que le ministère gagne à cette interface — et c'est lui qui gagne :**
> l'intégrité de l'état civil scolaire, et la visibilité sur les inscriptions **avant** le
> 14 février, quand c'est encore réparable.

---

## 2. Principe fondateur : une norme, pas un privilège

**Cette interface doit être ouverte à tout éditeur de logiciel scolaire**, sans exception —
CongoEduSoft, E-PILOTE, ou tout acteur à venir.

Trois raisons, dans cet ordre :

1. **C'est juste.** Une interface publique réservée à un fournisseur est un favoritisme.
2. **C'est plus robuste pour le ministère.** Une norme survit à ses fournisseurs ; une intégration
   sur mesure meurt avec eux.
3. **C'est plus fort pour tout le monde.** Le METP publierait le **premier standard national
   d'échange scolaire** du pays.

**La DEC reste seule autorité.** Cette interface ne lui retire rien : elle attribue toujours les
numéros de candidat, affecte les centres, arbitre les dossiers, proclame les résultats. Elle
cesse seulement de dépendre d'une frappe manuelle pour la qualité de sa donnée.

---

## 3. Ce que fait l'interface

```
                    ÉCRITURE ─────────────▶
    LOGICIEL                                    APPLICATION
  D'ÉTABLISSEMENT                                 DEC
                    ◀───────────── LECTURE
```

### 3.1 Écriture — déposer les candidats

L'établissement envoie ses candidats pour une session. **Rien d'autre.**

| Donnée | Origine | Note |
|---|---|---|
| Noms, prénoms | acte de naissance | **la donnée qui compte** |
| Date et lieu de naissance | acte de naissance | |
| Sexe | | |
| Filière / spécialité / série | portée par la classe | |
| Classe d'origine | | détermine le lot |
| Établissement | | déjà connu par le compte |
| Photo | | ⚠️ binaire — voir §5 |

**Ce que l'établissement n'envoie jamais** : numéro de candidat, centre, résultat. Ce sont des
prérogatives de la DEC.

### 3.2 Lecture — récupérer ce que la DEC décide

| Donnée | Pourquoi c'est vital |
|---|---|
| **Calendrier et sessions** | Aujourd'hui recopié à la main depuis les arrêtés → **deux vérités qui divergeront**. Une seule source : la vôtre. |
| Numéros de candidat attribués | Aujourd'hui l'agent les voit à l'écran et ils se perdent |
| Affectation en centre | Pour éditer les convocations |
| **Résultats** | Pour que l'école exploite ses résultats sans ressaisie |

---

## 4. Contraintes non négociables

**Idempotence.** Rejouer deux fois le même dépôt ne doit rien dupliquer. Une école sans réseau
fiable **réessaiera** — c'est certain.

**Référence de l'établissement.** Chaque candidat porte une référence stable choisie par
l'établissement (`EP-KIN01-2026-0042`). La DEC la conserve et la **renvoie** avec le numéro
qu'elle attribue. **C'est la seule chose qui permet de rendre un résultat au bon élève sans
appariement par nom** — les homonymes sont fréquents, les orthographes varient. Le coût est nul
aujourd'hui ; sans elle, le rapprochement se fera à la main, pour toujours.

**Le dépôt physique reste.** Cette interface ne remplace pas l'envoi des dossiers papier à la
DEC ni leur vérification au comptoir. Elle garantit seulement que **ce qui est tapé et ce qui est
expédié disent la même chose**.

**Identité.** L'établissement possède **déjà** un compte dans l'application DEC. L'interface doit
s'appuyer dessus — pas créer un second annuaire.

**La DEC a toujours raison.** En cas de divergence, sa donnée prime. Le logiciel de
l'établissement doit le **montrer**, jamais le masquer.

---

## 5. Les photos — le point technique à trancher

Photos et badges existeront des deux côtés : les nôtres pour l'école, ceux de la DEC pour
l'examen. **Si la photo transite par l'interface, ce sont des fichiers, pas des données.**

Conséquence côté éditeur offline : les fichiers ne suivent pas le même chemin que le reste (chez
nous, `upload_outbox` — PowerSync met en file le SQL, **pas** les fichiers). Une photo perdue au
retour du réseau est silencieuse.

**Question à la DEC** : la photo est-elle attendue dans l'application, ou uniquement au dossier
papier ? La réponse change la conception.

---

## 6. Ce qui est demandé, concrètement

1. **Le format de l'échange** — champs, types, obligatoires ou non. La DEC le définit ; nous nous
   y conformons.
2. **Un accès de test** avant la campagne, sur une session blanche.
3. **Une session pilote** : quelques établissements du METP déposent par interface, les autres à
   la main. On compare les erreurs et le temps. **Le pilote décide, pas l'argumentaire.**
4. **La publication de la norme** — pour qu'elle appartienne au ministère, pas à un éditeur.

---

## 7. Ce qui n'est pas demandé

- Aucun accès à la base au-delà des candidats de **son propre établissement**.
- Aucune écriture sur les numéros, centres ou résultats.
- Aucune exclusivité.
- Aucun financement.

---

## 8. Ce que ça ne résout pas

- Les **candidats libres** (dépôt en direction départementale) restent hors périmètre.
- La **vérification des pièces** reste un acte humain, au comptoir.
- Les **dossiers physiques** continuent de circuler.

---

## 9. Points ouverts (à trancher avec la DEC)

- Photos : dans l'interface ou au papier seulement ?
- Les **lots** (~50, à l'intérieur d'une classe) : constitués par l'établissement, ou par la DEC ?
- Modalité de retour des résultats : par interface, fichier, ou publication ?
- **Attestation de stage** : due pour BEP / BTF / CAP, ou seulement pour le bac ?

---

## 10. La position à tenir en séance

> *« Vous avez numérisé l'inscription à l'examen. Ce que je viens vous demander n'est pas une
> faveur pour un logiciel : c'est une interface ouverte, publiée par votre ministère, que
> n'importe quel éditeur congolais pourra utiliser — pour que le nom sur le diplôme soit celui de
> l'acte de naissance. »*

**Note de gouvernance** — cette proposition est portée par un agent de la DSIC qui développe
également un logiciel scolaire. **C'est précisément pourquoi elle doit être une norme ouverte, et
pourquoi ce point doit être dit avant qu'on ne le demande.** Une interface réservée à un éditeur
serait indéfendable ; une norme publique, dont ce logiciel n'est que la première implémentation,
est irréprochable.
