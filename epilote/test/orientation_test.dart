import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  ORIENTATION — CE QUI SE COMPTE, ET CE QUI S'AGRÈGE
//
//  ── D1. UNE ORIENTATION EN TEXTE LIBRE NE S'AGRÈGE PAS (2026-08-28) ────────
//  « Niveau cible » et « Filière cible » étaient deux `TextField`. Sur mille
//  écoles, « Série C », « serie C », « C » et « Scientifique » deviennent
//  quatre orientations distinctes : le MEPSA ne peut pas compter combien
//  d'élèves partent vers les séries scientifiques — ce qui est précisément la
//  raison d'être de ce module au niveau national.
//
//  Le référentiel existait déjà et descendait déjà sur le poste :
//  `education_levels` et `education_programs`. On y écrit le CODE ; l'écran en
//  affiche le nom, et rend le code brut si la filière a quitté le référentiel
//  depuis — une orientation ancienne ne doit pas devenir illisible.
//
//  ── D2. LE MÊME ÉLÈVE POUVAIT APPARAÎTRE DEUX FOIS ────────────────────────
//  `saveOrientation` décidait insert/update sur un instantané du flux : ouvrir
//  deux fois la fiche créait DEUX orientations pour le même élève et le même
//  trimestre. Aucune contrainte en base ne l'attrape — donc rien ne prévient :
//  la liste montrait l'enfant deux fois, avec deux recommandations qui
//  pouvaient se contredire, et la couverture les additionnait.
//
//  ── D3. UN COMPTEUR QUI NE DESCEND JAMAIS ────────────────────────────────
//  Le KPI « À orienter » valait `effectif - orientés` : une 6ᵉ entière, en
//  permanence, alors que l'orientation ne concerne que les fins de cycle. Il
//  masquait la seule liste de travail réelle — les élèves que le CONSEIL a
//  déclarés « réorienté » et dont personne n'a encore dit vers quoi.
//
//  ── D4. DEUX MODULES QUI NE SE PARLAIENT PAS ─────────────────────────────
//  Le verdict `reoriente` écarte VOLONTAIREMENT l'élève de la réinscription en
//  lot (« la classe d'accueil se choisit dossier par dossier »). Mais aucun
//  dossier ne s'ouvrait : le conseil les considérait traités, l'Orientation
//  n'en avait jamais entendu parler. Le module les nomme maintenant — il ne
//  décide rien à leur place.
// ════════════════════════════════════════════════════════════════════════════

const _kProvider =
    'lib/features/vie_scolaire/providers/orientation_provider.dart';
const _kSheet = 'lib/features/vie_scolaire/screens/orientation_sheet.dart';
const _kScreen = 'lib/features/vie_scolaire/screens/orientation_screen.dart';

String _lire(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) fail('$chemin introuvable — tourner depuis `epilote/`.');
  return f.readAsStringSync().replaceAll('\r\n', '\n');
}

void main() {
  group('La cible se prend au référentiel, jamais au clavier', () {
    test('la fiche propose des listes, pas des champs libres', () {
      final sheet = _lire(_kSheet);
      expect(sheet.contains('niveauxCiblesProvider'), isTrue);
      expect(sheet.contains('filieresCiblesProvider'), isTrue);
      // Les deux contrôleurs de texte des cibles ont disparu.
      expect(sheet.contains('_level = TextEditingController'), isFalse);
      expect(sheet.contains('_filiere = TextEditingController'), isFalse);
      expect(sheet.contains('DropdownButtonFormField'), isTrue);
    });

    test('les référentiels lus sont ceux qui existent hors ligne', () {
      final src = _lire(_kProvider);
      expect(src.contains('FROM education_levels'), isTrue);
      expect(src.contains('FROM education_programs'), isTrue);
      // Tous deux déclarés dans le schéma local : sans quoi la liste serait
      // vide sur un poste hors ligne, et le champ inutilisable.
      final schema = _lire('lib/services/powersync/powersync_schema.dart');
      expect(schema.contains("Table('education_levels'"), isTrue);
      expect(schema.contains("Table('education_programs'"), isTrue);
      expect(schema.contains("Table('education_cycles'"), isTrue);
    });

    test('un code sorti du référentiel reste lisible', () {
      // Une filière retirée ne doit ni faire planter la liste déroulante, ni
      // effacer l'orientation d'un élève déjà décidée.
      expect(_lire(_kProvider).contains('String nomDeCible('), isTrue);
      expect(_lire(_kSheet).contains('hors référentiel'), isTrue);
      expect(_lire(_kScreen).contains('nomDeCible('), isTrue);
    });
  });

  group('Un élève, une fiche', () {
    test('l\'écriture relit la clé métier et déduit l\'identifiant', () {
      final src = _lire(_kProvider);
      // Le prefixe d'identite porte le nom SINGULIER de la table, comme
      // tous les autres (`attendance_record`, `canteen_record`, `payroll`).
      // Ecrit `'orientation'`, il entrait en collision avec le slug du
      // module et faisait echouer le garde « un slug declare une seule
      // fois » -- qui avait raison : deux choses differentes ne doivent
      // pas porter le meme litteral dans le meme dossier.
      expect(src.contains("idDeterministe('student_orientation'"), isTrue,
          reason: 'Deux postes hors ligne doivent écrire la MÊME ligne.');
      expect(src.contains('SELECT id FROM student_orientations WHERE student_id = ?'),
          isTrue,
          reason: 'Et un double appui ne doit pas créer une seconde fiche.');
      expect(src.contains('.v4()'), isFalse);
    });

    test('la liste d\'une classe rend UNE ligne par élève', () {
      final src = _lire(_kProvider);
      expect(src.contains('LEFT JOIN student_orientations o ON o.id = ('), isTrue,
          reason: 'La jointure directe multipliait l\'élève par ses fiches.');
      expect(src.contains('LIMIT 1)'), isTrue);
    });

    test('l\'année est enfin lue', () {
      // `academic_year_id` est NOT NULL et écrite depuis toujours ; aucune
      // requête ne la filtrait.
      final src = _lire(_kProvider);
      expect(src.contains('o.academic_year_id = ?'), isTrue);
      expect(src.contains('o2.academic_year_id = ?'), isTrue);
      expect(src.contains('activeYearIdProvider'), isTrue);
    });

    test('la couverture compte des élèves, pas des lignes', () {
      expect(_lire(_kProvider).contains('SELECT DISTINCT ce.class_id'), isTrue);
    });
  });

  group('Le conseil et l\'orientation se parlent', () {
    test('les réorientés sans fiche sont comptés', () {
      final src = _lire(_kProvider);
      expect(src.contains("ce.promotion_decision = 'reoriente'"), isTrue);
      expect(src.contains('NOT EXISTS ('), isTrue,
          reason: 'Ceux qui ont déjà une fiche ne sont plus en attente.');
      expect(src.contains('final int aOrienter'), isTrue);
    });

    test('l\'écran le montre, et le compteur inutile a disparu', () {
      final ecran = _lire(_kScreen);
      expect(ecran.contains('Réorientés sans fiche'), isTrue);
      expect(ecran.contains(r"'${ov.students - ov.oriented}'"), isFalse,
          reason: 'Un compteur qui ne descend jamais n\'est pas une liste de '
              'travail.');
      expect(ecran.contains('Réorienté par le conseil'), isTrue,
          reason: 'Et la ligne de l\'élève doit le dire aussi.');
    });
  });

  group('Orienter pour la première fois, c\'est insérer', () {
    test('l\'écran exige `create` autant qu\'`update`', () {
      // La RLS (0131) réserve l'INSERT à `create` : un profil doté du seul
      // `update` ouvrirait la fiche et recevrait un 42501 — code fatal, lot
      // PowerSync entier jeté.
      final ecran = _lire(_kScreen);
      expect(ecran.contains("action: 'create'"), isTrue);
      expect(ecran.contains("action: 'update'"), isTrue);
    });
  });
}
