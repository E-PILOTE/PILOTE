import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LA RELANCE S'ARRÊTAIT LE JOUR OÙ ELLE DEVENAIT UTILE
//
//  ── CE QUI SE PASSAIT (mesuré en production, 2026-09-04) ──────────────────
//  `emit_subscription_reminders()` prévenait à 30, 15, 7, 1 et 0 jour de
//  l'échéance, puis rendait la main dès que l'échéance était passée. Le
//  lendemain, plus rien — alors que l'accès n'est PAS coupé le jour J : il
//  l'est à la fin du délai de grâce. Quinze jours pendant lesquels le client
//  travaille, croit son abonnement en ordre, et n'entend plus personne ; le
//  seizième, la création d'écoles et de comptes s'arrête.
//
//  Et les notifications ne partaient qu'aux `admin_groupe` DU GROUPE : côté
//  plateforme, personne n'apprenait qu'un client venait d'échoir.
//
//  ── ⚠️ CE FICHIER LIT LE SQL SANS SES COMMENTAIRES ────────────────────────
//  L'en-tête de la migration CITE la forme fautive pour l'expliquer. Une sonde
//  qui chercherait cette forme dans le fichier entier se piégerait sur la
//  phrase qui la condamne — le piège s'est déjà refermé trois fois dans ce
//  dépôt.
//
//  ── CE QU'AUCUN TEST DART NE PEUT FAIRE ───────────────────────────────────
//  Rejouer un cron. Le comportement a été mesuré en transaction ANNULÉE sur la
//  base de production, et c'est ce relevé que ces sondes figent :
//
//      J+1  : client=1  fondateur=1   (« Client échu »)
//      J+2  : client=0  fondateur=0   (silence entre les jalons)
//      J+7  : client=1  fondateur=0
//      J+15 : client=1  fondateur=1   (« Client suspendu »)
//      J+16 : client=0  fondateur=0   (silence après la grâce)
//      deux passages le même jour     → 1 seule notification
//      J-30 / J-7 / J-1 / J-0         → inchangés, fondateur jamais notifié
// ════════════════════════════════════════════════════════════════════════════

const _mig =
    '../database/migrations/0191_AVANT_LE_BUILD_la_relance_ne_sarrete_pas_a_lecheance.sql';

String _lire(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) fail('Fichier introuvable : $chemin — sonde aveugle.');
  return f.readAsStringSync().replaceAll('\r\n', '\n');
}

/// Le SQL SANS ses commentaires — voir l'en-tête.
String _sql() => _lire(_mig)
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('--'))
    .join('\n');

void main() {
  group('La relance continue après l’échéance', () {
    test('⚠️ le retour immédiat sur échéance dépassée a disparu', () {
      // La ligne unique qui coupait tout : `if v_days_left < 0 ... continue`.
      final sql = _sql();
      expect(RegExp(r'v_days_left\s*<\s*0').hasMatch(sql), isFalse,
          reason: 'La fonction rend de nouveau la main dès l’échéance passée : '
              'le client n’entend plus rien pendant sa grâce.');
      expect(sql.contains('if v_days_left >= 0 then'), isTrue,
          reason: 'Les deux régimes — avant et après l’échéance — ne se '
              'distinguent plus.');
    });

    test('trois jalons, puis le silence', () {
      // Une relance quotidienne indéfinie se filtre mentalement en trois jours
      // et emporte les vraies avec elle.
      final sql = _sql();
      expect(
          sql.contains(
              'if v_retard <> 1 and v_retard <> 7 and v_retard <> v_grace then'),
          isTrue,
          reason: 'Les jalons d’après-échéance ont changé sans que la règle du '
              'silence soit revue.');
    });

    test('⚠️ l’idempotence réutilise la clé existante, en négatif', () {
      // `subscription_reminder_log` a pour clé (group_id, subscription_end,
      // threshold). Sans le seuil négatif, chaque nuit renverrait la même
      // relance : la colonne est un `integer` sans contrainte de signe.
      final sql = _sql();
      expect(sql.contains('values (g.id, v_end, -v_retard)'), isTrue);
      expect(
          sql.contains(
              'on conflict (group_id, subscription_end, threshold) do nothing'),
          isTrue);
      expect(sql.contains('if not found then'), isTrue,
          reason: 'Sans ce test, une relance déjà inscrite repart quand même.');
    });

    test('le délai de grâce se LIT, il ne se recopie pas', () {
      // Il est publié à l’application par `get_subscription_settings()` depuis
      // `platform_settings`. Une seconde constante ici, et le jour où le
      // fondateur le change, la base et l’écran ne parlent plus du même délai.
      final sql = _sql();
      expect(sql.contains("v_settings->>'grace_days'"), isTrue,
          reason: 'Le délai de grâce est de nouveau écrit en dur dans la '
              'fonction.');
    });
  });

  group('Le fondateur apprend enfin qu’un client a lâché', () {
    test('⚠️ deux alertes plateforme, pas une de plus', () {
      final sql = _sql();
      expect(sql.contains("where p.role = 'super_admin'"), isTrue,
          reason: 'Les alertes ne partent plus au fondateur : il doit de '
              'nouveau REMARQUER qu’un client a échu.');
      expect(sql.contains('if v_retard = 1 or v_retard >= v_grace then'), isTrue,
          reason: 'Le fondateur est notifié à d’autres jalons : une alerte qui '
              'revient tous les jours ne se lit plus.');
      expect(sql.contains("'Client échu : %s'"), isTrue);
      expect(sql.contains("'Client suspendu : %s'"), isTrue);
    });

    test('l’alerte mène là où il peut agir', () {
      final sql = _sql();
      expect(sql.contains("'route', '/super/abonnements'"), isTrue);
      // Et celle du client mène à SA page, pas à celle du fondateur.
      expect(sql.contains("'route', '/admin/abonnement'"), isTrue);
    });

    test('avant l’échéance, le fondateur n’est pas notifié', () {
      // Relevé J-30 / J-7 / J-1 / J-0 : fondateur = 0 à chaque fois. Ce qui le
      // garantit, c’est que le bloc plateforme vit APRÈS le `continue` du
      // régime « avant échéance ».
      final sql = _sql();
      final avant = sql.indexOf('v_emitted := v_emitted + 1;\n      continue;');
      final plateforme = sql.indexOf("where p.role = 'super_admin'");
      expect(avant, greaterThan(0),
          reason: 'Le régime « avant échéance » ne se referme plus sur un '
              'continue : la suite s’exécute pour un abonnement en cours.');
      expect(plateforme, greaterThan(avant));
    });
  });

  group('Ce qui reste hors du mécanisme', () {
    test('⚠️ un ministère n’est pas relancé', () {
      // Son terme est celui de sa licence : il n’expire pas (0183).
      final sql = _sql();
      expect(
          sql.contains(
              'and not coalesce(sg.administre_referentiel_national, false)'),
          isTrue,
          reason: 'Un ministère recevrait une relance d’abonnement — et le '
              'fondateur une alerte « client échu » sur une tutelle.');
    });

    test('un abonnement résilié n’est pas un impayé', () {
      final sql = _sql();
      expect(sql.contains("if g.statut = 'cancelled' then"), isTrue,
          reason: 'Un client qui a résilié est relancé comme un retardataire.');
    });

    test('la fonction n’est pas exposée à la clé publique', () {
      // `anon`, c’est la clé écrite en clair dans l’installateur (leçon 0189).
      final sql = _sql();
      expect(
          RegExp(r'REVOKE EXECUTE ON FUNCTION public\.emit_subscription_reminders'
                  r'\(\)\s*\n?\s*FROM PUBLIC, anon, authenticated')
              .hasMatch(sql),
          isTrue);
    });
  });
}
