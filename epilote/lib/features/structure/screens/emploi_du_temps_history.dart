import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../providers/edt_audit_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  HISTORIQUE DE L'EMPLOI DU TEMPS — tiroir latéral droit listant « qui a modifié
//  quoi, quand » (table `audit_logs`, alimentée par le trigger serveur, lue
//  offline). Lecture seule, chronologique (plus récent d'abord).
// ════════════════════════════════════════════════════════════════════════════
void openEdtHistoryDrawer(BuildContext context) {
  showGeneralDialog(
    context: context,
    barrierLabel: 'Historique de l\'emploi du temps',
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (ctx, _, _) => const Align(
      alignment: Alignment.centerRight,
      child: _EdtHistoryView(),
    ),
    transitionBuilder: (ctx, anim, _, child) => SlideTransition(
      position: Tween(begin: const Offset(1, 0), end: Offset.zero)
          .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
      child: child,
    ),
  );
}

class _EdtHistoryView extends ConsumerWidget {
  const _EdtHistoryView();

  Color _actionColor(String action) => switch (action) {
        'INSERT' => kGreen,
        'DELETE' => kRed,
        _ => kNavy,
      };
  IconData _actionIcon(String action) => switch (action) {
        'INSERT' => Icons.add_circle_outline_rounded,
        'DELETE' => Icons.remove_circle_outline_rounded,
        _ => Icons.edit_outlined,
      };

  String _when(DateTime? at) {
    if (at == null) return '';
    final now = DateTime.now();
    final diff = now.difference(at);
    if (diff.inMinutes < 1) return 'à l\'instant';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'il y a ${diff.inDays} j';
    return '${at.day.toString().padLeft(2, '0')}/'
        '${at.month.toString().padLeft(2, '0')}/${at.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(edtAuditProvider);
    final w = MediaQuery.of(context).size.width;
    return Material(
      color: Colors.white,
      child: SizedBox(
        width: w < 560 ? w : 500,
        height: double.infinity,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
            decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: kBorder))),
            child: Row(children: [
              Icon(Icons.history_rounded, size: 19, color: kNavy),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Historique des modifications',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: kTextPrimary)),
              ),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20)),
            ]),
          ),
          Expanded(
            child: async.when(
              skipLoadingOnReload: true,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erreur : $e')),
              data: (entries) {
                if (entries.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: AdminEmptyState(
                        icon: Icons.history_toggle_off_rounded,
                        title: 'Aucune modification',
                        message:
                            'Les changements de l\'emploi du temps (créneaux, '
                            'annulations, publications) apparaîtront ici.',
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final e = entries[i];
                    final c = _actionColor(e.action);
                    return Container(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: kBorder),
                      ),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: c.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(_actionIcon(e.action), size: 16, color: c),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(e.summary,
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: kTextPrimary)),
                                const SizedBox(height: 2),
                                Text(
                                    '${e.actionLabel} · '
                                    '${e.actorName ?? 'Agent'}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 11.5, color: kTextMuted)),
                              ]),
                        ),
                        const SizedBox(width: 8),
                        Text(_when(e.at),
                            style: TextStyle(
                                fontSize: 11, color: kTextMuted)),
                      ]),
                    );
                  },
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}
