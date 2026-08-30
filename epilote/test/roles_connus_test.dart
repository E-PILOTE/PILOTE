import 'dart:io';

import 'package:epilote/core/constants/app_constants.dart';
import 'package:epilote/features/user/widgets/staff_account_widgets.dart'
    show staffRoleLabel;
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  UN AIGUILLAGE SUR LE RÔLE NE TESTE QUE DES RÔLES QUI EXISTENT
//
//  ── TROIS FOIS LE MÊME DÉFAUT ─────────────────────────────────────────────
//  1. `roleUtilisateur = 'utilisateur'` — valeur absente de l'enum, testée dans
//     le code. Elle a tué la synchro de TOUT le personnel (2026-06-06).
//  2. `directeur_etudes` dans `directionRoles` — le test ne pouvait jamais
//     réussir, la garde du Calendrier ne gardait rien (retiré 2026-08-27).
//  3. `directeur_ecole` et `directeur_etudes` dans `_shortenRole` du tableau de
//     bord plateforme — deux branches inatteignables, pendant que six rôles
//     réels tombaient dans le cas par défaut (corrigé 2026-08-30).
//
//  Le défaut ne se voit pas : le code compile, l'écran s'affiche, et la branche
//  morte a l'air d'une prise en charge. Ce n'est visible qu'en confrontant les
//  valeurs testées à l'enum.
//
//  ── CE QUE CE GARDE TIENT ─────────────────────────────────────────────────
//  Toute chaîne qui ressemble à un rôle, dans un fichier qui aiguille sur le
//  rôle, doit appartenir à `AppConstants.tousLesRoles`. Et `staffRoleLabel`,
//  source unique de l'étiquetage du personnel, doit couvrir tous les rôles
//  d'école sans exception.
// ════════════════════════════════════════════════════════════════════════════

/// Les treize valeurs, telles que l'enum `user_role` les porte en base
/// (relevé du 2026-08-30). Écrites À LA MAIN ici, exprès : si quelqu'un ajoute
/// une valeur à `AppConstants.tousLesRoles` sans toucher l'enum, la confrontation
/// doit échouer — sinon le garde suivrait l'erreur au lieu de la voir.
const _kEnumServeur = {
  'super_admin',
  'admin_groupe',
  'directeur',
  'proviseur',
  'enseignant',
  'cpe',
  'comptable',
  'secretaire',
  'surveillant',
  'parent',
  'eleve',
  'infirmier',
  'responsable_cantine',
};

/// Les rôles d'un établissement — tout sauf les deux rôles de plateforme.
Set<String> get _kRolesEcole =>
    _kEnumServeur.difference({'super_admin', 'admin_groupe'});

void main() {
  group('La liste Dart et l’enum serveur disent la même chose', () {
    test('aucune valeur en trop côté Dart', () {
      expect(AppConstants.tousLesRoles.difference(_kEnumServeur), isEmpty,
          reason: 'Un rôle qui n’existe pas en base ne peut jamais être porté '
              'par un compte : tout test dessus est mort.');
    });

    test('aucun rôle du serveur oublié côté Dart', () {
      expect(_kEnumServeur.difference(AppConstants.tousLesRoles), isEmpty,
          reason: 'Un rôle absent de la liste tombera dans les cas par défaut '
              'de chaque aiguillage, sans que rien ne le signale.');
    });
  });

  group('staffRoleLabel couvre tout le personnel', () {
    test('chaque rôle d’école a son étiquette, aucun ne tombe au défaut', () {
      for (final r in _kRolesEcole) {
        expect(staffRoleLabel(r), isNot('Personnel'),
            reason: 'Le rôle « $r » s’affiche « Personnel » : l’agent ne lit '
                'pas sa fonction, et deux métiers différents deviennent '
                'indiscernables à l’écran.');
      }
    });

    test('un rôle inconnu retombe proprement, sans exception', () {
      expect(staffRoleLabel('rôle_qui_nexiste_pas'), 'Personnel');
    });
  });

  group('Le tableau de bord plateforme n’aiguille plus sur du vide', () {
    test('les deux valeurs mortes ont disparu', () {
      final src = File(
        'lib/features/super_admin/providers/super_dashboard_provider.dart',
      ).readAsStringSync();
      // ⚠️ On cherche la valeur ENTRE GUILLEMETS : le fichier documente
      // désormais l'erreur en prose, et cette prose doit rester lisible.
      expect(src.contains("'directeur_ecole'"), isFalse,
          reason: 'Cette valeur n’est pas dans l’enum — la branche ne peut pas '
              's’exécuter.');
      expect(src.contains("'directeur_etudes' =>"), isFalse,
          reason: 'Le Directeur des Études est un PROFIL D’ACCÈS, pas un '
              'user_role. Décision du 2026-08-30, voir app_constants.dart.');
    });

    test('il délègue à la source unique plutôt que de recopier', () {
      final src = File(
        'lib/features/super_admin/providers/super_dashboard_provider.dart',
      ).readAsStringSync();
      expect(src.contains('staffRoleLabel(role)'), isTrue,
          reason: 'Une seconde table d’étiquettes finirait par diverger de la '
              'première — c’est déjà arrivé au barème des mentions, à quatre '
              'exemplaires.');
    });
  });

  group('Les rôles « direction » existent tous', () {
    test('directionRoles ne contient que des rôles de l’enum', () {
      expect(AppConstants.directionRoles.difference(_kEnumServeur), isEmpty,
          reason: 'C’est exactement le défaut retiré le 2026-08-27 : une garde '
              'qui teste une valeur qu’aucun compte ne peut porter ne garde '
              'rien, et laisse croire le contraire.');
    });
  });
}
