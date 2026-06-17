import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/routes.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../../../data/models/class_model.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/classes/providers/class_provider.dart';
import '../../../features/structure/providers/academic_year_context.dart';
import '../../../services/powersync/powersync_service.dart';
import 'add_inscription_screen.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
const _kNavy   = Color(0xFF1E3A5F);
const _kGreen  = Color(0xFF009A44);
const _kGold   = Color(0xFFFBBC04);
const _kRed    = Color(0xFFDC2626);
const _kMuted  = Color(0xFF64748B);
const _kText   = Color(0xFF0F172A);

// Provider inscriptions validées (actives) de l'école
final _validatedEnrollmentsProvider = StreamProvider.autoDispose
    .family<List<ClassEnrollmentModel>, String>((ref, schoolId) {
  return db
      .watch(
        '''
        SELECT ce.*,
               s.first_name,
               s.last_name,
               s.matricule,
               s.photo_url,
               s.gender
        FROM   class_enrollments ce
        JOIN   students s ON s.id = ce.student_id
        WHERE  ce.school_id = ?
        AND    ce.status    = 'active'
        ORDER  BY ce.validated_at DESC
        LIMIT  100
        ''',
        parameters: [schoolId],
      )
      .map((rows) => rows.map(ClassEnrollmentModel.fromMap).toList());
});

// ─── Screen ───────────────────────────────────────────────────────────────────

class InscriptionsScreen extends ConsumerWidget {
  const InscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readOnly = ref.watch(yearReadOnlyProvider);
    return ModuleScaffold(
      slug: 'inscriptions',
      title: 'Inscriptions',
      actions: [
        // Année archivée/non courante → aucune écriture possible (verrou année).
        if (readOnly)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Tooltip(
              message: 'Année en lecture seule',
              child: Icon(Icons.lock_clock_rounded, color: _kGold, size: 20),
            ),
          )
        else
          PermissionGate(
            slug: 'inscriptions',
            action: 'create',
            child: IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Nouvelle inscription',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  fullscreenDialog: true,
                  builder: (_) => const AddInscriptionScreen(),
                ),
              ),
            ),
          ),
      ],
      child: const _InscriptionsBody(),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _InscriptionsBody extends ConsumerWidget {
  const _InscriptionsBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingEnrollmentsProvider);
    final profile      = ref.watch(authNotifierProvider).valueOrNull;

    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(pendingAsync: pendingAsync),
          const TabBar(
            labelColor: _kNavy,
            unselectedLabelColor: _kMuted,
            indicatorColor: _kGreen,
            tabs: [
              Tab(text: 'En attente'),
              Tab(text: 'Validées'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _PendingList(pendingAsync: pendingAsync),
                _ValidatedList(schoolId: profile?.schoolId ?? ''),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.pendingAsync});
  final AsyncValue<List<ClassEnrollmentModel>> pendingAsync;

  @override
  Widget build(BuildContext context) {
    final count = pendingAsync.valueOrNull?.length ?? 0;
    return Container(
      color: _kNavy,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Inscriptions',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  count > 0
                      ? '$count inscription(s) en attente de validation'
                      : 'Aucune inscription en attente',
                  style: TextStyle(
                    color: count > 0 ? _kGold : Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (count > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _kGold,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: _kNavy,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── En attente ───────────────────────────────────────────────────────────────

class _PendingList extends ConsumerWidget {
  const _PendingList({required this.pendingAsync});
  final AsyncValue<List<ClassEnrollmentModel>> pendingAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return pendingAsync.when(
      loading: () => const LoadingWidget(),
      error:   (e, _) => _ErrorView(message: e.toString()),
      data:    (items) {
        if (items.isEmpty) {
          return const _EmptyState(
            icon: Icons.check_circle_outline,
            message: 'Aucune inscription en attente',
            sub: 'Toutes les inscriptions ont été traitées.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _PendingCard(
            enrollment: items[i],
            validatedBy: ref.read(authNotifierProvider).valueOrNull?.id ?? '',
          ),
        );
      },
    );
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({
    required this.enrollment,
    required this.validatedBy,
  });
  final ClassEnrollmentModel enrollment;
  final String validatedBy;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _kNavy.withValues(alpha: 0.1),
                  child: Text(
                    (enrollment.studentFirstName?.isNotEmpty == true)
                        ? enrollment.studentFirstName![0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: _kNavy,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        enrollment.studentFullName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: _kText,
                        ),
                      ),
                      Text(
                        enrollment.inscriptionTypeLabel,
                        style: const TextStyle(fontSize: 12, color: _kMuted),
                      ),
                    ],
                  ),
                ),
                _TypeBadge(type: enrollment.inscriptionType),
              ],
            ),
            if (enrollment.previousSchoolName != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.school_outlined, size: 14, color: _kMuted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Venant de : ${enrollment.previousSchoolName}',
                      style: const TextStyle(fontSize: 12, color: _kMuted),
                    ),
                  ),
                ],
              ),
            ],
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.close, size: 16, color: _kRed),
                  label: const Text('Rejeter', style: TextStyle(color: _kRed)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _kRed),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => _showRejectDialog(context),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Valider'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => _validate(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _validate(BuildContext context) async {
    try {
      await validateEnrollment(
        enrollmentId: enrollment.id,
        validatedBy: validatedBy,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inscription validée'),
            backgroundColor: _kGreen,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: _kRed),
        );
      }
    }
  }

  Future<void> _showRejectDialog(BuildContext context) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rejeter l\'inscription'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Motif du rejet',
            hintText: 'Ex. : Dossier incomplet, quota atteint…',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _kRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rejeter', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      try {
        await rejectEnrollment(
          enrollmentId: enrollment.id,
          rejectionReason: controller.text.trim().isEmpty
              ? 'Aucun motif précisé'
              : controller.text.trim(),
          validatedBy: validatedBy,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Inscription rejetée')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur : $e'), backgroundColor: _kRed),
          );
        }
      }
    }
    controller.dispose();
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});
  final String type;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (type) {
      'new'           => ('Nouvelle', _kGreen),
      'reinscription' => ('Réinscription', _kNavy),
      'transfer'      => ('Transfert', _kGold),
      _               => (type, _kMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─── Validées ─────────────────────────────────────────────────────────────────

class _ValidatedList extends ConsumerWidget {
  const _ValidatedList({required this.schoolId});
  final String schoolId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (schoolId.isEmpty) return const SizedBox.shrink();

    final enrollmentsAsync = ref.watch(_validatedEnrollmentsProvider(schoolId));

    return enrollmentsAsync.when(
      loading: () => const LoadingWidget(),
      error:   (e, _) => _ErrorView(message: e.toString()),
      data:    (items) {
        if (items.isEmpty) {
          return const _EmptyState(
            icon: Icons.people_outline,
            message: 'Aucune inscription validée',
            sub: 'Les nouvelles inscriptions validées apparaîtront ici.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _ValidatedCard(enrollment: items[i]),
        );
      },
    );
  }
}

class _ValidatedCard extends StatelessWidget {
  const _ValidatedCard({required this.enrollment});
  final ClassEnrollmentModel enrollment;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _kGreen.withValues(alpha: 0.1),
          child: Text(
            (enrollment.studentFirstName?.isNotEmpty == true)
                ? enrollment.studentFirstName![0].toUpperCase()
                : '?',
            style: const TextStyle(
              color: _kGreen,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          enrollment.studentFullName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          enrollment.inscriptionTypeLabel,
          style: const TextStyle(fontSize: 12, color: _kMuted),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (enrollment.studentMatricule != null)
              Text(
                enrollment.studentMatricule!,
                style: const TextStyle(fontSize: 11, color: _kMuted),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.check_circle, color: _kGreen, size: 18),
          ],
        ),
        onTap: () => context.push(
          Routes.eleveDetail.replaceFirst(':id', enrollment.studentId),
        ),
      ),
    );
  }
}

// ─── Widgets utilitaires ─────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.message,
    required this.sub,
  });
  final IconData icon;
  final String   message;
  final String   sub;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: _kMuted.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _kText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              sub,
              style: const TextStyle(color: _kMuted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          style: const TextStyle(color: _kRed),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
