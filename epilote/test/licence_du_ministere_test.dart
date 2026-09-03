import 'dart:io';

import 'package:epilote/core/constants/licence_statut.dart';
import 'package:epilote/features/admin_groupe/providers/admin_licence_provider.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  UN MINISTÈRE N'A PAS D'ÉCHÉANCE D'ABONNEMENT
//
//  0182 a sorti les deux ministères de la formule mensuelle et mis leur
//  `subscription_end` à NULL. Ce fichier garde ce NULL, parce que la valeur
//  seule ne tenait pas : CINQ chemins d'écriture la réinstallaient.
//
//  ── ⚠️ CE QUI EST EN JEU, MESURÉ ──────────────────────────────────────────
//  Rendre la date, c'est relancer toute la cascade d'abonnement sur l'État :
//    • `emit_subscription_reminders` notifie « votre abonnement expire dans
//      30 jours » à l'admin du ministère ;
//    • `expire_subscriptions` bascule le groupe en `expired` ;
//    • 15 jours plus tard, `computeSubscriptionAccess` rend `readOnly` — le
//      ministère de l'Éducation nationale ET tout son réseau en lecture seule,
//      pour une date de facturation.
//  Les quatre gardes ci-dessous ignorent un `subscription_end` nul : c'est la
//  SEULE chose qui protège un ministère aujourd'hui.
//
//  ── LES CINQ CHEMINS, TOUS VÉRIFIÉS EN PRODUCTION AVANT 0183 ──────────────
//   1. `fn_set_trial_window` — l'écran de création envoie `'trial'` : tout
//      nouveau ministère naissait avec une période d'essai.
//   2. `fn_auto_create_invoice` — plan à 0 XAF ⇒ échéance à +12 mois.
//   3. `fn_guard_active_requires_payment` — plan gratuit ⇒ il en fabrique une.
//   4. `create_renewal_invoice` — le bouton « Renouveler mon abonnement ».
//   5. Toute écriture manuelle sur la colonne.
// ════════════════════════════════════════════════════════════════════════════

const _migration =
    '../database/migrations/0183_AVANT_LE_BUILD_le_terme_dun_ministere_est_sa_licence.sql';
const _ecran =
    'lib/features/admin_groupe/screens/admin_subscription_screen.dart';
const _carte = 'lib/features/admin_groupe/screens/admin_licence_card.dart';
const _nav = 'lib/core/widgets/app_shell/nav_config.dart';
const _economie = 'lib/features/super_admin/screens/economie_screen.dart';
const _dialogue =
    'lib/features/super_admin/screens/economie/licence_form_dialog.dart';

String _lire(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) fail('Fichier introuvable : $chemin — sonde aveugle.');
  return f.readAsStringSync();
}

LicenceDuGroupe _licence({
  int montant = 18000000,
  int avance = 0,
  int regle = 0,
  String statut = 'active',
  int finDansJours = 200,
  String? reference,
  String? signataire,
}) =>
    LicenceDuGroupe(
      id: 'l1',
      intitule: 'Licence annuelle de tutelle',
      dateDebut: DateTime.now().subtract(const Duration(days: 30)),
      dateFin: DateTime.now().add(Duration(days: finDansJours)),
      montantXaf: montant,
      avanceXaf: avance,
      montantRegleXaf: regle,
      statut: statut,
      referenceMarche: reference,
      signataire: signataire,
    );

void main() {
  group('Le statut de licence n’a plus qu’un seul vocabulaire', () {
    test('les quatre valeurs sont celles de l’énumération en base', () {
      expect(kStatutsLicence, ['brouillon', 'active', 'echue', 'resiliee']);
    });

    test('une valeur inconnue ne devient pas « Brouillon »', () {
      // ⚠️ Retomber sur « Brouillon » afficherait qu'un marché SIGNÉ ne l'est
      // pas — la pire des quatre erreurs possibles.
      expect(libelleStatutLicence('active'), 'Active');
      expect(libelleStatutLicence('bidon'), isNull);
      expect(libelleStatutLicence(null), isNull);
      expect(libelleStatutLicenceOuTiret('bidon'), '—');
      expect(statutLicenceConnu('echue'), isTrue);
      expect(statutLicenceConnu('expiree'), isFalse);
    });

    test('« en vigueur » ne vaut que pour active', () {
      // Sert de base au revenu (mensuelCompte) : un brouillon n'est pas un
      // revenu, une licence résiliée encore moins.
      expect(licenceEnVigueur('active'), isTrue);
      for (final s in ['brouillon', 'echue', 'resiliee', null]) {
        expect(licenceEnVigueur(s), isFalse);
      }
    });

    test('les deux écrans du fondateur lisent le référentiel', () {
      final eco = _lire(_economie);
      expect(eco.contains('libelleStatutLicenceOuTiret('), isTrue,
          reason: 'Le vocabulaire local est revenu dans Économie : il pourra '
              'diverger de celui de la base et du ministère.');
      expect(eco.contains("'resiliee' => 'RÉSILIÉE'"), isFalse);
      expect(_lire(_dialogue).contains('for (final st in kStatutsLicence)'),
          isTrue,
          reason: 'Le menu de saisie a repris une liste écrite à la main : '
              'une valeur ajoutée en base n’y apparaîtra pas.');
    });
  });

  group('Ce qu’un ministère lit de son contrat', () {
    test('le solde est ce qui reste dû, pas ce qui est payé', () {
      final l = _licence(montant: 18000000, avance: 5000000, regle: 5000000);
      expect(l.soldeXaf, 13000000);
      expect(l.soldee, isFalse);
      expect(_licence(montant: 900000, regle: 900000).soldee, isTrue);
    });

    test('une licence à titre gracieux n’est pas « réglée à 0 % »', () {
      // ⚠️ `null`, pas `0.0` : afficher une barre vide sur un marché sans
      // montant laisserait croire à un impayé.
      expect(_licence(montant: 0).partReglee, isNull);
      expect(_licence(montant: 1000, regle: 250).partReglee, 0.25);
      // Un règlement supérieur au dû ne dépasse pas 100 %.
      expect(_licence(montant: 1000, regle: 4000).partReglee, 1.0);
      expect(_licence(montant: 1000, regle: 4000).soldeXaf, -3000);
    });

    test('le terme se compte en jours civils', () {
      expect(_licence(finDansJours: 200).echue, isFalse);
      expect(_licence(finDansJours: -3).echue, isTrue);
      expect(_licence(finDansJours: -3).joursRestants, -3);
    });
  });

  group('Laquelle des licences on montre', () {
    test('aucune licence ⇒ rien, et surtout pas une erreur', () {
      expect(licenceAMontrer(const []), isNull);
    });

    test('celle qui couvre aujourd’hui passe avant la plus récente', () {
      final ancienneActive = _licence(finDansJours: 100);
      final futurBrouillon = _licence(statut: 'brouillon', finDansJours: 900);
      expect(licenceAMontrer([futurBrouillon, ancienneActive]),
          same(ancienneActive),
          reason: 'Un brouillon signé pour l’an prochain masquerait le marché '
              'en cours d’exécution.');
    });

    test('sans licence en vigueur, on montre l’échue — pas rien', () {
      // Une licence expirée est précisément ce qu'il faut voir : elle appelle
      // un avenant.
      final echue = _licence(statut: 'echue', finDansJours: -40);
      final vieille = _licence(statut: 'echue', finDansJours: -400);
      expect(licenceAMontrer([vieille, echue]), same(echue));
    });

    test('une « active » dont le terme est passé ne masque pas le reste', () {
      // Le statut n'est pas rafraîchi automatiquement pour un ministère (rien
      // ne l'expire) : la date tranche.
      final activePerimee = _licence(finDansJours: -10);
      final brouillonCourant = _licence(statut: 'brouillon', finDansJours: 50);
      expect(licenceAMontrer([activePerimee, brouillonCourant]),
          same(brouillonCourant),
          reason: 'Une licence « active » périmée depuis 10 jours a été '
              'préférée à celle qui couvre aujourd’hui.');
    });
  });

  group('La base referme les cinq chemins', () {
    test('le déclencheur écoute TOUTE mise à jour, plus deux colonnes', () {
      final sql = _lire(_migration);
      expect(sql.contains('BEFORE INSERT OR UPDATE\n  ON public.school_groups'),
          isTrue,
          reason: 'Le déclencheur est redevenu sélectif : une échéance écrite '
              'par une autre colonne — ou par le UPDATE d’un déclencheur AFTER '
              '— passerait dessous.');
    });

    test('il NORMALISE au lieu de refuser', () {
      // Une exception ferait échouer la création d'un groupe parfaitement
      // légitime : personne ne « demande » cette date, ce sont des
      // automatismes de facturation qui la posent.
      final sql = _lire(_migration);
      expect(sql.contains('NEW.subscription_end := NULL;'), isTrue);
    });

    test('un ministère ne naît pas en période d’essai', () {
      final sql = _lire(_migration);
      expect(
          sql.contains(
              "NEW.subscription_status := 'active'::subscription_status;"),
          isTrue);
      expect(sql.contains('CREATE OR REPLACE FUNCTION public.fn_set_trial_window'),
          isTrue,
          reason: 'fn_set_trial_window n’est plus corrigée : l’écran de '
              'création envoie « trial » pour tout le monde.');
    });

    test('les trois autres fonctions savent s’abstenir', () {
      final sql = _lire(_migration);
      for (final fn in [
        'public.fn_auto_create_invoice',
        'public.fn_guard_active_requires_payment',
        'public.create_renewal_invoice',
      ]) {
        expect(sql.contains('CREATE OR REPLACE FUNCTION $fn'), isTrue,
            reason: '$fn ne traite plus le cas du ministère : elle réinstallera '
                'une échéance.');
      }
      expect(
          'administre_referentiel_national, false)'.allMatches(sql).length >= 3,
          isTrue,
          reason: 'Les gardes testent le drapeau de ministère moins de trois '
              'fois : l’un des chemins est resté ouvert.');
    });

    test('le renouvellement en libre-service est refusé, avec un pourquoi', () {
      final sql = _lire(_migration);
      expect(
          sql.contains('Un ministere de tutelle ne renouvelle pas un abonnement'),
          isTrue);
      // Le HINT est ce que `message_erreur.dart` affiche mot pour mot.
      expect(sql.contains('licence de tutelle, dont le '), isTrue);
    });

    test('la migration vérifie l’invariant avant de rendre la main', () {
      final sql = _lire(_migration);
      expect(sql.contains('Invariant viole'), isTrue,
          reason: 'La migration peut désormais laisser un ministère avec une '
              'échéance sans que rien ne le signale.');
    });
  });

  group('L’écran ne propose plus ce que la base refuse', () {
    test('la page change de nature, pas seulement de titre', () {
      final src = _lire(_ecran);
      expect(src.contains('LicenceDeTutelleSection(sub: sub)'), isTrue);
      expect(src.contains("estMinistere ? 'Licence de tutelle' : 'Abonnement'"),
          isTrue);
    });

    test('ni comparateur, ni demande de plan, ni renouvellement', () {
      final src = _lire(_ecran);
      expect(src.contains('if (!sub.estMinistere)\n                    '
          '_MecaniqueAbonnement(data: data, sub: sub),'), isTrue,
          reason: 'La grille des offres est revenue pour un ministère : la '
              'base refuse ces plans depuis 0182.');
      // Le bouton « Renouveler » vit dans _CurrentPlanCard, qui n'est plus
      // construite pour un ministère — la sonde garde la bifurcation.
      expect(src.contains('if (sub.estMinistere)\n                    '
          'LicenceDeTutelleSection(sub: sub)\n                  else\n'
          '                    _CurrentPlanCard(sub: sub),'), isTrue);
    });

    test('la carte dit que l’accès ne dépend pas de la licence', () {
      // Contrainte C4 du 0160. Sans cette phrase, un solde affiché se lit
      // comme une menace de coupure — et c'est l'État qu'on menace.
      final src = _lire(_carte);
      expect(src.contains('Votre accès ne dépend pas de cette licence'), isTrue);
    });

    test('la carte DIT l’échec au lieu d’afficher « aucune licence »', () {
      final src = _lire(_carte);
      expect(src.contains('_Incident(erreur: e)'), isTrue,
          reason: 'Une requête ratée ferait croire à un ministère que son '
              'marché n’est pas enregistré.');
    });

    test('la barre latérale dit « Licence », pas « Abonnement »', () {
      final src = _lire(_nav);
      expect(src.contains("estTutelle ? 'Licence' : 'Abonnement'"), isTrue);
    });
  });
}
