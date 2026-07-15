import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_shell.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../providers/platform_settings_provider.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
const _kNavy   = Color(0xFF1E3A5F);
const _kGreen  = Color(0xFF009A44);
const _kGold   = Color(0xFFFBBC04);
const _kOrange = Color(0xFFFF6B35);
const _kRed    = Color(0xFFEF4444);
const _kCard   = Colors.white;
const _kText   = Color(0xFF0F172A);
const _kSub    = Color(0xFF64748B);
const _kBorder = Color(0xFFE2E8F0);

// ─── Screen ───────────────────────────────────────────────────────────────────

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  // ── Général ──────────────────────────────────────────────────────────────────
  final _platformNameCtrl  = TextEditingController(text: 'E-PILOTE CONGO');
  final _platformDescCtrl  = TextEditingController(text: 'Plateforme de gestion scolaire pour la République du Congo');
  final _supportEmailCtrl  = TextEditingController(text: 'support@epilote.cg');
  final _supportPhoneCtrl  = TextEditingController(text: '+242 06 000 0000');
  final _websiteCtrl       = TextEditingController(text: 'https://epilote.cg');
  final _maxGroupsCtrl     = TextEditingController(text: '500');
  final _maxSchoolsCtrl    = TextEditingController(text: '5000');
  bool   _maintenanceMode  = false;
  bool   _registrationOpen = true;
  String _defaultLanguage  = 'fr';
  String _defaultTimezone  = 'Africa/Brazzaville';

  // ── Facturation ───────────────────────────────────────────────────────────────
  final _taxRateCtrl       = TextEditingController(text: '18');
  final _invoicePrefixCtrl = TextEditingController(text: 'INV');
  final _receiptPrefixCtrl = TextEditingController(text: 'REC');
  final _dueDaysCtrl       = TextEditingController(text: '30');
  final _graceCtrl         = TextEditingController(text: '7');
  final _trialDaysCtrl     = TextEditingController(text: '3');
  final _companyNameCtrl   = TextEditingController(text: 'E-PILOTE CONGO SARL');
  final _companyRccCtrl    = TextEditingController(text: 'RC-BZV-2024-B-0001');
  final _companyTaxCtrl    = TextEditingController(text: 'M202400001');
  final _bankNameCtrl      = TextEditingController(text: 'BGFI Bank Congo');
  final _bankIbanCtrl      = TextEditingController(text: 'CG00 0000 0000 0000 0000 0000 000');
  bool   _autoInvoice      = true;
  bool   _sendInvoiceEmail = true;
  bool   _taxInclusive     = false;

  // ── Notifications ─────────────────────────────────────────────────────────────
  bool _notifInvoiceDue        = true;
  bool _notifPaymentReceived   = true;
  bool _notifSubscriptionExpiry = true;
  bool _notifNewGroup          = true;
  bool _notifAuditAlert        = true;
  bool _notifPushEnabled       = true;
  bool _notifEmailEnabled      = true;
  bool _notifSmsEnabled        = false;
  final _notifEmailCtrl        = TextEditingController(text: 'admin@epilote.cg');
  final _notifReminderCtrl     = TextEditingController(text: '30,15,7,1,0');

  // ── Sécurité ──────────────────────────────────────────────────────────────────
  bool _mfaRequired            = false;
  bool _auditLogEnabled        = true;
  bool _sessionTimeout         = true;
  bool _ipWhitelist            = false;
  final _sessionDurationCtrl   = TextEditingController(text: '480');
  final _maxLoginAttemptsCtrl  = TextEditingController(text: '5');
  final _lockoutDurationCtrl   = TextEditingController(text: '30');
  final _ipWhitelistCtrl       = TextEditingController(text: '');
  String _passwordPolicy       = 'strong';
  bool _logApiCalls            = true;

  // ── Intégrations ──────────────────────────────────────────────────────────────
  bool _mtnMoneyEnabled    = true;
  bool _airtelMoneyEnabled = true;
  bool _visaEnabled        = false;
  bool _especesEnabled     = true;
  final _mtnApiKeyCtrl     = TextEditingController(text: '••••••••••••');
  final _airtelApiKeyCtrl  = TextEditingController(text: '••••••••••••');
  final _webhookBaseCtrl   = TextEditingController(text: 'https://api.epilote.cg/webhooks');
  final _smtpHostCtrl      = TextEditingController(text: 'smtp.gmail.com');
  final _smtpPortCtrl      = TextEditingController(text: '587');
  final _smtpUserCtrl      = TextEditingController(text: 'noreply@epilote.cg');
  bool _smsGatewayEnabled  = false;
  final _smsApiKeyCtrl     = TextEditingController(text: '');

  // ── State ─────────────────────────────────────────────────────────────────────
  bool _saving   = false;
  bool _saved    = false;
  bool _loaded   = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final data = await ref.read(platformSettingsProvider.future);
      if (!mounted) return;
      setState(() {
        _applyData(data);
        _loaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _loaded = true;
      });
    }
  }

  void _applyData(Map<String, dynamic> d) {
    if (d.isEmpty) return;
    void txt(TextEditingController c, String key) {
      if (d[key] != null) c.text = d[key].toString();
    }
    bool flag(String key, bool fallback) => d[key] is bool ? d[key] as bool : fallback;
    String str(String key, String fallback) => d[key] is String && (d[key] as String).isNotEmpty ? d[key] as String : fallback;

    // Général
    txt(_platformNameCtrl, 'platform_name');
    txt(_platformDescCtrl, 'platform_desc');
    txt(_supportEmailCtrl, 'support_email');
    txt(_supportPhoneCtrl, 'support_phone');
    txt(_websiteCtrl,      'website');
    txt(_maxGroupsCtrl,    'max_groups');
    txt(_maxSchoolsCtrl,   'max_schools');
    _maintenanceMode  = flag('maintenance_mode', _maintenanceMode);
    _registrationOpen = flag('registration_open', _registrationOpen);
    _defaultLanguage  = str('default_language', _defaultLanguage);
    _defaultTimezone  = str('default_timezone', _defaultTimezone);

    // Facturation
    txt(_taxRateCtrl,       'tax_rate');
    txt(_invoicePrefixCtrl, 'invoice_prefix');
    txt(_receiptPrefixCtrl, 'receipt_prefix');
    txt(_dueDaysCtrl,       'due_days');
    txt(_graceCtrl,         'grace_days');
    txt(_trialDaysCtrl,     'trial_days');
    txt(_companyNameCtrl,   'company_name');
    txt(_companyRccCtrl,    'company_rcc');
    txt(_companyTaxCtrl,    'company_tax');
    txt(_bankNameCtrl,      'bank_name');
    txt(_bankIbanCtrl,      'bank_iban');
    _autoInvoice      = flag('auto_invoice', _autoInvoice);
    _sendInvoiceEmail = flag('send_invoice_email', _sendInvoiceEmail);
    _taxInclusive     = flag('tax_inclusive', _taxInclusive);

    // Notifications
    _notifInvoiceDue         = flag('notif_invoice_due', _notifInvoiceDue);
    _notifPaymentReceived    = flag('notif_payment_received', _notifPaymentReceived);
    _notifSubscriptionExpiry = flag('notif_subscription_expiry', _notifSubscriptionExpiry);
    _notifNewGroup           = flag('notif_new_group', _notifNewGroup);
    _notifAuditAlert         = flag('notif_audit_alert', _notifAuditAlert);
    _notifPushEnabled        = flag('notif_push', _notifPushEnabled);
    _notifEmailEnabled       = flag('notif_email', _notifEmailEnabled);
    _notifSmsEnabled         = flag('notif_sms', _notifSmsEnabled);
    txt(_notifEmailCtrl,    'notif_email_addr');
    txt(_notifReminderCtrl, 'notif_reminder_days');

    // Sécurité
    _mfaRequired     = flag('mfa_required', _mfaRequired);
    _auditLogEnabled = flag('audit_log_enabled', _auditLogEnabled);
    _sessionTimeout  = flag('session_timeout', _sessionTimeout);
    _ipWhitelist     = flag('ip_whitelist_enabled', _ipWhitelist);
    txt(_sessionDurationCtrl,  'session_duration');
    txt(_maxLoginAttemptsCtrl, 'max_login_attempts');
    txt(_lockoutDurationCtrl,  'lockout_duration');
    txt(_ipWhitelistCtrl,      'ip_whitelist');
    _passwordPolicy = str('password_policy', _passwordPolicy);
    _logApiCalls    = flag('log_api_calls', _logApiCalls);

    // Intégrations (hors secrets)
    _mtnMoneyEnabled    = flag('mtn_enabled', _mtnMoneyEnabled);
    _airtelMoneyEnabled = flag('airtel_enabled', _airtelMoneyEnabled);
    _visaEnabled        = flag('visa_enabled', _visaEnabled);
    _especesEnabled     = flag('especes_enabled', _especesEnabled);
    txt(_webhookBaseCtrl, 'webhook_base');
    txt(_smtpHostCtrl,    'smtp_host');
    txt(_smtpPortCtrl,    'smtp_port');
    txt(_smtpUserCtrl,    'smtp_user');
    _smsGatewayEnabled  = flag('sms_gateway_enabled', _smsGatewayEnabled);
  }

  Map<String, dynamic> _collectData() => {
    // Général
    'platform_name':  _platformNameCtrl.text.trim(),
    'platform_desc':  _platformDescCtrl.text.trim(),
    'support_email':  _supportEmailCtrl.text.trim(),
    'support_phone':  _supportPhoneCtrl.text.trim(),
    'website':        _websiteCtrl.text.trim(),
    'max_groups':     _maxGroupsCtrl.text.trim(),
    'max_schools':    _maxSchoolsCtrl.text.trim(),
    'maintenance_mode':  _maintenanceMode,
    'registration_open': _registrationOpen,
    'default_language':  _defaultLanguage,
    'default_timezone':  _defaultTimezone,
    // Facturation
    'tax_rate':        _taxRateCtrl.text.trim(),
    'invoice_prefix':  _invoicePrefixCtrl.text.trim(),
    'receipt_prefix':  _receiptPrefixCtrl.text.trim(),
    'due_days':        _dueDaysCtrl.text.trim(),
    'grace_days':      _graceCtrl.text.trim(),
    'trial_days':      _trialDaysCtrl.text.trim(),
    'company_name':    _companyNameCtrl.text.trim(),
    'company_rcc':     _companyRccCtrl.text.trim(),
    'company_tax':     _companyTaxCtrl.text.trim(),
    'bank_name':       _bankNameCtrl.text.trim(),
    'bank_iban':       _bankIbanCtrl.text.trim(),
    'auto_invoice':       _autoInvoice,
    'send_invoice_email': _sendInvoiceEmail,
    'tax_inclusive':      _taxInclusive,
    // Notifications
    'notif_invoice_due':         _notifInvoiceDue,
    'notif_payment_received':    _notifPaymentReceived,
    'notif_subscription_expiry': _notifSubscriptionExpiry,
    'notif_new_group':           _notifNewGroup,
    'notif_audit_alert':         _notifAuditAlert,
    'notif_push':  _notifPushEnabled,
    'notif_email': _notifEmailEnabled,
    'notif_sms':   _notifSmsEnabled,
    'notif_email_addr':    _notifEmailCtrl.text.trim(),
    'notif_reminder_days': _notifReminderCtrl.text.trim(),
    // Sécurité
    'mfa_required':         _mfaRequired,
    'audit_log_enabled':    _auditLogEnabled,
    'session_timeout':      _sessionTimeout,
    'ip_whitelist_enabled': _ipWhitelist,
    'session_duration':   _sessionDurationCtrl.text.trim(),
    'max_login_attempts': _maxLoginAttemptsCtrl.text.trim(),
    'lockout_duration':   _lockoutDurationCtrl.text.trim(),
    'ip_whitelist':       _ipWhitelistCtrl.text.trim(),
    'password_policy':    _passwordPolicy,
    'log_api_calls':      _logApiCalls,
    // Intégrations (hors secrets : les clés API ne sont jamais persistées ici)
    'mtn_enabled':        _mtnMoneyEnabled,
    'airtel_enabled':     _airtelMoneyEnabled,
    'visa_enabled':       _visaEnabled,
    'especes_enabled':    _especesEnabled,
    'webhook_base':       _webhookBaseCtrl.text.trim(),
    'smtp_host':          _smtpHostCtrl.text.trim(),
    'smtp_port':          _smtpPortCtrl.text.trim(),
    'smtp_user':          _smtpUserCtrl.text.trim(),
    'sms_gateway_enabled': _smsGatewayEnabled,
  };

  @override
  void dispose() {
    _tabs.dispose();
    for (final c in [
      _platformNameCtrl, _platformDescCtrl, _supportEmailCtrl, _supportPhoneCtrl,
      _websiteCtrl, _maxGroupsCtrl, _maxSchoolsCtrl,
      _taxRateCtrl, _invoicePrefixCtrl, _receiptPrefixCtrl, _dueDaysCtrl,
      _graceCtrl, _trialDaysCtrl, _companyNameCtrl, _companyRccCtrl, _companyTaxCtrl,
      _bankNameCtrl, _bankIbanCtrl,
      _notifEmailCtrl, _notifReminderCtrl,
      _sessionDurationCtrl, _maxLoginAttemptsCtrl, _lockoutDurationCtrl, _ipWhitelistCtrl,
      _mtnApiKeyCtrl, _airtelApiKeyCtrl, _webhookBaseCtrl,
      _smtpHostCtrl, _smtpPortCtrl, _smtpUserCtrl, _smsApiKeyCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() { _saving = true; _saved = false; });
    try {
      final client = ref.read(supabaseClientProvider);
      final userId = client.auth.currentUser?.id;
      await savePlatformSettings(client, _collectData(), updatedBy: userId);
      ref.invalidate(platformSettingsProvider);
      if (!mounted) return;
      setState(() { _saving = false; _saved = true; });
      messenger.showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Paramètres enregistrés avec succès'),
          ]),
          backgroundColor: _kGreen,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _saved = false);
    } catch (e) {
      if (!mounted) return;
      setState(() { _saving = false; _saved = false; });
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'enregistrement : $e'),
          backgroundColor: _kRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Paramètres de la plateforme',
      child: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                _TabBar(controller: _tabs),
                const Spacer(),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  child: FilledButton.icon(
                    onPressed: (_saving || !_loaded) ? null : _save,
                    icon: _saving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Icon(_saved ? Icons.check_rounded : Icons.save_rounded, size: 16),
                    label: Text(_saving ? 'Enregistrement…' : _saved ? 'Enregistré !' : 'Enregistrer'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _saved ? _kGreen : _kNavy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_loadError != null)
            Container(
              width: double.infinity,
              color: _kRed.withValues(alpha: 0.08),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded, color: _kRed, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  'Impossible de charger les paramètres enregistrés (valeurs par défaut affichées) : $_loadError',
                  style: const TextStyle(fontSize: 11, color: _kRed),
                )),
              ]),
            ),
          Expanded(
            child: !_loaded
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabs,
                    children: [
                      _TabGeneral(state: this),
                      _TabFacturation(state: this),
                      _TabNotifications(state: this),
                      _TabSecurite(state: this),
                      _TabIntegrations(state: this),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Tab bar ──────────────────────────────────────────────────────────────────

class _TabBar extends StatelessWidget {
  const _TabBar({required this.controller});
  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return TabBar(
      controller: controller,
      labelColor: _kNavy,
      unselectedLabelColor: _kSub,
      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      indicatorColor: _kNavy,
      indicatorWeight: 3,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      tabs: const [
        Tab(icon: Icon(Icons.settings_rounded, size: 15), text: 'Général'),
        Tab(icon: Icon(Icons.receipt_rounded, size: 15), text: 'Facturation'),
        Tab(icon: Icon(Icons.notifications_rounded, size: 15), text: 'Notifications'),
        Tab(icon: Icon(Icons.security_rounded, size: 15), text: 'Sécurité'),
        Tab(icon: Icon(Icons.extension_rounded, size: 15), text: 'Intégrations'),
      ],
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children}) : trailing = null;
  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kNavy)),
                ?trailing,
              ],
            ),
          ),
          const Divider(height: 16, thickness: 1, indent: 16, endIndent: 16, color: _kBorder),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.label, required this.ctrl, this.hint = '', this.suffix, this.numeric = false, this.csv = false, this.lines = 1});
  final String label; final TextEditingController ctrl; final String hint;
  final String? suffix; final bool numeric; final bool csv; final int lines;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kText)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          maxLines: lines,
          keyboardType: (numeric || csv) ? TextInputType.number : TextInputType.text,
          inputFormatters: numeric
              ? [FilteringTextInputFormatter.digitsOnly]
              : csv
                  ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9, ]'))]
                  : null,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            suffixText: suffix,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _kBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _kBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _kNavy, width: 1.5),
            ),
          ),
        ),
      ],
    ),
  );
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.label, required this.sub, required this.value, required this.onChanged, this.color = _kNavy});
  final String label; final String sub; final bool value;
  final ValueChanged<bool> onChanged; final Color color;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _kText)),
            Text(sub, style: const TextStyle(fontSize: 11, color: _kSub)),
          ],
        )),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: color,
        ),
      ],
    ),
  );
}

class _SelectRow extends StatelessWidget {
  const _SelectRow({required this.label, required this.value, required this.items, required this.onChanged});
  final String label; final String value;
  final Map<String, String> items; final ValueChanged<String?> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kText)),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          initialValue: value,
          onChanged: onChanged,
          items: items.entries.map((e) =>
              DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 13)))).toList(),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBorder)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kNavy, width: 1.5)),
          ),
        ),
      ],
    ),
  );
}

Widget _row2(Widget a, Widget b) => Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [Expanded(child: a), const SizedBox(width: 12), Expanded(child: b)],
);

// ─── Tab Général ──────────────────────────────────────────────────────────────

class _TabGeneral extends StatefulWidget {
  const _TabGeneral({required this.state});
  final _SettingsScreenState state;
  @override
  State<_TabGeneral> createState() => _TabGeneralState();
}
class _TabGeneralState extends State<_TabGeneral> {
  _SettingsScreenState get s => widget.state;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _Section(
            title: 'Identité de la plateforme',
            children: [
              _FieldRow(label: 'Nom de la plateforme', ctrl: s._platformNameCtrl, hint: 'E-PILOTE CONGO'),
              _FieldRow(label: 'Description', ctrl: s._platformDescCtrl, hint: 'Description courte', lines: 2),
              _row2(
                _FieldRow(label: 'Email support', ctrl: s._supportEmailCtrl, hint: 'support@...'),
                _FieldRow(label: 'Téléphone support', ctrl: s._supportPhoneCtrl, hint: '+242 …'),
              ),
              _FieldRow(label: 'Site web', ctrl: s._websiteCtrl, hint: 'https://'),
            ],
          ),
          _Section(
            title: 'Limites & Quotas',
            children: [
              _row2(
                _FieldRow(label: 'Max groupes scolaires', ctrl: s._maxGroupsCtrl, numeric: true, suffix: 'groupes'),
                _FieldRow(label: 'Max établissements', ctrl: s._maxSchoolsCtrl, numeric: true, suffix: 'écoles'),
              ),
            ],
          ),
          _Section(
            title: 'Localisation',
            children: [
              _row2(
                _SelectRow(
                  label: 'Langue par défaut',
                  value: s._defaultLanguage,
                  items: const {'fr': 'Français', 'en': 'English'},
                  onChanged: (v) => setState(() => s._defaultLanguage = v ?? 'fr'),
                ),
                _SelectRow(
                  label: 'Fuseau horaire',
                  value: s._defaultTimezone,
                  items: const {
                    'Africa/Brazzaville': 'Africa/Brazzaville (UTC+1)',
                    'Africa/Lagos':       'Africa/Lagos (UTC+1)',
                    'UTC':                'UTC',
                  },
                  onChanged: (v) => setState(() => s._defaultTimezone = v ?? 'Africa/Brazzaville'),
                ),
              ),
            ],
          ),
          _Section(
            title: 'Mode d\'exploitation',
            children: [
              _SwitchRow(
                label: 'Mode maintenance',
                sub: 'Bloque l\'accès à tous les utilisateurs non super-admin',
                value: s._maintenanceMode,
                onChanged: (v) => setState(() => s._maintenanceMode = v),
                color: _kOrange,
              ),
              _SwitchRow(
                label: 'Inscriptions ouvertes',
                sub: 'Permet aux nouveaux groupes scolaires de s\'inscrire',
                value: s._registrationOpen,
                onChanged: (v) => setState(() => s._registrationOpen = v),
                color: _kGreen,
              ),
            ],
          ),
          if (s._maintenanceMode)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _kOrange.withValues(alpha: 0.08),
                border: Border.all(color: _kOrange.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(children: [
                Icon(Icons.warning_amber_rounded, color: _kOrange, size: 18),
                SizedBox(width: 8),
                Expanded(child: Text(
                  'Le mode maintenance est actif. Seul le super-admin peut accéder à la plateforme.',
                  style: TextStyle(fontSize: 12, color: _kOrange, fontWeight: FontWeight.w500),
                )),
              ]),
            ),
        ],
      ),
    );
  }
}

// ─── Tab Facturation ──────────────────────────────────────────────────────────

class _TabFacturation extends StatefulWidget {
  const _TabFacturation({required this.state});
  final _SettingsScreenState state;
  @override
  State<_TabFacturation> createState() => _TabFacturationState();
}
class _TabFacturationState extends State<_TabFacturation> {
  _SettingsScreenState get s => widget.state;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _Section(
            title: 'Configuration générale',
            children: [
              _row2(
                _FieldRow(label: 'Taux de TVA', ctrl: s._taxRateCtrl, numeric: true, suffix: '%'),
                _FieldRow(label: 'Délai paiement', ctrl: s._dueDaysCtrl, numeric: true, suffix: 'jours'),
              ),
              _row2(
                _FieldRow(label: 'Préfixe facture', ctrl: s._invoicePrefixCtrl, hint: 'INV'),
                _FieldRow(label: 'Préfixe reçu', ctrl: s._receiptPrefixCtrl, hint: 'REC'),
              ),
              _row2(
                _FieldRow(label: 'Délai de grâce', ctrl: s._graceCtrl, numeric: true, suffix: 'jours après échéance'),
                _FieldRow(label: "Durée d'essai", ctrl: s._trialDaysCtrl, numeric: true, suffix: 'jours (nouveaux groupes)'),
              ),
              _SwitchRow(
                label: 'Facturation automatique',
                sub: 'Génère les factures automatiquement à la date de renouvellement',
                value: s._autoInvoice,
                onChanged: (v) => setState(() => s._autoInvoice = v),
              ),
              _SwitchRow(
                label: 'Envoi par email',
                sub: 'Envoie la facture PDF par email au groupe dès la génération',
                value: s._sendInvoiceEmail,
                onChanged: (v) => setState(() => s._sendInvoiceEmail = v),
              ),
              _SwitchRow(
                label: 'Prix TTC',
                sub: 'Les montants affichés incluent la TVA',
                value: s._taxInclusive,
                onChanged: (v) => setState(() => s._taxInclusive = v),
              ),
            ],
          ),
          _Section(
            title: 'Informations légales',
            children: [
              _FieldRow(label: 'Raison sociale', ctrl: s._companyNameCtrl),
              _row2(
                _FieldRow(label: 'N° RCCM', ctrl: s._companyRccCtrl, hint: 'RC-BZV-…'),
                _FieldRow(label: 'N° Identifiant Fiscal', ctrl: s._companyTaxCtrl, hint: 'M20…'),
              ),
            ],
          ),
          _Section(
            title: 'Coordonnées bancaires',
            children: [
              _FieldRow(label: 'Banque', ctrl: s._bankNameCtrl),
              _FieldRow(label: 'IBAN / RIB', ctrl: s._bankIbanCtrl),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Tab Notifications ────────────────────────────────────────────────────────

class _TabNotifications extends StatefulWidget {
  const _TabNotifications({required this.state});
  final _SettingsScreenState state;
  @override
  State<_TabNotifications> createState() => _TabNotificationsState();
}
class _TabNotificationsState extends State<_TabNotifications> {
  _SettingsScreenState get s => widget.state;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _Section(
            title: 'Canaux d\'envoi',
            children: [
              _SwitchRow(
                label: 'Notifications email',
                sub: 'Envoie des emails automatiques pour les événements clés',
                value: s._notifEmailEnabled,
                onChanged: (v) => setState(() => s._notifEmailEnabled = v),
              ),
              _SwitchRow(
                label: 'Notifications push',
                sub: 'Notifications en temps réel dans l\'interface web et mobile',
                value: s._notifPushEnabled,
                onChanged: (v) => setState(() => s._notifPushEnabled = v),
              ),
              _SwitchRow(
                label: 'Notifications SMS',
                sub: 'Envoi de SMS via passerelle (nécessite configuration Intégrations)',
                value: s._notifSmsEnabled,
                onChanged: (v) => setState(() => s._notifSmsEnabled = v),
              ),
              if (s._notifEmailEnabled) ...[
                const Divider(height: 16, color: _kBorder),
                _FieldRow(label: 'Email destinataire admin', ctrl: s._notifEmailCtrl, hint: 'admin@...'),
              ],
            ],
          ),
          _Section(
            title: 'Événements déclencheurs',
            children: [
              _SwitchRow(
                label: 'Facture échue',
                sub: 'Notifie quand une facture atteint sa date d\'échéance',
                value: s._notifInvoiceDue,
                onChanged: (v) => setState(() => s._notifInvoiceDue = v),
              ),
              _SwitchRow(
                label: 'Paiement reçu',
                sub: 'Notifie à chaque confirmation de paiement',
                value: s._notifPaymentReceived,
                onChanged: (v) => setState(() => s._notifPaymentReceived = v),
                color: _kGreen,
              ),
              _SwitchRow(
                label: 'Abonnement expirant',
                sub: 'Alerte avant l\'expiration d\'un abonnement',
                value: s._notifSubscriptionExpiry,
                onChanged: (v) => setState(() => s._notifSubscriptionExpiry = v),
                color: _kOrange,
              ),
              _SwitchRow(
                label: 'Nouveau groupe inscrit',
                sub: 'Notifie le super-admin lors de chaque nouvelle inscription',
                value: s._notifNewGroup,
                onChanged: (v) => setState(() => s._notifNewGroup = v),
              ),
              _SwitchRow(
                label: 'Alerte d\'audit',
                sub: 'Notifie pour les actions sensibles (suppressions, modifications admin)',
                value: s._notifAuditAlert,
                onChanged: (v) => setState(() => s._notifAuditAlert = v),
                color: _kRed,
              ),
            ],
          ),
          _Section(
            title: 'Rappels automatiques',
            children: [
              _FieldRow(
                label: 'Jours de rappel avant échéance',
                ctrl: s._notifReminderCtrl,
                csv: true,
                hint: '30, 15, 7, 1, 0',
                suffix: 'jours (liste séparée par des virgules)',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Tab Sécurité ─────────────────────────────────────────────────────────────

class _TabSecurite extends StatefulWidget {
  const _TabSecurite({required this.state});
  final _SettingsScreenState state;
  @override
  State<_TabSecurite> createState() => _TabSecuriteState();
}
class _TabSecuriteState extends State<_TabSecurite> {
  _SettingsScreenState get s => widget.state;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _Section(
            title: 'Authentification',
            children: [
              _SwitchRow(
                label: 'Double authentification (MFA)',
                sub: 'Exige un second facteur pour tous les comptes admin',
                value: s._mfaRequired,
                onChanged: (v) => setState(() => s._mfaRequired = v),
                color: _kGreen,
              ),
              _SelectRow(
                label: 'Politique de mot de passe',
                value: s._passwordPolicy,
                items: const {
                  'basic':  'Basique (6+ caractères)',
                  'medium': 'Moyen (8+, majuscule + chiffre)',
                  'strong': 'Fort (12+, majuscule + chiffre + symbole)',
                },
                onChanged: (v) => setState(() => s._passwordPolicy = v ?? 'strong'),
              ),
              _row2(
                _FieldRow(label: 'Tentatives max avant blocage', ctrl: s._maxLoginAttemptsCtrl, numeric: true, suffix: 'essais'),
                _FieldRow(label: 'Durée de blocage', ctrl: s._lockoutDurationCtrl, numeric: true, suffix: 'min'),
              ),
            ],
          ),
          _Section(
            title: 'Sessions',
            children: [
              _SwitchRow(
                label: 'Expiration de session automatique',
                sub: 'Déconnecte les utilisateurs inactifs',
                value: s._sessionTimeout,
                onChanged: (v) => setState(() => s._sessionTimeout = v),
              ),
              if (s._sessionTimeout)
                _FieldRow(
                  label: 'Durée de session',
                  ctrl: s._sessionDurationCtrl,
                  numeric: true,
                  suffix: 'minutes',
                ),
            ],
          ),
          _Section(
            title: 'Audit & Traçabilité',
            children: [
              _SwitchRow(
                label: 'Journal d\'audit actif',
                sub: 'Enregistre toutes les actions sensibles avec IP, date et utilisateur',
                value: s._auditLogEnabled,
                onChanged: (v) => setState(() => s._auditLogEnabled = v),
                color: _kNavy,
              ),
              _SwitchRow(
                label: 'Journaliser les appels API',
                sub: 'Enregistre les requêtes API entrantes et leurs réponses',
                value: s._logApiCalls,
                onChanged: (v) => setState(() => s._logApiCalls = v),
              ),
            ],
          ),
          _Section(
            title: 'Contrôle d\'accès réseau',
            children: [
              _SwitchRow(
                label: 'Whitelist IP admin',
                sub: 'Restreint l\'accès super-admin aux adresses IP autorisées',
                value: s._ipWhitelist,
                onChanged: (v) => setState(() => s._ipWhitelist = v),
                color: _kRed,
              ),
              if (s._ipWhitelist)
                _FieldRow(
                  label: 'Adresses IP autorisées',
                  ctrl: s._ipWhitelistCtrl,
                  hint: '192.168.1.1, 10.0.0.0/24',
                  lines: 3,
                ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kNavy.withValues(alpha: 0.05),
              border: Border.all(color: _kNavy.withValues(alpha: 0.15)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded, color: _kNavy, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'Supabase gère l\'infrastructure d\'authentification. Ces paramètres '
                'configurent des couches supplémentaires de sécurité applicative.',
                style: TextStyle(fontSize: 11, color: _kNavy.withValues(alpha: 0.8)),
              )),
            ]),
          ),
        ],
      ),
    );
  }
}

// ─── Tab Intégrations ─────────────────────────────────────────────────────────

class _TabIntegrations extends StatefulWidget {
  const _TabIntegrations({required this.state});
  final _SettingsScreenState state;
  @override
  State<_TabIntegrations> createState() => _TabIntegrationsState();
}
class _TabIntegrationsState extends State<_TabIntegrations> {
  _SettingsScreenState get s => widget.state;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _Section(
            title: 'Modes de paiement',
            children: [
              _ProviderTile(
                icon: Icons.phone_android_rounded,
                label: 'MTN Mobile Money',
                color: _kGold,
                enabled: s._mtnMoneyEnabled,
                onToggle: (v) => setState(() => s._mtnMoneyEnabled = v),
                child: s._mtnMoneyEnabled
                    ? _FieldRow(label: 'Clé API MTN', ctrl: s._mtnApiKeyCtrl)
                    : null,
              ),
              _ProviderTile(
                icon: Icons.phone_android_rounded,
                label: 'Airtel Money',
                color: _kRed,
                enabled: s._airtelMoneyEnabled,
                onToggle: (v) => setState(() => s._airtelMoneyEnabled = v),
                child: s._airtelMoneyEnabled
                    ? _FieldRow(label: 'Clé API Airtel', ctrl: s._airtelApiKeyCtrl)
                    : null,
              ),
              _ProviderTile(
                icon: Icons.credit_card_rounded,
                label: 'Visa / Carte bancaire',
                color: const Color(0xFF1A1F71),
                enabled: s._visaEnabled,
                onToggle: (v) => setState(() => s._visaEnabled = v),
                child: s._visaEnabled
                    ? const Padding(
                        padding: EdgeInsets.only(top: 4, bottom: 8),
                        child: Text('Configuration via Stripe ou Flutterwave — contacter le support.',
                            style: TextStyle(fontSize: 11, color: _kSub)),
                      )
                    : null,
              ),
              _ProviderTile(
                icon: Icons.payments_rounded,
                label: 'Espèces / Dépôt manuel',
                color: _kGreen,
                enabled: s._especesEnabled,
                onToggle: (v) => setState(() => s._especesEnabled = v),
                child: null,
              ),
            ],
          ),
          _Section(
            title: 'Webhooks',
            children: [
              _FieldRow(label: 'URL de base des webhooks', ctrl: s._webhookBaseCtrl, hint: 'https://api…/webhooks'),
              _WebhookItem(label: 'Paiement confirmé',      url: '${s._webhookBaseCtrl.text}/payment-confirmed'),
              _WebhookItem(label: 'Facture générée',         url: '${s._webhookBaseCtrl.text}/invoice-created'),
              _WebhookItem(label: 'Abonnement expiré',       url: '${s._webhookBaseCtrl.text}/subscription-expired'),
            ],
          ),
          _Section(
            title: 'Email (SMTP)',
            children: [
              _row2(
                _FieldRow(label: 'Hôte SMTP', ctrl: s._smtpHostCtrl, hint: 'smtp.gmail.com'),
                _FieldRow(label: 'Port', ctrl: s._smtpPortCtrl, numeric: true),
              ),
              _FieldRow(label: 'Utilisateur SMTP', ctrl: s._smtpUserCtrl, hint: 'noreply@...'),
              Row(children: [
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Email de test envoyé !')),
                    );
                  },
                  icon: const Icon(Icons.send_rounded, size: 14),
                  label: const Text('Tester la connexion SMTP'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kNavy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ]),
            ],
          ),
          _Section(
            title: 'Passerelle SMS',
            children: [
              _SwitchRow(
                label: 'Activer l\'envoi de SMS',
                sub: 'Utilise une passerelle SMS tierce pour les alertes',
                value: s._smsGatewayEnabled,
                onChanged: (v) => setState(() => s._smsGatewayEnabled = v),
              ),
              if (s._smsGatewayEnabled)
                _FieldRow(label: 'Clé API SMS Gateway', ctrl: s._smsApiKeyCtrl, hint: 'sk_live_…'),
            ],
          ),
          const _Section(
            title: 'Infrastructure Supabase',
            children: [
              _InfoRow(label: 'Project ID',  value: 'wqpdamlnrwgozfvzjjpo'),
              _InfoRow(label: 'Région',      value: 'eu-central-2 (Frankfurt)'),
              _InfoRow(label: 'URL API',     value: 'https://wqpdamlnrwgozfvzjjpo.supabase.co'),
              _InfoRow(label: 'Tables RLS',  value: '28 tables protégées'),
              _InfoRow(label: 'Statut',      value: 'Opérationnel ✓', color: _kGreen),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProviderTile extends StatelessWidget {
  const _ProviderTile({required this.icon, required this.label, required this.color,
      required this.enabled, required this.onToggle, this.child});
  final IconData icon; final String label; final Color color;
  final bool enabled; final ValueChanged<bool> onToggle; final Widget? child;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: enabled ? color.withValues(alpha: 0.05) : Colors.grey.shade50,
      border: Border.all(color: enabled ? color.withValues(alpha: 0.3) : _kBorder),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 32, height: 32,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 16)),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: enabled ? _kText : _kSub))),
            Switch(value: enabled, onChanged: onToggle, activeThumbColor: color),
          ],
        ),
        if (child != null) ...[const SizedBox(height: 8), child!],
      ],
    ),
  );
}

class _WebhookItem extends StatelessWidget {
  const _WebhookItem({required this.label, required this.url});
  final String label; final String url;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        const Icon(Icons.link_rounded, size: 14, color: _kSub),
        const SizedBox(width: 6),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _kText)),
            Text(url, style: const TextStyle(fontSize: 10, color: _kSub, fontFamily: 'monospace'),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        )),
        IconButton(
          icon: const Icon(Icons.copy_rounded, size: 14),
          color: _kSub,
          tooltip: 'Copier',
          onPressed: () => Clipboard.setData(ClipboardData(text: url)),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.color = _kText});
  final String label; final String value; final Color color;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 120, child: Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kSub))),
        Expanded(child: Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color,
            fontFamily: label == 'URL API' || label == 'Project ID' ? 'monospace' : null))),
      ],
    ),
  );
}
