import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  MILLE LIGNES NE SONT PAS LE TOTAL
//
//  ── LE DÉFAUT, ET IL N'EST PAS THÉORIQUE ───────────────────────────────────
//  PostgREST plafonne une réponse à 1 000 lignes. Il ne renvoie ni erreur ni
//  avertissement : la liste est simplement plus courte. Un code qui ramène des
//  lignes pour les compter, les ventiler ou les additionner obtient donc un
//  chiffre juste tant que la base est petite, puis un chiffre FAUX — et faux
//  d'autant plus que la plateforme grandit. Le pire est qu'il tombe rond :
//  « 1 000 élèves » a l'air d'une mesure.
//
//  ── CE QUI A ÉTÉ MESURÉ LE 2026-09-09, EN PRODUCTION ───────────────────────
//  44 écoles seulement, sur les 1 000+ visées :
//    • le plus gros groupe compte  3 781 élèves  → les rapports du réseau en
//      annonçaient 1 000, soit 26 % du réel ;
//    • ce même groupe a            3 461 paiements → le recouvrement affiché
//      valait moins d'un tiers de ce qui est encaissé ;
//    • la carte territoriale répartissait 1 000 élèves sur les seules écoles
//      que la première page contenait.
//  Ces chiffres partent en PDF signé, en réunion, en arbitrage budgétaire.
//
//  ── LES QUATRE RÉPONSES LÉGITIMES ──────────────────────────────────────────
//   1. `fetchAllRows(...)`      — il faut les lignes (ventilation) : on pagine.
//   2. `.count(CountOption.exact)` — il ne faut qu'un compte : une requête,
//                                 aucune ligne transférée. Presque toujours ça.
//   3. `.limit(n)` / `.range(a, b)` — la liste est VOLONTAIREMENT bornée, et
//                                 l'écran dit qu'elle l'est (cf. la recherche
//                                 d'élèves du réseau, qui affiche « tronqué »).
//   4. `.single()` / `.maybeSingle()` — une seule ligne attendue.
//
//  Ne rien écrire n'est pas une cinquième réponse : c'est le défaut.
//
//  ── PORTÉE ─────────────────────────────────────────────────────────────────
//  Uniquement les espaces EN LIGNE (`super_admin`, `admin_groupe`, tutelle,
//  audit, profil). L'espace école lit son SQLite local par `db.watch` : aucun
//  plafond PostgREST ne s'y applique.
// ════════════════════════════════════════════════════════════════════════════

/// Les espaces qui parlent à PostgREST.
const _espacesEnLigne = [
  'lib/features/super_admin',
  'lib/features/admin_groupe',
  'lib/features/tutelle',
  'lib/features/audit',
  'lib/features/profil',
];

/// Tables dont le nombre de lignes croît avec l'usage de la plateforme.
///
/// Une table de RÉFÉRENCE (modules, plans, cycles, départements…) n'y figure
/// pas : son contenu est borné par construction, et exiger une pagination
/// pour lire douze départements serait du bruit.
const _tablesDeVolume = {
  'students',
  'class_enrollments',
  'student_payments',
  'student_documents',
  'student_tutors',
  'issued_documents',
  'grades',
  'bulletins',
  'bulletin_subject_lines',
  'evaluations',
  'attendance_records',
  'attendance_entries',
  'exam_candidates',
  'transmissions',
  'internships',
  'audit_logs',
  'schools',
  'school_groups',
  'group_invoices',
  'support_tickets',
  'profiles',
  'classes',
  'staff_members',
  'payroll',
};

/// Ce qui, dans la même instruction, prouve que la lecture est bornée.
const _preuvesDeBorne = [
  'fetchAllRows',
  '.limit(',
  '.range(',
  '.count(',
  'CountOption',
  '.single(',
  '.maybeSingle(',
];

/// Lectures laissées sans borne EXPRÈS, chacune avec sa raison.
///
/// Une entrée ici est une décision assumée, pas un oubli. Le format est
/// `fichier.dart:table`.
const Map<String, String> _dispenses = {
  // Une seule ligne d'élève : un enfant a au plus une inscription par année,
  // donc une poignée sur toute sa scolarité.
  'student_dossier_provider.dart:class_enrollments':
      "Le dossier d'UN élève : au plus une inscription par année scolaire.",
  // `.inFilter('id', <liste>)` : la borne est la liste d'identifiants, qui a
  // elle-même été bornée en amont (facettes plafonnées, top 5). Ajouter une
  // pagination ne changerait rien — et une liste de plus de 1 000 UUID
  // dépasserait de toute façon la longueur d'URL bien avant le plafond.
  'audit_data.dart:schools': 'Résolution de noms sur une liste déjà bornée.',
  'audit_data.dart:profiles': 'Résolution de noms sur une liste déjà bornée.',
  // La courbe des 30 jours a quitté `audit_data.dart` le 2026-09-09 ; ses deux
  // résolutions de noms sont bornées de la même façon (top 5 d'acteurs, top 5
  // d'écoles).
  'audit_timeline.dart:schools': "Top 5 : la liste d'identifiants borne déjà.",
  'audit_timeline.dart:profiles': "Top 5 : la liste d'identifiants borne déjà.",
};

List<File> _dartsSous(String chemin) {
  final d = Directory(chemin);
  if (!d.existsSync()) fail('$chemin introuvable — tourner depuis `epilote/`.');
  return d
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
}

/// Bornes de l'instruction Dart qui contient [index].
///
/// On remonte au dernier `;`, `{` ou `}` qui précède — c'est-à-dire au début
/// réel de l'instruction, et pas à une fenêtre de caractères arbitraire :
/// sinon un `.limit()` voisin couvrirait la requête d'à côté.
(int, int) _instruction(String src, int index) {
  var debut = index;
  while (debut > 0 && !';{}'.contains(src[debut - 1])) {
    debut--;
  }
  var fin = src.indexOf(';', index);
  if (fin < 0) fin = src.length;
  return (debut, fin + 1);
}

int _ligneDe(String src, int index) =>
    '\n'.allMatches(src.substring(0, index)).length + 1;

void main() {
  group('Aucune lecture en ligne ne prend le plafond pour le total', () {
    test('le relevé aboutit (le test ne passe pas à vide)', () {
      var vues = 0;
      for (final racine in _espacesEnLigne) {
        for (final f in _dartsSous(racine)) {
          vues += RegExp(r"\.from\('(\w+)'\)")
              .allMatches(f.readAsStringSync())
              .length;
        }
      }
      expect(vues, greaterThan(100),
          reason: 'Moins de 100 appels `.from(...)` relevés dans les espaces '
              'en ligne : la lecture des sources a échoué et ce test '
              'passerait à vide — ce qui est pire que rouge.');
    });

    test('toute lecture d\'une table de volume est bornée', () {
      final nues = <String>[];
      for (final racine in _espacesEnLigne) {
        for (final f in _dartsSous(racine)) {
          final src = f.readAsStringSync().replaceAll('\r\n', '\n');
          final nomFichier = f.uri.pathSegments.last;
          for (final m in RegExp(r"\.from\('(\w+)'\)").allMatches(src)) {
            final table = m.group(1)!;
            if (!_tablesDeVolume.contains(table)) continue;
            if (_dispenses.containsKey('$nomFichier:$table')) continue;
            final (debut, fin) = _instruction(src, m.start);
            final instruction = src.substring(debut, fin);
            // `.from(...)` sans `.select(...)` est une ÉCRITURE
            // (insert/update/delete/upsert) : aucun plafond ne s'y applique.
            if (!instruction.contains('.select(')) continue;
            var borne = _preuvesDeBorne.any((p) => instruction.contains(p));
            // Motif courant : le constructeur de requête est rangé dans une
            // variable, enrichi de filtres conditionnels, puis borné à
            // l'exécution (`final rows = await q.order(...).limit(n)`). La
            // borne est réelle, elle est juste écrite plus loin — on suit donc
            // la variable dans la suite du bloc.
            if (!borne) {
              final nom = RegExp(r'(?:final|var|dynamic)\s+(\w+)\s*=')
                  .firstMatch(instruction)
                  ?.group(1);
              if (nom != null) {
                final suite =
                    src.substring(fin, (fin + 3000).clamp(0, src.length));
                borne = RegExp(
                      '\\b$nom\\b[^;]{0,900}?'
                      r'(\.limit\(|\.range\(|\.count\(|CountOption)',
                      dotAll: true,
                    ).hasMatch(suite) ||
                    RegExp('fetchAllRows[^;]{0,300}?\\b$nom\\b', dotAll: true)
                        .hasMatch(suite);
              }
            }
            if (!borne) {
              nues.add('$nomFichier:${_ligneDe(src, m.start)}  → $table');
            }
          }
        }
      }
      expect(
        nues,
        isEmpty,
        reason: 'Ces lectures ramènent des lignes d\'une table qui grossit, '
            'sans pagination ni borne :\n  ${nues.join('\n  ')}\n\n'
            'PostgREST tronquera la réponse à 1 000 lignes SANS le dire, et le '
            'chiffre affiché sera le plafond, pas la mesure.\n'
            'Quatre issues : `fetchAllRows(...)` si la ventilation exige les '
            'lignes ; `.count(CountOption.exact)` si un compte suffit ; '
            '`.limit(n)` si la liste est volontairement bornée ET que l\'écran '
            'le dit ; `.maybeSingle()` si une seule ligne est attendue.',
      );
    });

    test('toute dispense vise une lecture qui existe encore', () {
      final vivantes = <String>{};
      for (final racine in _espacesEnLigne) {
        for (final f in _dartsSous(racine)) {
          final src = f.readAsStringSync();
          final nomFichier = f.uri.pathSegments.last;
          for (final m in RegExp(r"\.from\('(\w+)'\)").allMatches(src)) {
            vivantes.add('$nomFichier:${m.group(1)}');
          }
        }
      }
      final orphelines =
          _dispenses.keys.where((c) => !vivantes.contains(c)).toList();
      expect(orphelines, isEmpty,
          reason: 'Dispenses accordées à des lectures disparues : '
              '${orphelines.join(', ')}. Une dispense qui survit à son code '
              'couvrira un jour une lecture homonyme qui, elle, en aurait '
              'besoin.');
    });
  });
}
