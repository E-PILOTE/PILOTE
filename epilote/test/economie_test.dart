import 'dart:io';

import 'package:epilote/features/super_admin/providers/economie_provider.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CE QUI RENTRE, CE QUI SORT
//
//  Ces nombres servent à fixer des prix. Une erreur ici ne plante pas : elle
//  produit une marge plausible, et un tarif se décide dessus.
//
//  Coûts réels relevés le 2026-08-31 : Supabase Pro 25 $/mois, PowerSync Cloud
//  Pro 49 $/mois (30 Go et 1 000 clients simultanés inclus).
//
//  Depuis le recentrage privé (2026-10-21), tout le revenu récurrent vient des
//  abonnements des groupes privés : les licences de tutelle ont disparu.
// ════════════════════════════════════════════════════════════════════════════

CoutPlateforme _cout({
  int montant = 15250,
  String periodicite = 'mensuel',
  bool actif = true,
}) =>
    CoutPlateforme(
      id: 'c1',
      label: 'Supabase Pro',
      categorie: 'base_de_donnees',
      montantXaf: montant,
      periodicite: periodicite,
      isActive: actif,
    );

void main() {
  group('Le coût d\'exploitation', () {
    test('se ramène au mois quelle que soit sa périodicité', () {
      expect(_cout(montant: 15250).mensuelXaf, 15250);
      expect(_cout(montant: 120000, periodicite: 'annuel').mensuelXaf, 10000);
      expect(_cout(montant: 30000, periodicite: 'trimestriel').mensuelXaf, 10000);
    });

    test('un coût inactif ne pèse plus', () {
      final d = EconomieData(
          couts: [_cout(montant: 15250, actif: false)], mrrAbonnementsXaf: 0);
      expect(d.coutMensuelXaf, 0);
    });
  });

  group('La marge', () {
    test('rapproche les abonnements et les coûts', () {
      final d = EconomieData(
        couts: [_cout(montant: 15250), _cout(montant: 29890)],
        mrrAbonnementsXaf: 500000,
      );
      expect(d.coutMensuelXaf, 45140); // Supabase + PowerSync
      expect(d.mrrTotalXaf, 500000);
      expect(d.margeMensuelleXaf, 500000 - 45140);
    });

    // ⚠️ Une marge de « -100 % » sur zéro recette est un chiffre qui n'apprend
    // rien et alarme pour rien.
    test('n\'a pas de taux sans recette', () {
      final d = EconomieData(couts: [_cout()], mrrAbonnementsXaf: 0);
      expect(d.tauxMarge, isNull);
      expect(d.margeMensuelleXaf, -15250);
    });

    test('le seuil dit combien de clients couvrent l\'infrastructure', () {
      // Le nombre le plus parlant du tableau : ce n'est pas une projection,
      // c'est le seuil de survie.
      final d = EconomieData(
        couts: [_cout(montant: 15250), _cout(montant: 29890)],
        mrrAbonnementsXaf: 0,
      );
      // 45 140 / 30 000 → 2 groupes mono-école sur le plan Standard.
      expect(d.seuilEnGroupes(30000), 2);
      // Un prix nul ne doit pas faire diviser par zéro.
      expect(d.seuilEnGroupes(0), 0);
    });
  });

  // ── Le garde qui compte vraiment ──────────────────────────────────────────
  group('Ce que la base protège', () {
    test('les coûts de la plateforme sont fermés au super_admin seul', () {
      // Donnée de FONDATEUR. Qu'un groupe scolaire puisse lire ce que coûte
      // l'infrastructure — et donc en déduire la marge prise sur lui — serait
      // une fuite dont personne ne verrait jamais la trace.
      final f = File('../database/migrations/'
          '0160_AVANT_LE_BUILD_la_licence_annuelle_et_le_cout_reel.sql');
      expect(f.existsSync(), isTrue,
          reason: 'Sonde aveugle : la migration 0160 est introuvable.');
      final sql = f.readAsStringSync().replaceAll('\r\n', '\n');

      final bloc = sql.substring(
          sql.indexOf('CREATE POLICY platform_costs_super_admin'));
      final fin = bloc.indexOf(';');
      final policy = bloc.substring(0, fin);
      expect(policy.contains('is_super_admin()'), isTrue);
      expect(policy.contains('auth_group_id'), isFalse,
          reason: 'Aucune ouverture à un groupe sur les coûts de la plateforme.');

      // Et aucune autre politique ne doit exister sur cette table.
      final autres = RegExp(r'CREATE POLICY\s+(\w+)\s+ON\s+public\.platform_costs')
          .allMatches(sql)
          .map((m) => m.group(1))
          .toList();
      expect(autres, ['platform_costs_super_admin']);
    });
  });
}
