import 'package:flutter/material.dart';

import '../../core/widgets/admin_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/powersync/sync_failures_provider.dart';

Color get _kAlertRed => kRed;
Color get _kAlertBg => kRed.withValues(alpha: 0.12);
const _kAlertText = Color(0xFF991B1B);
const _kBorder = Color(0xFFFECACA);

// Le blocage n'est pas une perte : il ne se peint donc pas en rouge « données
// détruites », mais en orange « action requise ». La couleur fait partie du
// message — un bandeau rouge fait ressaisir, un orange fait mettre à jour.
const _kBlocage = Color(0xFFFF6B35);
const _kBlocageBg = Color(0x1AFF6B35);
const _kBlocageBorder = Color(0xFFFFD5C2);
const _kBlocageText = Color(0xFF9A3412);

/// Deux chiffres.
String _pad2(int n) => n.toString().padLeft(2, '0');

/// « le 04/07 à 14:32 »
String _formatAt(DateTime dt) =>
    'le ${_pad2(dt.day)}/${_pad2(dt.month)} à ${_pad2(dt.hour)}:${_pad2(dt.minute)}';

/// Bandeau d'alerte affiché en haut du shell (personnel uniquement).
///
/// ⚠️ DEUX MESSAGES, JAMAIS LE MÊME MOT :
///   • BLOCAGE — la file d'envoi de ce poste est arrêtée (le serveur ne
///     reconnaît plus une colonne : l'application est en retard). **Rien n'est
///     perdu.** Il n'y a rien à ressaisir, il faut mettre à jour. C'est le pire
///     défaut d'un produit hors-ligne : sans ce bandeau, l'école travaille
///     normalement pendant que plus rien ne remonte.
///   • PERTE — le serveur a refusé définitivement, la transaction a été
///     abandonnée : **il faut ressaisir**.
///
/// Dire « perdu » sur un blocage ferait ressaisir une école pour rien.
class SyncFailureBanner extends ConsumerWidget {
  const SyncFailureBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final failures = ref.watch(syncFailuresProvider).valueOrNull ?? const [];
    if (failures.isEmpty) return const SizedBox.shrink();

    // Le blocage prime : il concerne TOUT l'envoi du poste, pas une écriture.
    final blocage = failures.where((f) => f.estBlocage).toList();
    final pertes = failures.where((f) => !f.estBlocage).toList();
    final estBloque = blocage.isNotEmpty;
    final n = pertes.length;

    return Material(
      color: estBloque ? _kBlocageBg : _kAlertBg,
      child: InkWell(
        onTap: () => _showDetails(context, ref, failures),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(
                    color: estBloque ? _kBlocageBorder : _kBorder)),
          ),
          child: Row(
            children: [
              Icon(estBloque ? Icons.cloud_off_rounded : Icons.sync_problem_rounded,
                  size: 18, color: estBloque ? _kBlocage : _kAlertRed),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  estBloque
                      ? "Ce poste n'envoie plus rien au serveur. Rien n'est perdu : "
                          "vos saisies repartiront dès la mise à jour de l'application."
                      : n == 1
                          ? "Une donnée n'a pas pu être synchronisée et n'a pas été enregistrée."
                          : "$n données n'ont pas pu être synchronisées et n'ont pas été enregistrées.",
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: estBloque ? _kBlocageText : _kAlertText,
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

    final bloques = items.where((f) => f.estBlocage).toList();
    final pertes = items.where((f) => !f.estBlocage).toList();
    final estBloque = bloques.isNotEmpty;

    return AlertDialog(
      title: Row(
        children: [
          Icon(estBloque ? Icons.cloud_off_rounded : Icons.sync_problem_rounded,
              color: estBloque ? _kBlocage : _kAlertRed, size: 22),
          const SizedBox(width: 10),
          Expanded(
              child: Text(estBloque
                  ? 'Envoi interrompu'
                  : 'Données non synchronisées')),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ⚠️ NE JAMAIS dire « ressaisir » sur un blocage : rien n'est
            // perdu, et une école qui ressaisirait créerait des doublons le
            // jour où la file repart.
            if (estBloque)
              const Text(
                'Ce poste ne parvient plus à envoyer ses données au serveur, '
                "parce que l'application est en retard sur celui-ci. "
                
                "Rien n'est perdu : tout ce que vous saisissez reste en "
                'attente et partira automatiquement après la mise à jour. '
                'Ne ressaisissez rien.',
                style: TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.5),
              ),
            if (estBloque && pertes.isNotEmpty) const SizedBox(height: 14),
            if (pertes.isNotEmpty)
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
            // N'acquitte que les PERTES. Un blocage disparaît quand la synchro
            // repart, pas quand on clique — sinon le poste redevient muet.
            if (pertes.isNotEmpty) await acknowledgeAllSyncFailures();
            if (context.mounted) Navigator.of(context).pop();
          },
          child: Text(estBloque && pertes.isEmpty ? 'Fermer' : "J'ai compris"),
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
