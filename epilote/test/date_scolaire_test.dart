import 'dart:io';

import 'package:epilote/core/utils/date_scolaire.dart';
import 'package:epilote/data/models/academic_year_model.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  UNE DATE DE FAIT SCOLAIRE TOMBE DANS L'ANNÉE SCOLAIRE
//
//  Vingt-trois tables portent `academic_year_id`. Quand la ligne porte l'année
//  ET une date, les deux doivent s'accorder — sinon le fait n'est pas seulement
//  mal saisi, il est mal CLASSÉ : toutes les requêtes filtrent par l'année, et
//  le rendent donc dans une année où sa date n'existe pas.
//
//  Relevé du 2026-08-28 : HUIT formulaires bornaient leur sélecteur sur
//  l'année CIVILE (`± 1`, `± 2`, et jusqu'à `2020 → 2100`), dans six domaines.
//  C'est la même faute que le sélecteur de vacances de l'onglet Calendrier,
//  trouvée trois jours plus tôt et corrigée seule.
//
//  `AdminDateField` (espace admin groupe) portait déjà la règle écrite noir sur
//  blanc : « rien ne justifie de pouvoir pointer une date hors de l'année
//  scolaire ». L'espace personnel ne l'avait jamais reçue.
// ════════════════════════════════════════════════════════════════════════════

/// Écrans dont la date part sur une ligne portant `academic_year_id`.
const _kFormulaires = <(String, String)>[
  ('lib/features/structure/screens/cahier_textes_form.dart', 'lesson_entries'),
  ('lib/features/evaluation/screens/notes_form.dart', 'evaluations'),
  ('lib/features/finance/screens/paiements_form.dart', 'student_payments'),
  ('lib/features/finance/screens/depenses_form.dart', 'expenses'),
  ('lib/features/students/screens/transferts_form.dart', 'student_transfers'),
  ('lib/features/vie_scolaire/screens/infirmerie_form.dart', 'infirmary_visits'),
  ('lib/features/vie_scolaire/screens/discipline_form.dart', 'discipline_incidents'),
  ('lib/features/vie_scolaire/screens/presences_screen.dart', 'attendance_records'),
  // Le formulaire des jours non ouvres a quitte `edt_calendar_tab.dart` le
  // 2026-09-04 (509 lignes -> deux pieces). L'onglet AFFICHE, le formulaire
  // ECRIT : c'est lui que cette sonde doit lire.
  ('lib/features/structure/screens/edt_calendar_holiday_form.dart',
      'school_holidays'),
  // ⚠️ Ajoutés le 2026-08-28, après coup : le premier relevé interrogeait une
  // LISTE DE TABLES ÉCRITE À LA MAIN, où `internships` ne figurait pas. Deux
  // formulaires de plus bornaient donc sur l'année civile. Une sonde ne prouve
  // que ce qu'elle interroge — la leçon de la journée, une fois de plus.
  ('lib/features/stages/widgets/stage_form_dialog.dart', 'internships'),
  ('lib/features/stages/widgets/stage_attestation_dialog.dart', 'internships'),
];

AcademicYearModel _annee({
  required DateTime debut,
  required DateTime fin,
}) =>
    AcademicYearModel(
      id: 'ay',
      groupId: 'g',
      label: '2025-2026',
      startDate: debut,
      endDate: fin,
      isCurrent: true,
      isLocked: false,
      createdAt: DateTime(2025, 6, 1),
      updatedAt: DateTime(2025, 6, 1),
    );

/// Lit un fichier **et les `part` qu'il déclare**.
///
/// ⚠️ Sans cela, découper un formulaire devenu trop long suffit à aveugler ce
/// garde : le sélecteur de date part dans le fichier de champs, la sonde ne
/// regarde plus que la moitié qui décide, et elle passe au vert sur un
/// formulaire qui bornerait de nouveau sur l'année civile.
///
/// C'est arrivé le 2026-08-30, en découpant `stage_form_dialog.dart` — et
/// c'est mot pour mot la leçon que l'en-tête de ce fichier énonce déjà : une
/// sonde ne prouve que ce qu'elle interroge.
String _lire(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) fail('$chemin introuvable — tourner depuis `epilote/`.');
  final src = f.readAsStringSync().replaceAll('\r\n', '\n');
  final dossier = chemin.substring(0, chemin.lastIndexOf('/') + 1);
  final parts = RegExp(r"^part\s+'([^']+)';", multiLine: true)
      .allMatches(src)
      .map((m) => m.group(1)!)
      .where((nom) => !nom.endsWith('.g.dart'));
  return [
    src,
    for (final nom in parts)
      if (File('$dossier$nom').existsSync())
        File('$dossier$nom').readAsStringSync(),
  ].join('\n');
}

void main() {
  final debut = DateTime(2025, 9, 1);
  final fin = DateTime(2026, 7, 15);

  group('Les bornes sont celles de l\'année, jamais celles du calendrier', () {
    test('une date hors année est ramenée dans l\'année', () {
      final b = bornesScolaires(_annee(debut: debut, fin: fin),
          souhaitee: DateTime(2027, 12, 31));
      expect(b, isNotNull);
      expect(b!.premiere, debut);
      expect(b.derniere, fin);
      expect(b.initiale, fin,
          reason: '`initialDate` hors [firstDate, lastDate] fait lever une '
              'assertion à `showDatePicker` : la ramener est obligatoire.');
    });

    test('une date d\'avant la rentrée est ramenée au premier jour', () {
      final b = bornesScolaires(_annee(debut: debut, fin: fin),
          souhaitee: DateTime(2025, 3, 15));
      expect(b!.initiale, debut);
    });

    test('le plafond existant n\'est jamais desserré', () {
      // Un paiement ne se constate pas d'avance : l'écran plafonnait déjà au
      // jour même. On AJOUTE la borne de l'année, on n'en retire aucune.
      final b = bornesScolaires(_annee(debut: debut, fin: fin),
          souhaitee: DateTime(2026, 5, 20), plafond: DateTime(2026, 3, 10));
      expect(b!.derniere, DateTime(2026, 3, 10));
      expect(b.initiale, DateTime(2026, 3, 10));
    });

    test('un plafond au-delà de la fin d\'année ne l\'étend pas', () {
      final b = bornesScolaires(_annee(debut: debut, fin: fin),
          souhaitee: fin, plafond: DateTime(2026, 12, 31));
      expect(b!.derniere, fin);
    });

    test('année inconnue : aucune borne inventée', () {
      // « Je ne sais pas » se traite comme « pas maintenant ». C'est le repli
      // silencieux — `année civile ± 1` — qui était le défaut.
      expect(bornesScolaires(null, souhaitee: DateTime(2026, 1, 1)), isNull);
    });

    test('année entièrement future sous plafond : rien n\'est choisissable', () {
      final b = bornesScolaires(_annee(debut: debut, fin: fin),
          souhaitee: debut, plafond: DateTime(2025, 6, 1));
      expect(b, isNull,
          reason: '`lastDate` antérieure à `firstDate` fait lever une '
              'assertion : mieux vaut le dire que planter.');
    });

    test('l\'heure est écartée — seul le jour compte', () {
      final b = bornesScolaires(
          _annee(debut: DateTime(2025, 9, 1, 8, 30), fin: fin),
          souhaitee: DateTime(2025, 9, 1, 23, 59));
      expect(b!.premiere, DateTime(2025, 9, 1));
      expect(b.initiale, DateTime(2025, 9, 1));
    });
  });

  group('Aucun formulaire ne borne plus sur l\'année civile', () {
    for (final (chemin, table) in _kFormulaires) {
      test('${chemin.split('/').last} → $table', () {
        final src = _lire(chemin);
        expect(src.contains('showDatePicker('), isFalse,
            reason: 'Ce formulaire écrit une date sur `$table`, qui porte '
                '`academic_year_id` : la date doit passer par '
                '`choisirDateScolaire`, seul endroit qui connaît les bornes '
                'de l\'année.');
        expect(
            src.contains('choisirDateScolaire(') ||
                src.contains('year.startDate'),
            isTrue);
      });
    }

    test('le sélecteur partagé refuse de deviner l\'année', () {
      final src = _lire('lib/core/utils/date_scolaire.dart');
      expect(src.contains('DateTime.now().year - 1'), isFalse);
      expect(src.contains('activeYearProvider'), isTrue);
    });
  });
}
