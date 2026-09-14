// La fiche élève montre onze registres. Presque tout y est de la présentation,
// mais quatre calculs décident de ce qu'un agent lit — et chacun a une manière
// silencieuse de mentir :
//
//  • l'ÂGE, à cause des enfants nés en fin d'année : c'est sur eux que se
//    jouent les limites d'âge aux examens d'État ;
//  • le TAUX DE PRÉSENCE, s'il se calcule sur des séances jamais relevées ;
//  • la NOTE RAMENÉE SUR 20, sans quoi un devoir sur 40 et une interrogation
//    sur 10 se lisent comme s'ils disaient la même chose ;
//  • le RANG, qui ne veut rien dire sans son effectif.
//
// S'y ajoutent les LIBELLÉS : le défaut que la fiche corrige est l'affichage du
// code brut — « ajourne », « withdrawn », « monoparentale_pere » — à l'endroit
// même où un agent vérifie une situation avant d'appeler une famille. Les
// valeurs testées ici sont celles relevées en production le 2026-09-10.

import 'package:epilote/core/utils/scolarite_libelles.dart';
import 'package:epilote/features/students/providers/fiche_eleve_finance_provider.dart';
import 'package:epilote/features/students/providers/fiche_eleve_resultats_provider.dart';
import 'package:epilote/features/students/providers/fiche_eleve_vie_provider.dart';
import 'package:epilote/features/students/providers/student_dossier_provider.dart';
import 'package:flutter_test/flutter_test.dart';

StudentDossier _eleve(Map<String, dynamic> champs) =>
    StudentDossier(student: champs, tutors: const []);

BulletinLigne _bulletin({int? rang, int? effectif}) => BulletinLigne(
      id: 'b1',
      anneeId: 'a1',
      anneeLabel: '2025-2026',
      trimestre: 'Trimestre 1',
      trimestreNum: 1,
      moyenne: 12.5,
      moyenneClasse: 11,
      rang: rang,
      effectif: effectif,
      mention: 'Assez bien',
      decision: '',
      absences: 2,
      retards: 0,
      statut: 'published',
      appreciationProf: '',
      appreciationDirecteur: '',
      publieLe: null,
    );

NoteLigne _note({double? score, double? bareme, bool absent = false}) =>
    NoteLigne(
      matiere: 'Mathématiques',
      trimestre: 'Trimestre 1',
      titre: 'Devoir 1',
      type: 'devoir',
      date: DateTime(2025, 11, 4),
      note: score,
      bareme: bareme,
      coefficient: 2,
      absent: absent,
      appreciation: '',
    );

VersementLigne _versement({
  required String statut,
  DateTime? annuleLe,
}) =>
    VersementLigne(
      date: DateTime(2025, 10, 2),
      montant: 15000,
      libelle: 'Frais d\'inscription',
      typeFrais: 'inscription',
      methode: 'especes',
      recu: 'R-0042',
      reference: '',
      statut: statut,
      periode: '',
      anneeLabel: '2025-2026',
      annuleLe: annuleLe,
      motifAnnulation: '',
      rembourse: 0,
      notes: '',
    );

void main() {
  group("L'âge de l'élève", () {
    test('un anniversaire déjà passé cette année compte', () {
      final naissance = DateTime.now().subtract(const Duration(days: 366 * 12));
      final d = _eleve({
        'date_of_birth': naissance.toIso8601String().substring(0, 10),
      });
      expect(d.age, isNotNull);
      expect(d.age, greaterThanOrEqualTo(11));
    });

    test('un anniversaire PAS ENCORE passé ne compte pas — le piège de décembre',
        () {
      // Né il y a presque douze ans, mais l'anniversaire tombe demain.
      final demain = DateTime.now().add(const Duration(days: 1));
      final naissance = DateTime(demain.year - 12, demain.month, demain.day);
      final d = _eleve({
        'date_of_birth': naissance.toIso8601String().substring(0, 10),
      });
      // Onze, et non douze : c'est exactement l'écart qui décide d'une
      // recevabilité à un examen d'État.
      expect(d.age, 11);
    });

    test('sans date de naissance, il n\'y a pas d\'âge — et pas de zéro', () {
      expect(_eleve(const {}).age, isNull);
      expect(_eleve(const {'date_of_birth': ''}).age, isNull);
    });

    test('le nom complet met le patronyme en tête, comme un registre', () {
      final d = _eleve(const {'first_name': 'Aïcha', 'last_name': 'NGOMA'});
      expect(d.nomComplet, 'NGOMA Aïcha');
    });

    test('un nom incomplet ne laisse pas traîner d\'espace', () {
      expect(_eleve(const {'last_name': 'NGOMA'}).nomComplet, 'NGOMA');
      expect(_eleve(const {}).nomComplet, '');
    });
  });

  group('Le taux de présence', () {
    test('porte sur les séances RELEVÉES, pas sur une année théorique', () {
      const a = Assiduite(
        seances: 100,
        absences: 10,
        retards: 5,
        justifiees: 3,
        manquements: [],
      );
      // 90 séances sur 100 — les retards ne retirent pas une présence.
      expect(a.tauxPresence, 90);
    });

    test("sans appel relevé, il n'y a pas de taux — surtout pas 0 %", () {
      const a = Assiduite(
        seances: 0,
        absences: 0,
        retards: 0,
        justifiees: 0,
        manquements: [],
      );
      // ⚠️ 0 % ferait passer pour absent un élève dont personne n'a fait
      // l'appel. `null` dit « on ne sait pas », et l'écran affiche « — ».
      expect(a.tauxPresence, isNull);
      expect(a.vide, isTrue);
    });
  });

  group('La note ramenée sur 20', () {
    test('un devoir sur 40 se lit à sa juste hauteur', () {
      expect(_note(score: 30, bareme: 40).sur20, 15);
    });

    test('une interrogation sur 10 aussi', () {
      expect(_note(score: 7, bareme: 10).sur20, 14);
    });

    test('un barème absent ou nul ne produit pas de division', () {
      expect(_note(score: 12, bareme: null).sur20, isNull);
      expect(_note(score: 12, bareme: 0).sur20, isNull);
      expect(_note(score: null, bareme: 20).sur20, isNull);
    });
  });

  group('Le rang', () {
    test("s'écrit avec son effectif — « 8ᵉ » seul ne dit rien", () {
      expect(_bulletin(rang: 8, effectif: 52).rangLabel, '8 / 52');
    });

    test('sans effectif connu, le rang reste seul plutôt que faux', () {
      expect(_bulletin(rang: 8, effectif: null).rangLabel, '8');
      expect(_bulletin(rang: 8, effectif: 0).rangLabel, '8');
    });

    test('aucun rang arrêté ne devient pas un rang zéro', () {
      expect(_bulletin(rang: null, effectif: 52).rangLabel, '—');
    });
  });

  group('Les versements', () {
    test('seul un versement confirmé entre dans un total', () {
      expect(_versement(statut: 'confirmed').compte, isTrue);
      // ⚠️ « En attente » est une promesse, « annulé » une opération défaite.
      // Les additionner ferait dire à la caisse qu'elle a encaissé ce qu'elle
      // n'a pas.
      expect(_versement(statut: 'pending').compte, isFalse);
      expect(_versement(statut: 'cancelled').compte, isFalse);
    });

    test('un versement annulé reste reconnaissable', () {
      expect(_versement(statut: 'cancelled').annule, isTrue);
      // Annulé par la date, même si le statut n'a pas suivi : la famille tient
      // un reçu, la fiche doit le retrouver.
      expect(
        _versement(statut: 'confirmed', annuleLe: DateTime(2025, 11, 3)).annule,
        isTrue,
      );
      expect(_versement(statut: 'confirmed').annule, isFalse);
    });
  });

  group('Les libellés de la scolarité', () {
    test('les codes réellement présents en base sont tous traduits', () {
      // Relevé de production du 2026-09-10 : ces valeurs-là existent, et
      // aucune ne doit s'afficher brute devant un agent.
      expect(enrollmentStatutLabel('withdrawn'), 'Retirée');
      expect(inscriptionTypeLabel('reinscription'), 'Réinscription');
      expect(examResultatLabel('ajourne'), 'Ajourné');
      expect(examDossierLabel('incomplet'), 'Incomplet');
      expect(stageStatutLabel('interrompu'), 'Interrompu');
      expect(transfertStatutLabel('completed'), 'Effectué');
      expect(paiementStatutLabel('confirmed'), 'Confirmé');
      expect(presenceStatutLabel('late'), 'En retard');
      expect(repasLabel('dejeuner'), 'Déjeuner');
      expect(
        documentDelivreLabel('certificat_scolarite'),
        'Certificat de scolarité',
      );
    });

    test('le verdict de passage et la distinction ne se confondent pas', () {
      // Deux colonnes distinctes en base, gardées par `core/utils/decisions.dart`.
      // Un « félicitations » lu comme un verdict de passage ferait monter de
      // classe un élève que personne n'a fait passer.
      expect(verdictPassageLabel('redouble'), 'Redouble');
      expect(distinctionConseilLabel('felicitations'), 'Félicitations');
    });

    test('un code INCONNU s\'affiche tel quel, il ne disparaît pas', () {
      // ⚠️ Un code inconnu remplacé par « — » est une information perdue et un
      // défaut qu'on ne verra jamais. Le laisser visible, c'est le signaler.
      expect(enrollmentStatutLabel('etat_inedit'), 'etat_inedit');
      expect(examResultatLabel('nouveau_code'), 'nouveau_code');
    });

    test('l\'absence de valeur se dit par un tiret, pas par du vide', () {
      expect(enrollmentStatutLabel(null), '—');
      expect(enrollmentStatutLabel(''), '—');
      // La distinction fait exception : la plupart des bulletins n'en portent
      // aucune, et « — » dans cette colonne se lirait comme une décision.
      expect(distinctionConseilLabel(null), '');
    });
  });
}
