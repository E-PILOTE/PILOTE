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
  group('Inscrire exige la clé du guichet, d’où qu’on parte', () {
    // ⚠️ `AddInscriptionScreen` écrit `class_enrollments`. Le geste est une
    // inscription, que l'agent l'ouvre depuis Inscriptions ou depuis Élèves.
    // Deux portes vers un seul geste : si l'une demande moins que l'autre,
    // c'est la plus permissive qui décide, et la permission du module
    // Inscriptions ne veut plus rien dire.
    const formulaire =
        'lib/features/students/screens/add_inscription_screen.dart';

    test('le formulaire nomme publiquement la permission qu’il exige', () {
      final src = _lire(formulaire);
      expect(src, contains("const kSlugInscription = 'inscriptions';"),
          reason: 'La constante servait déjà au périmètre des classes, mais '
              'elle était privée : les écrans qui montent l’assistant ne '
              'pouvaient pas s’y adosser et gardaient la porte autrement.');
    });

    test('les deux portes du module Élèves demandent cette clé', () {
      for (final f in const [
        'lib/features/students/screens/eleves_parts.dart',
        'lib/features/students/screens/eleves_screen.dart',
      ]) {
        final src = _lire(f);
        expect(src, contains('kSlugInscription'),
            reason: '$f ouvre l’assistant d’inscription : il doit exiger '
                'inscriptions:create, pas eleves:create.');
      }
    });

    test('aucune des deux ne garde « créer » sous le slug du registre', () {
      final parts = _lire('lib/features/students/screens/eleves_parts.dart');
      expect(parts.contains("slug: 'eleves',\n            action: 'create'"),
          isFalse,
          reason: 'Consulter le registre et inscrire un enfant ne sont pas le '
              'même droit.');
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
