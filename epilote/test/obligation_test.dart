import 'package:epilote/features/finance/services/obligation.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CE QUE L'ÉLÈVE DOIT (spec §6.5, §5.7)
//
//  « Élèves à jour » comptait tout élève ayant versé AU MOINS UN FRANC. Un
//  élève qui verse 1 000 sur 90 000 était compté à jour, parce qu'aucun
//  montant dû n'existait nulle part.
//
//  Le dû se déduit des barèmes applicables. Trois cas seulement pour les
//  8 130 élèves du public — inscription, cotisation APE, frais d'examen — qui
//  se règlent en une fois. La mensualité, qui n'existe que dans le privé
//  (974 élèves), s'échelonne sur les mois écoulés : aucune table d'échéances.
// ════════════════════════════════════════════════════════════════════════════

void main() {
  group('dû d\'un barème', () {
    test('un frais unique est dû en entier dès le premier jour', () {
      for (final t in [
        'inscription',
        'cotisation_ape',
        'frais_examens',
        'autre'
      ]) {
        expect(duPourBareme(feeType: t, montant: 5000, moisEcoules: 1), 5000,
            reason: '$t se règle en une fois');
      }
    });

    test('une mensualité s\'accumule mois après mois', () {
      expect(duPourBareme(feeType: 'mensualite', montant: 25000, moisEcoules: 1),
          25000);
      expect(duPourBareme(feeType: 'mensualite', montant: 25000, moisEcoules: 4),
          100000);
    });

    test('une mensualité avant le début de l\'année ne doit rien', () {
      expect(duPourBareme(feeType: 'mensualite', montant: 25000, moisEcoules: 0),
          0);
    });
  });

  group('mois dus — sans fenêtre de présence, c\'est le compteur de l\'année',
      () {
    final debut = DateTime(2025, 10, 1);
    final fin = DateTime(2026, 7, 31);

    int mois(DateTime maintenant) =>
        moisDus(debutAnnee: debut, finAnnee: fin, maintenant: maintenant);

    test('le premier mois compte dès la rentrée', () {
      expect(mois(DateTime(2025, 10, 2)), 1);
    });

    test('quatre mois début janvier', () {
      expect(mois(DateTime(2026, 1, 5)), 4);
    });

    test('avant la rentrée, rien n\'est dû', () {
      expect(mois(DateTime(2025, 8, 30)), 0);
    });

    test('après la fin, le compteur se fige sur l\'année entière', () {
      // Sans plafond, un dossier consulté en 2030 réclamerait 60 mensualités.
      expect(mois(DateTime(2030, 1, 1)), 10);
    });
  });

  group('mois dus — la fenêtre de présence de L\'ÉLÈVE', () {
    final debut = DateTime(2025, 10, 1);
    final fin = DateTime(2026, 7, 31);

    int mois(DateTime maintenant, {DateTime? entree, DateTime? sortie}) =>
        moisDus(
          debutAnnee: debut,
          finAnnee: fin,
          maintenant: maintenant,
          entree: entree,
          sortie: sortie,
        );

    test('un élève arrivé en mars ne doit pas les mois qu\'il n\'a pas vécus',
        () {
      // LE défaut corrigé : le compteur d'année réclamait 6 mois (oct→mars) à
      // un enfant qui posait son cartable ce jour-là. À 25 000 F la mensualité,
      // il apparaissait débiteur de 150 000 F le jour de son inscription.
      expect(mois(DateTime(2026, 3, 10), entree: DateTime(2026, 3, 2)), 1);
      expect(mois(DateTime(2026, 3, 10)), 6, reason: 'le compteur d\'année');
    });

    test('le mois d\'arrivée compte pour un mois entier', () {
      // Personne ne facture à la semaine : arriver le 28 mars doit mars.
      expect(mois(DateTime(2026, 3, 30), entree: DateTime(2026, 3, 28)), 1);
    });

    test('puis la dette avance normalement', () {
      expect(mois(DateTime(2026, 6, 4), entree: DateTime(2026, 3, 2)), 4);
    });

    test('une entrée AVANT la rentrée est ignorée', () {
      // Cas normal d'une réinscription saisie en août pour une année qui
      // commence en octobre : la prendre au mot ferait payer deux mois où
      // l'école était fermée.
      expect(mois(DateTime(2025, 10, 5), entree: DateTime(2025, 8, 20)), 1);
    });

    test('un élève parti en décembre cesse d\'accumuler', () {
      // Avant : sa dette grossissait toute seule jusqu'en juillet, sept mois
      // après son départ.
      expect(
        mois(DateTime(2026, 6, 1), sortie: DateTime(2025, 12, 15)),
        3,
        reason: 'octobre, novembre, décembre',
      );
    });

    test('le mois de départ compte, comme celui d\'arrivée', () {
      expect(
        mois(DateTime(2026, 6, 1),
            entree: DateTime(2026, 1, 20), sortie: DateTime(2026, 1, 25)),
        1,
      );
    });

    test('une sortie antérieure à l\'entrée ne doit rien — jamais de négatif',
        () {
      expect(
        mois(DateTime(2026, 6, 1),
            entree: DateTime(2026, 3, 1), sortie: DateTime(2026, 1, 1)),
        0,
      );
    });

    test('le plafond de fin d\'année tient aussi avec une entrée tardive', () {
      expect(
        mois(DateTime(2030, 1, 1), entree: DateTime(2026, 5, 3)),
        3,
        reason: 'mai, juin, juillet — puis l\'année s\'arrête',
      );
    });
  });

  group('état d\'un élève', () {
    test('sans barème, on ne peut RIEN dire — surtout pas « à jour »', () {
      // 30 écoles publiques n'ont aucun barème : les déclarer à jour serait
      // aussi faux que de les déclarer débitrices.
      expect(etatObligation(du: 0, verse: 0), EtatObligation.sansBareme);
      expect(etatObligation(du: 0, verse: 5000), EtatObligation.sansBareme);
    });

    test('rien versé sur un dû : impayé', () {
      expect(etatObligation(du: 5000, verse: 0), EtatObligation.impaye);
    });

    test('une avance n\'est PAS être à jour', () {
      // Le défaut historique : 2 000 sur 5 000 comptait comme réglé.
      expect(etatObligation(du: 5000, verse: 2000), EtatObligation.partiel);
    });

    test('le compte exact est à jour', () {
      expect(etatObligation(du: 5000, verse: 5000), EtatObligation.aJour);
    });

    test('un trop-versé reste à jour — le dépassement se traite ailleurs', () {
      expect(etatObligation(du: 5000, verse: 7000), EtatObligation.aJour);
    });

    test('DEUX dûs nuls qui ne veulent pas dire la même chose', () {
      // Sans tarif publié, on ne peut RIEN affirmer. Avec un tarif
      // intégralement remis, on peut affirmer qu'il n'y a rien à réclamer.
      // Les confondre — ce que faisait la version précédente — envoyait la
      // caisse chercher un barème à propos d'un boursier, et affichait
      // « Barème non défini » sur un dossier parfaitement tarifé.
      expect(etatObligation(du: 0, verse: 0), EtatObligation.sansBareme);
      expect(etatObligation(du: 0, verse: 0, exonereTotal: true),
          EtatObligation.exonere);
    });

    test('une exonération PARTIELLE laisse les états ordinaires', () {
      // 50 % de 15 000 : l'élève doit 7 500 et n'a rien versé. C'est un impayé
      // comme un autre — l'exonération a déjà fait son office dans le montant.
      expect(etatObligation(du: 7500, verse: 0), EtatObligation.impaye);
      expect(etatObligation(du: 7500, verse: 7500), EtatObligation.aJour);
    });
  });

  group('libellés', () {
    test('chaque état a un libellé lisible', () {
      for (final e in EtatObligation.values) {
        expect(libelleEtat(e), isNotEmpty);
      }
    });
  });
}
