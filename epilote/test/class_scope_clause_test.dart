import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:epilote/features/navigation/providers/permissions_provider.dart';

/// ══════════════════════════════════════════════════════════════════════════
///  VERROU 4 — PÉRIMÈTRE DE DONNÉES (`own_classes`).
///
///  `classScopeClause` est le seul point où un module traduit « cet agent ne
///  voit que ses classes » en SQL. Le défaut qu'il répare ne se voyait pas :
///  le registre des élèves n'appelait rien du tout, et servait l'école entière
///  — y compris à l'Annuaire, donc les téléphones de toutes les familles — à
///  un enseignant restreint à ses classes. Une page qui oublie le périmètre ne
///  plante pas, ne journalise rien : elle montre simplement trop.
///
///  D'où ces tests : ils fixent le contrat, y compris le cas de chargement,
///  qui est celui où l'on se trompe.
/// ══════════════════════════════════════════════════════════════════════════

ModulePermission _perm(String slug, String scope) => ModulePermission(
      moduleSlug: slug,
      canRead: true,
      canCreate: false,
      canUpdate: false,
      canDelete: false,
      canExport: false,
      canImport: false,
      canValidate: false,
      canApprove: false,
      canManage: false,
      canWrite: false,
      dataScope: scope,
    );

/// Évalue `classScopeClause` dans un vrai conteneur Riverpod.
final _probe = Provider.autoDispose
    .family<({String clause, List<String> params})?, String>(
  (ref, slug) => classScopeClause(ref, slug, column: 'ce.class_id'),
);

Future<({String clause, List<String> params})?> _eval({
  required String slug,
  required Map<String, ModulePermission> perms,
  required AsyncValue<List<String>?> classIds,
}) async {
  final c = ProviderContainer(overrides: [
    myPermissionsProvider.overrideWith((ref) => Stream.value(perms)),
    scopedClassIdsProvider.overrideWith((ref, s) => switch (classIds) {
          AsyncData(:final value) => Stream.value(value),
          _ => const Stream<List<String>?>.empty(),
        }),
  ]);
  addTearDown(c.dispose);
  // Les StreamProvider n'émettent qu'au tour de boucle suivant : sans cette
  // attente on mesurerait l'état de CHARGEMENT et non le contrat.
  await c.read(myPermissionsProvider.future);
  if (classIds is AsyncData) await c.read(scopedClassIdsProvider(slug).future);
  return c.read(_probe(slug));
}

void main() {
  group('classScopeClause — périmètre par module', () {
    test('own_school : aucune restriction', () async {
      final r = await _eval(
        slug: 'eleves',
        perms: {'eleves': _perm('eleves', 'own_school')},
        classIds: const AsyncData(null),
      );
      expect(r, isNull, reason: 'own_school doit laisser passer toute l\'école');
    });

    test('own_classes : restreint aux classes du membre', () async {
      final r = await _eval(
        slug: 'eleves',
        perms: {'eleves': _perm('eleves', 'own_classes')},
        classIds: const AsyncData(['c1', 'c2']),
      );
      expect(r!.clause, 'AND ce.class_id IN (?,?)');
      expect(r.params, ['c1', 'c2']);
    });

    test('own_classes sans aucune classe : ferme au lieu d\'ouvrir', () async {
      // Un enseignant dont le lien staff_members n'est pas encore peuplé n'a
      // aucune classe. « Aucune classe » ne doit jamais vouloir dire « toutes ».
      final r = await _eval(
        slug: 'eleves',
        perms: {'eleves': _perm('eleves', 'own_classes')},
        classIds: const AsyncData(<String>[]),
      );
      expect(r!.clause, 'AND 0 = 1');
      expect(r.params, isEmpty);
    });

    test('own_classes pendant le chargement : ferme (rien ne fuit)', () async {
      // Le cas qui compte : entre l'ouverture de la page et l'arrivée de la
      // liste des classes, la requête part quand même. Si elle partait sans
      // restriction, l'école entière s'afficherait le temps d'une image — ce
      // qui suffit à l'avoir montrée.
      final r = await _eval(
        slug: 'eleves',
        perms: {'eleves': _perm('eleves', 'own_classes')},
        classIds: const AsyncLoading(),
      );
      expect(r!.clause, 'AND 0 = 1');
    });

    test('module absent du profil : aucune restriction ici', () async {
      // Le droit d'ENTRER dans la page est un autre verrou (canProvider /
      // PermissionGate). Ce fragment-ci ne parle que du périmètre.
      final r = await _eval(
        slug: 'annuaire',
        perms: const {},
        classIds: const AsyncData(null),
      );
      expect(r, isNull);
    });

    test('le périmètre se lit sur LE module demandé, pas sur un autre', () async {
      // Élèves ouvert à toute l'école, Annuaire restreint : chaque page doit
      // obtenir sa propre réponse. Partager un provider sans slug revenait à
      // appliquer partout le réglage d'une seule page.
      final perms = {
        'eleves': _perm('eleves', 'own_school'),
        'annuaire': _perm('annuaire', 'own_classes'),
      };
      final eleves = await _eval(
        slug: 'eleves',
        perms: perms,
        classIds: const AsyncData(['c1']),
      );
      final annuaire = await _eval(
        slug: 'annuaire',
        perms: perms,
        classIds: const AsyncData(['c1']),
      );
      expect(eleves, isNull);
      expect(annuaire!.clause, 'AND ce.class_id IN (?)');
    });

    test('la colonne appartient à la requête appelante', () async {
      final c = ProviderContainer(overrides: [
        myPermissionsProvider.overrideWith(
            (ref) => Stream.value({'notes': _perm('notes', 'own_classes')})),
        scopedClassIdsProvider
            .overrideWith((ref, s) => Stream.value(const ['c9'])),
      ]);
      addTearDown(c.dispose);
      await c.read(myPermissionsProvider.future);
      await c.read(scopedClassIdsProvider('notes').future);
      final probe = Provider.autoDispose(
          (ref) => classScopeClause(ref, 'notes', column: 'c.id'));
      expect(c.read(probe)!.clause, 'AND c.id IN (?)');
    });
  });
}
