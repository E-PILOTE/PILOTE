import '../../core/utils/booleen_offline.dart';

bool _b(dynamic v) => v == true || v == 1;

/// Table `students` — dossier élève.
/// Champs conformes au système éducatif de la République du Congo.
class StudentModel {
  const StudentModel({
    required this.id,
    required this.schoolId,
    required this.groupId,
    required this.matricule,
    this.ine,
    required this.firstName,
    required this.lastName,
    this.dateOfBirth,
    this.placeOfBirth,
    this.gender,
    this.nationality,
    this.address,
    this.city,
    this.region,
    this.photoUrl,
    this.bloodGroup,
    this.allergies,
    this.situationFamiliale,
    this.nombreFreresSoeurs,
    this.isBoarder = false,
    this.hasScholarship = false,
    this.scholarshipType,
    this.hasSocialAid = false,
    this.socialAidType,
    this.isAffecte = false,
    this.userId,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StudentModel.fromMap(Map<String, dynamic> map) {
    return StudentModel(
      id:                  map['id']                    as String,
      schoolId:            map['school_id']             as String,
      groupId:             map['group_id']              as String,
      matricule:           map['matricule']             as String? ?? '',
      ine:                 map['ine']                   as String?,
      firstName:           map['first_name']            as String,
      lastName:            map['last_name']             as String,
      dateOfBirth:         map['date_of_birth'] != null
          ? DateTime.tryParse(map['date_of_birth'] as String)
          : null,
      placeOfBirth:        map['place_of_birth']        as String?,
      gender:              map['gender']                as String?,
      nationality:         map['nationality']           as String? ?? 'Congolaise',
      address:             map['address']               as String?,
      city:                map['city']                  as String?,
      region:              map['region']                as String?,
      photoUrl:            map['photo_url']             as String?,
      bloodGroup:          map['blood_group']           as String?,
      allergies:           map['allergies']             as String?,
      situationFamiliale:  map['situation_familiale']   as String?,
      nombreFreresSoeurs:  map['nombre_freres_soeurs']  as int? ?? 0,
      isBoarder:           _b(map['is_boarder']),
      hasScholarship:      _b(map['has_scholarship']),
      scholarshipType:     map['scholarship_type']      as String?,
      hasSocialAid:        _b(map['has_social_aid']),
      socialAidType:       map['social_aid_type']       as String?,
      isAffecte:           _b(map['is_affecte']),
      userId:              map['user_id']                as String?,
      // ⚠️ Défaut VRAI — cf. `core/utils/booleen_offline.dart`. Les autres
      // booléens de ce modèle sont par défaut faux et gardent `_b`.
      isActive:            actifOffline(map['is_active']),
      createdAt:           DateTime.parse(map['created_at'] as String),
      updatedAt:           DateTime.parse(map['updated_at'] as String),
    );
  }

  final String   id;
  final String   schoolId;
  final String   groupId;
  final String   matricule;

  /// Identifiant NATIONAL — 11 chiffres, attribué par le serveur et
  /// immuable. Distinct du [matricule], qui reste le numéro de l'école.
  /// `null` tant qu'une inscription saisie hors ligne n'a pas été
  /// synchronisée : ce n'est ni une erreur ni un oubli.
  final String?  ine;
  final String   firstName;
  final String   lastName;
  final DateTime? dateOfBirth;
  final String?  placeOfBirth;
  final String?  gender;              // 'M' | 'F'
  final String?  nationality;
  final String?  address;
  final String?  city;
  final String?  region;
  final String?  photoUrl;
  final String?  bloodGroup;
  final String?  allergies;

  // ── Champs spécifiques au système éducatif congolais ─────────────────────
  final String? situationFamiliale;   // biparentale | monoparentale_* | orphelin_* | tuteur
  final int?    nombreFreresSoeurs;
  final bool    isBoarder;            // pensionnaire / interne
  final bool    hasScholarship;
  final String? scholarshipType;
  final bool    hasSocialAid;
  final String? socialAidType;
  final bool    isAffecte;            // affecté par le MEPSA/METP
  final String? userId;               // compte parent si activé

  final bool     isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  // ── Helpers ───────────────────────────────────────────────────────────────

  String get fullName  => '$firstName $lastName';
  String get lastFirst => '$lastName $firstName';

  String get genderLabel => switch (gender) {
    'M' => 'Masculin',
    'F' => 'Féminin',
    _   => '—',
  };

  String get situationFamilialeLabel => switch (situationFamiliale) {
    'biparentale'        => 'Biparentale',
    'monoparentale_pere' => 'Monoparentale (père)',
    'monoparentale_mere' => 'Monoparentale (mère)',
    'orphelin_partiel'   => 'Orphelin partiel',
    'orphelin_total'     => 'Orphelin total',
    'tuteur'             => 'Sous tutelle',
    _                    => '—',
  };

  int? get age {
    if (dateOfBirth == null) return null;
    final now = DateTime.now();
    int a = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month ||
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      a--;
    }
    return a;
  }

  StudentModel copyWith({
    String? matricule,
    String? ine,
    String? firstName,
    String? lastName,
    DateTime? dateOfBirth,
    String? placeOfBirth,
    String? gender,
    String? nationality,
    String? address,
    String? city,
    String? photoUrl,
    String? bloodGroup,
    String? allergies,
    String? situationFamiliale,
    int? nombreFreresSoeurs,
    bool? isBoarder,
    bool? hasScholarship,
    String? scholarshipType,
    bool? hasSocialAid,
    String? socialAidType,
    bool? isAffecte,
    String? userId,
    bool? isActive,
  }) => StudentModel(
    id: id, schoolId: schoolId, groupId: groupId,
    createdAt: createdAt, updatedAt: updatedAt,
    matricule:           matricule           ?? this.matricule,
    ine:                 ine                 ?? this.ine,
    firstName:           firstName           ?? this.firstName,
    lastName:            lastName            ?? this.lastName,
    dateOfBirth:         dateOfBirth         ?? this.dateOfBirth,
    placeOfBirth:        placeOfBirth        ?? this.placeOfBirth,
    gender:              gender              ?? this.gender,
    nationality:         nationality         ?? this.nationality,
    address:             address             ?? this.address,
    city:                city                ?? this.city,
    photoUrl:            photoUrl            ?? this.photoUrl,
    bloodGroup:          bloodGroup          ?? this.bloodGroup,
    allergies:           allergies           ?? this.allergies,
    situationFamiliale:  situationFamiliale  ?? this.situationFamiliale,
    nombreFreresSoeurs:  nombreFreresSoeurs  ?? this.nombreFreresSoeurs,
    isBoarder:           isBoarder           ?? this.isBoarder,
    hasScholarship:      hasScholarship      ?? this.hasScholarship,
    scholarshipType:     scholarshipType     ?? this.scholarshipType,
    hasSocialAid:        hasSocialAid        ?? this.hasSocialAid,
    socialAidType:       socialAidType       ?? this.socialAidType,
    isAffecte:           isAffecte           ?? this.isAffecte,
    userId:              userId              ?? this.userId,
    isActive:            isActive            ?? this.isActive,
  );

  @override
  String toString() => 'StudentModel($id, $fullName, $matricule)';
}
