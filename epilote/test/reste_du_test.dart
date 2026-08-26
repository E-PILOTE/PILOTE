import 'dart:io';

import 'package:epilote/features/finance/services/obligation.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE RESTE DÛ S'ADDITIONNE, IL NE SE SOUSTRAIT PAS
//
//  ── LE DÉFAUT, TROUVÉ LE 2026-08-25 ────────────────────────────────────────
//  Le total « Reste dû » de l'écran Paiements valait `(Σ dû) − (Σ versé)`, et
//  l'état de recouvrement imprimé refaisait la même soustraction par classe.
//
//  Une famille qui règle l'année d'avance — cas courant quand la récolte tombe
//  — efface alors la dette des autres. Avec une mensualité à 21 000 F, en
//  octobre le dû est d'UN mois : la famille qui verse les dix mois (210 000 F)
//  pèse −189 000 F dans la soustraction, soit exactement neuf familles qui
//  n'ont rien payé. L'écran annonçait « Reste dû : 0 », et le `.clamp(0, …)`
//  finissait de masquer le signe.
//
//  Le code savait pourtant le faire pour UN élève : `etatObligation` pose que
//  « le trop-versé reste à jour ». C'est en agrégeant que la règle se perdait —
//  d'où le fait qu'elle porte désormais un nom, `resteEleve`.
//
//  ⚠️ Ce total n'était couvert par AUCUN test. Il partait sur du papier, à une
//  direction départementale.
// ════════════════════════════════════════════════════════════════════════════

const _kProvider = 'lib/features/finance/providers/paiements_provider.dart';
const _kRapports = 'lib/features/user/providers/rapports_provider.dart';

String _lire(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) fail('$chemin introuvable — tourner depuis `epilote/`.');
  return f.readAsStringSync();
}

void main() {
  group('Ce qu\'un élève doit encore', () {
    test('la différence, quand il a versé moins que son dû', () {
      expect(resteEleve(du: 21000, verse: 5000), 16000);
    });

    test('rien, quand il a soldé', () {
      expect(resteEleve(du: 21000, verse: 21000), 0);
    });

    test('rien, et jamais une créance négative, quand il a payé d\'avance', () {
      // C'est ici que tout se joue : un trop-versé de 189 000 F ne doit pas
      // pouvoir être emporté dans un total et y annuler la dette d'autrui.
      expect(resteEleve(du: 21000, verse: 210000), 0);
    });

    test('rien à devoir quand aucun barème ne s\'applique', () {
      expect(resteEleve(du: 0, verse: 0), 0);
    });
  });

  group('Une avance ne solde que sa propre dette', () {
    test('dix élèves, une famille qui paie l\'année : la dette reste', () {
      // Octobre : chacun doit un mois de 21 000 F. Une famille verse les dix
      // mois d'un coup, les neuf autres n'ont rien versé.
      const du = 21000;
      final verses = [210000, 0, 0, 0, 0, 0, 0, 0, 0, 0];

      final reste =
          verses.fold(0, (a, v) => a + resteEleve(du: du, verse: v));
      expect(reste, 9 * 21000,
          reason: 'Neuf familles doivent encore un mois chacune.');

      // L'ancienne formule, pour mémoire — et pour qu'on voie l'écart.
      final ancienne =
          (du * verses.length - verses.fold(0, (a, v) => a + v))
              .clamp(0, du * verses.length);
      expect(ancienne, 0);
      expect(ancienne, isNot(reste),
          reason: 'La soustraction de deux sommes annonçait une école à jour '
              'alors qu\'il lui manquait 189 000 F.');
    });
  });

  group('Aucun chemin ne recalcule le reste par soustraction', () {
    test('l\'aperçu Paiements additionne les restes', () {
      final src = _lire(_kProvider);
      expect(src.contains('resteEleve(du:'), isTrue,
          reason: 'Le reste se compte élève par élève.');
      expect(RegExp(r'duTotal\s*-\s*collected').hasMatch(src), isFalse,
          reason: 'C\'était exactement le défaut : Σ dû − Σ versé.');
    });

    test('l\'état de recouvrement imprimé PORTE le reste', () {
      final src = _lire(_kRapports);
      expect(RegExp(r'resteDe\(LigneRecouvrement l\)\s*=>\s*l\.reste')
          .hasMatch(src), isTrue,
          reason: 'Le document ne refait aucun calcul : il imprime ce que '
              'l\'écran a compté, sans quoi les deux divergent — et ici la '
              'divergence part sur du papier.');
      expect(RegExp(r'l\.du\s*-\s*l\.encaisse').hasMatch(src), isFalse);
    });

    test('l\'encaissé et le dû comptent les mêmes élèves', () {
      // Un élève retiré du registre sortait du dû et de l'effectif, mais ses
      // versements restaient dans l'encaissé et dans le compte des payeurs :
      // l'écran pouvait annoncer plus de payeurs que d'élèves.
      final src = _lire(_kProvider);
      final filtres = RegExp(r'COALESCE\(s\.is_active, 1\) <> 0')
          .allMatches(src)
          .length;
      expect(filtres, greaterThanOrEqualTo(2),
          reason: 'Les DEUX lectures — versements et inscrits — doivent poser '
              'le même filtre de registre.');
    });
  });
}
