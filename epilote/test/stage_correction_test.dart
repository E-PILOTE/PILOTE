import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CORRIGER ET SUPPRIMER UN STAGE
//
//  ── LA PANNE : DEUX FONCTIONS ÉCRITES, AUCUN APPELANT ─────────────────────
//  `updateInternship` et `deleteInternship` existaient, complètes et testables,
//  et personne ne les appelait. Le formulaire ne savait que créer.
//
//  Conséquence pour une école : un stage saisi de travers — mauvaise
//  entreprise, dates inversées, téléphone du tuteur erroné — était DÉFINITIF.
//  L'agent n'avait d'autre recours que d'en créer un second, et l'établissement
//  se retrouvait avec deux stages pour un élève. Ce qui sort de là mène à
//  l'attestation, pièce du dossier du baccalauréat technique : une date fausse
//  y reste fausse jusqu'au jury.
//
//  La base, elle, était prête depuis toujours : `internships_update` exige
//  `stages/update`, `internships_delete` exige `stages/delete`, et les profils
//  « directeur » et « secrétaire » détiennent les trois verbes. Seuls les
//  boutons manquaient.
//
//  ── CE QUE CES TESTS TIENNENT ─────────────────────────────────────────────
//  Ils lisent le CODE SOURCE. Ils ne prouvent pas qu'une correction aboutit —
//  ils prouvent que le chemin existe, et qu'il se garde sur le bon verbe. La
//  seconde partie est la moins évidente et la plus facile à casser : garder la
//  suppression sur `update` la rendrait silencieusement refusée par la RLS.
// ════════════════════════════════════════════════════════════════════════════

String _lire(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) fail('$chemin introuvable — lancer depuis `epilote/`.');
  return f.readAsStringSync();
}

const _kFiche = 'lib/features/stages/widgets/stage_file_dialog.dart';
const _kFormulaire = 'lib/features/stages/widgets/stage_form_dialog.dart';
const _kActions = 'lib/features/stages/providers/stage_actions.dart';

void main() {
  group('Le chemin de correction existe', () {
    test('le formulaire accepte un stage à corriger', () {
      final src = _lire(_kFormulaire);
      expect(src.contains('StageDetail? stage'), isTrue,
          reason: 'Sans ce paramètre, le formulaire ne sait que créer.');
      expect(src.contains('await updateInternship('), isTrue,
          reason: 'Le mode correction doit appeler `updateInternship` — sinon '
              'il crée un SECOND stage, ce qui est le défaut d’origine.');
    });

    test('la fiche ouvre le formulaire sur le stage affiché', () {
      expect(_lire(_kFiche).contains('showStageFormDialog(context, stage: s)'),
          isTrue);
    });

    test('la fiche sait supprimer', () {
      expect(_lire(_kFiche).contains('await deleteInternship(s.id)'), isTrue);
    });
  });

  group('Chaque geste se garde sur SON verbe', () {
    test('la suppression exige `delete`, pas `update`', () {
      final src = _lire(_kFiche);
      expect(
        src.contains("canProvider((slug: _kSlug, action: 'delete'))"),
        isTrue,
        reason: 'La RLS `internships_delete` exige '
            'auth_module_permet([stages], delete). Garder le bouton sur '
            '`update` le montrerait à quelqu’un dont l’ordre de suppression '
            'serait refusé par la base — en silence, comme toujours.',
      );
    });

    test('la correction exige `update`', () {
      final src = _lire(_kFiche);
      final iCorriger = src.indexOf('_corriger(s)');
      expect(iCorriger, greaterThan(-1));
      // Le bouton « Corriger » est rendu sous `if (canEdit)`, et `canEdit` est
      // calculé sur le verbe `update` en tête de build.
      expect(src.contains("action: 'update'"), isTrue);
      expect(src.contains('if (canEdit)'), isTrue);
    });
  });

  group('L’élève d’un stage ne se change pas', () {
    test('le formulaire fige l’élève en correction', () {
      final src = _lire(_kFormulaire);
      expect(src.contains('if (_correction)'), isTrue);
      expect(src.contains('_EleveFige('), isTrue,
          reason: 'Déplacer un stage d’un élève à un autre n’est pas une '
              'correction : c’est un autre stage, et l’attestation déjà '
              'délivrée porterait le nom du premier.');
    });

    test('mais il l’AFFICHE — le taire serait pire que le figer', () {
      final src = _lire(_kFormulaire);
      expect(src.contains('widget.stage!.studentName'), isTrue);
    });
  });

  group('La suppression prévient de ce qu’elle emporte', () {
    test('la confirmation nomme l’élève', () {
      final src = _lire(_kFiche);
      expect(src.contains(r'${s.studentName}'), isTrue,
          reason: '« Supprimer ce stage ? » sur une fiche ouverte par erreur '
              'se valide sans lire. Le nom force à vérifier la ligne.');
    });

    test('elle alerte quand une attestation a été délivrée', () {
      final src = _lire(_kFiche);
      expect(src.contains('s.hasAttestation'), isTrue,
          reason: 'La pièce est peut-être déjà dans un dossier de bac, où elle '
              'continuera d’exister alors que le stage aura disparu.');
    });
  });

  group('Le modèle porte de quoi corriger', () {
    test('`StageDetail` connaît l’identifiant de l’entreprise, pas que son nom',
        () {
      final src = _lire('lib/features/stages/models/stage_detail.dart');
      expect(src.contains('final String? companyId;'), isTrue,
          reason: 'Le sélecteur d’entreprise doit se repositionner : un nom ne '
              'désigne pas une ligne.');
      expect(_lire(_kActions).contains('i.company_id'), isTrue,
          reason: 'Déclarer le champ sans le SÉLECTIONNER le laisserait '
              'toujours nul — le formulaire rouvrirait vide.');
    });
  });

  group('Aucune action de stage n’est écrite sans être proposée', () {
    test('les quatre gestes ont un appelant hors de leur fichier', () {
      final lib = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .map((f) => f.readAsStringSync())
          .join('\n');

      for (final geste in [
        'createInternship',
        'updateInternship',
        'deleteInternship',
        'setInternshipEvaluation',
      ]) {
        // Une occurrence est la déclaration ; il en faut au moins une autre.
        final appels = RegExp('[^A-Za-z0-9_]$geste\\(').allMatches(lib).length;
        expect(appels, greaterThan(1),
            reason: 'Aucun écran n’appelle `$geste` : la fonction existe, le '
                'geste n’existe pas. C’est exactement l’état d’où l’on sort.');
      }
    });
  });
}
