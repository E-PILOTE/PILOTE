# VIE SCOLAIRE — analyse

**Slug catégorie** : `vie-scolaire` · **Modules** : 5
**Code** : `features/vie_scolaire/` — 24 fichiers, 6 716 lignes, 14 écrans
**Date** : 2026-09-09 · analyse conduite directement (sans agent)

> ⚠️ Le dossier `features/vie_scolaire/` contient aussi `orientation_screen.dart`
> et `orientation_provider.dart`, mais le module `orientation` appartient à la
> catégorie **SCOLARITÉ** en base. Il est traité dans `01-cat-scolarite.md` ;
> seul le désalignement est repris ici, en D.7.

## A. Vue d'ensemble de la catégorie

Cinq modules qui suivent l'élève hors de la salle de classe : sa présence, sa
conduite, sa santé, ses repas, ses lectures. Ils partagent un kit d'interface
(`vs_kit.dart`, 416 l.) et un sélecteur d'élève commun
(`vs_student_field.dart`, `vs_students_provider.dart`), ce qui donne à la
catégorie une cohérence visuelle qu'aucune autre n'atteint.

**Ce qui va bien, en trois lignes** : le verrou 4 est appliqué sur les cinq
modules (vérifié fichier par fichier, voir C) ; il n'y a **aucun `catch (_) {}`**
dans les 6 716 lignes ; l'appel de présence converge entre deux appareils hors
ligne grâce à un UUID v5 déduit de la clé.

**Le défaut de la catégorie tient en une phrase** : *rien n'en sort*. Cinq
modules, **zéro document**. Et deux d'entre eux gouvernent des actes qui
engagent l'établissement — une sanction, un passage à l'infirmerie.

---

## B. Fiche par module

### Présences Élèves — `presences-eleves`

| | |
|---|---|
| Route | `/user/presences` |
| Écran | `PresencesScreen` — `screens/presences_screen.dart` (257 l.) + `presences_roll.dart` (462 l.) |
| Tables | `attendance_records`, `attendance_marks`, `class_enrollments`, `students` |
| Périmètre | ✅ `classesForModuleProvider(kSlugPresences)` — `presences_provider.dart:50` |
| Profondeur UI | **L2** (7/9) — manquent : tri, sortie |
| Sortie document | **aucune** |

**Ce qu'il fait** — l'appel par classe et par date, la finalisation de la
feuille, le « tous présents » en un geste. L'écriture est idempotente : l'id du
relevé est un **UUID v5 déduit de la clé** (classe + date), donc deux appareils
hors ligne qui font le même appel convergent au lieu de créer deux feuilles.

**Ce qui manque**
- **Aucun état mensuel de présence.** `attendanceOverviewProvider` agrège pour
  l'écran, rien ne le met sur papier. Le relevé d'assiduité est pourtant une
  pièce que la circonscription demande, et la base du calcul d'absentéisme.
- **Aucune sortie de la feuille d'appel signée.** Une feuille d'appel qui ne
  s'imprime pas ne peut pas être contresignée.
- Pas de tri (par nom, par nombre d'absences) sur la liste de classe.

**Ce qu'il partage** — les absences alimentent le **bulletin** (module
`bulletins`, migration 0122). C'est le seul flux sortant, et il fonctionne.

---

### Discipline — `discipline`

| | |
|---|---|
| Route | `/user/discipline` |
| Écran | `DisciplineScreen` (481 l.) + `discipline_form.dart` (267 l.) |
| Tables | `discipline_incidents`, `class_enrollments` (exclusion) |
| Périmètre | ✅ `classScopeClause` — `discipline_provider.dart` |
| Profondeur UI | **L2** (7/9) — manquent : tri, sortie |
| Sortie document | **aucune** |

**Ce qu'il fait** — consigne un incident, prononce une exclusion. L'exclusion
écrit `withdrawal_motif = 'exclusion'` sur l'inscription
(`discipline_provider.dart:232`) : elle rejoint donc correctement la
statistique nationale de déperdition. C'est bien fait.

**Ce qui manque**
- ⛔ **Aucune notification écrite de sanction.** Une exclusion est une décision
  qui doit être notifiée à la famille et versée au dossier. Elle sort
  aujourd'hui de l'écran et de nulle part ailleurs. C'est le manque le plus
  grave de la catégorie : la plateforme fait prendre une décision lourde sans
  produire l'acte qui la porte.
- **Aucun registre de discipline imprimable** — la pièce que l'inspection
  ouvre en premier.
- **L'audit est quasi inexistant** sur cette catégorie (un seul déclencheur en
  base au dernier relevé). Qui a prononcé quoi, et quand, n'est pas traçable
  au-delà de la ligne elle-même.

---

### Infirmerie — `infirmerie`

| | |
|---|---|
| Route | `/user/infirmerie` |
| Écran | `InfirmerieScreen` (270 l.) + `infirmerie_form.dart` (338 l.) + `infirmerie_cards.dart` (265 l.) |
| Tables | `infirmary_visits`, `students` (dont `blood_group`, `allergies`) |
| Périmètre | ✅ `classScopeClause` — `infirmerie_provider.dart` |
| Profondeur UI | **L2** (7/9) — manquent : tri, sortie |
| Sortie document | **aucune** |

**Ce qu'il fait** — consigne une visite, lève une alerte médicale
(`alerteMedicaleProvider`), clôt un suivi.

**Ce qui manque**
- ⛔ **Aucune fiche de santé de l'élève.** Les visites sont listées par date ;
  rien ne les rassemble par enfant. Un infirmier qui reçoit un élève ne voit
  pas son historique en un écran.
- **Aucun bulletin de passage à remettre à la famille**, ni de billet de
  sortie — les deux papiers du métier.
- ⚠️ **Donnée de santé sans traçabilité.** Le groupe sanguin et les visites
  sont des données sensibles ; l'audit ne les couvre pas. À trancher avant le
  déploiement national.

---

### Cantine — `cantine`

| | |
|---|---|
| Route | `/user/cantine` |
| Écran | `CantineScreen` (254 l.) + `cantine_roll.dart` (280 l.) |
| Tables | `canteen_meals` |
| Périmètre | ✅ `classesForModuleProvider(kSlugCantine)` — `cantine_provider.dart:47` |
| Profondeur UI | **L1** (6/9) — manquent : tri, action primaire, sortie |
| Sortie document | **aucune** |

**Ce qu'il fait** — pointe les repas servis, classe par classe, avec un « tous
servis » groupé.

**Ce qui manque**
- ⛔ **Aucun lien avec la caisse.** Vérifié : `grep -niE "fee|frais|payment|
  montant|xaf" cantine_provider.dart` ne rend **rien**. Or la cantine est un
  **frais annexe** au sens de la migration 0108 — cumulable, dû, et
  encaissable par le module `paiements-eleves`. La plateforme compte donc les
  repas d'un côté et facture un forfait de l'autre, sans que les deux se
  parlent. Une école qui sert 400 repas par mois n'a aucun moyen de convertir
  ce pointage en ce qui est dû.
- **Aucun état de consommation** (par mois, par classe) à remettre au
  gestionnaire ou au fournisseur.
- Écran le plus pauvre de la catégorie après Bibliothèque : pas d'action
  primaire hors du pointage.

---

### Bibliothèque — `bibliotheque`

| | |
|---|---|
| Route | `/user/bibliotheque` |
| Écran | `BibliothequeScreen` (371 l.) + `biblio_forms.dart` (299 l.) + `biblio_cards.dart` (183 l.) |
| Tables | `library_items`, `library_loans` |
| Périmètre | ✅ `classScopeClause` — `biblio_provider.dart` |
| Profondeur UI | **L1** (5/9) → **L2** après correction ci-dessous |
| Sortie document | **aucune** |

**Ce qu'il fait** — catalogue des ouvrages, prêts, retours, détection des
retards.

**⚠️ Défaut trouvé et CORRIGÉ le 2026-09-09** — `bibliotheque_screen.dart:98-99`
lisait ses deux sources en `.valueOrNull ?? const []`, **sans état de
chargement ni d'erreur**. Les quatre cartes de l'en-tête — Titres, Exemplaires,
Empruntés et **En retard** — se calculent sur ces listes. Pendant le
chargement, et *pour toujours* si la lecture échouait, l'écran affichait
« En retard : 0 » : le responsable n'a personne à relancer, et le catalogue
paraît vide alors qu'il ne l'est pas. C'est mot pour mot le défaut que le
projet garde ailleurs par `zero_nest_pas_je_ne_sais_pas_test.dart`.
Les deux `AsyncValue` sont désormais traités : erreur remontée, chargement
distinct de vide.

**Ce qui manque**
- **Aucune relance de retard.** Le KPI « En retard » compte, rien ne produit la
  liste à remettre aux professeurs principaux.
- **Aucun inventaire imprimable** — l'état du fonds documentaire.
- Pas de tri du catalogue.

---

## C. Relations entre les modules DE cette catégorie

```
              ┌───────────────── vs_students_provider ─────────────────┐
              │      (le sélecteur d'élève, partagé par les 5)         │
              └───────────────────────────────────────────────────────┘
                                       │
   presences-eleves ─► bulletins (absences comptées, mig. 0122)  ← seul flux SORTANT
   discipline       ─► class_enrollments.withdrawal_motif='exclusion'  ← statistique nationale ✅
   infirmerie       ─► (rien)
   cantine          ─╳► paiements-eleves        ← LIEN MANQUANT
   bibliotheque     ─► (rien)
```

**Ce que dit ce schéma** : la catégorie **consomme** beaucoup (élèves, classes,
périmètre) et ne **produit** presque rien pour les autres. Deux flux sortants
sur cinq modules. Les trois autres sont des culs-de-sac : ce qu'on y saisit n'y
sert qu'à être relu sur le même écran.

**Le verrou 4 est appliqué partout** — vérifié module par module, et cohérent
avec la base : les cinq modules ont chacun **7 profils en `own_classes`** et 21
en `own_school` (relevé live du 2026-09-09). C'est la seule catégorie de
l'espace école où le périmètre par classe a un effet réel sur tous ses modules.

## D. Synthèse de la catégorie

### D.1 Fonctionnalités manquantes — vue consolidée

| # | Module | Manque | Preuve | Impact métier | Effort |
|---|---|---|---|---|---|
| 1 | `discipline` | Notification écrite de sanction | `grep -rn "showPdfPreviewDialog\|PdfService" features/vie_scolaire/` → **0** | Une exclusion est prononcée sans acte remis à la famille | **M** |
| 2 | `cantine` | Aucun lien avec la caisse | `grep -niE "fee\|frais\|payment\|montant\|xaf" cantine_provider.dart` → 0 | Les repas servis ne deviennent jamais une créance (frais annexe, mig. 0108) | **M** |
| 3 | `infirmerie` | Fiche de santé par élève | visites listées par date, `infirmerie_provider.dart:49` | L'infirmier ne voit pas l'historique de l'enfant qu'il reçoit | **M** |
| 4 | `presences-eleves` | État mensuel d'assiduité imprimable | idem #1 | Pièce demandée par la circonscription, base de l'absentéisme | **M** |
| 5 | `discipline` | Registre de discipline imprimable | idem #1 | La pièce que l'inspection ouvre en premier | **S** |
| 6 | `bibliotheque` | Liste de relance des retards | KPI « En retard » calculé, jamais sorti | Le retard est compté, jamais réclamé | **S** |
| 7 | `bibliotheque` | Inventaire du fonds | idem #1 | Pas d'état du patrimoine documentaire | **S** |
| 8 | `infirmerie` | Billet de sortie / bulletin de passage | idem #1 | Les deux papiers du métier | **S** |
| 9 | tous (5/5) | Tri des listes | aucun `sort`/`onSort` dans les 5 écrans | Confort, mais sur des listes de 400 élèves | **S** |
| 10 | `cantine` | État de consommation par mois/classe | `canteenOverviewProvider` agrège à l'écran seulement | Rien à remettre au gestionnaire ni au fournisseur | **S** |

### D.2 Doublons et redondances — vue consolidée

| # | Modules | Ce qui est dupliqué | Nature | Foyer proposé |
|---|---|---|---|---|
| 1 | les 5 | **Néant à signaler.** `vs_kit.dart`, `vs_student_field.dart` et `vs_form_chrome.dart` sont un partage **voulu** et bien fait | — | — |
| 2 | `presences-eleves` ↔ `cantine` | Le pointage « par classe, par date, avec un tout-cocher » est écrit deux fois (`presences_roll.dart` 462 l. / `cantine_roll.dart` 280 l.) | Même geste métier, deux implémentations | Un `VsRollView` partagé dans `vs_kit` — à arbitrer, les deux divergent sur la finalisation |

*Faux positif écarté* : les cinq providers déclarent chacun leur `_kSlug` /
`kSlugXxx` en tête. Ce n'est pas une duplication mais **la règle** — chaque
module doit passer SON slug au périmètre, jamais celui d'un voisin.

### D.3 Données partagées HORS catégorie

| Donnée | Producteur | Consommateurs | Contrat | Risque si rompu |
|---|---|---|---|---|
| `attendance_marks` | `presences-eleves` | `bulletins` (mig. 0122) | Une absence n'est jamais un zéro | Bulletin sans assiduité |
| `class_enrollments.withdrawal_motif` | `discipline` (exclusion) | statistique nationale, `registre_matricule` | Code de `kMotifsRadiation` | Sortie invisible de la déperdition |
| `students.blood_group`, allergies | `infirmerie` (lecture) | `cartes` (module SCOLARITÉ) | Donnée de santé | ⚠️ C'est par `cartes` qu'elle fuyait — corrigé le 2026-09-09 |
| `classesForModuleProvider(slug)` | `classes` | les 5 | Chaque appelant passe SON slug | Périmètre d'un autre module appliqué |
| repas servis | `cantine` | **personne** — devrait être `paiements-eleves` | — | cf. D.1 #2 |

### D.4 Conformité export / aperçu / impression

| Module | Sortie ? | `OfficialPdfKit` | `showPdfPreviewDialog` | `Printing.layoutPdf(` | Verdict |
|---|---|---|---|---|---|
| `presences-eleves` | **non** | — | — | — | rien à sortir |
| `discipline` | **non** | — | — | — | rien à sortir |
| `infirmerie` | **non** | — | — | — | rien à sortir |
| `cantine` | **non** | — | — | — | rien à sortir |
| `bibliotheque` | **non** | — | — | — | rien à sortir |

**Zéro sortie sur cinq modules.** Vérifié par
`grep -rn "showPdfPreviewDialog|PdfService|exportCsv|toCsv|FicheDetail|Printing\." features/vie_scolaire/` → **aucune ligne**.
C'est le constat le plus net de toute l'analyse : la catégorie n'a **aucune**
infrastructure documentaire, alors que le socle (`OfficialPdfKit`,
`showPdfPreviewDialog`, `AttestationKit`) est disponible et adopté par 41
fichiers ailleurs. Rien à corriger dans l'existant — tout à ajouter.

### D.5 Cases mortes et zéros menteurs

| # | Module | Type | `fichier:ligne` | Prétend | Réalité |
|---|---|---|---|---|---|
| 1 | `bibliotheque` | Zéro menteur | `bibliotheque_screen.dart:98-99` | « En retard : 0 », « Titres : 0 » | Lecture non aboutie ou échouée rendue comme un fait — **✅ CORRIGÉ le 2026-09-09** |
| 2 | les 5 | — | — | — | **Aucun `catch (_) {}` dans les 6 716 lignes.** À signaler comme une réussite |

⚠️ Les 9 autres `valueOrNull ?? const []` de la catégorie
(`biblio_forms:220,222`, `cantine_roll:102`, `discipline_form:163`,
`infirmerie_form:121`, `orientation_screen:338,339`, `orientation_sheet:163,172`)
alimentent des **listes déroulantes de formulaire**, pas des compteurs affichés
comme des faits. Un déroulant brièvement vide n'est pas un zéro menteur. **Non
corrigés, à dessein.**

### D.6 Dette de structure

**Aucun fichier ne dépasse 500 lignes.** Le plus gros est
`discipline_screen.dart` à 481, sous la cible. Sur 24 fichiers et 6 716 lignes,
c'est la catégorie la plus propre de la plateforme sur cet axe.

### D.7 Désalignements catalogue ↔ code

1. **`orientation` est catalogué en SCOLARITÉ, codé ici.** Verdict repris de
   `01-cat-scolarite.md` : rangement, pas appartenance. Le module partage
   `vs_kit` avec les cinq autres et sa donnée d'entrée vient du conseil de
   classe. À noter au catalogue, pas à déplacer.
2. **Le rapport volume/ambition est le plus faible de l'espace école** :
   5 modules pour 6 716 lignes, quand SCOLARITÉ en fait 25 896 pour 7. Ce
   n'est pas un défaut en soi — mais mis en regard du « zéro sortie », il dit
   que la catégorie a été livrée à un niveau de finition inférieur au reste.

## E. Les cinq choses à faire en premier

1. **Donner à la Discipline l'acte qu'elle prononce.** Une notification de
   sanction sur `OfficialPdfKit` + `AttestationKit` (`pw.Page`, jamais
   `MultiPage`), servie par `showPdfPreviewDialog`, et notée au registre des
   documents émis comme les attestations le font déjà.
   *Gain : la plateforme cesse de faire prendre une décision lourde sans
   produire l'acte · Effort : M · Entrée : `features/vie_scolaire/screens/discipline_form.dart`.*

2. **Brancher la Cantine sur la caisse.** Convertir le pointage en créance via
   le frais annexe `cantine` (mig. 0108, cumulable). C'est le seul module de la
   catégorie qui produit de la valeur monétaire et la laisse tomber.
   *Gain : une recette réelle cesse d'être perdue · Effort : M · Entrée :
   `features/vie_scolaire/providers/cantine_provider.dart` + `finance/services/bareme_applicable.dart`.*

3. **Un état mensuel d'assiduité imprimable.** `attendanceOverviewProvider`
   calcule déjà l'agrégat ; il manque le service PDF et le bouton d'aperçu.
   *Gain : la pièce que la circonscription réclame · Effort : M · Entrée :
   `features/vie_scolaire/providers/presences_provider.dart:45`.*

4. **Une fiche de santé par élève à l'Infirmerie**, et trancher la question de
   l'audit sur les données de santé avant le 1er octobre.
   *Gain : l'infirmier voit l'historique ; la donnée sensible devient traçable
   · Effort : M · Entrée : `features/vie_scolaire/providers/infirmerie_provider.dart`.*

5. **La liste de relance des retards** de la Bibliothèque — le KPI existe, il
   ne manque que sa sortie. Le moins cher des cinq, et immédiatement utile.
   *Gain : le retard compté devient un retard réclamé · Effort : S · Entrée :
   `features/vie_scolaire/providers/biblio_provider.dart:108`.*
