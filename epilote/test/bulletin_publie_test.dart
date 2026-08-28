import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  UN BULLETIN PUBLIÉ EST UN DOCUMENT REMIS, PAS UN BROUILLON
//
//  ── DÉFAUT 1 (2026-08-27) : « Publier » ne publiait rien ────────────────────
//  L'écran Bulletins enseigne lui-même le parcours : « Ouvrez une classe →
//  cliquez Ouvrir ». Ce geste renseigne `_openClassId` et laisse
//  `_scope.classId` NUL — or `_setStatus` gardait sur `_scope.classId` et
//  rendait la main sans rien faire, sans un message. Le bouton qui remet les
//  bulletins aux familles était donc inerte sur le seul chemin documenté ;
//  seul le déroulant du panneau de périmètre marchait.
//
//  ── DÉFAUT 2 (2026-08-27) : « Recalculer » jetait le lot hors ligne ─────────
//  `generateBulletins` réécrivait TOUS les bulletins, publiés compris. Deux
//  conséquences, et la première suffirait :
//   1. un document déjà remis aux familles changeait sous elles, sans trace ;
//   2. la base refuse cette écriture à qui n'a pas `validate` (RLS 0118), et
//      42501 est FATAL pour le connecteur PowerSync : le LOT ENTIER en attente
//      est jeté. Un enseignant perdait toutes ses saisies hors ligne du moment.
//  Mesuré en production (transaction annulée) : 474 bulletins publiés dans
//  l'école témoin, refus 42501 confirmé pour le profil Enseignant.
// ════════════════════════════════════════════════════════════════════════════

const _kEcran = 'lib/features/evaluation/screens/bulletins_screen.dart';
const _kConseils = 'lib/features/evaluation/screens/conseils_screen.dart';
const _kProvider = 'lib/features/evaluation/providers/bulletins_provider.dart';

String _lire(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) fail('$chemin introuvable — tourner depuis `epilote/`.');
  return f.readAsStringSync();
}

/// Le fichier sans ses lignes de commentaire : l'en-tête d'un correctif cite
/// forcément la forme fautive pour expliquer ce qui a été corrigé, et cette
/// mémoire doit rester lisible. Seul le code exécuté est jugé.
String _codeSeul(String chemin) => _lire(chemin)
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  group('Publier agit sur la classe OUVERTE', () {
    test('`_setStatus` ne garde plus sur le seul panneau de périmètre', () {
      final code = _codeSeul(_kEcran);
      expect(code.contains('classId: _scope.classId!'), isFalse,
          reason: 'Le parcours « Ouvrir » laisse `_scope.classId` nul : le '
              'bouton Publier ne publiait rien, en silence.');
      expect(code.contains('classId: _activeClassId!'), isTrue,
          reason: 'La classe active = celle ouverte, sinon celle du panneau.');
    });

    test('les deux écrans qui publient lisent la même classe', () {
      // Conseils appliquait déjà la bonne forme ; Bulletins était seul à
      // diverger. On garde les deux ensemble pour que la prochaine copie parte
      // du bon modèle.
      for (final chemin in [_kEcran, _kConseils]) {
        expect(_codeSeul(chemin).contains('_activeClassId'), isTrue,
            reason: '$chemin doit raisonner sur la classe active.');
      }
    });
  });

  group('Recalculer ne touche pas un bulletin publié', () {
    test('la génération lit le statut et passe son chemin', () {
      final code = _codeSeul(_kProvider);
      expect(code.contains('SELECT id, status FROM bulletins'), isTrue,
          reason: 'Sans le statut, impossible de distinguer un publié.');
      expect(
          RegExp(r"==\s*'published'[\s\S]{0,80}continue;").hasMatch(code),
          isTrue,
          reason: 'Un bulletin publié doit être SAUTÉ, pas réécrit.');
    });

    test('la génération rend compte de ce qu\'elle n\'a pas fait', () {
      final code = _codeSeul(_kProvider);
      expect(code.contains('class GenerationBulletins'), isTrue);
      expect(code.contains('publiesIntacts'), isTrue,
          reason: 'Un compte rendu qui tait les bulletins non recalculés est '
              'un succès qui ment.');
      expect(code.contains('Future<int> generateBulletins'), isFalse,
          reason: 'Un simple entier ne peut pas dire ce qui a été épargné.');
    });

    test('les deux écrans affichent ce compte rendu', () {
      for (final chemin in [_kEcran, _kConseils]) {
        final code = _codeSeul(chemin);
        expect(code.contains('aLaisseIntact'), isTrue,
            reason: '$chemin doit signaler les bulletins laissés intacts.');
        expect(code.contains('dépubliez'), isTrue,
            reason: '$chemin doit dire COMMENT recalculer malgré tout.');
      }
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  //  DÉFAUT 3 (2026-08-28) : la protection gardait une porte que personne
  //  n'empruntait.
  //
  //  `generateBulletins` refusait de retoucher un bulletin publié — et
  //  `bulletin_subject_lines`, la table qu'elle protégeait ainsi, était ÉCRITE
  //  ET JAMAIS LUE. Ni l'écran, ni le PDF, ni le conseil, ni le passage ne
  //  l'ouvraient : tous repartaient de `bulletinComputationProvider`, qui
  //  recalcule tout en direct depuis les notes et les coefficients.
  //
  //  Donc corriger une note, ou changer le coefficient d'une matière,
  //  réécrivait un bulletin DÉJÀ REMIS aux familles et déjà signé. Réimprimé
  //  en septembre, le trimestre de juillet ne donnait plus les mêmes moyennes
  //  ni le même rang, et rien ne le disait. Le conseil de classe délibérait sur
  //  des chiffres qui pouvaient encore bouger après sa décision.
  //
  //  Les deux moitiés se contredisaient : soit le bulletin est un document et
  //  il se relit, soit il est une vue et la protection n'a pas de sens. Un
  //  bulletin remis à un parent est un document.
  // ══════════════════════════════════════════════════════════════════════════
  group('Un bulletin publié se RELIT, il ne se recalcule pas', () {
    test('le calcul ouvre les lignes enregistrées', () {
      final code = _codeSeul(_kProvider);
      expect(code.contains('FROM   bulletin_subject_lines bl'), isTrue,
          reason: 'La table était écrite et jamais lue : la protection de la '
              'génération gardait des lignes que personne n\'ouvrait.');
      expect(code.contains("(r['status'] as String?) == 'published'"), isTrue,
          reason: 'Seul un bulletin PUBLIÉ est figé ; un brouillon doit se '
              'recalculer — c\'est ce qu\'on attend d\'un brouillon.');
    });

    test('les valeurs rendues viennent du document, pas du recalcul', () {
      final code = _codeSeul(_kProvider);
      for (final champ in [
        'overall_average',
        'total_students',
        'total_absences',
        'total_lates',
      ]) {
        expect(code.contains("fige?['$champ']"), isTrue,
            reason: '`$champ` doit être relu du bulletin publié : c\'est ce '
                'chiffre-là qui est imprimé sur le document remis.');
      }
      expect(code.contains('lines: lignesFigees[enr] ?? lines'), isTrue,
          reason: 'Les lignes du document priment sur celles du jour.');
      expect(code.contains("(fige?['rank'] as num?)?.toInt()"), isTrue,
          reason: 'Le rang aussi : il change dès qu\'une note bouge ailleurs '
              'dans la classe, sans que l\'élève y soit pour rien.');
      // La moyenne de CLASSE n'est pas une valeur d'élève : elle se relit une
      // fois pour le trimestre. `setBulletinsStatus` publie la classe entière,
      // donc dès qu'un bulletin est publié le document porte la sienne.
      expect(code.contains('final classAvg = figeeClasse ??'), isTrue,
          reason: 'La moyenne de classe imprimée doit être celle du document.');
    });

    test('un bulletin publié sans ligne enregistrée reste lisible', () {
      // Les bulletins publiés AVANT ce correctif n'ont pas forcément leurs
      // lignes. Un document vide serait pire que le recalcul.
      final code = _codeSeul(_kProvider);
      expect(code.contains('if (l != null && l.isNotEmpty)'), isTrue,
          reason: 'Le repli doit être le calcul, jamais un bulletin vide.');
    });

    test('ce qui vit après la publication reste en direct', () {
      // La décision du conseil et les appréciations s'écrivent APRÈS que les
      // moyennes sont arrêtées : les figer les effacerait.
      final code = _codeSeul(_kProvider);
      expect(code.contains('decision: councilByEnr[enr]?.decision'), isTrue);
      expect(code.contains("fige?['decision']"), isFalse,
          reason: 'Figer la décision du conseil la rendrait insaisissable.');
    });
  });

  group('Le modèle fossile `GradeModel` ne revient pas', () {
    test('il n\'existe plus', () {
      // Il décrivait une table `grades` disparue : neuf de ses champs
      // (`value`, `sequence_id`, `trimester_id`, `grade_type`…) n'existent pas
      // en base, et trois champs réels (`evaluation_id`, `score`, `is_absent`)
      // lui manquaient. `fromMap` aurait levé sur la PREMIÈRE ligne venue.
      // Aucun appelant — donc aucun test, donc personne pour s'en apercevoir :
      // exactement le piège dormant de `AppConstants.roleUtilisateur`.
      expect(File('lib/data/models/grade_model.dart').existsSync(), isFalse);
    });
  });
}
