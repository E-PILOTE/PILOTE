import 'dart:io';

import 'package:epilote/features/tutelle/providers/tutelle_filtres.dart';
import 'package:epilote/features/tutelle/providers/tutelle_reseau_provider.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CE QU'UN MINISTÈRE LIT DE SON RÉSEAU
//
//  Ces fonctions décident des chiffres qu'une tutelle prend pour vrais. Une
//  erreur ici ne se voit pas : elle produit un nombre plausible, et ce nombre
//  finit dans un état ministériel. D'où des tests sur la logique NUE, sans
//  Flutter et sans réseau.
// ════════════════════════════════════════════════════════════════════════════

TutelleEcole _ecole({
  required String id,
  String groupId = 'G1',
  String groupeNom = 'Groupe A',
  String nom = 'École',
  String secteur = 'prive',
  String? dept = 'Brazzaville',
  String? typeCourt = 'CEG',
  String? agrement,
  int eleves = 100,
  int filles = 40,
  int? capacite,
  bool actif = true,
}) =>
    TutelleEcole(
      id: id,
      groupId: groupId,
      groupeNom: groupeNom,
      nom: nom,
      secteur: secteur,
      departement: dept,
      typeEtablissementCourt: typeCourt,
      agrementNumero: agrement,
      agrementType: agrement == null ? null : 'provisoire',
      nbEleves: eleves,
      nbFilles: filles,
      nbPersonnel: 10,
      nbClasses: 5,
      capacite: capacite,
      actif: actif,
    );

void main() {
  group('Filtres', () {
    final reseau = [
      _ecole(id: '1', secteur: 'public', dept: 'Pool', agrement: 'A-1'),
      _ecole(id: '2', nom: 'Sainte-Marie', typeCourt: 'CET'),
      _ecole(id: '3', groupId: 'G2', groupeNom: 'Groupe B', dept: 'Niari'),
      _ecole(id: '4', actif: false),
    ];

    test('sans filtre, tout passe', () {
      expect(filtrerEcoles(reseau, const FiltreReseau()).length, 4);
      expect(const FiltreReseau().estVierge, isTrue);
    });

    test('le secteur, le département et le type filtrent', () {
      expect(
          filtrerEcoles(reseau, const FiltreReseau(secteur: 'public')).length, 1);
      expect(
          filtrerEcoles(reseau, const FiltreReseau(departement: 'Niari')).length,
          1);
      expect(
          filtrerEcoles(reseau, const FiltreReseau(typeEtablissement: 'CET'))
              .length,
          1);
    });

    test('l\'agrément a trois états, et « non déclaré » n\'accuse personne', () {
      expect(
          filtrerEcoles(reseau, const FiltreReseau(agrement: FiltreAgrement.declare))
              .length,
          1);
      expect(
          filtrerEcoles(
                  reseau, const FiltreReseau(agrement: FiltreAgrement.nonDeclare))
              .length,
          3);
      // L'énumération n'a PAS de valeur « nonAgree » : la plateforme n'instruit
      // aucun dossier, elle ne peut donc pas conclure qu'une école ne l'est pas.
      expect(FiltreAgrement.values.length, 3);
    });

    test('la recherche porte sur le nom, le code, la ville et le groupe', () {
      expect(filtrerEcoles(reseau, const FiltreReseau(recherche: 'sainte')).length,
          1);
      expect(
          filtrerEcoles(reseau, const FiltreReseau(recherche: 'Groupe B')).length,
          1);
    });

    // ⚠️ LE TEST QUI A MOTIVÉ LA SENTINELLE. Avec un `??` dans copyWith,
    // repasser un filtre à « tous » était IMPOSSIBLE : `null` se lisait comme
    // « ne change rien », et l'écran restait bloqué sur le dernier choix.
    test('copyWith sait remettre un filtre à « tous »', () {
      const pose = FiltreReseau(secteur: 'public', departement: 'Pool');
      final relache = pose.copyWith(secteur: null, departement: null);
      expect(relache.secteur, isNull);
      expect(relache.departement, isNull);
      // …sans effacer ce qu'on n'a pas touché.
      final autre = pose.copyWith(recherche: 'x');
      expect(autre.secteur, 'public');
    });
  });

  group('Bilan', () {
    test('les totaux se recalculent sur la SÉLECTION, pas sur le réseau', () {
      final tout = [
        _ecole(id: '1', eleves: 100, filles: 60),
        _ecole(id: '2', eleves: 200, filles: 40, secteur: 'public'),
      ];
      final b = BilanReseau.de(
          filtrerEcoles(tout, const FiltreReseau(secteur: 'public')));
      expect(b.nbEcoles, 1);
      expect(b.nbEleves, 200);
      expect(b.partFilles!.round(), 20);
    });

    test('aucun élève → part de filles nulle, jamais 0 %', () {
      final b = BilanReseau.de([_ecole(id: '1', eleves: 0, filles: 0)]);
      // 0 % se lirait « aucune fille » ; l'absence de donnée n'est pas zéro.
      expect(b.partFilles, isNull);
    });

    // ⚠️ LE PIÈGE. Diviser l'effectif COMPLET par une capacité PARTIELLE donne
    // un taux au-dessus de 100 % qui ressemble à une école surchargée.
    test('le taux d\'occupation ne mélange pas les périmètres', () {
      final b = BilanReseau.de([
        _ecole(id: '1', eleves: 90, capacite: 100), // capacité connue
        _ecole(id: '2', eleves: 500), // capacité inconnue
      ]);
      expect(b.nbEleves, 590);
      expect(b.capaciteTotale, 100);
      // 90 / 100, et non 590 / 100.
      expect(b.tauxOccupation, 90);
      expect(b.capaciteComplete, isFalse);
      expect(b.nbCapaciteConnue, 1);
    });

    test('aucune capacité renseignée → pas de taux du tout', () {
      final b = BilanReseau.de([_ecole(id: '1', eleves: 50)]);
      expect(b.tauxOccupation, isNull);
    });

    test('les groupes sont comptés une fois, pas une par école', () {
      final b = BilanReseau.de([
        _ecole(id: '1', groupId: 'G1'),
        _ecole(id: '2', groupId: 'G1'),
        _ecole(id: '3', groupId: 'G2'),
      ]);
      expect(b.nbEcoles, 3);
      expect(b.nbGroupes, 2);
    });
  });

  group('Listes de choix', () {
    test('ne proposent que ce qui existe', () {
      final r = [
        _ecole(id: '1', dept: 'Pool', typeCourt: 'CEG'),
        _ecole(id: '2', dept: 'Pool', typeCourt: null),
        _ecole(id: '3', dept: null, typeCourt: 'CET'),
      ];
      // Un menu qui propose un choix ne rendant rien fait douter de la donnée.
      expect(departementsDe(r), ['Pool']);
      expect(typesEtablissementDe(r), ['CEG', 'CET']);
    });
  });

  // ── Le garde qui compte vraiment ──────────────────────────────────────────
  group('La ligne qui ne doit pas bouger', () {
    test('les RPC de tutelle ne rendent aucune donnée nominative d\'élève', () {
      final f = File('../database/migrations/'
          '0158_AVANT_LE_BUILD_lagrement_du_groupe_et_la_vue_de_tutelle.sql');
      expect(f.existsSync(), isTrue,
          reason: 'Sonde aveugle : la migration 0158 est introuvable.');
      final sql = f.readAsStringSync().replaceAll('\r\n', '\n');

      // La décision : ÉTABLISSEMENTS en clair, PERSONNES en agrégats. La seule
      // exception nominative est le chef d'établissement, lu sur `profiles`.
      // Toute lecture de colonne nominative de `students` la violerait.
      final corps = sql.substring(sql.indexOf('tutelle_groupes'));
      for (final interdit in [
        'st.first_name',
        'st.last_name',
        'st.matricule',
        'st.birth_date',
        'st.ine',
      ]) {
        expect(corps.contains(interdit), isFalse,
            reason: 'La RPC de tutelle expose « $interdit » : un ministère '
                'supervise des établissements, il ne tient pas le registre '
                'nominatif du pays.');
      }
      // Et rien sur l'abonnement : ce qu'un groupe privé paie à E-PILOTE ne
      // regarde pas son ministère.
      for (final interdit in ['plan_id', 'subscription_status', 'price_xaf']) {
        expect(corps.contains(interdit), isFalse,
            reason: 'La RPC de tutelle expose « $interdit ».');
      }
    });
  });
}
