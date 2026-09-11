import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/comptes_admin_provider.dart';
import '../../providers/subscriptions_provider.dart';
import 'subs_detail_bits.dart';
import 'subs_style.dart';

// ─── Les trois onglets de la fiche ────────────────────────────────────
//  Groupe / Abonnement / Système. L'onglet Groupe montre les DEUX adresses,
//  chacune sous son vrai nom : le compte de connexion d'abord, l'e-mail de
//  contact ensuite — c'est leur confusion qui a fait échouer une connexion.

class SubGroupTab extends ConsumerWidget {
  const SubGroupTab({super.key, required this.sub});
  final SubscriptionDetail sub;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = sub;
    final comptes = ref.watch(comptesAdminParGroupeProvider).maybeWhen(
          data: (m) => m[s.id] ?? const <CompteAdmin>[],
          orElse: () => const <CompteAdmin>[],
        );
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SubDetailSectionTitle('Coordonnées'),
        const SizedBox(height: 8),
        SubDetailCard([
          SubDetailRow(Icons.business_rounded, 'Nom du groupe', s.groupName),
          // Les DEUX adresses, chacune sous son vrai nom. « E-mail admin »
          // désignait le contact du formulaire, et se lisait comme un
          // identifiant : c'est ce malentendu qui a fait échouer une
          // connexion. Le compte d'abord — c'est lui qu'on cherche quand on
          // ouvre cette fiche pour dépanner quelqu'un.
          ...comptes.isEmpty
              ? const <Widget>[]
              : [
                  for (final c in comptes)
                    SubDetailRow(
                        Icons.key_rounded,
                        comptes.length > 1
                            ? 'Compte · ${c.nom}'
                            : 'Compte de connexion',
                        c.actif ? c.email : '${c.email}  (désactivé)',
                        copyable: true),
                ],
          SubDetailRow(Icons.email_outlined, 'E-mail de contact', s.adminEmail,
              copyable: true),
          SubDetailRow(Icons.phone_rounded, 'Téléphone', s.phone ?? '—'),
          SubDetailRow(Icons.location_on_outlined, 'Département', s.department ?? '—', last: true),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: SubMetaChip(
            icon: subTypeIcon(s.groupType), label: s.groupTypeLabel, color: subTypeColor(s.groupType))),
          const SizedBox(width: 8),
          Expanded(child: SubMetaChip(
            icon: Icons.school_rounded, label: '${s.schoolsCount} école(s)', color: kSubNavy)),
          const SizedBox(width: 8),
          Expanded(child: SubMetaChip(
            icon: subStatusIcon(s.status), label: s.statusLabel, color: subStatusColor(s.status))),
        ]),
      ]),
    );
  }
}

class SubSubscriptionTab extends StatelessWidget {
  const SubSubscriptionTab({super.key, required this.sub});
  final SubscriptionDetail sub;

  @override
  Widget build(BuildContext context) {
    final s = sub;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SubDetailSectionTitle('Plan & Tarification'),
        const SizedBox(height: 8),
        SubDetailCard([
          SubDetailRow(Icons.workspace_premium_rounded, 'Plan', s.planName ?? '—'),
          SubDetailRow(Icons.payments_outlined, 'Prix mensuel',
              s.priceLabel),
          SubDetailRow(Icons.radio_button_checked_rounded, 'Statut', s.statusLabel, last: true),
        ]),
        const SizedBox(height: 14),
        const SubDetailSectionTitle('Période'),
        const SizedBox(height: 8),
        SubDetailCard([
          SubDetailRow(Icons.play_circle_outline_rounded, 'Début', subDate(s.start)),
          SubDetailRow(Icons.stop_circle_outlined, 'Fin', subDate(s.end)),
          SubDetailRow(Icons.timelapse_rounded, 'Échéance', s.remainingLabel, last: true),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: SubMetaChip(
            icon: s.isOverdue ? Icons.error_rounded : Icons.check_circle_rounded,
            label: s.isOverdue ? 'En retard' : (s.isExpiringSoon ? 'Expire bientôt' : 'À jour'),
            color: s.isOverdue ? kSubRed : (s.isExpiringSoon ? kSubOrange : kSubGreen))),
          const SizedBox(width: 8),
          Expanded(child: SubMetaChip(
            icon: Icons.payments_rounded,
            // « / mois » était faux : le même montant est facturé pour un an.
            label: '${subMoney(s.priceXaf)} F / ${s.periodSuffix}',
            color: kSubPurple)),
        ]),
      ]),
    );
  }
}

class SubSystemTab extends StatelessWidget {
  const SubSystemTab({super.key, required this.sub});
  final SubscriptionDetail sub;

  @override
  Widget build(BuildContext context) {
    final s = sub;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SubDetailSectionTitle('Identité système'),
        const SizedBox(height: 8),
        SubDetailCard([
          SubDetailRow(Icons.tag_rounded, 'UUID', s.id, copyable: true, mono: true),
          if (s.planId != null)
            SubDetailRow(Icons.confirmation_number_outlined, 'Plan ID', s.planId!, mono: true),
          if (s.planSlug != null)
            SubDetailRow(Icons.label_outline_rounded, 'Plan slug', s.planSlug!),
          SubDetailRow(Icons.calendar_today_outlined, 'Créé le', subDate(s.createdAt)),
          SubDetailRow(Icons.update_outlined, 'Mis à jour', subDate(s.updatedAt), last: true),
        ]),
      ]),
    );
  }
}
