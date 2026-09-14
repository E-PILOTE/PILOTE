import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LA CAISSE NE SE CONTREDIT PAS, ET LA PORTE DEMANDE LA BONNE CLÉ
//
//  Trois défauts trouvés en regardant l'application tourner, aucun ne
//  produisant la moindre erreur : l'écran s'affichait, les chiffres
//  s'alignaient, et ils se contredisaient.
//
//  Ce sont des tests de SOURCE. Ils ne rejouent pas un calcul — ils
//  surveillent qu'un écran continue d'appeler la règle plutôt que de la
//  recopier, et qu'une porte continue de demander la clé du geste qu'elle
//  ouvre. Deux choses qu'aucun test de valeur ne peut voir.
// ════════════════════════════════════════════════════════════════════════════

String _lire(String chemin) =>
    File(chemin).readAsStringSync().replaceAll('\r\n', '\n');

void main() {
  group('Le registre consulte, le guichet inscrit', () {
    // ⚠️ `AddInscriptionScreen` écrit `class_enrollments`. Le module Élèves le
    // montait aussi, sous la permission `eleves` : le droit d'inscrire
    // s'obtenait donc en n'ayant que celui de consulter. Le bouton est retiré
    // — un même geste offert à deux endroits finit par diverger, et l'écran se
    // contredisait lui-même (son état vide renvoie à la page Inscriptions).
    const registre = 'lib/features/students/screens/eleves_parts.dart';
    const ecran = 'lib/features/students/screens/eleves_screen.dart';

    test('le formulaire nomme publiquement la permission qu’il exige', () {
      final src =
          _lire('lib/features/students/screens/add_inscription_screen.dart');
      expect(src, contains("const kSlugInscription = 'inscriptions';"),
          reason: 'La constante servait déjà au périmètre des classes, mais '
              'elle était privée : les écrans qui montent l’assistant ne '
              'pouvaient pas s’y adosser et gardaient la porte autrement.');
    });

    test('la barre d’outils du registre n’offre plus « Nouvel élève »', () {
      expect(_lire(registre).contains("label: 'Nouvel élève'"), isFalse,
          reason: 'Le registre proposait d’inscrire, au-dessus d’un état vide '
              'expliquant que l’inscription se fait ailleurs.');
    });

    test('l’écran ne monte plus l’assistant d’inscription', () {
      // La coquille reste dangereuse tant qu'elle est montable : un futur
      // bouton la rebrancherait sans repasser par le guichet.
      expect(_lire(ecran).contains('child: AddInscriptionScreen()'), isFalse,
          reason: 'L’assistant est encore monté depuis le module Élèves.');
    });

    test('l’état vide MÈNE au guichet au lieu de s’en passer', () {
      final src = _lire(ecran);
      expect(src, contains('Routes.inscriptions'),
          reason: 'Le message nomme la page Inscriptions : l’action doit y '
              'conduire.');
      expect(src, contains('kSlugInscription'),
          reason: 'Le raccourci n’est offert qu’à qui a le droit d’inscrire — '
              'sinon la porte se referme sur l’agent au bout du trajet.');
    });
  });

  group('L’onglet Finances de la fiche dit la même chose que sa caisse', () {
    final src = _lire('lib/features/students/screens/fiche_eleve_finance.dart');

    test('le reste par poste appelle `resteDe`, il ne le recalcule pas', () {
      expect(src, contains('d.resteDe(l)'));
      // La recopie perdait la règle que `resteDe` documente : un trop-versé
      // sur la cantine n'éponge pas l'inscription. Recopiée, elle dérive.
      expect(src.contains('.clamp(0, d.duDe(l))'), isFalse,
          reason: 'Le calcul est réimplémenté au lieu d’être appelé.');
    });

    test('les versements non rattachés expliquent la contradiction', () {
      // « reste dû : 0 » au-dessus de « Inscription — reste 3 000 » : les deux
      // sont justes sur deux bases différentes. Afficher le montant ne
      // suffisait pas — il faut dire POURQUOI un poste reste ouvert.
      expect(src, contains('Versements non rattachés à un poste'));
      expect(src, contains('sans solder'),
          reason: 'Le montant seul laisse l’agent arbitrer entre deux chiffres '
              'contradictoires sur un écran de caisse.');
    });

    test('« Mensualités dues » ne s’affiche que s’il existe une mensualité',
        () {
      // `mois` vient de la fenêtre de présence, pas des barèmes : il vaut 10
      // même dans une école publique, qui ne perçoit aucune mensualité.
      expect(src, contains("l.feeType == 'mensualite'"),
          reason: 'La ligne s’affichait sans condition : dix mensualités de '
              'rien sous un décompte où pas un franc n’est mensuel.');
    });
  });
}
