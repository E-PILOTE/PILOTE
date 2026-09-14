part of '../school_groups_screen.dart';

// Suppression : confirmation, refus ministère, avertissements.

class _DeleteConfirmDialog extends StatefulWidget {
  const _DeleteConfirmDialog({required this.group});
  final GroupDetail group;

  @override
  State<_DeleteConfirmDialog> createState() => _DeleteConfirmDialogState();
}

class _DeleteConfirmDialogState extends State<_DeleteConfirmDialog> {
  bool _confirmed = false;

  /// ⚠️ CE DIALOGUE NE PROPOSE PAS DE SUPPRIMER UN MINISTÈRE. La base refuse
  /// (déclencheur `trg_ministere_ne_seffce_pas`, migration 0179) ; l'écran doit
  /// le dire AVANT le clic, pas laisser cocher « je comprends que cette action
  /// est irréversible » pour finir sur un refus.
  bool get _estMinistere => widget.group.administreReferentielNational;

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
                child: Icon(
                    _estMinistere
                        ? Icons.block_rounded
                        : Icons.delete_forever_rounded,
                    color: _kRed, size: 30),
              ),
              const SizedBox(height: 14),
              Text(
                  _estMinistere
                      ? 'Suppression impossible'
                      : 'Supprimer définitivement',
                  style: const TextStyle(
                      color: _kRed, fontSize: 17,
                      fontWeight: FontWeight.w900, letterSpacing: 0.2)),
              const SizedBox(height: 6),
              Text(
                  _estMinistere
                      ? 'Ce groupe est un ministère de tutelle'
                      : 'Cette action est irréversible',
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
                      Text('${g.groupTypeLabel}  •  ${g.adminEmail}',
                          style: TextStyle(
                              color: _kMuted, fontSize: 11),
                          overflow: TextOverflow.ellipsis),
                    ],
                  )),
                ]),
              ),
              const SizedBox(height: 16),

              // ── Le refus, ou les avertissements ────────────────────
              if (_estMinistere)
                _RefusMinistere(nom: g.name, tutelle: g.tutelle)
              else ...[
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
                opacity: _confirmed && !_estMinistere ? 1.0 : 0.4,
                child: MouseRegion(
                  cursor: _confirmed
                      ? SystemMouseCursors.click
                      : SystemMouseCursors.forbidden,
                  child: GestureDetector(
                    onTap: _confirmed && !_estMinistere
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

/// Le refus opposé à la suppression d'un ministère de tutelle.
///
/// ⚠️ IL NE S'AJOUTE PAS AUX QUATRE AVERTISSEMENTS, IL LES REMPLACE. Le
/// dialogue énumérait déjà « écoles, élèves, paiements, archives » et faisait
/// cocher « je comprends ». Un cinquième point dans la même liste se serait lu
/// comme les quatre autres — et ici il n'y a rien à comprendre : il n'y aura
/// pas de suppression. Ce qu'il faut donner, c'est le chemin sûr.
class _RefusMinistere extends StatelessWidget {
  const _RefusMinistere({required this.nom, required this.tutelle});

  final String nom;
  final String? tutelle;

  @override
  Widget build(BuildContext context) {
    final sigle = sigleTutelle(tutelle);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: _kRed.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kRed.withValues(alpha: 0.30)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.account_balance_rounded, size: 15, color: _kRed),
          const SizedBox(width: 8),
          Expanded(child: Text(
            sigle == null
                ? '« $nom » est un ministère de tutelle.'
                : '« $nom » est le ministère de tutelle $sigle.',
            style: TextStyle(
                fontSize: 12.5, height: 1.4,
                fontWeight: FontWeight.w700, color: _kText),
          )),
        ]),
        const SizedBox(height: 9),
        Text(
          'Les établissements de son ministère en dépendent pour leurs '
          'examens d’État et leurs circulaires — y compris ceux qu’il ne '
          'possède pas. La base refuse cette suppression.',
          style: TextStyle(fontSize: 11.5, height: 1.45, color: _kMuted),
        ),
        const SizedBox(height: 11),
        Container(
          padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
          decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kBorder),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text('Pour supprimer ce groupe malgré tout :',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w800, color: _kText)),
            const SizedBox(height: 6),
            Text(
              '1.  Modifier le groupe et lui retirer le rôle de ministère de '
              'tutelle — vous devrez alors dire qui le reprend.\n'
              '2.  Revenir ici et supprimer.',
              style: TextStyle(fontSize: 11.5, height: 1.5, color: _kMuted),
            ),
          ]),
        ),
      ]),
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
