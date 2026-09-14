import 'dart:io';

import 'package:epilote/features/admin_groupe/providers/admin_subscription_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ecran_abonnement_groupe_source.dart';

// ════════════════════════════════════════════════════════════════════════════
//  UN ÉCRAN D'ARGENT NE MENT PAS
//
//  ── CE QUI A ÉTÉ TROUVÉ (2026-09-05) ──────────────────────────────────────
//  L'écran d'abonnement du groupe faisait NEUF lectures, huit d'entre elles
//  enveloppées dans un `catch (_) {}`. C'est le même défaut que sur les trois
//  écrans de mesures corrigés le même jour, mais ses conséquences sont d'une
//  autre nature : cette page-ci porte un MONTANT, une ÉCHÉANCE et des QUOTAS.
//
//  Deux effets, du plus discret au plus grave :
//
//   1. Les trois compteurs d'usage retombaient à zéro → « 0 / 2 000 élèves ».
//      Le client se croyait au large et découvrait la limite au refus du
//      serveur. Le commentaire posé au-dessus de ces compteurs disait déjà
//      qu'un quota est « le pire endroit possible pour mentir » ; trois
//      `catch (_) {}` faisaient exactement cela, dix lignes plus bas.
//
//   2. L'échec de la lecture du groupe laissait `subscription` à `null`, et
//      `_Body` traduisait ce `null` par « Aucun abonnement — ce groupe n'a pas
//      encore de plan actif ». À un ministère sous licence, cette phrase est
//      fausse, alarmante, et envoie appeler la plateforme pour rien.
//
//  ── CE QUE CE FICHIER GARDE ───────────────────────────────────────────────
//  Que les huit lectures restent nommées, que la neuvième — l'écoute temps
//  réel — reste muette POUR UNE RAISON ÉCRITE, et surtout que « inconnu » et
//  « aucun » ne se confondent plus jamais à l'écran.
// ════════════════════════════════════════════════════════════════════════════

const _provider =
    'lib/features/admin_groupe/providers/admin_subscription_provider.dart';

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
  group('Les huit lectures ont un nom', () {
    test('chaque échec est nommé et tracé', () {
      final src = _sansCommentaires(_lire(_provider));
      expect('manquantes.note('.allMatches(src).length, 8,
          reason: 'Une lecture a été ajoutée ou retirée sans dire ce qu’elle '
              'devient quand elle échoue.');
    });

    test('le résultat porte la liste, sinon elle ne sert à rien', () {
      final src = _sansCommentaires(_lire(_provider));
      expect(src.contains('mesuresManquantes: manquantes.cles'), isTrue);
    });

    test('le seul silence restant est celui du temps réel, et il s’explique',
        () {
      final brut = _lire(_provider);
      expect(_sansCommentaires(brut).contains('catch (_) {}'), isFalse,
          reason: 'Un `catch (_) {}` d’une seule ligne est précisément la '
              'forme qu’on ne relit jamais.');
      // Le silence subsiste — mais accompagné du raisonnement qui l’autorise.
      expect(brut.contains('MUET À DESSEIN'), isTrue,
          reason: 'Se taire reste permis quand rien d’affiché ne devient '
              'faux ; encore faut-il que ce soit écrit, sinon le prochain '
              'lecteur ne peut pas distinguer l’examen de l’oubli.');
    });

    test('chaque clé a un libellé lisible', () {
      // Une clé technique affichée telle quelle (« corps_enseignant ») dit à
      // l'utilisateur que le message ne lui était pas destiné.
      for (final cle in [
        MesuresAbonnement.abonnement,
        MesuresAbonnement.ecoles,
        MesuresAbonnement.eleves,
        MesuresAbonnement.personnel,
        MesuresAbonnement.familles,
        MesuresAbonnement.formules,
        MesuresAbonnement.demandes,
        MesuresAbonnement.factures,
      ]) {
        final l = MesuresAbonnement.libelle(cle);
        expect(l, isNot(cle), reason: '« $cle » n’a pas de libellé.');
        expect(l.contains('_'), isFalse);
      }
    });
  });

  group('Le cas normal reste silencieux', () {
    test('aucune mesure manquante par défaut', () {
      expect(AdminSubscriptionData.empty.mesuresManquantes, isEmpty);
      expect(AdminSubscriptionData.empty.abonnementIllisible, isFalse);
    });

    test('`manque` répond sur la clé exacte', () {
      const d = AdminSubscriptionData(
        subscription: null,
        plans: [],
        tickets: [],
        invoices: [],
        mesuresManquantes: {MesuresAbonnement.eleves},
      );
      expect(d.manque(MesuresAbonnement.eleves), isTrue);
      expect(d.manque(MesuresAbonnement.factures), isFalse);
      expect(d.abonnementIllisible, isFalse,
          reason: 'Un quota illisible ne rend pas l’abonnement illisible : '
              'confondre les deux ferait disparaître toute la page pour une '
              'jauge manquante.');
    });

    test('« abonnement » manquant se distingue, lui', () {
      const d = AdminSubscriptionData(
        subscription: null,
        plans: [],
        tickets: [],
        invoices: [],
        mesuresManquantes: {MesuresAbonnement.abonnement},
      );
      expect(d.abonnementIllisible, isTrue);
    });
  });

  group('« Inconnu » n’est pas « aucun »', () {
    test('l’écran a deux états distincts pour un `subscription` nul', () {
      final src = _sansCommentaires(sourceAbonnementGroupe());
      final illisible = src.indexOf('if (sub == null && data.abonnementIllisible)');
      final aucun = src.indexOf("title: 'Aucun abonnement'");
      expect(illisible, greaterThan(-1),
          reason: 'Sans cette garde, un échec de lecture annonce à un client '
              'qui paie qu’il n’a pas de plan.');
      expect(aucun, greaterThan(-1),
          reason: 'Le vrai « aucun abonnement » doit rester dit : c’est un '
              'fait, et il demande d’appeler la plateforme.');
      expect(illisible, lessThan(aucun),
          reason: 'La garde doit passer AVANT, sinon elle n’est jamais '
              'atteinte.');
    });

    test('l’état illisible ne prétend rien savoir', () {
      final src = _sansCommentaires(sourceAbonnementGroupe());
      expect(src.contains('class _AbonnementIllisible'), isTrue);
      expect(src.contains('Cela ne veut PAS dire que '), isTrue,
          reason: 'La phrase doit démentir explicitement la lecture « vous '
              'n’avez pas d’abonnement » : c’est celle que l’utilisateur fera '
              'sinon.');
    });
  });

  group('Le bandeau se lit avant les montants', () {
    test('il est posé avant la carte de plan', () {
      final src = _sansCommentaires(sourceAbonnementGroupe());
      final bandeau = src.indexOf('_MesuresManquantesAbonnement(data: data)');
      final carte = src.indexOf('LicenceDeTutelleSection(sub: sub)');
      expect(bandeau, greaterThan(-1));
      expect(carte, greaterThan(-1));
      expect(bandeau, lessThan(carte),
          reason: 'Apprendre après avoir lu le montant ne sert plus à rien.');
    });

    test('les jauges de quota sont déconseillées nommément', () {
      // C'est la seule des huit mesures dont l'erreur pousse à AGIR — inscrire
      // des élèves, recruter — et non seulement à mal s'informer.
      final src = _sansCommentaires(sourceAbonnementGroupe());
      expect(src.contains('quotaTouche'), isTrue);
      expect(src.contains('Ne vous fiez pas aux jauges'), isTrue);
    });

    test('le bandeau propose de réessayer', () {
      final src = _sansCommentaires(sourceAbonnementGroupe());
      expect('invalidate(adminSubscriptionProvider)'.allMatches(src).length,
          greaterThanOrEqualTo(2),
          reason: 'Le bandeau ET l’état illisible doivent tous deux offrir '
              'de réessayer.');
    });
  });
}
