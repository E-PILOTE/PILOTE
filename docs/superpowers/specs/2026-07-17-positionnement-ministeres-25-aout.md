# Positionnement E-PILOTE face au MEPSA et au METP — présentation du 25 août 2026

**Date** : 2026-07-17 · **Révisé** : 2026-07-17 (v2) · **Statut** : note stratégique (aucun code)
**Objet** : ce que les ministères ont réellement, ce que nous avons vraiment, et comment le dire.

> **⚠️ Cette note a été réécrite.** La v1 affirmait « le METP est encore sur papier, aucun
> incumbent » et bâtissait la présentation sur la **demande manuscrite pré-remplie**. Les deux
> étaient faux. Ils venaient d'une méthode fautive : **déduire l'état du terrain depuis des
> pages web**. Ce qui suit distingue systématiquement ce qui est **établi par un témoin
> interne** de ce qui n'est que **trouvé en ligne**.

---

## 1. La règle de méthode (apprise à mes dépens)

La source de vérité sur les systèmes ministériels est **l'utilisateur : il est fonctionnaire à
la DSIC du METP**. Il travaille dedans.

En une seule journée, j'ai affirmé successivement, avec assurance, deux choses opposées et
également fausses :

1. « Le METP est encore au papier, aucun incumbent » → faux.
2. « La DSIC a un ERP complet à 5 modules qui nous concurrence » → faux aussi.

**Même cause** : `dsic-metp.net` affiche une « Gestion Scolaire » à 5 modules (Monitoring,
Examens, Finances, Scolarité, RH) avec guide d'utilisation complet. **Ce sont des vitrines.**
Elles n'existent que sur le web.

**Règle** : tout constat sur un système ministériel non confirmé par l'utilisateur est une
hypothèse, et doit être écrit comme telle.

---

## 2. Ce qui existe RÉELLEMENT au METP

**✅ Établi par l'utilisateur (DSIC) :**

| Fait | Conséquence |
|---|---|
| **Une seule application réelle : l'inscription aux examens d'État** | Une seule frontière à traiter |
| Les **établissements se connectent eux-mêmes** | L'école est déjà un utilisateur en ligne |
| **Tout est tapé à la main** — aucun import | ⭐ **Notre valeur n°1** (§4) |
| Les candidats sont groupés en **lots** — un lot est **dans une classe**, ~50 | `niveau ▸ classe (= filière) ▸ lot` — **notre axe actuel est le bon** |
| Le **dossier physique part quand même à la DEC** | L'école a **deux sorties** : une saisie + une expédition (§5) |
| Vérification des pièces : **école avant dépôt ET DEC au comptoir** | Notre pré-contrôle n'est pas redondant |
| Les autres modules (Scolarité, Finances, RH) | **N'existent pas.** Vitrine. |

**✅ Établi par la note officielle METP 2025-2026** (l'utilisateur a tranché : *« crois la note
officielle »*) :

- Dépôt : **directions départementales** (candidats libres) · **établissements** (candidats officiels).
- Campagne **8 déc. 2025 → clôture 14 févr. 2026 à 14 h 00**.
- Pièces par examen : voir `2026-07-17-dossiers-examens-metp.md` (âges 24 / 20 / 21 — conformes
  à `exam_age_at_session()`).
- **L'attestation de fin de stage est une pièce du dossier du baccalauréat.**

**❌ Abandonné** : la **demande manuscrite**. Absente des deux notes officielles, le PDF qui
l'appuyait renvoie 404. L'utilisateur a tranché : *« laisse la demande manuscrite »*. Elle
n'aurait de toute façon pas survécu à son propre nom — une demande imprimée n'est pas manuscrite.

---

## 3. Ce que le MEPSA a — ⚠️ NON VÉRIFIÉ

**Tout ce qui suit vient du web. `e-meppsa.net`, `resultat.e-meppsa.net` et `meppsa.cg` sont
injoignables depuis ce poste.** Après m'être trompé deux fois sur le METP en lisant des
vitrines, **je refuse de traiter celle du MEPSA comme un fait**. À confirmer avant d'en faire
un argument en séance.

| Brique (supposée) | Ce qu'elle ferait |
|---|---|
| e-MEPPSA | Portail : inscriptions, résultats, suivi |
| ExaTrust | Publication et vérification officielle des résultats |
| Cartographie des centres | Géolocalisation des centres d'examen |

**Le point qui vaudrait de l'or, s'il est vrai** : ExaTrust serait utilisé par **Campus France**
pour recouper les relevés de notes. Si c'est exact, le ministère **sait** ouvrir un accès
institutionnel à un tiers, et l'a **déjà fait pour un organisme étranger**. L'argument devient :
*« vous l'avez ouvert à Campus France ; ouvrez-le aux écoles congolaises. »*

**À vérifier absolument** : c'est l'argument le plus puissant de la présentation — et le plus
embarrassant s'il est faux.

**CongoEduSoft** : éditeur congolais, publie des résultats METP en ligne. Part de marché réelle
**inconnue**. Ni surestimer (ce n'est pas forcément l'incumbent que je décrivais), ni ignorer.

---

## 4. Notre valeur réelle : la ressaisie et l'intégrité du nom

C'est le cœur de la présentation, et ça ne vient pas d'un argumentaire — ça vient du terrain.

**La situation d'aujourd'hui :**

```
L'école détient l'élève           Un agent de CETTE MÊME école
(nom, date de naissance,   ───▶   ouvre l'appli DEC et RETAPE
matricule, classe, filière)       TOUT À LA MAIN, candidat par candidat
issus de l'acte de naissance
```

**Le BET seul : 6 867 candidats retapés à la main dans le pays.**

**Et voici ce qui compte vraiment** — ce n'est pas une perte de temps, **c'est là que le nom se
casse**. L'application de la DEC est le système de référence : ce qui y est tapé **devient le
diplôme**. Une lettre de travers, une date inversée à 23 h 50 le 13 février, et l'élève reçoit
un BET qui ne correspond pas à son acte de naissance. Au Congo, cet écart le poursuit à chaque
démarche administrative, **à vie**.

**Nous détenons l'orthographe juste** — saisie une fois, depuis l'acte de naissance, contrôlée.

> **L'argument à porter devant le ministre, et il n'est pas pour nous :**
> *« Sans interface, la qualité de votre base nationale dépend de 6 867 frappes manuelles faites
> la veille de la clôture, et le diplôme porte le nom que quelqu'un a tapé à 23 h 50. Avec
> interface, la donnée vient de l'acte de naissance, saisie une fois. Vous y gagnez l'intégrité
> de l'état civil scolaire et la visibilité avant le 14 février. »*

---

## 5. L'école est un relais à deux sorties

Fait établi : **le dossier physique part à la DEC**, *en plus* de la saisie en ligne.

```
                    ┌──▶ SAISIE en ligne dans l'appli DEC (à la main)
ÉLÈVE ──dossier──▶ ÉCOLE
                    └──▶ EXPÉDITION physique des dossiers à la DEC
```

**Les deux flux doivent dire la même chose.** S'ils divergent, la DEC le constate au comptoir et
renvoie l'école — après la clôture, c'est une année perdue pour l'élève.

D'où l'objet **`transmissions`** (déjà décidé dans `architecture-transmission-dec.md`) : **une
seule liste**, figée, qui sert **à la fois** de feuille de frappe et de bordereau d'expédition.
L'école prouve ce qu'elle a déclaré et ce qu'elle a envoyé, et les deux coïncident par
construction.

---

## 6. Notre unique fossé défendable : le hors-ligne

L'application d'inscription de la DEC est **en ligne**. Toutes les offres concurrentes trouvées
le sont aussi.

Or une école de la Likouala, de la Sangha ou du Congo-Oubangui n'a ni courant stable ni réseau
fiable. E-PILOTE est **offline-first** (PowerSync) : l'école travaille sans réseau, tout remonte
au retour.

**Ce n'est pas rattrapable par une mise à jour** — c'est une décision d'architecture. C'est la
différence entre *« le numérique pour Brazzaville et Pointe-Noire »* et *« le numérique pour la
République »*.

**Et le périmètre est vide** : aucun système ministériel **réel** ne couvre la scolarité, les
emplois du temps, les notes, les bulletins, la finance, la paie, la RH, la vie scolaire. La
vision « E-PILOTE gère tout » **ne se heurte à rien**.

> ⚠️ **Formulation à bannir : « système amont ».** Elle décrivait la **frontière** avec la DEC ;
> elle a été lue comme un **périmètre produit**. E-PILOTE est le système de référence de l'école
> sur toute sa vie. Il ne l'est **que** sur un seul acte : l'inscription à l'examen et la
> certification. Là, la DEC décide.

---

## 7. Le positionnement

> **E-PILOTE n'est pas un système d'examen. C'est le système d'exploitation de l'école — hors
> ligne — et il alimente les systèmes de l'État.**

| | Rôle de l'État | Rôle d'E-PILOTE |
|---|---|---|
| Inscrire aux examens, attribuer numéros et centres | **DEC** | ❌ jamais |
| Publier les résultats officiels | **DEC** | ❌ jamais |
| Faire tourner l'école toute l'année, hors ligne | ❌ rien | ✅ **nous** |
| Préparer un dossier complet et pré-vérifié | ❌ | ✅ **nous** |
| Fournir la donnée juste à la DEC | — | ✅ **nous** |
| Récupérer résultats et les exploiter | — | ✅ **nous** |

**Phrase pour la salle :**
> *« Vos systèmes gèrent l'examen. Aucun ne fait tourner l'école entre deux examens — et aucun ne
> fonctionne à Impfondo quand le réseau tombe. Nous ne remplaçons rien : nous alimentons. »*

---

## 8. La demande réelle du 25 août : **une API**

**La réunion n'est pas une démonstration de produit. C'est une négociation d'interface.**
L'utilisateur le dit : il veut une API pour **écrire** (candidats) et **lire** (examens,
résultats, calendrier) dans la base de la DEC.

L'architecture l'attend déjà : `DecGateway.submit()` / `DecResultsSource.fetch()`, deux
adaptateurs — manuel aujourd'hui, API demain. **Rien à redessiner : on branche.**

### La condition qui protège l'utilisateur

Il est **fonctionnaire à la DSIC** et porte un produit privé. Si l'API n'accepte qu'E-PILOTE,
c'est du favoritisme, et devant deux ministres **ça l'expose personnellement**.

> **Si elle accepte un format ouvert que n'importe quel éditeur peut produire — CongoEduSoft
> compris — c'est une norme nationale.** E-PILOTE en devient la première implémentation.

C'est plus défendable en séance, plus fort stratégiquement, et c'est simplement la bonne façon
de le faire.

### Ce qu'un ministre peut accorder le jour même

Un ministre à qui on demande « une API » répond *« voyez avec mes services »*. Un ministre à qui
on présente **deux pages précises** — ce qu'on écrit, ce qu'on lit, dans quel format, ouvert à
tous — peut arbitrer sur-le-champ. → `2026-07-17-spec-api-dec.md` (à rédiger).

---

## 9. À obtenir avant le 25 août

Par ordre de valeur. **Aucun ne se code — ils se demandent.**

1. **Une capture du formulaire de saisie de la DEC.** Notre liste doit épouser ses champs, dans
   son ordre. C'est ce qui fait passer l'export de « raisonnable » à « exact ».
2. **Vérifier la pile du MEPSA** (§3), en particulier l'accès Campus France à ExaTrust.
3. **Le retour des résultats** : sous quelle forme la DEC les rend-elle à l'école ?
4. **La liste des pièces confirmée** par la DEC elle-même (nous avons la note ; l'utilisateur est
   dedans).
5. **Photos et badges** : téléversés dans l'appli, ou seulement au dossier papier ? ⚠️ S'ils
   transitent, ce sont des **fichiers** → `upload_outbox` obligatoire (PowerSync met en file le
   SQL, pas les fichiers).

---

## 10. Mon avis franc

**Le danger n'est pas technique, il est narratif.** Le produit est solide et le hors-ligne est un
vrai fossé.

**Le récit qui gagne :**
> *« Vous avez numérisé l'inscription à l'examen. Personne n'a numérisé l'école — et personne ne
> l'a fait fonctionner sans réseau. Voilà les 30 modules, voilà les 14 écoles du METP déjà
> dedans. Et voilà ce que je viens vous demander : une interface, ouverte à tous les éditeurs,
> pour que le nom sur le diplôme soit celui de l'acte de naissance. »*

---

## 11. Limites de cette note

- **La pile du MEPSA (§3) n'est pas vérifiée.** Sites injoignables. C'est le plus gros trou.
- **Piège écarté** : les sources parlant d'« Examen d'État » et de « 26 provinces » relèvent de la
  **RDC (Kinshasa)**, pas du Congo-Brazzaville (15 départements). Rien ici n'en provient.
- Parts de marché de CongoEduSoft et Zaame : **inconnues**.
- Aucune API publique DEC/ExaTrust attestée.
- **`dsic-metp.net` est une vitrine** — ne jamais s'en servir comme preuve d'un produit déployé.

## Sources

- Terrain : **l'utilisateur, fonctionnaire à la DSIC du METP** (source prioritaire).
- [Note d'information — Inscription aux examens d'État 2025-2026 METP](https://ecolesaucongo.com/article-64-note-d-information-inscription-aux-examens-d-etat-2025-2026-metp.html)
- [Dossiers, période d'inscription et lieux de dépôt METP 2024-2025](https://ecolesaucongo.com/article-3-dossiers-periode-d-inscription-et-lieux-de-depots-de-dossiers-aux-examens-metp-2024-2025.html)
- [Examens techniques et professionnels 2026 : BET, BEP, BTF — Matin Libre](https://www.matinlibre.cg/examens-techniques-et-professionnels-2026-les-candidats-au-bet-bep-et-btf-a-lepreuve/)
- [METP — site officiel](https://enseignement-technique.gouv.cg/) · [DSIC-METP — ⚠️ vitrine](https://www.dsic-metp.net/)
- ⚠️ Non consultés (injoignables) : [e-MEPPSA](https://www.e-meppsa.net/) · [ExaTrust](https://resultat.e-meppsa.net/) · [MEPPSA](https://www.meppsa.cg/)
