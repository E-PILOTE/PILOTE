import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  INFIRMERIE — CE QUE L'ÉCRAN DOIT DIRE, ET QUAND
//
//  ── D1. L'ALLERGIE CONNUE N'ÉTAIT MONTRÉE NULLE PART (2026-08-28) ──────────
//  Le formulaire de passage demande la MÉDICATION administrée, en texte libre.
//  `students.allergies` se saisit à l'inscription et descend déjà sur le poste
//  — la colonne est déclarée dans le schéma PowerSync local. L'écran ne la
//  lisait jamais.
//
//  L'application connaissait donc l'allergie de l'enfant, l'avait sous la main,
//  hors ligne, et se taisait au moment exact où quelqu'un allait lui donner un
//  médicament. Une infirmerie scolaire n'a pas de second système pour vérifier.
//
//  ⚠️ ET LE CONTRAIRE SERAIT PIRE. Deux élèves sur 9 106 ont une allergie
//  renseignée : afficher « aucune allergie » pour les 9 104 autres inventerait
//  une information qu'on n'a pas. L'écran dit « aucune allergie RENSEIGNÉE »,
//  ce qui est vrai, et ne rassure personne à tort.
//
//  ── D2. LE JOURNAL N'AVAIT PAS D'ANNÉE ────────────────────────────────────
//  Seule table du domaine élève sans `academic_year_id` (migration 0132). Les
//  compteurs cumulaient toutes les promotions depuis l'ouverture, et la classe
//  d'un passage ne pouvait pas être celle du jour des faits.
//
//  ── D3. « SUIVI REQUIS » NE REDESCENDAIT JAMAIS ───────────────────────────
//  L'infirmier cochait la case pour revoir l'enfant ; rien ne permettait de
//  dire que c'était fait. Le KPI montait indéfiniment, et un suivi réellement
//  en attente se noyait dans ceux déjà traités. Un rappel qu'on ne peut pas
//  éteindre cesse d'être lu.
// ════════════════════════════════════════════════════════════════════════════

const _kProvider = 'lib/features/vie_scolaire/providers/infirmerie_provider.dart';
const _kForm = 'lib/features/vie_scolaire/screens/infirmerie_form.dart';
const _kScreen = 'lib/features/vie_scolaire/screens/infirmerie_screen.dart';
const _kCards = 'lib/features/vie_scolaire/screens/infirmerie_cards.dart';

String _lire(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) fail('$chemin introuvable — tourner depuis `epilote/`.');
  return f.readAsStringSync();
}

void main() {
  group('L\'allergie connue est montrée à qui donne le médicament', () {
    test('le formulaire lit l\'alerte médicale', () {
      final form = _lire(_kForm);
      expect(form.contains('alerteMedicaleProvider'), isTrue,
          reason: 'Le formulaire demande la médication : il doit d\'abord dire '
              'ce qu\'on sait de l\'enfant.');
      expect(form.contains('_AlerteMedicale(studentId:'), isTrue,
          reason: 'L\'alerte doit être posée dans l\'arbre, pas seulement '
              'importée.');
    });

    test('l\'alerte suit le choix de l\'élève, pas l\'ouverture du dialogue',
        () {
      // Affichée à vide, elle serait un cadre décoratif ; c'est le choix de
      // l'élève qui doit la faire apparaître, et la faire changer.
      final form = _lire(_kForm);
      expect(form.contains('if (_studentId != null)'), isTrue);
    });

    test('« aucune allergie renseignée » n\'est pas « aucune allergie »', () {
      final form = _lire(_kForm);
      expect(form.contains('Aucune allergie renseignée'), isTrue,
          reason: 'Le dossier est vide pour la quasi-totalité des élèves : '
              'annoncer l\'absence d\'allergie serait inventer une information '
              'qu\'on n\'a pas.');
      // Le libellé rassurant ne doit pas réapparaître au fil des retouches.
      expect(RegExp(r"'Aucune allergie'|'Pas d.allergie'").hasMatch(form),
          isFalse);
    });

    test('le médical ne passe pas par le modèle partagé des trois modules', () {
      // `VsStudent` sert aussi à Discipline et Bibliothèque : y ajouter les
      // allergies les ferait porter du médical sans raison.
      final vs = _lire('lib/features/vie_scolaire/providers/'
          'vs_students_provider.dart');
      expect(vs.contains('allergies'), isFalse);
      expect(vs.contains('blood_group'), isFalse);
    });
  });

  group('Le journal est borné à l\'année scolaire', () {
    test('la lecture filtre sur l\'année active', () {
      final src = _lire(_kProvider);
      expect(src.contains('v.academic_year_id = ?'), isTrue,
          reason: 'Sans ce filtre, les compteurs cumulent les promotions.');
      expect(src.contains('activeYearIdProvider'), isTrue);
    });

    test('l\'écriture pose l\'année', () {
      final src = _lire(_kProvider);
      expect(src.contains('required String academicYearId'), isTrue);
      expect(src.contains('academic_year_id, created_at, updated_at'), isTrue,
          reason: 'La colonne doit figurer dans l\'INSERT, sinon la ligne naît '
              'sans année et disparaît de sa propre liste.');
    });

    test('la classe affichée est celle de l\'année du passage', () {
      final src = _lire(_kProvider);
      expect(src.contains('ce.academic_year_id = v.academic_year_id'), isTrue,
          reason: 'La classe DES FAITS, pas celle d\'aujourd\'hui.');
      // Une seule ligne par passage : sans LIMIT 1, une reconduction pouvait
      // faire compter le même passage deux fois.
      expect(src.contains('LIMIT 1)'), isTrue);
    });
  });

  group('Un suivi requis peut être clos', () {
    test('la mutation existe et retombe la case', () {
      final src = _lire(_kProvider);
      expect(src.contains('Future<void> cloreSuivi('), isTrue);
      expect(src.contains('follow_up_required = 0'), isTrue);
    });

    test('clore n\'efface aucune note déjà écrite', () {
      final src = _lire(_kProvider);
      expect(src.contains('follow_up_notes ||'), isTrue,
          reason: 'Ce qui a été fait s\'AJOUTE aux notes ; un suivi clos ne '
              'doit pas effacer ce qu\'on avait noté à l\'accueil.');
    });

    test('l\'écran l\'expose, et le filtre permet d\'atteindre la liste', () {
      final ecran = _lire(_kScreen);
      expect(ecran.contains('cloreSuivi('), isTrue);
      expect(ecran.contains('_suiviSeul'), isTrue,
          reason: 'Un KPI qu\'aucun filtre n\'ouvre annonce un travail qu\'on '
              'ne peut pas atteindre.');
      expect(_lire(_kCards).contains("value: 'suivi'"), isTrue);
    });

    test('clore est une modification, pas une suppression', () {
      // Le droit qui l'ouvre doit être `update` : réserver la clôture à
      // `delete` la donnerait à trop peu de monde, l'ouvrir sans droit du tout
      // la donnerait à tous.
      final cartes = _lire(_kCards);
      expect(cartes.contains('canEdit && visit.followUpRequired'), isTrue);
    });
  });
}
