import 'dart:io';

import 'package:epilote/features/examens/providers/exam_verbes.dart';
import 'package:epilote/features/navigation/providers/permissions_provider.dart'
    show canProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE VERBE DU BOUTON EST CELUI DE L'ACTE
//
//  ── CE QUI ÉTAIT ROMPU (relevé le 2026-09-10) ─────────────────────────────
//  Le RETRAIT d'une candidature fait un `DELETE exam_candidates`. La politique
//  serveur `exam_candidates_delete` exige `examens/delete`. Le bouton, lui,
//  était gardé par `examens/update`.
//
//  Latent aujourd'hui : les 14 profils qui portent `update` portent aussi
//  `delete`. Le jour où une école crée un profil « saisie sans suppression »,
//  le retrait s'affiche comme réussi, part en local, et se fait refuser en
//  `42501` à la remontée — un code FATAL, qui fait JETER le lot PowerSync
//  entier. Le candidat revient à la synchro suivante ; ce qui l'accompagnait
//  dans le lot est perdu. Sans un message.
//
//  ── LA RÈGLE QUE CE FICHIER TIENT ─────────────────────────────────────────
//  Un bouton ne demande JAMAIS moins que la politique serveur. Plus, c'est un
//  choix de produit ; moins, c'est une perte de données silencieuse.
//
//  C'est le défaut que `test/stage_correction_test.dart` interdit côté stages,
//  et qui n'avait pas de gardien côté examens.
// ════════════════════════════════════════════════════════════════════════════

String _lire(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) fail('$chemin introuvable — lancer depuis `epilote/`.');
  return f.readAsStringSync().replaceAll('\r\n', '\n');
}

const _kVerbes = 'lib/features/examens/providers/exam_verbes.dart';
const _kActions = 'lib/features/examens/widgets/exam_candidate_views.dart';
const _kBarre = 'lib/features/examens/widgets/exam_candidate_list.dart';
const _kEcran = 'lib/features/examens/screens/exam_session_screen.dart';
const _kDialogue = 'lib/features/examens/widgets/class_candidates_dialog.dart';

/// Un conteneur où `can(slug, action)` rend vrai pour les couples fournis.
ProviderContainer _profil(Set<String> accordes) => ProviderContainer(
      overrides: [
        canProvider.overrideWith(
            (ref, key) => accordes.contains('${key.slug}/${key.action}')),
      ],
    );

void main() {
  group('Chaque verbe porte l’acte que le serveur exige', () {
    test('le retrait demande `delete` — pas `update`', () {
      final c = _profil({'examens/update'});
      addTearDown(c.dispose);
      expect(c.read(peutRetirerCandidatProvider), isFalse,
          reason: 'Un profil « saisie sans suppression » verrait le bouton, '
              'et le serveur jetterait le lot entier.');

      final d = _profil({'examens/delete'});
      addTearDown(d.dispose);
      expect(d.read(peutRetirerCandidatProvider), isTrue);
    });

    test('le dépôt demande `validate` — le verbe qui sait aussi ROUVRIR', () {
      final c = _profil({'examens/update'});
      addTearDown(c.dispose);
      expect(c.read(peutDeposerDossierProvider), isFalse,
          reason: 'Déposer bloque le retrait ; rouvrir demande `validate`. '
              'Qui pose doit pouvoir défaire.');

      final d = _profil({'examens/validate'});
      addTearDown(d.dispose);
      expect(d.read(peutDeposerDossierProvider), isTrue);
    });

    test('l’inscription et la modification gardent leurs verbes', () {
      final c = _profil({'examens/create', 'examens/update'});
      addTearDown(c.dispose);
      expect(c.read(peutInscrireCandidatProvider), isTrue);
      expect(c.read(peutModifierCandidatProvider), isTrue);

      final vide = _profil({});
      addTearDown(vide.dispose);
      expect(vide.read(peutInscrireCandidatProvider), isFalse);
      expect(vide.read(peutModifierCandidatProvider), isFalse);
    });
  });

  group('🩸 La caisse d’examen recopie la disjonction de `payments_insert`', () {
    test('le comptable encaisse — c’est tout l’objet du correctif', () {
      // Profil « Comptabilité » réel : LIT `examens`, aucun droit d'écriture
      // dessus, et `paiements-eleves/create`. Le bouton lui était caché.
      final c = _profil({'paiements-eleves/create'});
      addTearDown(c.dispose);
      expect(c.read(peutEncaisserFraisExamenProvider), isTrue,
          reason: '`payments_insert` accepte son droit depuis toujours : lui '
              'cacher le bouton, c’est lui refuser sa propre caisse.');
    });

    test('le secrétariat NE PERD PAS la caisse', () {
      // Profil « Secrétariat » réel : `examens/create`, aucune ligne
      // `paiements-eleves`. Choisir un module unique la lui aurait retirée —
      // trois semaines avant un déploiement national.
      final c = _profil({'examens/create'});
      addTearDown(c.dispose);
      expect(c.read(peutEncaisserFraisExamenProvider), isTrue);
    });

    test('un profil sans aucun `create` n’encaisse pas', () {
      final c = _profil({'examens/update', 'paiements-eleves/read'});
      addTearDown(c.dispose);
      expect(c.read(peutEncaisserFraisExamenProvider), isFalse);
    });

    test('la disjonction est écrite comme telle, pas résumée', () {
      final src = _lire(_kVerbes);
      expect(src.contains('kSlugPaiementsEleves'), isTrue);
      expect(src.contains('||'), isTrue,
          reason: 'Remplacer le OU par un module unique fabrique une règle '
              'DIFFÉRENTE de celle du serveur, qui dérivera à la première '
              'évolution de la politique.');
    });
  });

  group('Les écrans passent bien par ces verbes', () {
    test('le retrait n’est plus sous `canEdit`', () {
      final src = _lire(_kActions);
      expect(src.contains('ref.watch(peutRetirerCandidatProvider)'), isTrue);
      expect(src.contains('if (!canEdit) {'), isFalse,
          reason: 'Le retour anticipé sur `canEdit` masquait aussi la caisse '
              'au comptable.');
    });

    test('la caisse est hors du bloc `canEdit`', () {
      final src = _lire(_kActions);
      final caisse = src.indexOf('ref.watch(peutEncaisserFraisExamenProvider)');
      final edition = src.indexOf('if (canEdit) {');
      expect(caisse, greaterThan(-1));
      expect(edition, greaterThan(-1));
      expect(caisse, lessThan(edition),
          reason: 'Si la caisse retombe dans le bloc d’édition, le comptable '
              'la reperd.');
    });

    test('la barre d’actions groupées porte ses deux verbes', () {
      expect(_lire(_kBarre).contains('required this.canDeposit'), isTrue);
      expect(_lire(_kBarre).contains('required this.canRemove'), isTrue);
      final ecran = _lire(_kEcran);
      expect(ecran.contains('canDeposit: ref.watch(peutDeposerDossierProvider)'),
          isTrue);
      expect(
          ecran.contains('canRemove: ref.watch(peutRetirerCandidatProvider)'),
          isTrue);
    });

    test('un bouton refusé se DÉSACTIVE en disant pourquoi', () {
      // Un bouton absent laisse chercher ; un bouton grisé qui nomme le droit
      // manquant apprend à qui s'adresser. Le droit se donne d'une case.
      final src = _lire(_kBarre);
      expect(src.contains('Réservé au droit « valider »'), isTrue);
      expect(src.contains('Réservé au droit « supprimer »'), isTrue);
    });

    test('le dialogue « candidats de la classe » suit la même caisse', () {
      final src = _lire(_kDialogue);
      expect(
          src.contains(
              'canEncaisser: ref.watch(peutEncaisserFraisExamenProvider)'),
          isTrue);
      expect(src.contains('if (canEncaisser && sessionId != null)'), isTrue,
          reason: 'Laisser ce bouton sur `canEdit` rendrait les deux écrans '
              'incohérents entre eux.');
    });
  });

  group('La table de correspondance reste écrite quelque part', () {
    test('le fichier des verbes nomme les politiques serveur', () {
      final src = _lire(_kVerbes);
      for (final attendu in [
        'exam_candidates',
        'payments_insert',
        'student_payments',
        '42501',
      ]) {
        expect(src.contains(attendu), isTrue,
            reason: 'Sans la politique nommée, la prochaine personne devra '
                'refaire l’enquête en base pour changer un bouton.');
      }
    });

    test('`approve` et `manage` restent délibérément inutilisés, et c’est dit',
        () {
      final src = _lire(_kVerbes);
      expect(src.contains('approve'), isTrue);
      expect(src.contains('manage'), isTrue,
          reason: 'Deux verbes accordés en base et lus par zéro ligne : sans '
              'la raison écrite, quelqu’un les branchera « pour faire propre » '
              'et retirera au secrétariat des gestes qu’il fait tous les jours.');
    });
  });
}
