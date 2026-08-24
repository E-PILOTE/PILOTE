import 'package:epilote/core/utils/subscription_days.dart';
import 'package:epilote/core/widgets/school_subscription_banner.dart';
import 'package:epilote/data/models/school_group_model.dart';
import 'package:epilote/features/navigation/providers/module_navigation_provider.dart';
import 'package:epilote/licensing/domain/entitlement.dart';
import 'package:epilote/licensing/presentation/license_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  L'ÉCOLE VOIT L'ÉCHÉANCE DE SON GROUPE — sans licence, hors ligne.
//
//  Avant : le personnel n'avait de compte à rebours QUE si son groupe figurait
//  dans `LICENSE_PILOT_GROUP_IDS` et détenait une licence signée. En pratique,
//  aucune école ne voyait rien, et découvrait l'échéance le jour de la
//  coupure — pendant que l'admin de groupe, lui, était prévenu.
//
//  Le bandeau lit désormais `school_groups`, table déjà synchronisée sur
//  chaque poste (bucket `by_group`), et la fenêtre d'alerte que la migration
//  0106 y recopie depuis `platform_settings`.
// ════════════════════════════════════════════════════════════════════════════

/// Entitlement injectable : `Entitlement.none()` = aucune licence (le cas de
/// la quasi-totalité du parc).
class _FakeEntitlement extends EntitlementNotifier {
  _FakeEntitlement(this._value);
  final Entitlement _value;
  @override
  Future<Entitlement> build() async => _value;
}

SchoolGroupModel _group({DateTime? end, int? alertDays}) => SchoolGroupModel(
      id: 'g1',
      name: 'Groupe de test',
      groupType: 'prive',
      planId: 'p1',
      subscriptionStatus: 'active',
      subscriptionEnd: end,
      subscriptionAlertDays: alertDays,
      adminEmail: 'admin@test.cg',
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

Future<void> _pump(WidgetTester tester, SchoolGroupModel? group) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentSchoolGroupProvider.overrideWith((ref) => Stream.value(group)),
        entitlementProvider
            .overrideWith(() => _FakeEntitlement(const Entitlement.none())),
      ],
      child: const MaterialApp(
        home: Scaffold(body: SchoolSubscriptionBanner()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // Le widget lit l'horloge réelle : on construit les dates relativement à
  // aujourd'hui, à midi, pour rester insensible à l'heure d'exécution.
  DateTime inDays(int n) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + n);
  }

  group('SchoolSubscriptionBanner', () {
    testWidgets('sans licence, à J-3 : le personnel EST averti', (t) async {
      await _pump(t, _group(end: inDays(3)));
      expect(find.textContaining('expire dans 3 jours'), findsOneWidget);
    });

    testWidgets("le jour même : « aujourd'hui »", (t) async {
      await _pump(t, _group(end: inDays(0)));
      expect(find.textContaining("expire aujourd'hui"), findsOneWidget);
    });

    testWidgets('hors fenêtre (J-20) : rien, aucune place prise', (t) async {
      await _pump(t, _group(end: inDays(20)));
      expect(
        t.getSize(find.byType(SchoolSubscriptionBanner)),
        Size.zero,
      );
    });

    testWidgets('la fenêtre synchronisée prime sur le défaut compilé',
        (t) async {
      // Le super_admin a réglé 30 : le trigger 0106 l'a recopié sur le groupe,
      // la synchro l'a descendu sur le poste. J-20 doit donc s'allumer.
      await _pump(t, _group(end: inDays(20), alertDays: 30));
      expect(find.textContaining('expire dans 20 jours'), findsOneWidget);
    });

    testWidgets('groupe sans réglage synchronisé → filet compilé (5 j)',
        (t) async {
      await _pump(t, _group(end: inDays(kSubscriptionAlertDays)));
      expect(
        find.textContaining('expire dans $kSubscriptionAlertDays jours'),
        findsOneWidget,
      );
    });

    testWidgets('échéance dépassée : silence (la licence prend le relais)',
        (t) async {
      await _pump(t, _group(end: inDays(-2)));
      expect(t.getSize(find.byType(SchoolSubscriptionBanner)), Size.zero);
    });

    testWidgets('sans abonnement daté : silence', (t) async {
      await _pump(t, _group());
      expect(t.getSize(find.byType(SchoolSubscriptionBanner)), Size.zero);
    });

    testWidgets('groupe pas encore synchronisé : silence, jamais de faux',
        (t) async {
      await _pump(t, null);
      expect(t.getSize(find.byType(SchoolSubscriptionBanner)), Size.zero);
    });
  });
}
