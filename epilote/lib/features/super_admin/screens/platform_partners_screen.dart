import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/admin_ui.dart';
import '../providers/platform_partners_provider.dart';
import 'platform_partner_form_dialog.dart';
import '../../../core/utils/message_erreur.dart';

final _fmt = DateFormat('dd/MM/yyyy', 'fr_FR');

/// Partenaires curatés affichés sur la vitrine des postes (Phase 3b). Curation
/// super_admin ; l'affichage réel dépend de l'opt-in de chaque groupe.
class PlatformPartnersScreen extends ConsumerWidget {
  const PlatformPartnersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(partnersAdminProvider);
    return AppShell(
      title: 'Partenaires des postes',
      child: async.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.error_outline_rounded, color: kRed, size: 40),
            const SizedBox(height: 12),
            Text(messageErreur(e),
                textAlign: TextAlign.center,
                style: TextStyle(color: kTextMuted)),
            const SizedBox(height: 12),
            FilledButton(
                onPressed: () => ref.invalidate(partnersAdminProvider),
                child: const Text('Réessayer')),
          ]),
        ),
        data: (partners) => _Body(partners: partners),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.partners});
  final List<PartnerModel> partners;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(
                  child: Text('${partners.length} partenaire${partners.length > 1 ? 's' : ''}',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: kTextMuted)),
                ),
                FilledButton.icon(
                  onPressed: () => _openForm(context),
                  style: FilledButton.styleFrom(backgroundColor: kNavy),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Nouveau partenaire'),
                ),
              ]),
              const SizedBox(height: 8),
              const _Explainer(),
              const SizedBox(height: 16),
              if (partners.isEmpty)
                const AdminEmptyState(
                  icon: Icons.handshake_outlined,
                  title: 'Aucun partenaire',
                  message:
                      'Ajoutez un partenaire institutionnel ou éducatif. Il ne '
                      's’affichera que sur les postes des groupes ayant activé '
                      'l’affichage partenaires.',
                )
              else
                ...partners.map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _PartnerCard(
                        partner: p,
                        onEdit: () => _openForm(context, p),
                        onToggle: () => ref
                            .read(partnersAdminServiceProvider)
                            .toggleActive(p.id, !p.isActive),
                        onDelete: () => _confirmDelete(context, ref, p),
                      ),
                    )),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openForm(BuildContext context, [PartnerModel? existing]) =>
      showDialog(
          context: context,
          builder: (_) => PartnerFormDialog(existing: existing));

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, PartnerModel p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce partenaire ?'),
        content: Text('« ${p.name} » disparaîtra des vitrines.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kRed),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok == true) await ref.read(partnersAdminServiceProvider).delete(p.id);
  }
}

class _Explainer extends StatelessWidget {
  const _Explainer();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: kNavy.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(Icons.shield_outlined, size: 18, color: kNavy),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Curation institutionnelle uniquement. Les encarts sont discrets, '
              'étiquetés « Partenaire », et n’apparaissent que sur les postes '
              'des groupes ayant explicitement activé l’affichage partenaires.',
              style: TextStyle(
                  fontSize: 12.5, color: kTextPrimary.withValues(alpha: 0.8)),
            ),
          ),
        ]),
      );
}

class _PartnerCard extends StatelessWidget {
  const _PartnerCard({
    required this.partner,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });
  final PartnerModel partner;
  final VoidCallback onEdit, onToggle, onDelete;

  @override
  Widget build(BuildContext context) {
    final has = partner.logoUrl != null && partner.logoUrl!.isNotEmpty;
    return AdminCard(
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10)),
          child: has
              ? CachedNetworkImage(
                  imageUrl: partner.logoUrl!,
                  fit: BoxFit.contain,
                  errorWidget: (_, _, _) => Icon(
                      Icons.handshake_rounded, color: kTextMuted))
              : Icon(Icons.handshake_rounded, color: kTextMuted),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(partner.name,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: kTextPrimary)),
              const SizedBox(height: 4),
              Row(children: [
                AdminBadge(partner.isActive ? 'Actif' : 'Inactif',
                    color: partner.isActive ? kGreen : kTextMuted,
                    icon: partner.isActive ? Icons.check_circle : Icons.cancel),
                const SizedBox(width: 8),
                AdminBadge(partnerCategoryLabel(partner.category),
                    color: kNavy, icon: Icons.category_outlined),
                const SizedBox(width: 8),
                Text('Ordre ${partner.sortOrder}',
                    style: TextStyle(fontSize: 11.5, color: kTextMuted)),
              ]),
              if (partner.startsAt != null || partner.endsAt != null) ...[
                const SizedBox(height: 4),
                Text(
                    'Du ${partner.startsAt != null ? _fmt.format(partner.startsAt!) : '…'} '
                    'au ${partner.endsAt != null ? _fmt.format(partner.endsAt!) : '…'}',
                    style: TextStyle(fontSize: 11.5, color: kTextMuted)),
              ],
            ],
          ),
        ),
        IconButton(
            tooltip: partner.isActive ? 'Désactiver' : 'Activer',
            icon: Icon(
                partner.isActive
                    ? Icons.toggle_on_rounded
                    : Icons.toggle_off_rounded,
                color: partner.isActive ? kGreen : kTextMuted,
                size: 26),
            onPressed: onToggle),
        IconButton(
            tooltip: 'Modifier',
            icon: Icon(Icons.edit_outlined, color: kNavy, size: 20),
            onPressed: onEdit),
        IconButton(
            tooltip: 'Supprimer',
            icon: Icon(Icons.delete_outline_rounded, color: kRed, size: 20),
            onPressed: onDelete),
      ]),
    );
  }
}
