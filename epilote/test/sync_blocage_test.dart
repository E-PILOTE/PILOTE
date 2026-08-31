import 'dart:io';

import 'package:epilote/services/powersync/powersync_connector.dart';
import 'package:epilote/services/powersync/sync_failures_provider.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  UN POSTE QUI N'ENVOIE PLUS RIEN DOIT LE DIRE
//
//  ── LE DÉFAUT ─────────────────────────────────────────────────────────────
//  Le connecteur traite trois codes comme définitifs (22…, 23…, 42501) : il
//  abandonne la transaction et journalise la perte. TOUT LE RESTE est
//  `rethrow` — donc rejoué par PowerSync, indéfiniment.
//
//  Pour une panne réseau c'est exactement ce qu'il faut. Pour un désaccord de
//  SCHÉMA — `42703`, colonne inconnue, parce que le poste tourne sur un build
//  antérieur — le rejeu ne réussira JAMAIS. L'école continue de travailler,
//  tout paraît normal à l'écran, et plus une seule inscription ne remonte.
//
//  C'est le pire défaut possible d'un produit hors-ligne, et c'est ce qui tient
//  la migration 0146 (retrait des colonnes Firebase) en otage : on ne retire
//  pas une colonne tant qu'un poste resté en arrière se bloque en silence.
//
//  ── LA CORRECTION, ET CE QU'ELLE N'EST PAS ────────────────────────────────
//  On ne rend PAS ces codes fatals : ce serait jeter les écritures de l'école
//  pour lui épargner un bandeau. On garde le rejeu — rien n'est perdu — et on
//  rend le blocage VISIBLE. Ces tests gardent surtout cette distinction.
// ════════════════════════════════════════════════════════════════════════════

void main() {
  group('Reconnaître un désaccord de schéma', () {
    test('les codes qui ne se résoudront jamais', () {
      for (final code in ['42703', '42P01', '42804', '42883', '42P10']) {
        expect(estDesaccordDeSchema(code), isTrue, reason: 'code $code');
      }
    });

    test('ni un refus définitif, ni une panne passagère', () {
      for (final code in ['42501', '23502', '22001', '40001', '53300', 'PGRST116']) {
        expect(estDesaccordDeSchema(code), isFalse, reason: 'code $code');
      }
      expect(estDesaccordDeSchema(null), isFalse);
    });
  });

  group('Reconnaître un refus définitif', () {
    test('contrainte, donnée invalide, RLS', () {
      for (final code in ['22001', '22P02', '23502', '23503', '23505', '42501']) {
        expect(estRefusDefinitif(code), isTrue, reason: 'code $code');
      }
    });

    test('une panne passagère n\'en est pas un', () {
      for (final code in ['40001', '53300', '08006']) {
        expect(estRefusDefinitif(code), isFalse, reason: 'code $code');
      }
      expect(estRefusDefinitif(null), isFalse);
    });
  });

  // ── LE GARDE QUI COMPTE ───────────────────────────────────────────────────
  group('Les deux familles ne doivent JAMAIS se recouvrir', () {
    test('un désaccord de schéma n\'est jamais traité comme définitif', () {
      // Si `42703` devenait fatal, le connecteur compléterait la transaction :
      // les inscriptions saisies par l'école seraient DÉTRUITES pour faire
      // disparaître un bandeau. Le remède serait pire que le mal.
      for (final code in ['42703', '42P01', '42804', '42883', '42P10']) {
        expect(estRefusDefinitif(code), isFalse,
            reason: 'Le code $code a été ajouté aux codes fatals. Un poste en '
                'retard verrait alors ses écritures JETÉES au lieu d\'être '
                'gardées en file. Le blocage se signale, il ne se solde pas.');
      }
    });
  });

  group('Les deux natures d\'échec ne se disent pas du même mot', () {
    test('un abandon est une perte, un blocage n\'en est pas une', () {
      final quand = DateTime(2026, 8, 31);
      final perte = SyncFailure(
          id: '1', at: quand, code: '23502', message: 'm', summary: 's');
      final bloque = SyncFailure(
          id: '2', at: quand, code: '42703', message: 'm', summary: 's',
          kind: 'blocage');
      expect(perte.estBlocage, isFalse);
      expect(bloque.estBlocage, isTrue);
    });

    test('une ligne écrite avant la colonne `kind` est un abandon', () {
      // Rétro-compatibilité : les lignes d'avant valent toutes « abandon ».
      // Les traiter comme des blocages ferait afficher « rien n'est perdu »
      // sur des écritures réellement détruites.
      final ancienne = SyncFailure(
          id: '3', at: DateTime(2026, 8, 31), code: '42501',
          message: 'm', summary: 's');
      expect(ancienne.kind, 'abandon');
      expect(ancienne.estBlocage, isFalse);
    });
  });

  // ── Sondes de source ──────────────────────────────────────────────────────
  group('Le connecteur ne peut pas redevenir muet', () {
    String lireConnecteur() {
      final f = File('lib/services/powersync/powersync_connector.dart');
      expect(f.existsSync(), isTrue, reason: 'Sonde aveugle : connecteur absent.');
      return f.readAsStringSync();
    }

    test('le rejeu est consigné AVANT d\'être relancé', () {
      final src = lireConnecteur();
      final i = src.indexOf('await _noterRejeu(');
      final j = src.indexOf('rethrow;', i < 0 ? 0 : i);
      expect(i, greaterThan(0),
          reason: 'Le `rethrow` non fatal ne consigne plus rien : le blocage '
              'redevient invisible, et 0146 reste en otage pour toujours.');
      expect(j, greaterThan(i),
          reason: '`_noterRejeu` doit précéder le `rethrow`.');
    });

    test('une transaction réussie efface le blocage', () {
      // Sans cela, le bandeau resterait affiché sur un poste réparé — et un
      // indicateur qui ment dans ce sens ne sera plus cru dans l\'autre.
      expect(lireConnecteur().contains('_finBlocage('), isTrue);
    });

    test('le journal local porte la colonne qui distingue les deux', () {
      final schema =
          File('lib/services/powersync/powersync_schema.dart').readAsStringSync();
      final i = schema.indexOf("Table.localOnly('sync_failures'");
      expect(i, greaterThan(0), reason: 'Sonde aveugle : table introuvable.');
      final bloc = schema.substring(i, i + 700);
      expect(bloc.contains("Column.text('kind')"), isTrue,
          reason: 'Sans `kind`, blocage et perte se confondent à l\'écran.');
    });
  });
}
