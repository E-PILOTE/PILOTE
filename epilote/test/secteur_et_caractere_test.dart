import 'dart:io';

import 'package:epilote/core/constants/caractere_groupe.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE SECTEUR ET LE CARACTÈRE SONT DEUX QUESTIONS
//
//  ── LE DÉFAUT, MESURÉ EN PRODUCTION ───────────────────────────────────────
//  Le formulaire de création de groupe proposait CINQ types dans un seul
//  champ — Public, Privé, Catholique, Islamique, Protestant — alors que l'enum
//  `group_type` n'en accepte que DEUX. `'catholique'::group_type` rend 22P02 :
//  trois choix sur cinq faisaient échouer la création, et le filtre « Type »
//  de la liste proposait de chercher ce qui ne pouvait pas exister.
//
//  ── POURQUOI ON N'A PAS ÉLARGI L'ENUM ─────────────────────────────────────
//  Parce que `group_type` porte LE SECTEUR, et que quatre choses en dépendent :
//   • `school_form_dialog` — « le secteur d'une école suit TOUJOURS celui de
//     son groupe (public XOR privé) », verrouillé par 0060 ;
//   • `schools.school_type`, enum à deux valeurs lui aussi ;
//   • `adminGroupePublicProvider` → le barème de frais public / privé ;
//   • `tutelle_groupes()` rend `group_type` sous le nom `secteur`.
//  Une école catholique EST une école privée. Mettre sa confession dans la
//  colonne du secteur, c'est perdre le secteur.
//
//  ── CE QUE CE FICHIER GARDE ───────────────────────────────────────────────
//  Que les deux listes restent distinctes, que le secteur reste binaire, et
//  qu'aucun écran ne se remette à écrire ses propres libellés — ils l'étaient
//  en QUATRE exemplaires, dont un avec un vocabulaire entièrement inventé
//  (« confessionnel », « ministere », « reseau »).
// ════════════════════════════════════════════════════════════════════════════

const _formulaire =
    'lib/features/super_admin/screens/groups/group_form_modal.dart';
const _liste = 'lib/features/super_admin/screens/school_groups_screen.dart';
const _reglages =
    'lib/features/admin_groupe/screens/admin_settings_screen.dart';
const _migration =
    '../database/migrations/0180_AVANT_LE_BUILD_le_caractere_nest_pas_le_secteur.sql';

String _lire(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) fail('Fichier introuvable : $chemin — sonde aveugle.');
  return f.readAsStringSync().replaceAll('\r\n', '\n');
}

void main() {
  group('Le secteur reste binaire', () {
    test('deux valeurs, pas une de plus', () {
      // ⚠️ Ce test est la barrière. Y ajouter une valeur « pour l'afficher »
      // casse le barème de frais, l'héritage du type d'école et la vue de
      // tutelle — dans cet ordre, et sans un message d'erreur.
      expect(kSecteursGroupe, ['public', 'prive']);
    });

    test('aucune confession n’a pu se glisser dans le secteur', () {
      for (final interdit in ['catholique', 'islamique', 'protestant']) {
        expect(kSecteursGroupe.contains(interdit), isFalse,
            reason: '« $interdit » est revenu dans le secteur : la création '
                'de groupe échouera de nouveau sur un 22P02.');
      }
    });

    test('il se lit en français, et l’inconnu reste visible', () {
      expect(libelleSecteur('public'), 'Public');
      expect(libelleSecteur('prive'), 'Privé');
      // Une valeur aberrante s'affiche telle quelle plutôt que traduite en
      // « Autre » : on veut la VOIR si elle existe.
      expect(libelleSecteur('catholique'), 'catholique');
      expect(libelleSecteur(null), '—');
    });

    test('estSecteurPublic ne dit vrai que pour le public', () {
      expect(estSecteurPublic('public'), isTrue);
      expect(estSecteurPublic('prive'), isFalse);
      expect(estSecteurPublic(null), isFalse);
    });
  });

  group('Le caractère est l’autre axe', () {
    test('les trois valeurs orphelines y ont trouvé leur place', () {
      for (final c in ['catholique', 'islamique', 'protestant']) {
        expect(kCaracteresGroupe.contains(c), isTrue);
        expect(libelleCaractere(c), isNotNull);
      }
    });

    test('« non renseigné » n’est pas un caractère', () {
      // ⚠️ `null` n'entre pas dans la liste : un groupe dont personne n'a
      // renseigné le caractère n'est pas laïc pour autant.
      expect(kCaracteresGroupe.contains('laic'), isTrue);
      expect(libelleCaractere(null), isNull);
      expect(libelleCaractere(''), isNull);
      expect(caractereConnu(null), isFalse);
      expect(caractereConnu('bouddhiste'), isFalse);
    });

    test('un affichage qui ne supporte pas le vide DIT le manque', () {
      expect(libelleCaractereOuManque(null), 'Non renseigné');
      expect(libelleCaractereOuManque('laic'), 'Laïc');
    });

    test('il ne se saisit que sur un groupe privé', () {
      // Règle d'écran, délibérément pas une contrainte de base : si le terrain
      // nous détrompe, c'est cette ligne qui change.
      expect(caractereSeSaisit('prive'), isTrue);
      expect(caractereSeSaisit('public'), isFalse);
      expect(caractereSeSaisit(null), isFalse);
    });
  });

  group('La base porte bien deux colonnes', () {
    test('la migration ajoute `caractere` sans toucher à l’enum', () {
      final sql = _lire(_migration);
      expect(sql.contains('ADD COLUMN IF NOT EXISTS caractere'), isTrue);
      expect(sql.contains('caractere_groupe'), isTrue);
      expect(sql.contains('ALTER TYPE public.group_type'), isFalse,
          reason: 'L’enum du secteur a été élargi : le barème de frais et '
              'l’héritage du type d’école partent avec.');
    });

    test('les valeurs SQL et Dart sont les mêmes', () {
      // Les deux listes ne peuvent pas se lire l'une l'autre : on les compare.
      final sql = _lire(_migration);
      final i = sql.indexOf('CREATE TYPE public.caractere_groupe');
      expect(i, greaterThan(0));
      final bloc = sql.substring(i, sql.indexOf(';', i));
      for (final c in kCaracteresGroupe) {
        expect(bloc.contains("'$c'"), isTrue,
            reason: '« $c » existe côté Dart mais pas dans l’enum : la saisie '
                'sera refusée en 22P02.');
      }
    });
  });

  group('Les écrans lisent le référentiel au lieu de le recopier', () {
    test('le formulaire propose le secteur ET le caractère', () {
      final src = _lire(_formulaire);
      expect(src.contains('kSecteursGroupe'), isTrue,
          reason: 'Le formulaire a repris une liste locale : c’est comme ça '
              'que « Catholique » s’était retrouvé dans le secteur.');
      expect(src.contains('caractereSeSaisit(_groupType)'), isTrue,
          reason: 'Le caractère est proposé sur un groupe public, ou plus du '
              'tout.');
      expect(src.contains("'caractere':"), isTrue,
          reason: 'Le formulaire n’envoie plus le caractère.');
    });

    test('le filtre ne cherche plus ce qui ne peut pas exister', () {
      final src = _lire(_liste);
      for (final mort in ["'catholique': 'Catholique'", "'islamique': 'Islamique'"]) {
        expect(src.contains(mort), isFalse,
            reason: 'Une entrée de filtre morte est revenue : elle ne peut '
                'rendre aucune ligne.');
      }
    });

    test('l’espace groupe n’a plus son vocabulaire à lui', () {
      final src = _lire(_reglages);
      expect(src.contains("'confessionnel' => 'Confessionnel'"), isFalse,
          reason: 'Le troisième vocabulaire inventé est revenu — aucune base '
              'n’a jamais accepté ces valeurs.');
      expect(src.contains('libelleSecteur('), isTrue);
    });
  });
}
