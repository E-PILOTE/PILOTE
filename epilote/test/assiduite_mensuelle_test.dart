import 'dart:io';

import 'package:epilote/features/vie_scolaire/providers/assiduite_mensuelle_provider.dart';
import 'package:epilote/features/vie_scolaire/services/assiduite_pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE RELEVÉ MENSUEL D'ASSIDUITÉ
//
//  ── CE QUI MANQUAIT ────────────────────────────────────────────────────────
//  L'appel était saisi chaque demi-journée, agrégé pour l'écran du jour, et
//  totalisé NULLE PART. L'établissement détenait la donnée et recomptait à la
//  main la pièce que la circonscription lui demande tous les mois.
//
//  ── LE PIÈGE DE CE DOCUMENT, ET IL EST GRAVE ──────────────────────────────
//  Un relevé d'assiduité est un document à charge. Le produire faux ne fait
//  pas perdre du temps : il fait convoquer une famille, ou un professeur.
//
//  Deux erreurs le rendraient faux, et toutes deux ressemblent à un calcul
//  normal :
//
//   1. UN TAUX SANS POINTAGE VALANT 0 %. Une classe dont l'appel n'a pas été
//      fait afficherait le pire taux possible, présenté comme un fait, sur la
//      classe dont on ne sait justement rien.
//
//   2. UN DÉNOMINATEUR EN JOURS PLUTÔT QU'EN POINTAGES. Noter sur vingt une
//      classe pointée huit fois transforme un défaut de saisie du personnel en
//      absentéisme des élèves.
//
//  Ce fichier tient les deux, et vérifie que le document sort à l'échelle
//  d'un vrai établissement.
// ════════════════════════════════════════════════════════════════════════════

AssiduiteClasse _classe(
  String nom, {
  int effectif = 30,
  int demiJournees = 0,
  int presences = 0,
  int absences = 0,
  int retards = 0,
  int justifiees = 0,
}) =>
    AssiduiteClasse(
      classId: 'c$nom',
      className: nom,
      cycleCode: 'college',
      levelCode: '6e',
      levelOrder: 6,
      effectif: effectif,
      demiJournees: demiJournees,
      finalisees: demiJournees,
      presences: presences,
      absences: absences,
      retards: retards,
      justifiees: justifiees,
    );

EtatAssiduiteMensuel _etat(List<AssiduiteClasse> classes,
        {List<AssiduiteEleve> alertes = const []}) =>
    EtatAssiduiteMensuel(
      mois: (annee: 2026, mois: 3),
      classes: classes,
      alertes: alertes,
      joursPointes: 18,
      perimetreCharge: true,
    );

void main() {
  setUpAll(() async => initializeDateFormatting('fr'));
  TestWidgetsFlutterBinding.ensureInitialized();

  group('🩸 Un taux sans pointage est INCONNU, pas nul', () {
    test('une classe jamais pointée ne rend pas 0 %', () {
      final c = _classe('6ème A');
      expect(c.pointages, 0);
      expect(c.tauxPresence, isNull,
          reason: 'Zéro pour cent est le pire chiffre possible. L\'écrire sur '
              'la classe dont on ne sait rien fait convoquer un professeur '
              'pour un travail dont rien ne dit qu\'il n\'a pas été fait.');
    });

    test('un mois entier sans appel se déclare comme tel', () {
      final e = _etat([_classe('6ème A'), _classe('5ème B')]);
      expect(e.aucunPointage, isTrue);
      expect(e.tauxPresence, isNull);
    });

    test('les classes muettes sont NOMMÉES, pas noyées dans une moyenne', () {
      // Trois classes à 96 % et une jamais pointée donnent un établissement
      // « à 96 % ». C'est la quatrième qui appelle une décision.
      final e = _etat([
        _classe('6ème A', demiJournees: 18, presences: 480, absences: 20),
        _classe('5ème B', demiJournees: 18, presences: 480, absences: 20),
        _classe('4ème C'),
      ]);
      expect(e.aucunPointage, isFalse);
      expect(e.sansAucunAppel.map((c) => c.className), ['4ème C']);
    });
  });

  group('🩸 Le dénominateur est le POINTAGE, jamais le jour', () {
    test('une classe pointée huit fois n’est pas notée sur vingt', () {
      // 8 demi-journées × 30 élèves = 240 pointages ; 230 présents.
      final c = _classe('6ème A',
          effectif: 30, demiJournees: 8, presences: 230, absences: 10);
      expect(c.pointages, 240);
      expect(c.tauxPresence, closeTo(95.83, 0.01),
          reason: 'Compter les jours non pointés comme des absences ferait '
              'passer cette classe sous 40 % — un absentéisme inventé par un '
              'défaut de saisie.');
    });

    test('un retard compte comme une présence au taux, et se voit à part', () {
      final c = _classe('6ème A',
          demiJournees: 10, presences: 90, absences: 5, retards: 5);
      expect(c.pointages, 100);
      expect(c.tauxPresence, 95.0,
          reason: 'L\'élève en retard ÉTAIT là : le compter absent fausse le '
              'taux dans le sens qui accuse.');
      expect(c.retards, 5);
    });
  });

  group('Justifiées et injustifiées', () {
    test('l’injustifié est le reste, jamais un compteur séparé', () {
      final c = _classe('6ème A',
          demiJournees: 10, presences: 80, absences: 20, justifiees: 12);
      expect(c.injustifiees, 8);
    });

    test('le total de l’établissement suit la même règle', () {
      final e = _etat([
        _classe('6ème A', demiJournees: 10, presences: 80, absences: 20, justifiees: 12),
        _classe('5ème B', demiJournees: 10, presences: 90, absences: 10, justifiees: 3),
      ]);
      expect(e.absences, 30);
      expect(e.justifiees, 15);
      expect(e.injustifiees, 15);
    });
  });

  group('Le seuil d’alerte', () {
    test('quatre demi-journées — deux jours de classe', () {
      expect(kSeuilAlerteAbsences, 4,
          reason: 'Plus bas, la liste se remplit de rhumes et cesse d\'être '
              'lue ; plus haut, on rate le premier signal de déperdition.');
    });

    test('l’état en attente ne prétend pas être un mois vide', () {
      const e = EtatAssiduiteMensuel.enAttente((annee: 2026, mois: 3));
      expect(e.perimetreCharge, isFalse,
          reason: 'Sans ce drapeau, un périmètre en cours de chargement '
              'produirait un état « aucune classe » — un établissement '
              'inexistant.');
    });
  });

  group('Le mois se nomme en français', () {
    test('libellé complet', () {
      expect(libelleMois((annee: 2026, mois: 3)), 'mars 2026');
      expect(libelleMois((annee: 2025, mois: 10)), 'octobre 2025');
    });

    test('un mois hors bornes ne fait pas planter le document', () {
      expect(() => libelleMois((annee: 2026, mois: 13)), returnsNormally);
    });
  });

  group('🩸 Le document SORT — à l’échelle d’un vrai établissement', () {
    test('20 classes et 60 élèves à suivre', () async {
      // Bien au-delà des 28 lignes d'un bloc portrait : sans découpe, ce
      // document ne se génèrerait pas du tout.
      final bytes = await AssiduitePdfService.buildPdf(
        etat: _etat(
          [
            for (var i = 0; i < 20; i++)
              _classe('${6 - (i ~/ 4)}ème ${String.fromCharCode(65 + i % 4)}',
                  demiJournees: 18,
                  presences: 480 + i,
                  absences: 20 + i,
                  retards: i,
                  justifiees: i),
          ],
          alertes: [
            for (var i = 0; i < 60; i++)
              AssiduiteEleve(
                studentId: 'e$i',
                nom: 'MAKOSSO-NGOMA BOUKAKA Jean-Baptiste $i',
                matricule: 'MAT-${i.toString().padLeft(5, '0')}',
                className: '6ème A',
                absences: 4 + (i % 12),
                retards: i % 5,
                justifiees: i % 3,
              ),
          ],
        ),
        schoolName: 'Collège d\'Enseignement Général de Mpaka',
        yearLabel: '2025-2026',
      );
      expect(bytes.lengthInBytes, greaterThan(1000));
    });

    test('un mois sans le moindre appel rend un document, pas une exception',
        () async {
      final bytes = await AssiduitePdfService.buildPdf(
        etat: _etat([_classe('6ème A'), _classe('5ème B')]),
        schoolName: 'École primaire de Loandjili',
        yearLabel: '2025-2026',
      );
      expect(bytes.lengthInBytes, greaterThan(1000));
    });

    test('un périmètre vide rend un document, pas une exception', () async {
      final bytes = await AssiduitePdfService.buildPdf(
        etat: _etat(const []),
        schoolName: 'École primaire de Loandjili',
      );
      expect(bytes.lengthInBytes, greaterThan(1000));
    });
  });

  group('Le service et le provider tiennent leur doctrine dans la source', () {
    String lire(String c) => File(c).readAsStringSync().replaceAll('\r\n', '\n');

    test('le PDF n’écrit jamais « 0 % » par défaut', () {
      final src =
          lire('lib/features/vie_scolaire/services/assiduite_pdf_service.dart');
      expect(src.contains("v == null ? '—'"), isTrue,
          reason: 'Le tiret est la seule écriture honnête d\'un taux inconnu.');
      expect(src.contains('tableSection'), isTrue,
          reason: 'Vingt classes et cinquante alertes dépassent la page ; '
              '`frame(table())` ne produirait AUCUN document.');
    });

    test('le relevé porte le périmètre de SON module', () {
      final src = lire(
          'lib/features/vie_scolaire/providers/assiduite_mensuelle_provider.dart');
      expect(src.contains('classesForModuleProvider(kSlugPresences)'), isTrue,
          reason: 'Avec le slug d\'un autre module, un enseignant restreint à '
              'ses classes produirait l\'état de tout l\'établissement.');
    });

    test('le bouton suit `export`, pas `update`', () {
      final src =
          lire('lib/features/vie_scolaire/screens/presences_screen.dart');
      expect(src.contains("canProvider((slug: _kSlug, action: 'export'))"),
          isTrue,
          reason: 'Produire un état est une LECTURE. Le garder sur `update` '
              'le cacherait au directeur, qui ne pointe jamais lui-même.');
    });
  });
}
