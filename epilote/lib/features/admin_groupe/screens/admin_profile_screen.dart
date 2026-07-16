import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_shell.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../providers/admin_profile_provider.dart';
import '../providers/admin_settings_provider.dart';
import '../providers/admin_users_provider.dart' show roleLabel;
import '../../../core/widgets/admin_ui.dart';

class AdminProfileScreen extends ConsumerWidget {
  const AdminProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AppShell(
      title: 'Mon profil',
      child: _Body(),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body();

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _phone = TextEditingController();
  bool _init = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_first.text.trim().isEmpty || _last.text.trim().isEmpty) {
      setState(() => _error = 'Le prénom et le nom sont obligatoires');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await ref.read(adminSelfServiceProvider).updateOwnProfile(
            firstName: _first.text.trim(),
            lastName: _last.text.trim(),
            phone: _phone.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: kGreen, content: const Text('Profil mis à jour.')));
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authNotifierProvider).valueOrNull;
    final email = ref.watch(currentUserProvider)?.email ?? '—';
    final groupName = ref.watch(adminGroupProfileProvider).valueOrNull?.name;

    if (profile == null) {
      return Center(child: CircularProgressIndicator(color: kNavy));
    }
    if (!_init) {
      _first.text = profile.firstName;
      _last.text = profile.lastName;
      _phone.text = profile.phone ?? '';
      _init = true;
    }
    final initials = _initials(profile.fullName);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(children: [
              // En-tête identité
              AdminCard(
                child: Row(children: [
                  CircleAvatar(
                    radius: 34, backgroundColor: kGreen,
                    child: Text(initials, style: const TextStyle(
                        color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(profile.fullName.isEmpty ? '—' : profile.fullName,
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kTextPrimary)),
                      const SizedBox(height: 4),
                      Row(children: [
                        AdminBadge(roleLabel(profile.role), color: kGreen, icon: Icons.shield_rounded),
                        if (groupName != null) ...[
                          const SizedBox(width: 8),
                          Flexible(child: AdminBadge(groupName, color: kNavy, icon: Icons.business_rounded)),
                        ],
                      ]),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 20),

              // Informations personnelles
              AdminCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const AdminSectionTitle('Informations personnelles', icon: Icons.person_rounded),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: TextField(controller: _first,
                        decoration: adminInputDecoration('Prénom', icon: Icons.badge_outlined))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: _last,
                        decoration: adminInputDecoration('Nom'))),
                  ]),
                  const SizedBox(height: 12),
                  TextField(controller: _phone, keyboardType: TextInputType.phone,
                      decoration: adminInputDecoration('Téléphone', icon: Icons.phone_outlined)),
                  const SizedBox(height: 12),
                  // Email — lecture seule (géré dans auth.users)
                  TextField(
                    enabled: false,
                    decoration: adminInputDecoration('Email (non modifiable)', icon: Icons.email_outlined)
                        .copyWith(hintText: email),
                    controller: TextEditingController(text: email),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    AdminErrorBanner(message: _error!),
                  ],
                  const SizedBox(height: 16),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    OutlinedButton.icon(
                      onPressed: () => showDialog(context: context, builder: (_) => const _PasswordDialog()),
                      icon: const Icon(Icons.lock_reset_rounded, size: 17),
                      label: const Text('Changer le mot de passe'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kNavy, side: BorderSide(color: kBorder),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    AdminActionButton(
                      label: 'Enregistrer',
                      icon: _saving ? Icons.hourglass_empty_rounded : Icons.check_rounded,
                      color: kNavy,
                      onPressed: _saving ? () {} : _save,
                    ),
                  ]),
                ]),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  String _initials(String name) {
    final p = name.trim().split(RegExp(r'\s+'));
    if (p.length >= 2 && p[0].isNotEmpty && p[1].isNotEmpty) {
      return '${p[0][0]}${p[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

// ─── Dialog changement de mot de passe ───────────────────────────────────────
class _PasswordDialog extends ConsumerStatefulWidget {
  const _PasswordDialog();

  @override
  ConsumerState<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends ConsumerState<_PasswordDialog> {
  final _pwd = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _pwd.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_pwd.text.length < 6) {
      setState(() => _error = 'Au moins 6 caractères');
      return;
    }
    if (_pwd.text != _confirm.text) {
      setState(() => _error = 'Les mots de passe ne correspondent pas');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await ref.read(adminSelfServiceProvider).changePassword(_pwd.text);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: kGreen, content: const Text('Mot de passe modifié.')));
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const AdminDialogHeader(
            title: 'Changer le mot de passe',
            icon: Icons.lock_reset_rounded,
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: _pwd, obscureText: true,
                  decoration: adminInputDecoration('Nouveau mot de passe', icon: Icons.lock_outline_rounded)),
              const SizedBox(height: 12),
              TextField(controller: _confirm, obscureText: true,
                  decoration: adminInputDecoration('Confirmer', icon: Icons.lock_outline_rounded)),
              if (_error != null) ...[
                const SizedBox(height: 12),
                AdminErrorBanner(message: _error!),
              ],
            ]),
          ),
          AdminDialogFooter(
            saving: _saving,
            submitLabel: 'Modifier',
            submitColor: kAccent,
            submitIcon: Icons.check_rounded,
            onCancel: () => Navigator.of(context).pop(),
            onSubmit: _submit,
          ),
        ]),
      ),
    );
  }
}
