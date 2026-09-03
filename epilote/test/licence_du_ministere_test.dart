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
const _tableauDeBord =
    'lib/features/admin_groupe/screens/admin_dashboard_screen.dart';
const _fiche = 'lib/features/admin_groupe/screens/admin_settings_screen.dart';
const _groupes =
    'lib/features/super_admin/providers/school_groups_provider.dart';
const _couverture =
    'lib/features/admin_groupe/screens/admin_licence_couverture.dart';
const _formulaireLicence =
    'lib/features/super_admin/screens/economie/licence_form_dialog.dart';
const _migrationRpc =
    '../database/migrations/0184_AVANT_LE_BUILD_reconnaitre_un_ministere_dans_la_messagerie.sql';
const _messagerie =
    'lib/features/communication/screens/messagerie_staff.dart';
const _inbox =
    'lib/features/communication/screens/messagerie_staff_inbox.dart';

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

    test('le slug du plan de licence n’est écrit qu’une fois', () {
      expect(kPlanSlugLicence, 'licence');
      expect(estPlanDeLicence('licence'), isTrue);
      expect(estPlanDeLicence('institutionnel'), isFalse);
      expect(estPlanDeLicence(null), isFalse);
      // ⚠️ Trois écrans en dépendent. Un `slug == 'licence'` recopié quelque
      // part, et c'est cet exemplaire-là qui divergera le jour où le slug
      // change — en proposant le plan des ministères à un groupe privé.
      expect(_lire(_groupes).contains('estPlanDeLicence(slug)'), isTrue);
      expect(_lire(_tableauDeBord).contains('estPlanDeLicence(data.planSlug)'),
          isTrue,
          reason: 'Le bandeau du tableau de bord annonce de nouveau « Plan '
              'Licence de tutelle » à un ministère.');
    });

    test('la fiche du groupe ne parle pas d’abonnement à un ministère', () {
      final src = _lire(_fiche);
      expect(src.contains("g.estMinistere ? 'Licence' : 'Plan'"), isTrue);
      expect(src.contains("g.estMinistere ? 'Statut' : 'Statut abonnement'"),
          isTrue);
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

  group('Un marché à quarante millions se lit comme un marché', () {
    // Le fondateur : « une licence est vendue pour un début à 40 millions ».
    // Une page qui n'affiche qu'un montant brut ne sert à rien : ce qu'un
    // ordonnateur cherche, c'est le montant RAMENÉ — à l'année qu'il vote, au
    // mois qu'il compare, à l'établissement qu'il défend.
    LicenceDuGroupe quaranteMillions({int jours = 365}) => LicenceDuGroupe(
          id: 'm',
          intitule: 'Licence annuelle de tutelle',
          dateDebut: DateTime.now().subtract(const Duration(days: 90)),
          dateFin: DateTime.now().add(Duration(days: jours - 90)),
          montantXaf: kLicenceMontantDepartXaf,
          avanceXaf: 12000000,
          montantRegleXaf: 12000000,
          statut: 'active',
        );

    test('le montant de départ est écrit à un seul endroit', () {
      expect(kLicenceMontantDepartXaf, 40000000);
      expect(_lire(_formulaireLicence).contains('kLicenceMontantDepartXaf'),
          isTrue,
          reason: 'La saisie repropose « 0 » : une licence à 0 F ressemble à '
              'une licence gracieuse dans tous les écrans qui la lisent.');
    });

    test('il se ramène à l’année et au mois', () {
      final l = quaranteMillions();
      expect(l.annuelXaf, closeTo(40000000, 200000));
      // 12 mois → ~3,33 M/mois. Même formule que côté fondateur, sinon les
      // deux espaces annoncent deux équivalents différents du même marché.
      expect(l.mensuelXaf, closeTo(3333333, 60000));
      expect(l.moisCouverts, 12);
    });

    test('une licence pluriannuelle ne gonfle pas le budget annuel', () {
      // ⚠️ Le piège : un marché de 40 M sur TROIS ans n'est pas 40 M par an.
      final triennal = quaranteMillions(jours: 1095);
      expect(triennal.annuelXaf, closeTo(13333333, 200000));
      expect(triennal.montantXaf, 40000000);
    });

    test('le montant divisé — le seul chiffre qui se défend en réunion', () {
      final l = quaranteMillions();
      expect(l.coutAnnuelParEtablissement(25), closeTo(1600000, 20000));
      expect(l.coutAnnuelParEleve(12500), closeTo(3200, 50));
      // ⚠️ `null` sur un réseau inconnu : « 0 F par école » sur un marché de
      // quarante millions serait pire que de ne rien afficher.
      expect(l.coutAnnuelParEtablissement(0), isNull);
      expect(l.coutAnnuelParEleve(0), isNull);
    });

    test('temps écoulé et règlement sont DEUX barres', () {
      // Un marché peut être couvert à 25 % du temps et réglé à 30 % : une
      // seule des deux barres ne dit rien de l'exécution.
      final l = quaranteMillions();
      expect(l.partEcoulee, closeTo(90 / 365, 0.02));
      expect(l.partReglee, closeTo(0.30, 0.01));
      expect(l.dureeJours, 365);
    });

    test('la page dit ce que la licence ACHÈTE, pas seulement ce qu’elle coûte',
        () {
      final src = _lire(_couverture);
      expect(src.contains('coutAnnuelParEtablissement('), isTrue);
      expect(src.contains('coutAnnuelParEleve('), isTrue);
      expect(src.contains('Référentiel national des examens'), isTrue,
          reason: 'La liste des droits ouverts a disparu : c’est l’objet même '
              'du marché, et aucun autre écran ne l’énonce.');
      expect(src.contains('reseauSuperviseProvider'), isTrue);
    });

    test('un zéro faux ne remplace jamais un réseau qu’on n’a pas pu lire', () {
      // Ce chiffre finit recopié dans un état ministériel.
      final src = _lire(_couverture);
      expect(src.contains('AdminErrorBanner'), isTrue,
          reason: 'L’échec de lecture du réseau s’affiche désormais comme '
              '« 0 établissement ».');
    });
  });

  group('Un ministère se reconnaît dans la messagerie', () {
    test('la RPC ne rend que des ministères, et que des correspondants', () {
      final sql = _lire(_migrationRpc);
      expect(sql.contains('AND g.administre_referentiel_national'), isTrue,
          reason: 'La fonction rend maintenant TOUS les groupes : elle devient '
              'un annuaire des groupes du pays.');
      expect(sql.contains('correspondants AS ('), isTrue,
          reason: 'Le filtre « avoir échangé » a sauté : la fonction devient '
              'un annuaire du personnel ministériel.');
      expect(sql.contains('SECURITY DEFINER'), isTrue);
      expect(sql.contains('REVOKE ALL ON FUNCTION'), isTrue);
    });

    test('la messagerie retombe sur AUCUNE pastille en cas d’échec', () {
      // ⚠️ Le sens du fail-soft compte : afficher « MINISTÈRE » sur un
      // correspondant ordinaire lui prêterait l'autorité de l'État.
      final src = _lire(
          'lib/features/communication/providers/correspondants_ministere_provider.dart');
      expect(src.contains('return const {};'), isTrue);
    });

    test('la liste et le fil portent la pastille', () {
      expect(_lire(_messagerie).contains('correspondantsMinistereProvider'),
          isTrue);
      expect(_lire(_inbox).contains('BadgeMinistere('), isTrue,
          reason: 'La tuile de conversation ne distingue plus un ministère.');
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
