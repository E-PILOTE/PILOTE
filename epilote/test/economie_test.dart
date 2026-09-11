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
// ════════════════════════════════════════════════════════════════════════════

LicenceTutelle _licence({
  int montant = 18000000,
  int regle = 0,
  String statut = 'active',
  DateTime? debut,
  DateTime? fin,
}) =>
    LicenceTutelle(
      id: 'l1',
      groupId: 'g1',
      groupeNom: 'METP',
      tutelle: 'metp',
      intitule: 'Licence annuelle de tutelle',
      dateDebut: debut ?? DateTime(2026, 1, 1),
      dateFin: fin ?? DateTime(2026, 12, 31),
      montantXaf: montant,
      avanceXaf: 0,
      montantRegleXaf: regle,
      statut: statut,
    );

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
  group('Une licence annuelle', () {
    test('se ramène au mois pour être comparable au reste', () {
      // ⚠️ Une licence annuelle de 18 M et un abonnement mensuel de 30 000 ne
      // s'additionnent pas bruts. Tout passe au mois d'abord.
      final l = _licence(montant: 18000000);
      expect(l.moisCouverts, 12);
      expect(l.mensuelXaf, 1500000);
    });

    test('ne compte dans le revenu que si elle est ACTIVE', () {
      // Un brouillon n'est pas une recette, une licence résiliée encore moins.
      expect(_licence(statut: 'brouillon').mensuelCompte, 0);
      expect(_licence(statut: 'resiliee').mensuelCompte, 0);
      expect(_licence(statut: 'echue').mensuelCompte, 0);
      expect(_licence(statut: 'active').mensuelCompte, 1500000);
    });

    test('ne divise jamais par zéro mois', () {
      final l = _licence(
          debut: DateTime(2026, 1, 1), fin: DateTime(2026, 1, 5), montant: 90000);
      expect(l.moisCouverts, 1);
      expect(l.mensuelXaf, 90000);
    });

    test('le solde dû est le montant moins l\'encaissé', () {
      // Un marché public se règle en tranches : trois nombres, pas un.
      expect(_licence(montant: 18000000, regle: 6000000).soldeXaf, 12000000);
      expect(_licence(montant: 18000000, regle: 18000000).soldeXaf, 0);
    });
  });

  group('Le coût d\'exploitation', () {
    test('se ramène au mois quelle que soit sa périodicité', () {
      expect(_cout(montant: 15250).mensuelXaf, 15250);
      expect(_cout(montant: 120000, periodicite: 'annuel').mensuelXaf, 10000);
      expect(_cout(montant: 30000, periodicite: 'trimestriel').mensuelXaf, 10000);
    });

    test('un coût inactif ne pèse plus', () {
      final d = EconomieData(
          couts: [_cout(montant: 15250, actif: false)],
          licences: const [],
          mrrAbonnementsXaf: 0);
      expect(d.coutMensuelXaf, 0);
    });
  });

  group('La marge', () {
    test('rapproche les trois sources', () {
      final d = EconomieData(
        couts: [_cout(montant: 15250), _cout(montant: 29890)],
        licences: [_licence(montant: 18000000)],
        mrrAbonnementsXaf: 500000,
      );
      expect(d.coutMensuelXaf, 45140); // Supabase + PowerSync
      expect(d.mrrLicencesXaf, 1500000);
      expect(d.mrrTotalXaf, 2000000);
      expect(d.margeMensuelleXaf, 2000000 - 45140);
    });

    // ⚠️ Une marge de « -100 % » sur zéro recette est un chiffre qui n'apprend
    // rien et alarme pour rien.
    test('n\'a pas de taux sans recette', () {
      final d = EconomieData(
          couts: [_cout()], licences: const [], mrrAbonnementsXaf: 0);
      expect(d.tauxMarge, isNull);
      expect(d.margeMensuelleXaf, -15250);
    });

    test('le seuil dit combien de clients couvrent l\'infrastructure', () {
      // Le nombre le plus parlant du tableau : ce n'est pas une projection,
      // c'est le seuil de survie.
      final d = EconomieData(
        couts: [_cout(montant: 15250), _cout(montant: 29890)],
        licences: const [],
        mrrAbonnementsXaf: 0,
      );
      // 45 140 / 30 000 → 2 groupes mono-école sur le plan Standard.
      expect(d.seuilEnGroupes(30000), 2);
      // Un prix nul ne doit pas faire diviser par zéro.
      expect(d.seuilEnGroupes(0), 0);
    });

    test('le solde dû ne compte que les licences actives', () {
      final d = EconomieData(
        couts: const [],
        licences: [
          _licence(montant: 18000000, regle: 6000000),
          _licence(montant: 48000000, statut: 'brouillon'),
        ],
        mrrAbonnementsXaf: 0,
      );
      expect(d.soldeDuXaf, 12000000);
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

    test('une licence de tutelle n\'ouvre aucun accès', () {
      // On ne ferme pas l'État pour un mandat en retard — et un logiciel qui
      // se venge d'un impayé perd le client ET le marché.
      final sql = File('../database/migrations/'
              '0160_AVANT_LE_BUILD_la_licence_annuelle_et_le_cout_reel.sql')
          .readAsStringSync().replaceAll('\r\n', '\n');
      expect(sql.contains('N\'OUVRE NI NE FERME AUCUN ACCÈS') ||
              sql.contains('NE COMMANDE RIEN'),
          isTrue,
          reason: 'La migration doit dire explicitement que la licence ne '
              'commande aucun accès.');
      // La vue de tutelle reste commandée par le drapeau de la 0155.
      expect(sql.contains('administre_referentiel_national'), isTrue);
    });
  });
}
