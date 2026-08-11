import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/write_identity.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../../data/models/class_model.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/classes/providers/class_provider.dart';
import '../../../features/structure/providers/academic_year_context.dart';
import '../../../features/structure/providers/academic_year_provider.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../models/tutor_draft.dart';
import '../widgets/inscription_form_kit.dart';
import '../widgets/national_lookup_panel.dart';
import '../providers/inscriptions_data_provider.dart';
import '../providers/student_documents_provider.dart';
import '../providers/student_tutors_provider.dart';
import '../providers/student_match_provider.dart';
import '../providers/students_provider.dart';
import '../../../services/powersync/powersync_service.dart';
import '../../../core/utils/message_erreur.dart';

part 'add_inscription_steps_1_2.dart';
part 'add_inscription_steps_3_5.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
Color get _kNavy => kNavy;
Color get _kGreen => kGreen;
Color get _kRed => kRed;
Color get _kMuted => kTextMuted;
Color get _kText => kTextPrimary;
Color get _kBorder => kBorder;

// ─── State ────────────────────────────────────────────────────────────────────

class _InscriptionState {
  // Identité de l'élève générée en amont → chemin du dossier documentaire.
  final String studentId = const Uuid().v4();

  // Étape 1 — Élève
  String  firstName        = '';
  String  lastName         = '';
  String? dateOfBirth;
  String? placeOfBirth;
  String  gender           = 'M';
  String  nationality      = 'Congolaise';
  String? situationFamiliale;
  int     nombreFreresSoeurs = 0;
  bool    isBoarder        = false;
  bool    hasScholarship   = false;
  String? scholarshipType;
  bool    hasSocialAid     = false;
  String? socialAidType;
  bool    isAffecte        = false;
  String? address;
  String? city;
  String? region;
  String? bloodGroup;
  String? allergies;

  /// Renseigné quand le secrétariat reconnaît un élève DÉJÀ présent dans
  /// l'école : on n'écrit alors ni fiche élève ni tuteurs — seulement la
  /// nouvelle inscription. C'est la vraie réinscription. Sans cela, le même
  /// enfant repartait avec un second matricule et un dossier vierge.
  String? existingStudentId;
  String? existingStudentName;

  bool get reusesExistingStudent => existingStudentId != null;

  /// L'identifiant sous lequel l'inscription sera écrite.
  String get effectiveStudentId => existingStudentId ?? studentId;

  /// Identifiant national repris d'un élève reconnu dans une AUTRE école.
  ///
  /// Cas distinct de [existingStudentId] : là, l'enfant est déjà chez nous et
  /// on réutilise sa fiche. Ici, il arrive d'ailleurs — on crée bien une fiche
  /// neuve, mais elle porte l'identifiant qu'il avait déjà. C'est ce qui fait
  /// que sa scolarité ne se coupe pas en deux au passage de la frontière entre
  /// deux établissements.
  String? claimedIne;

  // Étape 2 — Tuteurs
  final List<_TutorEntry> tutors = [
    _TutorEntry(isPrimary: true),
  ];

  // Étape 3 — Scolarité
  String  inscriptionType    = 'new';
  String? academicYearId;
  String? classId;
  bool    isRepeating        = false;
  String? previousSchoolName;
  String? previousClassName;
  String? previousClassId;
  String? transferReason;
  String? notes;

  // Étape 4 — Documents (pièces réellement téléversées du dossier élève)
  final Map<String, _DocEntry> uploadedDocs = {};
}

/// Une pièce du dossier téléversée (chemin Storage prêt à être persisté au submit).
class _DocEntry {
  _DocEntry({
    required this.typeSlug,
    required this.label,
    required this.fileName,
    required this.path,
  });
  final String typeSlug, label, fileName, path;
}

/// La fiche tuteur et sa règle de validation vivent dans `models/tutor_draft.dart`
/// pour être testables hors widget (perte silencieuse — cf. l'en-tête du fichier).
typedef _TutorEntry = TutorDraft;

// ─── Screen ───────────────────────────────────────────────────────────────────

class AddInscriptionScreen extends ConsumerStatefulWidget {
  const AddInscriptionScreen({super.key});

  @override
  ConsumerState<AddInscriptionScreen> createState() =>
      _AddInscriptionScreenState();
}

class _AddInscriptionScreenState extends ConsumerState<AddInscriptionScreen> {
  final _pageController = PageController();
  final _state          = _InscriptionState();
  int  _currentStep     = 0;
  bool _submitting      = false;
  String? _error;

  static const _steps = ['Élève', 'Parents', 'Scolarité', 'Documents', 'Résumé'];

  @override
  void initState() {
    super.initState();
    // L'inscription porte l'année EN COURS, la seule dont l'étape 3 sait
    // proposer les classes. On la fixe ici plutôt que de la faire choisir :
    // le formulaire ne peut honorer aucun autre choix.
    _state.academicYearId = ref.read(activeYearIdProvider);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    // Garde les champs requis AVANT d'avancer : ils sont NOT NULL en base, donc
    // une saisie incomplète serait acceptée en local puis REJETÉE à la synchro
    // (transaction abandonnée = perte silencieuse). Bloquer ici évite ça.
    final err = _validateStep(_currentStep);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    if (_currentStep < _steps.length - 1) {
      setState(() { _currentStep++; _error = null; });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Contrôle des champs obligatoires d'une étape (alignés sur les contraintes
  /// NOT NULL du serveur). Retourne un message d'erreur, ou null si valide.
  String? _validateStep(int step) {
    switch (step) {
      case 0: // Élève
        if (_state.firstName.trim().isEmpty) {
          return "Le prénom de l'élève est obligatoire.";
        }
        if (_state.lastName.trim().isEmpty) {
          return "Le nom de l'élève est obligatoire.";
        }
        if (_state.dateOfBirth == null || _state.dateOfBirth!.trim().isEmpty) {
          return 'La date de naissance est obligatoire.';
        }
        return null;
      // La règle est dans `models/tutor_draft.dart` : elle refuse une fiche
      // entamée mais incomplète au lieu de la sauter en silence.
      case 1:
        // Un élève déjà connu a ses tuteurs en base : rien à exiger ici.
        if (_state.reusesExistingStudent) return null;
        return validateTutorDrafts(_state.tutors);
      case 2: // Scolarité — l'affectation porte l'année et la classe
        if (_state.academicYearId == null) {
          return "Sélectionnez l'année scolaire.";
        }
        if (_state.classId == null) {
          return "Sélectionnez la classe d'affectation.";
        }
        return null;
      default:
        return null;
    }
  }

  void _back() {
    if (_currentStep > 0) {
      setState(() { _currentStep--; _error = null; });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _submit() async {
    setState(() { _submitting = true; _error = null; });

    final profile = ref.read(authNotifierProvider).valueOrNull;
    if (profile == null) {
      setState(() {
        _submitting = false;
        _error = 'Session expirée. Reconnectez-vous.';
      });
      return;
    }

    // Verrou année : aucune inscription sur une année archivée/non courante.
    if (ref.read(yearReadOnlyProvider)) {
      setState(() {
        _submitting = false;
        _error = 'Année en lecture seule — inscription impossible.';
      });
      return;
    }

    // Verrou LICENCE : abonnement expiré au-delà de la grâce ⇒ lecture seule.
    // L'assistant affiche ses erreurs dans son propre bandeau, pas en snackbar :
    // un message qui disparaît au bout de quatre secondes derrière un modal
    // plein écran n'est pas un refus, c'est un clignotement.
    if (writeBlockedByLicense) {
      setState(() {
        _submitting = false;
        _error = kReadOnlyWriteMessage;
      });
      return;
    }

    // Dernier rempart : champs NOT NULL (identité + affectation) — évite la
    // perte silencieuse à la synchro si une étape a été contournée.
    final missing =
        _validateStep(0) ?? _validateStep(1) ?? _validateStep(2);
    if (missing != null) {
      setState(() { _submitting = false; _error = missing; });
      return;
    }

    // Rattachement de l'agent : sans école ni groupe, l'élève, ses tuteurs ET
    // son inscription partiraient avec des identifiants vides — le serveur
    // rejetterait le lot PowerSync ENTIER, silencieusement. On refuse ici, en
    // le disant.
    final missingIds = missingWriteIds(
      groupId:  profile.groupId,
      schoolId: profile.schoolId,
      actorId:  profile.id,
    );
    if (missingIds.isNotEmpty) {
      setState(() {
        _submitting = false;
        _error      = writeIdentityMessage(missingIds);
      });
      return;
    }

    // ── RÉINSCRIPTION D'UN ÉLÈVE DÉJÀ CONNU ────────────────────────────────
    // `class_enrollments` porte `UNIQUE (student_id, academic_year_id)`. Une
    // seconde inscription du même élève sur la même année serait rejetée par
    // le serveur (23505) — et un code fatal fait abandonner à PowerSync le LOT
    // ENTIER : l'inscription, les pièces, et tout ce qui aurait été saisi dans
    // la même fenêtre disparaîtraient sans un mot. On vérifie donc en local
    // AVANT d'écrire quoi que ce soit.
    if (_state.reusesExistingStudent) {
      final existing = await db.getAll(
        'SELECT status FROM class_enrollments '
        'WHERE student_id = ? AND academic_year_id = ? LIMIT 1',
        [_state.existingStudentId, _state.academicYearId],
      );
      if (existing.isNotEmpty) {
        setState(() {
          _submitting = false;
          _error = '${_state.existingStudentName ?? 'Cet élève'} a déjà une '
              'inscription pour cette année scolaire. Ouvrez son dossier depuis '
              'la page Élèves pour le modifier.';
        });
        return;
      }
    }

    try {
      // Le quota compte les ÉLÈVES : réinscrire un élève déjà présent n'en
      // ajoute aucun, la vérification n'a donc pas lieu d'être.
      if (!_state.reusesExistingStudent) {
        final quotaError = await checkStudentQuota(
          schoolId: profile.schoolId!,
          groupId:  profile.groupId!,
        );
        if (quotaError != null) {
          setState(() { _submitting = false; _error = quotaError; });
          return;
        }
      }

      // Créer l'élève (id généré en amont = chemin du dossier documentaire),
      // sauf s'il s'agit d'un élève déjà présent : son identité et ses tuteurs
      // existent, les réécrire créerait le doublon qu'on cherche à éviter.
      final studentId = _state.reusesExistingStudent
          ? _state.existingStudentId!
          : await createStudent(
        id:                 _state.studentId,
        schoolId:           profile.schoolId!,
        groupId:            profile.groupId!,
        claimedIne:         _state.claimedIne,
        firstName:          _state.firstName,
        lastName:           _state.lastName,
        dateOfBirth:        _state.dateOfBirth != null
            ? DateTime.tryParse(_state.dateOfBirth!)
            : null,
        placeOfBirth:       _state.placeOfBirth,
        gender:             _state.gender,
        nationality:        _state.nationality,
        address:            _state.address,
        city:               _state.city,
        region:             _state.region,
        bloodGroup:         _state.bloodGroup,
        allergies:          _state.allergies,
        situationFamiliale: _state.situationFamiliale,
        nombreFreresSoeurs: _state.nombreFreresSoeurs,
        isBoarder:          _state.isBoarder,
        hasScholarship:     _state.hasScholarship,
        scholarshipType:    _state.scholarshipType,
        hasSocialAid:       _state.hasSocialAid,
        socialAidType:      _state.socialAidType,
        isAffecte:          _state.isAffecte,
      );

      // Créer les tuteurs — l'élève déjà connu a les siens.
      // Seules les fiches JAMAIS remplies sont écartées : une fiche partielle
      // a déjà été refusée à l'étape 2, elle ne peut plus se perdre ici.
      for (final t in _state.reusesExistingStudent
          ? const <_TutorEntry>[]
          : tutorsToPersist(_state.tutors)) {
        await addTutor(
          studentId:         studentId,
          groupId:           profile.groupId!,
          firstName:         t.firstName,
          lastName:          t.lastName,
          relationship:      t.relationship,
          phonePrimary:      t.phonePrimary,
          phoneSecondary:    t.phoneSecondary,
          email:             t.email,
          profession:        t.profession,
          address:           t.address,
          isPrimaryContact:  t.isPrimary,
          isEmergencyContact: t.isEmergency,
        );
      }

      // Créer l'inscription (pending_validation)
      if (_state.classId != null && _state.academicYearId != null) {
        await enrollStudent(
          schoolId:           profile.schoolId!,
          groupId:            profile.groupId!,
          studentId:          studentId,
          classId:            _state.classId!,
          academicYearId:     _state.academicYearId!,
          isRepeating:        _state.isRepeating,
          previousClassId:    _state.previousClassId,
          inscriptionType:    _state.inscriptionType,
          previousSchoolName: _state.previousSchoolName,
          previousClassName:  _state.previousClassName,
          transferReason:     _state.transferReason,
          notes:              _state.notes,
          createdBy:          profile.id,
        );
      }

      // Persister les pièces du dossier déjà téléversées (offline-first).
      for (final d in _state.uploadedDocs.values) {
        await insertStudentDocumentRow(
          groupId:      profile.groupId!,
          schoolId:     profile.schoolId!,
          studentId:    studentId,
          documentType: d.typeSlug,
          documentName: d.label,
          fileUrl:      d.path,
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Inscription créée — en attente de validation'),
            backgroundColor: _kGreen,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _submitting = false;
        _error      = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return InscriptionModalFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InscriptionHeader(
            icon: Icons.how_to_reg_rounded,
            title: 'Nouvelle inscription',
            subtitle:
                'Étape ${_currentStep + 1}/${_steps.length} · ${_steps[_currentStep]}',
          ),
          InscriptionStepIndicator(current: _currentStep, steps: _steps),
          Flexible(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _Step1Eleve(state: _state, onChanged: () => setState(() {})),
                _Step2Parents(state: _state, onChanged: () => setState(() {})),
                _Step3Scolarite(state: _state, onChanged: () => setState(() {})),
                _Step4Documents(state: _state, onChanged: () => setState(() {})),
                _Step5Resume(state: _state),
              ],
            ),
          ),
          if (_error != null) AdminErrorBanner(message: _error!),
          InscriptionNavBar(
            currentStep: _currentStep,
            totalSteps: _steps.length,
            submitting: _submitting,
            onBack: _back,
            onNext: _next,
            onSubmit: _submit,
            lastLabel: 'Enregistrer l\'inscription',
          ),
        ],
      ),
    );
  }
}
