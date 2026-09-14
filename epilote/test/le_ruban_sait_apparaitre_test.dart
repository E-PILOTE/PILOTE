import 'package:epilote/features/updates/providers/update_provider.dart';
import 'package:epilote/features/updates/widgets/update_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE RUBAN SAIT APPARAÎTRE
//
//  ── POURQUOI CE FICHIER EXISTE (2026-09-06) ───────────────────────────────
//  `update_provider_test.dart` couvrait bien la DÉCISION — quel build est en
//  retard, lequel est obligatoire, comment se lit l'empreinte. Personne
//  n'avait jamais fait S'AFFICHER la bannière. Le seul écran par lequel une
//  correction atteint mille postes n'était vérifié qu'en arithmétique.
//
//  C'est la même lacune que celle refermée le 2026-09-05 sur le dialogue de
//  code PIN : une logique juste dans un widget que rien n'exécute reste une
//  promesse.
//
//  ── LES VALEURS SONT CELLES RÉELLEMENT PUBLIÉES ───────────────────────────
//  3.5.15 / build 49, empreinte et adresse comprises, telles qu'elles ont été
//  écrites dans `app_releases` et vérifiées en accès anonyme le 2026-09-06.
//  Un test qui invente ses données ne dit rien de la ligne qui est en ligne.
// ════════════════════════════════════════════════════════════════════════════

/// Une empreinte de forme valide — 64 hexadécimaux — quand la valeur exacte
/// n'est pas le sujet du test.
const _sha =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

/// La version publiée sur le canal `windows / stable`, telle quelle.
const _publiee = AppRelease(
  version: '3.5.15',
  buildNumber: 49,
  downloadUrl: 'https://github.com/E-PILOTE/telechargements/releases/download/'
      'v3.5.15/E-PILOTE-3.5.15-installateur.exe',
  sha256: 'e721f45036f080f024b5e3881eb75e3ee7a60699c39a6ef58aac65f85a1f257e',
  sizeBytes: 36091527,
);

Future<void> _poser(
  WidgetTester tester,
  EtatMiseAJour etat,
) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [miseAJourProvider.overrideWith((ref) async => etat)],
    child: const MaterialApp(
      home: Scaffold(body: Column(children: [UpdateBanner()])),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('un poste en retard voit le ruban, et il nomme la version',
      (tester) async {
    // Exactement la situation du parc au 2026-09-06 : cinq profils entre les
    // builds 27 et 45, face au 49 publié.
    await _poser(
        tester,
        const EtatMiseAJour(
          buildInstalle: 45,
          versionInstallee: '3.5.11 (build 45)',
          disponible: _publiee,
        ));

    expect(find.text('Version 3.5.15 disponible'), findsOneWidget);
    expect(find.textContaining('3.5.11 (build 45)'), findsOneWidget,
        reason: 'Dire ce qu’on propose sans dire ce qu’on a installé oblige à '
            'chercher ailleurs pour savoir si l’on est concerné.');
    expect(find.widgetWithText(FilledButton, 'Mettre à jour'), findsOneWidget);
  });

  testWidgets('un poste à jour ne voit rien — c’est le cas de ce poste-ci',
      (tester) async {
    await _poser(
        tester,
        const EtatMiseAJour(
          buildInstalle: 49,
          versionInstallee: '3.5.15 (build 49)',
          disponible: _publiee,
        ));
    expect(find.textContaining('disponible'), findsNothing);
  });

  testWidgets('hors ligne : aucune bannière, aucune alerte', (tester) async {
    // Un poste d'école est hors ligne la moitié du temps. C'est le cas NORMAL.
    await _poser(
        tester,
        const EtatMiseAJour(
            buildInstalle: 45, versionInstallee: '3.5.11 (build 45)'));
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('« Plus tard » referme le ruban pour la session',
      (tester) async {
    await _poser(
        tester,
        const EtatMiseAJour(
          buildInstalle: 45,
          versionInstallee: '3.5.11 (build 45)',
          disponible: _publiee,
        ));
    await tester.tap(find.byTooltip('Plus tard'));
    await tester.pumpAndSettle();
    expect(find.text('Version 3.5.15 disponible'), findsNothing,
        reason: 'Une bannière qui revient à chaque écran finit par être '
            'fermée sans être lue.');
  });

  testWidgets('une version obligatoire ne se referme pas', (tester) async {
    // Ce n'est pas de l'insistance : `is_mandatory` signale une rupture de
    // schéma, donc un poste qui ne peut plus travailler correctement.
    await _poser(
        tester,
        const EtatMiseAJour(
          buildInstalle: 45,
          versionInstallee: '3.5.11 (build 45)',
          disponible: AppRelease(
            version: '3.5.15',
            buildNumber: 49,
            downloadUrl: 'https://exemple.invalide/e.exe',
            sha256: _sha,
            isMandatory: true,
          ),
        ));

    expect(find.text('Mise à jour nécessaire — version 3.5.15'), findsOneWidget);
    expect(find.byTooltip('Plus tard'), findsNothing,
        reason: 'Offrir de reporter un avertissement d’intégrité revient à '
            'ne pas l’avoir donné.');
  });

  testWidgets('un plancher de build rend la mise à jour obligatoire aussi',
      (tester) async {
    await _poser(
        tester,
        const EtatMiseAJour(
          buildInstalle: 27,
          versionInstallee: '3.4.3 (build 27)',
          disponible: AppRelease(
            version: '3.5.15',
            buildNumber: 49,
            downloadUrl: 'https://exemple.invalide/e.exe',
            sha256: _sha,
            minBuild: 40,
          ),
        ));
    expect(find.byTooltip('Plus tard'), findsNothing);
  });
}
