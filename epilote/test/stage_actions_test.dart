import 'package:flutter_test/flutter_test.dart';

import 'package:epilote/features/stages/providers/stage_actions.dart';
import 'package:epilote/features/stages/providers/stages_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  STAGES — les règles que le module applique tout seul.
//
//  Le statut d'un stage est DÉDUIT de ses dates, jamais demandé à l'agent : un
//  agent qui saisit un stage de mars n'a aucune raison de cocher « terminé », et
//  l'oublierait — ce qui masquerait l'alerte d'attestation, donc l'irrecevabilité
//  du dossier de bac. La déduction est le garde-fou.
// ════════════════════════════════════════════════════════════════════════════

DateTime _inDays(int d) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day).add(Duration(days: d));
}

InternshipRow _row({
  required InternshipStatus status,
  bool attestation = false,
}) =>
    InternshipRow(
      id: 'i1',
      studentName: 'Élève Test',
      className: 'Tle F2',
      companyName: 'SOTEC',
      title: 'Stage atelier',
      startDate: _inDays(-60),
      endDate: _inDays(-30),
      status: status,
      hasAttestation: attestation,
      conventionSigned: true,
    );

void main() {
  group('statusFromDates — le statut se déduit', () {
    test('sans date de début -> prévu', () {
      expect(statusFromDates(null, null), 'prevu');
      expect(statusFromDates(null, _inDays(30)), 'prevu');
    });

    test('début dans le futur -> prévu', () {
      expect(statusFromDates(_inDays(10), _inDays(40)), 'prevu');
    });

    test('commencé, fin dans le futur -> en cours', () {
      expect(statusFromDates(_inDays(-10), _inDays(20)), 'en_cours');
    });

    test('fin dans le passé -> terminé', () {
      expect(statusFromDates(_inDays(-60), _inDays(-30)), 'termine');
    });

    test('commencé SANS date de fin -> en cours (on n\'invente pas la fin)', () {
      expect(statusFromDates(_inDays(-10), null), 'en_cours');
    });

    test('commencé aujourd\'hui -> en cours, pas prévu', () {
      expect(statusFromDates(_inDays(0), _inDays(30)), 'en_cours');
    });

    test('fini aujourd\'hui -> en cours : le stage n\'est pas encore fini', () {
      // `end.isBefore(aujourd'hui)` est faux le jour même — le dernier jour
      // compte. Déclarer « terminé » à 8 h du matin serait faux.
      expect(statusFromDates(_inDays(-30), _inDays(0)), 'en_cours');
    });
  });

  group('attestationOverdue — le cas rageant', () {
    test('stage terminé sans attestation -> en retard', () {
      expect(_row(status: InternshipStatus.termine).attestationOverdue, isTrue);
    });

    test('stage validé sans attestation -> en retard aussi', () {
      expect(_row(status: InternshipStatus.valide).attestationOverdue, isTrue);
    });

    test('stage terminé AVEC attestation -> rien à signaler', () {
      expect(
        _row(status: InternshipStatus.termine, attestation: true)
            .attestationOverdue,
        isFalse,
      );
    });

    test('stage en cours ou prévu sans attestation -> normal, pas un retard', () {
      // Réclamer une attestation pour un stage qui n'a pas eu lieu serait du
      // bruit — et le bruit fait ignorer les vraies alertes.
      for (final s in [InternshipStatus.prevu, InternshipStatus.enCours]) {
        expect(_row(status: s).attestationOverdue, isFalse, reason: s.name);
      }
    });

    test('stage interrompu -> pas d\'attestation attendue', () {
      expect(
          _row(status: InternshipStatus.interrompu).attestationOverdue, isFalse);
    });
  });

  group('InternshipStatus — lecture de la base', () {
    test('chaque valeur de l\'enum Postgres est reconnue', () {
      expect(InternshipStatus.parse('prevu'), InternshipStatus.prevu);
      expect(InternshipStatus.parse('en_cours'), InternshipStatus.enCours);
      expect(InternshipStatus.parse('termine'), InternshipStatus.termine);
      expect(InternshipStatus.parse('interrompu'), InternshipStatus.interrompu);
      expect(InternshipStatus.parse('valide'), InternshipStatus.valide);
    });

    test('une valeur inconnue ou nulle retombe sur prévu, sans planter', () {
      expect(InternshipStatus.parse(null), InternshipStatus.prevu);
      expect(InternshipStatus.parse('n_importe_quoi'), InternshipStatus.prevu);
    });
  });

  group('StagesOverview — les compteurs', () {
    test('compte les en cours, les attestations et les retards', () {
      final o = StagesOverview(
        internships: [
          _row(status: InternshipStatus.enCours),
          _row(status: InternshipStatus.termine),
          _row(status: InternshipStatus.termine, attestation: true),
          _row(status: InternshipStatus.valide, attestation: true),
        ],
        blocked: const [],
      );
      expect(o.ongoing, 1);
      expect(o.attestations, 2);
      expect(o.overdue, 1);
    });
  });

  group('Le lien avec les examens', () {
    test('seuls les bacs exigent une attestation de stage', () {
      // Note officielle METP : l'attestation est au dossier des baccalauréats.
      // Le BET, le BEP et le CAP n'en demandent pas (source non confirmée pour
      // BEP/BTF/CAP -> volontairement hors de la règle).
      expect(kExamsRequiringInternship, {'BAC_T', 'BAC_P'});
      for (final code in ['BET', 'BEP', 'CAP', 'BTF', 'BEPC', 'CEPE']) {
        expect(kExamsRequiringInternship.contains(code), isFalse, reason: code);
      }
    });
  });
}
