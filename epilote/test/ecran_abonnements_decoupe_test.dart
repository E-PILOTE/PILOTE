import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'ecran_abonnements_source.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CE QU'ON VIENT DE COUPER NE DOIT PAS SE RECOLLER
//
//  ── LA DETTE (2026-09-04) ─────────────────────────────────────────────────
//  `subscriptions_screen.dart` pesait 2 652 lignes — cinq fois la limite du
//  projet. Un fichier de cette taille ne se relit pas : on y ajoute. C'est
//  ainsi qu'il a fini par contenir le style, les six KPI, les filtres, deux
//  vues, trois modales et l'aperçu PDF, avec DEUX titres de section nommés
//  `_SectionTitle` et `_SubSectionTitle` pour deux styles opposés.
//
//  ── CE QUE CE FICHIER GARDE ───────────────────────────────────────────────
//  La limite, pièce par pièce — et le fait que le vocabulaire partagé reste
//  déclaré à UN endroit. Un fichier qui se redonne ses propres couleurs ou son
//  propre format de montant, c'est la divergence qui recommence : c'est
//  exactement ce qui avait fait annoncer 120 000 F ici et 184 000 F ailleurs.
// ════════════════════════════════════════════════════════════════════════════

const _limite = 500;

List<File> _pieces() => Directory(dossierAbonnements)
    .listSync()
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList()
  ..sort((a, b) => a.path.compareTo(b.path));

int _lignes(String chemin) =>
    File(chemin).readAsStringSync().replaceAll('\r\n', '\n').split('\n').length;

void main() {
  group('L’écran des abonnements tient dans ses fichiers', () {
    test('la coquille est redevenue lisible', () {
      // 2 652 lignes avant le découpage.
      final n = _lignes(coquilleAbonnements);
      expect(n, lessThanOrEqualTo(_limite),
          reason: 'La coquille regrossit ($n lignes) : ce qu’on y ajoute '
              'appartient à une pièce, pas à l’assemblage.');
    });

    test('aucune pièce ne dépasse la limite', () {
      final trop = <String>[];
      for (final f in _pieces()) {
        final n = _lignes(f.path);
        if (n > _limite) trop.add('${f.uri.pathSegments.last} : $n lignes');
      }
      expect(trop, isEmpty,
          reason: 'Découper par responsabilité, jamais au milieu d’un widget.');
    });

    test('l’écran est bien un dossier, pas un fichier déguisé', () {
      expect(_pieces().length, greaterThanOrEqualTo(10),
          reason: 'Les pièces ont fusionné : le dossier redevient un bloc.');
    });
  });

  group('Le vocabulaire partagé n’est déclaré qu’une fois', () {
    test('⚠️ aucune pièce ne se redonne ses couleurs ni son format', () {
      // `subs_style.dart` porte la palette, les libellés de statut, le format
      // d'un montant et d'une date. Une pièce qui les redéclare fabrique une
      // seconde vérité — celle qui finit par ne plus coïncider.
      final coupables = <String>[];
      for (final f in _pieces()) {
        final nom = f.uri.pathSegments.last;
        if (nom == 'subs_style.dart') continue;
        final src = f.readAsStringSync();
        for (final motif in const [
          'const _kOrange',
          'const _moisFr',
          'String _money(',
          'String _fmtDate(',
          'Color _statusColor(',
          'IconData _statusIcon(',
        ]) {
          if (src.contains(motif)) coupables.add('$nom → $motif');
        }
      }
      expect(coupables, isEmpty,
          reason: 'Le style de l’écran s’est remis à vivre à deux endroits.');
    });

    test('le style ne dépend d’aucune autre pièce', () {
      // Il est la racine : s'il importait une vue, le dossier boucle.
      final src = File('$dossierAbonnements/subs_style.dart').readAsStringSync();
      expect(src.contains("import 'sub"), isFalse,
          reason: 'subs_style.dart importe une pièce de l’écran : le '
              'vocabulaire dépend désormais de ce qui s’en sert.');
    });
  });
}
