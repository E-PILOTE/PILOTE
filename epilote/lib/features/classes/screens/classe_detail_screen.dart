import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../data/models/class_model.dart';
import '../../../features/structure/providers/academic_year_provider.dart';
import '../providers/class_provider.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
const _kNavy   = Color(0xFF1E3A5F);
const _kGreen  = Color(0xFF009A44);
const _kGold   = Color(0xFFFBBC04);
const _kRed    = Color(0xFFDC2626);
const _kCard   = Colors.white;
const _kText   = Color(0xFF0F172A);
const _kMuted  = Color(0xFF64748B);

class ClasseDetailScreen extends ConsumerWidget {
  const ClasseDetailScreen({super.key, required this.classId});
  final String classId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classAsync = ref.watch(classByIdProvider(classId));

    return AppShell(
      title: classAsync.valueOrNull?.name ?? 'Classe',
      child: _DetailBody(classId: classId),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.classId});
  final String classId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classAsync       = ref.watch(classByIdProvider(classId));
    final enrollmentsAsync = ref.watch(classEnrollmentsProvider(classId));
    final yearAsync        = ref.watch(currentAcademicYearProvider);

    return classAsync.when(
      loading: () => const LoadingWidget(),
      error:   (e, _) => Center(child: Text('Erreur : $e')),
      data:    (classe) {
        if (classe == null) {
          return const Center(child: Text('Classe introuvable'));
        }
        return _ClassContent(
          classe:          classe,
          enrollmentsAsync: enrollmentsAsync,
          yearLabel:       yearAsync.valueOrNull?.label ?? '—',
        );
      },
    );
  }
}

// ─── Contenu ──────────────────────────────────────────────────────────────────

class _ClassContent extends StatelessWidget {
  const _ClassContent({
    required this.classe,
    required this.enrollmentsAsync,
    required this.yearLabel,
  });
  final ClassModel                              classe;
  final AsyncValue<List<ClassEnrollmentModel>>  enrollmentsAsync;
  final String                                  yearLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Fiche classe ──────────────────────────────────────────────────
        _ClassInfoCard(classe: classe, yearLabel: yearLabel),
        const SizedBox(height: 4),

        // ── Titre liste élèves ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
          child: Row(
            children: [
              const Icon(Icons.people_rounded, size: 18, color: _kNavy),
              const SizedBox(width: 8),
              const Text(
                'Élèves inscrits',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _kText,
                ),
              ),
              const Spacer(),
              enrollmentsAsync.whenOrNull(
                data: (list) => Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: _kNavy.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${list.length}',
                    style: const TextStyle(
                      color: _kNavy,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ) ?? const SizedBox.shrink(),
            ],
          ),
        ),

        // ── Liste élèves ──────────────────────────────────────────────────
        Expanded(
          child: enrollmentsAsync.when(
            loading: () => const LoadingWidget(),
            error:   (e, _) => Center(child: Text('Erreur : $e')),
            data:    (enrollments) => enrollments.isEmpty
                ? const _EmptyEnrollments()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 80),
                    itemCount: enrollments.length,
                    itemBuilder: (_, i) =>
                        _StudentTile(enrollment: enrollments[i], rank: i + 1),
                  ),
          ),
        ),
      ],
    );
  }
}

// ─── Fiche classe ─────────────────────────────────────────────────────────────

class _ClassInfoCard extends StatelessWidget {
  const _ClassInfoCard({required this.classe, required this.yearLabel});
  final ClassModel classe;
  final String     yearLabel;

  @override
  Widget build(BuildContext context) {
    final fill      = classe.fillRate ?? 0.0;
    final fillColor = fill > 1.0 ? _kRed
        : fill > 0.85 ? _kGold
        : _kGreen;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nom + année
          Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: _kNavy,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.class_rounded,
                    color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(classe.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: _kText,
                        )),
                    Text('Année $yearLabel',
                        style: const TextStyle(
                            fontSize: 13, color: _kMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Infos
          Wrap(
            spacing: 24,
            runSpacing: 10,
            children: [
              if (classe.room != null)
                _InfoPair(
                    icon: Icons.room_rounded,
                    label: 'Salle',
                    value: classe.room!),
              _InfoPair(
                  icon: Icons.people_rounded,
                  label: 'Occupation',
                  value: classe.fillRateLabel,
                  valueColor: fillColor),
              if (classe.capacity != null)
                _InfoPair(
                    icon: Icons.event_seat_rounded,
                    label: 'Capacité',
                    value: '${classe.capacity}'),
            ],
          ),

          // Barre remplissage
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: fill.clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(fillColor),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${(fill * 100).round()}%',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: fillColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoPair extends StatelessWidget {
  const _InfoPair({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });
  final IconData icon;
  final String   label;
  final String   value;
  final Color?   valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: _kMuted),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(
                fontSize: 10, color: _kMuted)),
            Text(value, style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor ?? _kText)),
          ],
        ),
      ],
    );
  }
}

// ─── Tuile élève ──────────────────────────────────────────────────────────────

class _StudentTile extends StatelessWidget {
  const _StudentTile({required this.enrollment, required this.rank});
  final ClassEnrollmentModel enrollment;
  final int                  rank;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(
        enrollment.studentFirstName, enrollment.studentLastName);
    final genderColor =
        enrollment.studentGender == 'M' ? _kNavy : _kGreen;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: genderColor.withValues(alpha: 0.15),
          child: Text(
            initials,
            style: TextStyle(
                color: genderColor,
                fontSize: 13,
                fontWeight: FontWeight.w700),
          ),
        ),
        title: Text(
          enrollment.studentFullName,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: _kText),
        ),
        subtitle: enrollment.studentMatricule != null
            ? Text(
                'Matricule : ${enrollment.studentMatricule}',
                style: const TextStyle(fontSize: 12, color: _kMuted),
              )
            : null,
        trailing: Text(
          '$rank',
          style: const TextStyle(
              fontSize: 14, color: _kMuted, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  String _initials(String? first, String? last) {
    final f = first?.isNotEmpty == true ? first![0].toUpperCase() : '';
    final l = last?.isNotEmpty  == true ? last![0].toUpperCase()  : '';
    return '$f$l';
  }
}

// ─── État vide ────────────────────────────────────────────────────────────────

class _EmptyEnrollments extends StatelessWidget {
  const _EmptyEnrollments();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline_rounded,
              size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Text('Aucun élève inscrit',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600,
                  color: _kText)),
          const SizedBox(height: 6),
          Text(
            'Utilisez le module Inscriptions pour affecter\ndes élèves à cette classe.',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
