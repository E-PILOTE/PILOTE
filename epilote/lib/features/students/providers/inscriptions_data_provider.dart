import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/navigation/providers/permissions_provider.dart';
import '../../../features/structure/providers/academic_year_context.dart';
import '../../../services/powersync/powersync_service.dart';

// Le dossier de l'élève a quitté ce fichier (règle des 500 lignes) mais reste
// servi par lui : une quinzaine d'écrans importent `inscriptions_data_provider`
// pour `studentDossierProvider`. Le ré-export garde leur import valide — la
// coupe est interne, elle n'a pas à se propager.
export 'student_dossier_provider.dart';

// Même coupe, même raison : le BILAN DE L'ANNÉE (effectif, types, redoublants
// et rythme mensuel) interroge toutes les inscriptions, pas seulement celles
// restées au guichet — c'est une autre question posée à la même table, et elle
// pèse deux cents lignes. La page et les tests continuent d'importer ce
// fichier-ci.
export 'inscriptions_rythme_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  DONNÉES DE LA PAGE INSCRIPTIONS — 100% offline (db.watch local), année active.
//  Joint class_enrollments + students + classes ; les KPI/graphes/listes sont
//  dérivés côté client (une école = quelques centaines d'inscrits au plus).
// ════════════════════════════════════════════════════════════════════════════

// ─── Classifieur de cycle (nom de classe → cycle) ────────────────────────────
// Les classes congolaises n'ont pas toujours de level_id renseigné ; le NOM de
// la classe (« 6ème A », « CP1 », « Terminale C ») est le seul lien fiable et
// 100% offline vers le cycle. Les cycles présents reflètent dynamiquement ceux
// de l'école (hérités à sa création). Ordre = ordre pédagogique (préscolaire→FP).
class InscriptionCycle {
  const InscriptionCycle(this.code, this.label, this.order);
  final String code;
  final String label;
  final int order;
}

const _cyclePrescolaire = InscriptionCycle('prescolaire', 'Préscolaire', 1);
const _cyclePrimaire    = InscriptionCycle('primaire', 'Primaire', 2);
const _cycleCollege     = InscriptionCycle('college', 'Collège', 3);
const _cycleLycee       = InscriptionCycle('lycee', 'Lycée', 4);
const _cycleFp          = InscriptionCycle('fp', 'Formation Pro.', 5);
const _cycleAutre       = InscriptionCycle('autre', 'Non classé', 9);

/// Cycle RÉEL d'une classe via son `cycle_code` (dénormalisé depuis
/// classe→niveau→cycle, migration 0010). Repli sur l'heuristique par NOM
/// uniquement si la classe n'est pas encore reliée à un niveau (cycle_code nul).
const _cycleByCode = <String, InscriptionCycle>{
  'prescolaire': _cyclePrescolaire,
  'primaire': _cyclePrimaire,
  'college': _cycleCollege,
  'lycee': _cycleLycee,
  'formation_pro': _cycleFp,
};

InscriptionCycle inscriptionCycleFromCode(String? code, String? fallbackName) {
  final c = _cycleByCode[code];
  return c ?? inscriptionCycleOf(fallbackName);
}

/// Ordre pédagogique d'un cycle par son code normalisé (cf. InscriptionCycle).
/// Sert au tri GLOBAL des niveaux/classes quand l'école a plusieurs cycles
/// (sinon CP1, 6ᵉ et 2ⁿᵈᵉ — tous d'ordre 1 dans leur cycle — s'entremêlent).
const _cycleOrderByCode = <String, int>{
  'prescolaire': 1, 'primaire': 2, 'college': 3, 'lycee': 4, 'fp': 5,
};
int cycleOrderOf(String code) => _cycleOrderByCode[code] ?? 9;

/// Déduit le cycle d'une classe à partir de son nom (conventions Congo).
InscriptionCycle inscriptionCycleOf(String? rawName) {
  final n = (rawName ?? '').toLowerCase().trim();
  if (n.isEmpty) return _cycleAutre;
  // Normalisation : accents → ascii, espaces/tirets retirés.
  final s = n
      .replaceAll(RegExp(r'[éèê]'), 'e')
      .replaceAll(RegExp(r'[àâ]'), 'a')
      .replaceAll(RegExp(r'[\s\-_.]'), '');
  if (s.contains('maternelle') ||
      RegExp(r'^(ps|ms|gs|creche|eveil)').hasMatch(s)) {
    return _cyclePrescolaire;
  }
  if (RegExp(r'(cp[12]?|ce[12]|cm[12])').hasMatch(s)) return _cyclePrimaire;
  if (RegExp(r'^(6|5|4|3)(e|eme|ieme)').hasMatch(s)) return _cycleCollege;
  if (RegExp(r'(2nd|2de|seconde|1er|1re|premiere|tle|tlle|terminale)')
      .hasMatch(s)) {
    return _cycleLycee;
  }
  if (RegExp(r'(cap|bep|bacpro|^bt|^fp)').hasMatch(s)) return _cycleFp;
  return _cycleAutre;
}

// ─── Ligne d'inscription (vue liste/table/cartes) ───────────────────────────
class InscriptionRow {
  const InscriptionRow({
    required this.id,
    required this.studentId,
    required this.firstName,
    required this.lastName,
    required this.matricule,
    required this.ine,
    required this.gender,
    required this.dateOfBirth,
    required this.photoUrl,
    this.placeOfBirth,
    this.nationality,
    required this.classId,
    required this.className,
    required this.capacity,
    required this.cycle,
    required this.levelCode,
    required this.levelOrder,
    required this.filiereLabel,
    required this.inscriptionType,
    required this.status,
    required this.isRepeating,
    required this.enrollmentDate,
    required this.validatedAt,
  });

  final String id;
  final String studentId;
  final String firstName;
  final String lastName;
  final String matricule;

  /// Identifiant national — `null` tant que l'inscription saisie hors ligne
  /// n'a pas été synchronisée.
  final String? ine;
  final String? gender;
  final DateTime? dateOfBirth;
  final String? photoUrl;

  /// Portés pour l'EXPORT, pas pour l'affichage : une liste d'effectifs que
  /// deux écoles s'échangent doit pouvoir être relue par l'import, qui sait
  /// lire ces deux colonnes.
  final String? placeOfBirth, nationality;
  final String? classId;
  final String className;

  /// Âge en années révolues (null si date de naissance inconnue).
  int? get age {
    final d = dateOfBirth;
    if (d == null) return null;
    final now = DateTime.now();
    var a = now.year - d.year;
    if (now.month < d.month || (now.month == d.month && now.day < d.day)) a--;
    return a < 0 || a > 130 ? null : a;
  }
  final int capacity;           // capacité de la classe (0 si non définie)
  final InscriptionCycle cycle;
  final String? levelCode;      // niveau réel (ex. « 6e ») via classe→niveau
  final int levelOrder;         // ordre pédagogique (tri des niveaux)
  final String? filiereLabel;   // filière (lycée/FP) via classe→niveau, NULL sinon
  final String inscriptionType; // new | reinscription | transfer
  final String status;          // active | pending_validation | rejected | …
  final bool isRepeating;
  final DateTime? enrollmentDate;
  final DateTime? validatedAt;

  String get fullName => '$firstName $lastName'.trim();
  String get lastFirst {
    final l = lastName.trim(), f = firstName.trim();
    if (l.isEmpty) return f;
    if (f.isEmpty) return l;
    return '$l $f';
  }

  String get typeLabel => switch (inscriptionType) {
        'new' => 'Nouvelle',
        'reinscription' => 'Réinscription',
        'transfer' => 'Transfert',
        _ => inscriptionType,
      };

  String get statusLabel => switch (status) {
        'active' => 'Validée',
        'pending_validation' => 'En attente',
        'rejected' => 'Rejetée',
        'withdrawn' => 'Retirée',
        'transferred' => 'Transférée',
        'graduated' => 'Diplômée',
        _ => status,
      };
}

/// Toutes les inscriptions de l'année active (tous statuts) + élève + classe.
///
/// ── ⚠️ CE PROVIDER PORTE UN PÉRIMÈTRE ──────────────────────────────────────
/// `inscriptions` est une entrée du profil d'accès comme les autres, et le
/// profil « Enseignant » livré en base la règle sur `own_classes`. Le verrou
/// n'était pourtant posé nulle part ici : un enseignant restreint à ses propres
/// classes lisait TOUT le guichet de l'école — identité, date de naissance,
/// classe et photo de chaque dossier en attente, et par la fiche détail les
/// tuteurs et les frais.
///
/// C'est le même oubli que celui déjà réparé sur le registre des élèves puis
/// sur le graphe d'effectif. Il ne se signalait pas : une requête sans
/// restriction ne lève rien, elle rend simplement plus de lignes.
final inscriptionsDataProvider =
    StreamProvider.autoDispose<List<InscriptionRow>>((ref) {
  ref.keepAlive();
  final schoolId = ref.watch(authNotifierProvider).valueOrNull?.schoolId;
  final yearId = ref.watch(activeYearIdProvider);
  if (schoolId == null || schoolId.isEmpty || yearId == null) {
    return Stream.value(const []);
  }
  // Tant que le profil d'accès n'est pas lu, on ne PUBLIE rien : la page garde
  // son squelette. Émettre la liste complète, même une demi-seconde, c'est
  // l'avoir affichée.
  if (!permissionsLoaded(ref)) return const Stream.empty();
  final scope = classScopeClause(ref, 'inscriptions', column: 'ce.class_id');

  return db
      .watch(
        '''$_kInscriptionSelect
        WHERE  ce.school_id = ? AND ce.academic_year_id = ?
        AND    ce.status != 'active'
        ${scope?.clause ?? ''}
        ORDER  BY s.last_name, s.first_name
        ''',
        parameters: [schoolId, yearId, ...?scope?.params],
      )
      .map((rows) => [for (final r in rows) inscriptionRowFrom(r)]);
});

/// Les colonnes que [inscriptionRowFrom] attend — partagées par la vue liste et
/// par la lecture d'UN dossier, pour que les deux ne puissent pas diverger.
const _kInscriptionSelect = '''
        SELECT ce.id, ce.student_id, ce.status, ce.inscription_type,
               ce.is_repeating, ce.enrollment_date, ce.validated_at,
               s.first_name, s.last_name, s.matricule, s.ine, s.gender,
               s.date_of_birth, s.photo_url,
               s.place_of_birth, s.nationality,
               c.id AS class_id, c.name AS class_name, c.capacity AS capacity,
               c.cycle_code AS cycle_code, c.level_code AS level_code,
               c.level_order AS level_order, c.filiere_label AS filiere_label
        FROM   class_enrollments ce
        JOIN   students s ON s.id = ce.student_id
        LEFT JOIN classes c ON c.id = ce.class_id
''';

/// Une ligne SQL → une ligne d'écran.
InscriptionRow inscriptionRowFrom(Map<String, dynamic> r) => InscriptionRow(
      id: r['id'] as String,
      studentId: r['student_id'] as String,
      firstName: r['first_name'] as String? ?? '',
      lastName: r['last_name'] as String? ?? '',
      matricule: r['matricule'] as String? ?? '',
      ine: r['ine'] as String?,
      gender: r['gender'] as String?,
      dateOfBirth: _d(r['date_of_birth']),
      photoUrl: r['photo_url'] as String?,
      placeOfBirth: r['place_of_birth'] as String?,
      nationality: r['nationality'] as String?,
      classId: r['class_id'] as String?,
      className: r['class_name'] as String? ?? '—',
      capacity: (r['capacity'] as int?) ?? 0,
      cycle: inscriptionCycleFromCode(
          r['cycle_code'] as String?, r['class_name'] as String?),
      levelCode: r['level_code'] as String?,
      levelOrder: (r['level_order'] as int?) ?? 999,
      filiereLabel: (r['filiere_label'] as String?)?.trim().isEmpty ?? true
          ? null
          : (r['filiere_label'] as String).trim(),
      inscriptionType: r['inscription_type'] as String? ?? 'new',
      status: r['status'] as String? ?? 'active',
      isRepeating: r['is_repeating'] == 1 || r['is_repeating'] == true,
      enrollmentDate: _d(r['enrollment_date']),
      validatedAt: _d(r['validated_at']),
    );

/// UN dossier, lu directement par son identifiant.
///
/// ⚠️ Ne PAS passer par [inscriptionsDataProvider] pour retrouver une ligne
/// qu'on vient d'écrire : c'est un flux, et sa première émission peut précéder
/// l'écriture. Au sortir de l'assistant, la fiche se serait imprimée sur un
/// dossier introuvable — une fois sur cinq, et jamais sur le poste du
/// développeur. La lecture directe n'a pas cette course.
///
/// Sans filtre de statut non plus : cette lecture sert notamment à imprimer la
/// fiche d'un dossier VALIDÉ, que la vue liste écarte.
final inscriptionRowProvider = FutureProvider.autoDispose
    .family<InscriptionRow?, String>((ref, enrollmentId) async {
  final r = await db.getOptional(
      '$_kInscriptionSelect WHERE ce.id = ?', [enrollmentId]);
  return r == null ? null : inscriptionRowFrom(r);
});

DateTime? _d(Object? v) =>
    (v is String && v.isNotEmpty) ? DateTime.tryParse(v) : null;


// ─── Structure académique RÉELLE de l'école (cycles / niveaux / classes) ─────
// Dérivée 100% offline de la table `classes` (déjà synchronisée). Une classe
// porte son cycle (`cycle_code`), son niveau (`level_code`/`level_order`) et sa
// filière (`filiere_label`). On peut inscrire un élève UNIQUEMENT dans une
// classe : la structure pertinente pour les inscriptions = les classes qui
// existent. Dès que la direction crée une classe (ex. une 2nde au Lycée), son
// cycle / niveau / classe apparaît automatiquement — sans dépendre d'un
// déploiement des sync-rules. Inclut les classes VIDES (0 inscrit).
class SchoolLevelDef {
  const SchoolLevelDef(this.code, this.cycleCode, this.order);
  final String code, cycleCode;
  final int order;
}

class SchoolClassDef {
  const SchoolClassDef(this.name, this.cycleCode, this.levelCode,
      this.levelOrder, this.capacity, this.filiere);
  final String name, cycleCode;
  final String? levelCode, filiere;
  final int levelOrder, capacity;
}

class SchoolStructure {
  const SchoolStructure(this.cycles, this.levels, this.classes);
  final List<InscriptionCycle> cycles;
  final List<SchoolLevelDef> levels;
  final List<SchoolClassDef> classes;
  static const empty = SchoolStructure([], [], []);
}

final schoolStructureProvider =
    StreamProvider.autoDispose<SchoolStructure>((ref) {
  ref.keepAlive();
  final schoolId = ref.watch(authNotifierProvider).valueOrNull?.schoolId;
  final yearId = ref.watch(activeYearIdProvider);
  if (schoolId == null || schoolId.isEmpty || yearId == null) {
    return Stream.value(SchoolStructure.empty);
  }
  // Scopé à l'ANNÉE ACTIVE (comme les inscriptions) : les classes d'une autre
  // année n'apparaissent pas. Dynamique aussi au changement d'école/groupe
  // (schoolId) et d'année (yearId).
  return db
      .watch(
    '''
    SELECT name, cycle_code, level_code, level_order, capacity, filiere_label
    FROM   classes
    WHERE  school_id = ? AND academic_year_id = ?
      AND  COALESCE(is_active, 1) <> 0
    ORDER  BY level_order, name
    ''',
    parameters: [schoolId, yearId],
  )
      .map((rows) {
    final cyclesByCode = <String, InscriptionCycle>{};
    final levels = <SchoolLevelDef>[];
    final seenLevel = <String>{};
    final classes = <SchoolClassDef>[];
    for (final r in rows) {
      final cyc = inscriptionCycleFromCode(
          r['cycle_code'] as String?, r['name'] as String?);
      cyclesByCode.putIfAbsent(cyc.code, () => cyc);
      final lc = r['level_code'] as String?;
      final lo = (r['level_order'] as int?) ?? 999;
      if (lc != null && lc.isNotEmpty && seenLevel.add('${cyc.code}/$lc')) {
        levels.add(SchoolLevelDef(lc, cyc.code, lo));
      }
      final fl = (r['filiere_label'] as String?)?.trim();
      classes.add(SchoolClassDef(
        r['name'] as String? ?? '—',
        cyc.code,
        (lc == null || lc.isEmpty) ? null : lc,
        lo,
        (r['capacity'] as int?) ?? 0,
        (fl == null || fl.isEmpty) ? null : fl,
      ));
    }
    final cycles = cyclesByCode.values.toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    levels.sort((a, b) {
      final c = cycleOrderOf(a.cycleCode).compareTo(cycleOrderOf(b.cycleCode));
      return c != 0 ? c : a.order.compareTo(b.order);
    });
    return SchoolStructure(cycles, levels, classes);
  });
});


// ════════════════════════════════════════════════════════════════════════════
//  LES CHIFFRES DU GUICHET — et rien d'autre.
//
//  ── CE QUI A ÉTÉ RETIRÉ, ET POURQUOI ───────────────────────────────────────
//  Ce provider produisait quinze agrégats : répartition par cycle, par niveau,
//  par classe, par filière, par sexe, capacité totale, taux de remplissage,
//  compteurs par type. La page n'en lisait plus que quatre depuis sa refonte —
//  les onze autres se recalculaient à chaque reconstruction pour personne.
//
//  Deux d'entre eux étaient pires qu'inutiles : `active` ne POUVAIT PAS être
//  différent de zéro, puisque la requête amont écarte précisément ce statut, et
//  `fillRatio` en dérivait — il aurait affiché un taux de remplissage proche de
//  0 % pour une école pleine. Invisible tant que rien ne les lisait, armé pour
//  le premier qui rebrancherait la carte.
//
//  Ce qui reste ici décrit le GUICHET, et le dit : les dossiers à traiter. Les
//  chiffres de l'ANNÉE — effectif, types, redoublants, rythme — vivent dans
//  `yearInscriptionTotalsProvider`, qui interroge toutes les inscriptions.
//  Deux sources, deux questions, aucune ambiguïté.
// ════════════════════════════════════════════════════════════════════════════
class InscriptionStats {
  const InscriptionStats({
    this.pending = 0,
    this.rejected = 0,
    this.filieres = const [],
  });

  /// Dossiers en attente de validation.
  final int pending;

  /// Dossiers refusés, encore visibles au guichet.
  final int rejected;

  /// Filières OFFERTES par l'école, triées. Vient de la STRUCTURE, pas des
  /// inscriptions : le filtre doit exister dès qu'un établissement technique a
  /// créé ses classes, même avant d'avoir inscrit le premier élève.
  final List<String> filieres;

  int get aTraiter => pending + rejected;
}

/// Les compteurs du guichet, dérivés du pipeline déjà chargé.
final inscriptionStatsProvider = Provider.autoDispose<InscriptionStats>((ref) {
  final rows = ref.watch(inscriptionsDataProvider).valueOrNull ?? const [];
  final structure =
      ref.watch(schoolStructureProvider).valueOrNull ?? SchoolStructure.empty;

  var pending = 0, rejected = 0;
  for (final r in rows) {
    switch (r.status) {
      case 'pending_validation':
        pending++;
      case 'rejected':
        rejected++;
    }
  }

  final filieres = <String>{
    for (final c in structure.classes)
      if (c.filiere != null && c.filiere!.isNotEmpty) c.filiere!,
  }.toList()
    ..sort();

  return InscriptionStats(
    pending: pending,
    rejected: rejected,
    filieres: filieres,
  );
});
