import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/classes/providers/class_provider.dart';
import '../../../features/structure/providers/academic_year_provider.dart';
import '../providers/student_tutors_provider.dart';
import '../providers/students_provider.dart';

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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: _kNavy,
        foregroundColor: Colors.white,
        title: const Text('Nouvelle inscription'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          _StepIndicator(current: _currentStep, steps: _steps),
          Expanded(
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
          if (_error != null)
            Container(
              color: _kRed.withValues(alpha: 0.1),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_outlined, color: _kRed, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: _kRed, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
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
    );
  }
}

// ─── Step indicator ───────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current, required this.steps});
  final int current;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kNavy,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: List.generate(steps.length, (i) {
          final active   = i == current;
          final done     = i < current;
          final color    = active ? Colors.white : (done ? _kGreen : Colors.white30);
          final bgColor  = active
              ? _kGreen
              : (done ? _kGreen.withValues(alpha: 0.3) : Colors.white12);
          return Expanded(
            child: Row(
              children: [
                if (i > 0)
                  Expanded(
                    child: Container(
                      height: 1,
                      color: done ? _kGreen : Colors.white24,
                    ),
                  ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(
                        color: bgColor,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: done
                            ? const Icon(Icons.check, size: 14, color: Colors.white)
                            : Text(
                                '${i + 1}',
                                style: TextStyle(
                                  color: color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      steps[i],
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: active ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ─── Nav bar ──────────────────────────────────────────────────────────────────

class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.currentStep,
    required this.totalSteps,
    required this.submitting,
    required this.onBack,
    required this.onNext,
    required this.onSubmit,
  });
  final int  currentStep;
  final int  totalSteps;
  final bool submitting;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final isLast = currentStep == totalSteps - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _kBorder)),
      ),
      child: Row(
        children: [
          if (currentStep > 0)
            OutlinedButton.icon(
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Retour'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _kNavy,
                side: const BorderSide(color: _kNavy),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: onBack,
            ),
          const Spacer(),
          ElevatedButton.icon(
            icon: submitting
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(isLast ? Icons.save : Icons.arrow_forward, size: 16),
            label: Text(isLast ? 'Enregistrer' : 'Suivant'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isLast ? _kGreen : _kNavy,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: submitting ? null : (isLast ? onSubmit : onNext),
          ),
        ],
      ),
    );
  }
}

// ─── Étape 1 — Élève ─────────────────────────────────────────────────────────

class _Step1Eleve extends StatefulWidget {
  const _Step1Eleve({required this.state, required this.onChanged});
  final _InscriptionState state;
  final VoidCallback onChanged;

  @override
  State<_Step1Eleve> createState() => _Step1EleveState();
}

class _Step1EleveState extends State<_Step1Eleve> {
  late final _firstNameCtrl       = TextEditingController(text: widget.state.firstName);
  late final _lastNameCtrl        = TextEditingController(text: widget.state.lastName);
  late final _placeOfBirthCtrl    = TextEditingController(text: widget.state.placeOfBirth ?? '');
  late final _addressCtrl         = TextEditingController(text: widget.state.address ?? '');
  late final _cityCtrl            = TextEditingController(text: widget.state.city ?? '');
  late final _allergiesCtrl       = TextEditingController(text: widget.state.allergies ?? '');
  late final _scholarshipTypeCtrl = TextEditingController(text: widget.state.scholarshipType ?? '');

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _placeOfBirthCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _allergiesCtrl.dispose();
    _scholarshipTypeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle('Identité'),
          _Field(
            ctrl: _firstNameCtrl,
            label: 'Prénom *',
            onChanged: (v) { s.firstName = v; widget.onChanged(); },
          ),
          _Field(
            ctrl: _lastNameCtrl,
            label: 'Nom *',
            onChanged: (v) { s.lastName = v; widget.onChanged(); },
          ),
          Row(
            children: [
              Expanded(
                child: _DropdownField<String>(
                  label: 'Genre',
                  value: s.gender,
                  items: const {'M': 'Masculin', 'F': 'Féminin'},
                  onChanged: (v) { s.gender = v!; widget.onChanged(); },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DateField(
                  label: 'Date de naissance',
                  value: s.dateOfBirth,
                  onChanged: (v) { s.dateOfBirth = v; widget.onChanged(); },
                ),
              ),
            ],
          ),
          _Field(
            ctrl: _placeOfBirthCtrl,
            label: 'Lieu de naissance',
            onChanged: (v) { s.placeOfBirth = v.isEmpty ? null : v; widget.onChanged(); },
          ),
          const SizedBox(height: 16),
          _SectionTitle('Situation familiale'),
          _DropdownField<String>(
            label: 'Situation familiale',
            value: s.situationFamiliale,
            items: const {
              'biparentale':        'Biparentale',
              'monoparentale_pere': 'Monoparentale (père)',
              'monoparentale_mere': 'Monoparentale (mère)',
              'orphelin_partiel':   'Orphelin partiel',
              'orphelin_total':     'Orphelin total',
              'tuteur':             'Sous tutelle',
            },
            onChanged: (v) { s.situationFamiliale = v; widget.onChanged(); },
          ),
          const SizedBox(height: 16),
          _SectionTitle('Statuts particuliers'),
          _CheckTile(
            label: 'Pensionnaire / Interne',
            value: s.isBoarder,
            onChanged: (v) { s.isBoarder = v!; widget.onChanged(); },
          ),
          _CheckTile(
            label: 'Affecté par le MEPSA/METP',
            value: s.isAffecte,
            onChanged: (v) { s.isAffecte = v!; widget.onChanged(); },
          ),
          _CheckTile(
            label: 'Bénéficie d\'une bourse',
            value: s.hasScholarship,
            onChanged: (v) { s.hasScholarship = v!; widget.onChanged(); },
          ),
          if (s.hasScholarship)
            _Field(
              label: 'Type de bourse',
              ctrl: _scholarshipTypeCtrl,
              onChanged: (v) { s.scholarshipType = v.isEmpty ? null : v; widget.onChanged(); },
            ),
          _CheckTile(
            label: 'Bénéficie d\'une aide sociale',
            value: s.hasSocialAid,
            onChanged: (v) { s.hasSocialAid = v!; widget.onChanged(); },
          ),
          const SizedBox(height: 16),
          _SectionTitle('Santé & Adresse'),
          _Field(
            ctrl: _allergiesCtrl,
            label: 'Allergies / Antécédents médicaux',
            onChanged: (v) { s.allergies = v.isEmpty ? null : v; widget.onChanged(); },
            maxLines: 2,
          ),
          _Field(
            ctrl: _addressCtrl,
            label: 'Adresse',
            onChanged: (v) { s.address = v.isEmpty ? null : v; widget.onChanged(); },
          ),
          _Field(
            ctrl: _cityCtrl,
            label: 'Ville',
            onChanged: (v) { s.city = v.isEmpty ? null : v; widget.onChanged(); },
          ),
        ],
      ),
    );
  }
}

// ─── Étape 2 — Parents / Tuteurs ─────────────────────────────────────────────

class _Step2Parents extends StatefulWidget {
  const _Step2Parents({required this.state, required this.onChanged});
  final _InscriptionState state;
  final VoidCallback onChanged;

  @override
  State<_Step2Parents> createState() => _Step2ParentsState();
}

class _Step2ParentsState extends State<_Step2Parents> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...widget.state.tutors.asMap().entries.map((e) => _TutorForm(
            index: e.key,
            tutor: e.value,
            onChanged: () {
              setState(() {});
              widget.onChanged();
            },
            onRemove: e.key > 0
                ? () {
                    setState(() => widget.state.tutors.removeAt(e.key));
                    widget.onChanged();
                  }
                : null,
          )),
          const SizedBox(height: 8),
          if (widget.state.tutors.length < 3)
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un tuteur / contact'),
              style: TextButton.styleFrom(foregroundColor: _kNavy),
              onPressed: () {
                setState(() => widget.state.tutors.add(_TutorEntry()));
                widget.onChanged();
              },
            ),
        ],
      ),
    );
  }
}

class _TutorForm extends StatefulWidget {
  const _TutorForm({
    required this.index,
    required this.tutor,
    required this.onChanged,
    this.onRemove,
  });
  final int          index;
  final _TutorEntry  tutor;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  State<_TutorForm> createState() => _TutorFormState();
}

class _TutorFormState extends State<_TutorForm> {
  late final _firstNameCtrl = TextEditingController(text: widget.tutor.firstName);
  late final _lastNameCtrl  = TextEditingController(text: widget.tutor.lastName);
  late final _phoneCtrl     = TextEditingController(text: widget.tutor.phonePrimary);
  late final _emailCtrl     = TextEditingController(text: widget.tutor.email ?? '');
  late final _profCtrl      = TextEditingController(text: widget.tutor.profession ?? '');

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _profCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t     = widget.tutor;
    final title = t.isPrimary
        ? 'Parent / tuteur principal'
        : 'Contact ${widget.index + 1}';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: t.isPrimary ? _kNavy.withValues(alpha: 0.3) : _kBorder,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: _kNavy,
                  ),
                ),
                const Spacer(),
                if (widget.onRemove != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: _kRed, size: 18),
                    onPressed: widget.onRemove,
                    tooltip: 'Supprimer',
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _Field(
                    ctrl: _firstNameCtrl,
                    label: 'Prénom *',
                    onChanged: (v) { t.firstName = v; widget.onChanged(); },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Field(
                    ctrl: _lastNameCtrl,
                    label: 'Nom *',
                    onChanged: (v) { t.lastName = v; widget.onChanged(); },
                  ),
                ),
              ],
            ),
            _DropdownField<String>(
              label: 'Lien de parenté',
              value: t.relationship,
              items: const {
                'pere':   'Père',
                'mere':   'Mère',
                'tuteur': 'Tuteur légal',
                'autre':  'Autre',
              },
              onChanged: (v) { t.relationship = v!; widget.onChanged(); },
            ),
            _Field(
              ctrl: _phoneCtrl,
              label: 'Téléphone *',
              keyboardType: TextInputType.phone,
              onChanged: (v) { t.phonePrimary = v; widget.onChanged(); },
            ),
            _Field(
              ctrl: _emailCtrl,
              label: 'Email',
              keyboardType: TextInputType.emailAddress,
              onChanged: (v) { t.email = v.isEmpty ? null : v; widget.onChanged(); },
            ),
            _Field(
              ctrl: _profCtrl,
              label: 'Profession',
              onChanged: (v) { t.profession = v.isEmpty ? null : v; widget.onChanged(); },
            ),
            _CheckTile(
              label: 'Contact d\'urgence',
              value: t.isEmergency,
              onChanged: (v) { setState(() => t.isEmergency = v!); widget.onChanged(); },
            ),
            if (!t.isPrimary)
              _CheckTile(
                label: 'Contact principal',
                value: t.isPrimary,
                onChanged: (v) { setState(() => t.isPrimary = v!); widget.onChanged(); },
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Étape 3 — Scolarité ─────────────────────────────────────────────────────

class _Step3Scolarite extends ConsumerStatefulWidget {
  const _Step3Scolarite({
    required this.state,
    required this.onChanged,
  });
  final _InscriptionState state;
  final VoidCallback onChanged;

  @override
  ConsumerState<_Step3Scolarite> createState() => _Step3ScolariteState();
}

class _Step3ScolariteState extends ConsumerState<_Step3Scolarite> {
  late final _prevSchoolCtrl = TextEditingController(
    text: widget.state.previousSchoolName ?? '',
  );
  late final _prevClassCtrl = TextEditingController(
    text: widget.state.previousClassName ?? '',
  );

  @override
  void dispose() {
    _prevSchoolCtrl.dispose();
    _prevClassCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s            = widget.state;
    final yearsAsync   = ref.watch(academicYearsProvider);
    final classesAsync = ref.watch(classesProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle('Type d\'inscription'),
          _DropdownField<String>(
            label: 'Type',
            value: s.inscriptionType,
            items: const {
              'new':           'Nouvelle inscription',
              'reinscription': 'Réinscription',
              'transfer':      'Transfert',
            },
            onChanged: (v) { s.inscriptionType = v!; widget.onChanged(); },
          ),
          const SizedBox(height: 12),
          _SectionTitle('Affectation'),
          yearsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error:   (e, _) => Text('Erreur : $e', style: const TextStyle(color: _kRed)),
            data:    (years) {
              if (years.isEmpty) {
                return const Text(
                  'Aucune année scolaire active.',
                  style: TextStyle(color: _kMuted),
                );
              }
              return _DropdownField<String>(
                label: 'Année scolaire *',
                value: s.academicYearId,
                items: {for (final y in years) y.id: y.label},
                onChanged: (v) { s.academicYearId = v; widget.onChanged(); },
              );
            },
          ),
          classesAsync.when(
            loading: () => const LinearProgressIndicator(),
            error:   (e, _) => Text('Erreur : $e', style: const TextStyle(color: _kRed)),
            data:    (classes) {
              if (classes.isEmpty) {
                return const Text(
                  'Aucune classe disponible.',
                  style: TextStyle(color: _kMuted),
                );
              }
              return _DropdownField<String>(
                label: 'Classe *',
                value: s.classId,
                items: {for (final c in classes) c.id: c.name},
                onChanged: (v) { s.classId = v; widget.onChanged(); },
              );
            },
          ),
          _CheckTile(
            label: 'Élève redoublant',
            value: s.isRepeating,
            onChanged: (v) { s.isRepeating = v!; widget.onChanged(); },
          ),
          if (s.inscriptionType == 'transfer') ...[
            const SizedBox(height: 12),
            _SectionTitle('École d\'origine'),
            _Field(
              ctrl: _prevSchoolCtrl,
              label: 'Nom de l\'école précédente',
              onChanged: (v) { s.previousSchoolName = v.isEmpty ? null : v; widget.onChanged(); },
            ),
            _Field(
              ctrl: _prevClassCtrl,
              label: 'Classe précédente',
              onChanged: (v) { s.previousClassName = v.isEmpty ? null : v; widget.onChanged(); },
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Étape 4 — Documents ─────────────────────────────────────────────────────

class _Step4Documents extends StatefulWidget {
  const _Step4Documents({required this.state, required this.onChanged});
  final _InscriptionState state;
  final VoidCallback onChanged;

  @override
  State<_Step4Documents> createState() => _Step4DocumentsState();
}

class _Step4DocumentsState extends State<_Step4Documents> {
  static const _docs = [
    'Extrait d\'acte de naissance',
    'Certificat de nationalité',
    'Certificat de résidence',
    'Bulletin de notes (année précédente)',
    'Certificat médical de bonne santé',
    'Photos d\'identité (2)',
    'Attestation de transfert (si transfert)',
    'Livret scolaire',
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _docs.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle('Pièces justificatives'),
                const Text(
                  'Cochez les documents fournis par la famille.',
                  style: TextStyle(color: _kMuted, fontSize: 13),
                ),
              ],
            ),
          );
        }
        final doc = _docs[i - 1];
        return CheckboxListTile(
          title: Text(doc, style: const TextStyle(fontSize: 14)),
          value: widget.state.checkedDocs.contains(doc),
          activeColor: _kGreen,
          onChanged: (v) {
            setState(() {
              if (v == true) {
                widget.state.checkedDocs.add(doc);
              } else {
                widget.state.checkedDocs.remove(doc);
              }
            });
            widget.onChanged();
          },
        );
      },
    );
  }
}

// ─── Étape 5 — Résumé ─────────────────────────────────────────────────────────

class _Step5Resume extends StatelessWidget {
  const _Step5Resume({required this.state});
  final _InscriptionState state;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle('Résumé de l\'inscription'),
          _ResumeCard(
            title: 'Élève',
            icon: Icons.person_outline,
            rows: [
              ('Prénom', state.firstName),
              ('Nom', state.lastName),
              ('Genre', state.gender == 'M' ? 'Masculin' : 'Féminin'),
              if (state.dateOfBirth != null) ('Date de naissance', state.dateOfBirth!),
              if (state.placeOfBirth != null) ('Lieu de naissance', state.placeOfBirth!),
              if (state.situationFamiliale != null)
                ('Situation familiale', state.situationFamiliale!),
            ],
          ),
          _ResumeCard(
            title: 'Parents / Tuteurs',
            icon: Icons.family_restroom,
            rows: state.tutors
                .where((t) => t.firstName.isNotEmpty)
                .map((t) => (
                  '${t.isPrimary ? "Principal" : "Contact"}',
                  '${t.firstName} ${t.lastName} (${t.relationship})',
                ))
                .toList(),
          ),
          _ResumeCard(
            title: 'Scolarité',
            icon: Icons.school_outlined,
            rows: [
              ('Type', switch (state.inscriptionType) {
                'new'           => 'Nouvelle inscription',
                'reinscription' => 'Réinscription',
                'transfer'      => 'Transfert',
                _               => state.inscriptionType,
              }),
              if (state.isRepeating) ('Statut', 'Redoublant'),
              if (state.previousSchoolName != null)
                ('École précédente', state.previousSchoolName!),
            ],
          ),
          _ResumeCard(
            title: 'Documents',
            icon: Icons.description_outlined,
            rows: state.checkedDocs.isEmpty
                ? [('Aucun document coché', '')]
                : state.checkedDocs.map((d) => (d, '✓')).toList(),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kGreen.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kGreen.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: _kGreen, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'L\'inscription sera créée avec le statut "En attente de validation". '
                    'Le directeur devra la valider pour qu\'elle devienne active.',
                    style: TextStyle(color: _kGreen, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({
    required this.title,
    required this.icon,
    required this.rows,
  });
  final String             title;
  final IconData           icon;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _kBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: _kNavy),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _kNavy,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const Divider(height: 12),
            ...rows.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 140,
                    child: Text(
                      r.$1,
                      style: const TextStyle(color: _kMuted, fontSize: 13),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      r.$2,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}

// ─── Widgets communs ──────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: _kNavy,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.ctrl,
    required this.label,
    required this.onChanged,
    this.keyboardType,
    this.maxLines = 1,
  });
  final TextEditingController ctrl;
  final String label;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        maxLines: maxLines,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _kBorder),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final String label;
  final T? value;
  final Map<T, String> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<T>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _kBorder),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        items: items.entries
            .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class _CheckTile extends StatelessWidget {
  const _CheckTile({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      title: Text(label, style: const TextStyle(fontSize: 14)),
      value: value,
      activeColor: _kGreen,
      dense: true,
      contentPadding: EdgeInsets.zero,
      onChanged: onChanged,
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: value != null
                ? DateTime.tryParse(value!) ?? DateTime(2010)
                : DateTime(2010),
            firstDate: DateTime(1990),
            lastDate: DateTime.now(),
          );
          if (picked != null) {
            onChanged(picked.toIso8601String().substring(0, 10));
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: const Icon(Icons.calendar_today, size: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _kBorder),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          child: Text(
            value ?? 'Sélectionner',
            style: TextStyle(
              color: value != null ? _kText : _kMuted,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
