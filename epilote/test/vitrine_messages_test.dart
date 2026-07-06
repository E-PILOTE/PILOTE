import 'package:flutter_test/flutter_test.dart';
import 'package:epilote/features/auth/providers/vitrine_messages_provider.dart';

void main() {
  final now = DateTime(2026, 7, 6, 10);
  final past = DateTime(2026, 7, 1);
  final future = DateTime(2026, 7, 20);

  group('isMessageLive', () {
    test('inactif → jamais visible', () {
      expect(isMessageLive(now, null, null, false), isFalse);
      expect(isMessageLive(now, past, future, false), isFalse);
    });
    test('actif sans fenêtre → visible', () {
      expect(isMessageLive(now, null, null, true), isTrue);
    });
    test('dans la fenêtre → visible', () {
      expect(isMessageLive(now, past, future, true), isTrue);
    });
    test('avant le début → masqué', () {
      expect(isMessageLive(now, future, null, true), isFalse);
    });
    test('après la fin → masqué', () {
      expect(isMessageLive(now, null, past, true), isFalse);
    });
    test('début nul mais fin future → visible', () {
      expect(isMessageLive(now, null, future, true), isTrue);
    });
    test('début passé mais fin nulle → visible', () {
      expect(isMessageLive(now, past, null, true), isTrue);
    });
  });
}
