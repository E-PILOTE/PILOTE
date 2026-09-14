import 'dart:io';

import 'package:epilote/features/auth/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

// ════════════════════════════════════════════════════════════════════════════
//  L'ÉCRAN DE DÉMARRAGE NE DOIT DIRE CHAQUE CHOSE QU'UNE FOIS
//
//  ── CE QUI A ÉTÉ TROUVÉ (2026-09-06) ──────────────────────────────────────
//  `logo.svg` n'est pas une icône : c'est un BLOC COMPLET, avec « E-PILOTE »,
//  « CONGO », « GESTION SCOLAIRE » et une barre tricolore gravés dedans. À
//  46 px (connexion, PDF, barre latérale) ces mots sont illisibles et le bloc
//  se lit comme une icône — c'est pour cela que personne ne l'avait vu. L'écran
//  de démarrage, lui, l'affichait jusqu'à 140 px.
//
//  Résultat : le nom du produit écrit TROIS fois sur le même écran, sa vocation
//  DEUX fois, le pays DEUX fois, les couleurs nationales CINQ fois.
//
//  ── POURQUOI CE TEST PLUTÔT QU'UNE RELECTURE ──────────────────────────────
//  Le doublon ne se voit PAS en lisant le code : rien dans
//  `SvgPicture.asset('assets/icons/logo.svg')` ne dit que ce fichier contient
//  déjà le nom du produit. Il fallait ouvrir le SVG pour le savoir. C'est
//  exactement le genre de défaut qu'une relecture ne rattrape pas et qu'une
//  sonde attrape à tous les coups.
//
//  ── 🩸 CE QUE CE FICHIER GARDE AVANT TOUT ─────────────────────────────────
//  Le numéro de version. Il était écrit « v3.0 » À LA MAIN sur l'écran de
//  démarrage ET sur celui de connexion, pendant que le paquet passait de 3.0 à
//  3.5.17 — seize publications. C'est le premier chiffre que voit un visiteur.
//  `app_constants.dart` avait DÉJÀ retiré une constante `appVersion` figée pour
//  cette raison exacte, et le défaut avait repoussé ailleurs. Une version se
//  lit dans le binaire ; elle ne se tape pas.
// ════════════════════════════════════════════════════════════════════════════

String _lire(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) fail('Fichier introuvable : $chemin — sonde aveugle.');
  return f.readAsStringSync().replaceAll('\r\n', '\n');
}

/// Retire les blocs `<!-- … -->` : un commentaire n'est pas dessiné.
String _sansCommentairesXml(String svg) =>
    svg.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

String _sansCommentaires(String source) => source
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

const _splash = 'lib/features/auth/screens/splash_screen.dart';
const _login = 'lib/features/auth/screens/login_screen.dart';
const _pied = 'lib/features/auth/screens/widgets/splash_pied.dart';

void main() {
  group('La marque de l’écran de démarrage est muette', () {
    test('`logo_marque.svg` existe et ne contient AUCUN texte', () {
      // Les commentaires XML sont retirés d'abord : l'en-tête du fichier
      // CITE les mots qu'on y a supprimés, pour expliquer pourquoi. Ce
      // qui compte est ce qui est RENDU. (Ce test a commencé par se
      // prendre les pieds là-dedans — la sonde marchait trop bien.)
      final svg = _sansCommentairesXml(_lire('assets/icons/logo_marque.svg'));
      expect(svg.contains('<text'), isFalse,
          reason: 'La variante « marque » a repris du texte. Elle est affichée '
              'à 168 px sous un titre qui dit déjà « E-PILOTE CONGO » : le nom '
              'serait écrit deux fois, à trente centimètres d’un ministre.');
      expect(svg.contains('E-PILOTE'), isFalse);
      expect(svg.contains('CONGO'), isFalse);
      expect(svg.contains('GESTION SCOLAIRE'), isFalse);
    });

    test('le bloc complet, lui, garde ses mots — il sert ailleurs', () {
      // `logo.svg` n'est pas en cause : à 46 px il se lit comme une icône, et
      // il reste la signature des PDF et de la barre latérale. Ce test existe
      // pour qu'on ne « corrige » pas le mauvais fichier.
      final svg = _lire('assets/icons/logo.svg');
      expect(svg.contains('E-PILOTE'), isTrue,
          reason: 'Le bloc complet a perdu son texte : les en-têtes de PDF et '
              'la barre latérale ont perdu leur signature.');
    });

    test('l’écran de démarrage affiche la marque, jamais le bloc complet', () {
      final src = _sansCommentaires(_lire(_splash));
      expect(src.contains("'assets/icons/logo_marque.svg'"), isTrue);
      expect(src.contains("'assets/icons/logo.svg'"), isFalse,
          reason: 'Retour au bloc complet : le nom et la vocation seraient de '
              'nouveau écrits deux fois chacun.');
    });
  });

  group('🩸 La version n’est jamais tapée à la main', () {
    // Un numéro écrit en dur ne se périme pas bruyamment : il reste juste faux,
    // publication après publication. La sonde couvre les trois fichiers que
    // voit un visiteur avant d'entrer.
    final regexVersion = RegExp(r'''['"]v?\d+\.\d+(\.\d+)?['"]''');

    for (final chemin in [_splash, _login, _pied]) {
      test('aucun numéro de version en dur dans ${chemin.split('/').last}',
          () {
        final src = _sansCommentaires(_lire(chemin));
        final trouves = regexVersion.allMatches(src).map((m) => m[0]).toList();
        expect(trouves, isEmpty,
            reason: 'Version écrite à la main : $trouves. Elle sera fausse à '
                'la prochaine publication et personne ne le verra. Utiliser '
                '`VersionInstallee`, qui lit la ressource du binaire.');
      });
    }

    testWidgets('le pied affiche la version RÉELLEMENT installée',
        (tester) async {
      PackageInfo.setMockInitialValues(
        appName: 'E-PILOTE CONGO',
        packageName: 'cg.epilote',
        version: '9.9.9',
        buildNumber: '404',
        buildSignature: '',
      );

      await tester.binding.setSurfaceSize(const Size(1280, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(home: SplashScreen()),
      ));
      // Le pied n'apparaît qu'à 72 % des 3,2 s de la séquence.
      await tester.pump(const Duration(milliseconds: 3000));
      await tester.pump();

      expect(find.text('v9.9.9'), findsOneWidget,
          reason: 'Le pied n’a pas suivi la version du paquet. C’est le '
              'dernier chiffre que voit un visiteur avant de se connecter.');
    });
  });

  group('🩸 Chaque chose est dite une fois', () {
    Future<void> monter(WidgetTester tester) async {
      PackageInfo.setMockInitialValues(
        appName: 'E-PILOTE CONGO',
        packageName: 'cg.epilote',
        version: '3.5.17',
        buildNumber: '51',
        buildSignature: '',
      );
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(home: SplashScreen()),
      ));
      await tester.pump(const Duration(milliseconds: 3000));
      await tester.pump();
    }

    testWidgets('le nom du produit n’apparaît qu’une fois', (tester) async {
      await monter(tester);
      expect(find.text('E-PILOTE CONGO'), findsOneWidget);
    });

    testWidgets('le pays n’est nommé qu’une fois', (tester) async {
      await monter(tester);
      expect(find.text('République du Congo'), findsOneWidget,
          reason: 'Le pays était nommé dans le badge ET dans le pied, à deux '
              'tailles différentes, à trente pixels d’écart.');
    });

    test('le tricolore ne se dessine que deux fois, et pour deux raisons', () {
      // 1. le badge — le VRAI drapeau, en proportions de drapeau ;
      // 2. la barre de progression — 380 px sur 3, ça ne se lit plus comme un
      //    drapeau mais comme une ligne de lumière.
      // Le liseré vertical du décor est un dégradé à cinq arrêts (avec deux
      // transparents) : il ne correspond pas à ce motif, et c'est voulu.
      final src = _sansCommentaires(_lire(_splash));
      final triples =
          '[splashVert, splashJaune, splashRouge]'.allMatches(src).length;
      expect(triples, 2,
          reason: 'Le tricolore est dessiné $triples fois. Il y en avait cinq '
              'sur cet écran : dans le logo, DEUX fois dans le badge, dans la '
              'barre et dans le liseré. Cinq drapeaux ne font pas cinq fois '
              'plus de République.');
    });
  });
}
