import 'package:epilote/features/admin_groupe/providers/exam_archives_provider.dart';
import 'package:epilote/features/admin_groupe/widgets/exam_figure_fields.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  SAISIE GROUPÉE — une publication de la DEC porte des dizaines de chiffres.
//
//  Le national, puis chacun des douze départements, puis les établissements.
//  Le panneau imposait un aller-retour complet par chiffre : rouvrir,
//  rechoisir la session, retrouver la pièce dans une liste.
//
//  Tout se joue sur ce qui SURVIT d'un relevé au suivant — la pièce, la
//  session, la date de publication — et ce qui doit DISPARAÎTRE : le périmètre
//  et les nombres. Se tromper de côté, c'est soit ressaisir la pièce trente
//  fois, soit recopier par inadvertance les effectifs du Pool sur la Bouenza.
//  Le second cas est le pire : il ne se voit pas.
// ════════════════════════════════════════════════════════════════════════════
void main() {
  final base = FigureDraft(
    sessionId: 'sess-1',
    publicationId: 'pub-1',
    publishedAt: DateTime(2026, 7, 24),
    scope: PubScope.departement,
    department: 'Pool',
    schoolId: null,
    filiereLabel: 'F5',
    registered: 120,
    present: 112,
    admitted: 47,
    rate: null,
  );

  test('la pièce, la session et la date survivent au relevé suivant', () {
    final next = resetForNext(base);
    expect(next.publicationId, 'pub-1');
    expect(next.sessionId, 'sess-1');
    expect(next.publishedAt, DateTime(2026, 7, 24));
  });

  test('le périmètre et les nombres se vident', () {
    final next = resetForNext(base);
    expect(next.scope, PubScope.national);
    expect(next.department, isNull);
    expect(next.schoolId, isNull);
    expect(next.filiereLabel, isEmpty);
    expect(next.registered, isNull);
    expect(next.present, isNull);
    expect(next.admitted, isNull);
    expect(next.rate, isNull);
  });

  test('un relevé sans aucun chiffre n\'en est pas un', () {
    expect(base.isComplete, isTrue);
    expect(resetForNext(base).isComplete, isFalse);
  });

  test('le taux se déduit des effectifs, sinon c\'est le taux publié', () {
    expect(base.retainedRate, closeTo(47 / 112 * 100, 0.001));
    final published = base.copyWith(
      present: null,
      admitted: null,
      rate: 63.5,
    );
    expect(published.retainedRate, 63.5);
  });

  test('copyWith distingue « non fourni » de « remis à null »', () {
    // Sans cette distinction, vider un département deviendrait impossible :
    // passer `null` signifierait « ne touche pas », et le Pool traînerait sur
    // le relevé suivant. C'est exactement l'erreur que la saisie groupée doit
    // rendre impossible.
    expect(base.copyWith(admitted: 50).department, 'Pool');
    expect(base.copyWith(department: null).department, isNull);
    expect(base.copyWith(department: null).admitted, 47);
  });

  test('un périmètre départemental sans département n\'est pas enregistrable',
      () {
    expect(base.scopeProblem, isNull);
    expect(base.copyWith(department: null).scopeProblem, isNotNull);
    expect(
      base.copyWith(scope: PubScope.etablissement, department: null).scopeProblem,
      isNotNull,
    );
    expect(
      base
          .copyWith(scope: PubScope.etablissement, schoolId: 'school-1')
          .scopeProblem,
      isNull,
    );
  });

  test('plus d\'admis que de présents est refusé', () {
    expect(base.copyWith(admitted: 200).countsProblem, isNotNull);
    expect(base.countsProblem, isNull);
  });

  test('présents et admis vont ensemble, ou pas du tout', () {
    expect(base.copyWith(admitted: null).countsProblem, isNotNull);
    expect(base.copyWith(present: null).countsProblem, isNotNull);
  });

  test('l\'étiquette d\'un relevé enregistré dit son périmètre et son taux', () {
    expect(base.chipLabel, 'Pool · 41,96 %');
    expect(
      base.copyWith(scope: PubScope.national, department: null).chipLabel,
      startsWith('National · '),
    );
  });
}
