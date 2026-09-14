part of '../admin_settings_screen.dart';

// Éditeur d’un moyen de paiement.

class _PaymentEditorDialog extends ConsumerStatefulWidget {
  const _PaymentEditorDialog({this.existing});
  final PaymentConfig? existing;

  @override
  ConsumerState<_PaymentEditorDialog> createState() => _PaymentEditorDialogState();
}

class _PaymentEditorDialogState extends ConsumerState<_PaymentEditorDialog> {
  late PaymentProvider _provider;
  late final TextEditingController _name;
  late final TextEditingController _apiKey;
  late final TextEditingController _apiSecret;
  late final TextEditingController _merchant;
  late final TextEditingController _webhook;
  late final TextEditingController _notes;
  late bool _active;
  late bool _testMode;
  bool _showSecret = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _provider = e?.provider ?? PaymentProvider.mtnMoney;
    _name = TextEditingController(text: e?.displayName ?? '');
    _apiKey = TextEditingController(text: e?.apiKey ?? '');
    _apiSecret = TextEditingController(text: e?.apiSecret ?? '');
    _merchant = TextEditingController(text: e?.merchantId ?? '');
    _webhook = TextEditingController(text: e?.webhookUrl ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
    _active = e?.isActive ?? false;
    _testMode = e?.isTestMode ?? true;
    if (_name.text.isEmpty) _name.text = _provider.label;
  }

  @override
  void dispose() {
    _name.dispose();
    _apiKey.dispose();
    _apiSecret.dispose();
    _merchant.dispose();
    _webhook.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = "Le nom d'affichage est obligatoire");
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await ref.read(adminSettingsServiceProvider).savePaymentConfig(PaymentConfig(
            id: widget.existing?.id,
            provider: _provider,
            displayName: _name.text.trim(),
            apiKey: _apiKey.text,
            apiSecret: _apiSecret.text,
            merchantId: _merchant.text,
            webhookUrl: _webhook.text,
            isActive: _active,
            isTestMode: _testMode,
            notes: _notes.text,
          ));
      if (mounted) {
        Navigator.of(context).pop();
        _toast(context, widget.existing == null
            ? 'Moyen de paiement ajouté.'
            : 'Moyen de paiement mis à jour.');
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final apiBased = _provider.isApiBased;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AdminDialogHeader(
            title: widget.existing == null ? 'Ajouter un moyen de paiement' : 'Modifier le moyen de paiement',
            icon: Icons.account_balance_wallet_outlined,
            subtitle: 'Collecte des frais de scolarité',
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<PaymentProvider>(
                  initialValue: _provider,
                  isExpanded: true,
                  decoration: adminInputDecoration('Fournisseur', icon: Icons.bolt_rounded),
                  items: [
                    for (final p in PaymentProvider.values)
                      DropdownMenuItem(value: p, child: Text(p.label)),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      final wasDefault = _name.text.trim() == _provider.label || _name.text.trim().isEmpty;
                      _provider = v;
                      if (wasDefault) _name.text = v.label;
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _name,
                  decoration: adminInputDecoration("Nom d'affichage", icon: Icons.label_outline_rounded),
                ),
                if (apiBased) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _apiKey,
                    decoration: adminInputDecoration('Clé API', icon: Icons.vpn_key_outlined),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _apiSecret,
                    obscureText: !_showSecret,
                    enableSuggestions: false,
                    autocorrect: false,
                    decoration: adminInputDecoration('Clé secrète', icon: Icons.password_rounded).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(_showSecret ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            size: 19, color: kTextMuted),
                        onPressed: () => setState(() => _showSecret = !_showSecret),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _merchant,
                    decoration: adminInputDecoration('Identifiant marchand', icon: Icons.store_outlined),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _webhook,
                    keyboardType: TextInputType.url,
                    decoration: adminInputDecoration('URL de webhook', icon: Icons.link_rounded,
                        hint: 'https://…'),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _notes,
                  maxLines: 2,
                  decoration: adminInputDecoration('Notes (interne)', icon: Icons.notes_rounded),
                ),
                const SizedBox(height: 6),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: kGreen,
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                  title: const Text('Actif', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                  subtitle: Text('Disponible pour encaisser les paiements',
                      style: TextStyle(fontSize: 11.5, color: kTextMuted)),
                ),
                if (apiBased)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: kAccent,
                    value: _testMode,
                    onChanged: (v) => setState(() => _testMode = v),
                    title: const Text('Mode test', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                    subtitle: Text('Sandbox — aucune transaction réelle',
                        style: TextStyle(fontSize: 11.5, color: kTextMuted)),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  AdminErrorBanner(message: _error!),
                ],
              ]),
            ),
          ),
          AdminDialogFooter(
            saving: _saving,
            submitLabel: widget.existing == null ? 'Ajouter' : 'Enregistrer',
            submitIcon: Icons.save_rounded,
            onCancel: () => Navigator.of(context).pop(),
            onSubmit: _submit,
          ),
        ]),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ONGLET 3 — NOTIFICATIONS  (group_settings.notifications)
// ═════════════════════════════════════════════════════════════════════════════
