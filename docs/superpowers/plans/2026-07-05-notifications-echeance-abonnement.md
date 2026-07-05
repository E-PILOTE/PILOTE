# Notifications d'échéance d'abonnement — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Avertir proactivement les trois audiences (admin_groupe, super_admin, personnel école) de l'échéance d'abonnement avant le hard-lock jour-même.

**Architecture:** Moteur hybride. Serveur `pg_cron` quotidien pousse des notifications idempotentes aux admin_groupe (audiences online). Le personnel école (offline) voit un compte à rebours calculé **localement** depuis `license.validTo` (aucun serveur). Le super_admin lit une vue « recouvrement » online. Réutilise la table `notifications`, les bandeaux existants et les clés de réglage `notif_subscription_expiry` / `notif_reminder_days`.

**Tech Stack:** Flutter + Riverpod (Dart pur pour la logique testable), Postgres 17 + pg_cron, Supabase.

## Global Constraints

- **C4 (non négociable)** : aucun composant ne gate la synchro PowerSync.
- **Fail-soft partout** : au doute (pas de licence, pas d'admin, seuils illisibles, réseau) → n'entrave/ne spamme rien.
- **Offline natif** : le compte à rebours staff ne dépend d'aucun réseau (source = licence locale signée).
- **Pas de fuite** : les notifs d'échéance ne ciblent que les `recipient_id` admin_groupe ; jamais synchronisées vers le staff.
- **Convention** : fichiers Dart ≤ 500 lignes ; logique en fonctions pures testables ; `flutter analyze` = 0 issue.
- **Commandes** depuis `epilote/` : `flutter test <fichier>`, `flutter analyze`. Binaire dans `/home/melack/flutter/bin/`.

---

## File Structure

| Fichier | Rôle | Action |
|---|---|---|
| `epilote/lib/licensing/presentation/license_banner.dart` | Bandeau staff : ajoute `subscriptionCountdownLabel` (pure) + états countdown/hardLock | Modify |
| `epilote/test/subscription_countdown_test.dart` | Tests de `subscriptionCountdownLabel` | Create |
| `epilote/test/license_banner_priority_test.dart` | Test de priorité d'affichage du bandeau | Create |
| `epilote/lib/features/super_admin/providers/dunning_provider.dart` | `DunningBucket`, `DunningRow`, `bucketDunning` (pure) + `dunningProvider` (I/O) | Create |
| `epilote/test/dunning_bucket_test.dart` | Tests de `bucketDunning` | Create |
| `epilote/lib/features/super_admin/widgets/dunning_panel.dart` | Panneau « Recouvrement » (3 seaux) | Create |
| `epilote/test/dunning_panel_test.dart` | Test de rendu du panneau (provider overridé) | Create |
| `epilote/lib/features/super_admin/screens/invoices_screen.dart` | Greffe le panneau Recouvrement | Modify |
| `database/migrations/0029_subscription_reminders.sql` | pg_cron + ledger + fonction + schedule | Create |

---

## Task 1: Compte à rebours staff — fonction pure

**Files:**
- Modify: `epilote/lib/licensing/presentation/license_banner.dart` (ajout de la fonction en fin de fichier, avant `ensureLicenseWritable`)
- Test: `epilote/test/subscription_countdown_test.dart`

**Interfaces:**
- Produces: `String? subscriptionCountdownLabel(DateTime? validTo, DateTime now, {int maxThreshold = 30})` — renvoie le libellé du bandeau de compte à rebours, ou `null` s'il n'y a rien à afficher en phase active (validTo nul, échéance > seuil, ou déjà dépassée).

- [ ] **Step 1: Write the failing test**

Créer `epilote/test/subscription_countdown_test.dart` :

```dart
import 'package:epilote/licensing/presentation/license_banner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 7, 5, 9);

  group('subscriptionCountdownLabel', () {
    test('validTo nul → null (abonnement perpétuel)', () {
      expect(subscriptionCountdownLabel(null, now), isNull);
    });

    test('échéance lointaine (> seuil) → null', () {
      final r = subscriptionCountdownLabel(now.add(const Duration(days: 45)), now);
      expect(r, isNull);
    });

    test('déjà dépassée → null (grace/hardLock prennent le relais)', () {
      final r = subscriptionCountdownLabel(now.subtract(const Duration(days: 2)), now);
      expect(r, isNull);
    });

    test('J-10 → libellé au pluriel', () {
      final r = subscriptionCountdownLabel(now.add(const Duration(days: 10)), now);
      expect(r, contains('dans 10 jours'));
    });

    test('J-1 → libellé au singulier', () {
      final r = subscriptionCountdownLabel(now.add(const Duration(days: 1)), now);
      expect(r, contains('dans 1 jour'));
      expect(r, isNot(contains('1 jours')));
    });

    test("J0 (jour même) → « aujourd'hui »", () {
      final r = subscriptionCountdownLabel(now.add(const Duration(hours: 6)), now);
      expect(r, contains("aujourd'hui"));
    });

    test('frontière : exactement au seuil max (30) → affiché', () {
      final r = subscriptionCountdownLabel(now.add(const Duration(days: 30)), now);
      expect(r, contains('dans 30 jours'));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd epilote && flutter test test/subscription_countdown_test.dart`
Expected: FAIL — `subscriptionCountdownLabel` non défini (erreur de compilation).

- [ ] **Step 3: Write minimal implementation**

Dans `epilote/lib/licensing/presentation/license_banner.dart`, ajouter cette fonction **juste avant** `bool ensureLicenseWritable(` (fin de fichier) :

```dart
/// Libellé de compte à rebours d'échéance, dérivé de la date d'expiration
/// SIGNÉE de la licence (`license.validTo`). Pur & testable — aucune I/O.
///
/// Renvoie `null` (= rien à afficher en phase active) quand :
///   - `validTo` est nul (abonnement perpétuel),
///   - l'échéance est au-delà de `maxThreshold` jours,
///   - l'échéance est déjà dépassée (les états grace/hardLock prennent le relais).
///
/// Comparaison au jour près (les échéances sont des dates, pas des instants).
String? subscriptionCountdownLabel(
  DateTime? validTo,
  DateTime now, {
  int maxThreshold = 30,
}) {
  if (validTo == null) return null;
  final end = DateTime.utc(validTo.year, validTo.month, validTo.day);
  final today = DateTime.utc(now.year, now.month, now.day);
  final daysLeft = end.difference(today).inDays;
  if (daysLeft < 0 || daysLeft > maxThreshold) return null;
  if (daysLeft == 0) {
    return "L'abonnement de l'établissement expire aujourd'hui ; au-delà, "
        "l'accès aux modules sera suspendu.";
  }
  return "L'abonnement de l'établissement expire dans $daysLeft jour"
      "${daysLeft > 1 ? 's' : ''} ; au-delà, l'accès aux modules sera suspendu.";
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd epilote && flutter test test/subscription_countdown_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 5: Commit**

```bash
git add epilote/lib/licensing/presentation/license_banner.dart epilote/test/subscription_countdown_test.dart
git commit -m "feat(abonnement): fonction pure de compte à rebours d'échéance (staff)"
```

---

## Task 2: Bandeau staff — câbler countdown + état hardLock

**Files:**
- Modify: `epilote/lib/licensing/presentation/license_banner.dart` (méthode `build` de `_LicenseBannerState`)
- Test: `epilote/test/license_banner_priority_test.dart`

**Interfaces:**
- Consumes: `subscriptionCountdownLabel` (Task 1) ; `entitlementProvider`, `Entitlement.phaseAt`, `LicensePhase` (existants).
- Produces: bandeau à 4 états prioritaires — `hardLock` (rouge, cadenas) > `readOnly` (rouge) > `grace` (ambre) > compte à rebours (ambre) > rien.

**Contexte :** aujourd'hui `build` fait `if (phase == LicensePhase.active) return SizedBox.shrink();` et traite tout non-active/non-readOnly comme grace — donc `hardLock` s'afficherait à tort en ambre. Cette tâche corrige les deux : ajoute le countdown en phase active et un branchement `hardLock` explicite.

- [ ] **Step 1: Write the failing test**

Créer `epilote/test/license_banner_priority_test.dart` :

```dart
import 'package:epilote/licensing/domain/entitlement.dart';
import 'package:epilote/licensing/domain/license.dart';
import 'package:epilote/licensing/presentation/license_banner.dart';
import 'package:epilote/licensing/presentation/license_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeEnt extends EntitlementNotifier {
  _FakeEnt(this._e);
  final Entitlement _e;
  @override
  Future<Entitlement> build() async => _e;
}

Entitlement _ent({required DateTime validTo, required Duration offlineWindow, bool hardLockable = true}) {
  final now = DateTime.now().toUtc();
  return Entitlement(
    license: License(
      groupId: 'g', plan: 'p', modules: const {'eleves'}, quotas: const {},
      validFrom: null, validTo: validTo, offlineWindow: offlineWindow,
      version: 1, issuedAt: now, hardLockable: hardLockable),
    lastSyncAt: now,
  );
}

Future<void> _pump(WidgetTester tester, Entitlement e) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [entitlementProvider.overrideWith(() => _FakeEnt(e))],
    child: const MaterialApp(home: Scaffold(body: LicenseBanner())),
  ));
  await tester.pump();
}

void main() {
  final now = DateTime.now().toUtc();

  testWidgets('phase active + échéance J-5 → bandeau compte à rebours', (tester) async {
    await _pump(tester, _ent(validTo: now.add(const Duration(days: 5)), offlineWindow: const Duration(days: 30)));
    expect(find.textContaining('expire dans 5 jours'), findsOneWidget);
  });

  testWidgets('phase active + échéance lointaine → aucun bandeau', (tester) async {
    await _pump(tester, _ent(validTo: now.add(const Duration(days: 90)), offlineWindow: const Duration(days: 30)));
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('hardLock (échu, hardLockable) → message de suspension rouge', (tester) async {
    await _pump(tester, _ent(validTo: now.subtract(const Duration(days: 1)), offlineWindow: const Duration(days: 30)));
    expect(find.textContaining('suspendu'), findsOneWidget);
    expect(find.byIcon(Icons.lock_clock_rounded), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd epilote && flutter test test/license_banner_priority_test.dart`
Expected: FAIL — en phase active aucun bandeau (le countdown n'est pas câblé) ; le cas hardLock affiche le mauvais message.

- [ ] **Step 3: Write minimal implementation**

Dans `epilote/lib/licensing/presentation/license_banner.dart`, remplacer le corps de `build` **à partir de** `final phase = ent.phaseAt(...)` **jusqu'à la fin du `switch`/construction du tuple** par la logique prioritaire. Concrètement, remplacer ce bloc :

```dart
    final phase = ent.phaseAt(DateTime.now().toUtc());
    if (phase == LicensePhase.active) return const SizedBox.shrink();

    final isStop = phase == LicensePhase.readOnly;
    final (bg, border, fg, icon, message) = isStop
        ? (
            _kStopBg,
            _kStopBorder,
            _kStopFg,
            _kStopIcon,
            "Abonnement de l'établissement expiré — application en lecture seule. "
                'Rapprochez-vous de votre administration.',
          )
        : (
            _kWarnBg,
            _kWarnBorder,
            _kWarnFg,
            _kWarnIcon,
            "Abonnement de l'établissement échu — régularisation requise auprès "
                'de votre administration.',
          );
```

par :

```dart
    final now = DateTime.now().toUtc();
    final phase = ent.phaseAt(now);

    // Priorité d'affichage : hardLock > readOnly > grace > compte à rebours > rien.
    final (Color bg, Color border, Color fg, IconData icon, Color iconColor, String message) info;
    switch (phase) {
      case LicensePhase.hardLock:
        info = (
          _kStopBg, _kStopBorder, _kStopFg, Icons.lock_clock_rounded, _kStopIcon,
          "Accès aux modules suspendu — abonnement de l'établissement à renouveler "
              'auprès de votre administration.',
        );
      case LicensePhase.readOnly:
        info = (
          _kStopBg, _kStopBorder, _kStopFg, Icons.lock_clock_rounded, _kStopIcon,
          "Abonnement de l'établissement expiré — application en lecture seule. "
              'Rapprochez-vous de votre administration.',
        );
      case LicensePhase.grace:
        info = (
          _kWarnBg, _kWarnBorder, _kWarnFg, Icons.warning_amber_rounded, _kWarnIcon,
          "Abonnement de l'établissement échu — régularisation requise auprès "
              'de votre administration.',
        );
      case LicensePhase.active:
        final countdown = subscriptionCountdownLabel(ent.license?.validTo, now);
        if (countdown == null) return const SizedBox.shrink();
        info = (
          _kWarnBg, _kWarnBorder, _kWarnFg, Icons.schedule_rounded, _kWarnIcon, countdown,
        );
    }
    final (bg, border, fg, icon, iconColor, message) = info;
```

Puis, dans le `return Material(...)`, remplacer la ligne de l'icône qui utilise l'ancien ternaire :

```dart
            Icon(isStop ? Icons.lock_clock_rounded : Icons.warning_amber_rounded,
                size: 18, color: icon),
```

par :

```dart
            Icon(icon, size: 18, color: iconColor),
```

(Le tuple fournit désormais `icon` = `IconData` et `iconColor` = `Color` ; l'ancien `icon` local était une couleur — d'où le renommage.)

- [ ] **Step 4: Run test to verify it passes**

Run: `cd epilote && flutter test test/license_banner_priority_test.dart test/subscription_countdown_test.dart`
Expected: PASS. Puis `flutter analyze` → No issues found.

- [ ] **Step 5: Commit**

```bash
git add epilote/lib/licensing/presentation/license_banner.dart epilote/test/license_banner_priority_test.dart
git commit -m "feat(abonnement): bandeau staff compte à rebours + état hardLock explicite"
```

---

## Task 3: Recouvrement super_admin — bucketing pur

**Files:**
- Create: `epilote/lib/features/super_admin/providers/dunning_provider.dart` (enum + fonction pure ; le provider I/O est ajouté en Task 4)
- Test: `epilote/test/dunning_bucket_test.dart`

**Interfaces:**
- Produces:
  - `enum DunningBucket { expiringSoon, inGrace, overdue }`
  - `DunningBucket? bucketDunning({required String status, required DateTime? end, required DateTime now, int graceDays = 15, int soonDays = 7})` — classe un groupe dans un seau de recouvrement, ou `null` s'il n'est pas concerné (actif et loin de l'échéance, ou sans date de fin). Mirroir de `computeSubscriptionAccess`.

- [ ] **Step 1: Write the failing test**

Créer `epilote/test/dunning_bucket_test.dart` :

```dart
import 'package:epilote/features/super_admin/providers/dunning_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 7, 5, 9);
  DunningBucket? b(String status, DateTime? end) =>
      bucketDunning(status: status, end: end, now: now);

  test('sans date de fin → null (hors recouvrement)', () {
    expect(b('active', null), isNull);
  });

  test('actif, échéance lointaine (J-30) → null', () {
    expect(b('active', now.add(const Duration(days: 30))), isNull);
  });

  test('actif, échéance proche (J-7) → expiringSoon', () {
    expect(b('active', now.add(const Duration(days: 7))), DunningBucket.expiringSoon);
  });

  test('actif, échéance J-8 → null (au-delà du seuil « proche »)', () {
    expect(b('active', now.add(const Duration(days: 8))), isNull);
  });

  test('échu depuis 10 j (naturel, ≤ grâce 15) → inGrace', () {
    expect(b('active', now.subtract(const Duration(days: 10))), DunningBucket.inGrace);
  });

  test('échu depuis 16 j (> grâce) → overdue', () {
    expect(b('active', now.subtract(const Duration(days: 16))), DunningBucket.overdue);
  });

  test('suspendu → overdue immédiat (pas de grâce)', () {
    expect(b('suspended', now.subtract(const Duration(days: 1))), DunningBucket.overdue);
  });

  test('résilié → overdue immédiat', () {
    expect(b('cancelled', now.subtract(const Duration(days: 1))), DunningBucket.overdue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd epilote && flutter test test/dunning_bucket_test.dart`
Expected: FAIL — fichier/fonction inexistants.

- [ ] **Step 3: Write minimal implementation**

Créer `epilote/lib/features/super_admin/providers/dunning_provider.dart` :

```dart
/// Vue « recouvrement » super_admin : quels groupes approchent de l'échéance,
/// sont en grâce, ou échus/impayés. Logique de classement PURE (testable) ;
/// le provider I/O est ajouté plus bas.

enum DunningBucket { expiringSoon, inGrace, overdue }

/// Classe un groupe dans un seau de recouvrement à partir de son statut brut et
/// de sa date de fin. Renvoie `null` si le groupe n'est PAS concerné (actif et
/// loin de l'échéance, ou sans date de fin). Comparaison au jour près.
/// Miroir de `computeSubscriptionAccess` (même sémantique grâce/statuts).
DunningBucket? bucketDunning({
  required String status,
  required DateTime? end,
  required DateTime now,
  int graceDays = 15,
  int soonDays = 7,
}) {
  if (end == null) return null;
  final e = DateTime(end.year, end.month, end.day);
  final n = DateTime(now.year, now.month, now.day);
  final daysLeft = e.difference(n).inDays;

  final entitling = status == 'active' || status == 'trial';

  if (daysLeft >= 0) {
    if (entitling && daysLeft <= soonDays) return DunningBucket.expiringSoon;
    return null; // actif et loin → hors recouvrement
  }

  // Échu. La grâce ne vaut que pour une expiration NATURELLE et récente ;
  // 'suspended' (impayé posé par le super_admin) et 'cancelled' → overdue direct.
  final overdue = -daysLeft;
  final naturalExpiry = status != 'suspended' && status != 'cancelled';
  if (naturalExpiry && overdue <= graceDays) return DunningBucket.inGrace;
  return DunningBucket.overdue;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd epilote && flutter test test/dunning_bucket_test.dart`
Expected: PASS (8 tests).

- [ ] **Step 5: Commit**

```bash
git add epilote/lib/features/super_admin/providers/dunning_provider.dart epilote/test/dunning_bucket_test.dart
git commit -m "feat(abonnement): bucketing pur de la vue recouvrement super_admin"
```

---

## Task 4: Recouvrement super_admin — provider I/O + panneau + greffe

**Files:**
- Modify: `epilote/lib/features/super_admin/providers/dunning_provider.dart` (ajout modèle `DunningRow` + `dunningProvider`)
- Create: `epilote/lib/features/super_admin/widgets/dunning_panel.dart`
- Modify: `epilote/lib/features/super_admin/screens/invoices_screen.dart` (greffe le panneau)
- Test: `epilote/test/dunning_panel_test.dart`

**Interfaces:**
- Consumes: `DunningBucket`, `bucketDunning` (Task 3) ; `supabaseClientProvider` (via `features/auth/providers/auth_provider.dart`).
- Produces:
  - `class DunningRow { final String groupId, groupName, planName; final DateTime? end; final int? daysLeft; final int amountDueXaf; final DunningBucket bucket; }`
  - `final dunningProvider = FutureProvider.autoDispose<List<DunningRow>>(...)` — groupes en recouvrement, triés par `end` croissant (les plus urgents d'abord).
  - `class DunningPanel extends ConsumerWidget` — rend les 3 seaux ; masqué si liste vide.

- [ ] **Step 1: Write the failing test**

Créer `epilote/test/dunning_panel_test.dart` :

```dart
import 'package:epilote/features/super_admin/providers/dunning_provider.dart';
import 'package:epilote/features/super_admin/widgets/dunning_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, List<DunningRow> rows) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [dunningProvider.overrideWith((ref) async => rows)],
      child: const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: DunningPanel()))),
    ));
    await tester.pump();
  }

  testWidgets('liste vide → panneau masqué', (tester) async {
    await pump(tester, const []);
    expect(find.textContaining('Recouvrement'), findsNothing);
  });

  testWidgets('groupes présents → titre + nom de groupe + seau', (tester) async {
    await pump(tester, [
      const DunningRow(
        groupId: 'g1', groupName: 'Groupe Alpha', planName: 'Premium',
        end: null, daysLeft: 3, amountDueXaf: 0, bucket: DunningBucket.expiringSoon),
      const DunningRow(
        groupId: 'g2', groupName: 'Groupe Beta', planName: 'Standard',
        end: null, daysLeft: -20, amountDueXaf: 150000, bucket: DunningBucket.overdue),
    ]);
    expect(find.textContaining('Recouvrement'), findsOneWidget);
    expect(find.text('Groupe Alpha'), findsOneWidget);
    expect(find.text('Groupe Beta'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd epilote && flutter test test/dunning_panel_test.dart`
Expected: FAIL — `DunningRow`, `dunningProvider`, `DunningPanel` inexistants.

- [ ] **Step 3a: Add the model + provider**

Ajouter à la fin de `epilote/lib/features/super_admin/providers/dunning_provider.dart` :

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';

/// Une ligne de recouvrement (un groupe concerné).
class DunningRow {
  const DunningRow({
    required this.groupId,
    required this.groupName,
    required this.planName,
    required this.end,
    required this.daysLeft,
    required this.amountDueXaf,
    required this.bucket,
  });
  final String groupId;
  final String groupName;
  final String planName;
  final DateTime? end;
  final int? daysLeft; // >=0 restants ; <0 dépassement
  final int amountDueXaf; // impayés (overdue + pending) agrégés
  final DunningBucket bucket;
}

/// Groupes en recouvrement (échéance proche / grâce / échus-impayés), triés par
/// date de fin croissante. Online (super_admin). Fail-soft : erreur → liste vide.
final dunningProvider =
    FutureProvider.autoDispose<List<DunningRow>>((ref) async {
  ref.keepAlive();
  final client = ref.watch(supabaseClientProvider);
  final now = DateTime.now();

  try {
    final groups = await client
        .from('school_groups')
        .select('id, name, subscription_status, subscription_end, '
            'subscription_plans!plan_id(name)') as List;

    // Impayés par groupe (statuts pending/overdue).
    final Map<String, int> due = {};
    try {
      final inv = await client
          .from('group_invoices')
          .select('group_id, amount_xaf, status')
          .inFilter('status', ['pending', 'overdue']) as List;
      for (final r in inv) {
        final m = r as Map;
        final gid = m['group_id'] as String?;
        if (gid == null) continue;
        due[gid] = (due[gid] ?? 0) + ((m['amount_xaf'] as int?) ?? 0);
      }
    } catch (_) {}

    final rows = <DunningRow>[];
    for (final r in groups) {
      final m = r as Map;
      final status = (m['subscription_status'] as String?) ?? 'active';
      final endRaw = m['subscription_end'] as String?;
      final end = endRaw != null ? DateTime.tryParse(endRaw) : null;
      final bucket = bucketDunning(status: status, end: end, now: now);
      if (bucket == null) continue;

      final gid = m['id'] as String;
      final e = end == null ? null : DateTime(end.year, end.month, end.day);
      final daysLeft = e == null
          ? null
          : e.difference(DateTime(now.year, now.month, now.day)).inDays;
      rows.add(DunningRow(
        groupId: gid,
        groupName: (m['name'] as String?) ?? '—',
        planName: (m['subscription_plans'] as Map?)?['name'] as String? ?? '—',
        end: end,
        daysLeft: daysLeft,
        amountDueXaf: due[gid] ?? 0,
        bucket: bucket,
      ));
    }
    rows.sort((a, b) {
      final ea = a.end, eb = b.end;
      if (ea == null && eb == null) return 0;
      if (ea == null) return 1;
      if (eb == null) return -1;
      return ea.compareTo(eb);
    });
    return rows;
  } catch (_) {
    return const []; // fail-soft : jamais d'écran d'erreur bloquant
  }
});
```

Note : déplacer l'`import` en tête du fichier (Dart exige les imports en haut). Regrouper les deux imports (`flutter_riverpod`, `auth_provider`) au sommet, au-dessus de l'`enum`.

- [ ] **Step 3b: Create the panel widget**

Créer `epilote/lib/features/super_admin/widgets/dunning_panel.dart` :

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/routes.dart';
import '../providers/dunning_provider.dart';

const _kSoonColor = Color(0xFFD97706); // ambre
const _kGraceColor = Color(0xFFB45309); // ambre foncé
const _kOverdueColor = Color(0xFFDC2626); // rouge

/// Panneau « Recouvrement » (super_admin) : groupes proches de l'échéance, en
/// grâce, ou échus/impayés. Greffé dans l'écran factures. Masqué si rien à relancer.
class DunningPanel extends ConsumerWidget {
  const DunningPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(dunningProvider).valueOrNull ?? const [];
    if (rows.isEmpty) return const SizedBox.shrink();

    Iterable<DunningRow> of(DunningBucket b) => rows.where((r) => r.bucket == b);

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.campaign_rounded, size: 18, color: _kOverdueColor),
            const SizedBox(width: 8),
            Text('Recouvrement — ${rows.length} groupe${rows.length > 1 ? 's' : ''}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          ]),
          const SizedBox(height: 12),
          _bucketSection(context, 'Échoit bientôt', _kSoonColor, of(DunningBucket.expiringSoon)),
          _bucketSection(context, 'En grâce', _kGraceColor, of(DunningBucket.inGrace)),
          _bucketSection(context, 'Échus / impayés', _kOverdueColor, of(DunningBucket.overdue)),
        ],
      ),
    );
  }

  Widget _bucketSection(BuildContext context, String title, Color color, Iterable<DunningRow> items) {
    final list = items.toList();
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(title.toUpperCase(),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color, letterSpacing: .5)),
        ),
        ...list.map((r) => _row(context, r, color)),
      ],
    );
  }

  Widget _row(BuildContext context, DunningRow r, Color color) {
    final d = r.daysLeft;
    final when = d == null
        ? ''
        : d >= 0
            ? 'J-$d'
            : 'échu +${-d}j';
    final due = r.amountDueXaf > 0 ? ' · ${r.amountDueXaf} FCFA dus' : '';
    return InkWell(
      onTap: () => context.go(Routes.superGroupes),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Container(width: 8, height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(child: Text(r.groupName, style: const TextStyle(fontWeight: FontWeight.w600))),
          Text('${r.planName} · $when$due',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        ]),
      ),
    );
  }
}
```

Note : la route est `Routes.superGroupes` (`/super/groupes`), confirmée dans `epilote/lib/core/constants/routes.dart:13`.

- [ ] **Step 4: Graft the panel into the invoices screen**

Dans `epilote/lib/features/super_admin/screens/invoices_screen.dart` : ajouter en tête l'import
`import '../widgets/dunning_panel.dart';`
puis, dans `_InvoicesBodyState.build` → branche `data: (data) { ... }` → `Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [ ... ])`, insérer `const DunningPanel(),` **juste après** la ligne `_KpiGrid(data: data),` (avant `const SizedBox(height: 20),`). Le panneau se masque seul si la liste est vide — aucun garde conditionnel requis. Résultat attendu :

```dart
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _KpiGrid(data: data),
                  const DunningPanel(),
                  const SizedBox(height: 20),
                  _FilterBar(
```

- [ ] **Step 5: Run tests + analyze**

Run:
```
cd epilote && flutter test test/dunning_panel_test.dart && flutter analyze
```
Expected: PASS (2 tests) ; analyze → No issues found.

- [ ] **Step 6: Commit**

```bash
git add epilote/lib/features/super_admin/providers/dunning_provider.dart \
        epilote/lib/features/super_admin/widgets/dunning_panel.dart \
        epilote/lib/features/super_admin/screens/invoices_screen.dart \
        epilote/test/dunning_panel_test.dart
git commit -m "feat(abonnement): panneau recouvrement super_admin (3 seaux)"
```

---

## Task 5: Moteur serveur — migration pg_cron + fonction + idempotence

**Files:**
- Create: `database/migrations/0029_subscription_reminders.sql`

**Interfaces:**
- Produces (en base) : table `subscription_reminder_log`, fonction `emit_subscription_reminders()`, job cron `subscription-reminders`. Émet des `notifications` `type='subscription'` avec `data.route='/admin/abonnement'` pour chaque admin_groupe.

**Prérequis / notes de déploiement :**
- `pg_cron` doit être activable sur le projet (Supabase Dashboard → Database → Extensions, ou `create extension` via rôle `postgres`). Les migrations `database/migrations/*` sont appliquées **en SQL brut** contre Supabase (cf. registre en dérive) — appliquer ce fichier via l'éditeur SQL Supabase ou le MCP `execute_sql`.
- `notifications` cible des `recipient_id` admin_groupe → aucune fuite vers le staff (sync-rules non touchées, C4 respecté).

- [ ] **Step 1: Write the migration**

Créer `database/migrations/0029_subscription_reminders.sql` :

```sql
-- 0029_subscription_reminders.sql
-- Notifications d'échéance d'abonnement (rappels avant hard-lock jour-même, ADR-0009).
-- Moteur SERVEUR pour les audiences ONLINE (admin_groupe). Le personnel école
-- (offline) est averti par un bandeau client dérivé de license.validTo — aucun
-- serveur, aucune sync-rule (C4 : la synchro n'est jamais gatée).

create extension if not exists pg_cron;

-- Ledger d'idempotence : un seuil (J-X) n'est émis qu'une fois par cycle
-- d'échéance (identifié par subscription_end). Un renouvellement change
-- subscription_end → nouveau cycle → les seuils se rejouent proprement.
create table if not exists subscription_reminder_log (
  group_id         uuid not null references school_groups(id) on delete cascade,
  subscription_end date not null,
  threshold        int  not null,
  notified_at      timestamptz not null default now(),
  primary key (group_id, subscription_end, threshold)
);

create or replace function emit_subscription_reminders()
returns void
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_settings   jsonb;
  v_enabled    boolean;
  v_thresholds int[];
  g            record;
  v_days_left  int;
  v_end        date;
  v_title      text;
  v_body       text;
begin
  select data into v_settings from platform_settings where id = 1;

  -- Garde master : le super_admin peut couper les rappels (défaut = activé).
  v_enabled := coalesce((v_settings->>'notif_subscription_expiry')::boolean, true);
  if not v_enabled then
    return;
  end if;

  -- Seuils depuis le champ texte 'notif_reminder_days' (CSV), défaut {30,15,7,1,0}.
  begin
    v_thresholds := (
      select array_agg(t::int)
      from regexp_split_to_table(
        coalesce(nullif(btrim(v_settings->>'notif_reminder_days'), ''), '30,15,7,1,0'),
        '\s*,\s*'
      ) as t
      where t ~ '^[0-9]+$'
    );
  exception when others then
    v_thresholds := array[30,15,7,1,0];
  end;
  if v_thresholds is null or array_length(v_thresholds, 1) is null then
    v_thresholds := array[30,15,7,1,0];
  end if;

  for g in
    select id, name, subscription_end::date as sub_end
    from school_groups
    where subscription_end is not null
  loop
    v_end := g.sub_end;
    v_days_left := v_end - current_date;

    if not (v_days_left = any(v_thresholds)) then
      continue;
    end if;

    -- Idempotence : réserve le seuil pour ce cycle. Déjà présent → on saute.
    insert into subscription_reminder_log(group_id, subscription_end, threshold)
    values (g.id, v_end, v_days_left)
    on conflict (group_id, subscription_end, threshold) do nothing;

    if not found then
      continue;
    end if;

    if v_days_left = 0 then
      v_title := 'Abonnement : expire aujourd''hui';
      v_body  := 'L''abonnement de votre groupe expire aujourd''hui. Renouvelez pour '
              || 'éviter la suspension de l''accès aux modules.';
    elsif v_days_left = 1 then
      v_title := 'Abonnement : expire demain';
      v_body  := 'L''abonnement de votre groupe expire demain. Pensez à renouveler.';
    else
      v_title := format('Abonnement : expire dans %s jours', v_days_left);
      v_body  := format('L''abonnement de votre groupe expire dans %s jours. '
              || 'Renouvelez pour maintenir l''accès aux modules.', v_days_left);
    end if;

    -- Une notification par admin_groupe du groupe (chemin cloche online).
    -- data.route → deep-link exploité par notifications_drawer.dart.
    insert into notifications(group_id, recipient_id, type, title, body, data, sent_at)
    select g.id, p.id, 'subscription', v_title, v_body,
           jsonb_build_object(
             'route', '/admin/abonnement',
             'threshold', v_days_left,
             'subscription_end', v_end
           ),
           now()
    from profiles p
    where p.group_id = g.id and p.role = 'admin_groupe';
  end loop;
end;
$fn$;

-- Planification quotidienne 06:00 UTC (~07:00 WAT, avant l'ouverture des écoles).
-- Idempotent : dé-planifie un éventuel job homonyme avant de (re)planifier.
select cron.unschedule(jobid) from cron.job where jobname = 'subscription-reminders';

select cron.schedule(
  'subscription-reminders',
  '0 6 * * *',
  $cron$select public.emit_subscription_reminders()$cron$
);
```

- [ ] **Step 2: Apply the migration**

Appliquer le fichier contre Supabase (éditeur SQL du Dashboard, ou MCP `execute_sql` du projet `wqpdamlnrwgozfvzjjpo`). Exécuter le contenu intégral.
Expected: succès sans erreur ; `select * from cron.job where jobname = 'subscription-reminders';` renvoie 1 ligne.

- [ ] **Step 3: Verify idempotence (test DB ciblé)**

Choisir/créer un groupe témoin avec `subscription_end = current_date + 7` et ≥ 1 profil `admin_groupe`. Puis exécuter :

```sql
-- Nettoyage préalable du témoin (rejouable).
delete from subscription_reminder_log where group_id = '<GID>';
delete from notifications where group_id = '<GID>' and type = 'subscription';

-- 1er appel : émet pour le seuil 7.
select emit_subscription_reminders();
-- 2e appel immédiat : ne doit RIEN réémettre (idempotence).
select emit_subscription_reminders();

-- Attendu : 1 ligne ledger (seuil 7), et 1 notif par admin_groupe du groupe.
select count(*) as ledger7 from subscription_reminder_log
  where group_id = '<GID>' and threshold = 7;              -- attendu : 1
select count(*) as notifs7 from notifications
  where group_id = '<GID>' and type = 'subscription'
    and (data->>'threshold')::int = 7;                     -- attendu : nb d'admins (1 appel, pas 2)
```

Expected: `ledger7 = 1` ; `notifs7 = nombre d'admin_groupe du groupe` (preuve que le 2ᵉ appel n'a pas dupliqué).

- [ ] **Step 4: Commit**

```bash
git add database/migrations/0029_subscription_reminders.sql
git commit -m "feat(abonnement): moteur pg_cron rappels d'échéance (idempotent, fail-soft)"
```

---

## Self-Review — couverture du spec

- **§1 moteur serveur pg_cron** → Task 5 (extension, ledger, fonction, schedule, idempotence). ✅
- **§2 réception admin_groupe** → Task 5 pose `type='subscription'` + `data.route='/admin/abonnement'` ; le drawer deep-linke déjà via `data.route` → **aucun Dart requis** (confirmé `notifications_drawer.dart:25-28`). Bandeau `SubscriptionBanner` inchangé. ✅
- **§3 vue recouvrement super_admin** → Task 3 (bucketing pur) + Task 4 (provider + panneau + greffe). ✅
- **§4 avertissement staff avant le mur** → Task 1 (fonction pure) + Task 2 (câblage bandeau + hardLock). ✅
- **§5 réglages + tests** → réglages réutilisés (`notif_subscription_expiry`/`notif_reminder_days`) lus en Task 5 ; tests dans chaque tâche (countdown, priorité bandeau, bucketing, rendu panneau, idempotence SQL). ✅

**Invariants** : C4 (aucun gating synchro — vérifié Task 4/5), fail-soft (défauts partout), offline natif (Task 1/2 sans réseau), pas de fuite (recipient_id admin only, Task 5) — tous couverts.
