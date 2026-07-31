import 'package:uuid/uuid.dart';

import '../../../services/powersync/powersync_service.dart';

// ════════════════════════════════════════════════════════════════════════════
//  RECONDUIRE LES CLASSES VERS L'ANNÉE SUIVANTE.
//
//  ── POURQUOI CE GESTE EXISTE ───────────────────────────────────────────────
//  Les classes portent `academic_year_id` : la 6ème A de 2025-2026 et celle de
//  2026-2027 sont deux lignes distinctes. Tant que la seconde n'existe pas, le
//  conseil peut décider qu'un élève passe — mais il n'y a nulle part où
//  l'inscrire. La reconduction est donc le préalable matériel de la
//  réinscription.
//
//  On recopie la STRUCTURE, jamais les gens :
//    • le nom, le niveau, le cycle, la filière, la capacité, la salle ;
//    • le programme de la classe (`class_subjects`) avec ses coefficients,
//      sinon la classe d'accueil ne pourrait recevoir aucune note ;
//    • PAS le professeur principal — cette responsabilité se désigne chaque
//      année. La recopier attribuerait en silence une charge que personne n'a
//      confiée.
//
//  ── ⚠️ PAS LE CALENDRIER, ET SURTOUT PAS ICI ───────────────────────────────
//  Le découpage de l'année en trimestres appartient au GROUPE, pas à l'école :
//  la politique RLS `trimesters_write_ministry` n'ouvre l'écriture qu'à
//  `admin_groupe`. Une reconduction qui tenterait de créer les trimestres se
//  ferait refuser (42501) — et comme PowerSync abandonne le LOT ENTIER sur un
//  code fatal, elle emporterait avec elle les seize classes et tous leurs
//  programmes, sans que rien n'ait été enregistré. Vérifié à l'exécution :
//  « new row violates row-level security policy for table "trimesters" », toute
//  la reconduction perdue.
//
//  L'école ne peut donc que CONSTATER l'absence de trimestres et la signaler ;
//  c'est le groupe qui ouvre l'année (écran « Années scolaires »).
//
//  `exam_id` / `exam_status` ne sont pas recopiés non plus : un trigger les
//  DÉRIVE à l'insertion depuis les règles d'éligibilité. Les écrire à la main
//  ferait diverger la classe du référentiel ministériel.
//
//  ── IDEMPOTENT ─────────────────────────────────────────────────────────────
//  Relancer ne duplique rien : une classe de même nom déjà présente dans
//  l'année cible est ignorée. Un secrétariat qui clique deux fois ne doit pas
//  se retrouver avec deux « 6ème A ».
// ════════════════════════════════════════════════════════════════════════════

const _uuid = Uuid();

class RolloverResult {
  const RolloverResult({required this.created, required this.skipped});
  final int created, skipped;
}

/// Recopie la structure de classes de [fromYearId] vers [toYearId].
///
/// [groupId] et [schoolId] sont exigés : une classe sans rattachement est
/// refusée au serveur, et PowerSync abandonne alors le LOT ENTIER — toute la
/// reconduction disparaîtrait sans message.
Future<RolloverResult> rolloverClasses({
  required String fromYearId,
  required String toYearId,
  required String groupId,
  required String schoolId,
}) async {
  final source = await db.getAll(
    'SELECT id, name, level_id, capacity, room, cycle_code, level_code, '
    '       level_order, filiere_code, filiere_label, exam_override_id, '
    '       exam_excluded '
    '  FROM classes WHERE school_id = ? AND academic_year_id = ? '
    '   AND is_active = 1 ORDER BY level_order, name',
    [schoolId, fromYearId],
  );
  if (source.isEmpty) return const RolloverResult(created: 0, skipped: 0);

  final existing = await db.getAll(
    'SELECT name FROM classes WHERE school_id = ? AND academic_year_id = ?',
    [schoolId, toYearId],
  );
  final taken = {for (final r in existing) (r['name'] as String? ?? '').trim()};

  final now = DateTime.now().toIso8601String();
  var created = 0, skipped = 0;

  await db.writeTransaction((tx) async {
    for (final c in source) {
      final name = (c['name'] as String? ?? '').trim();
      if (name.isEmpty || taken.contains(name)) {
        skipped++;
        continue;
      }
      final newId = _uuid.v4();
      await tx.execute(
        'INSERT INTO classes (id, group_id, school_id, academic_year_id, '
        '  level_id, name, capacity, room, is_active, cycle_code, level_code, '
        '  level_order, filiere_code, filiere_label, exam_override_id, '
        '  exam_excluded, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          newId,
          groupId,
          schoolId,
          toYearId,
          c['level_id'],
          name,
          c['capacity'] ?? 45,
          c['room'],
          c['cycle_code'],
          c['level_code'],
          c['level_order'],
          c['filiere_code'],
          c['filiere_label'],
          c['exam_override_id'],
          c['exam_excluded'] ?? 0,
          now,
          now,
        ],
      );

      final subjects = await tx.getAll(
        'SELECT subject_id, coefficient, weekly_hours FROM class_subjects '
        'WHERE class_id = ?',
        [c['id']],
      );
      for (final s in subjects) {
        await tx.execute(
          'INSERT INTO class_subjects (id, group_id, school_id, class_id, '
          '  subject_id, coefficient, weekly_hours, created_at, updated_at) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            _uuid.v4(),
            groupId,
            schoolId,
            newId,
            s['subject_id'],
            s['coefficient'],
            s['weekly_hours'],
            now,
            now,
          ],
        );
      }
      created++;
      taken.add(name);
    }
  });

  return RolloverResult(created: created, skipped: skipped);
}
