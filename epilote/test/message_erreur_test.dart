import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:epilote/core/utils/erreur_metier.dart';
import 'package:epilote/core/utils/message_erreur.dart';

// Ce qui compte ici n'est pas la formulation exacte — elle bougera — mais que
// l'agent ne voie JAMAIS le nom d'une exception, un code Postgres nu, ou le
// mot « null ». Les tests portent donc sur ces garanties-là.
void main() {
  const bruitTechnique = [
    'PostgrestException',
    'AuthException',
    'StorageException',
    'SocketException',
    'Exception',
    'null',
    'PGRST',
  ];

  void neDoitPasFuir(String message) {
    for (final mot in bruitTechnique) {
      expect(message.contains(mot), isFalse,
          reason: 'le message montre « $mot » à l’agent : "$message"');
    }
    expect(message.trim(), isNotEmpty);
  }

  group('aucune fuite technique vers l’agent', () {
    final cas = <String, Object>{
      'jeton expiré': const PostgrestException(
          message: 'JWT expired', code: 'PGRST303', details: 'Unauthorized'),
      'refus RLS': const PostgrestException(
          message: 'permission denied for view v_x', code: '42501'),
      'doublon': const PostgrestException(
          message: 'duplicate key value', code: '23505'),
      'clé étrangère': const PostgrestException(
          message: 'violates foreign key', code: '23503'),
      'champ obligatoire': const PostgrestException(
          message: 'null value in column', code: '23502'),
      'format invalide': const PostgrestException(
          message: 'invalid input syntax', code: '22P02'),
      'introuvable': const PostgrestException(
          message: 'no rows', code: 'PGRST116'),
      'réseau': const SocketException('Failed host lookup'),
      'délai dépassé': TimeoutException('trop long'),
      'format': const FormatException('mauvais json'),
    };

    cas.forEach((nom, erreur) {
      test(nom, () => neDoitPasFuir(messageErreur(erreur)));
    });

    test('erreur inconnue reste lisible', () {
      final m = messageErreur(StateError('boom'));
      expect(m, isNotEmpty);
      expect(m.contains('boom'), isFalse,
          reason: 'le détail interne ne doit pas remonter');
    });

    test('null ne produit pas le mot « null »', () {
      neDoitPasFuir(messageErreur(null));
    });
  });

  group('contenu utile', () {
    test('une session expirée dit de se reconnecter', () {
      final m = messageErreur(const PostgrestException(
          message: 'JWT expired', code: 'PGRST303'));
      expect(m.toLowerCase(), contains('reconnect'));
      // Rassurer explicitement : l'agent doit savoir qu'il n'a rien perdu.
      expect(m.toLowerCase(), contains('perdu'));
    });

    test('un refus RLS parle de DROITS, pas de session', () {
      final m = messageErreur(const PostgrestException(
          message: 'permission denied', code: '42501'));
      expect(m.toLowerCase(), contains('droits'));
      expect(m.toLowerCase(), isNot(contains('expir')));
    });

    test('le contexte préfixe le message', () {
      final m =
          messageErreur(const SocketException('x'), contexte: 'Impression');
      expect(m, startsWith('Impression — '));
    });

    test('sans contexte, aucun préfixe parasite', () {
      expect(messageErreur(const SocketException('x')), isNot(contains('—')));
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  //  CE QUE L'APPLICATION DIT ELLE-MÊME PASSE TEL QUEL (2026-08-28)
  //
  //  Quarante et quelques gardes pré-valident une écriture AVANT que la base ne
  //  la refuse — précisément pour éviter un code fatal à la synchro, qui ferait
  //  jeter le lot entier. Chacun lève une phrase écrite pour l'agent :
  //  « Une classe « 6e A » existe déjà pour cette année scolaire. », « Cet INE
  //  est déjà rattaché à un élève de l'établissement. »
  //
  //  Toutes tombaient dans le repli final : « Une erreur inattendue est
  //  survenue. (_Exception) ». L'agent ne voyait pas la cause, ne savait pas
  //  quoi corriger, et recommençait le même geste. Le garde parlait dans le
  //  vide.
  // ══════════════════════════════════════════════════════════════════════════
  group('Les messages écrits par l\'application arrivent à l\'agent', () {
    test('une `ErreurMetier` s\'affiche mot pour mot', () {
      expect(
          messageErreur(const ErreurMetier(
              'Cet élève est déjà inscrit pour cette année scolaire.')),
          'Cet élève est déjà inscrit pour cette année scolaire.');
    });

    test('le TYPE sépare le message du détail interne', () {
      // `StateError('boom')` venu d'une bibliothèque reste un incident
      // technique et ne remonte pas — c'est la règle d'origine, gardée plus
      // haut. Deviner d'après le texte aurait opposé les deux règles ; le type
      // les concilie.
      expect(messageErreur(const ErreurMetier('Choisissez un groupe.')),
          'Choisissez un groupe.');
      expect(messageErreur(StateError('boom')), isNot(contains('boom')));
    });

    test('une phrase sans point final en reçoit un', () {
      expect(messageErreur(const ErreurMetier('Groupe introuvable')),
          'Groupe introuvable.');
    });

    test('le repli générique ne les avale plus', () {
      for (final e in <Object>[
        const ErreurMetier('Aucun créneau à copier'),
        const ErreurMetier('Ce poste a déjà une ligne budgétaire cette année.'),
      ]) {
        expect(messageErreur(e), isNot(contains('inattendue')),
            reason: 'Le garde du module a écrit une phrase : elle doit '
                'arriver à l\'agent, sinon il refait le même geste.');
      }
    });

    test('le contexte préfixe aussi ces messages', () {
      expect(
          messageErreur(const ErreurMetier('Aucun créneau à copier'),
              contexte: 'Duplication'),
          'Duplication — Aucun créneau à copier.');
    });

    test('les exceptions typées gardent leur traduction', () {
      // `PostgrestException` est une `Exception` : le déballage ne doit pas
      // court-circuiter la traduction par code, ni recracher un message
      // technique anglais à la figure de l'agent.
      final m = messageErreur(
          const PostgrestException(message: 'permission denied', code: '42501'));
      expect(m.toLowerCase(), contains('droits'));
      expect(m, isNot(contains('permission denied')));
    });

    test('les gardes des modules lèvent bien ce type', () {
      // Le garde qui parle dans le vide ne sert à rien : si un module
      // pré-valide une écriture, sa phrase doit arriver à l'agent.
      const sites = <String>[
        'lib/features/classes/providers/class_provider.dart',
        'lib/features/students/providers/students_provider.dart',
        'lib/features/finance/providers/budget_provider.dart',
        'lib/features/staff/providers/payroll_provider.dart',
        'lib/features/communication/providers/announcements_provider.dart',
      ];
      for (final chemin in sites) {
        final src = File(chemin).readAsStringSync().replaceAll('\r\n', '\n');
        expect(RegExp(r'throw (const )?ErreurMetier\(').hasMatch(src), isTrue,
            reason: '$chemin doit lever `ErreurMetier` : levée en '
                '`Exception`, sa phrase est remplacée par « Une erreur '
                'inattendue est survenue. »');
        expect(src.contains('throw Exception('), isFalse,
            reason: '$chemin lève encore une `Exception` anonyme.');
      }
    });
  });
}
