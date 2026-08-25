import 'package:epilote/services/powersync/powersync_service.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  RÉGRESSION — perte de travail hors-ligne à la déconnexion.
//
//  Incident du 2026-07-13 : réseau coupé, clic sur « Déconnexion ».
//    1. gotrue supprime la session locale et émet `signedOut` AVANT l'appel
//       HTTP /logout ;
//    2. notre écouteur exécutait `db.disconnectAndClear()` → `powersync_clear()`
//       → base locale ET file d'écritures en attente (`ps_crud`) EFFACÉES ;
//    3. l'appel HTTP échouait ensuite → l'exception remontait → `state = null`
//       n'était jamais exécuté → l'app restait sur les écrans du personnel,
//       désormais VIDES.
//
//  La règle non négociable qui en découle : **on ne purge JAMAIS la base tant
//  qu'il reste du travail non remonté.** Ces tests gardent cette règle.
// ════════════════════════════════════════════════════════════════════════════

void main() {
  group('PendingLocalWork — verrou anti-purge', () {
    test('rien en attente → purge autorisée', () {
      const p = PendingLocalWork(writes: 0, files: 0);
      expect(p.isEmpty, isTrue);
      expect(p.total, 0);
    });

    test('une écriture en attente → purge INTERDITE', () {
      const p = PendingLocalWork(writes: 1, files: 0);
      expect(p.isEmpty, isFalse,
          reason: 'purger ici détruirait une inscription non synchronisée');
    });

    test('un fichier en attente → purge INTERDITE', () {
      const p = PendingLocalWork(writes: 0, files: 1);
      expect(p.isEmpty, isFalse,
          reason: 'la pièce jointe est encore sur le disque, pas sur le serveur');
    });

    test('écritures + fichiers se cumulent (compte annoncé à l\'utilisateur)', () {
      const p = PendingLocalWork(writes: 12, files: 3);
      expect(p.total, 15);
      expect(p.isEmpty, isFalse);
    });
  });
}
