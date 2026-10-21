import 'dart:io';

import 'package:epilote/core/constants/caractere_groupe.dart';
import 'package:flutter_test/flutter_test.dart';
import 'ecran_groupes_source.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE CARACTÈRE D'UN GROUPE, ET LA DISPARITION DU SECTEUR
//
//  Le formulaire de groupe proposait autrefois « Public · Privé · Catholique ·
//  Islamique · Protestant » dans un seul champ, alors que l'enum `group_type`
//  n'acceptait que deux valeurs : trois choix sur cinq échouaient en 22P02.
//  Le caractère a reçu sa colonne (0180).
//
//  Depuis le recentrage privé (2026-10-21), le SECTEUR a disparu de l'écran :
//  tout groupe est privé. Ce fichier garde le référentiel du caractère, et que
//  le secteur ne revienne pas par la porte d'un formulaire.
// ════════════════════════════════════════════════════════════════════════════

const _migration =
    '../database/migrations/0180_AVANT_LE_BUILD_le_caractere_nest_pas_le_secteur.sql';

String _lire(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) fail('Fichier introuvable : $chemin — sonde aveugle.');
  return f.readAsStringSync().replaceAll('\r\n', '\n');
}

void main() {
  group('Le caractère', () {
    test('les trois confessions ont leur place', () {
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
  });

  group('La base porte la colonne', () {
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

  group('Le secteur ne revient pas', () {
    test('le formulaire n’envoie plus de secteur, mais bien le caractère', () {
      final src = sourceFormulaireGroupe();
      expect(src.contains("'group_type':"), isFalse,
          reason: 'Le formulaire écrit de nouveau le secteur : la colonne ne '
              'pourra plus être retirée sans casser la création de groupe.');
      expect(src.contains("'caractere':"), isTrue,
          reason: 'Le formulaire n’envoie plus le caractère.');
    });

    test('le filtre ne cherche pas ce qui ne peut pas exister', () {
      final src = sourceEcranGroupes();
      for (final mort in ["'catholique': 'Catholique'", "'islamique': 'Islamique'"]) {
        expect(src.contains(mort), isFalse,
            reason: 'Une entrée de filtre morte est revenue : elle ne peut '
                'rendre aucune ligne.');
      }
    });
  });
}
