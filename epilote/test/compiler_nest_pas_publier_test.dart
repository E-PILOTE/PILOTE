import 'package:epilote/features/super_admin/providers/releases_provider.dart';
import 'package:epilote/features/super_admin/widgets/version_non_publiee.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

// ════════════════════════════════════════════════════════════════════════════
//  COMPILER N'EST PAS PUBLIER
//
//  ── CE QUI A ÉTÉ TROUVÉ (2026-09-05) ──────────────────────────────────────
//  La chaîne de mise à jour est entière et fonctionne : la bannière dans
//  `app_shell`, la vérification d'empreinte SHA-256 avant lancement, le
//  formulaire de publication et ses vingt-deux contrôles, le relevé du parc.
//  Rien ne manquait. Et pourtant ONZE VERSIONS CONSÉCUTIVES — 3.5.0 à 3.5.14,
//  builds 28 à 48 — ne sont jamais arrivées jusqu'au parc : `app_releases`
//  s'arrêtait au build 27, publié le 1er septembre.
//
//  Pendant onze versions, chaque poste demandant « existe-t-il une correction »
//  s'est entendu répondre « vous êtes à jour ».
//
//  ── LA VRAIE LEÇON, QUI N'EST PAS TECHNIQUE ───────────────────────────────
//  Publier est une étape HUMAINE qui suit la compilation. Rien, nulle part, ne
//  comparait les deux : `ParcSection` dit ce que le parc exécute, la liste dit
//  ce qui est publié, et personne ne disait ce que la machine d'en face vient
//  de compiler. L'écart n'avait aucun domicile — ni ligne, ni écran, ni test.
//
//  C'est exactement le défaut des `catch (_) {}` corrigés le même jour, déplacé
//  d'un cran : le silence d'un manquement le rend invisible, pas inoffensif.
//
//  ── CE QUE CE FICHIER GARDE ───────────────────────────────────────────────
//  Qu'un poste exécutant un build non publié le DISE, et — tout aussi
//  important — qu'il se taise dès que l'écart est comblé. Un avertissement
//  permanent ne s'avertit plus de rien.
// ════════════════════════════════════════════════════════════════════════════

ReleasePubliee _publiee({
  required int build,
  String platform = 'windows',
  String channel = 'stable',
}) =>
    ReleasePubliee(
      id: 'r$build',
      version: '3.x.$build',
      buildNumber: build,
      platform: platform,
      channel: channel,
      downloadUrl: 'https://example.invalid/e.exe',
      sha256: 'a' * 64,
      isMandatory: false,
    );

Future<void> _poser(
  WidgetTester tester, {
  required String version,
  required String build,
  required List<ReleasePubliee> publiees,
}) async {
  PackageInfo.setMockInitialValues(
    appName: 'E-PILOTE',
    packageName: 'cg.epilote',
    version: version,
    buildNumber: build,
    buildSignature: '',
  );
  await tester.pumpWidget(ProviderScope(
    overrides: [
      releasesProvider.overrideWith((ref) async => publiees),
    ],
    child: const MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: VersionNonPubliee())),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('un build compilé mais non publié le dit', (tester) async {
    await _poser(tester,
        version: '3.5.14',
        build: '48',
        publiees: [_publiee(build: 27), _publiee(build: 26)]);

    expect(
        find.textContaining('que le parc ne connaît pas'), findsOneWidget);
    // Le chiffre qui compte est l'ÉCART, pas les deux numéros : « 21 builds »
    // se retient, « 48 contre 27 » se relit deux fois.
    expect(find.textContaining('21 builds'), findsOneWidget);
  });

  testWidgets('il se tait dès que l’écart est comblé', (tester) async {
    await _poser(tester,
        version: '3.5.14', build: '48', publiees: [_publiee(build: 48)]);
    expect(find.textContaining('que le parc ne connaît pas'), findsNothing);
  });

  testWidgets('un poste EN RETARD ne déclenche rien', (tester) async {
    // Le super_admin peut ouvrir la page depuis une machine ancienne. Ce n'est
    // pas un défaut de livraison, et le dire ferait publier à tort.
    await _poser(tester,
        version: '3.4.0', build: '24', publiees: [_publiee(build: 27)]);
    expect(find.textContaining('que le parc ne connaît pas'), findsNothing);
  });

  testWidgets('un build publié sur une AUTRE plateforme ne comble rien',
      (tester) async {
    // La table est indexée par plateforme : un poste Windows ne reçoit jamais
    // une ligne Linux, si haute soit-elle.
    await _poser(tester, version: '3.5.14', build: '48', publiees: [
      _publiee(build: 60, platform: 'linux'),
      _publiee(build: 27),
    ]);
    expect(find.textContaining('que le parc ne connaît pas'), findsOneWidget);
    expect(find.textContaining('21 builds'), findsOneWidget);
  });

  testWidgets('publier en `beta` ne comble rien non plus', (tester) async {
    // Le poste code `p_channel: 'stable'` en dur : une ligne `beta` lui est
    // invisible. Compter le canal beta annoncerait une livraison qui n'a
    // atteint personne.
    await _poser(tester, version: '3.5.14', build: '48', publiees: [
      _publiee(build: 48, channel: 'beta'),
      _publiee(build: 27),
    ]);
    expect(find.textContaining('que le parc ne connaît pas'), findsOneWidget);
  });

  testWidgets('table vide : on nomme l’absence plutôt qu’un zéro',
      (tester) async {
    await _poser(tester, version: '3.5.14', build: '48', publiees: const []);
    expect(find.textContaining('est aucun'), findsOneWidget,
        reason: '« le plus haut build publié est 0 » laisserait croire à un '
            'build numéro zéro ; il n’y en a simplement aucun.');
  });

  testWidgets('un build illisible se tait au lieu de réclamer',
      (tester) async {
    // Même règle que `miseAJourProvider` : sans numéro de build, toute
    // comparaison est fausse, et l’avertissement resterait affiché à jamais.
    await _poser(tester,
        version: '3.5.14', build: '', publiees: [_publiee(build: 27)]);
    expect(find.textContaining('que le parc ne connaît pas'), findsNothing);
  });

  testWidgets('l’encart dit qu’il ne parle que de CE poste', (tester) async {
    await _poser(tester,
        version: '3.5.14', build: '48', publiees: [_publiee(build: 27)]);
    expect(find.textContaining('Depuis ce poste'), findsOneWidget,
        reason: 'Sans cette réserve, un écart lu depuis une machine de '
            'développement passe pour un défaut de livraison.');
  });
}
