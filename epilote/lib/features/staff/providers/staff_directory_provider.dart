import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/booleen_offline.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../services/powersync/powersync_service.dart';

/// Capacité de GESTION des agents (créer/modifier/transférer/désactiver le
/// PROFIL). Réservée à `admin_groupe`/`super_admin` (online, écrit `profiles`
/// lié à `auth.users`). Le personnel école est en lecture + dossier RH offline
/// (carrière/diplômes). C'est ce verrou qui rend la page Personnel scope-aware :
/// même écran, actions de gestion masquées si `false`.
final staffCanManageProvider = Provider.autoDispose<bool>((ref) {
  final role = ref.watch(authNotifierProvider).valueOrNull?.role;
  return role == 'admin_groupe' || role == 'super_admin';
});

// ════════════════════════════════════════════════════════════════════════════
//  ANNUAIRE DU PERSONNEL — 100 % offline (db.watch sur `profiles`).
//
//  Identité du personnel = la ligne `profiles` (nom, rôle, contact, matricule,
//  statut). Les comptes sont provisionnés EN LIGNE par l'admin groupe ; cet
//  écran est donc en LECTURE SEULE côté école. L'overlay RH/finance
//  (`staff_members` : contrat, salaire, iban) relève de la Paie (Phase 5) — il
//  n'a pas encore de lien `profile_id` en base, on ne le branche donc pas ici.
//
//  ⚠️ `teacher_subjects.staff_id` référence en réalité `profiles.id` (pas
//  `staff_members`) : l'affectation enseignant↔matière s'appuiera sur cet
//  annuaire-profils, cohérent avec le présent module.
// ════════════════════════════════════════════════════════════════════════════

/// Un membre du personnel (vue annuaire, dérivée de `profiles`).
class StaffMember {
  const StaffMember({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.isActive,
    this.phone,
    this.employeeNumber,
    this.avatarUrl,
    this.lastLogin,
    this.employmentStatus,
    this.teachingCycle,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String role;
  final bool isActive;
  final String? phone;
  final String? employeeNumber;
  final String? avatarUrl;
  final DateTime? lastLogin;

  /// Statut RH (fonctionnaire / volontaire / prestataire …) — `profiles`.
  final String? employmentStatus;

  /// Cycle d'enseignement (primaire/college/lycee) DÉDUIT des classes que
  /// l'agent enseigne (prof principal ou affectation matière). null = non
  /// enseignant ou cycle inconnu.
  final String? teachingCycle;

  String get fullName {
    final n = '${firstName.trim()} ${lastName.trim()}'.trim();
    return n.isEmpty ? '—' : n;
  }

  /// « NOM Prénom » pour un tri/affichage annuaire.
  String get lastFirst {
    final l = lastName.trim();
    final f = firstName.trim();
    if (l.isEmpty && f.isEmpty) return '—';
    if (l.isEmpty) return f;
    if (f.isEmpty) return l;
    return '$l $f';
  }

  /// Concaténation pour la recherche locale (insensible à la casse).
  String get searchBlob =>
      '$firstName $lastName ${employeeNumber ?? ''} $role'.toLowerCase();
}

// ─── Catégories métier (regroupement de l'annuaire) ──────────────────────────

enum StaffCategory { direction, administration, enseignement, vieScolaire, autres }

/// Catégorie métier d'un rôle (pour grouper l'annuaire et les compteurs).
StaffCategory staffCategory(String role) => switch (role) {
      'proviseur' || 'directeur' => StaffCategory.direction,
      'secretaire' || 'comptable' => StaffCategory.administration,
      'enseignant' => StaffCategory.enseignement,
      'cpe' || 'surveillant' || 'infirmier' || 'responsable_cantine' =>
        StaffCategory.vieScolaire,
      _ => StaffCategory.autres,
    };

String staffCategoryLabel(StaffCategory c) => switch (c) {
      StaffCategory.direction => 'Direction',
      StaffCategory.administration => 'Administration',
      StaffCategory.enseignement => 'Enseignants',
      StaffCategory.vieScolaire => 'Vie scolaire',
      StaffCategory.autres => 'Autres',
    };

/// Ordre d'affichage des catégories (direction en tête, comme l'organigramme).
const List<StaffCategory> staffCategoryOrder = [
  StaffCategory.direction,
  StaffCategory.administration,
  StaffCategory.enseignement,
  StaffCategory.vieScolaire,
  StaffCategory.autres,
];

// ─── Provider : annuaire de l'école (offline-first) ──────────────────────────

/// Personnel actif/inactif de l'école synchronisée localement.
/// Exclut élèves et parents (ce sont des usagers, pas du personnel).
final staffDirectoryProvider =
    StreamProvider.autoDispose<List<StaffMember>>((ref) {
  final schoolId = ref.watch(authNotifierProvider).valueOrNull?.schoolId;
  if (schoolId == null || schoolId.isEmpty) return Stream.value(const []);
  return db
      .watch(
        '''
        SELECT p.id, p.first_name, p.last_name, p.role, p.phone,
               p.employee_number, p.avatar_url, p.is_active, p.last_login,
               p.employment_status,
               (
                 SELECT c.cycle_code FROM classes c
                 WHERE c.main_teacher_id = p.id AND c.cycle_code IS NOT NULL
                 UNION
                 SELECT c2.cycle_code FROM teacher_subjects ts
                 JOIN classes c2 ON c2.id = ts.class_id
                 WHERE ts.staff_id = p.id AND c2.cycle_code IS NOT NULL
                 LIMIT 1
               ) AS teaching_cycle
        FROM   profiles p
        WHERE  p.school_id = ?
        AND    p.role NOT IN ('eleve', 'parent')
        ORDER  BY p.last_name, p.first_name
        ''',
        parameters: [schoolId],
      )
      .map((rows) => [
            for (final r in rows)
              StaffMember(
                id: r['id'] as String,
                firstName: r['first_name'] as String? ?? '',
                lastName: r['last_name'] as String? ?? '',
                role: r['role'] as String? ?? '',
                // ⚠️ `== 1` rendait « inactif » un agent dont la colonne
                // n'était pas renseignée, alors que le tableau de bord de la
                // MÊME école le comptait en fonction (`COALESCE(is_active, 1)
                // <> 0`). Deux écrans, deux réponses. `is_active` est un
                // booléen par défaut VRAI : l'absence d'information vaut oui.
                isActive: actifOffline(r['is_active']),
                phone: r['phone'] as String?,
                employeeNumber: r['employee_number'] as String?,
                avatarUrl: r['avatar_url'] as String?,
                lastLogin: (r['last_login'] as String?) != null
                    ? DateTime.tryParse(r['last_login'] as String)
                    : null,
                employmentStatus: r['employment_status'] as String?,
                teachingCycle: r['teaching_cycle'] as String?,
              ),
          ]);
});
