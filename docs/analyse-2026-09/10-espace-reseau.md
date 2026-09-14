# ESPACE RÉSEAU — `admin_groupe` — analyse

**Périmètre** : `features/admin_groupe/` — 245 fichiers, **74 731 lignes**, 147 écrans
**Routes** : `/admin/*` (12 écrans annoncés) · **Mode** : online, Supabase direct
**Date** : 2026-09-09 · analyse conduite directement (sans agent)

> **⚠️ Périmètre déclaré, et il est large.** C'est le plus gros dossier de la
> plateforme — **26 % du code**. Il ne se lit pas intégralement. Méthode :
> balayage mécanique des 245 fichiers (taille, `catch`, `valueOrNull`,
> marqueurs, sorties, accès données), croisement avec la base live, puis
> lecture profonde des points que le socle et la mémoire projet désignent.
>
> **Zones NON couvertes en lecture profonde**, à traiter dans une passe
> ultérieure : la cartographie régionale (`regional_map.dart` 1 045 l.,
> `regional_table_mode.dart` 894 l., `regional_markers.dart` 525 l.,
> `regional_project_dialog.dart` 526 l.), les archives d'examens
> (`exam_archives_provider.dart` 810 l. et les vues associées), et le détail
> des rapports (`admin_reports_provider.dart` 890 l.).

## A. Vue d'ensemble

L'espace du client : un réseau d'écoles piloté par un `admin_groupe`. Il
**gouverne** (écoles, utilisateurs, profils d'accès, modules attribués,
abonnement) et **supervise** (tableau de bord, rapports, carte régionale,
palmarès, élèves du réseau, audit).

**Rappel métier structurant** : l'`admin_groupe` **pilote** les modules, il ne
les **opère pas**. Un écran de cet espace qui refait le travail d'un module de
catalogue est une redondance de conception.

**Ce qui va bien.** La doctrine anti-redondance a été appliquée, et cela se
vérifie : `admin_module_screen.dart` (887 l.) — l'écran que le fondateur avait
rejeté comme « cockpit par-module » redondant — est aujourd'hui un écran de
**gouvernance d'accès** (niveaux Aucun / Lecture seule / Contribution / Gestion
complète par module et par profil). C'est exactement ce que la doctrine
prescrit : « par-application = gouvernance d'accès + config ; analytics d'usage
= centralisés ». Le rejet a produit la bonne architecture.

Sorties documentaires : **9 producteurs PDF pour 9 écrans avec aperçu partagé**,
et **0 `Printing.layoutPdf(` actif**. C'est le meilleur ratio de conformité
documentaire de la plateforme.

**Ce qui ne va pas.** 19 réglages qui ne font rien, 25 marqueurs
d'inachèvement, 34 `catch (_) {}`, 17 fichiers > 500 lignes.

---

## B. Fiche par écran *(échantillon raisonné)*

### Réglages ▸ Notifications — `reglages/reglages_notifications.dart` (288 l.)

⛔ **LA plus grosse « case qui ne fait rien » de toute l'analyse.**

**Dix-neuf réglages** : Email, SMS, Push, Notifier à l'inscription, au
paiement, à l'absence, en cas de faible assiduité, résumé quotidien + heure,
seuils d'alerte d'assiduité et de notes, jours d'impayé, relance de facturation
+ trois jours de rappel, notifier le directeur au paiement et à l'absence…

Ils s'enregistrent tous correctement. **Rien ne les lit.** Vérifié des **deux
côtés**, comme l'exige la règle du projet :

```
grep -rn "<champ>" lib/   (hors l'écran et son provider)   → 0 lecteur × 15 champs testés
select proname from pg_proc where prosrc ilike '%<colonne>%' → 0 fonction × 14 colonnes
```

Aucun courriel, aucun SMS, aucune notification poussée, aucun résumé quotidien,
aucune alerte d'assiduité, aucune relance de facturation n'est émis à partir
d'eux. Un administrateur qui active « Notifier le directeur en cas d'absence »
croit avoir mis en place une surveillance. Il n'y en a aucune.

**✅ CORRIGÉ le 2026-09-09, premier temps.** Un bandeau se lit **avant** les
réglages et dit ce qui n'existe pas : « Vos choix sont bien enregistrés, mais
la plateforme n'émet aujourd'hui aucun courriel, SMS… Les notifications qui
fonctionnent réellement sont celles de la cloche, dans l'application. »

**Le deuxième temps est un arbitrage produit** que je ne prends pas seul :
rendre vrai ce qui peut l'être à peu de frais (la relance de facturation a déjà
sa boucle de nuit, mig. 0190 — il ne manque que la lecture des jours de rappel)
et **retirer** le reste.

---

### Modules du groupe — `admin_module_screen.dart` (887 l.)

✅ **Conforme à la doctrine.** L'écran attribue des **niveaux d'accès** par
module et par profil — gouvernance, pas analytics. C'est la refonte demandée
après le rejet du cockpit par-module. Rien à signaler, sinon la taille.

---

### Abonnement — `admin_subscription_billing.dart`, `admin_licence_card.dart` (626 l.), `admin_licence_couverture.dart` (518 l.), `admin_licence_modales.dart` (543 l.)

**⛔ Défaut trouvé et CORRIGÉ le 2026-09-09** : les boutons « Facture » et
« Reçu » appelaient `printInvoice` / `printReceipt`, c'est-à-dire
`Printing.layoutPdf` — **la boîte d'impression système sans aucun aperçu**, sur
la facture et le reçu d'abonnement de l'école. Passent désormais par
`apercuFacture` / `apercuRecu`.

✅ **Vérifié conforme** : toutes les échéances passent par `daysUntilDate`
(`admin_dashboard_provider:198`, `admin_licence_provider:96`,
`admin_subscription_provider:106`, `subscription_access_provider:79`) et
**jamais** `now.difference(date)` — la règle qui avait fait couper la licence un
jour trop tôt tient.

---

### Rapports — `admin_reports_provider.dart` (890 l.) · Dashboard — `admin_dashboard_provider.dart` (719 l.)

Non lus en profondeur. **Point de vigilance** : c'est le foyer légitime des
analytics d'usage selon la doctrine. Toute KPI répétée ailleurs devrait
renvoyer ici plutôt que se recalculer.

---

### Cartographie régionale — `regional_map.dart` (1 045 l.) + 3 fichiers

Non lue en profondeur. Faits établis par la mémoire projet, non re-vérifiés :
la vue régionale est **fermée aux privés** (la NATURE du groupe ≠ le DROIT du
fondateur), Google Maps est **exclu** au profit d'Esri Wayback, et
`congo_places.json` porte 1 532 localités.

---

## C. Relations avec le reste de la plateforme

```
  super_admin ──(plans, catalogue)──► admin_groupe ──(profils d'accès)──► espace école
                                            │                                  ▲
                                            ├──► écoles, années scolaires ──────┘
                                            ├──► barèmes de frais (mig. 0096 : l'école EXÉCUTE)
                                            ├──► référentiel de niveaux (l'école REÇOIT)
                                            └──► communication (module transverse, pas une copie ✅)

  tutelle ──(supervise des GROUPES)──► admin_groupe
```

⚠️ **Ce que ce schéma dit** : l'espace réseau est le **producteur** de presque
tout ce que l'école consomme comme référentiel — barèmes, niveaux, années,
profils d'accès, modules. Une erreur ici se propage à 1 000 écoles ; une
correction aussi.

## D. Synthèse

### D.1 Fonctionnalités manquantes

| # | Écran | Manque | Preuve | Impact | Effort |
|---|---|---|---|---|---|
| 1 | Réglages ▸ Notifications | **Que les 19 réglages fassent quelque chose** | 0 lecteur Dart, 0 fonction en base | Une surveillance annoncée et inexistante | **L** (ou retrait) |
| 2 | Réglages | Audit « case morte » sur `admin_settings_provider.dart` (897 l.) | l'onglet Sécurité avait déjà 6 réglages morts | D'autres onglets sont probablement dans le même cas | **M** |
| 3 | tout l'espace | Qualification des 25 marqueurs d'inachèvement | balayage | Dette non chiffrée | **S** |

### D.2 Doublons et redondances

| # | Constat | Verdict |
|---|---|---|
| 1 | `admin_module_screen` = gouvernance d'accès, pas cockpit d'usage | ✅ **Doctrine appliquée** — le rejet du fondateur a produit la bonne architecture |
| 2 | Communication : les écrans de cet espace **importent** `features/communication/` | ✅ Pas de copie par espace |
| 3 | 9 services PDF dans `admin_groupe/services/` | Chacun sur `OfficialPdfKit`, aperçu partagé — pas de chrome divergent ✅ |

### D.3 Données partagées HORS espace

| Donnée | Producteur | Consommateurs | Contrat | Risque si rompu |
|---|---|---|---|---|
| `access_profiles`, `profile_permissions` | **`admin_groupe`** | **la cascade des 4 verrous de toute l'école** | Descend par sync-rules scopées au profil du membre | ⚠️ Sync-rules non redéployées = sidebar staff réduite à Dashboard + Communication |
| `fee_structures` | `admin_groupe` (mig. 0096) | `frais-scolarite`, `paiements-eleves`, `inscriptions`, `examens` | L'école EXÉCUTE, elle ne fixe pas | Un barème absent = pas d'encaissement possible |
| `school_levels`, `school_cycles` | `admin_groupe` | `niveaux`, `classes`, tous les KPI par cycle | L'école REÇOIT sa structure | ⚠️ Jointure sur `group_id` seul = 42 niveaux au lieu de 6 |
| `academic_years`, `trimesters` | `admin_groupe` | **toute la catégorie Enseignement** | `academic_years.school_id` est **NULL** — portées par le GROUPE | Aucune année `is_current` = tout l'espace école en lecture seule |
| `school_groups.group_type` | `super_admin` | `admin_groupe` | ⚠️ **`school_type_enum` ≠ `group_type`** : deux énumérations distinctes aux MÊMES libellés | `42883` seulement à l'exécution de la comparaison |

### D.4 Conformité export / aperçu / impression

| Mesure | Valeur |
|---|---|
| Producteurs PDF | **9** |
| Écrans avec aperçu partagé | **9** |
| `Printing.layoutPdf(` actifs | **0** |
| Méthode morte portant le geste banni, retirée aujourd'hui | 1 (`AcademicYearPdfService.printReport`) |
| Impressions aveugles corrigées aujourd'hui | 2 (facture + reçu d'abonnement) |

✅ **Meilleur ratio de conformité documentaire de la plateforme** : autant
d'aperçus que de producteurs, aucun contournement.

### D.5 Cases mortes et zéros menteurs

| # | Type | Constat |
|---|---|---|
| 1 | ⛔ **Case morte, corrigée (1ᵉʳ temps)** | 19 réglages de notification sans aucun lecteur, des deux côtés |
| 2 | ⚠️ Restant | **34 `catch (_) {}`**. Concentration : `admin_access_provider` ×7, `admin_module_provider` ×5, `admin_nav_provider` ×4, `admin_users_provider` ×4. **Ces quatre fichiers gouvernent les DROITS** — un `catch` qui avale y est plus grave qu'ailleurs : un droit non lu se rend comme un droit absent, ou pire, comme un succès d'écriture |
| 3 | ⚠️ | 6 services PDF ont un `catch (_) {}` en fin de méthode d'enregistrement — même motif que le faux succès corrigé côté fondateur. **À vérifier côté appelants** |
| 4 | ⚠️ | 15 `valueOrNull ?? const []`, dont la plupart alimentent des listes de référence (localités, sessions d'examen, trimestres) — **famille bénigne**, non corrigés |

### D.6 Dette de structure

**17 fichiers > 500 lignes** :

| Fichier | Lignes |
|---|---|
| `screens/regional/regional_map.dart` | **1 045** |
| `providers/admin_settings_provider.dart` | **897** |
| `screens/regional_table_mode.dart` | **894** |
| `providers/admin_reports_provider.dart` | **890** |
| `screens/admin_module_screen.dart` | **887** |
| `providers/exam_archives_provider.dart` | 810 |
| `providers/admin_subscription_provider.dart` | 732 |
| `providers/admin_dashboard_provider.dart` | 719 |
| `screens/admin_fee_form_dialog.dart` | 679 |
| `screens/admin_year_department_sheet.dart` | 656 |
| `screens/admin_licence_card.dart` | 626 |
| `screens/schools/school_education_section.dart` | 564 |
| `screens/admin_licence_modales.dart` | 543 |
| `widgets/exam_sessions_views.dart` | 533 |
| `widgets/admin_exams_views.dart` | 533 |
| `screens/regional/regional_project_dialog.dart` | 526 |
| `screens/regional/regional_markers.dart` | 525 |
| `screens/admin_licence_couverture.dart` | 518 |

### D.7 Désalignements

1. **25 marqueurs d'inachèvement** — le plus gros gisement de la plateforme.
2. **Les slugs de catégorie sont codés en dur dans un seul fichier** :
   `admin_access_screen.dart` (`_kPresets`, `grantFor(catSlug, modSlug)`). Tout
   changement de slug au catalogue DOIT y être répercuté, sans quoi les presets
   de profils sont incomplets — **sans erreur visible**. C'est le point de
   couplage le plus fragile entre cet espace et le catalogue.
3. **147 écrans pour « 12 écrans » annoncés** dans `CLAUDE.md` : le compte
   agrège des pages, le dossier compte des widgets d'écran. Pas une erreur,
   mais l'écart de perception explique pourquoi ce dossier surprend.

## E. Les cinq choses à faire en premier

1. **Trancher le sort des 19 réglages de notification.** Le bandeau les rend
   honnêtes ; il ne les rend pas vrais. La relance de facturation a déjà sa
   boucle de nuit (mig. 0190) : lui faire lire ses trois jours de rappel est
   peu coûteux. Pour le reste — SMS, push, résumé quotidien — c'est retirer, ou
   décider d'un chantier.
   *Effort : S pour la relance, L pour le reste, XS pour décider.*

2. **Qualifier les `catch (_) {}` des quatre providers de DROITS**
   (`admin_access` ×7, `admin_module` ×5, `admin_nav` ×4, `admin_users` ×4).
   Un droit avalé en silence est la définition du cadenas fermé sur rien.
   *Effort : M.*

3. **Vérifier les 6 services PDF qui avalent leur échec d'enregistrement**, et
   ce que leurs appelants en disent. Le même défaut a été trouvé et corrigé
   côté fondateur aujourd'hui — il y a de fortes chances qu'il soit ici aussi.
   *Effort : S.*

4. **Auditer `admin_settings_provider.dart` (897 l.)** avec la méthode des deux
   côtés. L'onglet Sécurité avait 6 réglages morts, l'onglet Notifications en a
   19 : il n'y a aucune raison de penser que les autres sont sains.
   *Effort : M.*

5. **Couvrir les zones que je n'ai pas lues** — cartographie régionale
   (3 000 l.), archives d'examens (810 l.), rapports (890 l.). Un trou déclaré
   est exploitable ; il reste un trou.
   *Effort : L.*
