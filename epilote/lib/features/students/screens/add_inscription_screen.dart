import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/classes/providers/class_provider.dart';
import '../../../features/structure/providers/academic_year_context.dart';
import '../../../features/structure/providers/academic_year_provider.dart';
import '../providers/student_tutors_provider.dart';
import '../providers/students_provider.dart';

part 'add_inscription_steps_1_2.dart';
part 'add_inscription_steps_3_5.dart';
part 'add_inscription_widgets.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
const _kNavy   = Color(0xFF1E3A5F);
const _kGreen  = Color(0xFF009A44);
const _kRed    = Color(0xFFDC2626);
const _kMuted  = Color(0xFF64748B);
const _kText   = Color(0xFF0F172A);
const _kBorder = Color(0xFFE2E8F0);

// ─── State ────────────────────────────────────────────────────────────────────

class _InscriptionState {
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

  // Étape 4 — Documents
  final Set<String> checkedDocs = {};
}

class _TutorEntry {
  _TutorEntry({this.isPrimary = false});
  String  firstName    = '';
  String  lastName     = '';
  String  relationship = 'mere';
  String  phonePrimary = '';
  String? phoneSecondary;
  String? email;
  String? profession;
  String? address;
  bool    isPrimary;
  bool    isEmergency  = false;
}

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
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentStep < _steps.length - 1) {
      setState(() { _currentStep++; _error = null; });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
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

    try {
      // Vérifier quota avant création offline
      final quotaError = await checkStudentQuota(
        schoolId: profile.schoolId ?? '',
        groupId:  profile.groupId  ?? '',
      );
      if (quotaError != null) {
        setState(() { _submitting = false; _error = quotaError; });
        return;
      }

      // Créer l'élève
      final studentId = await createStudent(
        schoolId:           profile.schoolId ?? '',
        groupId:            profile.groupId  ?? '',
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

      // Créer les tuteurs
      for (final t in _state.tutors) {
        if (t.firstName.isEmpty || t.lastName.isEmpty || t.phonePrimary.isEmpty) {
          continue;
        }
        await addTutor(
          studentId:         studentId,
          groupId:           profile.groupId ?? '',
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
          schoolId:           profile.schoolId ?? '',
          groupId:            profile.groupId  ?? '',
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

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inscription créée — en attente de validation'),
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
    final sw = MediaQuery.of(context).size.width;
    final modalW = sw < 760 ? sw - 32 : 720.0;
    return Center(
      child: Container(
        width: modalW,
        constraints: const BoxConstraints(maxHeight: 780),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 40,
                offset: const Offset(0, 10)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── En-tête (style « Nouvelle école ») ──────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(22, 16, 14, 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: _kBorder)),
              ),
              child: Row(children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1A2F5A), _kNavy],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                          color: _kNavy.withValues(alpha: 0.30),
                          blurRadius: 8,
                          offset: const Offset(0, 3)),
                    ],
                  ),
                  child: const Icon(Icons.how_to_reg_rounded,
                      color: Colors.white, size: 19),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Nouvelle inscription',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: _kText)),
                      const SizedBox(height: 2),
                      Text('Étape ${_currentStep + 1}/${_steps.length} · ${_steps[_currentStep]}',
                          style: const TextStyle(fontSize: 11.5, color: _kMuted)),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F4F8),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _kBorder),
                    ),
                    child: const Icon(Icons.close_rounded,
                        size: 16, color: _kMuted),
                  ),
                ),
              ]),
            ),
            _StepIndicator(current: _currentStep, steps: _steps),
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
            _NavBar(
              currentStep: _currentStep,
              totalSteps: _steps.length,
              submitting: _submitting,
              onBack: _back,
              onNext: _next,
              onSubmit: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
