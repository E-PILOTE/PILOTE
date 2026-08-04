# Finance — Lot 0 : le reçu ne perd plus d'argent

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rendre l'encaissement d'un élève infaillible hors ligne — numéro de reçu qui ne peut plus entrer en collision, reçu papier imprimable, et annulation traçable au lieu d'une suppression sèche.

**Architecture:** Trois corrections indépendantes sur le module Finance de l'espace école (offline-first PowerSync). Le numéro de reçu devient une fonction pure de (code école, année, identité du poste, séquence locale) — l'unicité ne dépend d'aucune coordination réseau. La contrainte d'unicité en base passe de nationale à `(school_id, receipt_number)`. La suppression d'un paiement est remplacée par une annulation qui conserve la ligne, son auteur et son motif. Le reçu PDF réutilise `AttestationKit` (page unique, chrome officiel partagé).

**Tech Stack:** Flutter 3 · Riverpod · PowerSync (SQLite local) · Supabase/PostgreSQL 17 · package `pdf` + `printing`

## Global Constraints

- **Architecture non négociable** : l'espace école est offline-first. Toute lecture/écriture passe par `db.watch()` / `db.execute()` (PowerSync). **Jamais `supabase.from()`** dans `features/finance/`.
- **Taille de fichier** : cible ≤ 500 lignes par fichier Dart, alerte à 400. Découper par responsabilité.
- **`flutter analyze` doit rester à 0 issue.**
- **Trois endroits** : toute colonne lue hors ligne doit exister en base, dans `powersync_schema.dart`, **et** dans les sync-rules. Ici le bucket projette `SELECT * FROM student_payments WHERE school_id = bucket.sid` (`powersync/config/sync-rules.yaml:231`) : les nouvelles colonnes sont couvertes par le `*`, **aucune modification de sync-rules n'est requise pour ce lot**. Ne pas y toucher.
- **Type local = type serveur** pour toute colonne numérique (`Column.integer` ↔ `integer`). Un `real` local contre un `integer` serveur fait rejeter le lot entier (code 22P02) et perd le paiement.
- **PDF** : `pw.Page`, **jamais** `pw.MultiPage` (`MultiPage` lève `TooManyPages` sur un `frame()` non scindable). Chrome via `OfficialPdfKit` / `AttestationKit`, aperçu via `showPdfPreviewDialog`.
- **Devise** : XAF (FCFA), entier. Formatage par `fmtXaf` / `fmtCompact` (`core/widgets/admin_ui.dart`).
- **Migrations** : numérotées à partir de `0094` (dernière appliquée : `0093`). Répertoire `database/migrations/`.
- **`audit_logs.action` est `varchar(20)`** — tout libellé d'action doit tenir en 20 caractères.
- Commandes depuis `epilote/` : `flutter test`, `flutter analyze`, `flutter build linux --debug`.
  Binaires dans `/home/melack/flutter/bin/`.
- Connexion base (migrations) :
  `PGPASSWORD='069698620libe' psql -h aws-1-eu-central-2.pooler.supabase.com -p 5432 -U postgres.wqpdamlnrwgozfvzjjpo -d postgres -f <fichier.sql>`
  ⚠️ `psql -c "BEGIN; … ROLLBACK;"` en une seule chaîne **ne restaure rien de fiable** : ne jamais s'en servir pour « essayer » une migration.

## Contexte du défaut corrigé

`epilote/lib/features/finance/providers/paiements_provider.dart:236` :

```dart
final receipt = 'REC-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
```

`millisecondsSinceEpoch` fait 13 chiffres ; `substring(7)` en garde **6** → le numéro recommence **toutes les 16 min 40 s**. En base, `student_payments_receipt_number_key UNIQUE (receipt_number)` impose l'unicité **sur tout le pays**. Une collision produit le code PostgreSQL `23505`, capté par `^23...$` dans `_fatalResponseCodes` (`powersync_connector.dart:11`) → la transaction est **abandonnée** et le paiement est **définitivement perdu**. Loi des anniversaires sur 10⁶ valeurs : ~2 000 encaissements suffisent pour une probabilité de 86 %.

Spécification de référence : `docs/superpowers/specs/2026-08-04-frais-scolarite-public-prive-design.md` §6.1, §6.2.

## Structure des fichiers

| Fichier | Responsabilité |
|---|---|
| `epilote/lib/features/finance/services/receipt_number.dart` **(créé)** | Décisions pures du numéro de reçu : format, extraction de séquence, séquence suivante. Aucun accès base, aucun `DateTime.now()`. |
| `epilote/lib/features/finance/services/poste_tag.dart` **(créé)** | Étiquette stable de l'appareil (SharedPreferences). Seul effet de bord du numéro de reçu. |
| `epilote/lib/features/finance/services/recu_pdf_service.dart` **(créé)** | Construction du reçu PDF. Ne connaît que son contenu, pas la mise en page officielle. |
| `epilote/lib/features/finance/providers/paiements_provider.dart` **(modifié)** | `savePayment` appelle le nouveau numéroteur ; `deletePayment` → `cancelPayment` ; `PaymentRow` porte le nécessaire au reçu. |
| `epilote/lib/features/finance/screens/paiements_sheet.dart` **(modifié)** | Bouton « Annuler » (motif obligatoire) et bouton « Reçu ». |
| `epilote/lib/services/powersync/powersync_schema.dart` **(modifié)** | Nouvelles colonnes locales de `student_payments`. |
| `database/migrations/0094_le_recu_ne_perd_plus_d_argent.sql` **(créé)** | Unicité par école, colonnes d'annulation et de remboursement. |
| `epilote/test/receipt_number_test.dart` **(créé)** | Garde-fou de non-régression sur la collision. |
| `epilote/test/paiement_annulation_test.dart` **(créé)** | Décisions d'annulation. |

---

### Task 1 : Le numéro de reçu ne peut plus entrer en collision

**Files:**
- Create: `epilote/lib/features/finance/services/receipt_number.dart`
- Test: `epilote/test/receipt_number_test.dart`

**Interfaces:**
- Consumes: rien (premier maillon).
- Produces:
  - `String formatReceiptNumber({required String? schoolCode, required int year, required String posteTag, required int sequence})`
  - `int? sequenceDansRecu(String receipt, {required String prefixe})`
  - `int prochaineSequence(Iterable<String?> recusExistants, {required String prefixe})`
  - `String prefixeRecu({required String? schoolCode, required int year, required String posteTag})`

- [ ] **Step 1: Écrire les tests qui échouent**

Créer `epilote/test/receipt_number_test.dart` :

```dart
import 'package:epilote/features/finance/services/receipt_number.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE NUMÉRO DE REÇU (spec §6.1)
//
//  L'ancien numéro valait `REC-` + les 6 derniers chiffres de l'horloge en
//  millisecondes : il recommençait toutes les 16 min 40 s, sous une contrainte
//  d'unicité NATIONALE. La collision produisait un 23505, que le connecteur
//  PowerSync traite comme définitif — la transaction était abandonnée et le
//  paiement perdu, alors que le parent était reparti avec son papier.
//
//  L'unicité doit tenir SANS RÉSEAU. Elle repose donc sur deux choses que le
//  poste possède seul : son étiquette d'appareil, et une séquence qu'il relit
//  dans sa propre base. Le code de l'école n'est là que pour la lisibilité.
// ════════════════════════════════════════════════════════════════════════════

void main() {
  group('format du numéro', () {
    test('assemble école, année, poste et séquence', () {
      expect(
        formatReceiptNumber(
            schoolCode: 'METPLTAOWANDO',
            year: 2026,
            posteTag: 'a3f19c',
            sequence: 147),
        'REC-PLTAOWANDO-26-A3F19C-000147',
      );
    });

    test('ne dépasse jamais les 50 caractères de la colonne', () {
      final n = formatReceiptNumber(
        schoolCode: 'X' * 50,
        year: 2026,
        posteTag: 'ffffff',
        sequence: 999999,
      );
      expect(n.length, lessThanOrEqualTo(50));
    });

    test('une école sans code reste numérotable', () {
      expect(
        formatReceiptNumber(
            schoolCode: null, year: 2026, posteTag: 'a3f19c', sequence: 1),
        'REC-ECOLE-26-A3F19C-000001',
      );
    });

    test('deux postes de la même école ne collisionnent pas', () {
      final a = formatReceiptNumber(
          schoolCode: 'KIN01', year: 2026, posteTag: 'aaaaaa', sequence: 12);
      final b = formatReceiptNumber(
          schoolCode: 'KIN01', year: 2026, posteTag: 'bbbbbb', sequence: 12);
      expect(a, isNot(b));
    });

    test('deux encaissements de la même milliseconde ne collisionnent pas',
        () {
      // Le défaut historique : le numéro ne dépendait QUE de l'horloge.
      final a = formatReceiptNumber(
          schoolCode: 'KIN01', year: 2026, posteTag: 'aaaaaa', sequence: 1);
      final b = formatReceiptNumber(
          schoolCode: 'KIN01', year: 2026, posteTag: 'aaaaaa', sequence: 2);
      expect(a, isNot(b));
    });
  });

  group('séquence suivante', () {
    const prefixe = 'REC-KIN01-26-A3F19C-';

    test('part à 1 sur un poste neuf', () {
      expect(prochaineSequence(const [], prefixe: prefixe), 1);
    });

    test('reprend après le plus grand numéro DÉJÀ en base', () {
      // Après une purge, les paiements redescendent par la synchro : relire la
      // base est ce qui empêche la séquence de repartir à 1 et de percuter des
      // reçus déjà émis par ce même poste.
      expect(
        prochaineSequence(
          const [
            'REC-KIN01-26-A3F19C-000003',
            'REC-KIN01-26-A3F19C-000011',
            'REC-KIN01-26-A3F19C-000007',
          ],
          prefixe: prefixe,
        ),
        12,
      );
    });

    test('ignore les reçus des AUTRES postes', () {
      expect(
        prochaineSequence(
          const [
            'REC-KIN01-26-BBBBBB-000900',
            'REC-KIN01-26-A3F19C-000004',
          ],
          prefixe: prefixe,
        ),
        5,
      );
    });

    test('ignore les valeurs nulles et les anciens formats', () {
      expect(
        prochaineSequence(
          const [null, 'REC-482913', '', 'REC-KIN01-26-A3F19C-000002'],
          prefixe: prefixe,
        ),
        3,
      );
    });
  });

  group('extraction de séquence', () {
    test('lit la séquence d\'un reçu du bon préfixe', () {
      expect(
        sequenceDansRecu('REC-KIN01-26-A3F19C-000042',
            prefixe: 'REC-KIN01-26-A3F19C-'),
        42,
      );
    });

    test('refuse un reçu d\'un autre préfixe', () {
      expect(
        sequenceDansRecu('REC-KIN01-26-BBBBBB-000042',
            prefixe: 'REC-KIN01-26-A3F19C-'),
        isNull,
      );
    });

    test('refuse l\'ancien format horodaté', () {
      expect(sequenceDansRecu('REC-482913', prefixe: 'REC-KIN01-26-A3F19C-'),
          isNull);
    });
  });
}
```

- [ ] **Step 2: Lancer les tests pour vérifier qu'ils échouent**

Run: `cd epilote && flutter test test/receipt_number_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'epilote' ... receipt_number.dart` / `Undefined name 'formatReceiptNumber'`.

- [ ] **Step 3: Écrire l'implémentation minimale**

Créer `epilote/lib/features/finance/services/receipt_number.dart` :

```dart
// ════════════════════════════════════════════════════════════════════════════
//  LE NUMÉRO DE REÇU — décisions pures
//
//  Un reçu est une pièce comptable : son numéro doit être unique, et il doit
//  l'être SANS RÉSEAU. L'ancien numéro (`REC-` + 6 derniers chiffres de
//  l'horloge) recommençait toutes les 16 min 40 s sous une contrainte
//  d'unicité nationale ; la collision faisait abandonner la transaction
//  PowerSync et perdait l'encaissement (cf. spec §6.1).
//
//  L'unicité repose désormais sur deux choses que le poste possède seul :
//  son ÉTIQUETTE D'APPAREIL, et une SÉQUENCE qu'il relit dans sa propre base.
//  Le code de l'école n'entre pas dans l'unicité — la contrainte est passée à
//  (school_id, receipt_number) — il n'est là que pour la lisibilité du papier.
// ════════════════════════════════════════════════════════════════════════════

/// Longueur maximale de `student_payments.receipt_number` en base.
const int kReceiptMaxLength = 50;

/// Nombre de caractères du code d'école conservés dans le numéro.
///
/// On garde la FIN du code, pas le début : les codes officiels commencent par
/// le préfixe de tutelle (« METPLTAOWANDO »), qui est justement la partie non
/// discriminante.
const int _kCodeLength = 10;

const String _kCodeSansEcole = 'ECOLE';

String _codeCourt(String? schoolCode) {
  final brut =
      (schoolCode ?? '').toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  if (brut.isEmpty) return _kCodeSansEcole;
  return brut.length <= _kCodeLength
      ? brut
      : brut.substring(brut.length - _kCodeLength);
}

/// Tout ce qui précède la séquence. Deux reçus de même préfixe viennent du même
/// poste, de la même école et de la même année.
String prefixeRecu({
  required String? schoolCode,
  required int year,
  required String posteTag,
}) =>
    'REC-${_codeCourt(schoolCode)}-'
    '${(year % 100).toString().padLeft(2, '0')}-'
    '${posteTag.toUpperCase()}-';

/// Le numéro tel qu'il s'imprime sur le papier du parent.
String formatReceiptNumber({
  required String? schoolCode,
  required int year,
  required String posteTag,
  required int sequence,
}) =>
    prefixeRecu(schoolCode: schoolCode, year: year, posteTag: posteTag) +
    sequence.toString().padLeft(6, '0');

/// La séquence portée par ce reçu, ou `null` s'il ne vient pas de ce préfixe
/// (autre poste, autre année, ou ancien format horodaté).
int? sequenceDansRecu(String receipt, {required String prefixe}) {
  if (!receipt.startsWith(prefixe)) return null;
  return int.tryParse(receipt.substring(prefixe.length));
}

/// La prochaine séquence libre, déduite des reçus DÉJÀ présents en base locale.
///
/// Relire la base plutôt que tenir un compteur à part est délibéré : après une
/// purge du poste, les paiements redescendent par la synchro. Un compteur
/// reparti à zéro rééditerait des numéros déjà émis par ce même poste — et
/// chaque doublon coûterait un paiement.
int prochaineSequence(Iterable<String?> recusExistants,
    {required String prefixe}) {
  var max = 0;
  for (final r in recusExistants) {
    if (r == null || r.isEmpty) continue;
    final n = sequenceDansRecu(r, prefixe: prefixe);
    if (n != null && n > max) max = n;
  }
  return max + 1;
}
```

- [ ] **Step 4: Lancer les tests pour vérifier qu'ils passent**

Run: `cd epilote && flutter test test/receipt_number_test.dart`
Expected: PASS — 12 tests.

- [ ] **Step 5: Vérifier la contrainte de longueur du test « 50 caractères »**

Le code court plafonne à 10, l'année à 2, la séquence à 6, le tag à 6 →
`4 + 10 + 1 + 2 + 1 + 6 + 1 + 6 = 31`. Confirmé par le test.

Run: `cd epilote && flutter analyze lib/features/finance/services/receipt_number.dart`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
cd /home/melack/E-PILOTE
git add epilote/lib/features/finance/services/receipt_number.dart epilote/test/receipt_number_test.dart
git commit -m "fix(finance) : un numéro de reçu qui ne recommence plus toutes les 16 minutes

Le numéro valait les 6 derniers chiffres de l'horloge en millisecondes, sous
une contrainte d'unicité nationale. La collision produisait un 23505, que le
connecteur PowerSync traite comme définitif : la transaction était abandonnée
et le paiement perdu, alors que le parent était reparti avec son papier.

L'unicité tient désormais sans réseau — étiquette du poste et séquence relue
dans la base locale, ce qui la fait survivre à une purge.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2 : L'étiquette stable du poste

**Files:**
- Create: `epilote/lib/features/finance/services/poste_tag.dart`
- Test: `epilote/test/receipt_number_test.dart` (ajout d'un groupe)

**Interfaces:**
- Consumes: `prefixeRecu` (Task 1) — pour le test d'intégration.
- Produces: `Future<String> posteTag()` — 6 caractères hexadécimaux minuscules, stables pour la durée de vie de l'installation.

- [ ] **Step 1: Écrire le test qui échoue**

Ajouter à la fin de `epilote/test/receipt_number_test.dart`, avant la dernière accolade de `main()` :

```dart
  group('étiquette du poste', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('fait 6 caractères hexadécimaux', () async {
      final t = await posteTag();
      expect(t, matches(RegExp(r'^[0-9a-f]{6}$')));
    });

    test('ne change pas d\'un appel à l\'autre', () async {
      // Si l'étiquette bougeait, la séquence repartirait à 1 sur un préfixe
      // neuf à chaque redémarrage — sans collision, mais avec une numérotation
      // illisible pour un contrôleur.
      expect(await posteTag(), await posteTag());
    });

    test('survit à un redémarrage de l\'application', () async {
      final premier = await posteTag();
      resetPosteTagCache();
      expect(await posteTag(), premier);
    });
  });
```

Et ajouter en tête du fichier de test :

```dart
import 'package:epilote/features/finance/services/poste_tag.dart';
import 'package:shared_preferences/shared_preferences.dart';
```

- [ ] **Step 2: Lancer le test pour vérifier qu'il échoue**

Run: `cd epilote && flutter test test/receipt_number_test.dart --name "étiquette du poste"`
Expected: FAIL — `Undefined name 'posteTag'`.

- [ ] **Step 3: Écrire l'implémentation minimale**

Créer `epilote/lib/features/finance/services/poste_tag.dart` :

```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

// ════════════════════════════════════════════════════════════════════════════
//  L'ÉTIQUETTE DU POSTE
//
//  Six caractères hexadécimaux, tirés une fois et conservés. C'est ce qui rend
//  deux reçus de deux postes distincts d'une même école impossibles à
//  confondre, SANS aucune coordination réseau — la seule propriété qui tienne
//  dans une école congolaise sans connexion.
//
//  Elle vit à côté de `epilote.identite_poste` (SessionKeeper), pas dedans :
//  l'identité du poste peut être oubliée par une déconnexion volontaire, alors
//  que la numérotation comptable, elle, ne doit jamais repartir de zéro.
//
//  16⁶ ≈ 16,7 millions de valeurs : sur un parc de 1 000 écoles de 5 postes, la
//  probabilité qu'UNE école ait deux postes de même étiquette est de l'ordre de
//  6 pour 10 000 — et il faudrait encore que les deux soient hors ligne au même
//  instant sur la même séquence pour que cela coûte quelque chose.
// ════════════════════════════════════════════════════════════════════════════

const String _kCle = 'epilote.poste_tag';

String? _cache;

/// Étiquette de CE poste, stable pour la durée de vie de l'installation.
Future<String> posteTag() async {
  final hit = _cache;
  if (hit != null) return hit;

  final prefs = await SharedPreferences.getInstance();
  final existant = prefs.getString(_kCle);
  if (existant != null && existant.length == 6) return _cache = existant;

  final neuf =
      const Uuid().v4().replaceAll('-', '').substring(0, 6).toLowerCase();
  await prefs.setString(_kCle, neuf);
  return _cache = neuf;
}

/// Vide le cache mémoire — utilisé par les tests pour simuler un redémarrage.
void resetPosteTagCache() => _cache = null;
```

- [ ] **Step 4: Lancer les tests pour vérifier qu'ils passent**

Run: `cd epilote && flutter test test/receipt_number_test.dart`
Expected: PASS — 15 tests.

- [ ] **Step 5: Commit**

```bash
cd /home/melack/E-PILOTE
git add epilote/lib/features/finance/services/poste_tag.dart epilote/test/receipt_number_test.dart
git commit -m "feat(finance) : une étiquette d'appareil qui survit aux redémarrages

Six caractères hexadécimaux tirés une fois. C'est ce qui distingue deux reçus
émis au même instant par deux postes d'une même école, sans réseau.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3 : Migration 0094 — unicité par école, annulation, remboursement

**Files:**
- Create: `database/migrations/0094_le_recu_ne_perd_plus_d_argent.sql`
- Modify: `epilote/lib/services/powersync/powersync_schema.dart:810-826`

**Interfaces:**
- Consumes: rien.
- Produces: colonnes `cancelled_at`, `cancelled_by`, `cancellation_reason`, `refunded_amount_xaf`, `refunded_at`, `refunded_by`, `refund_reason` sur `student_payments`, lisibles hors ligne.

- [ ] **Step 1: Écrire la migration**

Créer `database/migrations/0094_le_recu_ne_perd_plus_d_argent.sql` :

```sql
-- ════════════════════════════════════════════════════════════════════════════
--  0094 — LE REÇU NE PERD PLUS D'ARGENT
--
--  Deux corrections sur student_payments.
--
--  1. L'unicité du numéro de reçu était NATIONALE. Combinée à un numéro qui
--     recommençait toutes les 16 minutes, elle transformait chaque collision en
--     23505 — code que le connecteur PowerSync traite comme définitif : la
--     transaction était abandonnée et l'encaissement perdu. L'unicité descend
--     au niveau où elle a un sens comptable : l'établissement.
--
--  2. Un paiement se SUPPRIMAIT (DELETE sec). Sur de l'argent public on
--     n'efface pas, on annule : la ligne reste, avec son auteur et son motif.
--     Le remboursement, lui, existait comme statut sans rien pour le porter.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ── 1. Unicité par établissement ─────────────────────────────────────────────
ALTER TABLE student_payments
  DROP CONSTRAINT IF EXISTS student_payments_receipt_number_key;

CREATE UNIQUE INDEX IF NOT EXISTS uniq_payment_receipt_per_school
  ON student_payments (school_id, receipt_number)
  WHERE receipt_number IS NOT NULL;

-- ── 2. Annulation plutôt que suppression ─────────────────────────────────────
ALTER TABLE student_payments
  ADD COLUMN IF NOT EXISTS cancelled_at         timestamptz,
  ADD COLUMN IF NOT EXISTS cancelled_by         uuid REFERENCES profiles(id),
  ADD COLUMN IF NOT EXISTS cancellation_reason  text;

-- Un paiement annulé sans motif ne vaut pas mieux qu'un paiement effacé :
-- personne ne saurait dire pourquoi la caisse ne tombe pas juste.
ALTER TABLE student_payments
  DROP CONSTRAINT IF EXISTS chk_payment_cancellation;
ALTER TABLE student_payments
  ADD CONSTRAINT chk_payment_cancellation CHECK (
    status <> 'cancelled'
    OR (cancelled_at IS NOT NULL
        AND cancellation_reason IS NOT NULL
        AND length(btrim(cancellation_reason)) > 0)
  );

-- ── 3. Le remboursement gagne un contenu ─────────────────────────────────────
ALTER TABLE student_payments
  ADD COLUMN IF NOT EXISTS refunded_amount_xaf integer,
  ADD COLUMN IF NOT EXISTS refunded_at         timestamptz,
  ADD COLUMN IF NOT EXISTS refunded_by         uuid REFERENCES profiles(id),
  ADD COLUMN IF NOT EXISTS refund_reason       text;

-- On ne rembourse jamais plus qu'on n'a encaissé.
ALTER TABLE student_payments
  DROP CONSTRAINT IF EXISTS chk_payment_refund_amount;
ALTER TABLE student_payments
  ADD CONSTRAINT chk_payment_refund_amount CHECK (
    refunded_amount_xaf IS NULL
    OR (refunded_amount_xaf > 0 AND refunded_amount_xaf <= amount_xaf)
  );

COMMIT;
```

- [ ] **Step 2: Vérifier l'état AVANT application**

```bash
PGPASSWORD='069698620libe' psql -h aws-1-eu-central-2.pooler.supabase.com -p 5432 \
  -U postgres.wqpdamlnrwgozfvzjjpo -d postgres -c \
  "SELECT conname FROM pg_constraint WHERE conrelid='public.student_payments'::regclass AND conname LIKE '%receipt%';"
```
Expected: une ligne `student_payments_receipt_number_key`.

- [ ] **Step 3: Appliquer la migration**

```bash
cd /home/melack/E-PILOTE
PGPASSWORD='069698620libe' psql -h aws-1-eu-central-2.pooler.supabase.com -p 5432 \
  -U postgres.wqpdamlnrwgozfvzjjpo -d postgres \
  -f database/migrations/0094_le_recu_ne_perd_plus_d_argent.sql
```
Expected: `BEGIN` … `COMMIT`, sans `ERROR`.

- [ ] **Step 4: Vérifier l'état APRÈS application**

```bash
PGPASSWORD='069698620libe' psql -h aws-1-eu-central-2.pooler.supabase.com -p 5432 \
  -U postgres.wqpdamlnrwgozfvzjjpo -d postgres -c \
  "SELECT indexname FROM pg_indexes WHERE tablename='student_payments' AND indexname LIKE '%receipt%';" -c \
  "SELECT column_name FROM information_schema.columns WHERE table_name='student_payments' AND column_name LIKE 'cancel%' OR column_name LIKE 'refund%' ORDER BY 1;"
```
Expected : `uniq_payment_receipt_per_school` présent, `student_payments_receipt_number_key` absent, et les 7 colonnes listées.

- [ ] **Step 5: Déclarer les colonnes dans le schéma local**

Modifier `epilote/lib/services/powersync/powersync_schema.dart`, dans la table `student_payments`, juste après `Column.text('notes'),` :

```dart
    // ── Annulation (migration 0094) ──────────────────────────────────────────
    // Un paiement ne se supprime plus : il s'annule, et l'annulation porte son
    // auteur et son motif. Ces colonnes descendent par le `SELECT *` du bucket
    // by_school — aucune modification de sync-rules n'est requise.
    Column.text('cancelled_at'),
    Column.text('cancelled_by'),
    Column.text('cancellation_reason'),
    // ⚠️ `integer` local pour un `integer` serveur : un `real` ferait rejeter
    // le lot entier (22P02) et perdrait le paiement.
    Column.integer('refunded_amount_xaf'),
    Column.text('refunded_at'),
    Column.text('refunded_by'),
    Column.text('refund_reason'),
```

- [ ] **Step 6: Vérifier que l'application compile**

Run: `cd epilote && flutter analyze && flutter test`
Expected: `No issues found!` et la suite complète au vert (880 tests + les 15 de la Task 1-2).

- [ ] **Step 7: Commit**

```bash
cd /home/melack/E-PILOTE
git add database/migrations/0094_le_recu_ne_perd_plus_d_argent.sql epilote/lib/services/powersync/powersync_schema.dart
git commit -m "feat(finance) : l'unicité du reçu descend à l'établissement, l'annulation remplace l'effacement

L'unicité du numéro de reçu était nationale : deux écoles sans lien commun
pouvaient se percuter, et la collision faisait perdre l'encaissement. Elle
passe à (school_id, receipt_number).

Un paiement ne se supprime plus. La ligne reste, avec l'auteur et le motif de
l'annulation — un CHECK refuse une annulation muette. Le remboursement gagne
enfin un montant, une date et un motif ; il ne peut pas dépasser l'encaissé.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 4 : Brancher le numéroteur et remplacer la suppression

**Files:**
- Modify: `epilote/lib/features/finance/providers/paiements_provider.dart`
- Test: `epilote/test/paiement_annulation_test.dart` (créé)

**Interfaces:**
- Consumes: `formatReceiptNumber`, `prefixeRecu`, `prochaineSequence` (Task 1) ; `posteTag()` (Task 2) ; colonnes de la Task 3.
- Produces:
  - `bool peutAnnulerPaiement(String? status)`
  - `String? motifAnnulationInvalide(String motif)`
  - `Future<String> genererNumeroRecu({required String schoolId, required String? schoolCode, required DateTime quand})`
  - `Future<void> cancelPayment({required String id, required String motif, required String actorId})`
  - `PaymentRow` gagne `status`, `cancellationReason`, `method`, `amount` (déjà présents) et `feeName`.

- [ ] **Step 1: Écrire les tests qui échouent**

Créer `epilote/test/paiement_annulation_test.dart` :

```dart
import 'package:epilote/features/finance/providers/paiements_provider.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  ANNULER, PAS EFFACER (spec §5.3)
//
//  `deletePayment` faisait un DELETE sec : un reçu disparaissait sans laisser
//  de trace, et la caisse ne tombait plus juste sans que personne puisse dire
//  pourquoi. Sur des fonds publics, l'annulation doit rester lisible.
// ════════════════════════════════════════════════════════════════════════════

void main() {
  group('ce qui peut être annulé', () {
    test('un paiement confirmé peut l\'être', () {
      expect(peutAnnulerPaiement('confirmed'), isTrue);
    });

    test('un paiement en attente peut l\'être', () {
      expect(peutAnnulerPaiement('pending'), isTrue);
    });

    test('un paiement DÉJÀ annulé ne se réannule pas', () {
      expect(peutAnnulerPaiement('cancelled'), isFalse);
    });

    test('un paiement remboursé ne s\'annule pas', () {
      // Le remboursement a déjà rendu l'argent : annuler par-dessus ferait
      // disparaître la trace de la restitution.
      expect(peutAnnulerPaiement('refunded'), isFalse);
    });

    test('un statut inconnu est refusé plutôt que supposé', () {
      expect(peutAnnulerPaiement(null), isFalse);
      expect(peutAnnulerPaiement('brouillon'), isFalse);
    });
  });

  group('le motif est obligatoire', () {
    test('un motif vide est refusé', () {
      expect(motifAnnulationInvalide(''), isNotNull);
      expect(motifAnnulationInvalide('   '), isNotNull);
    });

    test('un motif trop court n\'explique rien', () {
      expect(motifAnnulationInvalide('ok'), isNotNull);
    });

    test('un motif renseigné passe', () {
      expect(motifAnnulationInvalide('Erreur de saisie du montant'), isNull);
    });
  });
}
```

- [ ] **Step 2: Lancer les tests pour vérifier qu'ils échouent**

Run: `cd epilote && flutter test test/paiement_annulation_test.dart`
Expected: FAIL — `Undefined name 'peutAnnulerPaiement'`.

- [ ] **Step 3: Écrire les décisions pures et le numéroteur**

Dans `epilote/lib/features/finance/providers/paiements_provider.dart`, ajouter les imports en tête :

```dart
import '../services/poste_tag.dart';
import '../services/receipt_number.dart';
```

Puis ajouter, juste avant la section `// ─── Mutations ───` :

```dart
// ─── Annulation ──────────────────────────────────────────────────────────────

/// Statuts depuis lesquels une annulation a un sens.
///
/// Ni `cancelled` (déjà fait) ni `refunded` : rembourser puis annuler ferait
/// disparaître la trace de la restitution, et la caisse mentirait deux fois.
const _kAnnulables = {'confirmed', 'pending'};

bool peutAnnulerPaiement(String? status) => _kAnnulables.contains(status);

/// Longueur en deçà de laquelle un motif n'explique rien.
const int kMotifAnnulationMin = 5;

/// `null` si le motif convient, sinon le message à montrer à l'utilisateur.
String? motifAnnulationInvalide(String motif) {
  final m = motif.trim();
  if (m.isEmpty) return 'Le motif de l\'annulation est obligatoire';
  if (m.length < kMotifAnnulationMin) {
    return 'Motif trop court — expliquez ce qui s\'est passé';
  }
  return null;
}

// ─── Numérotation des reçus ──────────────────────────────────────────────────

/// Le prochain numéro libre pour CE poste, dans CETTE école, pour CETTE année.
///
/// La séquence est relue dans la base locale à chaque encaissement plutôt que
/// tenue dans un compteur : après une purge du poste les paiements redescendent
/// par la synchro, et un compteur reparti à zéro rééditerait des numéros déjà
/// émis — chaque doublon coûtant un paiement (cf. `receipt_number.dart`).
/// Le code de l'école est relu ici, et non passé par l'appelant : l'écran est
/// un fichier `part` où `db` n'est pas en portée, et le numéroteur est de toute
/// façon le seul à en avoir besoin.
Future<String> genererNumeroRecu({
  required String schoolId,
  required DateTime quand,
}) async {
  final tag = await posteTag();
  final ecole = await db.getOptional(
      'SELECT school_code FROM schools WHERE id = ?', [schoolId]);
  final schoolCode = ecole?['school_code'] as String?;
  final prefixe =
      prefixeRecu(schoolCode: schoolCode, year: quand.year, posteTag: tag);
  final rows = await db.getAll(
    'SELECT receipt_number FROM student_payments '
    'WHERE school_id = ? AND receipt_number LIKE ?',
    [schoolId, '$prefixe%'],
  );
  final seq = prochaineSequence(
    rows.map((r) => r['receipt_number'] as String?),
    prefixe: prefixe,
  );
  return formatReceiptNumber(
    schoolCode: schoolCode,
    year: quand.year,
    posteTag: tag,
    sequence: seq,
  );
}
```

- [ ] **Step 4: Lancer les tests pour vérifier qu'ils passent**

Run: `cd epilote && flutter test test/paiement_annulation_test.dart`
Expected: PASS — 8 tests.

- [ ] **Step 5: Brancher le numéroteur dans `savePayment`**

Dans `paiements_provider.dart`, remplacer la signature et le corps de la branche création de `savePayment`.

Ancienne ligne (à supprimer) :

```dart
    final receipt = 'REC-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
```

La remplacer par (aucun changement de signature — `savePayment` reçoit déjà `schoolId`) :

```dart
    final receipt = await genererNumeroRecu(schoolId: schoolId, quand: d);
```

- [ ] **Step 6: Remplacer `deletePayment` par `cancelPayment`**

Supprimer :

```dart
Future<void> deletePayment(String id) async {
  await db.execute('DELETE FROM student_payments WHERE id = ?', [id]);
}
```

Et écrire à la place :

```dart
/// Annule un encaissement SANS l'effacer : la ligne reste, son auteur et son
/// motif avec elle. Un CHECK serveur (migration 0094) refuse une annulation
/// muette — la validation locale est là pour que l'utilisateur le sache avant
/// la synchro, pas à la place du serveur.
Future<void> cancelPayment({
  required String id,
  required String motif,
  required String actorId,
}) async {
  final probleme = motifAnnulationInvalide(motif);
  if (probleme != null) throw ArgumentError(probleme);
  final now = DateTime.now().toIso8601String();
  await db.execute(
    'UPDATE student_payments SET status = ?, cancelled_at = ?, '
    'cancelled_by = ?, cancellation_reason = ?, updated_at = ? WHERE id = ?',
    ['cancelled', now, actorId, motif.trim(), now, id],
  );
}
```

- [ ] **Step 7: Exposer le motif d'annulation au lecteur**

Dans la classe `PaymentRow`, ajouter le champ après `required this.receipt,` :

```dart
    this.cancellationReason,
```
et dans la liste des champs :
```dart
  final String? cancellationReason;
```

Dans `studentPaymentsProvider`, ajouter au constructeur `PaymentRow(` :

```dart
            cancellationReason: r['cancellation_reason'] as String?,
```

- [ ] **Step 8: Lancer la suite complète**

Run: `cd epilote && flutter analyze && flutter test`
Expected: `No issues found!`. Les appels à `deletePayment` dans `paiements_sheet.dart` échouent encore à la compilation — c'est attendu, ils sont corrigés à la Task 5. Si `flutter analyze` signale `deletePayment` non défini, passer directement à la Task 5 et relancer.

- [ ] **Step 9: Commit** (après la Task 5, les deux fichiers formant un tout compilable)

---

### Task 5 : L'écran annule, avec un motif

**Files:**
- Modify: `epilote/lib/features/finance/screens/paiements_sheet.dart:23-46` (méthode `_delete`) et `:177-182` (bouton)

**Interfaces:**
- Consumes: `peutAnnulerPaiement`, `motifAnnulationInvalide`, `cancelPayment` (Task 4) ; `PaymentRow.cancellationReason`.
- Produces: rien pour les tâches suivantes.

- [ ] **Step 1: Remplacer la méthode `_delete` par `_annuler`**

Dans `paiements_sheet.dart`, remplacer intégralement la méthode `_delete` (lignes 23-46) par :

```dart
  Future<void> _annuler(BuildContext context, WidgetRef ref, PaymentRow p) async {
    final motif = TextEditingController();
    final saisi = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Annuler ce paiement ?'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            '${fmtXaf(p.amount)} du ${p.date ?? '—'} sera marqué ANNULÉ. '
            'La ligne et son reçu restent au dossier — rien n\'est effacé.',
            style: TextStyle(fontSize: 13, color: kTextMuted),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: motif,
            autofocus: true,
            maxLines: 2,
            decoration: adminFilledInput('Motif de l\'annulation',
                icon: Icons.edit_note_rounded),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Renoncer')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kRed),
            onPressed: () => Navigator.pop(ctx, motif.text),
            child: const Text('Annuler le paiement'),
          ),
        ],
      ),
    );
    // Le contrôleur est libéré APRÈS la fermeture complète de la boîte : le
    // libérer plus tôt déclenche « _dependents.isEmpty is not true » pendant
    // l'animation de sortie.
    motif.dispose();
    if (saisi == null || !context.mounted) return;

    final probleme = motifAnnulationInvalide(saisi);
    if (probleme != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(probleme), backgroundColor: kRed));
      return;
    }
    final actor = ref.read(authNotifierProvider).valueOrNull?.id;
    if (actor == null) return;

    await runModuleWrite(
      context,
      () => cancelPayment(id: p.id, motif: saisi, actorId: actor),
      success: 'Paiement annulé',
    );
    onChanged();
  }
```

- [ ] **Step 2: Remplacer le bouton corbeille**

Remplacer le bloc `if (canEdit) IconButton(... Icons.delete_outline_rounded ...)` (lignes 177-182) par :

```dart
                        if (canEdit && peutAnnulerPaiement(p.status))
                          IconButton(
                            tooltip: 'Annuler ce paiement',
                            icon: Icon(Icons.block_rounded,
                                size: 18, color: kTextMuted),
                            onPressed: () => _annuler(context, ref, p),
                          ),
```

- [ ] **Step 3: Afficher le motif d'une annulation**

Dans le même `itemBuilder`, juste après le `Text` de la ligne de détail (`'${p.feeName ?? 'Frais'} · …'`), ajouter :

```dart
                                if (p.cancellationReason != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 3),
                                    child: Text('Annulé — ${p.cancellationReason}',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontStyle: FontStyle.italic,
                                            color: kRed)),
                                  ),
```

- [ ] **Step 4: Vérifier**

Run: `cd epilote && flutter analyze && flutter test`
Expected: `No issues found!` et suite complète au vert.

- [ ] **Step 5: Commit**

```bash
cd /home/melack/E-PILOTE
git add epilote/lib/features/finance/providers/paiements_provider.dart epilote/lib/features/finance/screens/paiements_sheet.dart epilote/test/paiement_annulation_test.dart
git commit -m "feat(finance) : on annule un paiement, on ne l'efface plus

Le bouton corbeille faisait un DELETE sec : le reçu disparaissait et la caisse
ne tombait plus juste sans que personne puisse dire pourquoi. Il devient une
annulation motivée — la ligne reste, avec son auteur et son motif, et le motif
s'affiche au dossier de l'élève.

Le numéroteur de reçus branché au passage : chaque encaissement tire son numéro
de l'étiquette du poste et de la séquence relue en base.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 6 : Le reçu papier

**Files:**
- Create: `epilote/lib/features/finance/services/recu_pdf_service.dart`
- Modify: `epilote/lib/features/finance/screens/paiements_sheet.dart` (bouton « Reçu »)

**Interfaces:**
- Consumes: `PaymentRow` (Task 4), `AttestationKit.build`, `OfficialPdfKit.loadFonts/loadLogo`, `showPdfPreviewDialog`.
- Produces: `Future<Uint8List> construireRecuPaiement({required RecuPaiement recu})` et la classe `RecuPaiement`.

- [ ] **Step 1: Écrire le service**

Créer `epilote/lib/features/finance/services/recu_pdf_service.dart` :

```dart
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/attestation_kit.dart';
import '../../../core/services/official_pdf_kit.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE REÇU DE PAIEMENT
//
//  L'application comptait une trentaine d'exports PDF — bulletins, convocations,
//  attestations, bordereaux de paie — et AUCUN pour un encaissement. Or au
//  Congo le reçu EST la preuve : un parent qui verse 5 000 F et repart les
//  mains vides revient trois mois plus tard contester, et l'école n'a rien à
//  lui opposer.
//
//  ⚠️ `pw.Page`, jamais `MultiPage` : un reçu tient sur une page, et le
//  `frame()` du kit officiel ne se scinde pas (TooManyPages).
// ════════════════════════════════════════════════════════════════════════════

/// Ce qu'un reçu doit porter pour faire preuve.
class RecuPaiement {
  const RecuPaiement({
    required this.numero,
    required this.eleve,
    required this.classe,
    required this.montant,
    required this.date,
    required this.methode,
    required this.encaissePar,
    this.matricule,
    this.motifFrais,
    this.annuleLe,
    this.motifAnnulation,
  });

  final String numero, eleve, classe, methode, encaissePar;
  final int montant;
  final DateTime date;
  final String? matricule, motifFrais, annuleLe, motifAnnulation;

  bool get estAnnule => annuleLe != null;
}

final _montant = NumberFormat.decimalPattern('fr');

String _xaf(int v) => '${_montant.format(v)} FCFA';

Future<Uint8List> construireRecuPaiement({required RecuPaiement recu}) async {
  final fonts = await OfficialPdfKit.loadFonts();
  final logo = await OfficialPdfKit.loadLogo();
  final issuer = OfficialPdfKit.issuer;

  pw.Widget ligne(String label, String valeur) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Row(children: [
          pw.SizedBox(
            width: 150,
            child: pw.Text(label,
                style: pw.TextStyle(
                    font: fonts.medium, fontSize: 10, color: kPdfMuted)),
          ),
          pw.Expanded(
            child: pw.Text(valeur,
                style: pw.TextStyle(font: fonts.bold, fontSize: 11)),
          ),
        ]),
      );

  return AttestationKit.build(
    titre: 'REÇU DE PAIEMENT',
    kicker: 'Pièce comptable',
    badge: 'REÇU',
    emetteur: issuer?.name ?? 'Établissement',
    sousTitre: issuer?.subtitle ?? '',
    fonts: fonts,
    logo: logo,
    quand: recu.date,
    corps: [
      pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: pdfTint(kPdfNavy, 0.06),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('N° ${recu.numero}',
                style: pw.TextStyle(font: fonts.bold, fontSize: 12)),
            pw.Text(_xaf(recu.montant),
                style: pw.TextStyle(
                    font: fonts.bold, fontSize: 16, color: kPdfGreen)),
          ],
        ),
      ),
      pw.SizedBox(height: 18),
      ligne('Élève', recu.eleve),
      if (recu.matricule != null) ligne('Matricule', recu.matricule!),
      ligne('Classe', recu.classe),
      ligne('Objet', recu.motifFrais ?? 'Frais scolaires'),
      ligne('Date', AttestationKit.jourLong.format(recu.date)),
      ligne('Mode de règlement', recu.methode),
      ligne('Encaissé par', recu.encaissePar),
      if (recu.estAnnule) ...[
        pw.SizedBox(height: 16),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: pdfTint(kPdfRed, 0.08),
            border: pw.Border.all(color: kPdfRed, width: 0.8),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('PAIEMENT ANNULÉ le ${recu.annuleLe}',
                  style: pw.TextStyle(
                      font: fonts.bold, fontSize: 11, color: kPdfRed)),
              if (recu.motifAnnulation != null)
                pw.Text(recu.motifAnnulation!,
                    style: pw.TextStyle(font: fonts.regular, fontSize: 10)),
            ],
          ),
        ),
      ],
    ],
  );
}
```

- [ ] **Step 2: Vérifier que le service compile**

Run: `cd epilote && flutter analyze lib/features/finance/services/recu_pdf_service.dart`
Expected: `No issues found!`
Si `AttestationKit.build` refuse un paramètre, relire sa signature dans `epilote/lib/core/services/attestation_kit.dart:32` et aligner les noms — ne pas inventer de paramètre.

- [ ] **Step 3: Brancher le bouton « Reçu » dans la fiche élève**

Dans `paiements_sheet.dart`, ajouter en tête de fichier (le fichier est un `part of`, donc l'import va dans `paiements_screen.dart`) :

```dart
import '../services/recu_pdf_service.dart';
import '../../../core/widgets/pdf_preview_dialog.dart';
```

Puis ajouter la méthode dans `_StudentPaymentsSheet` :

```dart
  void _recu(BuildContext context, WidgetRef ref, PaymentRow p) {
    final acteur =
        ref.read(authNotifierProvider).valueOrNull?.displayName ?? 'Le caissier';
    showPdfPreviewDialog(
      context,
      title: 'Reçu de paiement',
      subtitle: p.receipt,
      pdfFileName: '${p.receipt ?? 'recu'}.pdf',
      build: (_) => construireRecuPaiement(
        recu: RecuPaiement(
          numero: p.receipt ?? '—',
          eleve: row.studentName,
          matricule: row.matricule,
          classe: '—',
          montant: p.amount,
          date: DateTime.tryParse(p.date ?? '') ?? DateTime.now(),
          methode: paymentMethodLabel(p.method),
          encaissePar: acteur,
          motifFrais: p.feeName,
          annuleLe: p.status == 'cancelled' ? p.date : null,
          motifAnnulation: p.cancellationReason,
        ),
      ),
    );
  }
```

Et ajouter le bouton, juste avant celui d'annulation :

```dart
                        IconButton(
                          tooltip: 'Imprimer le reçu',
                          icon: Icon(Icons.receipt_long_rounded,
                              size: 18, color: kNavy),
                          onPressed: () => _recu(context, ref, p),
                        ),
```

- [ ] **Step 4: Vérifier**

Run: `cd epilote && flutter analyze && flutter test`
Expected: `No issues found!` et suite complète au vert.
Si `displayName` n'existe pas sur `ProfileModel`, utiliser les champs réels (`'${p.lastName} ${p.firstName}'`) — vérifier dans `epilote/lib/data/models/`.

- [ ] **Step 5: Recette à l'écran**

```bash
cd epilote && flutter run -d linux
```
Se connecter en directeur (`dir.metplt1ermai@epilote.cg` / `Demo@2026!`), ouvrir Finance ▸ Paiements ▸ une classe ▸ un élève.

Vérifier :
1. « Nouveau paiement » enregistre, et le numéro affiché suit le format `REC-…-26-XXXXXX-000001`.
2. Un second paiement porte `000002`.
3. Le bouton reçu ouvre l'aperçu, avec accents et montant en FCFA.
4. Le bouton d'annulation refuse un motif vide, accepte un motif, et la ligne bascule en « Annulé » avec son motif en rouge.
5. Le bouton d'annulation disparaît sur une ligne déjà annulée.

- [ ] **Step 6: Commit**

```bash
cd /home/melack/E-PILOTE
git add epilote/lib/features/finance/services/recu_pdf_service.dart epilote/lib/features/finance/screens/paiements_sheet.dart epilote/lib/features/finance/screens/paiements_screen.dart
git commit -m "feat(finance) : le reçu que le parent emporte

Une trentaine d'exports PDF dans l'application, aucun pour un encaissement.
Or au Congo le reçu EST la preuve : sans lui, un parent qui conteste trois mois
plus tard a raison par défaut.

Le reçu porte le numéro, l'élève, l'objet, le mode de règlement et qui a
encaissé. Un paiement annulé imprime son annulation plutôt que de se taire.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Auto-relecture du plan

**Couverture de la spécification (lot 0)**

| Exigence spec | Tâche |
|---|---|
| §6.1 numéro de reçu sans collision hors ligne | Tasks 1, 2, 4 |
| §6.1 unicité `(school_id, receipt_number)` | Task 3 |
| §6.2 reçu papier, tarif officiel imprimé | Task 6 — ⚠️ le tarif de référence n'existe qu'au lot 3 ; le reçu imprime l'objet et le montant, la ligne « tarif officiel » sera ajoutée au lot 3. |
| §5.3 annulation au lieu de suppression | Tasks 3, 4, 5 |
| §5.3 remboursement doté d'un contenu | Task 3 (colonnes) — l'écran de remboursement est au **lot 1**, pas ici. |
| §10 test « deux postes, même milliseconde → deux numéros » | Task 1, Step 1 |

**Hors périmètre de ce plan, explicitement** : `academic_year_id` sur les paiements, dû réel, exonérations, barèmes remontés au groupe, tarif figé et écran des écarts. Ce sont les lots 1 à 3.

**Cohérence des types** : `formatReceiptNumber` / `prefixeRecu` / `prochaineSequence` / `sequenceDansRecu` portent les mêmes noms en Tasks 1, 2 et 4. `peutAnnulerPaiement(String?)` accepte bien un nullable, conformément à `PaymentRow.status`. `cancelPayment` est nommée pareil en Tasks 4 et 5. `refunded_amount_xaf` est `integer` en base et `Column.integer` en local.
