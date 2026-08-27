import 'dart:io';

import 'package:epilote/core/utils/identite_offline.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  DEUX APPAREILS QUI POSENT LE MÊME FAIT DOIVENT ÉCRIRE LA MÊME LIGNE
//
//  ── DÉFAUT 1 — l'appel en double ───────────────────────────────────────────
//  Un appel est un fait unique : la 6ᵉ A, le 12 mars, au matin. Le professeur
//  principal et le surveillant le saisissaient chacun hors ligne, chacun avec
//  son `Uuid().v4()` : DEUX `attendance_records` remontaient pour un seul
//  appel. La contrainte serveur ne les rattrape pas — elle porte aussi sur
//  `subject_id`, resté NULL, et deux NULL ne sont pas égaux en SQL.
//  Conséquence visible : `classRollProvider` joint les deux enregistrements et
//  affiche CHAQUE ÉLÈVE DEUX FOIS, avec deux statuts contradictoires.
//
//  ── DÉFAUT 2 — le double appui qui jette le lot ────────────────────────────
//  `setAttendance` décidait d'insérer d'après `existingEntryId`, lu dans un
//  instantané du flux. Deux appuis rapides — « Absent » puis « Présent », le
//  geste ordinaire d'un appel — arrivaient tous deux avec `entryId` nul et
//  INSÉRAIENT deux fois. Or la base tient
//  `UNIQUE (attendance_record_id, student_id)` : 23505, code FATAL pour le
//  connecteur PowerSync, qui jette le LOT ENTIER en attente — l'appel, mais
//  aussi les paiements et les notes saisis dans la même heure.
//
//  ── POURQUOI PAS UNE CONTRAINTE D'UNICITÉ DE PLUS ? ────────────────────────
//  Parce qu'elle changerait la convergence en PERTE : un 23505 de plus, un lot
//  de plus jeté. On rend l'écriture idempotente, pas interdite.
// ════════════════════════════════════════════════════════════════════════════

const _kProvider = 'lib/features/vie_scolaire/providers/presences_provider.dart';

String _lire(String chemin) {
  final f = File(chemin);
  if (!f.existsSync()) fail('$chemin introuvable — tourner depuis `epilote/`.');
  return f.readAsStringSync();
}

String _codeSeul(String chemin) => _lire(chemin)
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

void main() {
  group('Un identifiant déduit de la clé', () {
    test('deux appareils, même fait, même identifiant', () {
      final a = idDeterministe('attendance_record', ['classe-1', '2026-03-12', 'AM']);
      final b = idDeterministe('attendance_record', ['classe-1', '2026-03-12', 'AM']);
      expect(a, b, reason: 'C\'est toute la raison d\'être du procédé.');
    });

    test('un fait différent, un identifiant différent', () {
      final matin = idDeterministe('attendance_record', ['c1', '2026-03-12', 'AM']);
      final soir = idDeterministe('attendance_record', ['c1', '2026-03-12', 'PM']);
      final demain = idDeterministe('attendance_record', ['c1', '2026-03-13', 'AM']);
      final autre = idDeterministe('attendance_record', ['c2', '2026-03-12', 'AM']);
      expect({matin, soir, demain, autre}.length, 4);
    });

    test('le TYPE sépare les familles', () {
      // Sans lui, une entrée d'appel et un appel bâtis sur les mêmes chaînes
      // se retrouveraient avec le même identifiant, dans deux tables.
      expect(idDeterministe('attendance_record', ['x', 'y']),
          isNot(idDeterministe('attendance_entry', ['x', 'y'])));
    });

    test('les composantes ne se confondent pas par recollage', () {
      // « ab » + « c » ne doit pas donner la même clé que « a » + « bc ».
      expect(idDeterministe('t', ['ab', 'c']), isNot(idDeterministe('t', ['a', 'bc'])));
    });

    test('c\'est un UUID valide, que Postgres acceptera', () {
      final id = idDeterministe('attendance_entry', ['appel-1', 'eleve-1']);
      expect(
          RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-'
                  r'[0-9a-f]{12}$')
              .hasMatch(id),
          isTrue,
          reason: 'UUID v5 attendu, sinon la colonne uuid refusera la ligne.');
    });

    test('l\'espace de noms est figé', () {
      // Le changer réattribuerait TOUS les identifiants déduits : les appareils
      // cesseraient de converger et les lignes existantes seraient orphelines.
      expect(kNamespaceEpilote, '9f2a6c31-8d47-5b0e-9c14-6a7b3e5d8f20');
    });
  });

  group('L\'appel écrit de façon idempotente', () {
    test('l\'appel et ses entrées portent un identifiant déduit', () {
      final code = _codeSeul(_kProvider);
      expect(code.contains("idDeterministe('attendance_record'"), isTrue);
      expect(code.contains("idDeterministe('attendance_entry'"), isTrue);
      expect(code.contains('Uuid()'), isFalse,
          reason: 'Un identifiant tiré au sort fait diverger deux appareils.');
    });

    test('l\'existence se relit dans la base, pas dans un instantané', () {
      final code = _codeSeul(_kProvider);
      expect(
          code.contains(
              'WHERE attendance_record_id = ? AND student_id = ? LIMIT 1'),
          isTrue,
          reason: 'Sans cette relecture, deux appuis rapides insèrent deux '
              'fois et le lot PowerSync entier est jeté (23505).');
    });

    test('« Tout présent » ne réécrit pas un élève déjà pointé', () {
      final code = _codeSeul(_kProvider);
      expect(
          code.contains(
              'SELECT student_id FROM attendance_entries WHERE attendance_record_id = ?'),
          isTrue);
      expect(code.contains('deja.contains(r.studentId)'), isTrue,
          reason: 'La liste passée est un instantané : elle disait encore '
              '« non pointé » pour un élève déclaré absent la seconde d\'avant.');
    });
  });
}
