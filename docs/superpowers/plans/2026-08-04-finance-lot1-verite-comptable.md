# Finance — Lot 1 : la vérité comptable

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Borner les paiements à l'année scolaire, rendre « Élèves à jour » vrai en calculant un dû réel, et permettre un remboursement qui porte son montant et son motif.

**Architecture:** Trois corrections sur le module Finance de l'espace école (offline-first PowerSync). L'année scolaire devient une colonne de `student_payments` au lieu d'être déduite par jointure — ce qui répare aussi le tableau de bord, où un paiement sans inscription rattachée disparaissait des totaux. Le dû se calcule par une fonction pure à partir des barèmes applicables au niveau de l'élève ; l'état d'un élève devient à quatre valeurs, dont « barème non défini », qui est la vérité tant que le groupe n'a rien saisi. Le remboursement réutilise les colonnes livrées par la migration 0094.

**Tech Stack:** Flutter 3 · Riverpod · PowerSync (SQLite local) · Supabase/PostgreSQL 17

## Global Constraints

- **Espace école = offline-first.** `db.watch()` / `db.execute()` uniquement. **Jamais `supabase.from()`** dans `features/finance/`.
- **Dart ≤ 500 lignes par fichier** (alerte à 400). `paiements_sheet.dart` est déjà à 488 : toute addition va dans un nouveau fichier.
- **`flutter analyze` à 0 issue.**
- **Type local = type serveur** pour toute colonne numérique (`Column.integer` ↔ `integer`).
- **Sync-rules** : le bucket projette `SELECT * FROM student_payments WHERE school_id = bucket.sid`. Les nouvelles colonnes passent par le `*`. **Aucune modification de sync-rules dans ce lot.**
- Migrations à partir de **0095** (dernière appliquée : 0094).
- Commandes depuis `epilote/` ; binaires dans `/home/melack/flutter/bin/`.
- Base : `PGPASSWORD='069698620libe' psql -h aws-1-eu-central-2.pooler.supabase.com -p 5432 -U postgres.wqpdamlnrwgozfvzjjpo -d postgres -v ON_ERROR_STOP=1 -f <fichier>`

## Découpage révisé

Les **exonérations** quittent ce lot pour le lot 2. Elles supposent que le groupe ait défini ses motifs : les livrer ici obligerait l'école à constater des motifs que personne n'aurait encore saisis. Elles rejoignent les écrans `admin_groupe` du lot 2.

## Structure des fichiers

| Fichier | Responsabilité |
|---|---|
| `epilote/lib/features/finance/services/obligation.dart` **(créé)** | Décisions pures : dû d'un barème, mois écoulés, état d'un élève. Aucun accès base. |
| `epilote/lib/features/finance/providers/paiements_provider.dart` **(modifié)** | `academic_year_id` en écriture et en filtre ; calcul du dû par élève et par classe. |
| `epilote/lib/features/finance/screens/paiements_remboursement.dart` **(créé)** | Boîte de remboursement (possède son contrôleur). |
| `epilote/lib/features/user/providers/dashboard_provider.dart` **(modifié)** | La jointure de contournement disparaît. |
| `epilote/lib/services/powersync/powersync_schema.dart` **(modifié)** | `academic_year_id` local. |
| `database/migrations/0095_le_paiement_connait_son_annee.sql` **(créé)** | Colonne + index. |
| `epilote/test/obligation_test.dart` **(créé)** | Garde-fous du dû et de l'état. |

---

### Task 1 : Le paiement connaît son année

**Files:**
- Create: `database/migrations/0095_le_paiement_connait_son_annee.sql`
- Modify: `epilote/lib/services/powersync/powersync_schema.dart` (table `student_payments`)
- Modify: `epilote/lib/features/finance/providers/paiements_provider.dart`
- Modify: `epilote/lib/features/finance/screens/paiements_sheet.dart` (`_PaymentFormState._save`)
- Modify: `epilote/lib/features/user/providers/dashboard_provider.dart:104-131`

**Interfaces:**
- Produces : `savePayment` gagne `required String academicYearId` ; tous les lecteurs filtrent sur cette colonne.

- [ ] **Step 1 : Écrire la migration**

```sql
-- ════════════════════════════════════════════════════════════════════════════
--  0095 — LE PAIEMENT CONNAÎT SON ANNÉE
--
--  `student_payments` n'avait aucune colonne d'année, et aucune requête n'en
--  filtrait : à la rentrée 2027, les versements de 2026 auraient compté comme
--  payés. À l'échelle nationale, c'est une falsification comptable silencieuse.
--
--  Le tableau de bord contournait le manque par une jointure sur
--  `class_enrollments` — ce qui faisait DISPARAÎTRE de ses totaux tout paiement
--  sans inscription rattachée, à commencer par les frais d'examen
--  (`savePayment` accepte un `enrollment_id` nul).
--
--  La table est vide (0 ligne) : le NOT NULL est gratuit, aucune reprise.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

ALTER TABLE student_payments
  ADD COLUMN IF NOT EXISTS academic_year_id uuid REFERENCES academic_years(id);

ALTER TABLE student_payments
  ALTER COLUMN academic_year_id SET NOT NULL;

CREATE INDEX IF NOT EXISTS idx_student_payments_academic_year
  ON student_payments (academic_year_id);

-- Un encaissement se retrouve par école ET par année : c'est la requête de
-- toutes les pages Finance.
CREATE INDEX IF NOT EXISTS idx_student_payments_school_year
  ON student_payments (school_id, academic_year_id);

COMMIT;
```

- [ ] **Step 2 : Vérifier que la table est bien vide avant le NOT NULL**

```bash
PGPASSWORD='069698620libe' psql -h aws-1-eu-central-2.pooler.supabase.com -p 5432 \
  -U postgres.wqpdamlnrwgozfvzjjpo -d postgres -t -c \
  "SELECT COUNT(*) FROM student_payments;"
```
Expected : `0`. **Si ce n'est pas 0, ARRÊTER** : le `SET NOT NULL` échouerait, et forcer détruirait des encaissements.

- [ ] **Step 3 : Appliquer**

```bash
cd /home/melack/E-PILOTE
PGPASSWORD='069698620libe' psql -h aws-1-eu-central-2.pooler.supabase.com -p 5432 \
  -U postgres.wqpdamlnrwgozfvzjjpo -d postgres -v ON_ERROR_STOP=1 \
  -f database/migrations/0095_le_paiement_connait_son_annee.sql
```
Expected : `BEGIN … COMMIT`, sans `ERROR`.

- [ ] **Step 4 : Déclarer la colonne en local**

Dans `powersync_schema.dart`, table `student_payments`, après `Column.text('enrollment_id'),` :

```dart
    // ⚠️ NOT NULL en base (migration 0095). Une écriture locale sans année
    // ferait rejeter le lot ENTIER (23502) et perdrait le paiement.
    Column.text('academic_year_id'),
```

- [ ] **Step 5 : L'écriture porte l'année**

Dans `paiements_provider.dart`, `savePayment` : ajouter `required String academicYearId,` à la signature (après `required String schoolId,`), la colonne `academic_year_id` à l'`INSERT` et sa valeur aux paramètres.

- [ ] **Step 6 : Le formulaire fournit l'année**

Dans `paiements_sheet.dart`, `_PaymentFormState._save`, avant la construction de `missing` :

```dart
    final yearId = ref.read(activeYearIdProvider);
```
Ajouter `if (!isUsableId(yearId)) 'année scolaire active',` à la liste `missing`, et `academicYearId: yearId!,` à l'appel `savePayment(`.

- [ ] **Step 7 : Les trois lecteurs filtrent l'année**

`paymentsOverviewProvider` : ajouter `AND sp.academic_year_id = ?` et le paramètre.
`classPaymentsProvider` : les deux sous-requêtes `SUM`/`COUNT`/`MAX` gagnent `AND p.academic_year_id = ?`. Le provider devient `family` sur un enregistrement `({String classId, String yearId})`.
`studentPaymentsProvider` : idem, `family` sur `({String studentId, String yearId})`.

- [ ] **Step 8 : Le tableau de bord perd sa jointure de contournement**

Dans `dashboard_provider.dart`, remplacer le corps de la requête de `paymentsSummaryProvider` par :

```sql
        SELECT
          COALESCE(SUM(CASE WHEN status = 'confirmed' THEN amount_xaf ELSE 0 END), 0) AS enc,
          COALESCE(SUM(CASE WHEN status = 'pending'   THEN amount_xaf ELSE 0 END), 0) AS att
        FROM student_payments
        WHERE school_id = ? AND academic_year_id = ?
```
et remplacer le commentaire d'en-tête qui décrit le contournement.

⚠️ Le `<> 'confirmed'` d'origine comptait les paiements **annulés** dans « En attente ». Passer à `= 'pending'`.

- [ ] **Step 9 : Vérifier**

Run : `cd epilote && flutter analyze && flutter test`
Expected : `No issues found!` et suite au vert.

- [ ] **Step 10 : Commit**

```bash
git add database/migrations/0095_le_paiement_connait_son_annee.sql epilote/lib/services/powersync/powersync_schema.dart epilote/lib/features/finance/ epilote/lib/features/user/providers/dashboard_provider.dart
git commit -m "fix(finance) : un paiement sait à quelle année il appartient

Aucune colonne d'année, aucun filtre : à la rentrée 2027 les versements de
2026 auraient compté comme payés.

Le tableau de bord contournait le manque par une jointure sur l'inscription,
ce qui faisait disparaître de ses totaux tout paiement sans inscription
rattachée — les frais d'examen au premier chef. La jointure disparaît. Au
passage, « En attente » comptait les paiements ANNULÉS.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2 : Le dû, le versé, le reste

**Files:**
- Create: `epilote/lib/features/finance/services/obligation.dart`
- Test: `epilote/test/obligation_test.dart`

**Interfaces:**
- Produces :
  - `enum EtatObligation { sansBareme, aJour, partiel, impaye }`
  - `int duPourBareme({required String feeType, required int montant, required int moisEcoules})`
  - `int moisEcoules({required DateTime debut, required DateTime fin, required DateTime maintenant})`
  - `EtatObligation etatObligation({required int du, required int verse})`
  - `String libelleEtat(EtatObligation e)`

- [ ] **Step 1 : Écrire les tests qui échouent**

Créer `epilote/test/obligation_test.dart` :

```dart
import 'package:epilote/features/finance/services/obligation.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CE QUE L'ÉLÈVE DOIT (spec §6.5, §5.7)
//
//  « Élèves à jour » comptait tout élève ayant versé AU MOINS UN FRANC. Un
//  élève qui verse 1 000 sur 90 000 était compté à jour, parce qu'aucun
//  montant dû n'existait nulle part.
//
//  Le dû se déduit des barèmes applicables. Trois cas seulement pour les
//  8 130 élèves du public — inscription, cotisation APE, frais d'examen — qui
//  se règlent en une fois. La mensualité, qui n'existe que dans le privé
//  (974 élèves), s'échelonne sur les mois écoulés : aucune table d'échéances.
// ════════════════════════════════════════════════════════════════════════════

void main() {
  group('dû d\'un barème', () {
    test('un frais unique est dû en entier dès le premier jour', () {
      for (final t in ['inscription', 'cotisation_ape', 'frais_examens', 'autre']) {
        expect(duPourBareme(feeType: t, montant: 5000, moisEcoules: 1), 5000,
            reason: '$t se règle en une fois');
      }
    });

    test('une mensualité s\'accumule mois après mois', () {
      expect(duPourBareme(feeType: 'mensualite', montant: 25000, moisEcoules: 1),
          25000);
      expect(duPourBareme(feeType: 'mensualite', montant: 25000, moisEcoules: 4),
          100000);
    });

    test('une mensualité avant le début de l\'année ne doit rien', () {
      expect(duPourBareme(feeType: 'mensualite', montant: 25000, moisEcoules: 0),
          0);
    });
  });

  group('mois écoulés', () {
    final debut = DateTime(2025, 10, 1);
    final fin = DateTime(2026, 7, 31);

    test('le premier mois compte dès la rentrée', () {
      expect(
          moisEcoules(
              debut: debut, fin: fin, maintenant: DateTime(2025, 10, 2)),
          1);
    });

    test('quatre mois début janvier', () {
      expect(
          moisEcoules(debut: debut, fin: fin, maintenant: DateTime(2026, 1, 5)),
          4);
    });

    test('avant la rentrée, rien n\'est dû', () {
      expect(
          moisEcoules(debut: debut, fin: fin, maintenant: DateTime(2025, 8, 30)),
          0);
    });

    test('après la fin, le compteur se fige sur l\'année entière', () {
      // Sans plafond, un élève consulté en 2030 devrait 60 mensualités.
      expect(
          moisEcoules(debut: debut, fin: fin, maintenant: DateTime(2030, 1, 1)),
          10);
    });
  });

  group('état d\'un élève', () {
    test('sans barème, on ne peut RIEN dire — surtout pas « à jour »', () {
      // 30 écoles publiques n'ont aucun barème : les déclarer à jour serait
      // aussi faux que de les déclarer débitrices.
      expect(etatObligation(du: 0, verse: 0), EtatObligation.sansBareme);
      expect(etatObligation(du: 0, verse: 5000), EtatObligation.sansBareme);
    });

    test('rien versé sur un dû : impayé', () {
      expect(etatObligation(du: 5000, verse: 0), EtatObligation.impaye);
    });

    test('une avance n\'est PAS être à jour', () {
      // Le défaut historique : 2 000 sur 5 000 comptait comme réglé.
      expect(etatObligation(du: 5000, verse: 2000), EtatObligation.partiel);
    });

    test('le compte exact est à jour', () {
      expect(etatObligation(du: 5000, verse: 5000), EtatObligation.aJour);
    });

    test('un trop-versé reste à jour — le dépassement se traite ailleurs', () {
      expect(etatObligation(du: 5000, verse: 7000), EtatObligation.aJour);
    });
  });

  group('libellés', () {
    test('chaque état a un libellé lisible', () {
      for (final e in EtatObligation.values) {
        expect(libelleEtat(e), isNotEmpty);
      }
    });
  });
}
```

- [ ] **Step 2 : Lancer pour vérifier l'échec**

Run : `cd epilote && flutter test test/obligation_test.dart`
Expected : FAIL — `Undefined name 'duPourBareme'`.

- [ ] **Step 3 : Écrire l'implémentation**

Créer `epilote/lib/features/finance/services/obligation.dart` :

```dart
// ════════════════════════════════════════════════════════════════════════════
//  CE QUE L'ÉLÈVE DOIT — décisions pures
//
//  « Élèves à jour » comptait tout élève ayant versé AU MOINS UN FRANC, faute
//  d'un montant dû quelque part. Le dû se déduit ici des barèmes applicables,
//  sans aucune table d'échéances : un frais unique est dû en entier, une
//  mensualité s'accumule sur les mois écoulés.
//
//  Les 8 130 élèves du public n'ont que des frais uniques — inscription,
//  cotisation APE, frais d'examen. La mensualité ne concerne que les 974
//  élèves du privé.
// ════════════════════════════════════════════════════════════════════════════

/// Où en est un élève vis-à-vis de ce qu'il doit.
enum EtatObligation {
  /// Aucun barème ne s'applique : on ne peut rien affirmer. Ce n'est PAS
  /// « à jour » — 30 écoles publiques sont dans ce cas et les déclarer réglées
  /// serait aussi faux que de les déclarer débitrices.
  sansBareme,
  aJour,
  partiel,
  impaye,
}

String libelleEtat(EtatObligation e) => switch (e) {
      EtatObligation.sansBareme => 'Barème non défini',
      EtatObligation.aJour => 'À jour',
      EtatObligation.partiel => 'Avance partielle',
      EtatObligation.impaye => 'Impayé',
    };

/// Nombre de mois entamés depuis la rentrée, plafonné à l'année scolaire.
///
/// Le plafond n'est pas cosmétique : sans lui, un dossier consulté deux ans
/// plus tard afficherait vingt-quatre mensualités dues.
int moisEcoules({
  required DateTime debut,
  required DateTime fin,
  required DateTime maintenant,
}) {
  final total = (fin.year - debut.year) * 12 + (fin.month - debut.month) + 1;
  if (maintenant.isBefore(debut)) return 0;
  final ecoules =
      (maintenant.year - debut.year) * 12 + (maintenant.month - debut.month) + 1;
  return ecoules > total ? total : ecoules;
}

/// Ce qu'un barème réclame à cette date.
int duPourBareme({
  required String feeType,
  required int montant,
  required int moisEcoules,
}) =>
    feeType == 'mensualite' ? montant * moisEcoules : montant;

/// L'état d'un élève au vu de ce qu'il doit et de ce qu'il a versé.
EtatObligation etatObligation({required int du, required int verse}) {
  if (du <= 0) return EtatObligation.sansBareme;
  if (verse >= du) return EtatObligation.aJour;
  if (verse > 0) return EtatObligation.partiel;
  return EtatObligation.impaye;
}
```

- [ ] **Step 4 : Lancer pour vérifier le succès**

Run : `cd epilote && flutter test test/obligation_test.dart`
Expected : PASS — 13 tests.

- [ ] **Step 5 : Commit**

```bash
git add epilote/lib/features/finance/services/obligation.dart epilote/test/obligation_test.dart
git commit -m "feat(finance) : ce que l'élève doit, et non ce qu'il a versé

« Élèves à jour » comptait tout élève ayant versé au moins un franc : 1 000 sur
90 000 valait réglé. Le dû se déduit désormais des barèmes applicables.

Un quatrième état apparaît, « barème non défini » — c'est la seule chose vraie
tant que le groupe n'a rien saisi, et 30 écoles publiques sont dans ce cas.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3 : Brancher le dû sur les écrans

**Files:**
- Modify: `epilote/lib/features/finance/providers/paiements_provider.dart`
- Modify: `epilote/lib/features/finance/screens/paiements_screen.dart`

**Interfaces:**
- Consumes : Task 1 (année), Task 2 (`etatObligation`, `duPourBareme`, `moisEcoules`).
- Produces : `PaymentsOverview` gagne `duTotal`, `aJour` ; `StudentPayRow` gagne `du` et `etat`.

- [ ] **Step 1 : Un provider du dû par niveau**

Dans `paiements_provider.dart`, ajouter un provider qui lit les barèmes actifs de l'année et les indexe par `applies_to_level_id` (`null` = toute l'école). ⚠️ Lire **`school_id = ? OR school_id IS NULL`** dès maintenant : le lot 2 fera remonter les barèmes au groupe, et cette requête doit déjà les voir.

- [ ] **Step 2 : `paymentsOverviewProvider` compte les élèves À JOUR**

`ok:` passe de « a versé quelque chose » à `etatObligation(...) == EtatObligation.aJour`. `VsCoverageRow.note` affiche le reste dû de la classe.

- [ ] **Step 3 : Les libellés cessent de mentir**

`paiements_screen.dart` : `metricLabel: 'Ont payé'` → `'À jour'`, et le KPI hero « Élèves à jour · X% ont payé » → « X% à jour ». Quand aucun barème n'existe, afficher `libelleEtat(EtatObligation.sansBareme)` à la place du taux.

- [ ] **Step 4 : Vérifier**

Run : `cd epilote && flutter analyze && flutter test`

- [ ] **Step 5 : Commit**

---

### Task 4 : Le remboursement

**Files:**
- Create: `epilote/lib/features/finance/screens/paiements_remboursement.dart`
- Modify: `epilote/lib/features/finance/providers/paiements_provider.dart`
- Modify: `epilote/lib/features/finance/screens/paiements_sheet.dart`

**Interfaces:**
- Produces : `bool peutRembourserPaiement(String? status)`, `String? montantRemboursementInvalide(int montant, int encaisse)`, `Future<void> refundPayment({required String id, required int montant, required String motif, required String actorId})`.

- [ ] **Step 1 : Tests des décisions**

Ajouter à `epilote/test/paiement_annulation_test.dart` :

```dart
  group('remboursement', () {
    test('seul un paiement confirmé se rembourse', () {
      expect(peutRembourserPaiement('confirmed'), isTrue);
      expect(peutRembourserPaiement('pending'), isFalse);
      expect(peutRembourserPaiement('cancelled'), isFalse);
      expect(peutRembourserPaiement('refunded'), isFalse);
    });

    test('on ne rembourse jamais plus qu\'on n\'a encaissé', () {
      // Le CHECK serveur (0094) le refuse : le dire AVANT la synchro évite de
      // perdre la transaction dans le journal d'échecs.
      expect(montantRemboursementInvalide(6000, 5000), isNotNull);
      expect(montantRemboursementInvalide(0, 5000), isNotNull);
      expect(montantRemboursementInvalide(-1, 5000), isNotNull);
      expect(montantRemboursementInvalide(5000, 5000), isNull);
      expect(montantRemboursementInvalide(2000, 5000), isNull);
    });
  });
```

- [ ] **Step 2 : Lancer pour vérifier l'échec, puis implémenter, puis vérifier le succès**

`refundPayment` écrit `status='refunded'`, `refunded_amount_xaf`, `refunded_at`, `refunded_by`, `refund_reason`.

- [ ] **Step 3 : La boîte de remboursement**

⚠️ Elle **possède son contrôleur** et le libère dans son propre `dispose()` — `await showDialog` rend la main au `pop`, pas à la fin de l'animation (écran rouge `_dependents.isEmpty`, constaté au lot 0).
Fichier séparé : `paiements_sheet.dart` est à 488 lignes.

- [ ] **Step 4 : Le bouton dans la fiche élève**

Visible seulement si `peutRembourserPaiement(p.status)`.

- [ ] **Step 5 : Vérifier, puis commit**

---

### Task 5 : Recette à l'écran

- [ ] `flutter build linux --debug` puis lancer, se connecter (PIN `1234`, proviseur du Lycée Technique du 1er Mai).
- [ ] Finance ▸ Paiements : sans aucun barème, l'écran affiche **« Barème non défini »** et non « 0 % ont payé ».
- [ ] Créer un barème (Frais de scolarité), revenir : le taux apparaît, les élèves sont **impayés**.
- [ ] Enregistrer une avance partielle : l'élève passe **« Avance partielle »**, pas « à jour ».
- [ ] Solder : l'élève passe **« À jour »**.
- [ ] Rembourser : montant supérieur refusé, montant valide accepté, ligne marquée remboursée.
- [ ] **Purger les données de test de la production** avant de conclure.

## Auto-relecture

**Couverture** : §5.3 (année) → Task 1 · §6.5 (dû réel) → Tasks 2-3 · §5.3 (remboursement doté d'un contenu) → Task 4. Les **exonérations (§5.4) sont volontairement reportées au lot 2**, avec les écrans du groupe qui définissent les motifs.

**Cohérence des types** : `EtatObligation` porte le même nom en Tasks 2 et 3. `etatObligation({du, verse})` a la même signature partout. `academicYearId` est un `String` non-nullable dans `savePayment` (Task 1, Step 5 et 6).

**Risque connu** : le `SET NOT NULL` de la Task 1 suppose la table vide — le Step 2 le vérifie et impose l'arrêt sinon.
