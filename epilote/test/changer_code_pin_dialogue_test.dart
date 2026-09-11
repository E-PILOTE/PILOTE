import 'package:epilote/data/models/profile_model.dart';
import 'package:epilote/features/auth/providers/active_agent_provider.dart';
import 'package:epilote/features/profil/providers/mon_code_pin_provider.dart';
import 'package:epilote/features/profil/providers/mon_profil_provider.dart';
import 'package:epilote/features/profil/widgets/changer_code_pin_dialog.dart';
import 'package:epilote/features/profil/widgets/profil_code_pin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE DIALOGUE DE CHANGEMENT DE CODE — EXÉCUTÉ POUR DE VRAI
//
//  ── POURQUOI CE FICHIER EXISTE ────────────────────────────────────────────
//  `le_code_pin_se_change_depuis_mon_profil_test.dart` garde les DÉCISIONS :
//  il lit le source pour vérifier que l'ancien code est exigé, que le compteur
//  d'échecs est partagé, que la carte n'est pas gatée sur le compte appareil.
//  Aucune de ces sondes ne fait tourner le widget. Le service, lui, est testé
//  seul. Entre les deux, il restait un trou de la taille de l'écran : le
//  câblage — champs, ordre des contrôles, fermeture, message d'erreur —
//  n'avait jamais été exécuté une seule fois, ni en test ni à la main (les
//  sessions de recette sont des `admin_groupe`, que le verrou ne concerne pas).
//
//  Ici on ouvre la boîte, on tape dedans, et on vérifie ce que la personne
//  au clavier obtient réellement.
// ════════════════════════════════════════════════════════════════════════════

const _svc = AgentPinService();
const _moi = 'agent-au-clavier';

Future<void> _ouvrir(WidgetTester tester, {required bool aPoser}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<bool>(
                context: context,
                builder: (_) =>
                    ChangerCodePinDialog(profilId: _moi, aPoser: aPoser),
              ),
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('ouvrir'));
  await tester.pumpAndSettle();
}

/// Remplit les champs dans l'ordre où le dialogue les présente.
Future<void> _saisir(WidgetTester tester, List<String> codes) async {
  final champs = find.byType(TextField);
  expect(tester.widgetList(champs).length, codes.length,
      reason: 'Le dialogue ne présente pas le nombre de champs attendu.');
  for (var i = 0; i < codes.length; i++) {
    await tester.enterText(champs.at(i), codes[i]);
  }
  await tester.pump();
}

Future<void> _valider(WidgetTester tester, String libelle) async {
  await tester.tap(find.widgetWithText(FilledButton, libelle));
  await tester.pumpAndSettle();
}

// ─── La carte, telle qu'elle apparaît dans « Mon profil » ────────────────────

MonProfil _profil(String role) => MonProfil(
      profil: ProfileModel.fromMap({
        'id': _moi,
        'role': role,
        'first_name': 'Alphonse',
        'last_name': 'Mabiala',
        'is_active': true,
        'created_at': '2026-01-05T08:00:00Z',
        'updated_at': '2026-01-05T08:00:00Z',
      }),
      emailDuCompte: null,
      // Le cas qui compte : la session appartient au compte APPAREIL, pas à
      // l'agent affiché. Mot de passe et sessions sont refusés là ; le code
      // PIN, lui, doit rester accessible.
      estLeCompteAppareil: false,
    );

Future<void> _carte(WidgetTester tester,
    {required String role, required EtatCodePin etat}) async {
  final moi = _profil(role);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      etatCodePinProvider((id: _moi, role: role)).overrideWith((_) => etat),
    ],
    child: MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: ProfilCodePin(moi: moi))),
    ),
  ));
  await tester.pumpAndSettle();
}

void _testsDeLaCarte() {
  group('La carte « Code de ce poste »', () {
    // La carte date la pose du code : `staffFmtDateTime` construit un
    // `DateFormat` français, qui exige les données de locale — l'application
    // les charge dans `main()`, un test doit le faire lui-même.
    setUpAll(() => initializeDateFormatting('fr_FR', null));

    testWidgets('invisible pour un rôle que le verrou ne concerne pas',
        (tester) async {
      await _carte(tester,
          role: 'admin_groupe',
          etat: const EtatCodePin(sApplique: false));
      expect(find.text('Code de ce poste'), findsNothing,
          reason: 'Proposer un code à qui n’en aura jamais besoin ajoute une '
              'case à remplir, pas de la sécurité.');
    });

    testWidgets('aucun code posé → « Poser », et on le dit', (tester) async {
      await _carte(tester,
          role: 'secretaire', etat: const EtatCodePin(sApplique: true));
      expect(find.text('Code de ce poste'), findsOneWidget);
      expect(find.text('Poser'), findsOneWidget);
      expect(find.text('Changer'), findsNothing);
      expect(find.textContaining('Aucun code'),
          findsOneWidget);
    });

    testWidgets('code existant → « Changer », avec la date et la portée',
        (tester) async {
      await _carte(tester,
          role: 'enseignant',
          etat: EtatCodePin(
              sApplique: true, existe: true, poseLe: DateTime(2026, 9, 2, 14)));
      expect(find.text('Changer'), findsOneWidget);
      expect(find.textContaining('CET ordinateur'), findsOneWidget,
          reason: 'Sans cette phrase, on croit changer son code partout.');
      expect(find.textContaining('Posé ici le'), findsOneWidget);
    });

    testWidgets('reset demandé → bandeau d’avertissement et retour à « Poser »',
        (tester) async {
      await _carte(tester,
          role: 'comptable',
          etat: EtatCodePin(
              sApplique: true,
              existe: true,
              poseLe: DateTime(2026, 9, 1),
              resetDemande: true));
      expect(find.text('Poser'), findsOneWidget,
          reason: 'Le code local ne vaut plus rien : il n’y a plus d’ancien '
              'code à opposer.');
      expect(find.textContaining('réinitialisation'), findsOneWidget,
          reason: 'Annoncé ici, au calme — pas devant une file de parents.');
    });
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Changer un code existant', () {
    testWidgets('le bon ancien code fait passer le nouveau', (tester) async {
      await _svc.setPin(_moi, '1234');
      await _ouvrir(tester, aPoser: false);

      expect(find.text('Code actuel'), findsOneWidget);
      await _saisir(tester, ['1234', '5678', '5678']);
      await _valider(tester, 'Changer le code');

      expect(find.byType(AlertDialog), findsNothing,
          reason: 'Le dialogue doit se refermer sur un changement réussi.');
      expect(await _svc.verifyPin(_moi, '5678'), isTrue);
      expect(await _svc.verifyPin(_moi, '1234'), isFalse,
          reason: 'L’ancien code rouvrirait encore le poste.');
    });

    testWidgets('un mauvais ancien code refuse ET compte l’échec',
        (tester) async {
      await _svc.setPin(_moi, '1234');
      await _ouvrir(tester, aPoser: false);

      await _saisir(tester, ['0000', '5678', '5678']);
      await _valider(tester, 'Changer le code');

      expect(find.text('Code actuel incorrect.'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget,
          reason: 'La boîte doit rester ouverte pour réessayer.');
      expect(await _svc.failCount(_moi), 1,
          reason: 'Un échec non compté ouvre dix mille essais gratuits.');
      expect(await _svc.verifyPin(_moi, '1234'), isTrue,
          reason: 'Le code d’origine ne doit surtout pas avoir bougé.');
      expect(await _svc.verifyPin(_moi, '5678'), isFalse);
    });

    testWidgets('le champ « code actuel » se vide après un échec',
        (tester) async {
      // Sinon on retape par-dessus une saisie invisible (le champ est masqué)
      // et l'on accumule des échecs sans comprendre pourquoi.
      await _svc.setPin(_moi, '1234');
      await _ouvrir(tester, aPoser: false);
      await _saisir(tester, ['0000', '5678', '5678']);
      await _valider(tester, 'Changer le code');

      final actuel = tester.widget<TextField>(find.byType(TextField).first);
      expect(actuel.controller?.text, isEmpty);
    });

    testWidgets('deux nouveaux codes différents sont refusés', (tester) async {
      await _svc.setPin(_moi, '1234');
      await _ouvrir(tester, aPoser: false);

      await _saisir(tester, ['1234', '5678', '5679']);
      await _valider(tester, 'Changer le code');

      expect(find.text('Les deux codes ne correspondent pas.'), findsOneWidget);
      expect(await _svc.verifyPin(_moi, '1234'), isTrue);
    });

    testWidgets('reposer le même code est refusé', (tester) async {
      // Se croire protégé sans que rien n'ait changé est pire que ne pas agir.
      await _svc.setPin(_moi, '1234');
      await _ouvrir(tester, aPoser: false);

      await _saisir(tester, ['1234', '1234', '1234']);
      await _valider(tester, 'Changer le code');

      expect(find.text('Choisissez un code différent de l\'actuel.'),
          findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('un code trop court ne part pas', (tester) async {
      await _svc.setPin(_moi, '1234');
      await _ouvrir(tester, aPoser: false);

      await _saisir(tester, ['1234', '56', '56']);
      await _valider(tester, 'Changer le code');

      expect(find.text('Le code compte 4 chiffres.'), findsOneWidget);
      expect(await _svc.verifyPin(_moi, '1234'), isTrue);
    });
  });

  group('Poser un premier code', () {
    testWidgets('aucun champ « code actuel » — il n’y a rien à opposer',
        (tester) async {
      await _ouvrir(tester, aPoser: true);

      expect(find.text('Code actuel'), findsNothing);
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.widgetWithText(FilledButton, 'Poser le code'), findsOneWidget);
    });

    testWidgets('le code posé ouvre ensuite le poste', (tester) async {
      await _ouvrir(tester, aPoser: true);

      await _saisir(tester, ['4321', '4321']);
      await _valider(tester, 'Poser le code');

      expect(find.byType(AlertDialog), findsNothing);
      expect(await _svc.hasPin(_moi), isTrue);
      expect(await _svc.verifyPin(_moi, '4321'), isTrue);
      expect(await _svc.pinSetAt(_moi), isNotNull,
          reason: 'La date de pose sert à réconcilier un reset serveur.');
    });
  });

  group('La pause anti-force-brute s’applique dans cette boîte', () {
    testWidgets('une pause héritée de l’écran-verrou bloque la validation',
        (tester) async {
      await _svc.setPin(_moi, '1234');
      // Cinq échecs : c'est le premier palier de `pinCooldown` (30 s).
      for (var i = 0; i < 5; i++) {
        await _svc.recordFail(_moi);
      }
      expect(await _svc.lockedUntil(_moi), isNotNull);

      await _ouvrir(tester, aPoser: false);
      await tester.pump(); // laisse `_relirePause` rendre la main

      final bouton = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Changer le code'));
      expect(bouton.onPressed, isNull,
          reason: 'Sinon cette boîte devient le chemin doux vers la force '
              'brute que l’écran-verrou refuse.');
      expect(find.textContaining('Trop d\'essais'), findsOneWidget);

      // Le minuteur du compte à rebours doit être arrêté à la fermeture.
      await tester.tap(find.widgetWithText(TextButton, 'Annuler'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });
  });

  _testsDeLaCarte();
}
