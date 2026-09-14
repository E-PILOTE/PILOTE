import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  UN RAPPORT INCOMPLET DOIT LE DIRE
//
//  ── CE QUI A ETE TROUVE (2026-09-05) ──────────────────────────────────────
//  Le provider des rapports du groupe faisait SEPT lectures, chacune enveloppee
//  dans un `catch (_) {}` : identite du groupe, annee scolaire, etablissements,
//  eleves, personnel, classes, paiements. Une requete qui echouait laissait
//  « 0 ecole », « 0 eleve », « 0 FCFA encaisse » — et cet ecran s'EXPORTE en
//  PDF pour un ministere. Un zero rond est d'autant plus credible qu'il est net.
//
//  Meme famille que les neuf lectures muettes du tableau de bord fondateur :
//  voir `zero_nest_pas_je_ne_sais_pas_test.dart`.
// ════════════════════════════════════════════════════════════════════════════

const _provider =
    'lib/features/admin_groupe/providers/admin_reports_provider.dart';
const _bandeau =
    'lib/features/admin_groupe/screens/rapports/rapports_mesures_manquantes.dart';
const _coquille =
    'lib/features/admin_groupe/screens/admin_reports_screen.dart';

String _lire(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) fail('Fichier introuvable : $chemin — sonde aveugle.');
  return f.readAsStringSync().replaceAll('\r\n', '\n');
}

String _sansCommentaires(String source) => source
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  group('Les sept lectures ne sont plus muettes', () {
    test('plus un seul `catch (_) {}`', () {
      final src = _sansCommentaires(_lire(_provider));
      expect(src.contains('catch (_) {}'), isFalse);
    });

    test('chaque echec est nomme et trace', () {
      final src = _sansCommentaires(_lire(_provider));
      expect('manquantes.note('.allMatches(src).length, 7,
          reason: 'Une lecture a ete ajoutee ou retiree sans dire ce qu’elle '
              'devient quand elle echoue.');
    });

    test('les echecs remontent jusqu’au modele affiche', () {
      final src = _sansCommentaires(_lire(_provider));
      expect(src.contains('mesuresManquantes: manquantes.cles'), isTrue);
      expect(src.contains('mesuresManquantes: s.mesuresManquantes'), isTrue,
          reason: 'Collectes dans le snapshot mais jamais passes au rapport.');
    });

    test('chaque cle a un libelle lisible', () {
      final src = _sansCommentaires(_lire(_provider));
      for (final cle in ['groupe', 'anneeScolaire', 'ecoles', 'eleves',
                         'personnel', 'classes', 'paiements']) {
        expect(src.contains('static const $cle ='), isTrue,
            reason: 'Mesure « $cle » absente du vocabulaire.');
      }
    });
  });

  group('L’ecran le dit avant les chiffres', () {
    test('le bandeau precede les sections', () {
      final src = _sansCommentaires(_lire(_coquille));
      final bandeau = src.indexOf('_MesuresManquantesRapport(data: data)');
      final sections = src.indexOf('_SectionTabs(');
      expect(bandeau, greaterThan(-1));
      expect(sections, greaterThan(-1));
      expect(bandeau, lessThan(sections),
          reason: 'On doit savoir que le rapport est incomplet AVANT de le '
              'lire, pas apres s’en etre servi.');
    });

    test('il deconseille l’export en l’etat', () {
      // C'est le geste dangereux : ce rapport part en PDF a un ministere.
      final src = _sansCommentaires(_lire(_bandeau));
      expect(src.contains('exportez'), isTrue);
      expect(src.contains('ils sont inconnus'), isTrue,
          reason: 'Sans cette phrase, les zeros restent lisibles comme des '
              'faits.');
    });

    test('il propose de reessayer', () {
      final src = _sansCommentaires(_lire(_bandeau));
      expect(src.contains('invalidate(reportsSnapshotProvider)'), isTrue);
    });
  });

  group('Le tableau de bord du groupe aussi', () {
    // Meme famille, meme correction : huit lectures muettes sur l'ecran qu'un
    // administrateur de reseau ouvre en premier chaque matin.
    const provider =
        'lib/features/admin_groupe/providers/admin_dashboard_provider.dart';

    test('plus un seul `catch (_) {}`', () {
      expect(_sansCommentaires(_lire(provider)).contains('catch (_) {}'),
          isFalse);
    });

    test('les huit echecs sont nommes et traces', () {
      final src = _sansCommentaires(_lire(provider));
      expect('manquantes.note('.allMatches(src).length, 8);
      expect(src.contains('mesuresManquantes: manquantes.cles'), isTrue);
    });

    test('le bandeau precede les cartouches', () {
      final src = _sansCommentaires(_lire(
          'lib/features/admin_groupe/screens/tableau_de_bord/dash_apercu.dart'));
      final bandeau = src.indexOf('_MesuresManquantesGroupe(data: data)');
      final kpis = src.indexOf('_KpiSection(data: data)');
      expect(bandeau, greaterThan(-1));
      expect(kpis, greaterThan(-1));
      expect(bandeau, lessThan(kpis));
    });
  });
}
