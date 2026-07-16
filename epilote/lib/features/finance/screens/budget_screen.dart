import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../../navigation/providers/permissions_provider.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../../structure/providers/academic_year_context.dart';
import '../../vie_scolaire/widgets/vs_kit.dart';
import '../../vie_scolaire/widgets/vs_form_chrome.dart';
import '../providers/budget_provider.dart';

part 'budget_form.dart';

const _kSlug = 'budget';

// ════════════════════════════════════════════════════════════════════════════
//  BUDGET — lignes budgétaires prévu vs réalisé (sensible). KPI hero (budgété,
//  réalisé, écart, exécution) → lignes avec barres de comparaison → formulaire.
// ════════════════════════════════════════════════════════════════════════════
class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => const ModuleScaffold(
        slug: _kSlug,
        title: 'Budget',
        child: _Body(),
      );
}

class _Body extends ConsumerStatefulWidget {
  const _Body();
  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  void _openForm({BudgetLine? line}) => showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _BudgetForm(line: line),
      );

  Future<void> _delete(BudgetLine l) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Supprimer cette ligne ?'),
        content: Text('La ligne « ${l.categoryLabel} » sera supprimée.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await runModuleWrite(context, () => deleteBudgetLine(l.id),
        success: 'Ligne supprimée');
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(budgetLinesProvider);
    final canCreate = ref.watch(canProvider((slug: _kSlug, action: 'create')));
    final canEdit = ref.watch(canProvider((slug: _kSlug, action: 'update')));
    final canDelete = ref.watch(canProvider((slug: _kSlug, action: 'delete')));
    final readOnly = ref.watch(yearReadOnlyProvider);

    return async.when(
      skipLoadingOnReload: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur : $e')),
      data: (all) {
        final budgeted = all.fold(0, (a, l) => a + l.budgeted);
        final actual = all.fold(0, (a, l) => a + l.actual);
        final gap = budgeted - actual;
        final rate = budgeted == 0 ? 0 : actual * 100 ~/ budgeted;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            VsHeader(
              title: 'Budget prévisionnel',
              subtitle: 'Prévu vs réalisé par poste — année en cours',
              trailing: (canCreate && !readOnly)
                  ? _AddBtn(label: 'Ligne', onTap: () => _openForm())
                  : null,
            ),
            const SizedBox(height: 20),
            VsHeroKpis(cards: [
              (Icons.account_balance_wallet_rounded, 'Budgété',
                  fmtCompact(budgeted), kNavy, 'FCFA prévus'),
              (Icons.payments_rounded, 'Réalisé', fmtCompact(actual),
                  const Color(0xFFF59E0B), 'FCFA engagés'),
              (Icons.savings_rounded, 'Disponible', fmtCompact(gap),
                  gap < 0 ? kRed : kGreen, gap < 0 ? 'dépassement' : 'restant'),
              (Icons.speed_rounded, 'Exécution', '$rate%',
                  rate > 100 ? kRed : const Color(0xFF8B5CF6), 'du budget'),
            ]),
            const SizedBox(height: 18),
            if (all.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 30),
                child: AdminEmptyState(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Aucune ligne budgétaire',
                  message:
                      'Définissez les postes du budget (prévu) et suivez leur '
                      'réalisation au fil de l\'année.',
                  actionLabel:
                      (canCreate && !readOnly) ? 'Nouvelle ligne' : null,
                  onAction: (canCreate && !readOnly) ? () => _openForm() : null,
                ),
              )
            else
              for (final l in all)
                _BudgetCard(
                  line: l,
                  canEdit: canEdit && !readOnly,
                  canDelete: canDelete && !readOnly,
                  onEdit: () => _openForm(line: l),
                  onDelete: () => _delete(l),
                ),
            const SizedBox(height: 24),
          ]),
        );
      },
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({
    required this.line,
    required this.canEdit,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
  });
  final BudgetLine line;
  final bool canEdit, canDelete;
  final VoidCallback onEdit, onDelete;
  @override
  Widget build(BuildContext context) {
    final l = line;
    final color = l.overBudget
        ? kRed
        : (l.rate >= 0.9 ? const Color(0xFFF59E0B) : kGreen);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(l.categoryLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 14.5, fontWeight: FontWeight.w800)),
          ),
          Text('${fmtXaf(l.actual)} / ${fmtXaf(l.budgeted)}',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, color: color)),
          if (canEdit || canDelete)
            PopupMenuButton<String>(
              icon:
                  Icon(Icons.more_vert_rounded, size: 20, color: kTextMuted),
              onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
              itemBuilder: (ctx) => [
                if (canEdit)
                  const PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit_outlined, size: 16),
                        SizedBox(width: 8),
                        Text('Modifier'),
                      ])),
                if (canDelete)
                  PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete_outline_rounded, size: 16, color: kRed),
                        const SizedBox(width: 8),
                        Text('Supprimer', style: TextStyle(color: kRed)),
                      ])),
              ],
            )
          else
            const SizedBox(width: 12),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(
            value: l.rate.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: kSurface,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: 6),
        Text(
            l.overBudget
                ? 'Dépassement de ${fmtXaf(-l.remaining)} (${(l.rate * 100).round()}%)'
                : '${fmtXaf(l.remaining)} disponibles · ${(l.rate * 100).round()}% exécuté',
            style: TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.w600, color: color)),
        if ((l.notes ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(l.notes!.trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: kTextMuted)),
        ],
      ]),
    );
  }
}

class _AddBtn extends StatelessWidget {
  const _AddBtn({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [kNavyDark, kNavy],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.add_rounded, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      );
}
