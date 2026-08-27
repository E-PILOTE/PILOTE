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
      expect(code.contains("SELECT id, status FROM bulletins"), isTrue,
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
