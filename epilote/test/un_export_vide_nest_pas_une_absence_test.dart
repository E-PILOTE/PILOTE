import 'dart:io';

import 'package:epilote/features/audit/providers/audit_data.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  UN EXPORT VIDE N'EST PAS UNE ABSENCE D'ACTIVITÉ
//
//  ── CE QUI A ÉTÉ TROUVÉ (2026-09-05) ──────────────────────────────────────
//  `fetchAllAuditForExport` se terminait par `catch (_) { return []; }`. Une
//  lecture qui échouait — réseau, RLS, délai dépassé — rendait une liste vide,
//  et la modale d'export écrivait consciencieusement un CSV ne contenant que
//  sa ligne d'en-têtes.
//
//  C'est le seul endroit de l'application où une lecture ratée FABRIQUE UN
//  DOCUMENT. Et ce document affirme quelque chose : « sur la période demandée,
//  le registre ne contient rien ». Il part sous cette forme à un inspecteur, à
//  un ministère, à un commissaire aux comptes. Personne, en le recevant, ne
//  peut deviner qu'il s'agit d'un échec de lecture.
//
//  ── LE DÉTAIL QUI DONNE LA MESURE DU DÉFAUT ───────────────────────────────
//  La modale d'export possédait DÉJÀ un `try/catch` et un `_errorMsg` prévus
//  pour ce cas exact. Tant que la fonction avalait l'erreur, ce chemin de
//  rattrapage était écrit et INATTEIGNABLE. Le garde-fou existait ; ce qu'il
//  gardait avait promis de ne jamais tomber.
//
//  ── L'AUTRE MOITIÉ : « SYSTÈME » N'EST PAS UN NOM DE REPLI ────────────────
//  Six autres lectures muettes portaient sur la résolution des noms. En échec,
//  la colonne « Auteur » se remplissait de « Système » et le top des acteurs
//  de « Utilisateur ». Dans un registre dont la raison d'être est de dire QUI
//  a fait quoi, « Système » n'est pas une étiquette manquante : c'est une
//  attribution fausse, qui déplace la responsabilité d'une personne vers la
//  plateforme — sur une suppression, c'est exactement ce qu'on ne veut pas.
// ════════════════════════════════════════════════════════════════════════════

const _source = 'lib/features/audit/providers/audit_data.dart';

/// La courbe des 30 jours a quitté `audit_data.dart` le 2026-09-09 — le
/// fichier passait 500 lignes. Elle emporte AVEC ELLE l'un des deux échecs de
/// résolution de noms que ce test garde : sans cette seconde source, la sonde
/// resterait verte tout en ne voyant plus que la moitié du sujet.
const _sourceTimeline = 'lib/features/audit/providers/audit_timeline.dart';
const _modale = 'lib/features/audit/screens/widgets/audit_export_dialog.dart';

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
  group('L’export échoue bruyamment ou pas du tout', () {
    test('il ne rend plus jamais une liste vide sur échec', () {
      final src = _sansCommentaires(_lire(_source));
      expect(src.contains('return [];'), isFalse,
          reason: 'Une liste vide rendue sur échec produit un CSV qui affirme '
              'qu’il ne s’est rien passé.');
    });

    test('il lève une erreur que la modale sait afficher', () {
      final src = _sansCommentaires(_lire(_source));
      final i = src.indexOf('fetchAllAuditForExport');
      expect(i, greaterThan(-1));
      final queue = src.substring(i);
      expect(queue.contains('throw ErreurMetier('), isTrue);
    });

    test('le message dit que RIEN n’a été produit', () {
      // « Erreur de chargement » laisse croire à un fichier partiel. Ce qui
      // doit être compris, c'est qu'aucun fichier n'existe.
      final src = _lire(_source);
      expect(src.contains('Aucun fichier'), isTrue);
    });

    test('le chemin de rattrapage de la modale existe toujours', () {
      // Il était inatteignable ; s'il disparaît, l'erreur remonterait en
      // exception non gérée au lieu de s'afficher dans la modale.
      final src = _sansCommentaires(_lire(_modale));
      expect(src.contains('_errorMsg = messageErreur(e'), isTrue);
    });
  });

  group('« Système » est réservé à ce qui n’a pas d’auteur', () {
    test('les deux remplacements sont nommés et distincts', () {
      expect(kNomNonResolu, isNot(kCompteIntrouvable));
      for (final n in [kNomNonResolu, kCompteIntrouvable]) {
        expect(n.toLowerCase().contains('système'), isFalse,
            reason: '« $n » se confondrait avec une action de la plateforme.');
        expect(n, isNot('Utilisateur'),
            reason: '« Utilisateur » se lit comme une personne anonyme, pas '
                'comme un nom qu’on n’a pas su lire.');
      }
    });

    test('un nom illisible ne devient plus « Système »', () {
      final src = _sansCommentaires(_lire(_source));
      expect(src.contains("(userNames[uid] ?? 'Système')"), isFalse,
          reason: 'Ce repli attribuait à la plateforme l’acte d’une personne.');
      expect(src.contains('nomsIllisibles ? kNomNonResolu'), isTrue);
    });

    test('le top des acteurs ne fabrique plus cinq anonymes', () {
      final src = _sansCommentaires(_lire(_source));
      expect(src.contains("userNames[id] ?? 'Utilisateur'"), isFalse);
    });

    test('une ligne réellement sans auteur reste « Système »', () {
      // Le correctif ne doit pas retirer le seul cas où « Système » est vrai :
      // une écriture déclenchée en base, sans utilisateur.
      final src = _sansCommentaires(_lire(_source));
      expect(src.contains("uid == null\n          ? 'Système'"), isTrue,
          reason: 'Tout renommer effacerait une information exacte.');
    });

    test('les deux échecs de résolution laissent une trace', () {
      // Les deux vivent désormais dans deux fichiers : la page du journal
      // (`audit_data`) et la courbe des 30 jours (`audit_timeline`).
      final src = _sansCommentaires(_lire(_source));
      final srcTimeline = _sansCommentaires(_lire(_sourceTimeline));
      expect(
        'nomsIllisibles = true;'.allMatches(src).length +
            'nomsIllisibles = true;'.allMatches(srcTimeline).length,
        2,
        reason: 'Les deux résolutions de noms — celle de la page et celle du '
            'top des acteurs — doivent chacune signaler leur échec.',
      );
      expect(src.contains('debugPrint('), isTrue,
          reason: 'Sans journal, un « Nom non résolu » se diagnostique en '
              'interrogeant l’utilisateur — ce qui n’arrive jamais.');
      expect(srcTimeline.contains('debugPrint('), isTrue);
    });
  });
}
