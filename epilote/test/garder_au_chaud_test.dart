import 'dart:io';

import 'package:epilote/core/utils/garder_au_chaud.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  GARDER AU CHAUD — ET LE DIRE QUAND ÇA CHANGE
//
//  ── CE QUI A ÉTÉ TROUVÉ (2026-09-06) ──────────────────────────────────────
//  35 providers des deux espaces en ligne étaient `autoDispose` sans
//  `keepAlive` : quitter un écran DÉTRUISAIT la donnée, y revenir la
//  retéléchargeait en entier. Sur une liaison congolaise, chaque va-et-vient
//  dans la navigation se payait en secondes — pour des chiffres inchangés.
//
//  ── POURQUOI PAS UN `keepAlive()` NU ──────────────────────────────────────
//  Un ministère laisse l'application ouverte la journée. Un cache sans fin lui
//  montrerait le soir les chiffres du matin, sans le dire. Le silence d'une
//  donnée périmée est le même défaut que le silence d'une lecture ratée.
//
//  ── 🩸 CE QUE CE FICHIER GARDE AVANT TOUT ─────────────────────────────────
//  Le cache seul FABRIQUE un défaut pire que la lenteur : on crée une licence,
//  on nomme un administrateur, on coche un niveau — et pendant cinq minutes
//  l'écran continue d'afficher l'état d'avant. Un succès qui se lit comme un
//  échec.
//
//  Deux lectures n'étaient JAMAIS invalidées après écriture. Elles étaient
//  justes PARCE QU'ELLES étaient froides. Les tests de la seconde moitié de ce
//  fichier existent pour que ce couple — cache + invalidation — ne soit jamais
//  redéfait à moitié.
// ════════════════════════════════════════════════════════════════════════════

String _lire(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) fail('Fichier introuvable : $chemin — sonde aveugle.');
  return f.readAsStringSync().replaceAll('\r\n', '\n');
}

String _sansCommentaires(String source) => source
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  group('L’outil garde, puis relâche', () {
    test('la donnée survit à la disparition de son dernier lecteur', () async {
      var calculs = 0;
      final p = FutureProvider.autoDispose<int>((ref) async {
        garderAuChaud(ref, pendant: const Duration(seconds: 30));
        return ++calculs;
      });
      final c = ProviderContainer();
      addTearDown(c.dispose);

      final sub = c.listen(p, (_, _) {});
      await c.read(p.future);
      expect(calculs, 1);

      sub.close(); // on quitte l'écran
      await Future<void>.delayed(const Duration(milliseconds: 30));
      c.listen(p, (_, _) {}); // on y revient
      await c.read(p.future);

      expect(calculs, 1,
          reason: 'Revenir sur l’écran a tout retéléchargé : le cache ne '
              'tient pas.');
    });

    test('mais elle est relâchée à l’échéance', () async {
      var calculs = 0;
      final p = FutureProvider.autoDispose<int>((ref) async {
        garderAuChaud(ref, pendant: const Duration(milliseconds: 40));
        return ++calculs;
      });
      final c = ProviderContainer();
      addTearDown(c.dispose);

      final sub = c.listen(p, (_, _) {});
      await c.read(p.future);
      sub.close();

      // ⚠️ MARGE VOLONTAIREMENT ÉNORME — corrigé le 2026-09-10.
      //
      //  L'attente était de 120 ms pour une échéance de 40 : trois fois. Ce
      //  test échouait donc par intermittence dans la suite complète, et
      //  passait toujours en isolation — le pire profil qui soit, celui qui
      //  fait douter de la suite entière puis relancer sans chercher.
      //
      //  La cause n'est pas le code gardé : c'est que `Timer` promet de tirer
      //  « au plus tôt à l'échéance », jamais « à l'échéance ». Sur une
      //  machine qui exécute 2 500 tests, il peut attendre son tour bien
      //  au-delà de 120 ms.
      //
      //  Vingt-cinq fois l'échéance coûte une seconde et ne ment plus. La
      //  valeur mesurée n'a aucune importance ici : ce qu'on vérifie, c'est
      //  qu'une échéance FINIT par relâcher, pas qu'elle relâche vite.
      await Future<void>.delayed(const Duration(seconds: 1));

      c.listen(p, (_, _) {});
      await c.read(p.future);
      expect(calculs, 2,
          reason: 'Passé l’échéance, la visite suivante doit relire — sinon '
              'on montre le matin ce qu’on a lu la veille.');
    });

    test('les trois durées sont ordonnées et nommées par ce qu’elles portent',
        () {
      // Un statut contractuel se périme plus vite qu'un référentiel : c'est
      // l'ordre qui porte le raisonnement, pas les valeurs exactes.
      expect(kChaudContrat, lessThan(kChaudCourant));
      expect(kChaudCourant, lessThan(kChaudReferentiel));
      expect(kChaudContrat.inMinutes, greaterThanOrEqualTo(1),
          reason: 'Sous la minute, le cache ne sert plus à rien.');
    });

    test('un statut contractuel n’est pas gardé aussi longtemps qu’une table '
        'de référence', () {
      for (final chemin in [
        'lib/features/admin_groupe/providers/admin_licence_provider.dart',
        'lib/features/admin_groupe/providers/subscription_access_provider.dart',
      ]) {
        final src = _sansCommentaires(_lire(chemin));
        expect(src.contains('pendant: kChaudContrat'), isTrue,
            reason: '$chemin porte une licence ou un droit d’accès : gardé '
                'cinq minutes, un réseau suspendu se croirait encore ouvert.');
      }
    });
  });

  group('🩸 Le cache ne va JAMAIS sans son invalidation', () {
    test('nommer un administrateur rafraîchit la fiche du groupe', () {
      // Sans cette ligne : on nomme un administrateur, et la fiche du groupe
      // affiche « aucun » pendant cinq minutes.
      final src = _sansCommentaires(
          _lire('lib/features/super_admin/screens/admins/admin_form_modal.dart'));
      expect(src.contains('invalidate(comptesAdminParGroupeProvider)'), isTrue,
          reason: 'Le succès se lirait comme un échec.');
    });

    test('cocher un niveau rafraîchit l’écran de rattachement', () {
      final src = _sansCommentaires(
          _lire('lib/features/admin_groupe/providers/education_provider.dart'));
      expect(src.contains('invalidate(adminRattachementProvider)'), isTrue,
          reason: '« Rattachement » lit `school_levels` : gardé au chaud sans '
              'invalidation, il ignorerait la coche cinq minutes.');
    });

    test('les providers gardés au chaud passent par l’outil, pas par un '
        '`keepAlive` nu', () {
      // Un `keepAlive()` sans échéance garde la donnée toute la session.
      // Il reste légitime là où un canal temps réel invalide déjà — d'où le
      // décompte plutôt qu'une interdiction.
      final dossiers = [
        Directory('lib/features/admin_groupe/providers'),
        Directory('lib/features/super_admin/providers'),
      ];
      var chauds = 0;
      for (final d in dossiers) {
        for (final f in d.listSync().whereType<File>()) {
          if (!f.path.endsWith('.dart')) continue;
          chauds += 'garderAuChaud(ref'.allMatches(_lire(f.path)).length;
        }
      }
      expect(chauds, greaterThanOrEqualTo(30),
          reason: 'Les lectures gardées au chaud sont retombées à $chauds : '
              'la navigation a retrouvé ses secondes.');
    });
  });
}
