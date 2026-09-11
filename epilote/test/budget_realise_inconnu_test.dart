import 'dart:io';

import 'package:epilote/features/finance/providers/budget_provider.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  « VOUS N'AVEZ RIEN DÉPENSÉ » — LE PIRE MENSONGE DE L'ÉCRAN BUDGET
//
//  ── LE DÉFAUT, TROUVÉ LE 2026-09-10 ────────────────────────────────────────
//  `budgetReelProvider` faisait `valueOrNull ?? const {}` sur les dépenses.
//  Pendant le chargement — et après un échec de lecture — le total retombait à
//  ZÉRO. Trois des quatre cartouches en dérivent, et l'écran annonçait donc,
//  d'un seul coup et comme des faits :
//
//      Réalisé : 0 F   ·   Disponible : <tout le budget>   ·   Exécution : 0 %
//
//  Autrement dit « vous n'avez rien dépensé, tout votre budget est
//  disponible » — à un comptable sur le point d'engager une dépense. Ce n'est
//  pas un chiffre faux parmi d'autres : c'est celui qui RASSURE, donc celui
//  qu'on ne vérifie pas.
//
//  ── CE QUE CE TEST GARDE ───────────────────────────────────────────────────
//  La distinction entre « zéro dépense » et « je ne sais pas », et le fait que
//  l'écran l'honore : « — » et un bandeau qui se lit AVANT les chiffres.
// ════════════════════════════════════════════════════════════════════════════

void main() {
  group('Zéro dépense et « je ne sais pas » ne sont pas la même chose', () {
    test('un réalisé SU à zéro reste un fait affichable', () {
      const r = BudgetReel.su(0, 0);
      expect(r.connu, isTrue,
          reason: 'Une école qui n\'a rien dépensé doit lire « 0 », pas '
              '« — » : c\'est une information exacte.');
      expect(r.total, 0);
      expect(r.erreur, isNull);
    });

    test('un réalisé INCONNU ne vaut pas zéro', () {
      const r = BudgetReel.inconnu();
      expect(r.connu, isFalse);
      expect(r.erreur, isNull,
          reason: 'Sans erreur : c\'est le cas « lecture en cours », qui se '
              'dit autrement qu\'un échec.');
    });

    test('un réalisé illisible porte SA cause', () {
      final r = BudgetReel.inconnu(erreur: Exception('réseau'));
      expect(r.connu, isFalse);
      expect(r.erreur, isNotNull,
          reason: 'Sans la cause, l\'écran ne peut pas distinguer « ça '
              'charge » de « ça a échoué » — et l\'agent attend indéfiniment.');
    });

    test('un réalisé connu porte ses deux montants', () {
      const r = BudgetReel.su(1250000, 300000);
      expect(r.total, 1250000);
      expect(r.horsBudget, 300000);
      expect(r.connu, isTrue);
    });
  });

  group('L\'écran honore l\'inconnu', () {
    String src() => File('lib/features/finance/screens/budget_screen.dart')
        .readAsStringSync()
        .replaceAll('\r\n', '\n');

    test('les trois cartouches dérivées passent par `siConnu`', () {
      final s = src();
      expect(s.contains('String siConnu('), isTrue,
          reason: 'Le garde a été renommé ou retiré.');
      expect(s.contains('siConnu(fmtCompact(actual))'), isTrue, reason: 'Réalisé');
      expect(s.contains('siConnu(fmtCompact(gap))'), isTrue, reason: 'Disponible');
      expect(s.contains("siConnu('\$rate%')"), isTrue, reason: 'Exécution');
    });

    test('le cartouche « Budgété » n\'est PAS masqué', () {
      // Il ne dépend que des lignes du budget : il reste exact même quand les
      // dépenses sont illisibles. Le masquer ferait disparaître une
      // information juste.
      final s = src();
      expect(s.contains("'Budgété',\n                  fmtCompact(budgeted)"),
          isTrue,
          reason: 'Le budget prévu ne dérive pas du réalisé : il ne doit pas '
              'tomber à « — » avec lui.');
    });

    test('le bandeau se lit AVANT les chiffres', () {
      final s = src();
      final bandeau = s.indexOf('_BandeauRealiseInconnu(');
      final kpis = s.indexOf('VsHeroKpis(cards:');
      expect(bandeau, greaterThan(-1));
      expect(bandeau, lessThan(kpis),
          reason: 'Sous les chiffres, le comptable s\'est déjà fait une '
              'opinion. Le bandeau doit précéder les cartouches.');
    });

    test('le bandeau dit de ne rien engager sur cette base', () {
      final s = src();
      expect(s.contains('ne valent pas zéro'), isTrue);
      expect(s.contains("n'engagez rien sur cette base"), isTrue,
          reason: 'C\'est la seule phrase qui transforme un avertissement en '
              'consigne. Sans elle, l\'agent lit « — » et engage quand même.');
    });
  });

  group('Le provider ne retombe plus sur un défaut vide', () {
    test('`valueOrNull ?? const {}` a disparu du calcul du réalisé', () {
      final s = File('lib/features/finance/providers/budget_provider.dart')
          .readAsStringSync()
          .replaceAll('\r\n', '\n');
      final debut = s.indexOf('final budgetReelProvider');
      expect(debut, greaterThan(-1));
      final corps = s.substring(debut);
      expect(corps.contains('valueOrNull ??'), isFalse,
          reason: 'Un défaut vide sur les dépenses ramène exactement le '
              'défaut corrigé : un total à zéro présenté comme un fait.');
      expect(corps.contains('hasValue'), isTrue);
    });
  });
}
