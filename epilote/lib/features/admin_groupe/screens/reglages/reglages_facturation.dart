part of '../admin_settings_screen.dart';

// Onglet Facturation : politique de frais et moyens de paiement.

class _BillingTab extends ConsumerWidget {
  const _BillingTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configs = ref.watch(adminPaymentConfigsProvider);
    final settings = ref.watch(adminGroupSettingsProvider);

    return _TabScaffold(
      onRefresh: () async {
        ref.invalidate(adminPaymentConfigsProvider);
        ref.invalidate(adminGroupSettingsProvider);
        await Future.wait([
          ref.read(adminPaymentConfigsProvider.future),
          ref.read(adminGroupSettingsProvider.future),
        ]);
      },
      children: [
        AdminCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AdminSectionTitle(
              'Moyens de paiement',
              icon: Icons.account_balance_wallet_outlined,
              subtitle: 'Configurez la collecte des frais scolaires',
              trailing: AdminActionButton(
                label: 'Ajouter',
                icon: Icons.add_rounded,
                onPressed: () => _openEditor(context),
              ),
            ),
            const SizedBox(height: 16),
            configs.when(
              skipLoadingOnReload: true,
              skipLoadingOnRefresh: true,
              loading: () => Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator(color: kNavy)),
              ),
              error: (e, _) => AdminErrorBanner(message: messageErreur(e)),
              data: (list) => list.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: AdminEmptyState(
                        icon: Icons.payments_outlined,
                        title: 'Aucun moyen de paiement',
                        message:
                            'Ajoutez MTN Money, Airtel Money, carte bancaire ou espèces pour encaisser les frais de scolarité.',
                      ),
                    )
                  : Column(
                      children: [
                        for (final c in list) _PaymentTile(config: c),
                      ],
                    ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: kAccent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kAccent.withValues(alpha: 0.3)),
          ),
          child: const Row(children: [
            Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFFB7791F)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Les clés secrètes sont masquées. Activez le mode test pour valider une intégration avant la mise en production.',
                style: TextStyle(fontSize: 12, color: Color(0xFF92651A)),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        // ── Politique de frais & remises (group_settings.general) ───────────
        settings.when(
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          loading: () => const _CardLoader(),
          error: (e, _) => AdminCard(child: AdminErrorBanner(message: messageErreur(e))),
          data: (s) => _FeePolicyCard(initial: s.general),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  void _openEditor(BuildContext context, {PaymentConfig? config}) {
    showDialog(
      context: context,
      builder: (_) => _PaymentEditorDialog(existing: config),
    );
  }
}

// ─── Politique de frais & remises (group_settings.general) ───────────────────
class _FeePolicyCard extends ConsumerStatefulWidget {
  const _FeePolicyCard({required this.initial});
  final GeneralSettings initial;

  @override
  ConsumerState<_FeePolicyCard> createState() => _FeePolicyCardState();
}

class _FeePolicyCardState extends ConsumerState<_FeePolicyCard> {
  late GeneralSettings _s = widget.initial;
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });
    try {
      final current = await ref.read(adminGroupSettingsProvider.future);
      final merged = current.general.copyWith(
        defaultInstallments:    _s.defaultInstallments,
        lateFeeRatePercent:     _s.lateFeeRatePercent,
        lateGraceDays:          _s.lateGraceDays,
        siblingDiscountPercent: _s.siblingDiscountPercent,
        scholarshipMaxPercent:  _s.scholarshipMaxPercent,
      );
      await ref.read(adminSettingsServiceProvider).saveGeneral(merged);
      if (mounted) _toast(context, 'Politique de frais enregistrée.');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const AdminSectionTitle('Politique de frais & remises',
            icon: Icons.policy_outlined,
            subtitle: 'Échéancier, pénalités de retard et remises par défaut'),
        const SizedBox(height: 4),
        _NumberStepper(
          icon: Icons.event_repeat_rounded,
          title: 'Échéances par défaut',
          subtitle: 'Tranches de paiement proposées aux familles',
          value: _s.defaultInstallments,
          min: 1,
          max: 12,
          suffix: 'tranches',
          onChanged: (v) => setState(() => _s = _s.copyWith(defaultInstallments: v)),
        ),
        _NumberStepper(
          icon: Icons.percent_rounded,
          title: 'Pénalité de retard',
          subtitle: 'Majoration appliquée aux frais impayés',
          value: _s.lateFeeRatePercent,
          min: 0,
          max: 50,
          suffix: '%',
          onChanged: (v) => setState(() => _s = _s.copyWith(lateFeeRatePercent: v)),
        ),
        _NumberStepper(
          icon: Icons.timer_outlined,
          title: 'Délai de grâce',
          subtitle: 'Jours avant application de la pénalité',
          value: _s.lateGraceDays,
          min: 0,
          max: 90,
          step: 5,
          suffix: 'jours',
          onChanged: (v) => setState(() => _s = _s.copyWith(lateGraceDays: v)),
        ),
        _NumberStepper(
          icon: Icons.family_restroom_rounded,
          title: 'Remise fratrie',
          subtitle: "Réduction pour élèves d'une même famille",
          value: _s.siblingDiscountPercent,
          min: 0,
          max: 100,
          step: 5,
          suffix: '%',
          onChanged: (v) => setState(() => _s = _s.copyWith(siblingDiscountPercent: v)),
        ),
        _NumberStepper(
          icon: Icons.volunteer_activism_outlined,
          title: 'Plafond de bourse',
          subtitle: 'Prise en charge maximale par bourse',
          value: _s.scholarshipMaxPercent,
          min: 0,
          max: 100,
          step: 5,
          suffix: '%',
          onChanged: (v) => setState(() => _s = _s.copyWith(scholarshipMaxPercent: v)),
        ),
        const SizedBox(height: 16),
        _SaveBar(saving: _saving, onSave: _save, error: _error),
      ]),
    );
  }
}

class _PaymentTile extends ConsumerStatefulWidget {
  const _PaymentTile({required this.config});
  final PaymentConfig config;

  @override
  ConsumerState<_PaymentTile> createState() => _PaymentTileState();
}

class _PaymentTileState extends ConsumerState<_PaymentTile> {
  bool _busy = false;

  IconData get _icon => switch (widget.config.provider) {
        PaymentProvider.mtnMoney => Icons.phone_android_rounded,
        PaymentProvider.airtelMoney => Icons.phone_android_rounded,
        PaymentProvider.visa => Icons.credit_card_rounded,
        PaymentProvider.especes => Icons.payments_rounded,
      };

  Future<void> _toggle(bool v) async {
    final c = widget.config;
    if (c.id == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(adminSettingsServiceProvider).setPaymentActive(c.id!, v);
    } catch (e) {
      if (mounted) _toast(context, messageErreur(e), ok: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final c = widget.config;
    if (c.id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Supprimer ce moyen de paiement ?'),
        content: Text('« ${c.displayName} » sera définitivement retiré.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler', style: TextStyle(color: kTextMuted)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: kRed),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(adminSettingsServiceProvider).deletePaymentConfig(c.id!);
      if (mounted) _toast(context, 'Moyen de paiement supprimé.');
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _toast(context, messageErreur(e), ok: false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.config;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: kNavy.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(_icon, color: kNavy, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(c.displayName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextPrimary)),
              ),
              const SizedBox(width: 8),
              if (c.isTestMode) AdminBadge('TEST', color: kAccent),
            ]),
            const SizedBox(height: 2),
            Text(c.provider.label, style: TextStyle(fontSize: 12, color: kTextMuted)),
          ]),
        ),
        if (_busy)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: kNavy)),
          )
        else ...[
          Switch(
            value: c.isActive,
            activeThumbColor: kGreen,
            onChanged: _toggle,
          ),
          AdminModalIconBtn(
            icon: Icons.edit_outlined,
            color: kNavy,
            tooltip: 'Modifier',
            onTap: () => showDialog(
              context: context,
              builder: (_) => _PaymentEditorDialog(existing: c),
            ),
          ),
          const SizedBox(width: 6),
          AdminModalIconBtn(
            icon: Icons.delete_outline_rounded,
            color: kRed,
            tooltip: 'Supprimer',
            onTap: _delete,
          ),
        ],
      ]),
    );
  }
}

// ─── Éditeur (ajout / modification) de moyen de paiement ─────────────────────
