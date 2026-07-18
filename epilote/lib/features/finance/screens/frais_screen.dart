import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/write_identity.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../../navigation/providers/permissions_provider.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../../structure/providers/academic_year_context.dart';
import '../../vie_scolaire/widgets/vs_kit.dart';
import '../../vie_scolaire/widgets/vs_form_chrome.dart';
import '../providers/frais_provider.dart';

part 'frais_form.dart';

const _kSlug = 'frais-scolarite';

// ════════════════════════════════════════════════════════════════════════════
//  FRAIS DE SCOLARITÉ — barèmes de frais de l'école. KPI hero → liste groupée
//  par type → formulaire (nom, type, montant, échéance, niveau). 100% offline.
// ════════════════════════════════════════════════════════════════════════════
class FraisScreen extends ConsumerWidget {
  const FraisScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => const ModuleScaffold(
        slug: _kSlug,
        title: 'Frais de scolarité',
        child: _Body(),
      );
}

class _Body extends ConsumerStatefulWidget {
  const _Body();
  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  void _openForm({FeeStructure? fee}) => showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _FeeForm(fee: fee),
      );

  Future<void> _delete(FeeStructure f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Supprimer ce barème ?'),
        content: Text('« ${f.name} » (${fmtXaf(f.amount)}) sera retiré.'),
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
    await runModuleWrite(context, () => deleteFeeStructure(f.id),
        success: 'Barème supprimé');
  }

  int _maxOf(List<FeeStructure> all, String type) {
    final v = all.where((f) => f.feeType == type).map((f) => f.amount);
    return v.isEmpty ? 0 : v.reduce((a, b) => a > b ? a : b);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(feeStructuresProvider);
    final canCreate = ref.watch(canProvider((slug: _kSlug, action: 'create')));
    final canEdit = ref.watch(canProvider((slug: _kSlug, action: 'update')));
    final canDelete = ref.watch(canProvider((slug: _kSlug, action: 'delete')));
    final readOnly = ref.watch(yearReadOnlyProvider);

    return async.when(
      skipLoadingOnReload: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur : $e')),
      data: (all) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            VsHeader(
              title: 'Barèmes de frais',
              subtitle: 'Frais de scolarité de l\'établissement (année en cours)',
              trailing: (canCreate && !readOnly)
                  ? _AddBtn(label: 'Barème', onTap: () => _openForm())
                  : null,
            ),
            const SizedBox(height: 20),
            VsHeroKpis(cards: [
              (Icons.request_quote_rounded, 'Barèmes', '${all.length}', kNavy,
                  'actifs'),
              (Icons.how_to_reg_rounded, 'Inscription',
                  fmtCompact(_maxOf(all, 'inscription')),
                  const Color(0xFF0EA5E9), 'FCFA'),
              (Icons.event_repeat_rounded, 'Mensualité',
                  fmtCompact(_maxOf(all, 'mensualite')), kGreen, 'FCFA / mois'),
              (Icons.school_rounded, 'Examens',
                  fmtCompact(_maxOf(all, 'frais_examens')),
                  const Color(0xFF8B5CF6), 'FCFA'),
            ]),
            const SizedBox(height: 18),
            if (all.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 30),
                child: AdminEmptyState(
                  icon: Icons.request_quote_outlined,
                  title: 'Aucun barème',
                  message:
                      'Définissez les frais de scolarité (inscription, mensualité, '
                      'examens) pour pouvoir enregistrer les paiements des élèves.',
                  actionLabel:
                      (canCreate && !readOnly) ? 'Nouveau barème' : null,
                  onAction: (canCreate && !readOnly) ? () => _openForm() : null,
                ),
              )
            else
              for (final f in all)
                _FeeCard(
                  fee: f,
                  canEdit: canEdit && !readOnly,
                  canDelete: canDelete && !readOnly,
                  onEdit: () => _openForm(fee: f),
                  onDelete: () => _delete(f),
                ),
            const SizedBox(height: 24),
          ]),
        );
      },
    );
  }
}

class _FeeCard extends StatelessWidget {
  const _FeeCard({
    required this.fee,
    required this.canEdit,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
  });
  final FeeStructure fee;
  final bool canEdit, canDelete;
  final VoidCallback onEdit, onDelete;
  @override
  Widget build(BuildContext context) {
    final f = fee;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
              color: kNavy.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.request_quote_rounded, size: 20, color: kNavy),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(f.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: kNavy.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(feeTypeLabel(f.feeType),
                        style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: kNavy)),
                  ),
                ]),
                const SizedBox(height: 3),
                Text(
                    '${f.levelName ?? 'Toute l\'école'}'
                    '${f.dueDay != null ? ' · échéance le ${f.dueDay}' : ''}',
                    style: TextStyle(fontSize: 12, color: kTextMuted)),
              ]),
        ),
        Text(fmtXaf(f.amount),
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800, color: kGreen)),
        if (canEdit || canDelete)
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, size: 20, color: kTextMuted),
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
