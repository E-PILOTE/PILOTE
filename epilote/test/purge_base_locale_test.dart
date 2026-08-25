import 'package:epilote/services/powersync/powersync_service.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  QUAND LA BASE HORS LIGNE A-T-ELLE LE DROIT D'ÊTRE EFFACÉE ?
//
//  Constaté en vrai le 2026-08-04 : la session Supabase d'un poste est morte
//  (jeton de rafraîchissement perdu), Supabase a émis `signedOut` tout seul,
//  et le code d'alors a répondu par `disconnectAndClear()` — 75 Mo de base
//  hors ligne effacés, 98 % des pages passées en liste libre. L'agent n'avait
//  rien demandé.
//
//  Au Congo, cela veut dire : tout retélécharger sur la liaison d'un lycée de
//  province, et surtout retomber sur un écran e-mail + mot de passe que
//  PERSONNE dans l'établissement ne connaît — les agents n'ont qu'un code à
//  quatre chiffres.
//
//  D'où la règle, désormais unique et testée : on ne purge QUE lorsque
//  l'appareil change réellement de main.
// ════════════════════════════════════════════════════════════════════════════

void main() {
  group('doitPurgerPourChangementDeCompte', () {
    const a = 'c7e339bf-69ce-3b4a-7d46-a3da95c0a090';
    const b = '7ca82e90-8da9-b467-1191-8e88d1cdb916';

    test('un agent DIFFÉRENT ouvre une session : on purge', () {
      expect(doitPurgerPourChangementDeCompte(precedent: a, courant: b), isTrue,
          reason: 'c\'est le seul cas multi-tenant : le poste change de main');
    });

    test('LE MÊME agent revient : on ne touche à rien', () {
      expect(doitPurgerPourChangementDeCompte(precedent: a, courant: a), isFalse,
          reason: 'son travail en attente doit le retrouver intact');
    });

    test('appareil neuf (aucun précédent) : rien à effacer', () {
      expect(
          doitPurgerPourChangementDeCompte(precedent: null, courant: a), isFalse,
          reason: 'purger au tout premier démarrage coûterait un '
              'retéléchargement complet pour rien');
    });

    test('utilisateur courant inconnu : on ne purge pas dans le doute', () {
      expect(
          doitPurgerPourChangementDeCompte(precedent: a, courant: null), isFalse,
          reason: 'une purge décidée sur une identité absente effacerait au '
              'hasard');
    });

    test('identifiant vide traité comme absent', () {
      // `?? ''` sur un identifiant est un motif déjà coûteux dans ce dépôt.
      expect(doitPurgerPourChangementDeCompte(precedent: '', courant: a), isFalse);
      expect(doitPurgerPourChangementDeCompte(precedent: a, courant: ''), isFalse);
    });

    test('la purge ne dépend QUE des deux identités', () {
      // Aucun paramètre « déconnexion » n'existe : une déconnexion ne peut
      // donc pas, structurellement, déclencher une purge. C'est le sens de
      // cette signature — la garantie est dans le type, pas dans un `if`.
      expect(doitPurgerPourChangementDeCompte(precedent: b, courant: b), isFalse);
    });
  });
}
