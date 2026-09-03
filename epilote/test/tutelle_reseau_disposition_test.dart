import 'dart:io';

import 'package:epilote/core/constants/routes.dart';
import 'package:epilote/core/constants/socle_natif.dart';
import 'package:epilote/features/tutelle/providers/tutelle_filtres.dart';
import 'package:epilote/features/tutelle/providers/tutelle_reseau_provider.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LA DISPOSITION PAR GROUPE, LES DOCUMENTS, ET LA PORTE D'ENTRÉE
//
//  Trois familles de gardes, toutes dictées par la même exigence : la page
//  « Réseau sous tutelle » est réservée aux ministères, et les chiffres qu'elle
//  imprime engagent l'État.
//
//   1. RÉPARTITIONS — un état ministériel dont les lignes ne totalisent pas
//      l'effectif annoncé en tête est un état qu'on ne peut pas signer.
//   2. SÉLECTION — un PDF quitte l'application. S'il ne porte pas écrit qu'il
//      est filtré, ses totaux partiels se lisent comme ceux du réseau entier.
//   3. FERMETURE — un groupe PRIVÉ ne doit voir cette page nulle part : ni
//      dans son menu, ni par une route directe, ni depuis la base.
// ════════════════════════════════════════════════════════════════════════════

TutelleEcole _ecole({
  required String id,
  String groupId = 'G1',
  String groupeNom = 'Groupe A',
  String nom = 'École',
  String secteur = 'prive',
  String? dept = 'Brazzaville',
  String? agrement,
  int eleves = 100,
  int filles = 40,
  int personnel = 10,
  int classes = 5,
  bool actif = true,
}) =>
    TutelleEcole(
      id: id,
      groupId: groupId,
      groupeNom: groupeNom,
      nom: nom,
      secteur: secteur,
      departement: dept,
      agrementNumero: agrement,
      agrementType: agrement == null ? null : 'definitif',
      nbEleves: eleves,
      nbFilles: filles,
      nbPersonnel: personnel,
      nbClasses: classes,
      actif: actif,
    );

TutelleGroupe _groupe({
  required String id,
  String nom = 'Groupe',
  String secteur = 'prive',
  int nbEcoles = 1,
}) =>
    TutelleGroupe(
      id: id,
      nom: nom,
      secteur: secteur,
      nbEcoles: nbEcoles,
      nbEcolesActives: nbEcoles,
      nbEleves: 0,
      nbFilles: 0,
      nbPersonnel: 0,
      nbClasses: 0,
      nbEcolesAgreees: 0,
    );

/// Lit un fichier du dépôt, ou échoue bruyamment : une sonde qui ne trouve pas
/// sa cible passerait au vert en n'ayant rien vérifié.
String _lire(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) fail('Fichier introuvable : $chemin — sonde aveugle.');
  return f.readAsStringSync();
}

void main() {
  // ══════════════════════════════════════════════════════════════════════════
  group('Disposition par groupe scolaire', () {
    final groupes = [
      _groupe(id: 'PUB', nom: 'Direction dép.', secteur: 'public', nbEcoles: 2),
      _groupe(id: 'PRI', nom: 'Groupe Bethel', nbEcoles: 3),
      _groupe(id: 'VIDE', nom: 'Groupe absent', nbEcoles: 4),
    ];
    final ecoles = [
      _ecole(id: '1', groupId: 'PUB', secteur: 'public'),
      _ecole(id: '2', groupId: 'PUB', secteur: 'public'),
      _ecole(id: '3', groupId: 'PRI'),
      _ecole(id: '4', groupId: 'PRI'),
    ];

    test('le PRIVÉ passe en premier — c’est l’angle mort du ministère', () {
      final s = sectionsDuReseau(groupes, ecoles);
      expect(s.map((x) => x.prive), [true, false],
          reason: 'Le ministère administre déjà ses écoles publiques. Ce que '
              'cette page lui apprend, ce sont les établissements privés '
              'qu’il agrée sans les posséder : ils ouvrent la vue.');
      expect(s.first.titre, 'Réseau privé sous tutelle');
    });

    test('un groupe dont aucune école ne passe les filtres disparaît', () {
      final s = sectionsDuReseau(groupes, ecoles);
      final ids = [for (final sec in s) ...sec.groupes.map((g) => g.id)];
      expect(ids, containsAll(['PUB', 'PRI']));
      expect(ids.contains('VIDE'), isFalse,
          reason: 'Une carte à zéro école au-dessus d’une liste filtrée fait '
              'croire à un groupe vide alors qu’il est hors sélection.');
    });

    test('le bilan d’une section porte sur la SÉLECTION, pas sur le réseau',
        () {
      final s = sectionsDuReseau(groupes, [ecoles.first]);
      expect(s.length, 1);
      expect(s.first.prive, isFalse);
      expect(s.first.bilan.nbEcoles, 1);
      expect(s.first.bilan.nbEleves, 100);
    });

    test('le secteur suit le GROUPE, pas l’école', () {
      // `group_type` descend sur les écoles par déclencheur : un groupe n'est
      // jamais mixte. Sectionner sur l'école donnerait le même résultat
      // aujourd'hui et un résultat FAUX si le déclencheur changeait.
      final s = sectionsDuReseau(
        [_groupe(id: 'PRI', secteur: 'prive')],
        [_ecole(id: '9', groupId: 'PRI', secteur: 'public')],
      );
      expect(s.single.prive, isTrue);
    });

    test('les écoles se rangent par groupe sans en perdre', () {
      final m = ecolesParGroupe(ecoles);
      expect(m.keys.toSet(), {'PUB', 'PRI'});
      expect(m.values.fold<int>(0, (a, l) => a + l.length), ecoles.length);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  group('Répartitions imprimées', () {
    final ecoles = [
      _ecole(id: '1', dept: 'Pool', eleves: 50, filles: 20),
      _ecole(id: '2', dept: 'Brazzaville', eleves: 300, filles: 150),
      _ecole(id: '3', dept: null, eleves: 10, filles: 5),
      _ecole(id: '4', dept: 'Brazzaville', eleves: 40, filles: 10),
    ];

    test('les lignes départementales totalisent l’effectif annoncé', () {
      final lignes = repartitionParDepartement(ecoles);
      final total = lignes.fold<int>(0, (a, l) => a + l.bilan.nbEleves);
      expect(total, BilanReseau.de(ecoles).nbEleves,
          reason: 'Un état dont les lignes ne font pas le total est un état '
              'qu’on ne signe pas.');
      final ecolesComptees = lignes.fold<int>(0, (a, l) => a + l.bilan.nbEcoles);
      expect(ecolesComptees, ecoles.length);
    });

    test('une école sans département est NOMMÉE, jamais écartée', () {
      final lignes = repartitionParDepartement(ecoles);
      expect(lignes.map((l) => l.libelle), contains('Non renseigné'));
    });

    test('le classement va du plus peuplé au moins peuplé', () {
      final lignes = repartitionParDepartement(ecoles);
      expect(lignes.first.libelle, 'Brazzaville');
      expect(lignes.first.bilan.nbEleves, 340);
      expect(lignes.last.libelle, 'Non renseigné');
    });

    test('le secteur se répartit en deux lignes, le privé d’abord', () {
      final mixte = [
        _ecole(id: 'a', secteur: 'public'),
        _ecole(id: 'b', secteur: 'prive'),
      ];
      final lignes = repartitionParSecteur(mixte);
      expect(lignes.map((l) => l.libelle), ['Privé', 'Public']);
      expect(lignes.fold<int>(0, (a, l) => a + l.bilan.nbEcoles), 2);
    });

    test('un secteur absent ne produit pas de ligne à zéro', () {
      final lignes = repartitionParSecteur([_ecole(id: 'a')]);
      expect(lignes.map((l) => l.libelle), ['Privé']);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  group('Un document filtré le DIT', () {
    test('une vue complète ne porte aucune mention de sélection', () {
      expect(descriptionDesFiltres(const FiltreReseau()), isNull);
    });

    test('chaque filtre actif apparaît dans la phrase', () {
      final phrase = descriptionDesFiltres(
        const FiltreReseau(
          secteur: 'prive',
          departement: 'Niari',
          typeEtablissement: 'CET',
          agrement: FiltreAgrement.nonDeclare,
          actifSeulement: true,
          recherche: ' Bethel ',
        ),
        nomGroupe: 'Groupe Bethel',
      );
      expect(phrase, isNotNull);
      for (final attendu in [
        'secteur privé',
        'Niari',
        'CET',
        'agrément non déclaré',
        'actifs',
        'Groupe Bethel',
        'Bethel',
      ]) {
        expect(phrase, contains(attendu),
            reason: 'Un PDF qui tait un de ses filtres présente des totaux '
                'partiels comme ceux du réseau entier.');
      }
    });

    test('le groupe filtré est NOMMÉ, pas désigné par son identifiant', () {
      final phrase = descriptionDesFiltres(
        const FiltreReseau(groupId: 'a6000000-0000-0000-0000-000000000006'),
        nomGroupe: 'Groupe Scolaire Bethel',
      );
      expect(phrase, contains('Groupe Scolaire Bethel'));
      expect(phrase, isNot(contains('a6000000')));
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  //  LES GARDES QUI COMPTENT VRAIMENT
  //
  //  Exigence explicite : cette page ne doit exister NULLE PART pour un groupe
  //  scolaire privé. Trois couches la ferment, et aucune ne se surveillait.
  // ══════════════════════════════════════════════════════════════════════════
  group('La page est fermée aux groupes privés', () {
    test('le MENU ne construit l’entrée que pour une tutelle', () {
      // L'entrée est déclarée dans le socle natif, pour le SEUL espace
      // groupe : une école ne peut pas la recevoir par mégarde.
      final entree = kSocleNatif.firstWhere(
        (e) => e.libelle == 'Réseau sous tutelle',
        orElse: () =>
            fail('L’entrée a été renommée : ce garde ne surveille plus rien.'),
      );
      expect(entree.places.keys, [EspaceNav.groupe]);

      final src = _lire('lib/core/widgets/app_shell/nav_config.dart');

      // Le droit doit venir de la BASE, pas d'une constante ni du type de
      // groupe déduit côté client.
      expect(src.contains('groupeAdministreReferentielProvider'), isTrue);

      // ⚠️ On ancre sur l'APPEL CONSTRUIT, pas sur le libellé nu. Une première
      // version cherchait « Réseau sous tutelle » et tombait sur le
      // commentaire qui explique pourquoi l'entrée a quitté sa section : la
      // sonde surveillait la prose, pas le code.
      final appel = RegExp(
        r'_entreesNatives\(\s*EspaceNav\.groupe,\s*ZoneNav\.tete,'
        r'([\s\S]{0,300}?)\),',
      ).firstMatch(src);
      expect(appel, isNotNull,
          reason: 'Le bloc de tête du groupe ne dérive plus du socle : '
              'ce garde ne surveille plus rien.');

      final garde = appel!.group(1)!;
      expect(garde.contains('estTutelle'), isTrue,
          reason: 'Le bloc de tête ne consulte plus `estTutelle` : un groupe '
              'privé verrait « Réseau sous tutelle » dans son menu.');
      expect(garde.contains("'Réseau sous tutelle'"), isTrue,
          reason: 'Le filtre ne nomme plus l’entrée à retirer — `sans:` '
              'filtre par LIBELLÉ, un nom qui change le rend muet.');
    });

    test('l’ÉCRAN refuse de lui-même, sans attendre l’erreur de la RPC', () {
      final src =
          _lire('lib/features/tutelle/screens/tutelle_reseau_screen.dart');
      expect(src.contains('groupeAdministreReferentielProvider'), isTrue,
          reason: 'La route est publique dans le shell admin : sans garde '
              'd’écran, un lien direct ouvre la page à n’importe qui.');
      expect(src.contains('_PasDeTutelle()'), isTrue);
    });

    test('le CHARGEMENT du droit n’est pas traité comme un refus', () {
      final src =
          _lire('lib/features/tutelle/screens/tutelle_reseau_screen.dart');
      expect(src.contains('droit.isLoading'), isTrue,
          reason: 'Avec `valueOrNull ?? false`, un ministre légitime lit '
              '« Réservé aux ministères de tutelle » le temps de '
              'l’aller-retour — l’écran commence par accuser à tort.');
    });

    test('la BASE refuse en 42501 avant toute lecture', () {
      final sql = _lire('../database/migrations/'
          '0158_AVANT_LE_BUILD_lagrement_du_groupe_et_la_vue_de_tutelle.sql');
      for (final fn in ['tutelle_groupes', 'tutelle_ecoles']) {
        final i = sql.indexOf('FUNCTION public.$fn(');
        expect(i, greaterThan(0), reason: 'RPC $fn introuvable.');
        // Le garde doit précéder le RETURN QUERY : contrôler après avoir lu
        // n'est pas contrôler.
        final corps = sql.substring(i);
        final garde = corps.indexOf('auth_peut_superviser()');
        final lecture = corps.indexOf('RETURN QUERY');
        expect(garde, greaterThan(0),
            reason: '$fn ne passe plus par `auth_peut_superviser()`.');
        expect(garde, lessThan(lecture),
            reason: '$fn lit avant de vérifier le droit.');
      }
      // Et l'anonyme n'a même pas le droit d'appeler.
      expect(sql.contains('REVOKE ALL ON FUNCTION public.tutelle_groupes()'),
          isTrue);
      expect(sql.contains('REVOKE ALL ON FUNCTION public.tutelle_ecoles(uuid)'),
          isTrue);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  group('Les documents de la tutelle', () {
    const fiches = 'lib/features/tutelle/services/tutelle_fiche_pdf_service.dart';
    const etat = 'lib/features/tutelle/services/tutelle_pdf_service.dart';

    test('aucune table de longueur libre n’est posée dans un cadre nu', () {
      // `frame()` enveloppe son contenu dans un `Padding`, qui ne sait pas se
      // scinder entre deux pages : une table plus haute qu'une feuille fait
      // boucler `MultiPage` jusqu'à `TooManyPagesException` — le document ne
      // sort alors PAS DU TOUT. Cible nationale : plus de mille écoles.
      for (final chemin in [fiches, etat]) {
        final src = _lire(chemin);
        expect(src.contains('OfficialPdfKit.table('), isFalse,
            reason: '$chemin appelle `table()` directement : la liste n’est '
                'plus paginée, et le PDF cessera de se générer passé une '
                'trentaine de lignes.');
        expect(src.contains('OfficialPdfKit.tableSection('), isTrue);
      }
    });

    test('les documents portent l’identité de l’émetteur, pas la nôtre', () {
      for (final chemin in [fiches, etat]) {
        final src = _lire(chemin);
        expect(src.contains('OfficialPdfKit.issuer?.name'), isTrue,
            reason: 'Un état remis au ministère et signé « E-PILOTE CONGO » '
                'porte le nom d’un fournisseur à la place de celui du '
                'ministère qui le remet.');
        expect(src.contains('OfficialPdfKit.headerFor('), isTrue);
      }
    });

    test('l’encart de portée est présent sur les trois documents', () {
      // Le PDF perd le contexte de l'écran : la portée doit être écrite
      // dessus, pas laissée à la mémoire du lecteur.
      final f = _lire(fiches);
      expect('pdfEncartPortee('.allMatches(f).length, 2,
          reason: 'Fiche d’établissement ET fiche de groupe doivent la porter.');
      expect(_lire(etat).contains('pdfEncartPortee('), isTrue);
    });

    test('aucun champ nominatif d’élève ne peut entrer dans un document', () {
      // Le modèle client ne porte que des agrégats : la sonde vérifie qu'on
      // n'a pas ajouté un champ d'élève au passage.
      final modele =
          _lire('lib/features/tutelle/providers/tutelle_reseau_provider.dart');
      for (final interdit in [
        'first_name',
        'last_name',
        'matricule',
        'birth_date',
        'plan_id',
        'subscription_status',
      ]) {
        expect(modele.contains(interdit), isFalse,
            reason: 'Le modèle de tutelle expose « $interdit » : un ministère '
                'supervise des établissements, il ne tient pas le registre '
                'nominatif du pays.');
      }
      // Le chef d'établissement est la SEULE exception, et elle est voulue.
      expect(modele.contains('chef_etablissement'), isTrue);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  //  LE PÉRIMÈTRE : SUPERVISER N'EST PAS EXPLOITER
  //
  //  Défaut constaté à l'écran le 2026-09-02 (compte METP) : la page annonçait
  //  « toutes les écoles sous tutelle METP, Y COMPRIS CELLES QUE VOUS NE GÉREZ
  //  PAS » et affichait 12 écoles dans 1 groupe — le ministère lui-même. La
  //  vue par groupe ne contenait qu'une carte : celle de son propre lecteur.
  // ══════════════════════════════════════════════════════════════════════════
  group('Le réseau supervisé exclut le ministère lui-même', () {
    final complet = TutelleReseau(
      groupes: [
        _groupe(id: 'MIN', nom: 'MEPSA', secteur: 'public', nbEcoles: 14),
        _groupe(id: 'PUB', nom: 'EDEC', secteur: 'public', nbEcoles: 2),
        _groupe(id: 'PRI', nom: 'Bethel', nbEcoles: 3),
      ],
      ecoles: [
        for (var i = 0; i < 14; i++)
          _ecole(id: 'M\$i', groupId: 'MIN', secteur: 'public'),
        for (var i = 0; i < 2; i++)
          _ecole(id: 'E\$i', groupId: 'PUB', secteur: 'public'),
        for (var i = 0; i < 3; i++) _ecole(id: 'B\$i', groupId: 'PRI'),
      ],
    );

    test('le groupe du consultant disparaît, groupes ET écoles', () {
      final r = reseauSuperviseDe(complet, 'MIN');
      expect(r.groupes.map((g) => g.id), ['PUB', 'PRI']);
      expect(r.ecoles.length, 5);
      expect(r.ecoles.any((e) => e.groupId == 'MIN'), isFalse,
          reason: 'Une page de supervision qui affiche les écoles de son '
              'propre lecteur ne répond à aucune question.');
    });

    test('ses écoles sont COMPTÉES pour être nommées, pas effacées', () {
      // Sans ce nombre, un ministère qui ne retrouve pas ses douze écoles
      // conclut à une panne plutôt qu'à un périmètre.
      expect(reseauSuperviseDe(complet, 'MIN').nbEcolesPropres, 14);
    });

    test('un ministère sans groupe tiers rend un vide EXPLICITE', () {
      // Le cas réel du METP : 12 écoles, toutes à lui, aucun groupe supervisé.
      final metp = TutelleReseau(
        groupes: [_groupe(id: 'MIN', secteur: 'public', nbEcoles: 12)],
        ecoles: [
          for (var i = 0; i < 12; i++)
            _ecole(id: 'M\$i', groupId: 'MIN', secteur: 'public'),
        ],
      );
      final r = reseauSuperviseDe(metp, 'MIN');
      expect(r.estVide, isTrue);
      expect(r.nbEcolesPropres, 12,
          reason: 'Le vide doit pouvoir DIRE combien d’écoles sont ailleurs.');
    });

    test('les groupes publics TIERS restent — ce ne sont pas les siennes', () {
      // ⚠️ Filtrer sur le secteur au lieu du groupe aurait écarté EDEC et
      // Savorgnan : 4 écoles et 2 575 élèves que le MEPSA supervise sans les
      // administrer, et qu'aucun autre écran ne lui montre.
      final r = reseauSuperviseDe(complet, 'MIN');
      expect(r.groupes.any((g) => g.id == 'PUB'), isTrue);
    });

    test('le super_admin n’a pas de groupe : rien n’est retiré', () {
      for (final sans in [null, '']) {
        final r = reseauSuperviseDe(complet, sans);
        expect(r.groupes.length, 3);
        expect(r.ecoles.length, 19);
        expect(r.nbEcolesPropres, 0);
      }
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  group('La page affiche le réseau SUPERVISÉ', () {
    test('elle lit `reseauSuperviseProvider`, pas le périmètre couvert', () {
      final src =
          _lire('lib/features/tutelle/screens/tutelle_reseau_screen.dart');
      expect(src.contains('ref.watch(reseauSuperviseProvider)'), isTrue,
          reason: 'La page doit lire ce qu’elle supervise, pas ce que la '
              'tutelle couvre.');
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  //  LA CIRCULAIRE A ÉTÉ RETIRÉE — la tutelle écrit par la MESSAGERIE
  //
  //  La plateforme portait déjà trois canaux : annonces, messagerie, tickets.
  //  La circulaire en ajoutait un quatrième — quatre écrans, un vocabulaire
  //  propre, deux entrées de menu — pour un objet dont la base ne comptait
  //  AUCUNE ligne. Décision du 2026-09-02 : un ministère écrit à un groupe
  //  supervisé comme il écrit à n'importe qui.
  // ══════════════════════════════════════════════════════════════════════════
  group('Plus aucun quatrième canal', () {
    test('la barre latérale ne porte plus une seule entrée « Circulaires »',
        () {
      final src = _lire('lib/core/widgets/app_shell/nav_config.dart');
      for (final route in [
        'route: Routes.adminCirculaires',
        'route: Routes.adminCirculairesEmises',
        'route: Routes.userCirculaires',
      ]) {
        expect(src.contains(route), isFalse,
            reason: '$route est de retour dans le menu.');
      }
    });

    test('les routes et les écrans ont disparu du dépôt', () {
      final routes = _lire('lib/core/constants/routes.dart');
      for (final r in [
        'String adminCirculaires',
        'String adminCirculairesEmises',
        'String userCirculaires',
      ]) {
        expect(routes.contains(r), isFalse, reason: '$r subsiste.');
      }
      for (final f in [
        'lib/features/communication/screens/circulaires_emises_screen.dart',
        'lib/features/communication/screens/circulaires_recues_screen.dart',
        'lib/features/communication/screens/circulaire_form_dialog.dart',
        'lib/features/communication/providers/circulaires_provider.dart',
      ]) {
        expect(File(f).existsSync(), isFalse, reason: '$f subsiste.');
      }
    });

    test('une SECTION de menu ne se justifie pas pour une seule entrée', () {
      // « Réseau sous tutelle » avait son intertitre « TUTELLE » et son
      // séparateur, pour une ligne. L'entrée a rejoint le bloc de tête.
      final src = _lire('lib/core/widgets/app_shell/nav_config.dart');
      expect(src.contains("title: 'TUTELLE'"), isFalse);

      // L'entrée existe toujours — dans le BLOC DE TÊTE, pas dans une section
      // à elle. Le socle porte désormais et sa zone et sa destination.
      final place = kSocleNatif
          .firstWhere((e) => e.libelle == 'Réseau sous tutelle')
          .places[EspaceNav.groupe]!;
      expect(place.zone, ZoneNav.tete);
      expect(place.route, Routes.adminTutelle);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  group('Écrire à un groupe supervisé', () {
    const dialogue = 'lib/features/tutelle/widgets/tutelle_message_dialog.dart';

    test('l’action passe par la messagerie, pas par un canal dédié', () {
      final ecran =
          _lire('lib/features/tutelle/screens/tutelle_reseau_screen.dart');
      expect(ecran.contains('ouvrirMessageGroupe(context, g)'), isTrue);
      expect(ecran.contains('showCirculaireForm'), isFalse);
    });

    test('le message part du groupe de l’EXPÉDITEUR', () {
      // `msg_insert` exige `group_id = auth_group_id()`. Poser le groupe du
      // destinataire ferait refuser l'insertion en 42501 — alors que
      // `msg_select` rend le message par `recipient_id`, sans condition de
      // groupe : chacun le lit dans sa propre messagerie.
      final src = _lire(dialogue);
      expect(src.contains('groupId: monGroupe'), isTrue);
    });

    test('un envoi part en FAN-OUT, une ligne par destinataire', () {
      // `recipient_id` est NOT NULL et unique : un envoi « groupé » n'existe
      // pas en base. Chacun reçoit sa copie et peut répondre seul.
      final src = _lire(dialogue);
      expect(src.contains('sendMessageToMany('), isTrue);
      expect(src.contains('recipientIds: _coches.toList()'), isTrue);
    });

    test('aucun envoi possible sans destinataire coché', () {
      final src = _lire(dialogue);
      expect(src.contains('onSubmit: _coches.isEmpty ? null : _envoyer'), isTrue,
          reason: 'Un envoi à vide échouerait en base (`recipient_id` NOT '
              'NULL) et l’agent croirait à une panne de réseau.');
    });

    test('la RPC de résolution porte DEUX gardes', () {
      final sql = _lire('../database/migrations/'
          '0174_AVANT_LE_BUILD_la_tutelle_ecrit_par_la_messagerie.sql');
      expect(sql.contains('auth_peut_superviser()'), isTrue,
          reason: 'Garde 1 : être une tutelle.');
      // ⚠️ Sans apostrophe : SQL la double (`n\'\'est`), la chercher simple
      // ne trouve rien.
      expect(sql.contains('pas place sous votre tutelle'), isTrue,
          reason: 'Garde 2 : sans elle, un UUID deviné rendrait les '
              'correspondants de n’importe quel groupe du pays.');
      expect(
          sql.contains('REVOKE ALL ON FUNCTION '
              'public.tutelle_destinataires(uuid) FROM public, anon'),
          isTrue);
    });

    test('elle rend de quoi ADRESSER, rien de plus', () {
      final sql = _lire('../database/migrations/'
          '0174_AVANT_LE_BUILD_la_tutelle_ecrit_par_la_messagerie.sql');
      // La SIGNATURE est l'invariant. Le corps, lui, a le droit de filtrer sur
      // `p.role` — filtrer n'est pas exposer.
      final debut = sql.indexOf('RETURNS TABLE (');
      final signature = sql.substring(debut, sql.indexOf(')', debut));
      for (final attendu in ['user_id', 'nom', 'fonction', 'school_id', 'ecole']) {
        expect(signature.contains(attendu), isTrue);
      }
      for (final interdit in ['email', 'phone', 'address', 'matricule']) {
        expect(signature.contains(interdit), isFalse,
            reason: 'La RPC rend « $interdit » : elle doit rendre de quoi '
                'adresser un message, rien de plus.');
      }
    });

    test('le chef se reconnaît à son RÔLE, pas à `schools.director_id`', () {
      // Mesuré le 2026-09-03 : `director_id` est NULL sur les onze écoles
      // supervisées du MEPSA, alors que chacune a un chef actif rattaché par
      // `profiles.school_id`. Résoudre par la colonne rendrait la sélection
      // TOUJOURS vide.
      final sql = _lire('../database/migrations/'
          '0174_AVANT_LE_BUILD_la_tutelle_ecrit_par_la_messagerie.sql');
      // ⚠️ Borné au CORPS de la fonction — de `RETURN QUERY` à sa fin. Le
      // `COMMENT ON FUNCTION` qui suit cite `schools.director_id` pour dire
      // de ne PAS s'y fier : une sonde qui lirait jusqu'au bout du fichier
      // tomberait sur cette phrase-là.
      final debutCorps = sql.indexOf('RETURN QUERY');
      final corps = sql.substring(debutCorps, sql.indexOf(r'$fn$;', debutCorps));
      expect(corps.contains("p.role IN ('directeur', 'proviseur')"), isTrue);
      expect(corps.contains('director_id'), isFalse,
          reason: 'La colonne n’est pas tenue : s’y fier vide la sélection.');
    });
  });


  // ══════════════════════════════════════════════════════════════════════════
  //  LE CHEF D'ÉTABLISSEMENT DOIT S'AFFICHER — 0175
  //
  //  0158 justifie sur dix lignes pourquoi le chef est la SEULE donnée
  //  nominative qui sort : « l'interlocuteur officiel de la tutelle ».
  //  Il le résolvait par `schools.director_id` — colonne NULL sur les 37
  //  écoles. La mention affichait donc « Non désigné » partout : dans la
  //  liste, dans la fiche, et dans les trois documents PDF.
  // ══════════════════════════════════════════════════════════════════════════
  group('Le chef d’établissement se résout par le RÔLE', () {
    const mig = '../database/migrations/'
        '0175_AVANT_LE_BUILD_le_chef_detablissement_se_reconnait_a_son_role.sql';

    test('la résolution retombe sur le rôle quand la colonne est vide', () {
      final sql = _lire(mig);
      final corps = sql.substring(sql.indexOf('RETURN QUERY'));
      expect(corps.contains("p.role IN ('directeur', 'proviseur')"), isTrue);
      expect(corps.contains('p.school_id = s.id'), isTrue);
    });

    test('une désignation explicite garde la priorité', () {
      // Le jour où un établissement désigne formellement son chef — deux
      // proviseurs, une intérimaire — cette désignation prime sur la déduction.
      final sql = _lire(mig);
      expect(sql.contains('ORDER BY (p.id = s.director_id) DESC'), isTrue);
    });

    test('un chef parti ne reste pas interlocuteur d’un ministère', () {
      final sql = _lire(mig);
      final corps = sql.substring(sql.indexOf('LEFT JOIN LATERAL'));
      expect(corps.contains('p.is_active'), isTrue);
    });

    test('la SIGNATURE n’a pas bougé — le client Dart n’a rien à changer', () {
      // C'est la condition pour qu'une correction de ce genre soit sûre.
      final sql = _lire(mig);
      final debut = sql.indexOf('RETURNS TABLE (');
      final signature = sql.substring(debut, sql.indexOf(')', debut));
      for (final colonne in [
        'school_id uuid',
        'chef_etablissement text',
        'nb_classes bigint',
      ]) {
        expect(signature.contains(colonne), isTrue, reason: colonne);
      }
      final modele =
          _lire('lib/features/tutelle/providers/tutelle_reseau_provider.dart');
      expect(modele.contains("r['chef_etablissement']"), isTrue);
    });
  });

}
