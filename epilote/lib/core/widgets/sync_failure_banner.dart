import 'package:flutter/material.dart';

import '../../core/widgets/admin_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/powersync/sync_failures_provider.dart';

Color get _kAlertRed => kRed;
const _kAlertBg = Color(0xFFFEF2F2);
const _kAlertText = Color(0xFF991B1B);
const _kBorder = Color(0xFFFECACA);

/// Deux chiffres.
String _pad2(int n) => n.toString().padLeft(2, '0');

/// « le 04/07 à 14:32 »
String _formatAt(DateTime dt) =>
    'le ${_pad2(dt.day)}/${_pad2(dt.month)} à ${_pad2(dt.hour)}:${_pad2(dt.minute)}';

/// Bandeau d'alerte affiché en haut du shell (personnel uniquement) quand des
/// écritures locales ont été DÉFINITIVEMENT perdues à la synchro. Rend la perte
/// visible et acquittable — cf [[sync_failures_provider]] / connecteur PowerSync.
class SyncFailureBanner extends ConsumerWidget {
  const SyncFailureBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final failures = ref.watch(syncFailuresProvider).valueOrNull ?? const [];
    if (failures.isEmpty) return const SizedBox.shrink();

    final n = failures.length;
    return Material(
      color: _kAlertBg,
      child: InkWell(
        onTap: () => _showDetails(context, ref, failures),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _kBorder)),
          ),
          child: Row(
            children: [
              Icon(Icons.sync_problem_rounded, size: 18, color: _kAlertRed),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  n == 1
                      ? "Une donnée n'a pas pu être synchronisée et n'a pas été enregistrée."
                      : "$n données n'ont pas pu être synchronisées et n'ont pas été enregistrées.",
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _kAlertText,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () => _showDetails(context, ref, failures),
                style: TextButton.styleFrom(
                  foregroundColor: _kAlertRed,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Voir',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetails(
    BuildContext context,
    WidgetRef ref,
    List<SyncFailure> failures,
  ) {
    showDialog<void>(
      context: context,
      builder: (_) => _SyncFailureDialog(failures: failures),
    );
  }
}

class _SyncFailureDialog extends ConsumerWidget {
  const _SyncFailureDialog({required this.failures});
  final List<SyncFailure> failures;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // On garde la liste passée à l'ouverture (snapshot) pour un rendu stable ;
    // l'acquittement retire les lignes du bandeau via le provider.
    final live = ref.watch(syncFailuresProvider).valueOrNull ?? failures;
    final items = live.isEmpty ? failures : live;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.sync_problem_rounded, color: _kAlertRed, size: 22),
          const SizedBox(width: 10),
          const Expanded(child: Text('Données non synchronisées')),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ces informations ont été refusées par le serveur et '
              "n'ont pas été enregistrées. Veuillez les ressaisir.",
              style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 14),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final f in items) _FailureRow(failure: f),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await acknowledgeAllSyncFailures();
            if (context.mounted) Navigator.of(context).pop();
          },
          child: const Text("J'ai compris"),
        ),
      ],
    );
  }
}

class _FailureRow extends StatelessWidget {
  const _FailureRow({required this.failure});
  final SyncFailure failure;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _kAlertBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  failure.summary.isEmpty ? 'Donnée' : failure.summary,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: _kAlertText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatAt(failure.at),
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Marquer comme vu',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.check_circle_outline_rounded,
                size: 20, color: _kAlertRed),
            onPressed: () => acknowledgeSyncFailure(failure.id),
          ),
        ],
      ),
    );
  }
}
