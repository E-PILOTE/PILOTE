import 'dart:io';

import 'package:epilote/features/audit/providers/audit_models.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE JOURNAL NE NOTAIT QUE LES ACTES ADMINISTRATIFS (2026-08-28)
//
//  ── L'ÉTAT DES LIEUX, MESURÉ ──────────────────────────────────────────────
//  `audit_logs` : 82 lignes, 6 tables, depuis le 4 août — sur 37 écoles. Il
//  était alimenté par 14 fonctions `SECURITY DEFINER` et 3 déclencheurs, tous
//  du côté ADMINISTRATIF et EN LIGNE : cycle de vie d'un agent, permissions,
//  tarifs, calendrier, emploi du temps.
//
//  Rien, ou presque, du côté ÉCOLE — celui où une secrétaire et un professeur
//  agissent chaque jour, hors ligne. Or c'est là que se prennent les décisions
//  qu'on vient contester : une note changée après coup, un paiement annulé, un
//  élève retiré d'une classe, une sanction ajoutée à un dossier.
//
//  La migration 0144 attache `fn_audit_metier()` à dix tables, en UPDATE et
//  DELETE seulement — créer une note est le geste normal du métier, la CHANGER
//  après coup est celui dont on demande des comptes.
//
//  ── L'ÉCRAN ATTENDAIT DÉJÀ CE JOURNAL ─────────────────────────────────────
//  `auditEntityLabel` connaissait déjà `grades`, `bulletins`, `payroll`,
//  `student_payments`, `discipline_incidents`… : l'interface avait été écrite
//  pour un journal qui n'existait pas encore. Seuls manquaient les deux
//  réglages ajoutés par 0144.
//
//  ── LES TROIS PROPRIÉTÉS VÉRIFIÉES EN PRODUCTION (transaction annulée) ────
//    sans auteur (migration)   → 0 ligne. Une seule migration a touché
//                                431 250 notes en une minute le 2 août ; sans
//                                cette garde le journal naîtrait avec un
//                                demi-million de lignes que personne n'a
//                                écrites.
//    auteur, rien ne bouge     → 0 ligne.
//    auteur, la note change    → 1 ligne : {"score": 15.93} → {"score": 16.93}
//
//  Et la plus importante, éprouvée en cassant volontairement le journal
//  (`CHECK (false)` sur `audit_logs`) : l'écriture métier a RÉUSSI, 0 ligne de
//  journal, aucune erreur remontée. Un `23xxx` ou un `42501` venu du
//  déclencheur serait FATAL pour le connecteur PowerSync, qui jetterait le lot
//  entier. Un journal ne doit jamais coûter la donnée qu'il observe.
// ════════════════════════════════════════════════════════════════════════════

/// Les dix tables attachées par la migration 0144.
const _kTablesJournalisees = <String>[
  'grades',
  'evaluations',
  'bulletins',
  'class_enrollments',
  'students',
  'discipline_incidents',
  'student_payments',
  'payroll',
  'class_subjects',
  'school_levels',
];

String _lireMigration() {
  final f = File('../database/migrations/'
      '0144_un_journal_qui_ne_note_que_les_actes_administratifs.sql');
  if (!f.existsSync()) fail('Migration 0144 introuvable.');
  return f.readAsStringSync();
}

void main() {
  group('Tout ce qui est journalisé est lisible à l\'écran', () {
    test('chaque table attachée porte un libellé français', () {
      for (final t in _kTablesJournalisees) {
        final libelle = auditEntityLabel(t);
        expect(libelle, isNot(equals(t.replaceAll('_', ' '))),
            reason: '`$t` retombe sur le repli générique : le journal '
                'afficherait « ${t.replaceAll('_', ' ')} » à une directrice. '
                'Journaliser une table sans la nommer, c\'est écrire pour '
                'personne.');
      }
    });

    test('les réglages invisibles sont au moins « sensibles »', () {
      // Un coefficient et une moyenne de passage ne touchent AUCUN élève
      // nommément — et les touchent tous.
      for (final t in ['class_subjects', 'school_levels', 'grades', 'payroll']) {
        final e = AuditEntry(
          id: 'x',
          action: 'UPDATE',
          tableName: t,
          userName: 'Agent',
          userRole: 'directeur',
          createdAt: DateTime(2026, 8, 28),
        );
        expect(e.severity, isNot(AuditSeverity.low),
            reason: 'Une modification de `$t` ne peut pas être anodine.');
      }
    });

    test('une suppression est toujours au niveau le plus haut', () {
      final e = AuditEntry(
        id: 'x',
        action: 'DELETE',
        tableName: 'lesson_entries',
        userName: 'Agent',
        userRole: 'directeur',
        createdAt: DateTime(2026, 8, 28),
      );
      expect(e.severity, AuditSeverity.high);
    });
  });

  group('Le journal ne coûte jamais la donnée qu\'il observe', () {
    final sql = _lireMigration();

    test('le déclencheur ne lève jamais', () {
      expect(sql.contains('EXCEPTION WHEN OTHERS THEN'), isTrue,
          reason: 'Une erreur du journal remonterait comme une erreur de '
              'l\'écriture métier — et `23xxx` / `42501` sont FATALS pour le '
              'connecteur PowerSync, qui jette le LOT ENTIER en attente.');
    });

    test('il se tait quand personne n\'agit', () {
      expect(sql.contains('IF acteur IS NULL THEN'), isTrue,
          reason: 'Migrations et tâches serveur n\'ont pas d\'auteur : les '
              'inscrire serait mentir. Une seule migration a touché 431 250 '
              'notes en une minute.');
    });

    test('il n\'enregistre que les colonnes qui ont bougé', () {
      expect(sql.contains("- 'updated_at'"), isTrue,
          reason: '`updated_at` change à chaque écriture : sans l\'exclure, '
              'toute mise à jour paraîtrait significative.');
      expect(sql.contains('IS DISTINCT FROM (j_new -> cle)'), isTrue,
          reason: 'Recopier la ligne entière rend le journal illisible '
              'précisément le jour où on en a besoin.');
    });

    test('créer n\'est pas journalisé — modifier et effacer le sont', () {
      expect(sql.contains('AFTER %s ON %I'), isTrue);
      expect(RegExp(r'AFTER\s+INSERT').hasMatch(sql), isFalse,
          reason: 'Créer une note est le geste normal du métier. Ce choix '
              'divise le volume par vingt et garde ce qui se conteste.');
    });

    test('les dix tables du relevé sont attachées', () {
      for (final t in _kTablesJournalisees) {
        expect(sql.contains("('$t',"), isTrue,
            reason: '`$t` n\'est plus attachée au journal.');
      }
    });
  });
}
