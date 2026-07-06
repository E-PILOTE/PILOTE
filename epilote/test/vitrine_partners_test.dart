import 'package:flutter_test/flutter_test.dart';
import 'package:epilote/features/auth/providers/vitrine_partners_provider.dart';

void main() {
  final now = DateTime(2026, 7, 6, 10);
  final past = DateTime(2026, 7, 1);
  final future = DateTime(2026, 7, 20);

  group('isPartnerLive', () {
    test('inactif → jamais', () {
      expect(isPartnerLive(now, null, null, false), isFalse);
    });
    test('actif sans fenêtre → visible', () {
      expect(isPartnerLive(now, null, null, true), isTrue);
    });
    test('dans la fenêtre → visible', () {
      expect(isPartnerLive(now, past, future, true), isTrue);
    });
    test('avant début / après fin → masqué', () {
      expect(isPartnerLive(now, future, null, true), isFalse);
      expect(isPartnerLive(now, null, past, true), isFalse);
    });
  });

  group('showPartnerStrip (opt-in groupe × partenaires vivants)', () {
    test('opt-in + partenaires → afficher', () {
      expect(showPartnerStrip(true, true), isTrue);
    });
    test('opt-in mais aucun partenaire → rien', () {
      expect(showPartnerStrip(true, false), isFalse);
    });
    test('partenaires mais pas d\'opt-in → rien (garde-fou)', () {
      expect(showPartnerStrip(false, true), isFalse);
    });
    test('ni l\'un ni l\'autre → rien', () {
      expect(showPartnerStrip(false, false), isFalse);
    });
  });
}
