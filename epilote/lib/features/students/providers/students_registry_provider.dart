import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../navigation/providers/permissions_provider.dart';
import '../../structure/providers/academic_year_context.dart';
import 'inscriptions_rythme_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  REGISTRE DES ÉLÈVES (la PERSONNE, pas l'inscription) — l'effectif ACTIF de
//  l'année en cours : chaque élève est joint à son inscription active, avec sa
//  classe. Un dossier « en attente de validation », retiré ou transféré n'y
//  figure pas ; il vit dans la page Inscriptions. Offline-first (db.watch).
//
//  ── ⚠️ CE PROVIDER PORTE UN PÉRIMÈTRE ──────────────────────────────────────
//  Il alimente TROIS pages — Élèves, Dossiers documentaires et surtout
//  l'Annuaire des familles (noms, téléphones, adresses des tuteurs). Il n'avait
//  aucun filtre : un enseignant dont le profil d'accès dit `own_classes` y
//  voyait l'école entière, coordonnées des parents comprises, alors que la même
//  restriction était correctement appliquée par `studentsProvider`. Le verrou
//  n'était pas contourné — il n'avait jamais été posé ici.
//
//  D'où le paramètre : le périmètre se règle PAR MODULE (`eleves`, `documents`,
//  `annuaire` sont trois entrées distinctes du profil d'accès), donc l'appelant
//  déclare sous quel module il lit. Passer le mauvais slug, c'est appliquer les
//  droits d'une autre page.
// ════════════════════════════════════════════════════════════════════════════
class StudentRow {
  const StudentRow({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.matricule,
    required this.ine,
    required this.gender,
    required this.dateOfBirth,
    required this.placeOfBirth,
    required this.nationality,
    required this.photoUrl,
    required this.isBoarder,
    required this.hasScholarship,
    required this.hasSocialAid,
    required this.isAffecte,
    required this.enrollmentId,
    required this.enrollmentStatus,
    required this.classId,
    required this.className,
    required this.cycleCode,
    required this.levelCode,
    required this.levelOrder,
    required this.filiereLabel,
    required this.hasPrimaryTutor,
  });

  final String id, firstName, lastName, matricule;

  /// Identifiant national — `null` tant qu'une inscription saisie hors
  /// ligne n'a pas été synchronisée (le serveur seul l'attribue).
  final String? ine;
  final String? gender;
  final DateTime? dateOfBirth;

  /// Portés pour l'export : sans eux, le CSV produit ici ne pouvait pas être
  /// relu par l'import de la page Inscriptions.
  final String? placeOfBirth, nationality;

  final String? photoUrl;
  final bool isBoarder, hasScholarship, hasSocialAid, isAffecte;

  // Inscription de l'année active (null si non inscrit).
  final String? enrollmentId, enrollmentStatus, classId, className;
  final String? cycleCode, levelCode, filiereLabel;
  final int levelOrder;

  /// Au moins un tuteur porte le titre de contact principal.
  ///
  /// ⚠️ Ce n'est PAS « l'élève a un tuteur ». La case « contact principal » se
  /// décochait librement dans l'éditeur du registre : des dossiers portent donc
  /// plusieurs numéros et aucun principal. `primaryTutorProvider` fait
  /// `LIMIT 1` sur `is_primary_contact = 1` et ne rend alors RIEN — l'école a
  /// des numéros, mais plus aucun ne se présente comme celui qu'on compose.
  /// La saisie est corrigée ; l'existant, lui, se compte.
  final bool hasPrimaryTutor;

  String get fullName => '$firstName $lastName'.trim();
  String get lastFirst {
    final l = lastName.trim(), f = firstName.trim();
    if (l.isEmpty) return f;
    if (f.isEmpty) return l;
    return '$l $f';
  }

  /// L'élève porte-t-il au moins un statut particulier ?
  bool get hasParticularite =>
      isBoarder || isAffecte || hasScholarship || hasSocialAid;

  int? get age {
    final d = dateOfBirth;
    if (d == null) return null;
    final now = DateTime.now();
    var a = now.year - d.year;
    if (now.month < d.month || (now.month == d.month && now.day < d.day)) a--;
    return a < 0 || a > 130 ? null : a;
  }
}

DateTime? _d(Object? v) =>
    (v is String && v.isNotEmpty) ? DateTime.tryParse(v) : null;
bool _b(Object? v) => v == 1 || v == true;
String? _t(Object? v) {
  final s = (v as String?)?.trim();
  return (s == null || s.isEmpty) ? null : s;
}

/// Effectif actif de l'école pour le module [slug] (`eleves`, `documents`,
/// `annuaire`), restreint aux classes du membre si son profil dit
/// `own_classes`.
final studentsRegistryProvider =
    StreamProvider.autoDispose.family<List<StudentRow>, String>((ref, slug) {
  ref.keepAlive();
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final schoolId = profile?.schoolId;
  final yearId = ref.watch(activeYearIdProvider);
  if (schoolId == null || schoolId.isEmpty) return Stream.value(const []);
  // Tant que le profil d'accès n'est pas lu, on ne PUBLIE rien : la page garde
  // son squelette de chargement. Émettre une liste vide afficherait « aucun
  // élève » à une école qui en a huit cents ; émettre la liste complète
  // montrerait à un enseignant restreint ce qu'il n'a pas à voir.
  if (!permissionsLoaded(ref)) return const Stream.empty();
  final scope = classScopeClause(ref, slug, column: 'ce.class_id');

  return db
      .watch(
        '''
        SELECT s.id, s.first_name, s.last_name, s.matricule, s.ine, s.gender,
               s.date_of_birth, s.place_of_birth, s.nationality,
               s.photo_url, s.is_boarder, s.has_scholarship,
               s.has_social_aid, s.is_affecte,
               ce.id            AS enrollment_id,
               ce.status        AS enrollment_status,
               ce.class_id      AS class_id,
               c.name           AS class_name,
               c.cycle_code     AS cycle_code,
               c.level_code     AS level_code,
               c.level_order    AS level_order,
               c.filiere_label  AS filiere_label,
               EXISTS(SELECT 1 FROM student_tutors t
                      WHERE t.student_id = s.id
                        AND COALESCE(t.is_primary_contact, 0) <> 0)
                                AS has_primary_tutor
        FROM   students s
        JOIN   class_enrollments ce
               ON ce.student_id = s.id
              AND ce.academic_year_id = ?
              AND ce.status = 'active'
        LEFT JOIN classes c ON c.id = ce.class_id
        WHERE  s.school_id = ? AND COALESCE(s.is_active, 1) <> 0
        ${scope?.clause ?? ''}
        ORDER  BY s.last_name, s.first_name
        ''',
        parameters: [yearId ?? '', schoolId, ...?scope?.params],
      )
      .map((rows) => [
            for (final r in rows)
              StudentRow(
                id: r['id'] as String,
                firstName: (r['first_name'] as String?) ?? '',
                lastName: (r['last_name'] as String?) ?? '',
                matricule: (r['matricule'] as String?) ?? '',
                ine: r['ine'] as String?,
                gender: r['gender'] as String?,
                dateOfBirth: _d(r['date_of_birth']),
                placeOfBirth: _t(r['place_of_birth']),
                nationality: _t(r['nationality']),
                photoUrl: r['photo_url'] as String?,
                isBoarder: _b(r['is_boarder']),
                hasScholarship: _b(r['has_scholarship']),
                hasSocialAid: _b(r['has_social_aid']),
                isAffecte: _b(r['is_affecte']),
                enrollmentId: r['enrollment_id'] as String?,
                enrollmentStatus: r['enrollment_status'] as String?,
                classId: r['class_id'] as String?,
                className: r['class_name'] as String?,
                cycleCode: r['cycle_code'] as String?,
                levelCode: r['level_code'] as String?,
                levelOrder: (r['level_order'] as int?) ?? 999,
                filiereLabel: _t(r['filiere_label']),
                hasPrimaryTutor: _b(r['has_primary_tutor']),
              ),
          ]);
});

// ─── Évolution de l'effectif (cumul mensuel des inscriptions actives) ────────

/// Croissance de l'effectif : élèves entrés par mois + effectif cumulé.
/// Offline-first.
///
/// ── ⚠️ CE GRAPHE DOIT DIRE LE MÊME NOMBRE QUE LA CARTE « EFFECTIF » ─────────
/// Il est tracé juste sous les KPI, sur la même page, pour la même année.
/// Trois écarts le faisaient pourtant mentir, et un quatrième effaçait ce
/// qu'il prétend montrer :
///
///  1. Il ne filtrait pas `students.is_active`. `deactivateStudent` retire
///     l'élève du registre SANS toucher au statut de son inscription — à
///     dessein : une sortie de classe exige un motif normalisé (déperdition
///     scolaire) qu'une désactivation administrative n'a pas. Le graphe
///     continuait donc de compter des élèves que la liste ne montre plus, et sa
///     courbe finissait au-dessus du compteur d'à côté. C'est exactement le
///     piège déjà corrigé sur l'effectif des classes.
///  2. Il n'appliquait aucun périmètre de classes, quand la liste juste en
///     dessous, elle, l'applique : un enseignant restreint à ses propres
///     classes lisait la courbe de l'école entière sous ses propres KPI.
///  3. Il publiait avant que le profil d'accès soit lu.
///  4. `GROUP BY` ne rend que les mois où quelque chose s'est passé : sur un axe
///     catégoriel, un mois creux n'existait même pas comme espace, et la pause
///     se lisait comme une reprise immédiate. Le remplissage des trous et les
///     libellés de mois viennent de `construireRythmeInscriptions`, qui porte
///     déjà cette correction — et ses tests — pour la page Inscriptions.
final effectifEvolutionProvider =
    StreamProvider.autoDispose<List<EnrollPoint>>((ref) {
  final profile = ref.watch(authNotifierProvider).valueOrNull;
  final schoolId = profile?.schoolId;
  final yearId = ref.watch(activeYearIdProvider);
  if (schoolId == null || schoolId.isEmpty) return Stream.value(const []);
  if (!permissionsLoaded(ref)) return const Stream.empty();
  final scope = classScopeClause(ref, 'eleves', column: 'ce.class_id');

  return db
      .watch(
        '''
        SELECT substr(ce.enrollment_date, 1, 7) AS ym, COUNT(*) AS n
        FROM   class_enrollments ce
        JOIN   students s ON s.id = ce.student_id
        WHERE  ce.academic_year_id = ?
          AND  ce.status = 'active'
          AND  s.school_id = ?
          AND  COALESCE(s.is_active, 1) <> 0
          AND  ce.enrollment_date IS NOT NULL
          AND  ce.enrollment_date != ''
        ${scope?.clause ?? ''}
        GROUP  BY ym
        ORDER  BY ym
        ''',
        parameters: [yearId ?? '', schoolId, ...?scope?.params],
      )
      .map((rows) {
        final parMois = <String, int>{};
        for (final r in rows) {
          final ym = (r['ym'] as String?) ?? '';
          if (ym.length == 7) parMois[ym] = (r['n'] as int?) ?? 0;
        }
        return construireRythmeInscriptions(parMois, const {});
      });
});

// ─── Export CSV de l'effectif ────────────────────────────────────────────────
//
//  ⚠️ CE FICHIER DOIT POUVOIR RENTRER PAR LA PORTE D'À CÔTÉ.
//
//  Il ne portait ni date de naissance, ni identifiant national, ni lieu de
//  naissance. Or l'import (`services/import_liste_eleves.dart`) tient la date
//  de naissance pour obligatoire et rejette toute ligne qui en manque : la
//  liste exportée depuis cette page, réimportée dans E-PILOTE, était rejetée à
//  CENT POUR CENT, et l'écran de contrôle affichait trois cents lignes rouges
//  sans que personne comprenne pourquoi.
//
//  Ce n'est pas un cas d'école : c'est le geste de la fin d'année et celui du
//  transfert. Le même défaut avait été corrigé sur l'export du guichet ; il
//  était resté ici, sur la page d'où l'on exporte justement l'effectif.
//
//  Les en-têtes portent donc LES LIBELLÉS QUE LE LECTEUR RECONNAÎT, et non des
//  noms de colonnes choisis librement. « Âge » a disparu : il se recalcule, il
//  vieillit dans le fichier, et aucun import ne le lit.

/// Les en-têtes de l'export, dans leur ordre.
///
/// Exposées pour que `test/eleves_csv_aller_retour_test.dart` les relise avec le
/// VRAI lecteur d'import : c'est le seul moyen de verrouiller qu'un libellé ne
/// soit pas renommé sans qu'on s'aperçoive que l'aller-retour est cassé.
const List<String> kEnTetesExportEleves = [
  'Matricule', 'INE', 'Nom', 'Prénom', 'Sexe',
  'Date de naissance', 'Lieu de naissance', 'Nationalité',
  'Classe', 'Niveau', 'Filière', 'Interne', 'Boursier',
];

String _csv(String? v) => '"${(v ?? '').replaceAll('"', '""')}"';

/// La ligne CSV d'un élève, dans l'ordre de [kEnTetesExportEleves].
List<String> ligneExportEleve(StudentRow r) => [
      r.matricule,
      r.ine ?? '',
      r.lastName,
      r.firstName,
      r.gender ?? '',
      // Format ISO « AAAA-MM-JJ » : le lecteur d'import l'accepte, et il ne
      // souffre pas de l'ambiguïté jour/mois d'un tableur configuré en anglais.
      r.dateOfBirth?.toIso8601String().substring(0, 10) ?? '',
      r.placeOfBirth ?? '',
      r.nationality ?? '',
      r.className ?? '',
      r.levelCode ?? '',
      r.filiereLabel ?? '',
      r.isBoarder ? 'Oui' : 'Non',
      (r.hasScholarship || r.hasSocialAid) ? 'Oui' : 'Non',
    ];

/// Écrit l'effectif (filtré) en CSV (séparateur `;`, BOM UTF-8 pour Excel FR)
/// dans le dossier Documents de l'appareil. Retourne le chemin.
Future<String> exportStudentsCsv(List<StudentRow> rows) async {
  final b = StringBuffer();
  b.writeln(kEnTetesExportEleves.map(_csv).join(';'));
  for (final r in rows) {
    b.writeln(ligneExportEleve(r).map(_csv).join(';'));
  }
  final dir = await getApplicationDocumentsDirectory();
  final ts = DateTime.now().toIso8601String().substring(0, 10);
  final file = File('${dir.path}/eleves_$ts.csv');
  // BOM UTF-8, sans quoi Excel rend « Ngoué » en « NgouÃ© ».
  await file.writeAsString('\u{FEFF}${b.toString()}');
  return file.path;
}
