---
name: archives-publications-dec
description: "Socle des archives DEC (mig 0062) : la plateforme conserve la pièce publiée, ne calcule jamais un taux national ; taux officiel = admis/PRÉSENTS ; DEC publie par établissement avec un code AAA…AIZ"
metadata: 
  node_type: memory
  type: project
  originSessionId: 3dd519ee-785a-464e-a27d-95c1a6fbc266
  modified: 2026-07-27T19:42:07.665Z
---

**Cadré par le user (fonctionnaire DSIC/METP) le 2026-07-27** — cf. [[user-fonctionnaire-dsic-metp]]. Commit `693b1d4`, app v3.1.0, migration **0062 appliquée en prod**.

## La règle qui commande tout
La plateforme **transmet** la liste des candidats à la DEC ; la DEC organise, proclame et **publie**. La DSIC **centralise** les publications (papier + PDF). Rôle restant : **gardienne**, pas calculatrice. → Ne JAMAIS calculer un taux national.

## Recherche web — faits vérifiés (2026-07-27)
- **La DEC publie par ÉTABLISSEMENT**, avec un **code établissement** propre (`AAA…AIZ`, >170 écoles pour le seul BEPC de Brazzaville) → `schools.dec_code`, seule clé de jointure fiable (jamais le nom).
- Les listes publiées portent : matricule, nom, sexe, date/lieu de naissance, série, **mention**, établissement. Canaux : digiDEC (MEPSA), ZwaHub, ecolesaucongo, congoedusoft, meppsa.org.
- **⚠️ Le taux officiel porte sur les PRÉSENTS** : BAC T&P 2025 = 7 681 admis / **15 843 présents** (16 070 inscrits) = **48,48 %**. Sur les inscrits on obtiendrait 47,80 % — un autre chiffre, faux.
- Format de publication du ministère = **classement ordinal des 15 départements** (Bac général 2026 : Likouala 92,10 % → Dové-Lefini 15,39 %) + taux national comparé à l'an passé. Certaines publications ne donnent **que le %**, sans effectifs → on le stocke tel quel, on ne fabrique pas les effectifs.

## Migration 0062
- `schools.dec_code` (unique par groupe, nullable).
- `exam_publications` — la **pièce** : scope `national|departement|etablissement`, `published_at` (proclamation) ≠ `received_at` (réception DSIC), `file_sha256`, bucket **privé** `exam-publications` (URL signée 300 s).
- `exam_official_results` — les **chiffres relevés**, 1 seul jeu par (session, scope, département, école, filière) ; contrainte `admitted <= present` ; `(present+admitted) OU pass_rate` obligatoire.
- `official_pass_rate(present, admitted, rate)` — règle en base **et** miroir Dart `officialPassRate()` pour qu'elles ne divergent pas.

## Deux familles de chiffres, séparées jusque dans les types
- **OFFICIEL** (`OfficialFigure`) — relevé sur la publication, fait autorité, badgé « OFFICIEL DEC », affiché à côté de SA pièce.
- **PLATEFORME** (`PlatformTally`) — dérivé de `exam_candidates`, **jamais sans `coverage`**. 3 résultats saisis sur 40 → taux brut 100 %, couverture 7,5 %, `isReliable=false` (seuils : couverture ≥ 80 % ET présents ≥ 5). Absents hors dénominateur ; **fraude = présent, jamais admis**.

## Refusé délibérément
- **Lire le PDF automatiquement** : une extraction ratée écrit un faux résultat sur le dossier d'un élève, et un scan ne rend aucun texte. Gain = éviter de taper ~15 nombres/an. Sans commune mesure.
- **Déduire « ajourné » d'une absence dans la liste des admis** : vrai seulement si la liste couvre exactement le périmètre — jugement humain.

## Livré depuis (v3.1.4)
- **Historique** : trajectoire nationale par examen + classement ordinal des 15 départements, détail départemental cliquable (trajectoire + **écart au national**), PDF « Statistiques officielles ». ⚠️ Une évolution s'exprime en **POINTS** (43,64 % → 48,49 % = +4,85 pt, jamais « +11 % »).
- **Avis aux écoles au dépôt** — le maillon manquant : personne ne prévenait les écoles, leurs résultats restaient « en attente » faute de savoir qu'il y avait à saisir. Destinataires déduits du périmètre ; **chefs d'établissement seulement** ; best-effort (un échec d'envoi n'annule pas le dépôt) ; renvoi possible depuis la pièce.
- **Actions sur les pièces** : télécharger, **vérifier l'intégrité** (SHA-256 recalculé vs dépôt), copier l'empreinte, retrait sous confirmation.
- **Démo peuplée** (seed prod idempotent) : 5 examens METP × 4 sessions 2021-2022 → 2024-2025. Le **national est la SOMME des départements** (poids fixes + écarts), jamais un tirage séparé. Bac T ancré sur le réel : 43,64 % (2023-24) et 48,49 % (2024-25).

## ⚠️ Pièges rencontrés
- **Police embarquée sans U+2192** : la flèche `→` ne s'imprime pas. Corrigé dans exam_statistics / reports / admin_year pdf services (« du X au Y »). Tout nouveau texte PDF doit rester dans le jeu Noto Sans.
- **Barres calées sur zéro** = tendance invisible quand les taux sont voisins (62,81 → 66,45 %). Échelle basée sous le minimum de la série, valeur exacte écrite sur chaque barre.
- `exam_session_status` = `draft,open,closed,running,published,cancelled` (pas « cloturee »).

## Organisation des écrans (v3.1.5-3.1.7) — décision structurante
**DEUX PAGES, jamais une.** J'avais empilé historique + archives sur « Examens nationaux » : « Réussite par département » (plateforme, nos 14 écoles) touchait « Classement départemental » (officiel DEC) — deux classements, deux valeurs, rien pour dire lequel fait autorité. Le user a signalé le désordre ; la cause était l'adjacence des SOURCES, pas l'ordre.
- **`/admin/examens`** — session en cours : dossiers, transmissions, écoles en retard. Ouverte tous les jours. Chiffres PLATEFORME. (574→236 lignes, vues extraites dans `widgets/admin_exams_views.dart`.)
- **`/admin/resultats`** — « Résultats & archives » : ce que la DEC a proclamé. Ouverte une fois l'an. Chiffres DEC. KPI mesurant l'ARCHIVE (sessions, pièces vérifiables par empreinte, **chiffres sans source**), pas les résultats.

Dépôt d'une publication = **panneau latéral** (`showGeneralDialog` + slide, largeur 560), pas boîte modale : ~10 champs, et la page reste visible derrière.

## 2026-07-28 — 🐛 LE BUG QUI TUAIT TOUT RELEVÉ (mig 0063)
`recordFigure` faisait `ON CONFLICT (session_id, scope, department, school_id, filiere_label)`, mais 0062 protégeait l'unicité par un index d'**EXPRESSION** (`COALESCE(...)`). **Postgres n'infère JAMAIS un index d'expression depuis un ON CONFLICT sur colonnes** → 42P10 à *chaque* écriture. En prod : au dépôt d'une publication le fichier montait, la pièce s'insérait, puis les chiffres échouaient — l'archive gardait le document et perdait ses chiffres. Jamais vu car ce chemin n'avait jamais été exercé en GUI.
→ **mig 0063** : même invariant sur les colonnes + `NULLS NOT DISTINCT` (PG15+). ✅ appliquée prod, cycle créer→lister→corriger→retirer exercé **dans l'app** contre la prod (CEPE 2025-2026, 780/1200 = 65 %), zéro résidu.
⚠️ Règle générale : `create or replace function` avec une signature différente **SURCHARGE** au lieu de remplacer → PostgREST « function name is not unique ». Toujours `drop function ... (types)` d'abord.

## Écrans livrés le 2026-07-28
- **Une seule famille de modales** (`core/widgets/`) : `admin_tokens` (jetons) · `admin_modal` (AdminModalHeader/Footer/Actions) · `admin_modal_shapes` (**3 géométries** : boîte centrée `AdminFormDialog`, panneau latéral `showAdminSidePanel`, **feuille montante** `showAdminBottomModal`, + `showAdminConfirm`) · `admin_dialog_legacy` (ancien bandeau navy, ~25 écrans, à ne plus employer). `admin_ui.dart` **ré-exporte** tout → aucun importeur touché.
  - ⚠️ Panneau latéral = `Expanded` (pas `Flexible`) sinon le pied flotte au milieu. Feuille montante = `maxHeight` + `mainAxisSize.min` sinon vide sous un contenu court.
  - L'en-tête porte SA croix : ne jamais en superposer une seconde (c'était le défaut du drawer de dépôt).
- **Relevé d'un chiffre SANS pièce** (`exam_figure_panel` + `exam_figures_section`) : créer / corriger / retirer / **rattacher une pièce de la même session**. Filtre « sans source (N) » → l'indicateur devient suivable jusqu'à la ligne. Base réelle : **320 chiffres, 0 publication** → tout est « sans source ».
- **Classement départemental** sorti de l'historique → feuille montante (podium 2·1·3, écart au national par ligne, détail départemental). Historique refait : taux en grand + évolution en pt + meilleure/plus faible/gain, courbe Syncfusion `SplineAreaSeries` échelle resserrée (⚠️ `decimalPlaces: 0` + `interval` sinon « 62.077 % »).
- **Cockpit** : ligne école → **fiche d'établissement** (feuille montante : état campagne, ventilation par examen, chiffres officiels `scope=etablissement`) + **relance** des chefs d'établissement à l'unité ou en lot (`ministryExamActionsProvider`, notif `exam_transmission_reminder`).

## Reste à faire
- **Actions multiples** sur les pièces (notifier / retirer / exporter en lot).
- `schools.dec_code` : **aucune UI ne permet de le saisir** (0 école renseignée) alors que c'est la seule clé de jointure fiable des publications par établissement.
- Redoublants (`is_repeater`) ; partage d'une pièce vers une école précise.
⚠️ **Non vérifié en GUI** : dépôt d'un vrai PDF de bout en bout, envoi réel des notifications, PDF statistiques à l'écran.

Voir [[metp-partage-dec-classes-passage]], [[examens-nationaux-socle]], [[examens-frais-stats-convocations]].
