import 'package:flutter_test/flutter_test.dart';
import 'package:epilote/features/audit/providers/audit_scope.dart';

/// Contrat de divergence du module d'audit partagé : le SEUL point qui sépare
/// l'espace admin_groupe de l'espace école. Une régression ici ferait fuir des
/// lignes hors périmètre (école voyant les autres écoles) ou masquerait à tort
/// la dimension école côté groupe.
void main() {
  group('AuditScope — périmètre groupe', () {
    const scope = AuditScope.group('g-123');

    test('filtre sur group_id', () {
      expect(scope.column, 'group_id');
      expect(scope.id, 'g-123');
      expect(scope.isGroup, isTrue);
    });

    test('dimension École visible (filtre, top-écoles, colonne)', () {
      expect(scope.showSchoolDimension, isTrue);
    });

    test('clé de canal Realtime stable', () {
      expect(scope.channelKey, 'group_id_g-123');
    });
  });

  group('AuditScope — périmètre école', () {
    const scope = AuditScope.school('s-456');

    test('filtre sur school_id', () {
      expect(scope.column, 'school_id');
      expect(scope.id, 's-456');
      expect(scope.isGroup, isFalse);
    });

    test('dimension École masquée (redondante pour une seule école)', () {
      expect(scope.showSchoolDimension, isFalse);
    });

    test('clé de canal Realtime distincte du groupe', () {
      expect(scope.channelKey, 'school_id_s-456');
    });
  });

  test('égalité par (kind, id) — deux portées distinctes ne se confondent pas',
      () {
    expect(const AuditScope.group('x'), const AuditScope.group('x'));
    expect(const AuditScope.group('x'), isNot(const AuditScope.school('x')));
    expect(const AuditScope.group('x'), isNot(const AuditScope.group('y')));
  });

  group('Plancher de visibilité — hiddenActorRolesForViewer', () {
    test('super_admin voit TOUT (aucun masquage)', () {
      expect(hiddenActorRolesForViewer('super_admin'), isEmpty);
    });

    test('admin_groupe masque super_admin, voit tout le reste', () {
      final hidden = hiddenActorRolesForViewer('admin_groupe');
      expect(hidden, contains('super_admin'));
      expect(hidden, isNot(contains('admin_groupe')));
      expect(hidden.length, 1);
    });

    test('personnel école masque super_admin ET admin_groupe', () {
      for (final role in ['proviseur', 'directeur', 'secretaire', 'enseignant']) {
        final hidden = hiddenActorRolesForViewer(role);
        expect(hidden, containsAll(['super_admin', 'admin_groupe']),
            reason: 'rôle école $role doit masquer les deux niveaux au-dessus');
      }
    });

    test('aucun rôle école ne masque un autre rôle école (vue partagée)', () {
      // Tout le staff voit toutes les actions de son école : le plancher ne
      // contient QUE des rôles hors-école (plateforme/groupe).
      final hidden = hiddenActorRolesForViewer('secretaire');
      expect(hidden, isNot(contains('proviseur')));
      expect(hidden, isNot(contains('directeur')));
      expect(hidden, isNot(contains('enseignant')));
    });

    test('la portée embarque le plancher (école ⇒ 2 rôles masqués)', () {
      const scope = AuditScope.school('s-1',
          hiddenActorRoles: {'super_admin', 'admin_groupe'});
      expect(scope.hiddenActorRoles, hasLength(2));
      // Défaut = vide (rétro-compatible avec les portées historiques).
      expect(const AuditScope.group('g-1').hiddenActorRoles, isEmpty);
    });
  });
}
