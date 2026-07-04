import 'package:epilote/features/navigation/providers/permissions_provider.dart';
import 'package:epilote/licensing/domain/entitlement.dart';
import 'package:epilote/licensing/domain/license.dart';
import 'package:epilote/licensing/presentation/license_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Verrou LICENCE dans canProvider : en lecture seule, les actions mutantes sont
/// coupées, mais `read` et `export` (N12) restent permis. Fail-soft si dormant.

const _permAll = ModulePermission(
  moduleSlug: 'notes', canRead: true, canCreate: true, canUpdate: true,
  canDelete: true, canExport: true, canImport: true, canValidate: true,
  canApprove: true, canManage: true, canWrite: true, dataScope: 'own_school',
);

class _FakeEnt extends EntitlementNotifier {
  _FakeEnt(this._e);
  final Entitlement _e;
  @override
  Future<Entitlement> build() async => _e;
}

Entitlement _ent(Duration overdue) {
  final now = DateTime.now().toUtc();
  return Entitlement(
    license: License(
      groupId: 'g', plan: 'p', modules: const {'notes'}, quotas: const {},
      validFrom: null, validTo: now.subtract(overdue),
      offlineWindow: const Duration(days: 30), version: 1, issuedAt: now),
    lastSyncAt: now,
  );
}

Future<ProviderContainer> _container(Entitlement e) async {
  final c = ProviderContainer(overrides: [
    modulePermissionProvider('notes').overrideWithValue(_permAll),
    entitlementProvider.overrideWith(() => _FakeEnt(e)),
  ]);
  await c.read(entitlementProvider.future); // force la résolution
  return c;
}

bool _can(ProviderContainer c, String action) =>
    c.read(canProvider((slug: 'notes', action: action)));

void main() {
  test('lecture seule : écritures coupées, read/export permis', () async {
    final c = await _container(_ent(const Duration(days: 40))); // > grâce
    expect(_can(c, 'write'), false);
    expect(_can(c, 'create'), false);
    expect(_can(c, 'delete'), false);
    expect(_can(c, 'read'), true);
    expect(_can(c, 'export'), true); // N12
    c.dispose();
  });

  test('grâce : écritures ENCORE permises', () async {
    final c = await _container(_ent(const Duration(days: 6))); // < 15 j grâce
    expect(_can(c, 'write'), true);
    c.dispose();
  });

  test('dormant (aucune licence) : fail-soft, écritures permises', () async {
    final c = await _container(const Entitlement.none());
    expect(_can(c, 'write'), true);
    c.dispose();
  });
}
