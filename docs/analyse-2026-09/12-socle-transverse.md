# SOCLE TRANSVERSE — analyse

**Périmètre** : ce qui ne se vend pas et que tout le monde traverse —
`features/auth/`, `features/profil/`, `features/audit/`,
`features/navigation/` + `core/widgets/app_shell/`, `features/user/`
(tableau de bord, rapports, paramètres), `features/updates/`, `licensing/`,
`services/powersync/`.
**Volume** : 117 fichiers, **27 034 lignes**
**Date** : 2026-09-09 · analyse conduite directement (sans agent)

> **Pourquoi ce périmètre est le plus dangereux de l'analyse.**
> Un défaut de module touche les écoles qui ont acheté ce module. Un défaut de
> socle touche **tout le monde, sur tous les postes, dès le premier écran** —
> et il n'a pas de propriétaire métier pour s'en plaindre.

---

## A. Vue d'ensemble

Le socle porte huit responsabilités, toutes indispensables au 1ᵉʳ octobre :

| Responsabilité | Où |
|---|---|
| Ouvrir une session, la reprendre, la partager sur un poste | `auth/` (27 f., 7 947 l.) |
| Sa propre fiche, pour les trois espaces | `profil/` (13 f., 2 109 l.) |
| Qui a fait quoi | `audit/` (15 f., 4 364 l.) |
| Où l'on a le droit d'aller | `navigation/` + `app_shell/` (16 f., 3 379 l.) |
| Le premier écran, les rapports de direction, les réglages du poste | `user/` (22 f., 4 577 l.) |
| Savoir qu'une correction existe | `updates/` (4 f., 648 l.) |
| L'abonnement — ⚠️ **plus dormant** : pilote depuis le 2026-07-04 | `licensing/` (12 f., 898 l.) |
| La base locale et sa remontée | `services/powersync/` (8 f., 3 112 l.) |

**Le socle est globalement en bon état** : la cascade des quatre verrous est
posée, documentée et gardée par des tests ; la couche PowerSync est le code le
mieux commenté du dépôt ; le module licence est un îlot hexagonal propre, dont
le rollout est borné côté serveur. Le rapport porte donc sur **quatre défauts
réels** et sur ce qui, à l'échelle du parc, ne tiendra pas.

Un seul défaut de ce rapport est de nature **sécurité**, et il a été corrigé le
jour même — voir B ▸ *Journal d'audit*.

---

## B. Fiche par écran / composant

### Le journal d'audit — `/user/journal-audit`, `/admin/audit`, `/super/audit`

| | |
|---|---|
| Écran | `AuditScreen` — `features/audit/screens/audit_screen.dart` (247 l.) |
| Mode | **en ligne**, dans les trois espaces (`supabase.from('audit_logs')`) |
| Portée | `auditScopeProvider` — groupe pour `super_admin`/`admin_groupe`, école pour la direction (`audit_scope.dart:87`) |
| Profondeur UI | **L3** — filtres, tri, KPI, graphiques, export, états vides et d'erreur traités |
| Sortie document | conforme (`audit_export_dialog.dart`) |

**Ce que le module fait** — répond à une seule question, « qui a fait quoi »,
avec un plancher de visibilité non décochable : on ne voit jamais les actions
d'un niveau au-dessus du sien (`hiddenActorRolesForViewer`,
`audit_scope.dart:71`). Un seul code pour trois espaces, un seul point de
divergence : la portée. C'est le module transverse le mieux fait de la
plateforme.

**⛔ CE QUI MANQUAIT — la garde de route (CORRIGÉ le 2026-09-09).**

`Routes.userAudit` porte, dans `routes.dart:101`, le commentaire
`// natif direction (online)`. `socle_natif.dart:220` la range dans
`ZoneNav.etablissement`, dont le commentaire dit :
« Configs natives **réservées à la direction** de l'établissement ». Et
`nav_config.dart:378` masque effectivement le bloc à tout rôle hors
`AppConstants.directionRoles`.

Mieux : `test/toute_page_ecole_est_un_module_test.dart:64` lui accordait une
dispense de verrou de module, avec cette raison écrite noir sur blanc :

> `'/user/journal-audit': 'Journal de direction (online). Gardé par le rôle, pas par un module.'`

**Le routeur ne la gardait pas.** Le `redirect` d'`app_router.dart` ne nommait
que `Routes.calendrier` et `Routes.userRapports`. Un enseignant, un
surveillant, un élève tapant l'URL ouvrait le journal de **toute son école** :
qui a modifié quelle note, encaissé quel paiement, touché à quel dossier du
personnel.

Ce n'est pas une fuite inter-établissements — la RLS tient le `school_id`, et
le plancher de visibilité masque bien `super_admin` et `admin_groupe`. C'est
**la page de gouvernance de l'école ouverte à qui n'a pas à la voir**, dans un
produit qui a par ailleurs pris soin de la masquer partout ailleurs.

> Une barre de navigation n'est pas un verrou : elle ne garde que le chemin
> qu'on a prévu. C'est exactement la leçon déjà tirée pour `/user/passage` —
> et une dispense qui s'appuie sur une garde inexistante est **pire** que pas
> de dispense, parce qu'elle rassure.

*Correction* : `Routes.userAudit` ajoutée au garde `directionRoles`
(`app_router.dart:299`), et un nouveau test —
`test/garde_des_pages_de_direction_test.dart` — confronte désormais les
**trois** fichiers qu'on n'édite jamais ensemble : `socle_natif.dart` (ce qui
est déclaré « de direction »), `app_router.dart` (ce qui est réellement gardé)
et la table des dispenses. Vérifié dans les deux sens : le test échoue quand on
retire la ligne.

**⚠️ Ce qui reste** — la courbe des 30 jours lit au plus
`kAuditTimelineMax = 5 000` événements. Les compteurs du haut de page sont
exacts (`count(exact)`), mais le graphique et les trois classements ne
portaient, au-delà, que sur une fraction de la période — **sans le dire**.
*Corrigé le 2026-09-09* : la lecture se fait maintenant du plus récent au plus
ancien (la troncature ronge le début de la période, pas les jours qu'on
regarde), `AuditTimeline.tronquee` porte l'information, et un bandeau la dit à
l'écran.

---

### Mon profil — `/user/profil`, `/admin/profil`, `/super/profil`

| | |
|---|---|
| Écran | `MonProfilScreen` — `features/profil/screens/mon_profil_screen.dart` (139 l.) + 5 sections |
| Mode | **les deux** : PowerSync pour le personnel, Supabase pour les deux espaces d'administration |
| Bascule | `ProfileModel.isSchoolStaff` — `mon_profil_provider.dart:103` |
| Profondeur UI | écran de saisie — non noté sur recherche/tri/compteur |
| Sortie document | sans objet |

**Sain, et exemplaire.** Un seul écran pour trois espaces, la bascule
online/offline lue à un seul endroit, et un en-tête qui explique pourquoi
`role`, `access_profile_id`, `school_id`, `group_id`, `is_active` et les
`sync_*` ne sont **jamais** envoyés : le déclencheur `profiles_garde_colonnes_
de_pouvoir` (0188) les gèle silencieusement, donc les envoyer afficherait
« enregistré » sur une valeur inchangée.

`peutModifierSaFiche` mérite d'être cité comme modèle de raisonnement : sur un
poste partagé, la fiche affichée est celle de l'agent au clavier tandis que la
session appartient au compte appareil — une écriture partirait, reviendrait en
`42501`, **code fatal**, et emporterait le lot entier, notes et paiements
compris.

**Ce qui manque** — rien de structurel. `mon_activite_provider.dart:62` lit
`audit_logs` en ligne : cohérent avec le journal d'audit, mais l'écran doit
dire qu'il est vide **faute de réseau** et non faute d'activité (à vérifier à
la recette).

---

### La cascade des quatre verrous — `app_router.dart` (794 l.) + `permissions_provider.dart` (206 l.)

**Le cœur du produit, et il tient.** Quatre verrous en séquence :

1. **rôle** — `/super/*` et `/admin/*` fermés au personnel, `/user/*` fermé aux
   deux espaces d'administration (`app_router.dart:262`) ;
2. **impayé** — `ent.isHardLockedAt(...)` → mur de renouvellement, en
   fail-soft ;
3. **plan puis profil d'accès** — `ent.grantsModule(slug)` puis
   `perms[slug]?.canRead`, `null` = encore en chargement, on laisse passer ;
4. **périmètre** — `data_scope`, traité écran par écran
   (cf. `23-transversal-perimetre.md`).

Ce qui rend l'ensemble crédible, ce sont les tests qui le gardent :
`toute_page_ecole_est_un_module_test` (toute route `/user/*` est un module ou
une exception **écrite avec sa raison**), `class_scope_clause_test`,
`perimetre_par_module_test`, `socle_natif_test`. Et désormais
`garde_des_pages_de_direction_test`, qui ferme le trou décrit plus haut.

⚠️ **La sidebar n'est pas en dur** : `_staffSections` la construit depuis
`modulesGroupedByCategoryProvider × myPermissionsProvider`, et distingue
« en cours de synchro » de « aucun module accordé ». C'est correct, et c'est
aussi ce qui a masqué le défaut d'audit : la barre faisait si bien son travail
que personne n'a vérifié le routeur.

---

### La couche PowerSync — `services/powersync/` (8 f., 3 112 l.)

| Fichier | Rôle | Verdict |
|---|---|---|
| `powersync_schema.dart` (1 708 → 1 865 l.) | déclare 89 tables locales | ⚠️ **déclarait 0 index** — corrigé, voir D.2 |
| `powersync_connector.dart` (376 l.) | JWT + remontée des écritures | ✅ le meilleur code du dépôt |
| `powersync_service.dart` (318 l.) | ouverture, purge, `isStaffRole` | ✅ |
| `upload_outbox.dart` (204 l.) | fichiers en attente | ✅ |
| `sync_failures_provider.dart` | journal local des échecs | ✅ |

**Le connecteur est exemplaire** et il faut le dire, parce que c'est lui qui
tient la promesse offline :

- il distingue le **refus définitif** (`abandon` — écriture perdue, journalisée
  dans la table locale `sync_failures`, visible après redémarrage) du
  **blocage** (`blocage` — rejoué indéfiniment, rien n'est perdu, mais on le
  signale) ;
- `42703`, `42P01`, `42804` sont **délibérément absents** des codes fatals, et
  un test (`sync_blocage_test`) échoue si quelqu'un les y glisse : un
  désaccord de schéma doit rester rejoué, pas jeter les écritures de l'école ;
- la purge locale n'a **qu'un seul** déclencheur — un utilisateur différent
  ouvre une session — et surtout **pas** la déconnexion, parce que Supabase
  émet `signedOut` tout seul après un week-end hors ligne.

**⛔ CE QUI MANQUAIT — l'indexation locale (CORRIGÉ le 2026-09-09).** Voir D.2 :
c'est le défaut le plus lourd de conséquences de tout le socle, et il ne se
serait vu qu'au troisième trimestre.

---

### Le tableau de bord du personnel — `/user/dashboard`

| | |
|---|---|
| Écran | `UserDashboardScreen` — `features/user/screens/user_dashboard_screen.dart` (**613 l.**) + 7 fichiers de parties |
| Mode | 100 % offline (`db.watch`) |
| Profondeur UI | **L3** |

**Bien traité.** `dashboard_chart_parts.dart:22` distingue explicitement le
chargement initial de l'absence de données — « sans ça, l'utilisateur croit
"aucune donnée" pendant la première synchro ». C'est exactement la doctrine du
zéro menteur appliquée d'elle-même.

⚠️ Deux cartes (`_PendingInscriptionsCard`, `_RecentAnnouncementsCard`) font
`valueOrNull ?? const []` puis `if (…isEmpty) return const SizedBox.shrink()`.
Elles n'affichent donc **pas** un faux zéro : elles disparaissent. C'est une
forme douce du travers — une lecture en échec fait disparaître « 12
inscriptions en attente » au lieu de le dire — mais ce n'est pas un chiffre
faux. **Signalé, pas corrigé** : le remède (un bandeau d'erreur sur le tableau
de bord d'accueil) demande un arbitrage d'ergonomie, pas une correction.

---

### Le module licence — `licensing/` (12 f., 898 l.)

**Îlot hexagonal, et le seul du dépôt** : `domain/` (aucune dépendance),
`application/`, `infrastructure/` (Ed25519, coffre sécurisé, passerelle
Supabase, horloge monotone), `presentation/`. Aucun fichier ne dépasse 145
lignes.

⚠️ **Correction à porter au socle de cette analyse** : `00-METHODE.md` et
`CLAUDE.md` décrivent l'enforcement comme « dormant tant que
`licensePinnedKeysProvider` est vide ». **Il ne l'est plus.**
`license_providers.dart:19` porte la clé `2026-07` depuis le **go-live pilote
du 2026-07-04**. Le rollout est borné **côté serveur** par
`LICENSE_PILOT_GROUP_IDS` : les groupes hors pilote reçoivent un 403, donc
aucune licence, donc restent dormants. La documentation est en retard de deux
mois sur le code, et c'est le genre d'écart qui fait conclure de travers.

Le garde-fou C4 tient : **la synchro PowerSync n'est jamais conditionnée à la
licence** — vérifié, `db.connect()` ne dépend que d'`isStaffRole`.

---

### Le canal de mise à jour — `features/updates/` (4 f., 648 l.)

`update_provider.dart` le dit lui-même, et il a raison : **c'est
l'infrastructure la plus importante du 2 octobre.** Sans chemin de mise à
jour, le moindre défaut trouvé après le déploiement est définitif — il
faudrait retourner sur mille postes.

Trois règles, toutes respectées : silencieux en cas d'échec (un poste hors
ligne est le cas *normal*), une seule vérification par session, **jamais**
d'installation automatique. Vérification SHA-256 avant installation.

L'appel Supabase depuis l'espace école est **légitime et argumenté** : une
version publiée n'est pas une donnée d'établissement, elle ne peut pas vivre
dans PowerSync, et télécharger exige de toute façon le réseau.

---

## C. Comment le socle s'enchaîne

```
  DÉMARRAGE ─► splash ─► session ? ──non──► reprise de poste  ──ou──► connexion
                             │                    (le poste se reconnaît et tient
                             │                     encore les données de son école)
                             oui
                             ▼
                    isStaffRole(role) ?
              ┌────────── oui ──────────┐         └── non ──► Supabase direct
              ▼                                              (super_admin / admin_groupe)
     db.connect()  ← ⚠️ JAMAIS conditionné à la licence (C4/ADR-0006)
              │
              ├─► sync-rules décident QUELLES LIGNES descendent
              ├─► SQLite local  ← 89 tables · 78 index (2026-09-09)
              └─► écritures ─► ps_crud ─► connecteur ─► Supabase
                                              │
                                     refus ?  ├── définitif ─► `abandon`  (perdu, journalisé)
                                              └── rejouable ─► `blocage`  (rien de perdu, signalé)

  ROUTAGE : rôle ─► impayé ─► plan ─► profil d'accès ─► périmètre
            (1)     (2)       (3a)    (3b)              (4, écran par écran)
```

**Où la chaîne cassait** : entre (1) et (3). Trois pages de l'école ne sont pas
des modules et sautent donc (3) ; deux étaient rattrapées par (1), la
troisième — le journal d'audit — ne l'était par rien.

---

## D. Synthèse

### D.1 Fonctionnalités manquantes

| # | Manque | Preuve | Impact | Effort |
|---|---|---|---|---|
| 1 | ~~Garde de rôle sur `/user/journal-audit`~~ | `app_router.dart` (avant) ne nommait que `calendrier` et `userRapports` | Le journal de gouvernance de l'école ouvert à tout agent | ✅ **corrigé** |
| 2 | ~~Index du SQLite local~~ | `grep -c "indexes:" powersync_schema.dart` → **0** sur 89 tables | Balayage complet + décodage JSON par ligne sur 38 544 notes | ✅ **corrigé** |
| 3 | ~~La courbe d'audit ne dit pas qu'elle est tronquée~~ | `.limit(5000)` muet | Un début de mois qui paraît calme | ✅ **corrigé** |
| 4 | L'espace `parent` n'existe pas | `/user/espace-parent` → `StaffComingSoonScreen` | Un rôle de l'enum sans espace | **L** |
| 5 | Bandeau d'erreur sur le tableau de bord du personnel | `dashboard_cards_parts.dart:69,144` | Une carte qui disparaît au lieu de dire pourquoi | **S** |
| 6 | `docs` et `CLAUDE.md` disent la licence « dormante » | `license_providers.dart:19` porte la clé depuis le 2026-07-04 | On conclut de travers sur l'état du produit | **XS** |

### D.2 Doublons et redondances

**Néant — et c'est remarquable.** `profil/`, `audit/` et `communication/` sont
des modules **scope-aware** : un seul code, périmètre déduit du rôle. Les
routes `/super/profil`, `/admin/profil` et `/user/profil` mènent au même
écran ; c'est voulu.

`socle_natif.dart` mérite d'être cité : les entrées natives étaient écrites
**trois fois** (deux fois dans `nav_config.dart`, une troisième en base sous
forme de modules) et les copies avaient déjà divergé — « Messages » d'un côté,
« Messagerie » de l'autre, et deux sections COMMUNICATION dans la barre de
chaque agent. Le fichier est la déclaration unique qui a fermé ça, et
`socle_natif_test` garde l'alignement avec le déclencheur SQL 0177.

### D.3 Données partagées

| Donnée | Producteur | Consommateurs | Contrat | Risque si rompu |
|---|---|---|---|---|
| `isStaffRole(role)` | `powersync_service` | routeur, profil, tout provider | **La règle centrale se LIT ici, elle ne se recopie pas** | Un rôle mal classé tue la synchro (bug historique `'utilisateur'`) |
| `myPermissionsProvider` | `navigation` | sidebar, routeur, chaque écran | `null` = chargement, pas « refusé » | Une sidebar vide au démarrage |
| `AppConstants.directionRoles` | `app_constants` | routeur, `nav_config` | Les deux doivent l'invoquer **ensemble** | C'est exactement le défaut corrigé ici |
| schéma local ↔ sync-rules | `powersync_schema` ↔ `sync-rules.yaml` | tout l'espace école | Une table déclarée sans bucket est **effacée** au checkpoint suivant | Écran vide, aucune erreur |
| `sync_failures` | connecteur | `sync_failures_provider`, paramètres | `abandon` ≠ `blocage` | Dire « perdu » sur un blocage fait ressaisir une école pour rien |

### D.4 Conformité export / aperçu / impression

| Composant | Sortie | `OfficialPdfKit` | `showPdfPreviewDialog` | `Printing.layoutPdf(` | Verdict |
|---|---|---|---|---|---|
| Journal d'audit | export | ✅ | ✅ | 0 | ✅ |
| Rapports de direction (`/user/rapports`) | 3 états PDF signables | ✅ | ✅ | 0 | ✅ |
| Mon profil | sans objet | — | — | 0 | — |
| Tableau de bord | sans objet | — | — | 0 | — |

**0 `Printing.layoutPdf(` dans tout le socle.**

### D.5 Cases mortes et zéros menteurs

| # | Composant | Type | `fichier:ligne` | Ce que l'écran prétend | Ce qui se passe |
|---|---|---|---|---|---|
| 1 | Tableau de bord personnel | zéro doux | `dashboard_cards_parts.dart:69` | « pas d'inscription en attente » | la carte disparaît si la lecture échoue |
| 2 | Tableau de bord personnel | zéro doux | `dashboard_cards_parts.dart:144` | « pas d'annonce » | idem |
| 3 | Graphiques d'audit | ~~courbe tronquée muette~~ | `audit_data.dart:215` | la période entière | **corrigé** : bandeau + `tronquee` |

53 `catch (_)` dans le socle, mais **la quasi-totalité sont justifiés et
commentés** (échec réseau normal hors ligne, écriture de journal local qui ne
doit jamais faire échouer l'opération, purge fail-soft). Ce n'est pas le
gisement du zéro menteur ; les vrais se trouvent ailleurs.

### D.6 Dette de structure

Cinq fichiers au-dessus de la cible de 500 lignes — c'est **peu** pour 27 000
lignes :

| Fichier | Lignes | Couture proposée |
|---|---|---|
| `powersync_schema.dart` | 1 865 | **Ne pas découper.** C'est une déclaration, pas de la logique ; la couper ferait perdre la lecture linéaire par phase, et trois tests la lisent au texte. |
| `auth/screens/widgets/vitrine_shell.dart` | 736 | vitrine (messages de service, partenaires) vs. coquille |
| `app_shell/app_header.dart` | 689 | barre de recherche · fil d'ariane · menu de compte |
| `user/screens/user_dashboard_screen.dart` | 613 | déjà entouré de 7 fichiers de parties ; extraire l'en-tête et la grille |
| `auth/screens/widgets/contact_support_drawer.dart` | 597 | formulaire vs. liste des tickets |

### D.7 Désalignements catalogue ↔ code

1. Le journal d'audit est une **page d'école** qui n'est pas un module :
   assumé, désormais gardé, et l'écart est écrit dans deux tests.
2. Le rôle `parent` existe dans l'enum `user_role` et n'a pas d'espace. Le
   seul placeholder de la plateforme.
3. `licensing/` ne suit pas l'organisation `features/<domaine>/` — c'est
   délibéré (îlot hexagonal, ADR-licence) et cohérent.

---

## E. Les cinq choses à faire en premier

1. ~~**Garder `/user/journal-audit` par le rôle.**~~ ✅ Fait le 2026-09-09,
   avec son test dans les deux sens.

2. ~~**Indexer le SQLite local.**~~ ✅ Fait : 78 index sur 44 tables, gardés
   par `index_local_powersync_test.dart`. Voir `24-transversal-echelle.md` —
   c'est le point le plus lourd de conséquences de toute l'analyse.

3. **Mettre à jour ce que disent les documents sur la licence.** `CLAUDE.md`
   et `00-METHODE.md` la décrivent dormante ; elle est en pilote depuis le
   2026-07-04. *Effort : XS. Gain : ne pas conclure de travers en réunion.*

4. **Donner un bandeau d'erreur au tableau de bord du personnel.** Deux cartes
   disparaissent silencieusement quand leur lecture échoue. C'est le premier
   écran que voit chaque agent chaque matin.
   *Effort : S · Entrée : `features/user/screens/dashboard_cards_parts.dart`.*

5. **Trancher l'espace parent.** C'est le seul placeholder du produit, et le
   rôle existe en base. Deux issues honnêtes : le construire, ou retirer le
   rôle de la sidebar et de l'enum d'affichage jusqu'à ce qu'il le soit. Le
   laisser tel quel promet un espace qui n'arrive pas.
   *Effort : L pour construire, XS pour assumer le report.*
