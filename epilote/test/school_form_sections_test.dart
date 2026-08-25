import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:epilote/features/admin_groupe/providers/education_provider.dart';
import 'package:epilote/features/admin_groupe/screens/admin_schools_screen.dart';
import 'package:epilote/features/admin_groupe/widgets/school_location_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Garde-fou du DÉCOUPAGE du formulaire école.
//
//  Le formulaire (3420 lignes dans un seul fichier) a été éclaté en widgets :
//  identité, cascade localité, position sur la carte, contacts, offre éducative.
//  Le risque d'un tel découpage n'est pas de casser la compilation — c'est de
//  PERDRE UNE SECTION en route, silencieusement. Ces tests montent le vrai
//  dialogue et vérifient que chacune est toujours là.
// ════════════════════════════════════════════════════════════════════════════

const _catalogue = EducationCatalog(
  cycles: [
    EducationCycle(
      id: 'c1',
      code: 'primaire',
      name: 'Primaire',
      orderIndex: 1,
      hasPrograms: false,
      isActive: true,
    ),
  ],
  programs: [],
  levels: [
    EducationLevel(
      id: 'l1',
      cycleId: 'c1',
      code: 'cp1',
      name: 'CP1',
      orderIndex: 1,
      isActive: true,
    ),
  ],
);

Future<void> _pumpForm(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        educationCatalogProvider.overrideWith((ref) async => _catalogue),
      ],
      child: const MaterialApp(
        home: Scaffold(body: SchoolFormDialog()),
      ),
    ),
  );
  await tester.pump(); // laisse le catalogue se résoudre
}

/// Aucun réseau en test : la carte du formulaire réclame ses tuiles et ferait
/// échouer le test sur des erreurs HTTP sans rapport. On sert un PNG vide.
class _NoNetwork extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? ctx) =>
      _FakeClient(super.createHttpClient(ctx));
}

class _FakeClient implements HttpClient {
  _FakeClient(this._inner);
  final HttpClient _inner;
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _FakeRequest(url);
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _FakeRequest(url);
  @override
  set autoUncompress(bool _) {}
  @override
  void close({bool force = false}) {}
  @override
  noSuchMethod(Invocation i) => _inner.noSuchMethod(i);
}

class _FakeRequest implements HttpClientRequest {
  _FakeRequest(this.uri);
  @override
  final Uri uri;
  @override
  final HttpHeaders headers = _FakeHeaders();
  @override
  Future<HttpClientResponse> close() async => _FakeResponse();
  // Les setters de confort (followRedirects, persistentConnection…) sont sans
  // objet ici : on les avale au lieu de lever.
  @override
  noSuchMethod(Invocation i) => null;
}

class _FakeHeaders implements HttpHeaders {
  @override
  noSuchMethod(Invocation i) => null;
}

/// PNG transparent 1×1 — décodable, donc la carte ne lève rien.
final _kPixel = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

class _FakeResponse extends Stream<List<int>> implements HttpClientResponse {
  @override
  int get statusCode => HttpStatus.ok;
  @override
  int get contentLength => _kPixel.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(void Function(List<int>)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      Stream<List<int>>.value(_kPixel).listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  setUpAll(() => HttpOverrides.global = _NoNetwork());
  tearDownAll(() => HttpOverrides.global = null);

  testWidgets('le formulaire conserve TOUTES ses sections après découpage',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pumpForm(tester);

    for (final section in [
      "IDENTITÉ DE L'ÉCOLE",
      'LOCALISATION',
      'POSITION SUR LA CARTE',
      'CONTACTS',
      'IDENTITÉ OFFICIELLE',
      "CYCLES D'ENSEIGNEMENT",
    ]) {
      expect(find.text(section), findsOneWidget,
          reason: 'section « $section » perdue au découpage');
    }
  });

  testWidgets('les widgets extraits sont bien montés', (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pumpForm(tester);

    expect(find.byType(SchoolLocalityField), findsOneWidget);
    expect(find.byType(SchoolContactSection), findsOneWidget);
    expect(find.byType(SchoolEducationSection), findsOneWidget);
    expect(find.byType(SchoolLocationField), findsOneWidget);
  });

  group('SchoolEducationController — pont section ↔ formulaire', () {
    test('publie la sélection ; le formulaire lit toujours la dernière', () {
      final c = SchoolEducationController();
      expect(c.cycleIds, isEmpty);

      c.write(cycles: {'c1'}, programs: {'p1'}, levels: {'l1', 'l2'});
      expect(c.cycleIds, {'c1'});
      expect(c.programIds, {'p1'});
      expect(c.levelIds, {'l1', 'l2'});

      // Une nouvelle publication REMPLACE : désélectionner doit désélectionner.
      c.write(cycles: {'c2'}, programs: {}, levels: {});
      expect(c.cycleIds, {'c2'});
      expect(c.programIds, isEmpty,
          reason: 'une filière retirée ne doit pas survivre à la publication');
      expect(c.levelIds, isEmpty);
    });
  });
}
