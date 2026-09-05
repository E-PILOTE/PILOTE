import 'dart:io';

import 'package:epilote/core/providers/identite_etablissement.dart';
import 'package:flutter_test/flutter_test.dart';
import 'ecran_groupes_source.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LA BARRE LATÉRALE PORTE L'ÉTABLISSEMENT, PAS L'ÉDITEUR
//
//  ── CE QU'IL Y AVAIT AVANT (2026-09-04) ───────────────────────────────────
//  L'en-tête de la barre latérale affichait « E-PILOTE CONGO / Gestion
//  scolaire » à tout le monde, sur tous les écrans, avec notre logo. Un
//  enseignant de Dolisie ouvrait donc sa journée sur la marque de son
//  fournisseur de logiciel — alors que le produit connaît le nom ET le logo de
//  son école depuis la première synchro.
//
//  ── LES TROIS RÉGRESSIONS QUE CE FICHIER ATTEND ───────────────────────────
//  1. Remettre l'emblème du logiciel en repli « parce que c'est plus joli
//     qu'une case vide » : l'écran dirait « cette école est E-PILOTE », et
//     l'école ne saurait jamais qu'il lui manque un fichier à déposer.
//  2. Faire dépendre le NOM du chargement de l'image : le nom vient de SQLite
//     et doit s'afficher hors ligne ; l'image, elle, a besoin d'un réseau au
//     moins une fois.
//  3. Réécrire la cascade dans un quatrième endroit. Elle existait déjà en
//     trois exemplaires (vitrine, tableau de bord, émetteur PDF) ; elle se
//     déclare désormais ici.
// ════════════════════════════════════════════════════════════════════════════

const _entete = 'lib/core/widgets/app_shell/sidebar_header.dart';
const _regle = 'lib/core/providers/identite_etablissement.dart';

String _lire(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) fail('Fichier introuvable : $chemin — sonde aveugle.');
  return f.readAsStringSync().replaceAll('\r\n', '\n');
}

/// Le code SANS ses commentaires : les en-têtes de ce projet citent justement
/// les formes interdites pour les expliquer.
String _sansCommentaires(String source) => source
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  group('Le personnel voit son école', () {
    test('nom de l’école en titre, logo de l’école', () {
      final id = identiteEtablissementDe(
        role: 'enseignant',
        ecole: {'name': 'Lycée de la Révolution', 'logo_url': 'https://x/l.png'},
        groupeDeLEcole: {'name': 'Groupe EDEC', 'logo_url': 'https://x/g.png'},
      );
      expect(id.nom, 'Lycée de la Révolution');
      expect(id.logoUrl, 'https://x/l.png');
      expect(id.estLaPlateforme, isFalse);
    });

    test('sans logo propre, l’école hérite de celui du groupe', () {
      // L'école est une émanation du groupe : l'héritage n'est pas un pis-aller,
      // c'est la réalité de l'organisation.
      final id = identiteEtablissementDe(
        role: 'secretaire',
        ecole: {'name': 'CEG Moungali', 'logo_url': null},
        groupeDeLEcole: {'name': 'Groupe EDEC', 'logo_url': 'https://x/g.png'},
      );
      expect(id.nom, 'CEG Moungali');
      expect(id.logoUrl, 'https://x/g.png');
    });

    test('aucun logo nulle part → aucune URL, donc les initiales', () {
      final id = identiteEtablissementDe(
        role: 'comptable',
        ecole: {'name': 'CEG Moungali'},
        groupeDeLEcole: {'name': 'Groupe EDEC'},
      );
      expect(id.nom, 'CEG Moungali');
      expect(id.logoUrl, isNull,
          reason: 'Reprendre notre emblème ici ferait passer le logiciel pour '
              'l’établissement.');
    });

    test('le nom survit à l’absence totale de logo — et l’inverse', () {
      // Hors ligne, le nom vient de SQLite et doit s'afficher ; les octets de
      // l'image, eux, ne sont peut-être jamais arrivés.
      final id = identiteEtablissementDe(
        role: 'directeur',
        ecole: {'name': 'École Saint-Pierre', 'logo_url': ''},
      );
      expect(id.nom, 'École Saint-Pierre');
      expect(id.logoUrl, isNull);
    });

    test('une école sans nom retombe sur le groupe, puis sur la plateforme', () {
      expect(
        identiteEtablissementDe(
          role: 'enseignant',
          ecole: {'name': '  '},
          groupeDeLEcole: {'name': 'Groupe EDEC'},
        ).nom,
        'Groupe EDEC',
      );
      // Base locale encore vide juste après la connexion : mieux vaut la marque
      // du produit qu'un en-tête vide au-dessus de toute la navigation.
      expect(
        identiteEtablissementDe(role: 'enseignant').estLaPlateforme,
        isTrue,
      );
    });
  });

  group('L’administrateur de groupe voit son groupe', () {
    test('nom et logo du groupe administré', () {
      final id = identiteEtablissementDe(
        role: 'admin_groupe',
        groupeAdministre: (nom: 'Groupe EDEC', logoUrl: 'https://x/g.png'),
      );
      expect(id.nom, 'Groupe EDEC');
      expect(id.logoUrl, 'https://x/g.png');
    });

    test('le remplissage « — » du provider ne devient jamais un titre', () {
      // `adminGroupProfileProvider` renvoie « — » quand il n'a rien pu lire.
      final id = identiteEtablissementDe(
        role: 'admin_groupe',
        groupeAdministre: (nom: '—', logoUrl: null),
      );
      expect(id.estLaPlateforme, isTrue);
    });

    test('son école n’est jamais consultée : il n’en a pas', () {
      final id = identiteEtablissementDe(
        role: 'admin_groupe',
        groupeAdministre: (nom: 'Groupe EDEC', logoUrl: null),
        ecole: {'name': 'Une école qui traîne', 'logo_url': 'https://x/l.png'},
      );
      expect(id.nom, 'Groupe EDEC');
      expect(id.logoUrl, isNull);
    });
  });

  group('La plateforme garde la vedette pour qui l’administre', () {
    test('super_admin reste sous la marque du produit', () {
      final id = identiteEtablissementDe(role: 'super_admin');
      expect(id.estLaPlateforme, isTrue);
      expect(id.nom, 'E-PILOTE CONGO');
      expect(id.sousTitre, 'Gestion scolaire');
    });

    test('personne d’autre n’est « la plateforme »', () {
      for (final role in ['enseignant', 'admin_groupe', 'parent', 'eleve']) {
        final id = identiteEtablissementDe(
          role: role,
          groupeAdministre: (nom: 'Groupe EDEC', logoUrl: null),
          ecole: {'name': 'CEG Moungali'},
        );
        expect(id.estLaPlateforme, isFalse, reason: 'rôle $role');
        expect(id.sousTitre, 'E-PILOTE CONGO',
            reason: 'Le produit garde sa signature en seconde ligne.');
      }
    });
  });

  group('Une adresse inutilisable conduit aux initiales, pas à une image cassée',
      () {
    test('les chemins de Storage relatifs sont refusés', () {
      expect(logoAffichable('logos/edec.png'), isFalse);
      expect(logoAffichable(''), isFalse);
      expect(logoAffichable('   '), isFalse);
      expect(logoAffichable(null), isFalse);
      expect(logoAffichable('https://storage/logos/edec.png'), isTrue);
    });

    test('la cascade saute une adresse invalide au lieu de s’y arrêter', () {
      final id = identiteEtablissementDe(
        role: 'enseignant',
        ecole: {'name': 'CEG Moungali', 'logo_url': 'logos/relatif.png'},
        groupeDeLEcole: {'name': 'Groupe EDEC', 'logo_url': 'https://x/g.png'},
      );
      expect(id.logoUrl, 'https://x/g.png');
    });
  });

  group('L’en-tête ne réinvente rien', () {
    test('il ne code plus la marque en dur', () {
      final src = _sansCommentaires(_lire(_entete));
      expect(src.contains("'E-PILOTE CONGO'"), isFalse,
          reason: 'Le nom affiché doit venir de la règle, pas du widget.');
      expect(src.contains("'Gestion scolaire'"), isFalse);
      expect(src.contains('identiteEtablissementProvider'), isTrue);
    });

    test('l’emblème du logiciel ne sert QUE pour la plateforme', () {
      final src = _sansCommentaires(_lire(_entete));
      expect('SvgPicture.asset'.allMatches(src).length, 1,
          reason: 'Un second usage serait le repli interdit.');
      expect(src.indexOf('estLaPlateforme'),
          lessThan(src.indexOf('SvgPicture.asset')),
          reason: 'Le logo E-PILOTE doit rester derrière ce test de rôle.');
    });

    test('hors ligne, la place est tenue par les initiales', () {
      final src = _sansCommentaires(_lire(_entete));
      expect(src.contains('placeholder: (_, _) => initiales'), isTrue);
      expect(src.contains('errorWidget: (_, _, _) => initiales'), isTrue,
          reason: 'Une URL morte ne doit pas laisser un trou dans la barre.');
    });
  });

  group('La règle respecte les deux chemins de données', () {
    test('elle ne lit jamais Supabase pour le personnel, ni SQLite pour le '
        'groupe', () {
      final src = _sansCommentaires(_lire(_regle));
      expect(src.contains('.from('), isFalse,
          reason: 'Le personnel travaille hors ligne : aucun appel réseau ici.');
      expect(src.contains('db.watch'), isFalse);
      expect(src.contains('db.getAll'), isFalse,
          reason: 'La base locale d’un admin_groupe est vide — il n’y a rien '
              'à y lire.');
      expect(src.contains('currentSchoolProvider'), isTrue);
      expect(src.contains('adminGroupProfileProvider'), isTrue);
    });
  });

  group('Sans logo, les initiales doivent encore distinguer deux écoles', () {
    test('les mots génériques sautent', () {
      // Trente-six des trente-sept écoles n'ont aucun logo aujourd'hui : ces
      // deux lettres SONT leur identité visuelle dans la barre latérale.
      expect(initialesEtablissement('Groupe Scolaire EDEC'), 'ED');
      expect(initialesEtablissement('Groupe Scolaire Bethel'), 'BE');
      expect(initialesEtablissement('Réseau Scolaire Horizon'), 'HO');
      expect(initialesEtablissement('Institut Savorgnan de Brazza'), 'SB');
      expect(initialesEtablissement('École Saint-Pierre'), 'SP');
    });

    test('deux groupes du même réseau ne se confondent plus', () {
      expect(
        initialesEtablissement('Groupe Scolaire EDEC'),
        isNot(initialesEtablissement('Groupe Scolaire Bethel')),
        reason: 'Des initiales naïves donneraient « GS » aux deux.',
      );
    });

    test('un nom entièrement générique garde quand même des initiales', () {
      expect(initialesEtablissement('Groupe Scolaire'), 'GS');
      expect(initialesEtablissement('Lycée'), 'LY');
    });

    test('la ponctuation ne devient jamais une initiale', () {
      expect(initialesEtablissement('MEPSA — Ministère Enseign. Primaire'),
          'MM');
      expect(initialesEtablissement('  '), '?');
      expect(initialesEtablissement(null), '?');
    });

    test('c’est une règle d’ÉTABLISSEMENT, pas de personne', () {
      // `avatarInitials` reste la règle des gens : « Jean Mabiala » → « JM ».
      // Lui appliquer cette liste de mots dégraderait les noms propres.
      final src = _sansCommentaires(_lire(_entete));
      expect(src.contains('avatarInitials'), isFalse);
      expect(src.contains('initialesEtablissement'), isTrue);
    });
  });

  group('Aucune deuxième version de la règle ne subsiste', () {
    // Le 2026-09-05, sept endroits calculaient les initiales d'un
    // établissement, chacun avec son propre repli (« ? », « G », « É »). Tous
    // donnaient « GS » à « Groupe Scolaire EDEC » comme à « Groupe Scolaire
    // Bethel ». Ils délèguent désormais.
    const delegataires = [
      'lib/core/widgets/app_shell/sidebar_header.dart',
      'lib/features/user/screens/user_dashboard_screen.dart',
      'lib/features/admin_groupe/screens/admin_settings_screen.dart',
      'lib/features/admin_groupe/screens/schools/school_form_widgets.dart',
      'lib/features/super_admin/providers/subscriptions_provider.dart',
      'lib/features/super_admin/services/financial_pdf_service.dart',
    ];

    test('les sept pastilles d’établissement lisent la même règle', () {
      for (final f in delegataires) {
        expect(_sansCommentaires(_lire(f)).contains('initialesEtablissement'),
            isTrue,
            reason: '$f a recommencé à calculer ses propres initiales.');
      }
      // L'écran des groupes est un DOSSIER depuis son découpage : ses trois
      // pastilles vivent dans `groupes_badges` et `groupes_form_bits`. Le lire
      // fichier par fichier ferait passer cette sonde au vert sans rien voir.
      expect(
          _sansCommentaires(sourceEcranGroupes())
              .contains('initialesEtablissement'),
          isTrue);
    });

    test('la règle n’est déclarée qu’une fois', () {
      final regle = _lire(_regle);
      expect('String initialesEtablissement('.allMatches(regle).length, 1);
      for (final f in delegataires) {
        expect(_lire(f).contains('String initialesEtablissement('), isFalse,
            reason: 'Une copie de la fonction est réapparue dans $f.');
      }
    });

    test('l’écran des groupes n’a plus de version maison', () {
      final src = sourceEcranGroupes();
      expect(src.contains('String get _initials {'), isFalse,
          reason: 'Les trois pastilles de cet écran doivent déléguer.');
    });
  });
}
