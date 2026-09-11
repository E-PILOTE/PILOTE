# PASSE TRANSVERSALE — TENIR À L'ÉCHELLE NATIONALE

**Objet** : ce qui, dans le code d'aujourd'hui, cesse d'être juste ou
utilisable quand le nombre d'élèves, d'écoles ou de jours de classe augmente.
**Date** : 2026-09-09 · mesures prises **sur la base de production**
**Cible** : 1 000+ écoles, plusieurs centaines de milliers d'élèves,
Windows d'entrée de gamme, liaisons lentes et intermittentes.

> Cette passe ne s'intéresse pas à ce qui est lent. Elle s'intéresse à ce qui
> devient **faux** — silencieusement — à mesure que la plateforme grandit.
> Un écran lent se voit et se signale. Un chiffre qui plafonne, non : il tombe
> rond, et il a l'air d'une mesure.

---

## 0. Les chiffres réels, aujourd'hui

`pg_stat_user_tables` sur `wqpdamlnrwgozfvzjjpo`, le 2026-09-09, avec
**44 écoles** en production sur les 1 000+ visées :

| Table | Lignes | Maximum pour UN groupe / UNE école |
|---|---:|---:|
| `grades` | **501 012** | 38 544 (une école) |
| `bulletin_subject_lines` | 178 419 | 12 824 (une école) |
| `attendance_entries` | 28 316 | |
| `bulletins` | 21 456 | |
| `evaluations` | 15 672 | |
| `student_documents` | 10 914 | |
| `student_payments` | 10 423 | **3 461 (un groupe)** |
| `class_enrollments` | 10 364 | **3 781 (un groupe)** |
| `students` | 10 364 | **3 781 (un groupe)** · 868 (une école) |
| `canteen_records` | 9 390 | |
| `exam_candidates` | 2 470 | 747 (un groupe) |
| `audit_logs` | 103 | |
| `schools` | 44 | |
| `school_groups` | 10 | |
| `profiles` | 414 | |

**Retenir deux nombres : 3 781 et 1 000.** Le premier est le plus gros groupe.
Le second est le plafond que PostgREST applique sans le dire.

---

## 1. Le plafond des mille lignes — **défaut LIVE, il fausse déjà des chiffres**

### Le mécanisme

PostgREST tronque toute réponse à 1 000 lignes. Pas d'erreur, pas d'en-tête
d'avertissement lu par le client : la liste est simplement plus courte. Tout
code qui **ramène des lignes pour les compter, les ventiler ou les
additionner** obtient donc un chiffre juste tant que la base est petite, puis
un chiffre faux.

Le remède existait déjà dans le dépôt — `core/utils/paged_fetch.dart`, écrit
après le précédent « 1.0 K élèves » — mais il n'était appliqué qu'à **17
lectures, dans 8 fichiers**. Il l'est aujourd'hui à **75, dans 35 fichiers**.

### Ce qui était faux au moment de l'analyse

| Écran | Lecture | Ce qui s'affichait | Ce qui est vrai |
|---|---|---|---|
| **Rapports du réseau** (PDF signable) | `students` du groupe | 1 000 élèves | **3 781** — 26 % du réel |
| **Rapports du réseau** | `student_payments` du groupe | plafonné à 1 000 | **3 461** — le recouvrement valait moins d'un tiers |
| **Tableau de bord du groupe** | paiements sur 12 mois | courbe des recettes tronquée | idem |
| **Carte territoriale** | élèves du groupe | 1 000, répartis sur les seules écoles de la 1ʳᵉ page | 3 781 |
| Rapports du réseau | `staff_members`, `classes` | tronqués | |

Ces chiffres partent en **PDF signé par le chef d'établissement ou le
directeur de réseau**. C'est le cas d'usage le plus grave que cette analyse ait
rencontré : pas un écran qui se plante, un document officiel qui se trompe.

### Ce qui allait devenir faux

À 1 000 écoles, sans rien changer d'autre :

- `schools` dépasse le plafond → **le prix d'un groupe suit son nombre
  d'écoles** (migration 0159, `plan_price_xaf(plan, n)`). Un parc tronqué,
  c'est une facturation fausse. Six lectures étaient concernées, dont
  `school_groups_provider.dart` et `subscriptions_provider.dart`.
- La **carte nationale** aurait laissé des départements entiers vides.
- Les **courbes de tendance** du tableau de bord fondateur lisaient toutes les
  lignes créées en six mois pour les compter : à l'échelle, plusieurs centaines
  de milliers de lignes transférées **pour six points** — et retombant sous le
  plafond, donc s'aplatissant d'elles-mêmes à mesure que la plateforme
  grossissait.
- Factures, reçus, tickets de support : monotones croissants, ils franchissent
  le plafond avec le temps, pas avec la taille. L'encours des impayés se
  serait mis à **rétrécir** à mesure que la dette grossissait.

### Ce qui a été fait

**61 lectures corrigées**, dans 27 fichiers :

| Traitement | Où | Nombre |
|---|---|---|
| `fetchAllRows(…)` + ordre total `.order('id')` | partout où la ventilation exige les lignes | **58** (17 → 75) |
| `countsByMonth6m(…)` — six `count(exact)`, aucune ligne transférée | les 3 courbes de tendance nationales | 3 |

⚠️ **L'ordre total n'est pas décoratif.** Chaque page est une requête séparée :
trier sur `name` quand deux écoles s'appellent « CEG de Kinkala » laisse une
ligne se faire sauter à la frontière de deux pages — ou compter deux fois.
Toutes les paginations ajoutées terminent par `.order('id')`.

### Ce qui l'empêche de revenir

`test/mille_lignes_ne_sont_pas_le_total_test.dart` — lit tout le code des
espaces en ligne, relève chaque `.from('<table de volume>')…select(…)`, et
exige l'une des quatre réponses légitimes :

1. `fetchAllRows(...)` — il faut les lignes ;
2. `.count(CountOption.exact)` — un compte suffit ;
3. `.limit(n)` / `.range(a, b)` — la liste est volontairement bornée **et
   l'écran le dit** ;
4. `.single()` / `.maybeSingle()` — une seule ligne attendue.

Le test suit le motif courant où le constructeur de requête est rangé dans une
variable puis borné plus loin, et porte une table de **dispenses écrites avec
leur raison** (deux entrées aujourd'hui, toutes deux des `inFilter` sur une
liste déjà bornée). Il refuse aussi une dispense devenue orpheline.

---

## 2. Le SQLite local sans index — **le défaut le plus lourd, et le plus invisible**

### Le mécanisme

PowerSync ne range pas une table en colonnes. Il stocke la ligne entière dans
un blob JSON (`ps_data__<table>.data`) et expose la table comme une **VUE**
dont chaque colonne vaut `json_extract(data, '$.colonne')`.

Conséquence : **sans index déclaré, `WHERE class_id = ?` est un balayage
complet de la table, avec un décodage JSON par ligne.**

`grep -c "indexes:" lib/services/powersync/powersync_schema.dart` → **0**,
sur **89 tables**.

### Pourquoi c'est le pire profil de défaut possible

- Il ne produit **aucune erreur**. Rien à voir dans un journal.
- Il ne se voit **pas à la recette de septembre** : une base fraîche est
  rapide. Il se voit au **troisième trimestre**, quand `grades` a grossi — sur
  mille postes à la fois, sans possibilité de retourner sur place.
- Chaque `db.watch()` **se rejoue à chaque tick de synchro**, et une page de
  saisie de notes en ouvre plusieurs. Le coût n'est pas payé une fois : il est
  payé en boucle.
- Le poste visé est un portable Windows d'entrée de gamme, hors ligne, en
  salle des professeurs. Pas un serveur.

Ordre de grandeur, sur l'école la plus chargée d'aujourd'hui : **38 544
notes**. Un écran de bulletins qui filtre par élève, par évaluation et par
inscription balayait donc trois fois cette table, en décodant 38 544 objets
JSON à chaque passage, à chaque tick.

### Ce qui a été fait

**78 index sur 44 tables**, choisis à partir des colonnes de jointure et de
filtre **réellement utilisées** — relevées automatiquement sur tout le SQL du
dépôt, pas devinées. Les tables retenues sont celles dont le volume croît avec
le nombre d'élèves, de jours de classe ou d'années scolaires ; les tables de
référence (modules, plans, cycles, départements) n'en reçoivent pas.

Extrait des plus lourds :

```dart
Table('grades', [...], indexes: [
  Index('par_evaluation',  [IndexedColumn.ascending('evaluation_id')]),
  Index('par_inscription', [IndexedColumn.ascending('enrollment_id')]),
  Index('par_eleve',       [IndexedColumn.ascending('student_id')]),
]),
Table('attendance_entries', [...], indexes: [
  Index('par_feuille', [IndexedColumn.ascending('attendance_record_id')]),
  Index('par_eleve',   [IndexedColumn.ascending('student_id')]),
]),
Table('class_enrollments', [...], indexes: [
  Index('par_classe_statut', [IndexedColumn.ascending('class_id'),
                              IndexedColumn.ascending('status')]),
  …
]),
```

Deux pièges, tous deux gardés par un test :

1. **`Index.ascending(...)` est une FABRIQUE, pas un constructeur `const`.**
   Dans le littéral `const schema = Schema([...])`, il faut écrire
   `Index('nom', [IndexedColumn.ascending('col')])`. La forme naturelle ne
   compile pas — et l'erreur ne pointe pas sur la cause.
2. **Une colonne indexée doit figurer dans la liste `columns` de sa table.**
   `IndexedColumn.toJson` la cherche avec `firstWhere` : si elle manque,
   l'application lève un `StateError` **au démarrage**, avant son premier
   écran.

`test/index_local_powersync_test.dart` vérifie les deux, plus : aucune table
de volume sans index ; la colonne de filtre la plus chaude est bien la **tête**
d'un index (un composite ne sert que si on l'attaque par sa tête) ; pas
d'homonymes ; et la forme textuelle du fichier reste lisible par les trois
autres gardes qui le découpent au texte.

**Coût** : la création des index est locale, faite une fois à l'ouverture de la
base. Aucun re-téléchargement, aucune migration serveur, aucun résultat changé.

---

## 3. Les allers-retours de la remontée — corrigé sur le chemin qui compte

### Le mécanisme

`SupabasePowerSyncConnector.uploadData` traite **une transaction locale par
appel**, et **une requête HTTP par opération**. Le coût réel d'une écriture
n'est donc pas le SQL : c'est le nombre de transactions locales.

L'import d'élèves écrivait `createStudent()` puis `enrollStudent()` en **deux
`db.execute` séparés**, donc deux transactions, donc **deux allers-retours par
élève**. Pour une rentrée de 1 200 élèves : 2 400 requêtes séquentielles.
À 150 ms l'aller-retour, six minutes de remontée — sur une liaison qui n'est
pas garantie de tenir six minutes.

### Le défaut de correction, plus grave que la lenteur

Deux transactions séparées, c'est aussi **deux moitiés d'un même acte**. Un
échec entre les deux — matricule introuvable, classe disparue, disque plein —
laissait une **fiche d'élève sans inscription**. Elle n'apparaît nulle part
(tous les écrans de scolarité entrent par `class_enrollments`) et occupe
pourtant un matricule définitivement pris. Sur un import de rentrée, ces
orphelins ne se découvrent qu'aux effectifs de janvier.

### Ce qui a été fait

`createStudent` et `enrollStudent` acceptent désormais un
`SqliteWriteContext? tx` optionnel, et l'import les appelle dans **une seule**
`db.writeTransaction`. L'élève et son inscription partent ensemble ou ne
partent pas ; les allers-retours passent de 2 400 à 1 200.

`sqlite_async` a été **déclaré explicitement** dans `pubspec.yaml` (il
n'arrivait que par `powersync`) : s'appuyer sur une dépendance transitive sans
la nommer, c'est laisser une montée de version casser la compilation sans
prévenir.

### Ce qui a été envisagé et **écarté**

Passer de `getNextCrudTransaction()` à `getCrudBatch(limit)` regrouperait les
opérations **au-delà** des frontières de transaction et diviserait encore les
allers-retours. **Rejeté**, et il faut dire pourquoi : le connecteur a une
doctrine explicite et bien construite sur la perte observable — un refus
définitif abandonne *une transaction* et la journalise dans `sync_failures`.
Avec un lot, un seul refus emporterait jusqu'à cent opérations sans rapport
entre elles. On échangerait de la latence contre de la perte silencieuse ;
c'est exactement le compromis que ce produit refuse.

---

## 4. Ce qui tient déjà, et qu'il faut savoir pour ne pas le « corriger »

| Sujet | Verdict | Pourquoi |
|---|---|---|
| Recherche d'élèves du réseau | ✅ | `.limit(kStudentSearchLimit + 1)` et l'écran affiche « tronqué ». C'est la bonne réponse, pas un oubli. |
| Compteurs d'effectifs | ✅ | `count(CountOption.exact)` déjà utilisé aux bons endroits. |
| `_applyScopeFloor` de l'audit | ✅ | Le plancher de visibilité est appliqué **en dur** dans chaque requête, jamais décochable. |
| Codes fatals du connecteur | ✅ | `42703`/`42P01`/`42804` délibérément absents, gardés par `sync_blocage_test`. |
| Purge de la base locale | ✅ | Un seul déclencheur — un utilisateur *différent* ouvre une session. Pas la déconnexion. |
| `db.connect()` conditionné à la licence | ✅ | Il ne l'est pas, et ne doit jamais l'être (C4/ADR-0006). |

---

## 5. Ce qui reste à surveiller

| # | Sujet | Pourquoi ce n'est pas traité ici | Quand ça mordra |
|---|---|---|---|
| 1 | `audit_logs` : 103 lignes aujourd'hui | La courbe est bornée à 5 000 **et le dit** depuis le 2026-09-09 ; les compteurs sont exacts | Quand un groupe dépassera 5 000 événements sur 30 jours — la courbe restera honnête, mais partielle |
| 2 | Volume descendu sur un poste | Les sync-rules décident quelles lignes descendent ; ce n'est pas du code Dart et ça se déploie séparément | Une école de 2 000 élèves qui reçoit 6 ans d'historique de notes au premier démarrage |
| 3 | `bulletin_subject_lines` : 178 419 lignes | Indexée par `bulletin_id`, ce qui couvre l'usage réel | Un export « tous les bulletins de l'école » |
| 4 | **Listes non virtualisées** | Relevé mais **non corrigé** — voir ci-dessous | Une école de 2 000 élèves |

### 5.1 Les listes d'élèves construisent toutes leurs lignes — relevé, non corrigé

`features/students/screens/eleves_liste_parts.dart:244` rend **chaque** élève
filtré dans un `Wrap` :

```dart
return Wrap(spacing: gap, runSpacing: gap, children: [
  for (final s in rows) SizedBox(width: cardW, child: _StudentCard(…)),
]);
```

Aucune virtualisation, et aucune borne en amont (`eleves_screen.dart:479`
passe `rows: filtered`, la liste entière). La vue tableau `_StudentTable` a le
même profil. À 868 élèves — la plus grosse école d'aujourd'hui — c'est de
l'ordre de 25 000 widgets construits à chaque `build`, et `db.watch` en
déclenche un à chaque tick de synchro.

**Ce n'est pas corrigé, et c'est une décision, pas un oubli.** Le remède
correct n'est pas un `GridView.builder` : à l'intérieur d'un défilement
existant, il exigerait `shrinkWrap: true`, ce qui construit tout de nouveau et
n'apporte rien. Il faut convertir le défilement de l'écran en
`CustomScrollView` — les sections de tête en `SliverToBoxAdapter`, la liste en
`SliverGrid`. C'est une refonte de la structure de défilement d'un écran de
500 lignes, celui que la secrétaire utilise toute la journée, et elle se vérifie
**à l'œil**, pas à l'analyseur.

À trois semaines d'un déploiement national, la faire à l'aveugle serait
échanger un défaut mesuré contre un risque non mesuré.

*Effort : M · Entrée : `features/students/screens/eleves_screen.dart:455-495`
et `eleves_liste_parts.dart:238`. À faire avec l'application sous les yeux.*

---

## 6. Récapitulatif des changements de cette passe

| Fichier | Changement |
|---|---|
| `core/utils/paged_fetch.dart` | + `countsByMonth6m(...)` |
| `services/powersync/powersync_schema.dart` | + 78 index sur 44 tables, + l'en-tête qui dit pourquoi |
| 27 fichiers de `super_admin/`, `admin_groupe/`, `audit/` | 61 lectures paginées ou comptées (`fetchAllRows` : 17 → **75**) |
| `students/providers/students_provider.dart` | `createStudent(… tx:)` |
| `classes/providers/class_provider.dart` | `enrollStudent(… tx:)` |
| `students/providers/import_eleves_provider.dart` | une transaction par élève |
| `audit/providers/audit_models.dart` · `audit_data.dart` · `audit_charts_tab.dart` | `AuditTimeline.tronquee` + bandeau ; `audit_timeline.dart` extrait (dette des 500 lignes) |
| `pubspec.yaml` | `sqlite_async` déclaré explicitement |
| **`test/index_local_powersync_test.dart`** | nouveau garde |
| **`test/mille_lignes_ne_sont_pas_le_total_test.dart`** | nouveau garde |
