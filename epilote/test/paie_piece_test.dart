import 'dart:io';

import 'package:epilote/features/staff/providers/payroll_provider.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  UN BULLETIN PAYÉ EST UNE PIÈCE
//
//  ── LA DETTE QUE 0145 AVAIT LAISSÉE OUVERTE ───────────────────────────────
//  La migration 0145 a scellé `bulletins`, `expenses` et `student_payments`
//  sur la clôture de l'année, et a EXPLICITEMENT écarté `payroll` : la table
//  n'a pas d'`academic_year_id`, et un sceau par `USING` y aurait produit
//  « une suppression qui ne supprime rien, sans message ».
//
//  Rattacher la paie à l'année scolaire aurait été faux — une paie est datée
//  par mois civil, pas par exercice de septembre à juin. L'événement qui rend
//  un bulletin définitif, c'est LE PAIEMENT.
//
//  ── LES DEUX MOITIÉS, ET POURQUOI IL EN FAUT DEUX ─────────────────────────
//  `payroll` est HORS LIGNE. Si seule la base refusait, le poste aurait déjà
//  effacé la ligne localement : l'écran montrerait une suppression réussie et
//  le serveur garderait le bulletin. D'où un garde applicatif QUI EXPLIQUE, et
//  un déclencheur en base QUI LÈVE (42501, fatal → journalisé et affiché).
// ════════════════════════════════════════════════════════════════════════════

PayrollLine _ligne({required String status}) => PayrollLine(
      id: 'p1',
      staffId: 's1',
      staffName: 'Agent',
      base: 200000,
      bonuses: 0,
      deductions: 0,
      net: 200000,
      status: status,
    );

void main() {
  group('Ce qui rend un bulletin définitif', () {
    test('c\'est le paiement, pas la clôture d\'une année', () {
      expect(_ligne(status: 'confirmed').estPaye, isTrue);
      expect(_ligne(status: 'pending').estPaye, isFalse);
    });

    test('un statut inconnu n\'est pas traité comme payé', () {
      // Défaut prudent dans le bon sens : au pire on autorise une suppression
      // sur un bulletin non payé, jamais l'inverse. Et la base tranche.
      expect(_ligne(status: '').estPaye, isFalse);
      expect(_ligne(status: 'cancelled').estPaye, isFalse);
    });
  });

  group('Les deux moitiés du garde', () {
    test('l\'application refuse AVANT d\'appeler la base', () {
      final src =
          File('lib/features/staff/providers/payroll_provider.dart')
              .readAsStringSync();
      final i = src.indexOf('Future<void> deletePayroll(');
      expect(i, greaterThan(0), reason: 'Sonde aveugle : deletePayroll absent.');
      final corps = src.substring(i, i + 900);
      final jRefus = corps.indexOf('ErreurMetier');
      final jDelete = corps.indexOf('DELETE FROM payroll');
      expect(jRefus, greaterThan(0),
          reason: '`deletePayroll` ne refuse plus un bulletin payé : le refus '
              'viendrait alors du serveur en 42501, donc APRÈS que le poste a '
              'déjà effacé la ligne localement.');
      expect(jRefus, lessThan(jDelete),
          reason: 'Le refus doit précéder le DELETE.');
    });

    test('l\'écran désactive la suppression d\'un bulletin payé', () {
      final src = File('lib/features/staff/screens/paie_screen.dart')
          .readAsStringSync();
      expect(src.contains('enabled: !l.estPaye'), isTrue,
          reason: 'L\'entrée « Supprimer » doit être DÉSACTIVÉE, pas masquée : '
              'la masquer ferait croire à un droit manquant.');
    });

    // ── LE POINT QUE 0145 EXIGEAIT ────────────────────────────────────────
    test('la base LÈVE, elle ne refuse pas en silence', () {
      final sql = File('../database/migrations/'
              '0165_AVANT_LE_BUILD_un_bulletin_paye_ne_seface_plus.sql')
          .readAsStringSync();
      expect(sql.contains('RAISE EXCEPTION'), isTrue);
      expect(sql.contains("ERRCODE = '42501'"), isTrue,
          reason: 'Sans code fatal, le connecteur rejouerait indéfiniment.');
      expect(sql.contains('BEFORE DELETE ON public.payroll'), isTrue);
      // Un `USING` sur une politique aurait donné zéro ligne, sans message —
      // exactement ce que 0145 refusait pour cette table hors ligne.
      expect(sql.contains('CREATE POLICY'), isFalse,
          reason: 'Un sceau par politique serait MUET sur une table hors '
              'ligne : la ligne a déjà disparu du poste.');
    });

    test('le journal de synchro sait nommer un bulletin de paie', () {
      // Sans libellé, un abandon afficherait « payroll » à une comptable.
      final src = File('lib/services/powersync/powersync_connector.dart')
          .readAsStringSync();
      expect(src.contains("'payroll':"), isTrue);
      expect(src.contains('Bulletin de paie'), isTrue);
    });
  });

  group('Ce qui reste permis', () {
    test('la migration ne ferme QUE la suppression', () {
      // Corriger une référence de virement n'est pas réécrire l'histoire.
      // Vérifié en base : UPDATE sur un bulletin payé → 1 ligne.
      final sql = File('../database/migrations/'
              '0165_AVANT_LE_BUILD_un_bulletin_paye_ne_seface_plus.sql')
          .readAsStringSync();
      expect(sql.contains('BEFORE UPDATE'), isFalse,
          reason: 'Fermer aussi la modification empêcherait de corriger une '
              'référence de virement, et forcerait le logiciel à mentir.');
    });
  });
}
