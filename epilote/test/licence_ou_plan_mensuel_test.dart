import 'dart:io';

import 'package:epilote/features/super_admin/providers/school_groups_provider.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  DEUX NATURES DE CLIENT, DEUX RELATIONS COMMERCIALES
//
//  La règle, dite par le fondateur : « un ministère est rattaché à une
//  LICENCE ; un groupe scolaire privé est rattaché à un PLAN MENSUEL ».
//
//  ⚠️ CE FICHIER GARDE DU REVENU, pas de l'affichage. Les plans mensuels sont
//  ce que la plateforme facture ; le plan « Licence de tutelle » ne porte
//  aucun prix, ses conditions réelles vivant dans `tutelle_licences` (0160 —
//  montant, durée négociée, avance, règlements, référence de marché,
//  signataire). Confondre les deux se paie deux fois :
//
//   • un ministère laissé sur une formule mensuelle injecte du revenu qui
//     n'existe pas — les deux ministères pesaient **80 000 XAF/mois** de
//     revenu fantôme dans le KPI de la plateforme, mesuré avant 0182 ;
//   • un groupe privé posé sur le plan « Licence » à 0 XAF sort du revenu
//     mensuel sans que rien ne le signale.
//
//  La base refuse les deux sens (`trg_ministere_sur_licence`, 0182). L'écran,
//  lui, ne doit même pas les offrir — un formulaire qui propose un choix que
//  la base refusera est un formulaire qui ment.
//
//  ── ⚠️ LE PIÈGE QUI A FAILLI COÛTER LES 32 MODULES ────────────────────────
//  Les modules sont accordés par le PLAN (`plan_modules`), pas par le groupe.
//  Basculer les ministères sur un plan « Licence » vide leur aurait retiré les
//  32 modules d'Institutionnel dans la seconde, sans un message. La migration
//  recopie les accès AVANT le rattachement, et refuse de continuer si la
//  recopie a échoué.
// ════════════════════════════════════════════════════════════════════════════

const _formulaire =
    'lib/features/super_admin/screens/groups/group_form_modal.dart';
const _migration =
    '../database/migrations/0182_AVANT_LE_BUILD_le_ministere_quitte_la_formule_mensuelle.sql';

String _lire(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) fail('Fichier introuvable : $chemin — sonde aveugle.');
  return f.readAsStringSync().replaceAll('\r\n', '\n');
}

PlanInfo _plan(String nom, {required String slug, required int prix}) =>
    PlanInfo(
      id: slug,
      name: nom,
      slug: slug,
      priceXaf: prix,
      maxSchools: -1,
      maxStudents: -1,
    );

void main() {
  final licence = _plan('Licence de tutelle', slug: 'licence', prix: 0);
  final decouverte = _plan('Découverte', slug: 'gratuit', prix: 0);

  group('Le plan de licence se reconnaît', () {
    test('au slug, et à rien d’autre', () {
      // ⚠️ Pas au PRIX : « Découverte » est aussi à 0 XAF. C'est exactement
      // pourquoi le défaut à la création (`plans.first`, trié par prix)
      // pouvait tomber sur l'un ou l'autre.
      expect(licence.estLicence, isTrue);
      expect(decouverte.estLicence, isFalse);
      expect(decouverte.priceXaf, licence.priceXaf);
    });

    test('un plan sans slug n’est jamais pris pour une licence', () {
      // Fail-soft : dans le doute, on reste sur le comportement commercial.
      const inconnu = PlanInfo(
        id: 'x',
        name: '?',
        priceXaf: 0,
        maxSchools: 1,
        maxStudents: 1,
      );
      expect(inconnu.estLicence, isFalse);
    });
  });

  group('La base sépare les deux relations', () {
    test('les modules sont recopiés AVANT le rattachement', () {
      final sql = _lire(_migration);
      final iModules = sql.indexOf('INSERT INTO public.plan_modules');
      final iBascule = sql.indexOf('UPDATE public.school_groups');
      expect(iModules, greaterThan(0));
      expect(iBascule, greaterThan(0));
      expect(iModules, lessThan(iBascule),
          reason: 'Le rattachement passe AVANT la recopie des accès : les '
              'ministères se retrouvent sans un seul module.');
    });

    test('et la migration refuse de basculer sur un plan vide', () {
      final sql = _lire(_migration);
      expect(sql.contains('n\'\'accorde aucun module'), isTrue,
          reason: 'Le garde a disparu : une recopie ratée passerait inaperçue '
              'et les ministères perdraient leurs 32 modules.');
    });

    test('la contrainte vaut dans les DEUX sens', () {
      final sql = _lire(_migration);
      expect(sql.contains('administre_referentiel_national AND v_slug'), isTrue,
          reason: 'Un ministère peut de nouveau être facturé au mois.');
      expect(sql.contains("v_slug = 'licence' AND NOT NEW"), isTrue,
          reason: 'Un groupe privé peut de nouveau être posé sur le plan à '
              '0 XAF — et sortir du revenu de la plateforme.');
    });

    test('le terme du ministère cesse d’être une échéance d’abonnement', () {
      // Sinon le KPI « expire bientôt » (≤ 30 j) signale un ministère comme
      // un client sur le départ. Le METP était à 27 jours.
      final sql = _lire(_migration);
      expect(sql.contains('subscription_end = NULL'), isTrue);
    });
  });

  group('L’écran n’offre pas ce que la base refusera', () {
    test('la liste des plans suit la nature du groupe', () {
      final src = _lire(_formulaire);
      expect(src.contains('p.estLicence == _estTutelle'), isTrue,
          reason: 'Le formulaire propose de nouveau tous les plans : un '
              'groupe privé peut être posé sur la licence, et un ministère '
              'sur une formule mensuelle.');
    });

    test('basculer l’interrupteur réaligne le plan', () {
      // Sans ça, cocher « ce groupe est un ministère » laisse « Standard »
      // sélectionné et l'enregistrement part se faire refuser par la base.
      final src = _lire(_formulaire);
      expect(src.contains('_alignerLePlan()'), isTrue);
      final i = src.indexOf('_estTutelle = v;');
      expect(i, greaterThan(0));
      expect(src.substring(i, i + 80).contains('_alignerLePlan()'), isTrue,
          reason: 'L’interrupteur ne réaligne plus le plan.');
    });

    test('le défaut à la création ne tombe plus sur la licence', () {
      // `plans.first` triait par prix : « Découverte » et « Licence » sont
      // tous deux à 0 XAF, l'ordre entre eux n'est pas garanti.
      final src = _lire(_formulaire);
      expect(src.contains('widget.plans.first.id'), isFalse,
          reason: 'Le défaut est revenu au premier plan par prix : un groupe '
              'ordinaire peut naître sur le plan des ministères.');
    });
  });
}
