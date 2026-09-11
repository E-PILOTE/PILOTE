import 'dart:io';

import 'package:epilote/features/students/providers/students_registry_provider.dart';
import 'package:epilote/features/students/screens/eleves_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  HUIT CENTS ÉLÈVES CONSTRUITS POUR EN MONTRER DOUZE
//
//  ── CE QUI SE PASSAIT ─────────────────────────────────────────────────────
//  La page Élèves était un `SingleChildScrollView` sur une `Column`. Flutter
//  construisait donc CHAQUE ligne, y compris celles qu'on ne verra jamais sans
//  faire défiler. Sur l'école la plus chargée du parc — 868 élèves — cela fait
//  868 `InkWell`, 868 avatars et 868 rangées de badges pour une douzaine de
//  lignes visibles.
//
//  Et ce n'est pas un coût payé une fois : la liste vient de `db.watch`. Elle
//  se reconstruit à CHAQUE tick de synchronisation. Un poste qui reçoit ses
//  données refaisait huit cents lignes invisibles à chaque lot — et le
//  symptôme, « l'application rame quand ça synchronise », ne désigne jamais sa
//  cause.
//
//  ── POURQUOI UN TEST QUI PEINT VRAIMENT ───────────────────────────────────
//  Une sonde de source dirait que `CustomScrollView` est là. Elle ne dirait
//  pas que la virtualisation OPÈRE : un `SliverList` mal imbriqué, une
//  contrainte de hauteur infinie, et tout se construit quand même sans que
//  rien ne le signale.
//
//  Ces tests montent la liste et comptent ce qui a été CONSTRUIT. Le nom d'un
//  élève hors écran ne doit exister nulle part dans l'arbre.
// ════════════════════════════════════════════════════════════════════════════

StudentRow _eleve(int i) => StudentRow(
      id: 'e$i',
      firstName: 'Jean',
      lastName: 'MAKOSSO $i',
      matricule: 'MAT-$i',
      ine: '2026${i.toString().padLeft(8, '0')}',
      gender: i.isEven ? 'M' : 'F',
      dateOfBirth: DateTime(2010, 5, 12),
      placeOfBirth: 'Pointe-Noire',
      nationality: 'Congolaise',
      photoUrl: null,
      isBoarder: i % 11 == 0,
      hasScholarship: false,
      hasSocialAid: false,
      isAffecte: false,
      enrollmentId: 'i$i',
      enrollmentStatus: 'active',
      classId: 'c1',
      className: '6ème A',
      cycleCode: 'college',
      levelCode: '6e',
      levelOrder: 6,
      filiereLabel: null,
      hasPrimaryTutor: true,
    );

/// Monte la liste dans une fenêtre de taille fixe et rend la main.
Future<void> _monter(
  WidgetTester tester, {
  required int combien,
  required bool isTable,
  Size fenetre = const Size(1280, 800),
}) async {
  tester.view.physicalSize = fenetre;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: CustomScrollView(
          slivers: studentListSlivers(
            rows: [for (var i = 0; i < combien; i++) _eleve(i)],
            isTable: isTable,
            sortAsc: true,
            readOnly: false,
            selected: const {},
            onSort: () {},
            onSelect: (_, _) {},
            onSelectAll: (_) {},
            onOpen: (_) {},
          ),
        ),
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  group('🩸 La table ne construit que ce qui se voit', () {
    testWidgets('868 élèves — l\'école la plus chargée du parc', (t) async {
      await _monter(t, combien: 868, isTable: true);

      expect(find.textContaining('MAKOSSO 0'), findsOneWidget,
          reason: 'La première ligne doit être là : virtualiser n\'est pas '
              'ne rien afficher.');
      expect(find.textContaining('MAKOSSO 867'), findsNothing,
          reason: 'Le dernier élève est à huit cents lignes du haut. Le '
              'construire, c\'est le défaut qu\'on corrige.');
    });

  });

  group('🩸 Les cartes non plus', () {
    testWidgets('868 élèves en mode cartes', (t) async {
      await _monter(t, combien: 868, isTable: false);
      expect(find.textContaining('MAKOSSO 0'), findsOneWidget);
      expect(find.textContaining('MAKOSSO 867'), findsNothing);
    });

    testWidgets('la grille garde ses quatre colonnes en grand écran',
        (t) async {
      // Mêmes seuils que la `Wrap` d'origine : quatre cartes par rangée
      // au-delà de 1180 pt de large. Si la conversion les avait perdus, la
      // page passerait à une colonne sans qu'aucun test ne bronche.
      await _monter(t, combien: 8, isTable: false,
          fenetre: const Size(1280, 900));
      for (var i = 0; i < 4; i++) {
        expect(find.textContaining('MAKOSSO $i'), findsOneWidget);
      }
    });

    testWidgets('une dernière rangée incomplète ne déforme pas les cartes',
        (t) async {
      // Cinq élèves sur quatre colonnes : la seconde rangée n'en porte qu'un.
      // Sans les remplisseurs, il s'étalerait sur toute la largeur.
      await _monter(t, combien: 5, isTable: false,
          fenetre: const Size(1280, 900));
      final large = t.getSize(find.ancestor(
        of: find.textContaining('MAKOSSO 4'),
        matching: find.byType(Expanded),
      ).first);
      final premiere = t.getSize(find.ancestor(
        of: find.textContaining('MAKOSSO 0'),
        matching: find.byType(Expanded),
      ).first);
      expect(large.width, closeTo(premiere.width, 1.0),
          reason: 'La carte esseulée doit garder la largeur d\'une colonne.');
    });
  });

  group('Les petits cas restent servis', () {
    testWidgets('un seul élève', (t) async {
      await _monter(t, combien: 1, isTable: true);
      expect(find.textContaining('MAKOSSO 0'), findsOneWidget);
    });

    testWidgets('un seul élève en cartes', (t) async {
      await _monter(t, combien: 1, isTable: false);
      expect(find.textContaining('MAKOSSO 0'), findsOneWidget);
    });
  });

  group('L\'écran a bien changé de structure', () {
    /// Sans les commentaires : le fichier NOMME `SingleChildScrollView` pour
    /// expliquer pourquoi il ne l'emploie plus. Compter cette mention ferait
    /// de l'explication elle-même une fausse alerte — et la première réaction
    /// serait de retirer l'explication.
    String lire(String c) => File(c)
        .readAsStringSync()
        .replaceAll('\r\n', '\n')
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');

    test('plus de `SingleChildScrollView` autour de la liste', () {
      final src = lire('lib/features/students/screens/eleves_screen.dart');
      expect(src.contains('SingleChildScrollView'), isFalse,
          reason: 'C\'est lui qui forçait la construction des huit cents '
              'lignes. Son retour rétablirait le défaut sans un message.');
      expect(src.contains('CustomScrollView'), isTrue);
      expect(src.contains('studentListSlivers('), isTrue);
    });

    test('l\'ancienne table monolithique a disparu', () {
      final src = lire('lib/features/students/screens/eleves_liste_parts.dart');
      expect(src.contains('class _StudentTable'), isFalse,
          reason: 'Elle posait en-tête ET lignes dans une seule `Column`.');
      expect(src.contains('class _StudentCards'), isFalse,
          reason: 'Le `Wrap` construisait toutes les cartes d\'un coup.');
      expect(src.contains('SliverList.builder'), isTrue);
    });
  });
}
