// ════════════════════════════════════════════════════════════════════════════
//  LA CARRIÈRE DE L'AGENT — lecture de l'historique, écriture des mouvements
//
//  Trois gestes, trois fonctions serveur (migration 0083). Elles écrivent
//  `profiles` ET `staff_affectations` dans la même transaction : le poste quitté
//  ne peut pas se fermer sans que le suivant s'ouvre. Ne JAMAIS reproduire ces
//  écritures ici — un `update` direct sur `profiles.school_id` recréerait très
//  exactement le trou qu'on vient de boucher.
//
//  Espace groupe → Supabase direct (règle d'architecture : `admin_groupe` est
//  en ligne). `staff_affectations` est hors PowerSync : muter est un acte de
//  l'autorité de tutelle, pas de l'école.
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import 'admin_users_provider.dart';

String _jour(DateTime d) => d.toIso8601String().substring(0, 10);

/// Un poste occupé : où, quand, en vertu de quel acte.
class Affectation {
  const Affectation({
    required this.id,
    required this.schoolId,
    required this.schoolName,
    required this.role,
    required this.startDate,
    required this.arrivalMotif,
    this.endDate,
    this.departureMotif,
    this.acteReference,
    this.acteDate,
    this.notes,
  });

  factory Affectation.fromMap(Map<String, dynamic> m) {
    final school = m['schools'];
    return Affectation(
      id:           m['id'] as String,
      schoolId:     m['school_id'] as String? ?? '',
      schoolName:   school is Map ? (school['name'] as String? ?? '—') : '—',
      role:         m['role'] as String? ?? '',
      startDate:    DateTime.parse(m['start_date'] as String),
      endDate:      m['end_date'] != null
          ? DateTime.tryParse(m['end_date'] as String) : null,
      arrivalMotif:   m['arrival_motif'] as String? ?? '',
      departureMotif: m['departure_motif'] as String?,
      acteReference:  m['acte_reference'] as String?,
      acteDate: m['acte_date'] != null
          ? DateTime.tryParse(m['acte_date'] as String) : null,
      notes: m['notes'] as String?,
    );
  }

  final String id, schoolId, schoolName, role, arrivalMotif;
  final DateTime startDate;
  final DateTime? endDate, acteDate;
  final String? departureMotif, acteReference, notes;

  bool get isCurrent => endDate == null;

  /// Durée du service à ce poste, en années révolues et mois.
  String get duree {
    final fin = endDate ?? DateTime.now();
    var mois = (fin.year - startDate.year) * 12 + (fin.month - startDate.month);
    if (fin.day < startDate.day) mois -= 1;
    if (mois < 1) return 'moins d\'un mois';
    if (mois < 12) return '$mois mois';
    final ans = mois ~/ 12;
    final reste = mois % 12;
    return reste == 0 ? '$ans an${ans > 1 ? 's' : ''}'
                      : '$ans an${ans > 1 ? 's' : ''} et $reste mois';
  }
}

/// L'historique complet d'un agent, du poste actuel au plus ancien.
final agentCarriereProvider =
    FutureProvider.autoDispose.family<List<Affectation>, String>((ref, profileId) async {
  final client = ref.watch(supabaseClientProvider);
  final rows = await client
      .from('staff_affectations')
      .select('id, school_id, role, start_date, end_date, arrival_motif, '
              'departure_motif, acte_reference, acte_date, notes, schools(name)')
      .eq('profile_id', profileId)
      .order('start_date', ascending: false) as List;
  return rows
      .map((r) => Affectation.fromMap(Map<String, dynamic>.from(r as Map)))
      .toList();
});

/// Un homonyme déjà présent sous le même matricule — avant de créer un doublon.
class PorteurMatricule {
  const PorteurMatricule({
    required this.fullName,
    required this.role,
    required this.schoolName,
    required this.groupName,
    required this.isActive,
    required this.memeGroupe,
    this.departureMotif,
  });

  factory PorteurMatricule.fromMap(Map<String, dynamic> m) => PorteurMatricule(
        fullName: '${m['first_name'] ?? ''} ${m['last_name'] ?? ''}'.trim(),
        role:        m['role'] as String? ?? '',
        schoolName:  m['school_name'] as String? ?? '—',
        groupName:   m['group_name'] as String? ?? '—',
        isActive:    m['is_active'] as bool? ?? false,
        memeGroupe:  m['meme_groupe'] as bool? ?? false,
        departureMotif: m['departure_motif'] as String?,
      );

  final String fullName, role, schoolName, groupName;
  final bool isActive, memeGroupe;
  final String? departureMotif;
}

/// Ce que le départ d'un agent a libéré — et ce qu'il laisse à faire.
///
/// La distinction porte tout : les cours, les classes dont il était professeur
/// principal et ses disponibilités disent CE QUI EST, et deviennent faux à son
/// départ ; l'emploi du temps, lui, n'est PAS touché. Qui remplace un
/// enseignant est une décision de chef d'établissement, pas l'effet de bord
/// d'un arrêté (migration 0085).
class ChargeLiberee {
  const ChargeLiberee({
    this.coursLiberes = 0,
    this.classesLiberees = 0,
    this.disponibilitesEffacees = 0,
    this.creneauxAReattribuer = 0,
  });

  factory ChargeLiberee.fromMap(Map<String, dynamic> m) => ChargeLiberee(
        coursLiberes:           (m['cours_liberes'] as num?)?.toInt() ?? 0,
        classesLiberees:        (m['classes_liberees'] as num?)?.toInt() ?? 0,
        disponibilitesEffacees: (m['disponibilites_effacees'] as num?)?.toInt() ?? 0,
        creneauxAReattribuer:   (m['creneaux_a_reattribuer'] as num?)?.toInt() ?? 0,
      );

  final int coursLiberes, classesLiberees, disponibilitesEffacees;

  /// Créneaux d'emploi du temps encore à son nom : à réattribuer par l'école.
  /// Ne jamais taire ce nombre — un silence se lirait « tout est réglé ».
  final int creneauxAReattribuer;

  bool get rienASignaler =>
      coursLiberes == 0 && classesLiberees == 0 && creneauxAReattribuer == 0;

  /// Phrase prête à afficher, ou `null` s'il n'y a rien à dire.
  String? get resume {
    if (rienASignaler) return null;
    final faits = <String>[
      if (classesLiberees > 0)
        '$classesLiberees classe${classesLiberees > 1 ? 's' : ''} sans '
            'professeur principal',
      if (coursLiberes > 0)
        '$coursLiberes affectation${coursLiberes > 1 ? 's' : ''} de cours '
            'libérée${coursLiberes > 1 ? 's' : ''}',
    ];
    final phrase = StringBuffer();
    if (faits.isNotEmpty) phrase.write('${faits.join(', ')}.');
    if (creneauxAReattribuer > 0) {
      if (phrase.isNotEmpty) phrase.write(' ');
      phrase.write('$creneauxAReattribuer créneau'
          '${creneauxAReattribuer > 1 ? 'x' : ''} d\'emploi du temps '
          'reste${creneauxAReattribuer > 1 ? 'nt' : ''} à son nom : '
          'à réattribuer par l\'établissement.');
    }
    return phrase.toString();
  }
}

class AgentCarriereService {
  AgentCarriereService(this._ref);
  final Ref _ref;

  void _rafraichir(String profileId) {
    _ref.invalidate(agentCarriereProvider(profileId));
    _ref.invalidate(adminUsersProvider);
  }

  /// L'agent change d'établissement — et RESTE ACTIF.
  Future<ChargeLiberee> muter({
    required String profileId,
    required String schoolId,
    required DateTime effectiveDate,
    String? role,
    String? acteReference,
    DateTime? acteDate,
    String? notes,
  }) async {
    final client = _ref.read(supabaseClientProvider);
    final res = await client.rpc('muter_agent', params: {
      'p_profile_id':     profileId,
      'p_school_id':      schoolId,
      'p_effective_date': _jour(effectiveDate),
      'p_role':           role,
      'p_acte_reference': acteReference,
      'p_acte_date':      acteDate == null ? null : _jour(acteDate),
      'p_notes':          notes,
    });
    _rafraichir(profileId);
    return ChargeLiberee.fromMap(
        res is Map ? Map<String, dynamic>.from(res) : const {});
  }

  /// L'agent quitte le service. Rien n'est supprimé : le dossier reste
  /// consultable, et les écritures qu'il a faites restent attribuables.
  Future<ChargeLiberee> radier({
    required String profileId,
    required String motif,
    required DateTime effectiveDate,
    String? acteReference,
    DateTime? acteDate,
    String? notes,
  }) async {
    final client = _ref.read(supabaseClientProvider);
    final res = await client.rpc('radier_agent', params: {
      'p_profile_id':     profileId,
      'p_motif':          motif,
      'p_effective_date': _jour(effectiveDate),
      'p_acte_reference': acteReference,
      'p_acte_date':      acteDate == null ? null : _jour(acteDate),
      'p_notes':          notes,
    });
    _rafraichir(profileId);
    return ChargeLiberee.fromMap(
        res is Map ? Map<String, dynamic>.from(res) : const {});
  }

  /// L'agent revient.
  Future<ChargeLiberee> reintegrer({
    required String profileId,
    required String schoolId,
    required DateTime effectiveDate,
    String? role,
    String? acteReference,
    DateTime? acteDate,
    String? notes,
  }) async {
    final client = _ref.read(supabaseClientProvider);
    final res = await client.rpc('reintegrer_agent', params: {
      'p_profile_id':     profileId,
      'p_school_id':      schoolId,
      'p_effective_date': _jour(effectiveDate),
      'p_role':           role,
      'p_acte_reference': acteReference,
      'p_acte_date':      acteDate == null ? null : _jour(acteDate),
      'p_notes':          notes,
    });
    _rafraichir(profileId);
    return ChargeLiberee.fromMap(
        res is Map ? Map<String, dynamic>.from(res) : const {});
  }

  /// Ce matricule est-il déjà porté ? On informe, on ne bloque pas : un rejet
  /// en pleine saisie de rentrée coûte plus cher qu'un doublon signalé.
  Future<List<PorteurMatricule>> verifierMatricule(String employeeNumber) async {
    if (employeeNumber.trim().length < 3) return const [];
    final client = _ref.read(supabaseClientProvider);
    final rows = await client.rpc('verifier_matricule_agent',
        params: {'p_employee_number': employeeNumber.trim()}) as List;
    return rows
        .map((r) => PorteurMatricule.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();
  }
}

final agentCarriereServiceProvider =
    Provider<AgentCarriereService>((ref) => AgentCarriereService(ref));
