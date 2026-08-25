import 'package:epilote/features/admin_groupe/providers/admin_subscription_provider.dart';
import 'package:epilote/features/admin_groupe/screens/admin_subscription_renew_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Réabonnement libre-service (admin_groupe) — comportement du dialogue.
//
//  Avant, se réabonner au MÊME plan était impossible : le bouton du plan courant
//  était désactivé. Ce dialogue génère une facture de renouvellement via
//  `create_renewal_invoice`. On vérifie ici les trois issues que l'admin peut
//  voir, sans toucher au réseau (service simulé).
// ════════════════════════════════════════════════════════════════════════════

/// Service simulé : renvoie un résultat canné ou lève, sans appeler Supabase.
class _FakeService extends AdminSubscriptionService {
  _FakeService(super.ref, {this.result, this.error});
  final Map<String, dynamic>? result;
  final Object? error;

  @override
  Future<Map<String, dynamic>> requestRenewal() async {
    if (error != null) throw error!;
    return result ?? const {'success': true};
  }
}

const _sub = GroupSubscription(
  groupName: 'Groupe Test',
  planId: 'p1',
  planName: 'Institutionnel',
  planSlug: 'institutionnel',
  priceXaf: 900000,
  status: 'expired',
  start: null,
  end: null,
  maxSchools: 0,
  maxStudents: 0,
  maxStaff: 0,
  moduleCount: 28,
  schoolsUsed: 0,
  studentsUsed: 0,
  staffUsed: 0,
);

Future<void> _open(
  WidgetTester tester, {
  Map<String, dynamic>? result,
  Object? error,
}) async {
  tester.view.physicalSize = const Size(700, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adminSubscriptionServiceProvider
            .overrideWith((ref) => _FakeService(ref, result: result, error: error)),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () => showRenewSubscriptionDialog(ctx, _sub),
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('ouvrir'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('écran de confirmation : plan + montant du plan courant',
      (tester) async {
    await _open(tester);
    expect(find.text('Renouveler mon abonnement'), findsOneWidget);
    expect(find.text('Institutionnel'), findsOneWidget);
    expect(find.textContaining('900'), findsWidgets); // montant / an
    expect(find.text('Confirmer'), findsOneWidget);
  });

  testWidgets('facture générée → montre le numéro et le montant dû',
      (tester) async {
    await _open(tester, result: {
      'success': true,
      'created': true,
      'invoice_number': 'INV-2026-0042',
      'amount_xaf': 900000,
    });
    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();

    expect(find.text('Facture de renouvellement générée'), findsOneWidget);
    expect(find.text('INV-2026-0042'), findsOneWidget);
    expect(find.text('Compris'), findsOneWidget);
  });

  testWidgets('facture déjà en attente → message dédié (pas de doublon)',
      (tester) async {
    await _open(tester, result: {
      'success': true,
      'already_pending': true,
      'invoice_number': 'INV-2026-0007',
      'amount_xaf': 900000,
    });
    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();
    expect(find.text('Facture déjà en attente'), findsOneWidget);
  });

  testWidgets('plan gratuit → renouvellement immédiat, sans facture',
      (tester) async {
    await _open(tester, result: {'success': true, 'free': true});
    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();
    expect(find.text('Abonnement renouvelé'), findsOneWidget);
    expect(find.textContaining('gratuit'), findsWidgets);
  });

  testWidgets('erreur serveur → message lisible, reste sur la confirmation',
      (tester) async {
    await _open(tester, error: Exception('Accès refusé'));
    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();
    expect(find.textContaining("n'êtes pas autorisé"), findsOneWidget);
    // On peut réessayer : le bouton Confirmer est toujours là.
    expect(find.text('Confirmer'), findsOneWidget);
  });
}
