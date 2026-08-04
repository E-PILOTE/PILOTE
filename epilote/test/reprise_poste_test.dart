import 'package:epilote/features/auth/services/session_keeper.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  NE PLUS ENFERMER UNE ÉCOLE DEHORS
//
//  Le 2026-08-04, la session Supabase d'un poste est morte toute seule et
//  l'application est retombée sur l'écran e-mail + mot de passe. Dans une école
//  congolaise, cet écran est un mur : les agents ne connaissent que leur code à
//  quatre chiffres, et le mot de passe du compte de l'établissement a été saisi
//  une fois, le jour de l'installation.
//
//  Ces tests gardent les deux décisions qui ouvrent — ou non — la porte de
//  secours. Elles sont pures exprès : la reprise d'un poste ne doit pas dépendre
//  de ce qu'on arrive à joindre au moment où justement on ne joint plus rien.
// ════════════════════════════════════════════════════════════════════════════

void main() {
  group('quelle porte au démarrage', () {
    test('session valide : rien à reprendre', () {
      expect(
        porteDeReprise(
            sessionOuverte: true,
            posteConnu: true,
            donneesLocalesPresentes: true),
        PorteDeReprise.aucune,
      );
    });

    test('le poste se reconnaît ET tient ses données : reprise', () {
      expect(
        porteDeReprise(
            sessionOuverte: false,
            posteConnu: true,
            donneesLocalesPresentes: true),
        PorteDeReprise.reprisePossible,
        reason: 'c\'est exactement la panne du 2026-08-04',
      );
    });

    test('poste connu mais base vide : écran de connexion habituel', () {
      // Rouvrir une application sans données serait pire qu'un écran de
      // connexion : elle aurait l'air cassée, et il n'y aurait rien à y faire.
      expect(
        porteDeReprise(
            sessionOuverte: false,
            posteConnu: true,
            donneesLocalesPresentes: false),
        PorteDeReprise.connexionHabituelle,
      );
    });

    test('appareil neuf : écran de connexion habituel', () {
      expect(
        porteDeReprise(
            sessionOuverte: false,
            posteConnu: false,
            donneesLocalesPresentes: false),
        PorteDeReprise.connexionHabituelle,
      );
    });

    test('des données sans identité connue : on ne devine pas qui c\'est', () {
      expect(
        porteDeReprise(
            sessionOuverte: false,
            posteConnu: false,
            donneesLocalesPresentes: true),
        PorteDeReprise.connexionHabituelle,
      );
    });
  });

  group('faut-il un code pour reprendre', () {
    test('des agents ont enrôlé un code : on l\'exige', () {
      expect(exigePinPourReprise(1), isTrue);
      expect(exigePinPourReprise(12), isTrue);
    });

    test('aucun code sur ce poste : on n\'en invente pas', () {
      // Poste personnel d'un directeur : le verrou d'agent ne s'affiche jamais,
      // donc aucun PIN n'existe. Exiger un code jamais créé enfermerait dehors,
      // à coup sûr, l'établissement qu'on prétend protéger — pour un gain nul :
      // qui tient la machine tient déjà le fichier SQLite.
      expect(exigePinPourReprise(0), isFalse);
    });
  });

  group('mémoire du poste', () {
    final vu = DateTime.utc(2026, 7, 24, 8);

    test('aller-retour JSON complet', () {
      final source = IdentitePoste(
        userId: 'c7e339bf-69ce-3b4a-7d46-a3da95c0a090',
        email: 'dir.lt1ermai@epilote.cg',
        vueLe: vu,
        role: 'directeur',
        schoolId: '7ca82e90-8da9-b467-1191-8e88d1cdb916',
      );
      final relu = IdentitePoste.fromJson(source.toJson())!;
      expect(relu.userId, source.userId);
      expect(relu.email, source.email);
      expect(relu.role, 'directeur');
      expect(relu.schoolId, source.schoolId);
      expect(relu.vueLe, source.vueLe);
    });

    test('une mémoire sans identifiant ne vaut rien', () {
      expect(IdentitePoste.fromJson({'email': 'x@y.cg'}), isNull);
      expect(IdentitePoste.fromJson({'user_id': '', 'email': 'x@y.cg'}), isNull);
    });

    test('depuis combien de jours le serveur n\'a pas été vu', () {
      final p = IdentitePoste(userId: 'u', email: 'e', vueLe: vu);
      expect(
          p.joursDepuisLaDerniereSession(DateTime.utc(2026, 8, 4, 8)), 11,
          reason: 'c\'est ce nombre que la bannière montre à l\'école');
    });

    test('une date illisible ne fait pas disparaître la mémoire', () {
      // Mieux vaut une date fausse qu'un poste qui ne se reconnaît plus.
      final p = IdentitePoste.fromJson(
          {'user_id': 'u', 'email': 'e', 'vue_le': 'pas une date'});
      expect(p, isNotNull);
    });
  });
}
