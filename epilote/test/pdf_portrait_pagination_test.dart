// ════════════════════════════════════════════════════════════════════════════
//  LE MÊME DÉFAUT, EN PORTRAIT — QUATRE AUTRES DOCUMENTS
//
//  ── CE QUI A CONDUIT ICI ───────────────────────────────────────────────────
//  `test/pdf_paysage_pagination_test.dart` a été écrit après avoir trouvé, par
//  accident, que la liste des candidats ne se générait pas. En cherchant
//  pourquoi, trois autres documents en paysage sont tombés.
//
//  Chercher par accident ne suffit pas. Ce fichier est le recensement : les 26
//  `OfficialPdfKit.frame(... table(...))` de l'application ont été relevés, et
//  triés selon UNE question — le nombre de lignes est-il FIXE, ou suit-il les
//  données ?
//
//  Vingt-deux sont bornés par construction : une fiche de candidat (six
//  lignes), deux tuteurs, un récapitulatif à quatre postes, ou un tableau déjà
//  découpé à la main (`chunk`, `blocks[i]`). Ceux-là tiennent sur une page
//  parce qu'ils ne peuvent pas faire autrement.
//
//  Quatre ne sont bornés par rien.
//
//  ── LE MÉCANISME, RAPPELÉ ──────────────────────────────────────────────────
//  `frame()` enveloppe son contenu dans un `Padding`, qui ne sait pas se
//  scinder entre deux pages. Une table plus haute qu'une feuille fait boucler
//  `MultiPage` jusqu'à `TooManyPagesException` : pas un document tronqué —
//  AUCUN document. En portrait, la limite mesurée est `kRowsPerBlock` = 28.
//
//  ── LES QUATRE, ET CE QU'ILS PORTENT ───────────────────────────────────────
//   · RÉFÉRENTIEL DES MATIÈRES — 95 matières en base aujourd'hui ;
//   · RÉPERTOIRE DES FAMILLES — une ligne par élève ayant un contact, la
//     liste qu'on appelle quand un enfant ne rentre pas ;
//   · REGISTRE DE CONFORMITÉ DES DOSSIERS — une ligne par élève actif, la
//     pièce que l'inspection demande ;
//   · ÉTAT DES TRANSFERTS — une ligne par transfert, groupée par statut.
//
//  Aucun ne dépasse 28 lignes sur un jeu de démonstration. Tous les dépassent
//  dans une école réelle — la plus chargée du parc porte 868 élèves.
//
//  ── CE QUE CES TESTS FONT ──────────────────────────────────────────────────
//  Ils CONSTRUISENT les documents. Un test de source dirait que `tableSection`
//  est appelé ; il ne dirait pas si le résultat sort. Ici, si le PDF ne se
//  génère pas, le test échoue.
// ════════════════════════════════════════════════════════════════════════════

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:epilote/data/models/student_tutor_model.dart';
import 'package:epilote/data/models/subject_model.dart';
import 'package:epilote/features/students/providers/annuaire_provider.dart';
import 'package:epilote/features/students/providers/documents_provider.dart';
import 'package:epilote/features/students/providers/students_registry_provider.dart';
import 'package:epilote/features/students/providers/transfers_provider.dart';
import 'package:epilote/features/students/services/annuaire_pdf_service.dart';
import 'package:epilote/features/students/services/documents_pdf_service.dart';
import 'package:epilote/features/students/services/transfers_pdf_service.dart';
import 'package:epilote/features/structure/services/subjects_pdf_service.dart';

/// Assez pour dépasser franchement les 28 lignes d'un bloc portrait, sans
/// allonger la suite inutilement. La réalité va bien au-delà : l'école la plus
/// chargée du parc porte 868 élèves.
const int _kLignes = 120;

/// Des noms longs, comme au Congo — c'est la largeur réelle des colonnes qui
/// décide si une ligne tient, pas le nombre de caractères d'un jeu d'essai.
String _nom(int i) => 'MAKOSSO-NGOMA BOUKAKA $i';

SubjectModel _matiere(int i) => SubjectModel(
      id: 'm$i',
      groupId: 'g1',
      name: 'Sciences de la Vie et de la Terre $i',
      slug: 'svt-$i',
      coefficient: 1 + (i % 5),
      isActive: true,
      classCount: i % 9,
      niveaux: const ['6e', '5e', '4e', '3e'],
    );

StudentRow _eleve(int i) => StudentRow(
      id: 'e$i',
      firstName: 'Jean-Baptiste',
      lastName: _nom(i),
      matricule: 'MAT-${i.toString().padLeft(5, '0')}',
      ine: '2026${i.toString().padLeft(8, '0')}',
      gender: i.isEven ? 'M' : 'F',
      dateOfBirth: DateTime(2010, 1 + (i % 12), 1 + (i % 28)),
      placeOfBirth: 'Pointe-Noire',
      nationality: 'Congolaise',
      photoUrl: null,
      isBoarder: i % 11 == 0,
      hasScholarship: i % 13 == 0,
      hasSocialAid: false,
      isAffecte: i % 3 == 0,
      enrollmentId: 'i$i',
      enrollmentStatus: 'active',
      classId: 'c${i % 7}',
      className: '6ème ${String.fromCharCode(65 + (i % 7))}',
      cycleCode: 'college',
      levelCode: '6e',
      levelOrder: 6,
      filiereLabel: null,
      hasPrimaryTutor: i % 5 != 0,
    );

StudentTutorModel _tuteur(int i) => StudentTutorModel(
      id: 't$i',
      studentId: 'e$i',
      groupId: 'g1',
      firstName: 'Marie-Claire',
      lastName: _nom(i),
      relationship: i.isEven ? 'mere' : 'pere',
      phonePrimary: '+242 06 000 00 ${i % 100}',
      phoneSecondary: '+242 05 111 11 ${i % 100}',
      email: 'tuteur$i@example.cg',
      profession: 'Commerçante au marché Total',
      address: 'Quartier Mpaka, arrondissement 5',
      isPrimaryContact: true,
      hasAppAccess: false,
      isEmergencyContact: i % 4 == 0,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

DocRow _piece(int i, String type) => DocRow(
      id: 'd$i$type',
      studentId: 'e$i',
      firstName: 'Jean-Baptiste',
      lastName: _nom(i),
      matricule: 'MAT-${i.toString().padLeft(5, '0')}',
      className: '6ème A',
      cycleCode: 'college',
      levelOrder: 6,
      documentType: type,
      documentName: 'Pièce $type',
      fileUrl: 'file://$i',
      isVerified: i.isEven,
      expiryDate: null,
      createdAt: DateTime(2026, 2, 1),
    );

TransferRow _transfert(int i, String statut) => TransferRow(
      id: 'tr$i$statut',
      studentId: 'e$i',
      firstName: 'Jean-Baptiste',
      lastName: _nom(i),
      matricule: 'MAT-${i.toString().padLeft(5, '0')}',
      gender: i.isEven ? 'M' : 'F',
      className: '6ème A',
      cycleCode: 'college',
      levelCode: '6e',
      levelOrder: 6,
      enrollmentId: 'i$i',
      toSchoolName: 'Lycée Technique de Pointe-Noire',
      transferDate: DateTime(2026, 3, 1 + (i % 28)),
      reason: 'Déménagement de la famille vers Brazzaville',
      status: statut,
      approvedAt: DateTime(2026, 3, 15),
      createdAt: DateTime(2026, 3, 1),
    );

void main() {
  setUpAll(() async => initializeDateFormatting('fr'));
  // Les polices officielles sont chargées depuis les assets : sans le binding,
  // `loadFonts()` échoue avant même d'atteindre la pagination.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('🩸 Les quatre documents dont la longueur suit les données', () {
    test('le référentiel des matières sort à 95 matières', () async {
      // 95 est le nombre réel en base. Un référentiel de groupe ne se réduit
      // pas : il grandit à chaque filière ouverte.
      final bytes = await SubjectsPdfService.buildPdf(
        rows: [for (var i = 0; i < 95; i++) _matiere(i)],
        schoolName: 'Collège d\'Enseignement Général de Mpaka',
        yearLabel: '2025-2026',
      );
      expect(bytes.lengthInBytes, greaterThan(1000));
    });

    test('le répertoire des familles sort à $_kLignes familles', () async {
      // C'est la liste qu'on ouvre quand un enfant ne rentre pas le soir.
      // Qu'elle refuse de se générer le jour où l'école dépasse trente
      // familles n'est pas un défaut d'affichage.
      final bytes = await AnnuairePdfService.buildPdf(
        families: [
          for (var i = 0; i < _kLignes; i++)
            FamilyRow(student: _eleve(i), tutors: [_tuteur(i)]),
        ],
        schoolName: 'Collège d\'Enseignement Général de Mpaka',
        yearLabel: '2025-2026',
      );
      expect(bytes.lengthInBytes, greaterThan(1000));
    });

    test('le registre de conformité sort à $_kLignes dossiers', () async {
      final bytes = await DocumentsPdfService.buildPdf(
        dossiers: [
          for (var i = 0; i < _kLignes; i++)
            StudentDossier(
              student: _eleve(i),
              docs: [
                _piece(i, 'acte_naissance'),
                if (i.isEven) _piece(i, 'certificat_scolarite'),
              ],
            ),
        ],
        schoolName: 'Collège d\'Enseignement Général de Mpaka',
        yearLabel: '2025-2026',
      );
      expect(bytes.lengthInBytes, greaterThan(1000));
    });

    test('l\'état des transferts sort à $_kLignes transferts', () async {
      // Groupé par statut : c'est le plus GROS groupe qui décide, pas le total.
      final bytes = await TransfersPdfService.buildPdf(
        rows: [
          for (var i = 0; i < _kLignes; i++)
            _transfert(i, i % 5 == 0 ? 'pending' : 'approved'),
        ],
        schoolName: 'Collège d\'Enseignement Général de Mpaka',
        yearLabel: '2025-2026',
      );
      expect(bytes.lengthInBytes, greaterThan(1000));
    });
  });

  group('🩸 Le cliquet — pour attraper le NEUVIÈME', () {
    // Huit documents ont été trouvés cassés de cette façon, en deux vagues,
    // tous les deux par accident. Ce compteur ferme la porte : il ne dit pas
    // qu'un `frame(table())` est interdit — vingt-deux sont parfaitement
    // légitimes — il dit qu'on n'en ajoute pas un de plus SANS SE POSER LA
    // QUESTION.
    //
    // La question est unique : **le nombre de lignes est-il fixe, ou suit-il
    // les données ?**
    //   · fixe (une fiche, deux tuteurs, quatre postes) → `frame(table())` ;
    //   · variable (une liste d'élèves, d'agents, de transferts)
    //     → `tableSection`, TOUJOURS.
    //
    // Pour faire baisser ce nombre, convertir. Pour le monter, il faut une
    // bonne raison — et elle s'écrit ici.
    const int kSitesBornes = 22;

    test('aucun nouveau `frame(table())` non compté', () {
      final frame = RegExp(r'OfficialPdfKit\.frame\(');
      final table = RegExp(r'OfficialPdfKit\.table\(');
      var n = 0;
      final parFichier = <String, int>{};
      for (final f in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final src = f.readAsStringSync().replaceAll('\r\n', '\n');
        if (!src.contains('OfficialPdfKit')) continue;
        for (final m in frame.allMatches(src)) {
          final fenetre = src.substring(
              m.start, (m.start + 1600).clamp(0, src.length));
          if (table.hasMatch(fenetre)) {
            n++;
            final rel = f.path.replaceAll(r'\', '/').split('lib/').last;
            parFichier[rel] = (parFichier[rel] ?? 0) + 1;
          }
        }
      }
      expect(n, lessThanOrEqualTo(kSitesBornes),
          reason: 'Un `frame(table())` de plus qu’au dernier recensement. '
              'S’il porte une liste dont la longueur suit les données, il ne '
              'produira AUCUN document passé ~28 lignes — et personne ne le '
              'verra sur un jeu de démonstration.\n\n'
              '${parFichier.entries.map((e) => "  ${e.value}  ${e.key}").join("\n")}');
    });

    test('les huit documents réparés emploient bien `tableSection`', () {
      for (final chemin in const [
        'lib/features/structure/services/subjects_pdf_service.dart',
        'lib/features/students/services/annuaire_pdf_service.dart',
        'lib/features/students/services/documents_pdf_service.dart',
        'lib/features/students/services/transfers_pdf_service.dart',
        'lib/features/examens/services/exam_export_service.dart',
        'lib/features/staff/services/personnel_export_service.dart',
        'lib/features/staff/services/payroll_pdf_service.dart',
        'lib/features/stages/services/stage_export_service.dart',
      ]) {
        final f = File(chemin);
        expect(f.existsSync(), isTrue, reason: '$chemin introuvable.');
        expect(f.readAsStringSync().contains('OfficialPdfKit.tableSection('),
            isTrue,
            reason: '$chemin est revenu à `frame(table())`.');
      }
    });
  });

  group('Le cas d\'une seule ligne reste servi', () {
    // Une école qui n'a qu'un transfert doit obtenir un document, pas une page
    // vide : la découpe ne doit pas casser le petit cas en réparant le grand.
    test('un document minuscule sort quand même', () async {
      final bytes = await TransfersPdfService.buildPdf(
        rows: [_transfert(1, 'approved')],
        schoolName: 'École primaire de Loandjili',
        yearLabel: '2025-2026',
      );
      expect(bytes.lengthInBytes, greaterThan(1000));
    });

    test('un document vide sort quand même', () async {
      final bytes = await SubjectsPdfService.buildPdf(
        rows: const [],
        schoolName: 'École primaire de Loandjili',
        yearLabel: '2025-2026',
      );
      expect(bytes.lengthInBytes, greaterThan(1000));
    });
  });
}
