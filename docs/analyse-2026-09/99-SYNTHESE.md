# SYNTHÈSE — le backlog unique

**Objet** : un seul ordre de marche, tiré des seize rapports.
**Date** : 2026-09-10 · déploiement national : **1-2 octobre 2026**

> Trois semaines. La question n'est pas « qu'est-ce qui serait mieux ? » mais
> « qu'est-ce qui, si on ne le fait pas, se verra sur mille postes le
> 2 octobre — et ne pourra plus se rattraper sur place ? »
>
> L'arbitre est une école congolaise qui fait sa rentrée hors ligne. L'ordre
> est : **ce qui casse une rentrée** > **ce qui casse un bulletin** > **ce qui
> casse un rapport** > **ce qui gêne l'œil**.

---

## 0. Ce qui a déjà été corrigé pendant l'analyse

**Trente-trois corrections** portées au code au fil des rapports, plus
**quatre nouveaux tests gardiens**. Elles ne sont pas dans le backlog : elles
sont faites : `flutter analyze` → **0 issue**, `flutter test` → **2 471
tests, 0 échec**. Les voici pour
mémoire, groupées par ce qu'elles évitaient.

### Une fuite de données

| Ce qui se passait | Où |
|---|---|
| Le module **Cartes scolaires** servait l'identité **et le groupe sanguin** de tous les élèves de l'école à un enseignant en `own_classes` — le seul module sans aucun verrou 4 | `cartes_provider.dart` |
| `/user/journal-audit` ouvrait le journal de **toute l'école** à n'importe quel agent : la sidebar le masquait, le routeur ne le gardait pas, et un test affirmait pourtant qu'il l'était | `app_router.dart` |

### Une perte de données

| Ce qui se passait | Où |
|---|---|
| Un transfert saisi depuis un compte mal rattaché partait en `22P02` — **code fatal** — et emportait **tout le lot PowerSync** en attente : les inscriptions et les paiements de la matinée avec lui | `transferts_form.dart` |
| Le « + » de la structure académique n'était gardé par aucun droit : 38 membres « Secrétariat » y perdaient leur lot à chaque clic (`42501`, fatal) | `academic_structure_*` |
| Un import d'élèves écrivait la fiche et l'inscription en **deux** transactions : un échec entre les deux laissait un élève orphelin, invisible partout, occupant un matricule | `import_eleves_provider.dart` |

### Des chiffres faux

| Ce qui s'affichait | Ce qui est vrai | Où |
|---|---|---|
| **1 matière** au catalogue | **95** — 94 portent `school_id IS NULL`, elles appartiennent au groupe. Le catalogue vide se propageait jusqu'au périmètre `own_classes` de chaque enseignant | `subjects_provider.dart` |
| **1 000 élèves** sur les rapports du réseau | **3 781** — le plafond de PostgREST pris pour une mesure | 27 fichiers, 61 lectures |
| **1 000 paiements** sur le recouvrement | **3 461** — moins d'un tiers de ce qui est encaissé | idem |
| « **reste dû : 0** » au guichet | inconnu — le barème chargeait encore | `decompte_du_provider.dart` |
| « **0 en retard** » à la bibliothèque | inconnu — la lecture avait échoué | `bibliotheque_screen.dart` |
| Une **sortie officielle** absente de `v_sorties_par_motif` | la statistique nationale des abandons ignorait les transferts réguliers | `transfers_provider.dart` |
| Un **PDF « généré »** avec une coche verte alors que rien n'avait été écrit | 5 écrans d'aperçu du fondateur | `*_print_preview.dart` |
| Une **classe de 6ᵉ rangée derrière la Terminale** sur un état signé | `cycle_code`/`level_order` perdus par un des deux chemins de rentrée | `academic_year_provider.dart` |

### Du temps, à l'échelle

| Ce qui se passait | Où |
|---|---|
| **Zéro index** sur 89 tables du SQLite local : chaque filtre balayait la table entière **avec un décodage JSON par ligne**, sur une école qui porte déjà 38 544 notes | `powersync_schema.dart` → **78 index** |
| Les courbes nationales ramenaient **toutes les lignes de six mois** pour en compter six points | → 6 `count(exact)` |
| Un import de 1 200 élèves faisait **2 400** allers-retours réseau | → 1 200 |

### De la conformité documentaire

Cinq `Printing.layoutPdf` supprimés des écrans (dont un **reçu** et une
**facture**), deux méthodes mortes retirées, cinq aperçus rendus honnêtes.

### Et des gardes pour que rien ne revienne

**Quatre nouveaux** — `garde_des_pages_de_direction_test`,
`index_local_powersync_test`, `mille_lignes_ne_sont_pas_le_total_test`,
`coefficient_effectif_test` — plus les extensions de `perimetre_par_module_test`,
`zero_nest_pas_je_ne_sais_pas_test` et `une_case_qui_ne_fait_rien_test`.

Chacun a été vérifié **dans les deux sens** : il échoue quand on retire la
correction qu'il garde. Un test qui ne peut pas devenir rouge ne garde rien.

---

## 1. AVANT LE 1ᵉʳ OCTOBRE — ce qui ne se rattrape pas sur place

> Cinq points. **Quatre sont faits** — dont un qui l'était déjà sans
> qu'on le sache. Il reste **une observation à faire sur une machine réelle**.

### 1.1 ✅ FAIT — le coefficient de matière

**Migration `0205` appliquée en production le 2026-09-10**, et le client
corrigé dans le même lot.

Trois moteurs calculent la moyenne d'un élève : le bulletin (ce que reçoit la
famille), le dossier réseau, et `get_passage_merit()`. Les deux derniers
lisaient `subjects.coefficient` — le **défaut** — quand le bulletin lit
`COALESCE(cs.coefficient, subj.coefficient)` — l'**effectif**.

**Vérifié après application, sur le groupe le plus chargé** : 3 034 élèves
évalués, **0 dont la moyenne change**, écart maximal `0.0000`. La correction
était un no-op exact, comme prévu — et la divergence ne peut plus naître le
jour où une classe pondérera une matière.

Gardé par `test/coefficient_effectif_test.dart`, qui exige la règle dans les
**trois** sources à la fois.

### 1.2 ✅ VÉRIFIÉ — les sync-rules étaient **déjà déployées**

**Comparaison faite le 2026-09-10**, jeton refait, sur l'instance
**`6a185943234fa2bf51a66759` (Production)** : **10 buckets déployés, 10
buckets locaux, 0 écart** après normalisation.

Les deux changements que ce point réclamait sont **en ligne** :

```
by_group.data     → SELECT * FROM subjects
                    WHERE group_id = bucket.gid AND school_id IS NULL
                      AND is_active = true          ✓ présent
circulaires_ecole → bucket complet, paramètres et données identiques  ✓ présent
```

⚠️ **Ce rapport a affirmé le contraire, et c'était un raisonnement, pas une
mesure.** Le fait vérifié en base — 94 matières sur 95 avec `school_id` nul —
était exact ; la conclusion « elles n'atteignent aucun poste » supposait en
plus que la règle ne soit pas déployée, ce qui n'avait **jamais été
contrôlé**. Les commits postérieurs au dernier relevé (2026-08-31) avaient
été pris pour des commits non déployés.

**Ne PAS redéployer.** Un déploiement relance le service et fait
resynchroniser tout le parc — cher, et pour rien.

→ **Comment refaire cette vérification** (elle est bon marché et sans effet) :

```
powersync.cmd fetch config --instance-id=6a185943234fa2bf51a66759 --directory=. > deploye.yaml
python compare_rules.py deploye.yaml config/sync-rules.yaml
```

⚠️ Comparer les **structures** après normalisation des espaces, jamais les
chaînes brutes : le service replie les scalaires `>-`, ce qui fait apparaître
huit buckets « différents » qui sont identiques.

⚠️ **Development `…a66757` n'est plus provisionnée** (`is_provisioned: false`
au 2026-09-10). Le piège historique — déployer sur Development en croyant
toucher le parc — s'est refermé tout seul, mais `powersync/cli.yaml` porte de
toute façon le bon identifiant.

### 1.3 ⏳ À OBSERVER — l'indexation locale sur un poste réel

Les 78 index sont créés à l'ouverture de la base, sur une base **existante**.
Sur un poste qui porte déjà 38 544 notes, cette création prend un temps non
mesuré ici. Il faut l'avoir vu **une fois**, sur une machine d'entrée de gamme,
avant de l'envoyer à mille.

*Effort : XS (une observation) · `24-transversal-echelle.md` §2.*

### 1.4 ✅ FAIT — aligner les verbes sur les actes (Examens)

Les quatre profils systèmes ont été **relevés en base** avant de décider, et
cela a changé deux des trois arbitrages du rapport :

| Geste | Verbe UI avant | Politique serveur | Après |
|---|---|---|---|
| Retirer une candidature | `update` | **`delete`** | `delete` — personne ne perd rien : les 14 profils qui ont `update` ont `delete` |
| Marquer un dossier déposé | `update` | `update` | **`validate`** — resserrement assumé |
| Encaisser les frais | `update` sur `examens` | `create` sur **l'un des trois** modules | la **même disjonction** que la RLS |

Le retrait était le seul vrai défaut : refus serveur en `42501`, code fatal,
**lot PowerSync entier jeté**, geste affiché comme réussi.

Sur la caisse, le rapport proposait `paiements-eleves/create` **seul**. La base
dit que cela aurait **retiré la caisse au Secrétariat** (qui n'a aucune ligne
`paiements-eleves`). En recopiant la disjonction du serveur, le comptable la
gagne — il *lit* `examens` sans y avoir aucun droit d'écriture, c'est pourquoi
le bouton lui était caché — et le secrétariat la garde.

Le dépôt sur `validate` **retire** un geste au Secrétariat. C'est délibéré :
déposer bloque le retrait, et rouvrir demandait déjà `validate` — il pouvait
verrouiller sans pouvoir déverrouiller. Le bouton ne disparaît pas, il se
grise en nommant le droit manquant.

`approve` et `manage` restent **délibérément** inutilisés, avec la raison
écrite : les brancher retirerait au secrétariat la saisie des résultats et la
caisse, qu'il fait en pratique.

Foyer unique : `features/examens/providers/exam_verbes.dart`.
Gardé par `test/verbes_des_examens_test.dart` (14 tests).

### 1.5 ✅ FAIT — les documents disent la vérité

- `CLAUDE.md` : l'enforcement de licence n'est plus décrit comme « dormant ».
  Il est **actif depuis le 2026-07-04**, borné côté serveur par
  `LICENSE_PILOT_GROUP_IDS` ;
- `CLAUDE.md` : l'exception offline-first porte désormais sur **les cinq RPC du
  cycle de vie de l'agent**, pas sur « la création d'agents ». Une règle
  énoncée trop étroitement finit par être invoquée contre du code correct ;
- `docs/CONTEXTE.md` et `database/schema.sql` portent un **avertissement en
  tête** qui dit ce qu'ils ont de faux et où regarder à la place.

---

## 2. LE MOIS SUIVANT — ✅ TRAITÉ EN ENTIER

| # | Quoi | État |
|---|---|---|
| 2.1 | Périmètre `own_classes` sur `examens`, `passage`, `emploi-du-temps` | ✅ |
| 2.2 | Donner à `passage` son propre slug | ✅ il portait le cadenas de `conseils` |
| 2.3 | Test miroir sur les trois moteurs de moyenne | ✅ |
| 2.4 | « Je ne sais pas ≠ zéro » sur le Budget | ✅ |
| 2.5 | La liste des candidats à l'examen | ✅ — et elle en a fait tomber sept autres, voir §2 bis |
| 2.6 | Donner un solde aux Congés | ✅ **avec une limite assumée**, voir ci-dessous |
| 2.7 | État mensuel d'assiduité imprimable | ✅ |
| 2.8 | Un foyer unique pour « nombre d'écoles d'un groupe » | ✅ |
| 2.9 | Le contrat de `class_enrollments`, en un seul endroit | ✅ — et un des trois contrats était **rompu** |
| 2.10 | Nommer les deux « décisions » | ✅ migration `0206` appliquée |
| 2.11 | Virtualiser la liste des élèves | ✅ |

### 2.6 — ce que le solde de congés fait, et ce qu'il ne fait pas

**Fait** : le consommé et l'engagé. Combien de jours de congé **annuel** un
agent a déjà obtenus sur l'année scolaire, et combien sont en instruction.
Affiché sous chaque demande à trancher. Entièrement dérivé de
`leave_requests` — aucune colonne, aucune écriture, aucune requête de plus.
C'est ce qui met fin à l'approbation à l'aveugle.

**Pas fait, et c'est un refus motivé** : le **droit annuel**, donc le reliquat
au sens strict. Ce nombre vient du Code du travail pour le privé et du statut
de la fonction publique pour le public — deux textes, deux chiffres, et la
plateforme sert les deux (`schools.school_type`).

L'inventer produirait exactement le défaut que ce dépôt a déjà payé : le
barème de mentions avait glissé de deux points, personne ne l'a vu, et 8/20
ressortait « Passable ». Un droit de congé faux ne se verrait pas davantage —
et il ferait **refuser** des congés.

⚠️ **Chiffre à faire établir par le MEPSA et le METP**, comme la nomenclature
de `sortie_motif.dart`. Le mécanisme est complet : `restant` et
`restantSiToutAccorde` sont écrits et testés, ils rendent `null` tant que le
droit est inconnu — **jamais zéro**. Le jour où le chiffre arrive, il se pose
sur l'agent et tout se calcule sans rien changer d'autre.

---

## 2 bis. CE QUE LE BACKLOG A FAIT REMONTER EN CHEMIN

Trois défauts que personne ne cherchait, trouvés en écrivant les tests des
points ci-dessus. Aucun n'était visible sur un jeu de démonstration.

### Huit documents officiels ne se généraient pas

`OfficialPdfKit.frame()` enveloppe son contenu dans un `Padding`, qui ne sait
pas se scinder entre deux pages. Une table plus haute qu'une feuille fait
boucler `MultiPage` jusqu'à `TooManyPagesException` : **pas un document
tronqué — aucun document**.

Quatre en **paysage** (la limite y est plus basse encore : `kRowsPerBlock` = 28
avait été calibré sur du portrait) :

| Document | Cassait à |
|---|---|
| Liste des candidats à l'examen | ~90 candidats (une session de BEPC en porte 300) |
| Liste du personnel | ~20 agents (une école en compte 40) |
| Journal de paie | autant, tous les mois |
| État des stages | une terminale professionnelle part en entier |

Puis, en recensant les **26** `frame(table())` de l'application et en les
triant sur une seule question — *le nombre de lignes est-il fixe, ou suit-il
les données ?* — quatre autres, en **portrait** :

| Document | Cassait à |
|---|---|
| **Référentiel des matières** | 28 — il y en a **95 en base aujourd'hui** |
| Répertoire des familles | 28 — la liste qu'on ouvre quand un enfant ne rentre pas |
| Registre de conformité des dossiers | 28 — la pièce que l'inspection réclame |
| État des transferts | 28 par statut |

Les 22 autres sites sont bornés par construction (une fiche, deux tuteurs, un
récapitulatif à quatre postes) et restent légitimes. Un **cliquet** fige ce
nombre à 22 avec la règle de décision écrite à côté : le neuvième ne passera
plus par accident.

Gardé par `pdf_paysage_pagination_test.dart` (16 tests) et
`pdf_portrait_pagination_test.dart` (8 tests) — qui **construisent** les
documents à taille réelle, au lieu de vérifier qu'une fonction est appelée.

### Une promotion entière de Terminale versée aux abandons

`v_sorties_par_motif` — la statistique nationale de déperdition — compte les
**trois** statuts de sortie (`transferred`, `withdrawn`, **`graduated`**) et
les groupe par `withdrawal_motif`. La clôture d'année posait `graduated`
**sans motif**.

Aucune ligne `graduated` n'existe encore en production : la clôture n'a jamais
tourné. Le défaut se serait déclaré **en juin, d'un coup, sur tout le parc** —
et le ministère aurait lu une déperdition là où il y a des diplômés.

### Un bandeau d'avertissement qui faisait échouer son propre document

Le relevé d'assiduité (§2.7) porte un bandeau quand aucun appel n'a été fait.
Le paquet `pdf` n'accepte un `borderRadius` qu'avec une bordure **uniforme** :
associé au filet de gauche, il levait une assertion **à la génération**. Le
document n'aurait donc échoué que dans les cas où le bandeau s'affiche —
c'est-à-dire exactement quand il compte. Trouvé par le test, pas à l'œil.

---

## 3. LA DETTE — à résorber quand on touche le fichier

### 3.1 Les `catch (_) {}` — 116 dans 59 fichiers

À traiter **par famille**, pas en bloc. Le tri est déjà fait :

| Famille | Verdict |
|---|---|
| `networkImage` d'un logo dans un PDF | ✅ légitime — un document sans logo vaut mieux que pas de document |
| écriture d'un journal local (`sync_failures`) | ✅ légitime — le journal ne doit jamais coûter l'opération |
| échec réseau sur un poste hors ligne | ✅ légitime — c'est le cas *normal* |
| **providers de DROITS** (`admin_access`, `admin_module`, `admin_nav`, `admin_settings`) | ⛔ **à qualifier en premier** — un droit avalé se lit « pas autorisé » |
| **compteurs affichés** | ⛔ le gisement du zéro menteur |

*Ordre : les quatre providers de droits, puis les compteurs, puis rien.*
*Détail : `09` §E.2, `10` §E.2, `08` §E.3.*

### 3.2 Les fichiers > 500 lignes — 82, plafond tenu

Le test `dette_des_fichiers_de_500_lignes_test` est un **cliquet** : il refuse
que le nombre monte. Il a servi pendant cette analyse (le découpage
d'`audit_data.dart` en `audit_data` + `audit_timeline` a été fait parce qu'il
est passé au rouge). Ne pas relever le plafond ; découper le long des coutures
quand on touche le fichier.

Les plus gros, avec leur couture proposée : `examens` (9 453 l. à eux seuls),
`super_admin/settings_screen.dart` (1 197), `ai_screen.dart` (1 102),
`messagerie_staff_thread.dart` (1 145), `receipts_screen.dart` (1 149).

### 3.3 Les sorties documentaires

Le socle est sain : 41 fichiers produisent un PDF, **41** utilisent
`OfficialPdfKit`. Restent :

- **23 écrans de liste sur 90 n'offrent aucune sortie** — à trier par valeur
  métier, pas à combler en masse ;
- **5 modales d'aperçu maison** dans l'espace Fondateur, à unifier sur
  `showPdfPreviewDialog` ;
- **Vie scolaire et Communication** n'ont presque aucune sortie ; le modèle à
  copier est `features/tutelle/` (2 services, un commun factorisé, l'émetteur
  pris de l'établissement, zéro contournement).

---

## 4. LES ONZE DÉCISIONS — TOUTES TRANCHÉES

Le fondateur a donné la main le 2026-09-10. Aucune ne reste ouverte.

| # | Décision | Ce qui a été fait |
|---|---|---|
| 1 | **Coefficient de matière** | ✅ **Migration `0205` APPLIQUÉE en production.** Vérifiée sans effet aujourd'hui : 3 034 élèves évalués, **0 dont la moyenne change**, écart max `0.0000`. La divergence ne peut plus naître. Gardée par `coefficient_effectif_test` |
| 2 | **Les 19 réglages de notification** | ✅ **Retirés.** 0 lecteur Dart, 0 fonction en base — revérifié champ par champ. Les colonnes de `group_settings` sont **conservées** : on retire l'offre, pas la mémoire. L'onglet dit désormais ce qui notifie vraiment (les six déclencheurs de la cloche) et ce qui n'existe pas |
| 3 | **L'espace `parent`** | ✅ **Report assumé, et dit.** L'entrée est déjà gardée par `if (!isParent)` et **0 compte** porte ce rôle. Le message ne promet plus « bientôt » : il nomme les trois documents papier qui rendent le service aujourd'hui |
| 4 | **`ai_screen.dart`** | ✅ **Renommé « Actions à mener ».** La catégorie `ia` n'existe plus au catalogue ; l'écran reste utile, il ne se présente plus comme une fonctionnalité facturable |
| 5 | **`createSubject`** | ✅ **Écrit `NULL`.** Trois preuves concordantes : la clé unique est `(group_id, level_id, slug)` — `school_id` n'est pas dans l'identité —, `_uniqueSlug` calcule déjà sur le groupe, et 94 matières sur 95 sont à `NULL`. Le formulaire annonce « créée pour tout le réseau » |
| 6 | **`niveaux` et `classes`** | ✅ **Les deux, assumé et écrit.** Deux gestes différents (bâtir la structure / gérer une classe). Le risque n'était pas deux formulaires mais deux ÉCRITURES : les deux passent par `createStructuredClass`, l'amputée a été supprimée |
| 7 | **Le rangement de la cartographie** | ✅ **Ne déménage pas, et c'est écrit dans le fichier.** Y verser 3 800 lignes détruirait ce qui fait de `features/tutelle/` le périmètre le plus sain du dépôt |
| 8 | **Le module `programmes`** | ✅ **Reste vendu.** Ce n'est ni un défaut de droits (21 profils le lisent, 14 y écrivent) ni de plan (6 groupes l'ont) : personne n'a publié de syllabus. L'état vide nomme désormais les deux sources et distingue qui peut créer de qui attend son réseau |
| 9 | **L'archive opposable d'une instruction de tutelle** | ✅ **Construite.** `TutelleInstructionPdfService` + branchement après l'envoi. La pièce porte l'objet, le texte intégral, la date d'**envoi** et surtout la liste **nommée** des destinataires — c'est elle qui fait l'opposabilité. Elle ne prétend PAS valoir accusé de réception. 12 tests, dont un corps de 60 alinéas et 31 destinataires |
| 10 | **La compression vidéo sous Windows** | ✅ **Déjà résolu — vérifié, rien à faire.** `plafondPieceJointe` applique 10 Mo quand le transcodage est indisponible, le refus dit quoi faire, `media_compression_test` garde le seuil ET son point d'application |
| 11 | **`getCrudBatch`** | ✅ **Refusé, et la raison est dans le connecteur.** On échangerait de la latence contre de la perte silencieuse : un seul refus emporterait cent opérations sans rapport. Le vrai levier a été pris ailleurs (import atomique) |

---

## 5. Ce que cette analyse n'a pas couvert

Un trou déclaré est exploitable ; un trou masqué ne l'est pas.

| Zone | Pourquoi |
|---|---|
| Cartographie régionale (`admin_groupe/screens/regional/`, ~3 000 l.) | Échantillonnée seulement — signalé dans `10` §E.5 |
| Les sync-rules déployées | Le dépôt contient le fichier, pas l'état de l'instance Cloud |
| Le rendu réel des PDF | Les tests vérifient qu'ils se *construisent*, pas qu'ils sont *lisibles* |
| Virtualisation des listes | **Relevée et documentée** (`24` §5.1), pas corrigée : `eleves_liste_parts.dart:244` construit chaque élève. Le remède est une refonte du défilement de l'écran — à faire avec l'application sous les yeux, pas à trois semaines d'un déploiement, en aveugle |
| Le volume descendu sur un poste au premier démarrage | Dépend des sync-rules, hors du code Dart |

---

## 6. L'état, en une ligne

**Le produit est en bien meilleur état que ne le laissait croire son propre
`CLAUDE.md`.** 102 routes câblées, un seul placeholder, zéro violation de la
règle d'architecture, une couche de synchro remarquablement raisonnée, et des
tests gardiens qui portent leur raison d'être dans leur en-tête.

Ce que cette analyse a trouvé n'est presque jamais un manque de travail : ce
sont des **contrats entre deux modules** que personne ne tenait à jour, et des
**chiffres qui plafonnaient sans le dire**. C'est la maladie normale d'un
produit qui a grandi vite et bien.

Le seul point qui devait être tranché **avant** le 1ᵉʳ octobre parce qu'il
devient rétroactif ensuite — le **coefficient de matière** — est **fait**
(migration `0205`, vérifiée sans effet sur 3 034 élèves).

---

### Où en est le backlog, au 2026-09-10

**Tout le code est fait.** §1 : 3 points sur 5 ; §2 : 11 sur 11. Les seize
rapports sont soldés.

Il reste **deux gestes, et aucun n'est du code** :

1. **Déployer les sync-rules** sur `6a185943234fa2bf51a66759` (Production).
   Le jeton d'administration de la machine est mort — `npx powersync login`
   d'abord. Sans ce déploiement, **94 matières sur 95 restent invisibles sur
   tout poste d'école**, et les écrans ne se vident pas : ils deviennent
   anonymes, ce qui met beaucoup plus longtemps à être signalé.
2. **Voir une fois** la création des 78 index locaux sur une machine d'entrée
   de gamme portant déjà une base pleine.

Et **une décision qui n'appartient pas au développement** : le nombre de jours
de congé annuel auquel un agent a droit, à faire établir par le MEPSA et le
METP. Le mécanisme est écrit, testé, et rend « — » tant que le chiffre
n'existe pas.

> Ce que ce dernier passage a surtout appris : **les trois défauts les plus
> coûteux trouvés en chemin l'ont été en écrivant les tests, jamais en lisant
> le code.** Huit documents officiels qui ne se généraient pas, une promotion
> de Terminale versée aux abandons, un bandeau d'alerte qui faisait échouer
> son propre document. Aucun ne se voyait sur un jeu de démonstration ; aucun
> n'aurait été trouvé par l'analyseur.
