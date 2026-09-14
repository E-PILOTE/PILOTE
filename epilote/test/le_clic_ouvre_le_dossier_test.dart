import 'dart:io';

import 'package:epilote/features/students/services/eleve_cycle_actions.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE CLIC SUR UN ÉLÈVE OUVRE SON DOSSIER
//
//  Pendant des semaines, cliquer sur une ligne d'élève ouvrait un TIROIR de
//  460 pixels, et la fiche complète — onze registres, l'aperçu imprimable —
//  n'était atteignable que par un bouton À L'INTÉRIEUR de ce tiroir. Il
//  fallait donc déjà avoir ouvert la vue superficielle pour découvrir que la
//  vue profonde existait.
//
//  Ce défaut ne produisait aucune erreur : l'application marchait, la fiche
//  aussi. Elle était simplement invisible. C'est la forme de défaut que les
//  tests ne trouvent jamais tout seuls — d'où ceux-ci, qui surveillent des
//  DESTINATIONS plutôt que des calculs.
// ════════════════════════════════════════════════════════════════════════════

String _lire(String chemin) =>
    File(chemin).readAsStringSync().replaceAll('\r\n', '\n');

void main() {
  group('Le clic mène au dossier, l’aperçu a sa propre cible', () {
    final ecran = _lire('lib/features/students/screens/eleves_screen.dart');

    test('la ligne ouvre la fiche, et non le tiroir', () {
      expect(ecran.contains('onOpen: _ouvrirFiche'), isTrue,
          reason: 'Cliquer sur le nom d’une personne doit ouvrir le dossier '
              'de cette personne. Le tiroir n’est pas une destination : il '
              'n’a pas d’adresse, ne s’envoie pas à un collègue et ne se '
              'retrouve pas en favori.');
    });

    test('le tiroir garde un clic, sur une cible explicite', () {
      expect(ecran.contains('onApercu: _apercu'), isTrue,
          reason: 'Le coup d’œil est le geste répété cinquante fois par jour. '
              'Le supprimer ferait payer une navigation complète à l’action '
              'la PLUS fréquente pour servir la plus rare.');
    });

    test('la fiche s’ouvre sur son adresse, pas dans une fenêtre', () {
      expect(ecran.contains('Routes.eleveDetail.replaceFirst'), isTrue,
          reason: 'Une adresse survit au plantage, se met en favori et rend '
              'le bouton Retour honnête.');
    });

    test('le chevron décoratif est devenu une action', () {
      final liste =
          _lire('lib/features/students/screens/eleves_liste_parts.dart');
      expect(liste.contains('Icons.chevron_right_rounded'), isFalse,
          reason: '36 pixels de décor à l’endroit exact où l’œil cherche une '
              'action : la place devait servir.');
      expect(liste.contains('tooltip: \'Aperçu rapide\''), isTrue);
    });
  });

  group('Un seul jeu de gestes pour deux vues', () {
    final service =
        _lire('lib/features/students/services/eleve_cycle_actions.dart');
    final menu = _lire('lib/features/students/widgets/eleve_actions_menu.dart');

    test('le tiroir et la fiche appellent le MÊME menu', () {
      for (final f in const [
        'lib/features/students/screens/eleves_drawer.dart',
        'lib/features/students/screens/fiche_eleve_entete.dart',
      ]) {
        expect(_lire(f), contains('EleveActions'),
            reason: 'Deux menus qui divergent, ce sont deux vocabulaires de '
                'motifs de sortie — donc des statistiques de déperdition '
                'qu’on ne sait plus additionner.');
      }
    });

    test('l’ancien tiroir-roi n’existe plus', () {
      expect(File('lib/features/students/screens/eleves_actions_parts.dart')
          .existsSync(), isFalse,
          reason: 'Tant que ce `part of` survit, les gestes restent '
              'atteignables depuis la seule liste.');
    });

    test('le service ne navigue JAMAIS', () {
      // Un `Navigator.pop` caché dans un service ferme la mauvaise chose dès
      // qu'une deuxième vue l'appelle : depuis la fiche, il fermerait la page.
      expect(service.contains('Navigator.pop(context)'), isFalse);
      expect(service.contains('context.pop()'), isFalse);
      expect(service.contains('Navigator.of(context).pop()'), isFalse,
          reason: 'Les gestes renvoient un booléen ; c’est l’APPELANT qui '
              'referme — le tiroir sur lui-même, la fiche vers la liste.');
    });

    test('chaque sortie prévient son appelant', () {
      for (final geste in const [
        'annulerInscriptionEleve',
        'sortirEleve',
        'desactiverEleve',
      ]) {
        expect(menu, contains(geste),
            reason: 'Un geste qui retire l’élève de l’effectif sans le dire '
                'laisse lire un dossier que la liste derrière ne contient '
                'plus.');
      }
      expect(menu.contains('onApresSortie?.call()'), isTrue);
    });
  });

  group('La cible d’un geste porte ce que les papiers consomment', () {
    // ⚠️ Un champ oublié ici ne casse rien à l'écran : il sort un certificat
    // à la ligne vide — signé, remis à une famille, refusé au guichet.
    const complet = EleveCible(
      id: 'e1',
      firstName: 'Mireille',
      lastName: 'Okemba',
      matricule: 'M-042',
      ine: '12345678901',
      gender: 'F',
      placeOfBirth: 'Brazzaville',
      className: '5e A',
      enrollmentId: 'enr-1',
      enrollmentStatus: 'active',
      isBoarder: true,
    );

    test('le nom complet ne laisse pas traîner d’espace', () {
      expect(complet.fullName, 'Mireille Okemba');
      expect(
          const EleveCible(
                  id: 'x', firstName: 'Jean', lastName: '', matricule: '')
              .fullName,
          'Jean');
    });

    test('l’attestation reçoit la classe, pas un vide', () {
      expect(complet.versAttestation().className, '5e A');
      expect(complet.versAttestation().ine, '12345678901');
      expect(complet.versAttestation().matricule, 'M-042');
    });

    test('sans classe connue, le papier porte un tiret et non « null »', () {
      const sansClasse =
          EleveCible(id: 'x', firstName: 'A', lastName: 'B', matricule: '');
      expect(sansClasse.versAttestation().className, '—');
    });

    test('le lieu de naissance relu au dossier prime sur celui de la liste', () {
      // La ligne de liste ne le porte pas toujours ; le dossier, si. Un
      // certificat sans lieu de naissance se fait refuser au guichet.
      expect(complet.versAttestation(lieuNaissance: 'Pointe-Noire').placeOfBirth,
          'Pointe-Noire');
      expect(complet.versAttestation().placeOfBirth, 'Brazzaville');
    });
  });

  group('Sans inscription, les gestes de l’année n’ont pas d’objet', () {
    test('une inscription présente ouvre les gestes de l’année', () {
      const avec = EleveCible(
          id: 'x',
          firstName: 'A',
          lastName: 'B',
          matricule: '',
          enrollmentId: 'enr-1');
      expect(avec.aUneInscription, isTrue);
    });

    test('une inscription absente ou vide les referme', () {
      // ⚠️ `enrollmentId!` sur un élève sans inscription de l'année plante à
      // l'exécution. On ne propose pas le geste plutôt que de le proposer
      // cassé : on ne change pas la classe de quelqu'un qui n'en a pas.
      const sans =
          EleveCible(id: 'x', firstName: 'A', lastName: 'B', matricule: '');
      expect(sans.aUneInscription, isFalse);
      expect(
          const EleveCible(
                  id: 'x',
                  firstName: 'A',
                  lastName: 'B',
                  matricule: '',
                  enrollmentId: '')
              .aUneInscription,
          isFalse,
          reason: 'Une chaîne vide passe `!= null` et plante plus loin.');
    });

    test('le menu conditionne bien les quatre gestes de l’année', () {
      final menu =
          _lire('lib/features/students/widgets/eleve_actions_menu.dart');
      expect(menu.contains('cible.aUneInscription'), isTrue);
      // Les deux papiers, eux, restent offerts même sans inscription et même
      // sur une année clôturée : imprimer n'est pas écrire, et c'est
      // précisément pour une année passée qu'on réclame un certificat.
      final avantDivider = menu.substring(0, menu.indexOf('surAnnee || canDelete'));
      expect(avantDivider, contains("value: 'certificat'"));
      expect(avantDivider, contains("value: 'carte'"));
    });
  });
}
