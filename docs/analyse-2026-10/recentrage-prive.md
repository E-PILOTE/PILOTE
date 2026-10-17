# Recentrage sur les groupes scolaires privés — analyse et avis

**2026-10-17.** Décision du fondateur : le projet ministériel (METP) est annulé.
E-PILOTE sert désormais **uniquement** les promoteurs privés — une école ou
plusieurs — qui paient un abonnement, quel que soit leur ordre d'enseignement
(général ou technique). Tout est mesuré en base de production et dans le dépôt
le jour même.

---

## 1. Mon avis, sans détour

**La décision est la bonne, et elle arrive au bon moment.** Trois faits la
rendent presque gratuite :

1. **Aucun compte d'un groupe privé ne s'est jamais connecté.** Les 6 groupes
   privés (127 comptes) sont des données de démonstration. Les seuls comptes
   réellement utilisés sont ministériels (METP : 11 comptes connectés, 3 actifs
   sur 30 jours). Il n'y a donc **aucun client privé à ne pas casser**.
2. **Le code ministériel est concentré.** Environ 22 000 lignes sur 274 000
   (8 %), regroupées dans quatre blocs identifiables (§ 4). Ce n'est pas un
   tissu diffus qu'il faudrait arracher fil à fil.
3. **Le cœur du produit est déjà privé.** Scolarité, évaluation, finance, RH,
   vie scolaire, communication, hors-ligne : rien de tout ça ne dépend d'un
   ministère.

**Mais je veux être honnête sur le vrai risque : ce n'est pas le code.** La
plateforme compte 274 000 lignes de Dart, 111 tables, 319 politiques RLS et
177 migrations — et **zéro client privé actif**. Le produit est plus avancé
que son marché. Alléger est nécessaire, mais la priorité absolue est d'avoir
**un premier promoteur qui paie et qui se connecte tous les jours**. Chaque
semaine passée à raffiner sans utilisateur produit du code que personne ne
valide.

**Ma règle directrice pour le recentrage :**

> Le ministère cesse d'être un **utilisateur** de la plateforme.
> Il reste un **fait réglementaire** que la plateforme décrit.

Une école privée technique est agréée par le METP, ses élèves passent le BET et
le BAC technique. Une école privée générale relève du MEPSA, ses élèves passent
le CEPE et le BEPC. Ces faits ne disparaissent pas avec le projet : ils
conditionnent les examens, les documents officiels et l'état de rentrée. Ce
qu'on supprime, c'est **le ministère en tant que compte** : son espace, sa
licence, sa supervision, sa carte nationale, son autorité sur le référentiel.

---

## 2. Le constat chiffré

| | Public (2 ministères + EDEC + Savorgnan) | Privé (6 groupes) |
|---|---|---|
| Écoles | 30 | 14 |
| Élèves (tous statuts) | 8 258 | ≈ 2 100 |
| Comptes | 287 | 127 |
| Comptes déjà connectés | 16 | **0** |
| Actifs sur 30 jours | 3 (METP) | **0** |
| Encaissé (factures `paid`) | 3,55 M XAF | 2,52 M XAF (**seed**, jamais connectés) |

Les candidats aux examens comptent 2 470 lignes, dont 588 dans des écoles
privées.

**Code Dart rattaché au modèle ministériel**

| Bloc | Fichiers | Lignes | Sort |
|---|---|---|---|
| A. Tutelle (réseau supervisé, messages de tutelle, badges, rôle) | 21 | 4 976 | **supprimer** |
| B. Licence de tutelle (marché, statut, PDF, couverture, territoire) | 10 | 3 882 | **supprimer** |
| C. Carte nationale / vue régionale (12 départements, satellite, projets) | 20 | 7 733 | **supprimer** (voir § 5.7) |
| D. Examens côté ministère (archives DEC, référence nationale, référentiel écrit par le groupe, statistiques par axe) | 34 | 10 471 | **≈ 6 000 à supprimer**, le reste déplacé chez le super_admin |
| E. Secteur public dispersé (`estPublic`, `group_type`, `is_public_plan`, gratuité) | ≈ 60 | ≈ 300 occ. | **simplifier** |

Au total : **≈ 22 000 lignes retirables**, ≈ 100 fichiers de tests à revoir.

**Base de données rattachée au modèle ministériel** : 53 fonctions,
6 politiques RLS et 26 colonnes. Tables entièrement ministérielles :
`tutelle_licences`, `circulaires`, `circulaire_destinataires`.

---

## 3. Ce que le pivot change dans le MODÈLE — le plus important

Supprimer des écrans est mécanique. Ce qui demande de la réflexion, ce sont les
règles qui avaient été pensées pour l'État et qui deviennent **fausses** pour
un promoteur privé.

### 3.1 Un groupe privé peut mêler général et technique
Aujourd'hui `fn_school_herite_tutelle` impose le même ministère à toutes les
écoles d'un groupe (« un groupe n'est jamais mixte »). C'est vrai pour un
ministère, **faux pour un promoteur** : un complexe qui a une école primaire et
un lycée technique est le cas typique de ta cible. → **La tutelle descend à
l'école**, saisie école par école. Le groupe n'en porte plus.

### 3.2 L'agrément est celui de l'ÉCOLE
Il est aujourd'hui saisi sur le groupe et recopié de force sur chaque école.
Or l'arrêté d'agrément autorise **un établissement**. → **L'agrément se saisit
par école**. Et il doit être saisissable par le promoteur lui-même, pas
seulement par le super_admin : c'est sa donnée.

### 3.3 Le personnel : le promoteur EMPLOIE, il ne « constate » pas
Le module RH a été conçu pour la fonction publique : « agent de l'État : nommé
par le ministère, jamais recruté par l'école » ; l'école « constate une
arrivée, elle ne la décide pas » ; mutation, détachement, mise à disposition,
réintégration. **Dans le privé, c'est l'inverse : le promoteur recrute,
licencie, affecte.**
→ Les statuts deviennent ceux d'un employeur privé : CDI, CDD, vacataire,
stagiaire, prestataire, bénévole. Le seul motif d'arrivée est le
recrutement.
→ La **mutation reste, mais change de sens** : c'est l'affectation interne
d'un agent d'une école du groupe à une autre. C'est même une vraie valeur pour
un promoteur multi-écoles, et il faut la garder.
→ Un enseignant fonctionnaire qui fait des heures dans une école privée devient
un **vacataire**.

### 3.4 Les examens : le catalogue national appartient à la PLATEFORME
Les écoles privées présentent des candidats aux examens d'État : il faut garder
le catalogue (CEPE, BEPC, BAC, CAP, BET…), les sessions, les inscriptions, les
dossiers, les frais et les résultats de **leurs** candidats. Mais personne
d'autre que l'opérateur ne peut désormais tenir ce catalogue. → **Le
super_admin le maintient** (c'est la donnée de référence du produit). Les
groupes le consultent. On supprime l'écriture par un « groupe de tutelle »,
les archives de publications DEC et la « référence nationale » posée à côté
des résultats du réseau.

### 3.5 Le secteur disparaît
`group_type`, `school_type`, `is_public_plan`, la gratuité légale du public
(loi 25-95), la garde « pas de mensualité dans le public » et
`groupe_est_public` n'ont plus d'objet : **tout est privé**. → À retirer, et non
à figer à `'prive'` : une colonne qui vaut toujours la même chose est une
case morte (cf. mémoire « cases mortes et zéros menteurs »).
Le **caractère** (laïc, catholique, protestant, islamique) reste : c'est une
vraie information commerciale sur un promoteur privé.

### 3.6 Une école seule est un groupe d'une école — et l'écran doit le savoir
Ton message le dit : « qu'ils soient une école ou un groupe ». Techniquement,
une école seule = un groupe d'une école, et c'est le bon modèle (pas de
second chemin). Mais **l'interface ne doit pas faire sentir le groupe** à qui
n'a qu'une école : pas de tableau comparatif à une ligne, pas de « réseau ».
C'est un chantier d'UX, pas de base.

### 3.7 Les offres
- **À supprimer** : « Licence de tutelle » (2 groupes) et « Institutionnel »
  (plan public, 2 groupes).
- **À garder** : Découverte, Standard, Pro, avec le prix qui suit le nombre
  d'écoles (0159). C'est le bon modèle pour un promoteur multi-écoles.
- **À corriger d'abord**, car c'est désormais le seul revenu : les deux
  défauts critiques de facturation de l'audit (C1 : une échéance qui recule ;
  C2 : une relance bloquée), le quota d'élèves du plan gratuit (Bethel : 237
  élèves pour 100 autorisés), et l'assiette facturée périmée.

---

## 4. Inventaire : supprimer, transformer, garder

### Supprimer
| Élément | Code | Base |
|---|---|---|
| Espace tutelle | `features/tutelle/` (16 fichiers), route `/admin/tutelle`, `badge_ministere.dart`, `core/constants/tutelle.dart` (à réduire à 2 libellés), `group_tutelle_role.dart`, `correspondants_ministere_provider.dart` | `tutelle_groupes`, `tutelle_ecoles`, `tutelle_destinataires`, `correspondants_ministere`, `auth_peut_superviser`, `auth_group_administre_referentiel`, colonnes `acces_suspendu*` |
| Licence de tutelle | `admin_licence_*` (4 écrans), `economie/licence_*`, `licence_pdf_service.dart`, `licence_statut.dart` | table `tutelle_licences`, `licence_changer_statut`, `fn_licence_*`, `fn_tutelle_licence_coherente`, plan `licence` |
| Rôle ministère | interrupteur dans la fiche du groupe, refus de suppression d'un ministère | colonne `administre_referentiel_national`, index 0178, `fn_une_seule_tutelle_par_ministere`, `fn_ministere_ne_seffce_pas`, `fn_ministere_sur_licence` |
| Circulaires | bucket PowerSync `circulaires_ecole`, tables du schéma local | `circulaires`, `circulaire_destinataires`, 3 fonctions, 3 politiques |
| Secteur public | `estPublic`, `adminGroupePublicProvider`, branche « public » du barème | `group_type`, `school_type`, `is_public_plan`, `cascade_group_type_to_schools`, `set_school_type_from_group`, `fn_guard_mensualite_publique`, `fn_guard_bascule_public_mensualite`, `groupe_est_public`, `fn_plan_coherent_avec_secteur` ; plan Institutionnel |
| Carte nationale | `regional*` (20 fichiers), onglet « Vue régionale » | — |
| Examens côté ministère | archives DEC, chiffres officiels, référence nationale, `ministry_exam_rows`, `referentiel_national_provider`, statistiques par axe | `exam_publications` (0 ligne), `exam_official_results` (14) ; écriture du référentiel par un groupe |

### Transformer
| Élément | Aujourd'hui | Demain |
|---|---|---|
| `tutelle` | portée par le groupe, imposée aux écoles | **portée par l'école**, libellée « ordre d'enseignement : général (MEPSA) / technique (METP) » |
| Agrément | groupe → recopié | **par école**, saisi par le promoteur |
| Statut d'emploi | fonctionnaire / contractuel / … | CDI, CDD, vacataire, stagiaire, prestataire, bénévole |
| Motifs d'arrivée et de départ | mutation, détachement, réintégration… | recrutement ; départ : démission, fin de contrat, licenciement… ; **affectation interne** entre écoles du groupe |
| Référentiel d'examens | écrit par le « groupe de tutelle » | écrit par le **super_admin** seul, lu par tous |
| `inspections` | référentiel METP, jamais saisi dans l'app | **supprimer** (info administrative sans usage pour un privé), ou garder en simple texte libre si le fondateur y tient |
| `institution_types` | 4 MEPSA + 4 METP | garder : type d'établissement (préscolaire, primaire, collège, lycée, lycée technique, CFP) |

### Garder tel quel
Tout le cœur : scolarité, inscriptions et caisse, structure académique,
évaluation, bulletins, passage, examens côté école, vie scolaire, finance,
RH (une fois transformé), communication, hors-ligne PowerSync, poste partagé,
licence signée hors ligne, facturation au nombre d'écoles, journal d'audit,
mise à jour du parc.

---

## 5. Comment le faire sans casser — méthode

### 5.1 La règle d'or : contracter dans le bon ordre
L'application fonctionne hors ligne. Un poste en retard de version qui écrit
dans une colonne supprimée provoque une erreur `42703`, rejouée indéfiniment :
la file de synchronisation est **bloquée** (`CLAUDE.md`, `_fatalResponseCodes`).
Donc :

1. **Version N de l'app** : elle n'écrit plus et ne lit plus ce qu'on va
   retirer. La base reste intacte.
2. **Diffusion** de N par le canal de mise à jour, et vérification que les
   postes l'ont prise (`build_number`).
3. **Seulement ensuite**, la base : désactivation, puis suppression.

Avec zéro client privé connecté, la fenêtre est courte. Mais la règle doit
devenir une habitude **maintenant**, avant le premier client.

### 5.2 Les données publiques : sauvegarder, puis purger
Les 30 écoles et 8 258 élèves du secteur public, les 287 comptes, les
2 licences et les factures ministérielles **ne doivent pas rester** dans une
base qui ne sert plus que le privé : ce sont des données personnelles de
mineurs sans finalité. Mais on ne détruit rien sans :
- une **exportation complète** de ces groupes (CSV par table, hors dépôt git,
  sur support chiffré) ;
- la **désactivation des comptes** avant suppression (les 3 comptes METP
  actifs doivent être prévenus) ;
- **ton accord explicite**, groupe par groupe.

`delete_school_group` refuse aujourd'hui de supprimer un ministère (0179) :
il faudra retirer le rôle, puis supprimer.

### 5.3 Ordre des chantiers
| # | Chantier | Pourquoi dans cet ordre |
|---|---|---|
| 0 | **Facturation** : C1, C2, quota du gratuit, assiette | c'est désormais le seul revenu, et c'est indépendant du reste |
| 1 | **Décisions** (§ 7) + sauvegarde des données publiques | rien d'irréversible avant |
| 2 | **App N** : retrait des écrans et providers A, B, C, D ; réduction de E | le plus gros volume, sans risque base |
| 3 | **Diffusion de N** | la règle d'or |
| 4 | **Base** : purge des groupes publics, puis suppression des tables, fonctions, colonnes et plans ministériels ; sync-rules et schéma local | après N, jamais avant |
| 5 | **Modèle privé** : tutelle et agrément par école, RH employeur privé, catalogue d'examens au super_admin | demande de vraies décisions métier |
| 6 | **UX « une école »** | quand le modèle est stable |
| 7 | **Documentation** : `CLAUDE.md`, `ANALYSE.md`, mémoire | `CLAUDE.md` parle encore de « commande MEPSA + METP » |

### 5.4 Les garde-fous
- Chaque suppression de base passe d'abord par une **transaction annulée**
  qui montre ce qui serait touché.
- `flutter analyze` à 0 et `flutter test` vert à chaque étape. Les **98 tests
  « sondes de source »** qui lisent `lib/` comme du texte tomberont en masse :
  les supprimer avec le code qu'ils gardaient, **dans le même commit**.
- Une branche dédiée, `feat/recentrage-prive`, avec des commits par bloc
  (A, B, C, D, E) : chacun est réversible séparément.

---

## 6. Mon avis à chaque niveau

**Produit.** Le positionnement « un seul tableau de bord pour un promoteur
multi-écoles » est clair et vendable ; c'est la vraie douleur du privé
congolais. Mais il faut le **démontrer sur un client réel**. Je recommande de
choisir dès maintenant un groupe pilote réel (un promoteur de 2-3 écoles) et
de tout prioriser sur ses besoins.

**Commercial.** Le prix qui suit le nombre d'écoles est juste. Un plan gratuit
dont le quota ne tient pas (237 élèves pour 100) n'est pas un plan, c'est une
fuite : à corriger avant d'ouvrir les inscriptions.

**Architecture.** L'offline-first avec PowerSync reste **le bon choix** :
la connectivité ne change pas parce que le client est privé. Le double chemin
de données (admin de groupe en ligne, personnel hors ligne) reste pertinent.
La licence signée hors ligne aussi, et elle compte davantage maintenant que
chaque client paie.

**Base de données.** C'est le point le plus préoccupant, au-delà du recentrage.
Le ledger compte 177 migrations, le dépôt 155 fichiers : **la structure
réelle n'est pas reproductible depuis le dépôt**. Bonne pratique : générer un
**schéma de référence** (`supabase db dump --schema-only`) versionné après le
recentrage, et repartir de là. C'est aussi le moment idéal : on va retirer
50 fonctions et des dizaines de colonnes, autant partir d'une photo propre.

**Code.** 274 000 lignes, 72 fichiers au-delà de 500 lignes. Retirer 22 000
lignes ministérielles est un bon début, pas une fin. Après le recentrage, je
recommande une passe « inventaire des écrans réellement utiles à un
promoteur » plutôt qu'une refactorisation générale.

**Tests.** 256 fichiers de test, dont 98 sondes de source : ce sont des tests
fragiles (ils échouent quand on renomme, et restent verts quand le
comportement casse — la mémoire en parle). Pour le code neuf, je préfère des
tests de **comportement** (providers, fonctions pures, RPC en transaction
annulée).

**Sécurité.** La RLS est sérieuse et les escalades connues sont fermées. Le
recentrage **réduit** la surface : toutes les RPC `SECURITY DEFINER` de
tutelle lisaient au-delà du groupe de l'appelant ; elles disparaissent. Reste
à retirer `EXECUTE` à `PUBLIC` sur les fonctions qui restent.

**Exploitation.** La boucle de facturation nocturne réussit en silence même
quand elle n'émet rien (C2). Une plateforme qui vit d'abonnements a besoin
d'une **alerte** quand une échéance passe sans facture émise.

**Documentation.** `CLAUDE.md` décrit encore une « commande MEPSA + METP » et
le rôle des ministères ; la mémoire projet contient une quinzaine de fiches
ministérielles. Après le recentrage, elles deviennent des pièges : elles
diront à la prochaine session de protéger un ministère qui n'existe plus. Les
réécrire fait partie du chantier.

**Correction de l'audit du matin.** J'y ai écrit qu'un plan public n'était
jamais soumis au hard-lock. C'est inexact pour l'émetteur actuel :
`license-issuer` émet `hard_lock: true` pour **tous** les groupes (ADR-0009).
Le reste de C3 tient, mais il est désormais sans objet.

---

## 7. Les décisions qui t'appartiennent

1. **Purge des données publiques** (30 écoles, 8 258 élèves, 287 comptes) :
   export puis suppression ? Et faut-il prévenir les 3 comptes METP actifs ?
2. **Tutelle et agrément par école** (§ 3.1, 3.2) : tu valides ?
3. **Statuts du personnel privé** (§ 3.3) : la liste CDI / CDD / vacataire /
   stagiaire / prestataire / bénévole te convient-elle ?
4. **Inspections** : supprimer, ou garder en texte libre ?
5. **Carte des écoles** : suppression totale de la vue régionale, ou une
   simple carte des écoles du groupe (≈ 300 lignes au lieu de 7 700) ?
6. **Un groupe pilote réel** : as-tu un promoteur en tête ?

## 8. Ce que je propose de faire en premier
**Chantier 0 (facturation)**, tout de suite : il ne dépend d'aucune de ces
décisions, et c'est le seul revenu de la nouvelle plateforme. Puis la
sauvegarde des données publiques et le chantier 2 dès que tu as tranché le
point 1.
