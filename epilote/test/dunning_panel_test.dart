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
