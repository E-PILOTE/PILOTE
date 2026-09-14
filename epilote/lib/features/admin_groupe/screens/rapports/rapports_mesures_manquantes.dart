part of '../admin_reports_screen.dart';

// Bandeau : ce que le rapport n’a pas pu lire.

class _MesuresManquantesRapport extends ConsumerWidget {
  const _MesuresManquantesRapport({required this.data});
  final ReportData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noms =
        (data.mesuresManquantes.map(MesuresRapport.libelle).toList()..sort())
            .join(', ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: kAccent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kAccent.withValues(alpha: 0.35)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.cloud_off_rounded, size: 18, color: kAccent),
        const SizedBox(width: 11),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Rapport incomplet',
                style: TextStyle(
                    color: kAccent, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(
              'Ces données n\'ont pas pu être lues : $noms. Les chiffres '
              'correspondants ne sont pas nuls — ils sont inconnus. '
              'N\'exportez pas ce rapport en l\'état.',
              style: TextStyle(
                  color: kTextPrimary.withValues(alpha: 0.85),
                  fontSize: 11.5,
                  height: 1.35),
            ),
          ]),
        ),
        const SizedBox(width: 12),
        TextButton.icon(
          onPressed: () => ref.invalidate(reportsSnapshotProvider),
          icon: const Icon(Icons.refresh_rounded, size: 15),
          label: const Text('Réessayer', style: TextStyle(fontSize: 12)),
          style: TextButton.styleFrom(foregroundColor: kAccent),
        ),
      ]),
    );
  }
}
