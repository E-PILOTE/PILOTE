import 'package:flutter/material.dart';

import '../../../core/widgets/admin_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/app_shell.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/payment_methods_provider.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
Color get _kNavy => kNavy;
Color get _kGreen => kGreen;
Color get _kGold => kAccent;
const _kOrange = Color(0xFFFF6B35);
Color get _kCard => kCardBg;
Color get _kText => kTextPrimary;
Color get _kSub => kTextMuted;

final _fmtDate = DateFormat('dd/MM/yyyy', 'fr_FR');

// ─── Local state ──────────────────────────────────────────────────────────────

final _pmSearchProvider = StateProvider.autoDispose<String>((ref) => '');
final _pmFilterProvider = StateProvider.autoDispose<String>((ref) => 'all');

// ─── Screen ───────────────────────────────────────────────────────────────────

class PaymentMethodsScreen extends ConsumerWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(paymentMethodsProvider);

    return AppShell(
      title: 'Modes de Paiement',
      child: async.when(
        skipLoadingOnReload: true, skipLoadingOnRefresh: true,
        loading: () => const _LoadingSkeleton(),
        error:   (e, _) => _ErrorView(error: e.toString(), onRetry: () => ref.invalidate(paymentMethodsProvider)),
        data:    (data) => _Body(data: data),
      ),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _Body extends ConsumerWidget {
  const _Body({required this.data});
  final PaymentMethodsData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = ref.watch(_pmSearchProvider);
    final filter = ref.watch(_pmFilterProvider);

    var configs = data.configs;
    if (search.isNotEmpty) {
      final q = search.toLowerCase();
      configs = configs.where((c) =>
          c.groupName.toLowerCase().contains(q) ||
          c.displayName.toLowerCase().contains(q) ||
          c.provider.toLowerCase().contains(q)).toList();
    }
    if (filter == 'active') {
      configs = configs.where((c) => c.isActive).toList();
    } else if (filter == 'test') {
      configs = configs.where((c) => c.isTestMode).toList();
    } else if (filter != 'all') {
      configs = configs.where((c) => c.provider == filter).toList();
    }

    return Column(
      children: [
        _KpiSection(data: data),
        _ProviderOverview(data: data),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: _FilterBar(),
        ),
        Expanded(child: _ConfigList(configs: configs, ref: ref)),
      ],
    );
  }
}

// ─── KPI Section ──────────────────────────────────────────────────────────────

class _KpiSection extends StatelessWidget {
  const _KpiSection({required this.data});
  final PaymentMethodsData data;

  @override
  Widget build(BuildContext context) {
    final kpis = [
      (Icons.payment_rounded,         'Configurations',  '${data.totalConfigs}',     'modes enregistrés',     _kNavy),
      (Icons.check_circle_rounded,    'Actifs',          '${data.activeConfigs}',     'en production',         _kGreen),
      (Icons.science_rounded,         'Mode test',       '${data.testConfigs}',       'en mode sandbox',       _kGold),
      (Icons.corporate_fare_rounded,  'Groupes config.', '${data.configuredGroups}',  'groupes paramétrés',    _kOrange),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: LayoutBuilder(builder: (_, c) {
        final cols = c.maxWidth > 700 ? 4 : 2;
        return GridView.builder(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 3.0),
          itemCount: kpis.length,
          itemBuilder: (_, i) {
            final k = kpis[i];
            return _KpiCard(icon: k.$1, label: k.$2, value: k.$3, sub: k.$4, color: k.$5);
          },
        );
      }),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.icon, required this.label, required this.value, required this.sub, required this.color});
  final IconData icon; final String label; final String value; final String sub; final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: _kCard, borderRadius: BorderRadius.circular(10),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
    ),
    child: Row(children: [
      Container(width: 36, height: 36,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9)),
        child: Icon(icon, color: color, size: 18)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(label, style: TextStyle(fontSize: 10, color: _kSub, fontWeight: FontWeight.w500)),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _kText)),
        Text(sub,   style: TextStyle(fontSize: 9, color: Colors.grey.shade400)),
      ])),
    ]),
  );
}

// ─── Provider Overview tiles ──────────────────────────────────────────────────

class _ProviderOverview extends StatelessWidget {
  const _ProviderOverview({required this.data});
  final PaymentMethodsData data;

  @override
  Widget build(BuildContext context) {
    final providers = [
      _ProvDef(key: 'mtn_money',    label: 'MTN Mobile Money', icon: Icons.phone_android_rounded,  color: _kGold,               desc: 'Paiement mobile Orange/MTN'),
      const _ProvDef(key: 'airtel_money', label: 'Airtel Money',      icon: Icons.phone_android_rounded,  color: Color(0xFFEF4444), desc: 'Paiement mobile Airtel'),
      const _ProvDef(key: 'visa',         label: 'Visa / Mastercard',  icon: Icons.credit_card_rounded,    color: Color(0xFF1A1F71), desc: 'Carte bancaire internationale'),
      _ProvDef(key: 'especes',      label: 'Espèces',            icon: Icons.payments_rounded,       color: _kGreen,              desc: 'Dépôt / paiement en main propre'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: LayoutBuilder(builder: (_, c) {
        final cols = c.maxWidth > 700 ? 4 : 2;
        return GridView.builder(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 2.2),
          itemCount: providers.length,
          itemBuilder: (_, i) => _ProviderTile(def: providers[i], count: data.byProvider[providers[i].key] ?? 0),
        );
      }),
    );
  }
}

class _ProvDef {
  const _ProvDef({required this.key, required this.label, required this.icon, required this.color, required this.desc});
  final String key; final String label; final IconData icon; final Color color; final String desc;
}

class _ProviderTile extends StatelessWidget {
  const _ProviderTile({required this.def, required this.count});
  final _ProvDef def; final int count;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: count > 0 ? def.color.withValues(alpha: 0.06) : Colors.grey.shade50,
      border: Border.all(color: count > 0 ? def.color.withValues(alpha: 0.25) : kBorder),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 32, height: 32,
              decoration: BoxDecoration(color: def.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
              child: Icon(def.icon, color: def.color, size: 16)),
            const SizedBox(width: 8),
            Expanded(child: Text(def.label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                    color: count > 0 ? _kText : _kSub),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
        ),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(def.desc, style: TextStyle(fontSize: 9, color: _kSub),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: count > 0 ? def.color.withValues(alpha: 0.15) : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('$count groupe${count > 1 ? "s" : ""}',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                      color: count > 0 ? def.color : _kSub)),
            ),
          ],
        ),
      ],
    ),
  );
}

// ─── Filter bar ───────────────────────────────────────────────────────────────

class _FilterBar extends ConsumerWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Row(
    children: [
      Expanded(
        flex: 3,
        child: SizedBox(
          height: 38,
          child: TextField(
            onChanged: (v) => ref.read(_pmSearchProvider.notifier).state = v,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Rechercher par groupe ou fournisseur…',
              hintStyle: TextStyle(fontSize: 12, color: _kSub),
              prefixIcon: Icon(Icons.search_rounded, size: 18, color: _kSub),
              isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: kBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: kBorder)),
              filled: true, fillColor: kCardBg,
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        flex: 2,
        child: DropdownButtonFormField<String>(
          initialValue: ref.watch(_pmFilterProvider),
          onChanged: (v) => ref.read(_pmFilterProvider.notifier).state = v ?? 'all',
          items: const [
            DropdownMenuItem(value: 'all',         child: Text('Tous', style: TextStyle(fontSize: 12))),
            DropdownMenuItem(value: 'active',      child: Text('Actifs seulement', style: TextStyle(fontSize: 12))),
            DropdownMenuItem(value: 'test',        child: Text('Mode test', style: TextStyle(fontSize: 12))),
            DropdownMenuItem(value: 'mtn_money',   child: Text('MTN Money', style: TextStyle(fontSize: 12))),
            DropdownMenuItem(value: 'airtel_money',child: Text('Airtel Money', style: TextStyle(fontSize: 12))),
            DropdownMenuItem(value: 'visa',        child: Text('Visa', style: TextStyle(fontSize: 12))),
            DropdownMenuItem(value: 'especes',     child: Text('Espèces', style: TextStyle(fontSize: 12))),
          ],
          decoration: InputDecoration(
            isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: kBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: kBorder)),
            filled: true, fillColor: kCardBg,
          ),
        ),
      ),
      const SizedBox(width: 8),
      FilledButton.icon(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => const _PaymentConfigDialog(),
        ),
        icon: const Icon(Icons.add_rounded, size: 16),
        label: const Text('Nouveau mode'),
        style: FilledButton.styleFrom(
          backgroundColor: _kNavy, foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      const SizedBox(width: 4),
      IconButton(
        tooltip: 'Actualiser',
        icon: const Icon(Icons.refresh_rounded),
        color: _kNavy,
        onPressed: () => ref.invalidate(paymentMethodsProvider),
      ),
    ],
  );
}

// ─── Config list ──────────────────────────────────────────────────────────────

class _ConfigList extends ConsumerWidget {
  const _ConfigList({required this.configs, required this.ref});
  final List<PaymentConfigModel> configs; final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef r) {
    if (configs.isEmpty) return const _EmptyState();
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
      itemCount: configs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) => _ConfigCard(config: configs[i], ref: r, context: ctx),
    );
  }
}

class _ConfigCard extends ConsumerStatefulWidget {
  const _ConfigCard({required this.config, required this.ref, required this.context});
  final PaymentConfigModel config; final WidgetRef ref; final BuildContext context;
  @override
  ConsumerState<_ConfigCard> createState() => _ConfigCardState();
}

class _ConfigCardState extends ConsumerState<_ConfigCard> {
  late bool isActive;
  late bool isTest;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    isActive = widget.config.isActive;
    isTest   = widget.config.isTestMode;
  }

  @override
  void didUpdateWidget(covariant _ConfigCard old) {
    super.didUpdateWidget(old);
    isActive = widget.config.isActive;
    isTest   = widget.config.isTestMode;
  }

  Future<void> _toggleActive(bool v) async {
    final prev = isActive;
    setState(() { isActive = v; _saving = true; });
    try {
      await togglePaymentConfigActive(
          client: ref.read(supabaseClientProvider), id: widget.config.id, newValue: v);
      if (!mounted) return;
      ref.invalidate(paymentMethodsProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() => isActive = prev);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Échec de la mise à jour : $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleTest(bool v) async {
    final prev = isTest;
    setState(() { isTest = v; _saving = true; });
    try {
      await togglePaymentConfigTestMode(
          client: ref.read(supabaseClientProvider), id: widget.config.id, newValue: v);
      if (!mounted) return;
      ref.invalidate(paymentMethodsProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() => isTest = prev);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Échec de la mise à jour : $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  (String, Color, IconData) get _provDef => switch (widget.config.provider) {
    'mtn_money'    => ('MTN Mobile Money', _kGold,               Icons.phone_android_rounded),
    'airtel_money' => ('Airtel Money',     const Color(0xFFEF4444), Icons.phone_android_rounded),
    'visa'         => ('Visa / Carte',     const Color(0xFF1A1F71), Icons.credit_card_rounded),
    'especes'      => ('Espèces',          _kGreen,             Icons.payments_rounded),
    _               => (widget.config.provider, _kSub,          Icons.payment_rounded),
  };

  @override
  Widget build(BuildContext context) {
    final (provLabel, provColor, provIcon) = _provDef;
    final configDate = widget.config.configuredAt.isNotEmpty
        ? _fmtDate.format(DateTime.parse(widget.config.configuredAt)) : '—';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
        border: Border.all(
          color: isActive ? provColor.withValues(alpha: 0.3) : kBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: provColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(provIcon, color: provColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(provLabel, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isActive ? _kText : _kSub)),
                    Text(widget.config.groupName, style: TextStyle(fontSize: 11, color: _kSub)),
                  ],
                ),
              ),
              if (isTest)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(color: _kGold.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                  child: Text('TEST', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _kGold)),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: isActive ? _kGreen.withValues(alpha: 0.12) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(isActive ? 'Actif' : 'Inactif',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                        color: isActive ? _kGreen : _kSub)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (widget.config.merchantId.isNotEmpty) ...[
                Icon(Icons.store_rounded, size: 12, color: _kSub),
                const SizedBox(width: 4),
                Text('ID: ${widget.config.merchantId}',
                    style: TextStyle(fontSize: 11, color: _kSub, fontFamily: 'monospace')),
                const SizedBox(width: 12),
              ],
              Icon(Icons.calendar_today_rounded, size: 12, color: _kSub),
              const SizedBox(width: 4),
              Text('Configuré le $configDate', style: TextStyle(fontSize: 11, color: _kSub)),
              if (widget.config.notes.isNotEmpty) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(widget.config.notes,
                      style: TextStyle(fontSize: 10, color: _kSub, fontStyle: FontStyle.italic),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: kBorder),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('Actif', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _kText)),
              Switch(
                value: isActive,
                onChanged: _saving ? null : _toggleActive,
                activeThumbColor: _kGreen,
              ),
              const SizedBox(width: 16),
              Text('Mode test', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _kText)),
              Switch(
                value: isTest,
                onChanged: _saving ? null : _toggleTest,
                activeThumbColor: _kGold,
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => _PaymentConfigDialog(config: widget.config),
                ),
                icon: const Icon(Icons.edit_rounded, size: 14),
                label: const Text('Modifier'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kNavy, side: BorderSide(color: _kNavy),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Add / Edit dialog ────────────────────────────────────────────────────────

const List<(String, String)> _kProviderOptions = [
  ('mtn_money',    'MTN Mobile Money'),
  ('airtel_money', 'Airtel Money'),
  ('visa',         'Visa / Mastercard'),
  ('especes',      'Espèces'),
];

class _PaymentConfigDialog extends ConsumerStatefulWidget {
  const _PaymentConfigDialog({this.config});
  final PaymentConfigModel? config;
  @override
  ConsumerState<_PaymentConfigDialog> createState() => _PaymentConfigDialogState();
}

class _PaymentConfigDialogState extends ConsumerState<_PaymentConfigDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _displayName;
  late final TextEditingController _merchantId;
  late final TextEditingController _webhookUrl;
  late final TextEditingController _notes;
  final _apiKey    = TextEditingController();
  final _apiSecret = TextEditingController();

  String? _groupId;
  String  _provider = 'mtn_money';
  late bool _isActive;
  late bool _isTest;
  bool _saving = false;

  bool get _isEdit => widget.config != null;

  @override
  void initState() {
    super.initState();
    final c = widget.config;
    _displayName = TextEditingController(text: c?.displayName ?? '');
    _merchantId  = TextEditingController(text: c?.merchantId ?? '');
    _webhookUrl  = TextEditingController(text: c?.webhookUrl ?? '');
    _notes       = TextEditingController(text: c?.notes ?? '');
    _groupId     = c?.groupId;
    _provider    = (c != null && c.provider.isNotEmpty) ? c.provider : 'mtn_money';
    _isActive    = c?.isActive ?? false;
    _isTest      = c?.isTestMode ?? true;
  }

  @override
  void dispose() {
    _displayName.dispose(); _merchantId.dispose(); _webhookUrl.dispose();
    _notes.dispose(); _apiKey.dispose(); _apiSecret.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isEdit && _groupId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sélectionnez un groupe scolaire.')));
      return;
    }
    setState(() => _saving = true);
    final client = ref.read(supabaseClientProvider);
    try {
      if (_isEdit) {
        await updatePaymentConfig(
          client: client, id: widget.config!.id,
          displayName: _displayName.text, merchantId: _merchantId.text,
          webhookUrl: _webhookUrl.text, notes: _notes.text,
          apiKey: _apiKey.text, apiSecret: _apiSecret.text,
          isActive: _isActive, isTestMode: _isTest,
        );
      } else {
        await createPaymentConfig(
          client: client, groupId: _groupId!, provider: _provider,
          displayName: _displayName.text, merchantId: _merchantId.text,
          webhookUrl: _webhookUrl.text, notes: _notes.text,
          apiKey: _apiKey.text, apiSecret: _apiSecret.text,
          isActive: _isActive, isTestMode: _isTest,
          configuredBy: client.auth.currentUser?.id,
        );
      }
      if (!mounted) return;
      ref.invalidate(paymentMethodsProvider);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEdit ? 'Configuration mise à jour.' : 'Mode de paiement ajouté.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Échec : $e')));
    }
  }

  static String _providerLabel(String key) =>
      _kProviderOptions.firstWhere((o) => o.$1 == key, orElse: () => (key, key)).$2;

  InputDecoration _dec(String label) => InputDecoration(
    labelText: label,
    labelStyle: TextStyle(fontSize: 12, color: _kSub),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border:        OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: kBorder)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: kBorder)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _kNavy)),
  );

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(paymentConfigGroupsProvider);
    return AlertDialog(
      backgroundColor: kCardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(_isEdit ? 'Modifier le mode de paiement' : 'Nouveau mode de paiement',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _kText)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isEdit)
                    InputDecorator(
                      decoration: _dec('Groupe'),
                      child: Text(widget.config!.groupName, style: TextStyle(fontSize: 13, color: _kText)),
                    )
                  else
                    groupsAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: LinearProgressIndicator(),
                      ),
                      error: (e, _) => Text('Erreur chargement groupes : $e',
                          style: const TextStyle(fontSize: 12, color: _kOrange)),
                      data: (groups) => DropdownButtonFormField<String>(
                        initialValue: _groupId,
                        isExpanded: true,
                        decoration: _dec('Groupe scolaire *'),
                        items: groups.map((g) => DropdownMenuItem(
                            value: g.id, child: Text(g.name, style: const TextStyle(fontSize: 13)))).toList(),
                        onChanged: (v) => setState(() => _groupId = v),
                        validator: (v) => v == null ? 'Requis' : null,
                      ),
                    ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _provider,
                    isExpanded: true,
                    decoration: _dec('Fournisseur *'),
                    items: _kProviderOptions.map((o) => DropdownMenuItem(
                        value: o.$1, child: Text(o.$2, style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: _isEdit ? null : (v) => setState(() => _provider = v ?? 'mtn_money'),
                    disabledHint: Text(_providerLabel(_provider), style: const TextStyle(fontSize: 13)),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _displayName,
                    decoration: _dec('Nom affiché *'),
                    style: const TextStyle(fontSize: 13),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(controller: _merchantId, decoration: _dec('Identifiant marchand'), style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 12),
                  TextFormField(controller: _webhookUrl, decoration: _dec('URL Webhook'), style: const TextStyle(fontSize: 13), keyboardType: TextInputType.url),
                  const SizedBox(height: 12),
                  TextFormField(controller: _apiKey, decoration: _dec(_isEdit ? 'Clé API (laisser vide pour conserver)' : 'Clé API'), style: const TextStyle(fontSize: 13), obscureText: true),
                  const SizedBox(height: 12),
                  TextFormField(controller: _apiSecret, decoration: _dec(_isEdit ? 'Secret API (laisser vide pour conserver)' : 'Secret API'), style: const TextStyle(fontSize: 13), obscureText: true),
                  const SizedBox(height: 12),
                  TextFormField(controller: _notes, decoration: _dec('Notes'), style: const TextStyle(fontSize: 13), maxLines: 2),
                  const SizedBox(height: 8),
                  Row(children: [
                    Switch(value: _isActive, activeThumbColor: _kGreen, onChanged: (v) => setState(() => _isActive = v)),
                    Text('Actif', style: TextStyle(fontSize: 13, color: _kText)),
                    const SizedBox(width: 12),
                    Switch(value: _isTest, activeThumbColor: _kGold, onChanged: (v) => setState(() => _isTest = v)),
                    Text('Mode test', style: TextStyle(fontSize: 13, color: _kText)),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text('Annuler', style: TextStyle(color: _kSub)),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(backgroundColor: _kNavy),
          child: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(_isEdit ? 'Enregistrer' : 'Ajouter'),
        ),
      ],
    );
  }
}

// ─── Empty / Loading / Error ──────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.payment_rounded, size: 56, color: Colors.grey.shade300),
      const SizedBox(height: 12),
      Text('Aucun mode de paiement configuré',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _kText)),
      const SizedBox(height: 4),
      Text('Configurez les modes de paiement par groupe scolaire',
          style: TextStyle(fontSize: 12, color: _kSub)),
    ]),
  );
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(children: [
      GridView.builder(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 3.0),
        itemCount: 4, itemBuilder: (_, _) => const _S(height: 60)),
      const SizedBox(height: 10),
      GridView.builder(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 2.2),
        itemCount: 4, itemBuilder: (_, _) => const _S(height: 90)),
      const SizedBox(height: 10),
      ...List.generate(3, (_) => const Padding(padding: EdgeInsets.only(bottom: 10), child: _S(height: 120))),
    ]),
  );
}

class _S extends StatelessWidget {
  const _S({required this.height});
  final double height;
  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
  );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final String error; final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFEF4444)),
    const SizedBox(height: 12),
    Text('Erreur : $error', style: TextStyle(fontSize: 12, color: _kSub), textAlign: TextAlign.center),
    const SizedBox(height: 16),
    ElevatedButton.icon(onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded, size: 16), label: const Text('Réessayer')),
  ]));
}
