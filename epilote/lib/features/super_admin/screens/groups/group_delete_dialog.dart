part of '../school_groups_screen.dart';

// Suppression : confirmation et avertissements.

class _DeleteConfirmDialog extends StatefulWidget {
  const _DeleteConfirmDialog({required this.group});
  final GroupDetail group;

  @override
  State<_DeleteConfirmDialog> createState() => _DeleteConfirmDialogState();
}

class _DeleteConfirmDialogState extends State<_DeleteConfirmDialog> {
  bool _confirmed = false;

  @override
  Widget build(BuildContext context) {
    final g = widget.group;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 60),
      child: Container(
        width: 480,
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(
              color: _kRed.withValues(alpha: 0.12),
              blurRadius: 40, offset: const Offset(0, 12))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // ── Zone danger ────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
            decoration: BoxDecoration(
              color: _kRed.withValues(alpha: 0.04),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              border: Border(bottom: BorderSide(color: _kRed.withValues(alpha: 0.12))),
            ),
            child: Column(children: [
              // Icône d'alerte
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: _kRed.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                  border: Border.all(color: _kRed.withValues(alpha: 0.2), width: 2),
                ),
                child: const Icon(Icons.delete_forever_rounded,
                    color: _kRed, size: 30),
              ),
              const SizedBox(height: 14),
              const Text('Supprimer définitivement',
                  style: TextStyle(
                      color: _kRed, fontSize: 17,
                      fontWeight: FontWeight.w900, letterSpacing: 0.2)),
              const SizedBox(height: 6),
              Text('Cette action est irréversible',
                  style: TextStyle(
                      color: _kRed.withValues(alpha: 0.7),
                      fontSize: 12, fontWeight: FontWeight.w500)),
            ]),
          ),

          // ── Corps ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 22, 28, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Groupe ciblé
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _kSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kBorder),
                ),
                child: Row(children: [
                  _GroupAvatar(name: g.name, size: 40, logoUrl: g.logoUrl),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(g.name, style: TextStyle(
                          color: _kText, fontSize: 14,
                          fontWeight: FontWeight.w800),
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(g.adminEmail,
                          style: TextStyle(
                              color: _kMuted, fontSize: 11),
                          overflow: TextOverflow.ellipsis),
                    ],
                  )),
                ]),
              ),
              const SizedBox(height: 16),

              ...[
                // Avertissement données
                Text('Seront également supprimées :',
                    style: TextStyle(
                        color: _kText, fontSize: 12,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const _DeleteWarningItem(
                    icon: Icons.school_rounded,
                    text: 'Toutes les écoles rattachées au groupe'),
                const _DeleteWarningItem(
                    icon: Icons.people_rounded,
                    text: 'Tous les élèves et le personnel'),
                const _DeleteWarningItem(
                    icon: Icons.payments_rounded,
                    text: 'L\'historique des paiements'),
                const _DeleteWarningItem(
                    icon: Icons.description_rounded,
                    text: 'Les documents et archives scolaires'),
                const SizedBox(height: 18),

                // Case à cocher confirmation
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => setState(() => _confirmed = !_confirmed),
                    child: Row(children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 20, height: 20,
                        decoration: BoxDecoration(
                          color: _confirmed ? _kRed : kCardBg,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: _confirmed
                                ? _kRed
                                : _kBorder,
                            width: 2,
                          ),
                        ),
                        child: _confirmed
                            ? const Icon(Icons.check_rounded,
                                size: 13, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(
                        'Je comprends que cette action est irréversible',
                        style: TextStyle(
                            color: _confirmed ? _kRed : _kMuted,
                            fontSize: 12.5,
                            fontWeight: _confirmed
                                ? FontWeight.w700
                                : FontWeight.w400),
                      )),
                    ]),
                  ),
                ),
              ],
              const SizedBox(height: 22),
            ]),
          ),

          // ── Footer ─────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(28, 14, 28, 22),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: _kBorder)),
            ),
            child: Row(children: [
              // Annuler
              Expanded(child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: InkWell(
                  onTap: () => Navigator.pop(context, false),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: _kBorder),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(child: Text('Annuler',
                        style: TextStyle(
                            color: _kMuted, fontSize: 13,
                            fontWeight: FontWeight.w700))),
                  ),
                ),
              )),
              const SizedBox(width: 12),
              // Supprimer
              Expanded(child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _confirmed ? 1.0 : 0.4,
                child: MouseRegion(
                  cursor: _confirmed
                      ? SystemMouseCursors.click
                      : SystemMouseCursors.forbidden,
                  child: GestureDetector(
                    onTap: _confirmed
                        ? () => Navigator.pop(context, true)
                        : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _kRed,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: _confirmed ? [BoxShadow(
                          color: _kRed.withValues(alpha: 0.30),
                          blurRadius: 12, offset: const Offset(0, 4),
                        )] : [],
                      ),
                      child: const Center(child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.delete_forever_rounded,
                              color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text('Supprimer',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 13,
                                  fontWeight: FontWeight.w800)),
                        ],
                      )),
                    ),
                  ),
                ),
              )),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _DeleteWarningItem extends StatelessWidget {
  const _DeleteWarningItem({required this.icon, required this.text});
  final IconData icon;
  final String   text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(children: [
      Container(
        width: 22, height: 22,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: _kRed.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Icon(icon, size: 12, color: _kRed.withValues(alpha: 0.7)),
      ),
      Expanded(child: Text(text, style: TextStyle(
          color: _kMuted, fontSize: 11.5))),
    ]),
  );
}

// ─── Fiche officielle d'identité du groupe ────────────────────────────────────
