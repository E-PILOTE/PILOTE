import 'dart:io';

import 'package:epilote/core/utils/contrat_inscriptions.dart';
import 'package:epilote/core/utils/sortie_motif.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LES TROIS CONTRATS DE `class_enrollments`
//
//  Cinq fichiers écrivent dans cette table, neuf domaines la lisent. Trois
//  règles doivent tenir pour que les chiffres de l'école soient justes — et
//  les trois ont été trouvées rompues au moins une fois pendant l'analyse de
//  septembre 2026. Elles n'étaient écrites nulle part : elles vivaient dans la
//  mémoire de qui les avait corrigées.
//
//  Ce fichier les énonce et les tient. La doctrine complète, avec ce que coûte
//  chaque rupture, est dans `lib/core/utils/contrat_inscriptions.dart`.
// ════════════════════════════════════════════════════════════════════════════

String _lire(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) fail('$chemin introuvable — lancer depuis `epilote/`.');
  return f.readAsStringSync().replaceAll('\r\n', '\n');
}

/// Les cinq écrivains connus. Un sixième doit passer par ces contrats avant
/// d'être ajouté ici.
const _kEcrivains = <String>[
  'lib/features/classes/providers/class_provider.dart',
  'lib/features/evaluation/providers/passage_provider.dart',
  'lib/features/evaluation/providers/cloture_examen_provider.dart',
  'lib/features/evaluation/providers/non_revenus_provider.dart',
  'lib/features/vie_scolaire/providers/discipline_provider.dart',
];

/// Découpe une source en instructions `UPDATE class_enrollments` — de
/// l'`UPDATE` jusqu'à la fin de la requête (`WHERE …` puis la fin de chaîne).
List<String> _updates(String src) {
  final out = <String>[];
  var i = src.indexOf('UPDATE class_enrollments');
  while (i >= 0) {
    // Une instruction ne dépasse jamais ce bloc : on s'arrête au `WHERE` qui
    // la referme, plus la ligne qui suit (les paramètres).
    final fin = src.indexOf('WHERE', i);
    out.add(src.substring(i, fin < 0 ? src.length : fin));
    i = src.indexOf('UPDATE class_enrollments', i + 1);
  }
  return out;
}

void main() {
  group('Le vocabulaire des statuts est celui du serveur', () {
    test('les six valeurs de `enrollment_status`', () {
      expect(kStatutsInscription, hasLength(6));
      expect(kStatutsInscription, containsAll(kStatutsDeSortie));
    });

    test('les trois statuts de sortie, et eux seuls', () {
      expect(kStatutsDeSortie, {'transferred', 'withdrawn', 'graduated'});
      expect(estUneSortie('graduated'), isTrue,
          reason: '⚠️ `graduated` EST une sortie : `v_sorties_par_motif` le '
              'compte au même titre que `withdrawn`. L’oublier est exactement '
              'le défaut corrigé le 2026-09-10.');
      expect(estUneSortie('active'), isFalse);
      expect(estUneSortie(null), isFalse);
      expect(estUneSortie('pending_validation'), isFalse);
    });
  });

  group('🩸 CONTRAT 1 — l’effectif, c’est DEUX conditions', () {
    test('la clause canonique porte les deux', () {
      final c = effectifActif();
      expect(c.contains("ce.status = 'active'"), isTrue);
      expect(c.contains('COALESCE(s.is_active, 1) <> 0'), isTrue,
          reason: '`deactivateStudent` retire un élève du registre sans '
              'toucher à son inscription : `status` seul le laisse compté.');
    });

    test('elle s’adapte aux alias de l’appelant', () {
      final c = effectifActif(inscription: 'e', eleve: 'st');
      expect(c.contains("e.status = 'active'"), isTrue);
      expect(c.contains('COALESCE(st.is_active, 1) <> 0'), isTrue);
    });

    test('les deux effectifs de classe portent bien les deux conditions', () {
      // Ce sont eux qui alimentent l'effectif affiché et les états signés.
      final src = _lire('lib/features/classes/providers/class_provider.dart');
      expect('COALESCE(s.is_active, 1) <> 0'.allMatches(src).length,
          greaterThanOrEqualTo(2),
          reason: 'Un effectif qui perd cette condition surdéclare l’école — '
              'et les dotations publiques suivent l’effectif déclaré.');
    });
  });

  group('🩸 CONTRAT 2 — toute sortie porte son motif', () {
    test('aucun écrivain ne pose un statut de sortie sans motif', () {
      final fautifs = <String>[];
      for (final chemin in _kEcrivains) {
        for (final u in _updates(_lire(chemin))) {
          final poseUneSortie = kStatutsDeSortie.any((s) => u.contains("'$s'"));
          // `setEnrollmentExit` passe le statut en paramètre : il est traité
          // comme une sortie puisque c'est sa seule raison d'être.
          final parametre = u.contains('status            = ?') ||
              u.contains('status = ?') ||
              u.contains('status       = ?');
          if (!poseUneSortie && !parametre) continue;
          if (!u.contains('withdrawal_motif')) {
            fautifs.add('$chemin :: ${u.split('\n').first.trim()}');
          }
        }
      }
      expect(fautifs, isEmpty,
          reason: 'Une sortie sans motif tombe dans le seau NULL de '
              '`v_sorties_par_motif` — la statistique nationale de '
              'déperdition. Elle n’y ressemble pas à une erreur : elle y '
              'ressemble à un abandon inexpliqué.\n${fautifs.join("\n")}');
    });

    test('la sortie diplômée porte `fin_de_scolarite`', () {
      final src =
          _lire('lib/features/evaluation/providers/cloture_examen_provider.dart');
      expect(src.contains("'fin_de_scolarite'"), isTrue,
          reason: 'C’est la seule écriture qui pose `graduated`. Sans motif, '
              'une promotion entière de Terminale sort du décompte des '
              'diplômés pour entrer dans celui des abandons.');
    });

    test('chaque motif écrit en dur appartient à la nomenclature fermée', () {
      // Un motif hors liste est refusé par `class_enrollments_withdrawal_motif_check`
      // (mig. 0082) — donc en `23514`, un code FATAL : le lot entier serait jeté.
      final codes = [
        for (final m in [...kMotifsTransfert, ...kMotifsRadiation]) m.code,
      ];
      final ecritsEnDur = <String>{};
      final motif = RegExp(r"withdrawal_motif\s*=\s*'([a-z_]+)'");
      for (final chemin in _kEcrivains) {
        for (final m in motif.allMatches(_lire(chemin))) {
          ecritsEnDur.add(m.group(1)!);
        }
      }
      expect(ecritsEnDur, isNotEmpty, reason: 'La sonde ne trouve plus rien.');
      for (final code in ecritsEnDur) {
        expect(codes, contains(code),
            reason: '« $code » n’est pas dans `sortie_motif.dart` : le serveur '
                'le refusera, et PowerSync jettera le lot.');
      }
    });
  });

  group('🩸 CONTRAT 3 — l’exonération s’applique ligne à ligne', () {
    test('`duScolarite` n’exonère que les frais de scolarité', () {
      final src =
          _lire('lib/features/finance/providers/obligation_provider.dart');
      expect(
          src.contains('kFraisScolarite.contains(b.feeType)\n'
              '        ? apresExoneration(du, exoneration)'),
          isTrue,
          reason: 'Appliquer le taux au TOTAL exonérerait aussi la cantine et '
              'le transport — que l’école a réellement engagés.');
    });

    test('l’exonération n’est jamais appliquée après la somme', () {
      final src =
          _lire('lib/features/finance/providers/obligation_provider.dart');
      expect(src.contains('return apresExoneration(total'), isFalse,
          reason: 'C’est la forme exacte du défaut : une remise sur le total.');
    });
  });

  group('Le cercle des écrivains reste fermé', () {
    test('exactement cinq fichiers écrivent dans la table', () {
      final trouves = <String>[];
      for (final f in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        // Sans les commentaires : le fichier de doctrine NOMME ces requêtes
        // pour les expliquer, il n'en exécute aucune.
        final src = f
            .readAsStringSync()
            .split('\n')
            .where((l) => !l.trimLeft().startsWith('//'))
            .join('\n');
        if (src.contains('UPDATE class_enrollments') ||
            src.contains('INSERT INTO class_enrollments')) {
          trouves.add(f.path.replaceAll(r'\', '/'));
        }
      }
      expect(trouves..sort(), _kEcrivains.toList()..sort(),
          reason: 'Un sixième écrivain doit d’abord tenir les trois contrats '
              'de `contrat_inscriptions.dart` — puis être ajouté à cette '
              'liste. Ce test n’interdit pas d’écrire : il interdit d’écrire '
              'sans avoir lu.');
    });
  });
}
