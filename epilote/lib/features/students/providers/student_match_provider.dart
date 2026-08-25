import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/powersync/powersync_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../structure/providers/academic_year_context.dart';

// ════════════════════════════════════════════════════════════════════════════
//  « CET ENFANT EST-IL DÉJÀ CHEZ NOUS ? »
//
//  ── LE TROU QUE CE FICHIER BOUCHE ──────────────────────────────────────────
//  L'assistant d'inscription créait TOUJOURS un nouvel élève : un identifiant
//  neuf est tiré à l'ouverture du formulaire, et `createStudent` l'écrit sans
//  jamais regarder si l'enfant existe. Y compris quand le secrétariat
//  choisissait le type « Réinscription » — le champ existait, il ne changeait
//  rien.
//
//  Conséquence : le même enfant pouvait se retrouver en double, avec deux
//  matricules, deux dossiers de pièces, et sa scolarité coupée en deux. Rien
//  ne l'empêche en base : la seule contrainte d'unicité porte sur le
//  matricule, qui est tiré au hasard et ne collisionne donc jamais. Deux
//  « Aristide NGOMA né le 15/01/2014 » sont deux élèves pour le système.
//
//  Un guichet d'admissions pose cette question avant toute autre. On la pose
//  ici, en local, hors ligne, pendant la frappe.
//
//  ── LA RÈGLE DE RAPPROCHEMENT ──────────────────────────────────────────────
//  Même NOM DE FAMILLE, et (même prénom OU même date de naissance).
//  Le nom de famille seul ramènerait toute la fratrie ; exiger les trois
//  laisserait passer « Aristide » écrit « Aristid ». On signale, on ne décide
//  pas : c'est au secrétariat de dire si c'est le même enfant.
// ════════════════════════════════════════════════════════════════════════════

/// Ce que l'on cherche : l'identité saisie à l'étape 1.
typedef StudentMatchQuery = ({String firstName, String lastName, String? dob});

class StudentMatch {
  const StudentMatch({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.matricule,
    required this.dateOfBirth,
    required this.sameBirthDate,
    required this.enrolledThisYear,
    required this.enrollmentStatus,
    required this.className,
  });

  final String id, firstName, lastName, matricule;
  final String? dateOfBirth;

  /// La date de naissance concorde : le rapprochement est quasi certain.
  final bool sameBirthDate;

  /// L'élève a DÉJÀ une inscription pour l'année en cours. Le réinscrire
  /// violerait `UNIQUE (student_id, academic_year_id)` — et un rejet du
  /// serveur fait abandonner à PowerSync le LOT ENTIER, silencieusement.
  /// On refuse donc avant d'écrire.
  final bool enrolledThisYear;
  final String? enrollmentStatus, className;

  String get fullName => '$firstName $lastName'.trim();
}

/// Élèves de l'école ressemblant à l'identité saisie. Vide tant que la saisie
/// est trop courte pour être discriminante.
final studentMatchesProvider = FutureProvider.autoDispose
    .family<List<StudentMatch>, StudentMatchQuery>((ref, q) async {
  final schoolId = ref.watch(authNotifierProvider).valueOrNull?.schoolId;
  final yearId = ref.watch(activeYearIdProvider);
  final last = q.lastName.trim();
  final first = q.firstName.trim();
  final dob = (q.dob ?? '').trim();
  // Un nom de famille d'une lettre rapprocherait la moitié de l'école ; et
  // sans prénom ni date, on ne saurait pas distinguer un frère.
  if (schoolId == null || schoolId.isEmpty || last.length < 2) return const [];
  if (first.isEmpty && dob.isEmpty) return const [];

  final rows = await db.getAll(
    '''
    SELECT s.id, s.first_name, s.last_name, s.matricule, s.date_of_birth,
           ce.status  AS enrollment_status,
           c.name     AS class_name
    FROM   students s
    -- ⚠️ AUCUN filtre sur le statut : la contrainte `UNIQUE (student_id,
    -- academic_year_id)` ne regarde pas le statut non plus. Un dossier rejeté
    -- ou une sortie occupent la place tout autant qu'une inscription active —
    -- proposer une réinscription par-dessus mènerait à un refus du serveur
    -- (23505), et PowerSync abandonne le LOT ENTIER sur un code fatal.
    LEFT JOIN class_enrollments ce
           ON ce.student_id = s.id AND ce.academic_year_id = ?
    LEFT JOIN classes c ON c.id = ce.class_id
    WHERE  s.school_id = ? AND COALESCE(s.is_active, 1) <> 0
      AND  LOWER(TRIM(s.last_name)) = LOWER(TRIM(?))
      AND  (LOWER(TRIM(s.first_name)) = LOWER(TRIM(?))
            OR (? != '' AND s.date_of_birth = ?))
    ORDER  BY s.first_name
    LIMIT  10
    ''',
    [yearId ?? '', schoolId, last, first, dob, dob],
  );

  return [
    for (final r in rows)
      StudentMatch(
        id: r['id'] as String,
        firstName: (r['first_name'] as String?) ?? '',
        lastName: (r['last_name'] as String?) ?? '',
        matricule: (r['matricule'] as String?) ?? '',
        dateOfBirth: r['date_of_birth'] as String?,
        sameBirthDate:
            dob.isNotEmpty && (r['date_of_birth'] as String?) == dob,
        enrolledThisYear: r['enrollment_status'] != null,
        enrollmentStatus: r['enrollment_status'] as String?,
        className: r['class_name'] as String?,
      ),
  ];
});
