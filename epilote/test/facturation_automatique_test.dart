import 'dart:io';

import 'package:epilote/features/admin_groupe/providers/admin_subscription_provider.dart';
import 'package:epilote/features/super_admin/providers/invoices_provider.dart'
    show InvoiceDetail;
import 'package:flutter_test/flutter_test.dart';

import 'ecran_abonnements_source.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LA FACTURE DU MOIS S'ÉMET TOUTE SEULE — ce qui ne doit plus se reperdre
//
//  ── CE QUI MANQUAIT (mesuré sur la base de production, 2026-09-04) ────────
//  Les cinq plans clients sont MENSUELS, et RIEN n'émettait la facture du mois
//  suivant. Les tâches de nuit expiraient et rappelaient ; la seule chose qui
//  créait une facture de renouvellement était un bouton, dans l'espace du
//  CLIENT, visible cinq jours par mois. Le fondateur, lui, n'avait aucun
//  moyen d'en émettre une : son écran ne savait que marquer PAYÉE une facture
//  déjà existante.
//
//  ── CE QUE CE FICHIER GARDE ───────────────────────────────────────────────
//  Le correctif (0190) vit surtout en base : une boucle nocturne, une fonction
//  interne, un job pg_cron. Aucun test Dart ne peut rejouer un cron. Ce qui
//  est gardé ici, ce sont les quatre propriétés dont dépend la sûreté de
//  l'automatisation — et les deux endroits de l'application qui doivent la
//  refléter à l'écran.
// ════════════════════════════════════════════════════════════════════════════

const _mig =
    '../database/migrations/0190_AVANT_LE_BUILD_la_facture_du_mois_ne_sattend_plus.sql';
const _dialogueClient =
    'lib/features/admin_groupe/screens/admin_subscription_renew_dialog.dart';
const _carteClient =
    'lib/features/admin_groupe/screens/admin_subscription_screen.dart';
const _boutonFondateur =
    'lib/features/super_admin/screens/subscriptions_emettre_facture.dart';
// La fiche d'un abonnement, où vit le bouton d'émission. C'était
// `subscriptions_screen.dart` avant que ses 2 652 lignes ne soient découpées.
const _ficheFondateur = 'subscription_detail_modal.dart';

String _lire(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) fail('Fichier introuvable : $chemin — sonde aveugle.');
  return f.readAsStringSync().replaceAll('\r\n', '\n');
}

InvoiceDetail _facture(String statut, {int montant = 52000}) => InvoiceDetail(
      id: 'i-$statut',
      groupId: 'g1',
      groupName: 'Groupe',
      invoiceNumber: 'INV-2026-0042',
      amountXaf: montant,
      periodStart: DateTime(2026, 9, 4),
      periodEnd: DateTime(2026, 10, 4),
      status: statut,
      createdAt: DateTime(2026, 9, 4),
      updatedAt: DateTime(2026, 9, 4),
    );

AdminSubscriptionData _donnees(List<InvoiceDetail> factures) =>
    AdminSubscriptionData(
      subscription: null,
      plans: const [],
      tickets: const [],
      invoices: factures,
    );

void main() {
  group('La boucle de nuit ne peut pas facturer deux fois', () {
    test('⚠️ aucune émission tant qu’une facture attend', () {
      // C'est CETTE règle qui autorise une tâche QUOTIDIENNE. Sans elle, un
      // client impayé recevrait une facture par nuit — trente par mois.
      final sql = _lire(_mig);
      expect(sql.contains("status IN ('pending'::invoice_status, 'overdue'::invoice_status)"),
          isTrue,
          reason: 'La garde d’idempotence a disparu : le cron facturera '
              'chaque nuit le même groupe.');
      expect(sql.contains("'already_pending', true"), isTrue);
    });

    test('un groupe mal configuré ne prive pas les autres de leur facture', () {
      final sql = _lire(_mig);
      final boucle = sql.substring(sql.indexOf('FOR v_grp IN'));
      expect(boucle.contains('EXCEPTION WHEN OTHERS THEN'), isTrue,
          reason: 'Une seule erreur interrompt désormais toute la nuit de '
              'facturation.');
      expect(boucle.contains('RAISE WARNING'), isTrue,
          reason: 'L’échec est avalé sans laisser de trace dans les logs.');
    });

    test('⚠️ la facture a toujours un auteur, même sans session', () {
      // `group_invoices.created_by` est NOT NULL et sous cron `auth.uid()` est
      // NUL. Trouvé en répétition à blanc : sans ce repli, la PREMIÈRE nuit
      // échouait sur chaque groupe — et silencieusement, puisque la boucle
      // avale les erreurs.
      final sql = _lire(_mig);
      expect(sql.contains('v_auteur := COALESCE('), isTrue);
      expect(sql.contains("WHERE role = 'super_admin' ORDER BY created_at LIMIT 1"),
          isTrue,
          reason: 'Plus de repli sur le super_admin : created_by sera NULL '
              'sous cron et l’insertion échouera.');
    });

    test('un plan gratuit est prolongé, pas facturé à zéro franc', () {
      final sql = _lire(_mig);
      expect(sql.contains('IF v_price IS NULL OR v_price = 0 THEN'), isTrue);
      final gratuit = sql.substring(sql.indexOf('IF v_price IS NULL OR v_price = 0 THEN'));
      expect(gratuit.contains("'free', true"), isTrue,
          reason: 'Un client gratuit se retrouverait en lecture seule pour '
              'une somme qui n’existe pas.');
    });

    test('un ministère est refusé net', () {
      final sql = _lire(_mig);
      expect(sql.contains('Un ministere de tutelle ne renouvelle pas un abonnement'),
          isTrue);
      expect(sql.contains('COALESCE(sg.administre_referentiel_national, false) = false'),
          isTrue,
          reason: 'La boucle balaierait les ministères, dont la licence n’a '
              'pas d’échéance à renouveler.');
    });
  });

  group('⚠️ Ces fonctions écrivent : elles ne sont pas publiques', () {
    test('les trois sont révoquées d’anon et authenticated', () {
      // `anon`, c'est la clé publique présente dans chaque installateur.
      final sql = _lire(_mig);
      for (final f in [
        '_emettre_facture_renouvellement',
        'emettre_factures_a_echoir',
        'expire_subscriptions',
      ]) {
        expect(sql.contains('REVOKE EXECUTE ON FUNCTION public.$f'), isTrue,
            reason: '$f redevient appelable sans compte.');
      }
      expect('FROM PUBLIC, anon, authenticated'.allMatches(sql).length,
          greaterThanOrEqualTo(3));
    });

    test('le bouton du fondateur passe par la fonction QUI VÉRIFIE', () {
      // create_renewal_invoice garde l'ACL ; le calcul, lui, a été extrait.
      // Deux implémentations du même contrat divergent au premier champ.
      final sql = _lire(_mig);
      final garde = sql.substring(sql.indexOf('CREATE OR REPLACE FUNCTION public.create_renewal_invoice'));
      expect(garde.contains('IF NOT (is_super_admin()'), isTrue);
      expect(garde.contains('RETURN _emettre_facture_renouvellement(p_group_id);'),
          isTrue,
          reason: 'Le calcul a été recopié dans create_renewal_invoice : deux '
              'sources pour une même facture.');
      expect(_lire(_boutonFondateur).contains("rpc('create_renewal_invoice'"),
          isTrue);
    });

    test('la nuit facture APRÈS l’expiration, jamais avant', () {
      // 01 h 05 expire, 01 h 20 facture : un groupe qui vient de basculer
      // reçoit sa facture dans la même nuit, pas le lendemain.
      final sql = _lire(_mig);
      expect(sql.contains("cron.schedule('emettre-factures', '20 1 * * *'"), isTrue,
          reason: 'L’horaire a bougé : vérifier qu’il reste après le job '
              'expire-subscriptions de 01 h 05.');
    });
  });

  group('L’écran du client dit la vérité sur ce qu’il doit', () {
    test('⚠️ le tarif n’est plus annoncé « / an » sur un plan mensuel', () {
      // Le mensonge d'un facteur douze que la migration 0077 avait corrigé en
      // base : l'écran, lui, ne l'avait jamais suivi.
      final src = _lire(_dialogueClient);
      expect(src.contains(r"'${fmtXaf(s.priceXaf)} / an'"), isFalse,
          reason: 'Le client relit « 50 000 F / an » pour un mois d’abonnement.');
      expect(src.contains(r'/ ${s.periodSuffix}'), isTrue);
    });

    test('la période couverte accompagne le montant dû', () {
      final src = _lire(_dialogueClient);
      expect(src.contains("_row('Période',"), isTrue,
          reason: 'Un montant dû sans sa période ne se vérifie pas.');
    });

    test('une facture déjà émise remplace le bouton « Renouveler »', () {
      // La plateforme émet 7 jours avant l'échéance, le bandeau s'allume à 5 :
      // il existe une fenêtre où le client voyait « Renouveler » alors que sa
      // facture attendait déjà. Il cliquait, on lui répondait « déjà en
      // attente ».
      final src = _lire(_carteClient);
      expect(src.contains('if (enAttente != null) ...['), isTrue);
      expect(src.contains('else if (sub.expired || sub.expireSoon)'), isTrue,
          reason: 'Les deux blocs ne s’excluent plus : le bouton et la facture '
              'peuvent s’afficher ensemble.');
    });

    test('factureEnAttente rend la facture due, et rien d’autre', () {
      expect(_donnees(const []).factureEnAttente, isNull);
      expect(_donnees([_facture('paid')]).factureEnAttente, isNull,
          reason: 'Une facture réglée est présentée comme due.');
      expect(_donnees([_facture('cancelled')]).factureEnAttente, isNull);
      expect(_donnees([_facture('pending')]).factureEnAttente?.amountXaf, 52000);
      expect(_donnees([_facture('overdue')]).factureEnAttente?.isOverdue, isTrue);
      // Réglée puis rouverte : c'est la due qui compte, pas la première ligne.
      expect(
          _donnees([_facture('paid'), _facture('pending', montant: 82000)])
              .factureEnAttente
              ?.amountXaf,
          82000);
    });
  });

  group('Le fondateur peut enfin émettre', () {
    test('le bouton existe dans la fiche du groupe', () {
      final src = sourcePieceAbonnements(_ficheFondateur);
      expect(src.contains('emettreFactureDeRenouvellement('), isTrue,
          reason: 'Le fondateur n’a plus aucun moyen d’émettre une facture : '
              'il ne peut que marquer payée celle que le client a demandée.');
    });

    test('⚠️ il n’est pas proposé sur un ministère', () {
      // La base refuserait — un écran qui le propose envoie l'utilisateur se
      // faire jeter.
      // ⚠️ Sonde de PROXIMITÉ : elle compare des positions. Elle lit la pièce,
      // jamais le dossier concaténé — sinon elle comparerait deux fichiers.
      final src = sourcePieceAbonnements(_ficheFondateur);
      final i = src.indexOf('emettreFactureDeRenouvellement(');
      final avant = src.substring(0, i);
      expect(avant.lastIndexOf('if (!s.estMinistere)') > avant.lastIndexOf('Row(children: ['),
          isTrue,
          reason: 'Le bouton d’émission n’est plus gardé par estMinistere.');
    });

    test('émettre n’encaisse pas', () {
      // Le paiement reste un second geste, explicite, dans l'écran Factures.
      final src = _lire(_boutonFondateur);
      // ⚠️ On cherche l'APPEL, pas le nom : le fichier NOMME `mark_invoice_paid`
      // dans son en-tête, précisément pour expliquer qu'il ne l'appelle pas.
      // Une sonde sur le nom seul se piège sur le commentaire qui la justifie.
      expect(src.contains("rpc('mark_invoice_paid'"), isFalse,
          reason: 'Le geste d’émission enregistre un paiement : de l’argent '
              'entre en comptabilité sans être arrivé.');
      expect(src.contains('émettre n’encaisse pas'), isTrue);
    });
  });
}
