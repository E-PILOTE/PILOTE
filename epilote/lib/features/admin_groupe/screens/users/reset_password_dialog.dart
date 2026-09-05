part of '../admin_users_screen.dart';

// Réinitialisation du mot de passe.

class ResetPasswordDialog extends ConsumerStatefulWidget {
  const ResetPasswordDialog({super.key, required this.user});
  final AdminUser user;

  @override
  ConsumerState<ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends ConsumerState<ResetPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _pwd     = TextEditingController();
  final _confirm = TextEditingController();
  bool    _obscure = true;
  bool    _saving  = false;
  String? _error;

  @override
  void dispose() {
    _pwd.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });
    try {
      await ref.read(adminUsersServiceProvider).resetPassword(widget.user.id, _pwd.text);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: kGreen,
          content: const Text('Mot de passe réinitialisé'),
        ));
      }
    } catch (e) {
      setState(() { _saving = false; _error = '$e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AdminDialogHeader(
              title: 'Réinitialiser le mot de passe',
              subtitle: widget.user.fullName,
              icon: Icons.key_rounded,
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Form(
                key: _formKey,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextFormField(
                    controller: _pwd,
                    obscureText: _obscure,
                    validator: ref.read(politiqueMotDePasseProvider).refus,
                    decoration: adminInputDecoration('Nouveau mot de passe', icon: Icons.lock_outline)
                        .copyWith(
                      helperText: ref.read(politiqueMotDePasseProvider).exigence,
                      helperMaxLines: 2,
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 20, color: kTextMuted),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _confirm,
                    obscureText: _obscure,
                    validator: (v) => v != _pwd.text ? 'Les mots de passe ne correspondent pas' : null,
                    decoration: adminInputDecoration('Confirmer', icon: Icons.lock_outline),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    AdminErrorBanner(message: _error!),
                  ],
                ]),
              ),
            ),
            AdminDialogFooter(
              saving: _saving,
              submitLabel: 'Réinitialiser',
              submitColor: kAccent,
              submitIcon: Icons.key_rounded,
              onCancel: () => Navigator.of(context).pop(),
              onSubmit: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
