import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  BIBLIOTHÈQUE — LA DISPONIBILITÉ NE SE STOCKE PAS, ELLE SE CALCULE
//
//  ── D1. UN COMPTEUR INCRÉMENTÉ NE SURVIT PAS À L'OFFLINE (2026-08-28) ──────
//  `available_quantity` était tenu par incréments : `- 1` au prêt, `+ 1` au
//  retour. Le connecteur ne rejoue pas le SQL, il remonte la VALEUR RÉSULTANTE
//  de la colonne. Deux postes hors ligne passent chacun 5 à 4 et envoient
//  « 4 » : deux prêts enregistrés, un exemplaire disparu du compte. Et rien ne
//  le rattrape — le compteur ne se recalculait nulle part. Tombé à zéro, il
//  refusait de prêter un livre posé sur l'étagère.
//
//  ── D2. CINQ EXEMPLAIRES, UN SEUL PRÊT ────────────────────────────────────
//  Un index unique PARTIEL, `uq_library_loans_item_en_cours (item_id) WHERE
//  return_date IS NULL`, limitait chaque OUVRAGE à un prêt simultané — quel
//  que soit `quantity`. Le deuxième élève recevait un 23505 : code fatal, lot
//  PowerSync entier jeté, pendant que l'écran affichait « 4 dispo ».
//  Migration 0134 : la règle devient « un même emprunteur ne peut pas avoir
//  deux fois le même ouvrage en cours », et le PLAFOND — qui dépend d'un
//  compte, pas d'une clé — se tient dans `createLoan`, en message lisible.
// ════════════════════════════════════════════════════════════════════════════

const _kProvider = 'lib/features/vie_scolaire/providers/biblio_provider.dart';
const _kMigration =
    '../database/migrations/0133_un_compteur_qui_derive_et_ne_revient_jamais.sql';

/// Le prédicat « ce prêt est en cours ». Il doit être LE MÊME des deux côtés :
/// le client calcule la disponibilité hors ligne, le déclencheur la calcule au
/// serveur, et deux définitions divergentes donneraient deux vérités.
const _kPredicat = 'return_date IS NULL';
const _kPredicatStatut = "COALESCE(l.status, 'active') <> 'returned'";

String _lire(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) fail('$chemin introuvable — tourner depuis `epilote/`.');
  return f.readAsStringSync().replaceAll('\r\n', '\n');
}

void main() {
  group('La disponibilité est dérivée, jamais stockée', () {
    test('le client n\'écrit plus `available_quantity`', () {
      final src = _lire(_kProvider);
      // On vise les ÉCRITURES : la colonne peut encore être nommée dans les
      // commentaires qui expliquent pourquoi on n'y touche plus.
      final ecrits = RegExp(
        r'(UPDATE\s+library_items[^;]*available_quantity\s*=)'
        r'|(INSERT\s+INTO\s+library_items[^)]*available_quantity)',
        dotAll: true,
        caseSensitive: false,
      );
      expect(ecrits.hasMatch(src), isFalse,
          reason: 'Un incrément écrit depuis un poste hors ligne remonte comme '
              'valeur absolue et écrase celui d\'un autre poste : un '
              'exemplaire disparaît du compte, définitivement.');
    });

    test('elle se recalcule à la lecture du catalogue', () {
      final src = _lire(_kProvider);
      expect(src.contains('AS dispo'), isTrue,
          reason: 'Le catalogue doit dériver la disponibilité, pas lire une '
              'colonne que personne ne recalcule.');
      expect(src.contains("r['dispo']"), isTrue);
      expect(src.contains("r['available_quantity']"), isFalse);
    });

    test('le plafond se COMPTE avant d\'accorder un prêt', () {
      final src = _lire(_kProvider);
      final i = src.indexOf('Future<String?> createLoan(');
      expect(i, greaterThan(0));
      final corps = src.substring(i, (i + 2200).clamp(i, src.length));
      expect(corps.contains('COUNT(*)'), isTrue,
          reason: 'Le nombre d\'exemplaires sortis se compte sur les prêts.');
      expect(corps.contains('Aucun exemplaire disponible'), isTrue);
      expect(corps.contains('available_quantity'), isFalse);
    });
  });

  group('Client et serveur tiennent la MÊME formule', () {
    test('le même prédicat « prêt en cours » des deux côtés', () {
      final dart = _lire(_kProvider);
      final sql = _lire(_kMigration);
      for (final p in const [_kPredicat, _kPredicatStatut]) {
        expect(dart.contains(p), isTrue,
            reason: 'Absent du client : « $p ».');
        expect(sql.contains(p), isTrue,
            reason: 'Absent de la migration : « $p ».');
      }
    });

    test('le déclencheur ÉCRASE, il ne refuse pas', () {
      final sql = _lire(_kMigration);
      expect(sql.contains('NEW.available_quantity :='), isTrue,
          reason: 'Une valeur cliente fausse doit être remplacée, jamais '
              'rejetée : une exception serait un code fatal pour le '
              'connecteur, qui jetterait le lot entier.');
      expect(RegExp(r'RAISE\s+EXCEPTION').hasMatch(sql), isFalse,
          reason: 'Aucun refus dans ces déclencheurs.');
    });
  });

  group('Un emprunteur n\'a pas deux fois le même ouvrage', () {
    test('le doublon se dit en clair, pas en 23505', () {
      final src = _lire(_kProvider);
      expect(src.contains('SELECT id FROM library_loans '), isTrue,
          reason: 'La relecture locale doit précéder l\'écriture : laisser '
              'l\'index partiel trancher coûterait le lot entier.');
      expect(src.contains('a déjà cet ouvrage en prêt'), isTrue,
          reason: 'Et le refus doit être une phrase, pas un code.');
    });

    test('l\'index de la base porte bien la règle du 0134', () {
      final sql = _lire(
          '../database/migrations/0134_cinq_exemplaires_un_seul_pret.sql');
      expect(sql.contains('DROP INDEX IF EXISTS uq_library_loans_item_en_cours'),
          isTrue);
      expect(sql.contains('(item_id, borrower_id)'), isTrue,
          reason: 'La règle porte sur le couple ouvrage × emprunteur — pas sur '
              'l\'ouvrage seul, qui rendait le catalogue multi-exemplaires '
              'inutilisable.');
    });
  });
}
