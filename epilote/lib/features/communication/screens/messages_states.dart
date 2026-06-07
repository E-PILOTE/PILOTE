part of 'messages_screen.dart';

// ─── États vides / chargement / erreur ────────────────────────────────────────
class _EmptyList extends StatelessWidget {
  const _EmptyList({required this.folder, required this.hasSearch});
  final String folder;
  final bool hasSearch;

  @override
  Widget build(BuildContext context) {
    final (icon, title, sub) = hasSearch
        ? (Icons.search_off_rounded, 'Aucun résultat', 'Modifiez votre recherche')
        : switch (folder) {
            'unread' =>
              (Icons.mark_email_read_rounded, 'Tout est lu !', 'Aucun message non lu'),
            'sent' => (
                Icons.outbox_rounded,
                'Aucun message envoyé',
                'Vos messages envoyés apparaîtront ici'
              ),
            'archived' =>
              (Icons.archive_rounded, 'Archives vides', 'Aucun message archivé'),
            _ => (
                Icons.inbox_rounded,
                'Aucun message',
                'Votre boîte de réception est vide'
              ),
          };

    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 52, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text(title,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: _kSub)),
        const SizedBox(height: 4),
        Text(sub, style: const TextStyle(fontSize: 12, color: _kSub)),
      ]),
    );
  }
}

class _NoSelection extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFFFAFBFC),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _kNavy.withValues(alpha: 0.07),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mail_outline_rounded, size: 40, color: _kNavy),
            ),
            const SizedBox(height: 20),
            const Text('Sélectionnez un message',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _kText)),
            const SizedBox(height: 8),
            const Text('Cliquez sur un message dans la liste pour le lire',
                style: TextStyle(fontSize: 13, color: _kSub)),
          ]),
        ),
      );
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(width: 220, color: _kCard),
        Container(width: 1, color: _kBorder),
        SizedBox(
          width: 360,
          child: ListView.builder(
            itemCount: 8,
            itemBuilder: (_, _) => Container(
              height: 72,
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        Container(width: 1, color: _kBorder),
        const Expanded(child: SizedBox()),
      ]);
}

class _Err extends StatelessWidget {
  const _Err({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline_rounded, size: 48, color: _kRed),
        const SizedBox(height: 12),
        Text(error,
            style: const TextStyle(fontSize: 12, color: _kSub),
            textAlign: TextAlign.center),
        const SizedBox(height: 16),
        ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Réessayer'),
            style: ElevatedButton.styleFrom(
                backgroundColor: _kNavy, foregroundColor: Colors.white)),
      ]));
}
