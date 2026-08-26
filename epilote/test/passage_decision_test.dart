import 'package:epilote/features/evaluation/providers/passage_provider.dart';
import 'package:epilote/services/powersync/powersync_schema.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powersync/powersync.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LA DÉCISION DE PASSAGE — ce qui ne doit jamais dériver.
//
//  Deux invariants, pour deux raisons différentes :
//
//  1. LA BARRE EST À 10/20. C'est la même que `mentionFor` (seule autorité
//     en base. Ce barème avait DÉJÀ dérivé de deux points côté bulletins : un
//     8/20 ressortait « Passable ». Sur une décision de passage, la même dérive
//     ferait redoubler — ou passer — des enfants à tort.
//
//  2. LE TYPE LOCAL SUIT LE TYPE SERVEUR. `promotion_average` est un `numeric`
//     en base : déclaré autrement, PowerSync abandonnerait la transaction
//     entière (22P02) et TOUTE la délibération d'une classe disparaîtrait sans
//     message. Même famille de panne que `student_payments.amount_xaf`.
// ════════════════════════════════════════════════════════════════════════════
void main() {
  group('verdict proposé', () {
    // Le barème par défaut : la barre du METP, sans zone de délibération.
    // C'est ce que rend `_baremeFor` quand aucun réglage n'a été posé, et donc
    // le comportement de TOUTES les écoles au jour du déploiement.
    const officiel = BaremePassage.officiel;

    test('la barre de passage par défaut est à 10/20, pas 8', () {
      expect(suggestedVerdict(10.0, officiel), 'passe');
      expect(suggestedVerdict(9.99, officiel), 'redouble');
      expect(suggestedVerdict(8.0, officiel), 'redouble');
      expect(suggestedVerdict(19.5, officiel), 'passe');
      expect(suggestedVerdict(0, officiel), 'redouble');
    });

    test('aucune note ne propose rien — on ne délibère pas dans le vide', () {
      expect(suggestedVerdict(null, officiel), isNull);
      expect(propositionPour(null, officiel), PropositionPassage.sansMoyenne);
    });

    test('« réorienté » n\'est jamais proposé automatiquement', () {
      for (var a = 0.0; a <= 20.0; a += 0.5) {
        expect(suggestedVerdict(a, officiel), isNot('reoriente'));
      }
    });
  });

  group('le barème se règle (migration 0107)', () {
    test('une barre abaissée fait passer un élève qui redoublait', () {
      const primaire = BaremePassage(barre: 9.5);
      expect(suggestedVerdict(9.6, BaremePassage.officiel), 'redouble');
      expect(suggestedVerdict(9.6, primaire), 'passe');
    });

    test('la barre atteinte suffit — on ne « frôle » pas', () {
      const b = BaremePassage(barre: 12);
      expect(suggestedVerdict(12.0, b), 'passe');
      expect(suggestedVerdict(11.999, b), 'redouble');
    });

    group('zone de délibération', () {
      const avecZone = BaremePassage(barre: 10, plancher: 8.5);

      test('sous le plancher, le redoublement se propose', () {
        expect(suggestedVerdict(8.49, avecZone), 'redouble');
        expect(propositionPour(8.49, avecZone), PropositionPassage.redouble);
      });

      test('dans la zone, RIEN n\'est proposé — le conseil tranche', () {
        // ⚠️ L'invariant qui compte. Un défaut prudent — « redouble » — ferait
        // redoubler tout élève que le conseil n'a pas eu le temps d'examiner,
        // et c'est exactement la population que la zone existe pour protéger.
        for (final a in [8.5, 9.0, 9.5, 9.99]) {
          expect(suggestedVerdict(a, avecZone), isNull, reason: 'moyenne $a');
          expect(propositionPour(a, avecZone),
              PropositionPassage.deliberation, reason: 'moyenne $a');
        }
      });

      test('le plancher est inclus dans la zone, la barre lui échappe', () {
        expect(propositionPour(8.5, avecZone), PropositionPassage.deliberation);
        expect(propositionPour(10.0, avecZone), PropositionPassage.passe);
      });

      test('sans plancher, la barre fait couperet — comportement d\'avant', () {
        expect(suggestedVerdict(9.99, BaremePassage.officiel), 'redouble');
      });
    });

    group('dérogation de niveau', () {
      const groupe = BaremePassage(barre: 10, plancher: 8.5);

      test('un niveau peut abaisser la barre seule', () {
        final d = groupe.avecDerogation(barre: 9);
        expect(d.barre, 9);
        expect(d.plancher, 8.5);
      });

      test('une dérogation absente laisse le barème du groupe intact', () {
        final d = groupe.avecDerogation();
        expect(d.barre, groupe.barre);
        expect(d.plancher, groupe.plancher);
      });

      test('une dérogation INCOHÉRENTE est ignorée, jamais devinée', () {
        // Plancher au-dessus de la barre : la zone serait à l'envers, un élève
        // à 11 « en délibération » pendant qu'un élève à 9 serait admis.
        // La contrainte SQL l'interdit ; si la ligne arrive quand même sur un
        // poste, on retombe sur le barème du groupe — connu et valide.
        final d = groupe.avecDerogation(barre: 8, plancher: 12);
        expect(d.barre, groupe.barre);
        expect(d.plancher, groupe.plancher);
      });

      test('une barre hors de l\'échelle sur 20 est ignorée', () {
        expect(groupe.avecDerogation(barre: 25).barre, groupe.barre);
        expect(groupe.avecDerogation(barre: 0).barre, groupe.barre);
      });
    });

    test('le libellé du barème se lit sans manuel', () {
      expect(const BaremePassage(barre: 10).libelle, '10/20');
      expect(const BaremePassage(barre: 9.5).libelle, '9,5/20');
      expect(const BaremePassage(barre: 10, plancher: 8.5).libelle,
          '10/20 · conseil entre 8,5 et 10');
    });
  });

  group('catalogue des verdicts', () {
    test('les trois codes attendus par la contrainte SQL, et eux seuls', () {
      expect(
        passageVerdicts.map((v) => v.code).toList(),
        ['passe', 'redouble', 'reoriente'],
      );
    });

    test('un code inconnu ne rend pas un verdict par défaut', () {
      expect(verdictFor(null), isNull);
      expect(verdictFor(''), isNull);
      expect(verdictFor('admis'), isNull);
    });
  });

  group('schéma PowerSync local', () {
    Column columnOf(String table, String name) => schema.tables
        .firstWhere((t) => t.name == table)
        .columns
        .firstWhere((c) => c.name == name);

    test('les colonnes de décision existent côté local', () {
      for (final c in [
        'promotion_decision',
        'promotion_average',
        'promotion_target_class_id',
        'promotion_decided_at',
        'promotion_decided_by',
      ]) {
        expect(
          () => columnOf('class_enrollments', c),
          returnsNormally,
          reason: 'Sans $c dans le schéma local, la décision reste sur '
              'l\'appareil et ne remonte jamais.',
        );
      }
    });

    test('promotion_average est « real » face au numeric du serveur', () {
      expect(columnOf('class_enrollments', 'promotion_average').type,
          ColumnType.real);
    });

    test('les identifiants et horodatages restent du texte', () {
      for (final c in [
        'promotion_decision',
        'promotion_target_class_id',
        'promotion_decided_at',
        'promotion_decided_by',
      ]) {
        expect(columnOf('class_enrollments', c).type, ColumnType.text);
      }
    });
  });

  group('moyenne annuelle = moyenne des trimestres', () {
    // L'année se délibère trois fois — conseils de classe trimestriels, qui
    // décernent des DISTINCTIONS — et s'arbitre une fois, ici. La moyenne qui
    // fonde le verdict annuel est celle des trois bulletins, à poids égal.
    //
    // ⚠️ Ce n'est PAS la moyenne de toutes les notes de l'année mises ensemble :
    // le trimestre le plus chargé en évaluations pèserait alors plus que les
    // autres. Sur les données de démo l'écart est nul (chaque trimestre y porte
    // exactement le même nombre d'évaluations) — aucun test manuel ne l'aurait
    // révélé, d'où ce test.
    test('les trois trimestres pèsent le même poids', () {
      expect(annualAverageOf(const [12.0, 6.0, 12.0]), closeTo(10.0, 1e-9));
      expect(annualAverageOf(const [9.0, 9.0, 15.0]), closeTo(11.0, 1e-9));
    });

    test('un trimestre sans note est ignoré, jamais compté zéro', () {
      // Élève arrivé en janvier : il n'a pas « eu 0 » au 1er trimestre.
      expect(annualAverageOf(const [null, 12.0, 14.0]), closeTo(13.0, 1e-9));
      // Compté zéro, il tomberait à 8.67 et redoublerait.
      expect(annualAverageOf(const [null, 12.0, 14.0])! >= 10, isTrue);
    });

    test('aucune note du tout ne donne aucune moyenne', () {
      expect(annualAverageOf(const [null, null, null]), isNull);
      expect(annualAverageOf(const []), isNull);
    });

    test('un seul trimestre renseigné vaut sa propre moyenne', () {
      expect(annualAverageOf(const [8.5, null, null]), closeTo(8.5, 1e-9));
    });

    test('la moyenne des trimestres décide du verdict, pas celle des notes', () {
      // 1er trimestre chargé (mauvais), 3e léger (bon) : mis dans le même sac,
      // le 1er l'emporterait. Trimestre par trimestre, l'élève passe.
      final moyenne = annualAverageOf(const [8.0, 10.0, 14.0]);
      expect(moyenne, closeTo(32 / 3, 1e-9));
      expect(suggestedVerdict(moyenne, BaremePassage.officiel), 'passe');
    });
  });

  group('redoublement une seule fois par niveau', () {
    // Règle publiée pour les collèges d'enseignement technique : « Le
    // redoublement, une seule fois par niveau, est toutefois autorisé. »
    // L'écran doit donc SIGNALER un second redoublement au conseil — sans le
    // bloquer : une dérogation relève de l'établissement, pas du logiciel.
    PassageEntry entry({required bool repeating, String? decision}) =>
        PassageEntry(
          enrollmentId: 'e1',
          studentId: 's1',
          studentName: 'Élève test',
          matricule: 'MAT-99-001',
          trimesterAverages: const [9.0, 9.0, 9.0],
          annualAverage: 9.0,
          rank: 12,
          totalStudents: 15,
          decision: decision,
          decidedAverage: null,
          targetClassId: null,
          reenrolled: false,
          alreadyRepeating: repeating,
        );

    test('un redoublant à qui on propose de redoubler est signalé', () {
      expect(entry(repeating: true, decision: 'redouble').repeatingTwice, isTrue);
    });

    test('un redoublant qui passe n\'est pas signalé', () {
      expect(entry(repeating: true, decision: 'passe').repeatingTwice, isFalse);
    });

    test('un non-redoublant qui redouble n\'est pas signalé', () {
      expect(entry(repeating: false, decision: 'redouble').repeatingTwice, isFalse);
    });

    test('sans décision, aucun signalement', () {
      expect(entry(repeating: true).repeatingTwice, isFalse);
    });
  });
}
