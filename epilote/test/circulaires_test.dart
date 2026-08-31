import 'dart:io';

import 'package:epilote/features/communication/providers/circulaires_provider.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LA CIRCULAIRE DE TUTELLE
//
//  Toute la valeur du dispositif tient dans une colonne : `lu_le`. Une
//  circulaire dont on ne peut pas prouver la réception n'a aucune valeur
//  administrative — les tests portent donc sur le COMPTAGE des accusés et sur
//  ce que la base autorise à écrire.
// ════════════════════════════════════════════════════════════════════════════

Circulaire _c({
  int destinataires = 0,
  int lus = 0,
  List<CirculaireEcole> mesEcoles = const [],
  bool accuseRequis = true,
  DateTime? publieeLe,
}) =>
    Circulaire(
      id: 'c1',
      emetteurGroupId: 'g1',
      objet: 'Objet',
      corps: 'Corps',
      priorite: CirculairePriorite.normale,
      accuseRequis: accuseRequis,
      createdAt: DateTime(2026, 8, 1),
      publieeLe: publieeLe,
      nbDestinataires: destinataires,
      nbLus: lus,
      mesEcoles: mesEcoles,
    );

CirculaireEcole _e(String id, {DateTime? lu}) =>
    CirculaireEcole(schoolId: id, nom: 'École $id', groupId: 'g2', luLe: lu);

void main() {
  group('Le taux de lecture', () {
    test('se calcule sur l\'assiette figée à la publication', () {
      expect(_c(destinataires: 25, lus: 5).tauxLecture, 20);
      expect(_c(destinataires: 4, lus: 4).tauxLecture, 100);
    });

    // ⚠️ LE PIÈGE. « 0 % lu » sur une circulaire qui n'est allée à personne se
    // lirait comme un échec de diffusion, alors qu'il n'y avait rien à
    // diffuser. L'absence de destinataire n'est pas un taux nul.
    test('n\'existe pas sans destinataire — et ne vaut pas 0 %', () {
      expect(_c(destinataires: 0, lus: 0).tauxLecture, isNull);
    });
  });

  group('L\'accusé côté destinataire', () {
    test('se compte école par école, jamais par groupe', () {
      // Un groupe de trois écoles qui accuserait « pour tout le monde » d'un
      // seul clic produirait une preuve fausse.
      final c = _c(mesEcoles: [
        _e('1', lu: DateTime(2026, 8, 20)),
        _e('2'),
        _e('3', lu: DateTime(2026, 8, 21)),
      ]);
      expect(c.nbMesEcolesLues, 2);
      expect(c.toutesLues, isFalse);
    });

    test('« toutes lues » est faux quand il n\'y a aucune école', () {
      // `every` sur une liste vide vaut `true` : sans garde, un groupe sans
      // destinataire serait compté comme ayant tout lu.
      expect(_c(mesEcoles: const []).toutesLues, isFalse);
    });

    test('« toutes lues » est vrai quand chacune a accusé', () {
      final c = _c(mesEcoles: [
        _e('1', lu: DateTime(2026, 8, 20)),
        _e('2', lu: DateTime(2026, 8, 20)),
      ]);
      expect(c.toutesLues, isTrue);
    });
  });

  group('Publication', () {
    test('une circulaire sans date de publication est un brouillon', () {
      expect(_c().publiee, isFalse);
      expect(_c(publieeLe: DateTime(2026, 8, 20)).publiee, isTrue);
    });
  });

  // ── Les gardes qui comptent vraiment ──────────────────────────────────────
  group('Ce que la base ne doit jamais autoriser', () {
    String _sql() {
      final f = File('../database/migrations/'
          '0161_AVANT_LE_BUILD_la_circulaire_de_tutelle.sql');
      expect(f.existsSync(), isTrue,
          reason: 'Sonde aveugle : la migration 0161 est introuvable.');
      return f.readAsStringSync();
    }

    test('aucune politique d\'UPDATE sur les accusés de lecture', () {
      // Un UPDATE que le `USING` d'une politique écarte ne lève RIEN : zéro
      // ligne, 204, et l'écran affiche « enregistré ». Trouvé trois fois dans
      // ce dépôt le 2026-08-30. Ici l'accusé passe par une RPC, qui LÈVE.
      final sql = _sql();
      final policies = RegExp(r'CREATE POLICY\s+(\w+)\s+ON\s+public\.(\w+)\s+FOR\s+(\w+)')
          .allMatches(sql);
      expect(policies, isNotEmpty, reason: 'Sonde aveugle : aucune politique lue.');
      for (final m in policies) {
        if (m.group(2) == 'circulaire_destinataires') {
          expect(m.group(3), isNot('UPDATE'),
              reason: 'La politique « ${m.group(1)} » ouvre un UPDATE direct '
                  'sur les accusés. Un refus y serait MUET — passer par '
                  '`circulaire_accuser`.');
        }
      }
      expect(sql.contains('circulaire_accuser'), isTrue);
    });

    test('les destinataires sont des établissements, jamais des personnes', () {
      // La chaîne est ministère → groupe / chef d'établissement. Un canal par
      // lequel l'État écrirait aux familles d'une école privée ne se déciderait
      // pas par commodité technique — et ne se refermerait plus.
      final sql = _sql();
      final publier = sql.substring(sql.indexOf('circulaire_publier'));
      for (final interdit in ["'parent'", "'eleve'", 'students', 'student_tutors']) {
        expect(publier.contains(interdit), isFalse,
            reason: 'La publication touche « $interdit » : une circulaire '
                's\'adresse aux ETABLISSEMENTS.');
      }
    });

    test('la liste des destinataires est figée, pas recalculée', () {
      // Une école créée le mois suivant n'a pas à apparaître « en défaut de
      // lecture » d'une circulaire envoyée avant qu'elle n'existe.
      final sql = _sql();
      expect(sql.contains('CREATE TABLE IF NOT EXISTS public.circulaire_destinataires'),
          isTrue,
          reason: 'Les destinataires doivent être MATÉRIALISÉS dans une table.');
      expect(sql.contains('deja publiee'), isTrue,
          reason: 'La republication doit être refusée, sinon l\'assiette bouge '
              'après coup et le taux de lecture ne veut plus rien dire.');
    });

    test('le ciblage compare le bon type d\'énumération', () {
      // `school_type_enum` et `group_type` portent les MÊMES libellés
      // (public | prive). Les confondre ne se voit qu'à la publication, où
      // Postgres refuse la comparaison (42883) — donc au pire moment.
      final sql = _sql();
      expect(sql.contains('cible_secteur     school_type_enum'), isTrue,
          reason: 'cible_secteur doit être un school_type_enum : il se compare '
              'à schools.school_type.');
    });
  });
}
