import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  UNE CLÉ MÉTIER UNIQUE EXIGE UN IDENTIFIANT DÉDUIT, PAS UN TIRAGE AU SORT
//
//  ── LE MÉCANISME, UNE FOIS POUR TOUTES ─────────────────────────────────────
//  Quand la base tient une contrainte `UNIQUE` sur des colonnes MÉTIER (et non
//  sur `id`), deux INSERT décrivant le même fait se font refuser en 23505. Ce
//  code figure dans `_fatalResponseCodes` du connecteur PowerSync : il ne
//  rejette pas la ligne fautive, il appelle `transaction.complete()` et JETTE
//  LE LOT ENTIER en attente. L'appel du matin, les paiements du guichet et les
//  notes saisies dans la même heure partent ensemble, sans un message.
//
//  Deux INSERT pour un même fait, ce n'est pas un cas tordu :
//    • deux appuis rapides avant que le flux n'ait rafraîchi — saisir 12, se
//      reprendre et saisir 14 dans la seconde, sur une grille de notes ;
//    • deux appareils hors ligne qui font le même geste, ce que l'offline-first
//      rend NORMAL : le professeur principal et le surveillant, la même classe.
//
//  ── LE REMÈDE ──────────────────────────────────────────────────────────────
//  L'identifiant se DÉDUIT de la clé métier (`idDeterministe`, UUID v5) : deux
//  postes calculent le même `id`, le connecteur fait deux upserts sur la même
//  ligne, et il ne reste qu'un fait. Là où l'identité ne peut pas se déduire —
//  un matricule, un slug — la ligne se relit d'abord dans la base LOCALE, où
//  toutes les écritures sont sérialisées.
//
//  ── HISTOIRE ───────────────────────────────────────────────────────────────
//  Le défaut a été trouvé trois fois : sur `attendance_*` (2026-08-26), puis
//  sur `canteen_records`, `grades`, `bulletins`, `payroll`, `class_enrollments`
//  et la chaîne de reconduction (2026-08-28). Trois découvertes séparées pour
//  un seul mécanisme : d'où ce garde, qui tient la liste COMPLÈTE des
//  contraintes d'unicité métier relevées en production, et le point d'écriture
//  qui doit les respecter.
//
//  ⚠️ DEUX FAMILLES, ET LA SECONDE M'AVAIT ÉCHAPPÉ. Un premier relevé n'avait
//  interrogé que `pg_constraint` (contype = 'u'). Les index uniques PARTIELS
//  (`CREATE UNIQUE INDEX … WHERE …`) n'y figurent pas — et c'est l'un d'eux,
//  `uq_library_loans_item_en_cours`, qui interdisait de prêter plus d'un
//  exemplaire d'un ouvrage possédé en cinq. Les deux familles sont ici.
//
//  ⚠️ TROISIÈME FAMILLE : LES CONTRAINTES QUI LÈVENT. `CHECK` et déclencheurs
//  `RAISE` produisent eux aussi un code fatal — 23514 pour un `check_violation`,
//  et `fn_ay_raise` va jusqu'à lever un 42501. Le mécanisme est le même : le lot
//  entier part. Relevé du 2026-08-28 sur la base de production : 16 déclencheurs
//  qui lèvent, dont TROIS seulement sur le chemin hors ligne (les autres ne sont
//  écrits que par l'espace admin groupe, en ligne, où un refus est une erreur
//  affichée à l'agent) ; et 16 contraintes `CHECK` sur les tables écrites hors
//  ligne, presque toutes sur des valeurs que l'écran impose par une liste.
//  Les gardes qui restent nécessaires sont assertés dans le dernier groupe.
//
//  ⚠️ AJOUTER UNE CONTRAINTE `UNIQUE` MÉTIER EN BASE, C'EST DEVOIR AJOUTER UNE
//  LIGNE ICI. C'est le prix, et il est petit devant un lot perdu en silence.
// ════════════════════════════════════════════════════════════════════════════

typedef Site = ({String table, String contrainte, String fichier, String garde});

/// Relevé de `pg_constraint` (contype = 'u') sur la base de production le
/// 2026-08-28, croisé avec chaque `INSERT INTO` du dépôt.
const _kSites = <Site>[
  // ── Identifiant déduit de la clé ─────────────────────────────────────────
  (
    table: 'attendance_records',
    contrainte: 'class_id, record_date, period, subject_id',
    fichier: 'features/vie_scolaire/providers/presences_provider.dart',
    garde: "idDeterministe('attendance_record'",
  ),
  (
    table: 'attendance_entries',
    contrainte: 'attendance_record_id, student_id',
    fichier: 'features/vie_scolaire/providers/presences_provider.dart',
    garde: "idDeterministe('attendance_entry'",
  ),
  (
    table: 'canteen_records',
    contrainte: 'student_id, record_date, meal_type',
    fichier: 'features/vie_scolaire/providers/cantine_provider.dart',
    garde: "idDeterministe('canteen_record'",
  ),
  (
    table: 'grades',
    contrainte: 'evaluation_id, student_id',
    fichier: 'features/evaluation/providers/eval_grades_provider.dart',
    garde: "idDeterministe('grade'",
  ),
  (
    table: 'bulletins',
    contrainte: 'student_id, trimester_id',
    fichier: 'features/evaluation/providers/bulletins_provider.dart',
    garde: "idDeterministe('bulletin',",
  ),
  (
    table: 'bulletin_subject_lines',
    contrainte: 'bulletin_id, subject_id',
    fichier: 'features/evaluation/providers/bulletins_provider.dart',
    garde: "idDeterministe('bulletin_subject_line'",
  ),
  (
    table: 'payroll',
    contrainte: 'staff_id, period_month, period_year',
    fichier: 'features/staff/providers/payroll_provider.dart',
    garde: "idDeterministe('payroll'",
  ),
  (
    table: 'class_enrollments',
    contrainte: 'student_id, academic_year_id',
    fichier: 'features/classes/providers/class_provider.dart',
    garde: "idDeterministe('class_enrollment'",
  ),
  (
    table: 'class_enrollments',
    contrainte: 'student_id, academic_year_id',
    fichier: 'features/evaluation/providers/passage_provider.dart',
    garde: "idDeterministe('class_enrollment'",
  ),
  (
    table: 'class_enrollments',
    contrainte: 'student_id, academic_year_id',
    fichier: 'features/evaluation/providers/cloture_examen_provider.dart',
    garde: "idDeterministe('class_enrollment'",
  ),
  // ── La chaîne de reconduction : classe → coefficients → professeurs ──────
  // Rendre la CLASSE déterministe déplace la collision d'un cran si on s'y
  // arrête : deux postes produisent alors la MÊME classe, donc la même clé
  // `(class_id, subject_id)`. Les trois maillons bougent ensemble.
  (
    table: 'classes',
    contrainte: 'school_id, academic_year_id, name',
    fichier: 'features/classes/providers/class_provider.dart',
    garde: "idDeterministe('class',",
  ),
  (
    table: 'classes',
    contrainte: 'school_id, academic_year_id, name',
    fichier: 'features/structure/providers/academic_year_provider.dart',
    garde: "idDeterministe('class',",
  ),
  (
    table: 'classes',
    contrainte: 'school_id, academic_year_id, name',
    fichier: 'features/structure/providers/class_rollover.dart',
    garde: "idDeterministe('class',",
  ),
  (
    table: 'class_subjects',
    contrainte: 'class_id, subject_id',
    fichier: 'features/structure/providers/class_subjects_provider.dart',
    garde: "idDeterministe('class_subject'",
  ),
  (
    table: 'class_subjects',
    contrainte: 'class_id, subject_id',
    fichier: 'features/structure/providers/class_rollover.dart',
    garde: "idDeterministe('class_subject'",
  ),
  (
    table: 'teacher_subjects',
    contrainte: 'staff_id, subject_id, class_id, academic_year_id',
    fichier: 'features/structure/providers/class_subjects_provider.dart',
    garde: "idDeterministe('teacher_subject'",
  ),
  // ── Identité non déductible : relecture de la base LOCALE avant d'écrire ──
  (
    table: 'announcement_reactions',
    contrainte: 'announcement_id, user_id',
    fichier: 'features/communication/providers/'
        'announcement_interactions_provider.dart',
    garde: 'FROM announcement_reactions WHERE announcement_id = ? '
        'AND user_id = ?',
  ),
  (
    table: 'exam_candidates',
    contrainte: 'session_id, student_id',
    fichier: 'features/examens/providers/exam_registration_provider.dart',
    garde: 'SELECT student_id FROM exam_candidates ',
  ),
  (
    table: 'staff_attendance',
    contrainte: 'staff_id, record_date',
    fichier: 'features/staff/providers/staff_attendance_provider.dart',
    garde: 'SELECT id FROM staff_attendance WHERE school_id = ? '
        'AND staff_id = ?',
  ),
  (
    table: 'students',
    contrainte: 'group_id, matricule',
    fichier: 'features/students/providers/students_provider.dart',
    garde: '_matriculeLibre(',
  ),
  (
    table: 'subjects',
    contrainte: 'group_id, level_id, slug',
    fichier: 'features/structure/providers/subjects_provider.dart',
    garde: '_uniqueSlug(',
  ),
  // `conversation_members` porte `UNIQUE (conversation_id, user_id)`, mais ses
  // lignes ne s'écrivent QU'APRÈS la création d'une conversation neuve, dont
  // l'identifiant est tiré au sort : deux postes créant le même salon
  // produisent deux conversations distinctes, donc deux clés distinctes. Rien
  // à déduire — mais il fallait le vérifier pour pouvoir l'écrire.
  (
    table: 'conversation_members',
    contrainte: 'conversation_id, user_id',
    fichier: 'features/communication/providers/group_chat_provider.dart',
    garde: 'INSERT INTO conversations',
  ),
];

/// ── INDEX UNIQUES PARTIELS (`CREATE UNIQUE INDEX … WHERE …`) ───────────────
/// Relevé de `pg_indexes` le 2026-08-28. Seuls figurent ici ceux qu'un chemin
/// OFFLINE écrit : sur le chemin en ligne d'admin groupe (`supabase.from`), un
/// 23505 est une erreur affichée à l'agent, pas un lot d'écritures perdu.
/// Écartés à ce titre, après vérification : `uq_ay_current_*`,
/// `staff_affectations_courante_key`, `school_levels_ecole_niveau_uniq`,
/// `schools_dec_code_uniq`, `education_*_code_global_ux`,
/// `exam_official_results_uniq`, et les quatre `uniq_fee_structure_*`.
const _kIndexPartiels = <Site>[
  (
    table: 'library_loans',
    contrainte: 'item_id, borrower_id WHERE return_date IS NULL',
    fichier: 'features/vie_scolaire/providers/biblio_provider.dart',
    garde: 'SELECT id FROM library_loans ',
  ),
  (
    table: 'class_enrollments',
    contrainte: "student_id, academic_year_id WHERE status = 'active'",
    fichier: 'features/classes/providers/class_provider.dart',
    garde: "idDeterministe('class_enrollment'",
  ),
  (
    table: 'student_payments',
    contrainte: 'school_id, receipt_number WHERE receipt_number IS NOT NULL',
    fichier: 'features/finance/providers/paiements_provider.dart',
    garde: 'SELECT receipt_number FROM student_payments ',
  ),
  (
    table: 'students',
    contrainte: 'ine, school_id WHERE ine IS NOT NULL',
    fichier: 'features/students/providers/students_provider.dart',
    garde: 'SELECT id FROM students WHERE school_id = ? AND ine = ?',
  ),
  (
    table: 'academic_years',
    contrainte: 'group_id / school_id WHERE is_current',
    fichier: 'features/structure/providers/academic_year_provider.dart',
    garde: 'uq_ay_current_group',
  ),
];

List<File> _dartsSous(String chemin) => Directory(chemin)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList()
  ..sort((a, b) => a.path.compareTo(b.path));

String _relatif(File f) {
  final c = f.path.replaceAll(r'\', '/');
  return c.substring(c.indexOf('lib/') + 4);
}

void main() {
  test('chaque écriture sur une clé métier unique porte son garde', () {
    final fautes = <String>[];
    for (final s in [..._kSites, ..._kIndexPartiels]) {
      final f = File('lib/${s.fichier}');
      if (!f.existsSync()) {
        fautes.add('${s.fichier} : fichier introuvable (déplacé ? renommé ?)');
        continue;
      }
      if (!f.readAsStringSync().contains(s.garde)) {
        fautes.add('${s.table} (UNIQUE ${s.contrainte})\n'
            '    ${s.fichier}\n'
            '    garde attendu : ${s.garde}');
      }
    }
    expect(fautes, isEmpty,
        reason: 'Sans ce garde, deux écritures du même fait — deux appuis, ou '
            'deux appareils hors ligne — se font refuser en 23505 : code '
            'FATAL, le lot PowerSync entier est jeté.\n\n'
            '${fautes.join('\n\n')}');
  });

  test('aucune écriture NON RECENSÉE sur une table à clé métier unique', () {
    // Le garde ci-dessus vérifie les points d'écriture connus. Celui-ci
    // attrape le suivant : un second chemin d'insertion ouvert ailleurs, qui
    // n'aurait aucune raison de connaître la contrainte.
    // Les tables des index partiels dont la clé pleine n'est pas déjà listée.
    final tables = {
      for (final s in _kSites) s.table,
      'library_loans',
      'student_payments',
    };
    final connus = <String>{
      for (final s in [..._kSites, ..._kIndexPartiels]) '${s.table}|${s.fichier}'
    };
    final motif = RegExp(r'INSERT\s+INTO\s+([a-z_0-9]+)', caseSensitive: false);
    final fautes = <String>[];
    for (final f in _dartsSous('lib')) {
      final rel = _relatif(f);
      for (final m in motif.allMatches(f.readAsStringSync())) {
        final t = m.group(1)!;
        if (!tables.contains(t)) continue;
        if (connus.contains('$t|$rel')) continue;
        fautes.add('$t ← $rel');
      }
    }
    expect(fautes.toSet().toList(), isEmpty,
        reason: 'Nouveau point d\'écriture sur une table à contrainte '
            'd\'unicité métier. Lui donner son garde, puis l\'inscrire dans '
            '`_kSites` — la liste est le seul endroit où cette connaissance '
            'existe côté application.\n\n${fautes.toSet().join('\n')}');
  });

  test('le tirage au sort a disparu des fichiers concernés', () {
    // `_uuid.v4()` n'est pas fautif en soi — deux incidents disciplinaires le
    // même jour sont deux incidents. Il l'est dans ces fichiers-là, où chaque
    // insertion porte une clé métier unique.
    const sansHasard = <String>[
      'features/vie_scolaire/providers/cantine_provider.dart',
      'features/evaluation/providers/eval_grades_provider.dart',
      'features/evaluation/providers/bulletins_provider.dart',
      'features/structure/providers/class_rollover.dart',
      'features/structure/providers/class_subjects_provider.dart',
    ];
    final fautes = <String>[];
    for (final p in sansHasard) {
      if (File('lib/$p').readAsStringSync().contains('.v4()')) fautes.add(p);
    }
    expect(fautes, isEmpty,
        reason: 'Toutes les lignes de ces fichiers portent une clé métier '
            'unique : aucun identifiant ne doit s\'y tirer au '
            'sort.\n\n${fautes.join('\n')}');
  });

  // ══════════════════════════════════════════════════════════════════════════
  //  LES CONTRAINTES QUI LÈVENT — CE QUI DOIT LES DEVANCER CÔTÉ ÉCRAN
  //
  //  Une contrainte `CHECK` ou un déclencheur `RAISE` coûtent le lot entier,
  //  exactement comme un doublon de clé. La différence : ils se déclenchent sur
  //  une saisie ORDINAIRE — un enfant de plus que le quota, des vacances hors
  //  de l'année, une année archivée. L'écran doit donc le dire AVANT.
  // ══════════════════════════════════════════════════════════════════════════
  group('Ce qui lèverait un 23xxx se dit d\'abord à l\'écran', () {
    test('le quota d\'élèves se vérifie avant la création', () {
      // `fn_enforce_student_quota` lève un `check_violation` (23514) BEFORE
      // INSERT ON students : inscrire un enfant de trop jetterait le lot.
      final prov = File('lib/features/students/providers/students_provider.dart')
          .readAsStringSync();
      expect(prov.contains('checkStudentQuota'), isTrue);
      final ecran =
          File('lib/features/students/screens/add_inscription_screen.dart')
              .readAsStringSync();
      expect(ecran.contains('await checkStudentQuota('), isTrue,
          reason: 'Le garde doit être APPELÉ, pas seulement défini.');
    });

    test('« absent » efface la note, comme l\'exige `chk_score_or_absent`', () {
      // CHECK ((is_absent AND score IS NULL) OR (NOT is_absent AND score IS
      // NOT NULL)) : garder 12 en cochant « absent » lèverait un 23514.
      final src = File('lib/features/evaluation/screens/notes_grades.dart')
          .readAsStringSync();
      expect(src.contains('score: isAbsent ? null : score'), isTrue);
    });

    test('le calendrier ferme quand il ne connaît pas l\'année', () {
      // `fn_check_holiday_period` refuse une vacance hors des bornes de
      // l'année. Le repli « année ± 1 » du sélecteur ouvrait grand.
      final src = File('lib/features/structure/screens/edt_calendar_tab.dart')
          .readAsStringSync();
      expect(src.contains('final first = year.startDate;'), isTrue,
          reason: 'Les bornes doivent venir de l\'année, jamais d\'un repli.');
      expect(src.contains('year ?? DateTime('), isFalse);
    });

    test('le calendrier tient l\'ordre des dates', () {
      // CHECK (end_date >= start_date).
      final src = File('lib/features/structure/screens/edt_calendar_tab.dart')
          .readAsStringSync();
      expect(src.contains('if (_end == null || _end!.isBefore(picked)) _end = picked;'),
          isTrue);
      expect(src.contains('if (_start == null || _start!.isAfter(picked)) _start = picked;'),
          isTrue);
    });

    test('une année archivée verrouille le calendrier', () {
      // `fn_guard_locked_year` lève un 42501 sur une année verrouillée. Cet
      // onglet était le SEUL écran d'écriture à ne pas lire l'état de l'année.
      final src = File('lib/features/structure/screens/edt_calendar_tab.dart')
          .readAsStringSync();
      expect(src.contains('yearReadOnlyProvider'), isTrue);
      expect(src.contains('&& !readOnly'), isTrue);
    });
  });
}
