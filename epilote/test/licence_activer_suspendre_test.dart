import 'dart:io';

import 'package:epilote/core/constants/licence_statut.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  ACTIVER, SUSPENDRE, REPRENDRE, RÉSILIER
//
//  ── L'ÉTAT AVANT, MESURÉ ──────────────────────────────────────────────────
//  Une licence de quarante millions avait UNE action : « Modifier ». Le statut
//  était une liste déroulante au milieu du formulaire, entre le montant et la
//  référence de marché — au même rang qu'une faute de frappe. On résiliait un
//  marché national en changeant un menu et en cliquant « Enregistrer » :
//    • sans confirmation,
//    • sans motif,
//    • sans trace — `tutelle_licences` était la SEULE table chère de la base
//      sans déclencheur d'audit, alors que `fn_audit_metier` en surveille dix
//      autres (notes, paiements, élèves…),
//    • et sans règle : ressusciter un marché résilié, activer un marché dont
//      le terme est passé, tout était permis.
//
//  ── ⚠️ ET LE REVENU DOUBLÉ ────────────────────────────────────────────────
//  `mrrLicencesXaf` somme TOUTES les licences actives. Deux licences actives
//  qui se chevauchent — un renouvellement activé avant le terme du précédent —
//  comptaient DEUX FOIS. Sur un marché à 40 M, c'est 3,3 M/mois de revenu
//  inexistant dans le seul tableau qui dit si la plateforme gagne de l'argent.
//
//  ── ⚠️⚠️ CE QUE SUSPENDRE NE FAIT PAS ─────────────────────────────────────
//  SUSPENDRE NE COUPE RIEN. Ni le ministère, ni son réseau, ni un module.
//  C'est la contrainte C4 du 0160 : « on ne ferme pas l'État pour un mandat en
//  retard ». La suspension est un état CONTRACTUEL — elle sort la licence du
//  revenu, elle s'affiche des deux côtés avec son motif, elle appelle une
//  conversation. Elle ne s'exécute pas contre l'utilisateur.
// ════════════════════════════════════════════════════════════════════════════

const _migration =
    '../database/migrations/0186_AVANT_LE_BUILD_activer_suspendre_une_licence.sql';
const _enumMigration =
    '../database/migrations/0185_AVANT_LE_BUILD_une_licence_peut_etre_suspendue.sql';
const _carte = 'lib/features/super_admin/screens/economie_screen.dart';
const _dialogue =
    'lib/features/super_admin/screens/economie/licence_statut_dialog.dart';
const _formulaire =
    'lib/features/super_admin/screens/economie/licence_form_dialog.dart';
const _provider =
    'lib/features/super_admin/providers/economie_provider.dart';
const _carteMinistere =
    'lib/features/admin_groupe/screens/admin_licence_card.dart';

String _lire(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) fail('Fichier introuvable : $chemin — sonde aveugle.');
  return f.readAsStringSync();
}

void main() {
  group('La machine à états dit la même chose des deux côtés', () {
    test('« suspendue » existe, entre « active » et « echue »', () {
      // L'ordre de l'énumération est celui du cycle de vie, et il sert au tri.
      expect(kStatutsLicence,
          ['brouillon', 'active', 'suspendue', 'echue', 'resiliee']);
      expect(libelleStatutLicence('suspendue'), 'Suspendue');
      expect(_lire(_enumMigration).contains("ADD VALUE IF NOT EXISTS 'suspendue'"),
          isTrue);
    });

    test('résiliée est TERMINAL — la seule règle sans exception', () {
      // Sans elle, « résilier » ne serait qu'un statut de plus, révocable
      // d'un clic. C'est ce qui distingue une clôture d'un changement d'avis.
      expect(transitionsLicence('resiliee'), isEmpty);
      expect(_lire(_migration).contains('Une licence resiliee ne se reactive pas'),
          isTrue);
    });

    test('chaque état ouvre exactement les sorties que la base accepte', () {
      expect(transitionsLicence('brouillon'), ['active', 'resiliee']);
      expect(transitionsLicence('active'), ['suspendue', 'echue', 'resiliee']);
      // La reprise : c'est tout l'intérêt d'un état RÉVERSIBLE.
      expect(transitionsLicence('suspendue'), ['active', 'resiliee']);
      // Une licence échue se prolonge par avenant, puis se réactive.
      expect(transitionsLicence('echue'), ['active', 'resiliee']);
      expect(transitionsLicence(null), isEmpty);
      expect(transitionsLicence('bidon'), isEmpty);
    });

    test('l’écran ne propose que des transitions existantes', () {
      // ⚠️ Proposer un bouton que la base refusera, c'est envoyer le fondateur
      // se faire jeter — sur un marché national, devant un ministère.
      for (final depuis in kStatutsLicence) {
        for (final vers in transitionsLicence(depuis)) {
          expect(kStatutsLicence.contains(vers), isTrue,
              reason: '« $depuis » propose « $vers », qui n’est pas un statut.');
          expect(vers, isNot(depuis));
        }
      }
    });

    test('le bouton porte un VERBE, pas le nom de l’état', () {
      // « Suspendre », pas « statut = suspendue ». Et la reprise se nomme
      // « Reprendre » : on ne « ré-active » pas un marché qu'on a arrêté.
      expect(verbeTransitionLicence('active', depuis: 'brouillon'), 'Activer');
      expect(verbeTransitionLicence('active', depuis: 'suspendue'), 'Reprendre');
      expect(verbeTransitionLicence('suspendue'), 'Suspendre');
      expect(verbeTransitionLicence('resiliee'), 'Résilier');
    });

    test('« échue » et « suspendue » ne se confondent pas', () {
      // L'une est un FAIT (le terme est passé), l'autre une DÉCISION. Les
      // confondre laisse croire qu'un marché s'est arrêté tout seul.
      expect(explicationStatutLicence('echue'), contains('terme'));
      expect(explicationStatutLicence('suspendue'), contains('décision'));
      expect(explicationStatutLicence('suspendue'),
          isNot(equals(explicationStatutLicence('echue'))));
    });
  });

  group('On n’arrête pas un marché sans écrire pourquoi', () {
    test('le motif est exigé pour suspendre et pour résilier — pas ailleurs',
        () {
      expect(motifObligatoire('suspendue'), isTrue);
      expect(motifObligatoire('resiliee'), isTrue);
      expect(motifObligatoire('active'), isFalse);
      expect(motifObligatoire('echue'), isFalse);
    });

    test('la base l’exige aussi — l’écran ne fait que le dire plus tôt', () {
      final sql = _lire(_migration);
      expect(sql.contains('Motif obligatoire'), isTrue,
          reason: 'Le garde a disparu de la base : un appel direct à la RPC '
              'suspendrait un marché sans un mot d’explication.');
      expect(sql.contains('motif_statut'), isTrue);
    });

    test('le motif est lu par le MINISTÈRE, pas seulement par le fondateur',
        () {
      // Une décision qui l'affecte et qu'il découvrirait sans explication est
      // une décision qu'il vient contester par téléphone — et il a raison.
      expect(_lire(_carteMinistere).contains('_MotifDuStatut'), isTrue);
      expect(_lire(_carte).contains('l.motifStatut'), isTrue);
    });
  });

  group('Le revenu ne compte pas deux fois le même mois', () {
    test('deux licences actives ne peuvent pas se chevaucher', () {
      final sql = _lire(_migration);
      expect(sql.contains('fn_licence_active_sans_chevauchement'), isTrue,
          reason: 'Le garde du revenu a sauté : un renouvellement activé avant '
              'le terme du précédent compterait DEUX FOIS.');
      expect(sql.contains('l.date_debut <= NEW.date_fin'), isTrue);
      expect(sql.contains('l.date_fin   >= NEW.date_debut'), isTrue);
    });

    test('le garde vit dans un DÉCLENCHEUR, pas seulement dans la RPC', () {
      // Il doit tenir sur TOUS les chemins d'écriture, y compris le formulaire
      // qui écrit en direct dans la table.
      final sql = _lire(_migration);
      expect(sql.contains('CREATE TRIGGER trg_licence_active_sans_chevauchement'),
          isTrue);
    });

    test('seul « active » compte comme revenu', () {
      expect(licenceEnVigueur('active'), isTrue);
      for (final s in ['suspendue', 'brouillon', 'echue', 'resiliee']) {
        expect(licenceEnVigueur(s), isFalse,
            reason: '« $s » est revenu dans le revenu de la plateforme.');
      }
    });
  });

  group('Une décision sur un marché laisse une trace', () {
    test('la table est enfin auditée', () {
      // ⚠️ `tutelle_licences` était la SEULE table chère sans déclencheur
      // d'audit, alors que `fn_audit_metier` en surveille dix autres.
      final sql = _lire(_migration);
      expect(sql.contains('CREATE TRIGGER trg_audit_metier'), isTrue);
      expect(sql.contains('ON public.tutelle_licences'), isTrue);
    });

    test('qui et quand sont stampés sur la ligne', () {
      final sql = _lire(_migration);
      expect(sql.contains('statut_change_par'), isTrue);
      expect(sql.contains('statut_change_le'), isTrue);
    });
  });

  group('Aucun chemin ne contourne les règles', () {
    test('l’écran passe par la RPC, jamais par un update direct', () {
      final src = _lire(_provider);
      expect(src.contains("rpc('licence_changer_statut'"), isTrue);
    });

    test('le formulaire ne change plus le statut en édition', () {
      // ⚠️ Il écrit en DIRECT dans la table : il contournerait le motif
      // obligatoire, le refus de ressusciter un résilié et le refus d'activer
      // un marché terminé.
      final src = _lire(_formulaire);
      expect(src.contains('_edition\n                              ? _StatutFige'),
          isTrue,
          reason: 'La liste déroulante de statut est revenue en édition : elle '
              'contourne les quatre règles de 0186.');
      expect(src.contains("for (final st in const [\n                                      'brouillon',\n                                      'active'\n                                    ])"),
          isTrue,
          reason: 'La création propose de nouveau les états de SORTIE, qui se '
              'décident après, avec un motif.');
    });

    test('le geste réservé au super_admin', () {
      final sql = _lire(_migration);
      expect(sql.contains('IF NOT is_super_admin() THEN'), isTrue);
      expect(sql.contains('REVOKE ALL ON FUNCTION'), isTrue);
    });
  });

  group('⚠️ Suspendre ne coupe l’accès de personne', () {
    test('la RPC n’écrit RIEN sur school_groups', () {
      // C'est la garantie technique de la contrainte C4 (0160). Le jour où
      // quelqu'un ajoute un UPDATE ici, ce test tombe — et c'est le but.
      final sql = _lire(_migration);
      final corps = sql.substring(sql.indexOf('licence_changer_statut'));
      expect(corps.contains('UPDATE public.school_groups'), isFalse,
          reason: 'Le statut d’un marché commande désormais un accès. Un '
              'ministère peut être coupé par une date de facturation.');
      expect(sql.contains('AUCUNE'), isTrue,
          reason: 'L’avertissement a disparu du fichier : la prochaine '
              'personne ajoutera l’UPDATE de bonne foi.');
    });

    test('le fondateur le lit AU MOMENT où il clique', () {
      // Sinon il croit tenir un levier, et découvre le contraire le jour où il
      // en a besoin — c'est-à-dire au pire moment.
      expect(
          _lire(_dialogue).contains('Cela ne coupe l’accès de personne'), isTrue);
    });

    test('et le ministère garde sa phrase', () {
      expect(
          _lire(_carteMinistere)
              .contains('Votre accès ne dépend pas de cette licence'),
          isTrue);
    });
  });
}
