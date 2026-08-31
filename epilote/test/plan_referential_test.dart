import 'dart:io';

import 'package:epilote/core/utils/plan_referential_realtime.dart';
import 'package:epilote/features/super_admin/providers/plans_provider.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE RÉFÉRENTIEL DE FACTURATION — TARIF, QUOTAS, MODULES
//
//  ── CE QUI S'EST PASSÉ (2026-08-01) ────────────────────────────────────────
//  Le prix du plan `institutionnel` est passé de 900 000 à 2 500 000 FCFA.
//  L'écriture a réussi. Le revenu récurrent du tableau de bord, la fiche
//  d'abonnement de l'admin de groupe et les cartes de groupes ont continué
//  d'afficher l'ancien montant jusqu'au redémarrage de l'application.
//
//  Trois causes empilées :
//    1. `subscription_plans` n'était pas dans la publication
//       `supabase_realtime` (migration 0076) — un canal Realtime sur une table
//       hors publication ne lève AUCUNE erreur, il se tait ;
//    2. aucun écran consommateur n'écoutait cette table — ils écoutaient
//       `school_groups`, or changer un tarif ne touche pas `school_groups` ;
//    3. tous ces providers sont `ref.keepAlive()` : la valeur périmée survit
//       à la navigation, donc à toute la session.
//
//  Le 3 est ce qui transforme un retard d'affichage en donnée fausse durable.
//  D'où la règle vérifiée ici : cache + tarif ⇒ écoute obligatoire.
// ════════════════════════════════════════════════════════════════════════════

/// Champs qui font d'un fichier un consommateur du référentiel de facturation.
const _planFields = [
  'price_xaf',
  'max_schools',
  'max_students',
  'max_staff',
  'module_count',
];

/// Fichiers dispensés, avec la raison — un fichier ne s'ajoute ici que si
/// écouter Supabase Realtime n'a PAS de sens pour lui.
const _exemptions = <String, String>{
  // Le helper lui-même.
  'lib/core/utils/plan_referential_realtime.dart': 'définit la règle',
  // Chemin PowerSync offline : ce provider ne parle jamais à Supabase, et
  // `subscription_plans` n'est même pas dans le schéma local. Il ne cite les
  // quotas que dans sa documentation.
  'lib/features/students/providers/students_provider.dart': 'offline PowerSync',
};

void main() {
  group('Tout écran qui met un tarif en cache doit écouter le référentiel', () {
    test('aucun consommateur `keepAlive` n\'ignore subscription_plans', () {
      final coupables = <String>[];

      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path.replaceAll(r'\', '/');
        if (_exemptions.containsKey(path)) continue;

        final source = entity.readAsStringSync();
        if (!source.contains('subscription_plans')) continue;
        if (!_planFields.any(source.contains)) continue;

        // Sans `keepAlive`, le provider est reconstruit à chaque affichage :
        // il se rafraîchit tout seul, l'écoute serait du confort.
        if (!source.contains('keepAlive()')) continue;

        if (!source.contains('watchPlanReferential')) coupables.add(path);
      }

      expect(
        coupables,
        isEmpty,
        reason: 'Ces fichiers lisent un tarif ou un quota de plan, le gardent '
            'en mémoire pour la session (`keepAlive`), et n\'écoutent pas '
            '`subscription_plans` : une révision tarifaire y resterait '
            'invisible jusqu\'au redémarrage de l\'application. Ajouter '
            '`.watchPlanReferential(...)` sur leur canal.',
      );
    });

    test('la règle attrape bien un fichier fautif', () {
      // Garde-fou du garde-fou : si la détection se met à ne plus rien voir,
      // le test précédent passerait au vert sur une application cassée.
      const fautif = '''
        final p = FutureProvider((ref) async {
          ref.keepAlive();
          await client.from('school_groups')
              .select('subscription_plans!plan_id(price_xaf)');
        });
      ''';
      expect(fautif.contains('subscription_plans'), isTrue);
      expect(_planFields.any(fautif.contains), isTrue);
      expect(fautif.contains('keepAlive()'), isTrue);
      expect(fautif.contains('watchPlanReferential'), isFalse);
    });

    test('le helper couvre le tarif ET la composition en modules', () {
      // `module_count` est dérivé de `plan_modules` (trigger, migration 0076) :
      // écouter `subscription_plans` seul manquerait un changement de modules.
      expect(kPlanReferentialTables, contains('subscription_plans'));
      expect(kPlanReferentialTables, contains('plan_modules'));
    });
  });

  group('Quotas — la convention « -1 = illimité »', () {
    test('-1 s\'affiche « Illimité », jamais « -1 »', () {
      expect(quotaLabel(-1), 'Illimité');
      expect(quotaLabel(50000), '50 000');
      expect(quotaLabel(0), '0');
    });

    test('un plan illimité l\'annonce sur les trois quotas', () {
      // Le plan `institutionnel` : écoles illimitées mais 50 000 élèves, c'était
      // promettre au MEPSA ce qu'on ne pouvait pas tenir — le mur tombait à la
      // 167ᵉ école. Les trois plafonds sont désormais alignés.
      final p = _plan(maxSchools: -1, maxStudents: -1, maxStaff: -1);
      expect(p.maxSchoolsLabel, 'Illimité');
      expect(p.maxStudentsLabel, 'Illimité');
      expect(p.maxStaffLabel, 'Illimité');
      expect(p.unlimited, isTrue);
    });

    test('un plan borné affiche ses chiffres', () {
      final p = _plan(maxSchools: 5, maxStudents: 2000, maxStaff: 200);
      expect(p.maxSchoolsLabel, '5');
      expect(p.maxStudentsLabel, '2 000');
      expect(p.maxStaffLabel, '200');
      expect(p.unlimited, isFalse);
    });

    test('la saisie accepte -1 et les entiers positifs', () {
      expect(validatePlanQuota('-1'), isNull);
      expect(validatePlanQuota('0'), isNull);
      expect(validatePlanQuota('50 000'), isNull);
    });

    test('la saisie refuse un négatif autre que -1', () {
      // `-5` aurait été accepté par l'ancien validateur, et `check_quota` ne
      // traite que `-1` comme illimité : toute création aurait été refusée dès
      // la première ligne, sans message compréhensible.
      expect(validatePlanQuota('-5'), isNotNull);
      expect(validatePlanQuota('-2'), isNotNull);
    });

    test('la saisie refuse ce qui n\'est pas un nombre', () {
      expect(validatePlanQuota(''), isNotNull);
      expect(validatePlanQuota(null), isNotNull);
      expect(validatePlanQuota('illimité'), isNotNull);
    });
  });

  group('Revenu récurrent', () {
    // ⚠️ CE QUI A CHANGÉ AVEC LA MIGRATION 0159. Le revenu ne peut PLUS
    // s'écrire « tarif mensuel × nombre d'abonnés » : deux groupes du même
    // plan ne paient plus le même montant, puisque le prix suit le nombre
    // d'écoles. La formule est donc calculée groupe par groupe dans le
    // provider, et `PlanDetail` la porte au lieu de la refaire.
    //
    // L'ancienne formule ne PLANTAIT pas : elle sous-estimait le revenu de la
    // plateforme d'autant que les réseaux sont grands, sans qu'aucun écran ne
    // s'en plaigne. C'est le genre d'erreur qu'on ne découvre qu'en
    // rapprochant un tableau de bord d'un relevé bancaire.
    test('il porte la somme calculée groupe par groupe', () {
      final p = _plan(subscribersActive: 4, revenu: 320000);
      expect(p.monthlyRevenue, 320000);
    });

    test('un groupe non actif ne compte pas dans le revenu', () {
      final p = _plan(priceXaf: 120000, subscribersActive: 0);
      expect(p.monthlyRevenue, 0);
    });

    test('deux groupes du même plan ne pèsent pas le même revenu', () {
      // Le fait qui a tué l'ancienne formule, écrit noir sur blanc.
      final plan = _plan(priceXaf: 30000, extra2a5: 10000, period: 'mensuel');
      expect(plan.priceFor(1), 30000);
      expect(plan.priceFor(3), 50000);
      expect(plan.priceFor(1) == plan.priceFor(3), isFalse);
    });
  });

  group('Le tarif affiché', () {
    test('dit « dès » quand le plan facture à l\'école', () {
      // Sans ce mot, le montant est faux pour tout groupe de plus d'une école.
      final parEcole = _plan(priceXaf: 30000, extra2a5: 10000, period: 'mensuel');
      final forfait = _plan(priceXaf: 30000, period: 'mensuel');
      expect(parEcole.parEcole, isTrue);
      expect(parEcole.priceLabel.startsWith('dès '), isTrue);
      expect(forfait.parEcole, isFalse);
      expect(forfait.priceLabel.startsWith('dès '), isFalse);
    });

    test('un plan gratuit ne dit jamais « dès 0 »', () {
      expect(_plan(priceXaf: 0).priceLabel, 'Gratuit');
    });
  });
}

PlanDetail _plan({
  int priceXaf = 0,
  int maxSchools = 1,
  int maxStudents = 100,
  int maxStaff = 10,
  int subscribersActive = 0,
  String period = 'annuel',
  int extra2a5 = 0,
  int revenu = 0,
}) =>
    PlanDetail(
      id: 'p1',
      name: 'Test',
      slug: 'gratuit',
      priceXaf: priceXaf,
      maxSchools: maxSchools,
      maxStudents: maxStudents,
      maxStaff: maxStaff,
      moduleCount: 7,
      billingPeriod: period,
      isPublicPlan: false,
      isActive: true,
      linkedModules: 7,
      subscribersTotal: subscribersActive,
      subscribersActive: subscribersActive,
      extra2a5: extra2a5,
      activeMonthlyRevenue: revenu,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
