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
}
