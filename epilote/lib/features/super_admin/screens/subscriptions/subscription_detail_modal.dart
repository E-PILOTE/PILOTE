import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/admin_ui.dart';
import '../../providers/comptes_admin_provider.dart';
import '../../providers/subscriptions_provider.dart';
import '../subscriptions_emettre_facture.dart';
import 'subs_badges.dart';
import 'subs_detail_bits.dart';
import 'subs_detail_tabs.dart';
import 'subs_style.dart';

// ─── Fiche détaillée d'un abonnement ─────────────────────────────────
//  C'est d'ici que le fondateur ÉMET une facture de renouvellement — et de
//  nulle part ailleurs. Émettre ≠ encaisser : le paiement reste un second
//  geste, dans l'écran Factures.

class SubDetailModal extends ConsumerStatefulWidget {
  const SubDetailModal({
    super.key,
    required this.sub,
    required this.onEdit,
    required this.onStatus,
    required this.onPrint,
  });
  final SubscriptionDetail sub;
  final VoidCallback onEdit, onPrint;
  final ValueChanged<String> onStatus;

  @override
  ConsumerState<SubDetailModal> createState() => _SubDetailModalState();
}

class _SubDetailModalState extends ConsumerState<SubDetailModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.sub;
    final color = subStatusColor(s.status);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Container(
        width: 720,
        constraints: const BoxConstraints(maxHeight: 680),
        decoration: BoxDecoration(
          color: kSubBg,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 30, offset: const Offset(0, 8))],
        ),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 14, 16),
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: kSubBorder)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              SubGroupGlyph(sub: s, size: 66),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.groupName, style: TextStyle(
                    color: kSubText, fontSize: 17, fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 5),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  SubStatusBadge(status: s.status),
                  SubTypeBadge(type: s.groupType),
                ]),
                const SizedBox(height: 5),
                Row(children: [
                  Icon(Icons.email_outlined, size: 12, color: color),
                  const SizedBox(width: 4),
                  Flexible(child: Text(
                      ref.watch(comptesAdminParGroupeProvider).maybeWhen(
                            data: (m) => compteDeConnexion(m, s.id),
                            orElse: () => null,
                          ) ??
                          s.adminEmail,
                      style: TextStyle(
                          color: color, fontSize: 12.5, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis)),
                ]),
              ])),
              const SizedBox(width: 8),
              Row(children: [
                // ⚠️ Émettre ≠ encaisser. Ce bouton crée la SOMME DUE de la
                // période suivante ; le paiement reste un second geste, dans
                // l'écran Factures. Un ministère n'en a pas : son marché se
                // renégocie par avenant (0182/0183), et la base le refuserait.
                if (!s.estMinistere) ...[
                  SubModalIconBtn(
                    icon: Icons.receipt_long_rounded,
                    color: kSubGreen,
                    tooltip: 'Émettre la facture de renouvellement',
                    onTap: () async {
                      final cree = await emettreFactureDeRenouvellement(
                        context, ref,
                        groupId: s.id, groupName: s.groupName,
                      );
                      if (cree) ref.invalidate(subscriptionsProvider);
                    },
                  ),
                  const SizedBox(width: 4),
                ],
                SubModalIconBtn(icon: Icons.edit_rounded, color: kSubNavy, tooltip: 'Modifier', onTap: widget.onEdit),
                const SizedBox(width: 4),
                SubModalIconBtn(icon: Icons.print_rounded, color: kSubMuted, tooltip: 'Imprimer', onTap: widget.onPrint),
                const SizedBox(width: 4),
                SubModalIconBtn(icon: Icons.close_rounded, color: kSubMuted, tooltip: 'Fermer',
                    onTap: () => Navigator.pop(context)),
              ]),
            ]),
          ),
          Container(
            color: kSubSurface,
            child: TabBar(
              controller: _tabs,
              labelColor: kSubNavy,
              unselectedLabelColor: kSubMuted,
              indicatorColor: kSubNavy,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              tabs: const [
                Tab(text: 'Groupe'),
                Tab(text: 'Abonnement'),
                Tab(text: 'Système'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                SubGroupTab(sub: s),
                SubSubscriptionTab(sub: s),
                SubSystemTab(sub: s),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: kSubBorder)),
            ),
            child: Row(children: [
              _StatusMenuButton(current: s.status, onSelect: widget.onStatus),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: widget.onEdit,
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text('Modifier'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kSubNavy,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _StatusMenuButton extends StatelessWidget {
  const _StatusMenuButton({required this.current, required this.onSelect});
  final String current;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    onSelected: onSelect,
    tooltip: 'Changer le statut',
    itemBuilder: (_) => kSubStatusLabels.entries
        .where((e) => e.key != current)
        .map((e) => PopupMenuItem<String>(
              value: e.key,
              child: Row(children: [
                Icon(subStatusIcon(e.key), size: 15, color: subStatusColor(e.key)),
                const SizedBox(width: 8),
                Text(e.value),
              ]),
            ))
        .toList(),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        border: Border.all(color: subStatusColor(current)),
        borderRadius: BorderRadius.circular(8),
        color: subStatusColor(current).withValues(alpha: 0.06),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.swap_horiz_rounded, size: 16, color: subStatusColor(current)),
        const SizedBox(width: 6),
        Text('Changer le statut', style: TextStyle(
            color: subStatusColor(current), fontSize: 13, fontWeight: FontWeight.w700)),
      ]),
    ),
  );
}
