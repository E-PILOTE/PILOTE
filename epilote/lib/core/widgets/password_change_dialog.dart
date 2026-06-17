import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_ui.dart';

/// Dialog partagé de changement de mot de passe (action EN LIGNE via Supabase
/// Auth). Réutilisé par « Mon profil » et « Paramètres » du personnel scolaire.
/// Hors-ligne : l'opération échoue proprement avec un message explicite.
class PasswordChangeDialog extends ConsumerStatefulWidget {
  const PasswordChangeDialog({super.key});

  @override
  ConsumerState<PasswordChangeDialog> createState() =>
      _PasswordChangeDialogState();
}

class _PasswordChangeDialogState extends ConsumerState<PasswordChangeDialog> {
  final _pwd = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  bool _obscurePwd = true;
  bool _obscureConfirm = true;
  String? _error;

  static const _offlineMessage =
      'Connexion internet requise pour changer le mot de passe';

  @override
  void dispose() {
    _pwd.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_pwd.text.length < 8) {
      setState(() => _error = 'Au moins 8 caractères requis');
      return;
    }
    if (_pwd.text != _confirm.text) {
      setState(() => _error = 'Les mots de passe ne correspondent pas');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth
          .updateUser(UserAttributes(password: _pwd.text));
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            backgroundColor: kGreen, content: Text('Mot de passe modifié.')));
      }
    } on AuthRetryableFetchException {
      _onOffline(); // serveur injoignable → hors ligne
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      _onOffline(); // erreur réseau (SocketException, ClientException…)
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _onOffline() {
    if (!mounted) return;
    setState(() => _error = '$_offlineMessage.');
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        backgroundColor: kRed, content: Text(_offlineMessage)));
  }

  InputDecoration _pwdDecoration(String label, bool obscure, VoidCallback onEye) =>
      adminInputDecoration(label, icon: Icons.lock_outline_rounded).copyWith(
        suffixIcon: IconButton(
          icon: Icon(
              obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 18,
              color: kTextMuted),
          onPressed: onEye,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AdminFormDialog(
      icon: Icons.lock_reset_rounded,
      title: 'Changer le mot de passe',
      subtitle: 'Action en ligne — connexion internet requise',
      width: 440,
      saving: _saving,
      submitLabel: 'Modifier',
      submitIcon: Icons.check_rounded,
      onSubmit: _submit,
      body: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          controller: _pwd,
          obscureText: _obscurePwd,
          autofocus: true,
          decoration: _pwdDecoration('Nouveau mot de passe', _obscurePwd,
              () => setState(() => _obscurePwd = !_obscurePwd)),
        ),
        const SizedBox(height: 6),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('8 caractères minimum',
              style: TextStyle(fontSize: 11.5, color: kTextMuted)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _confirm,
          obscureText: _obscureConfirm,
          onSubmitted: (_) => _submit(),
          decoration: _pwdDecoration(
              'Confirmer le mot de passe',
              _obscureConfirm,
              () => setState(() => _obscureConfirm = !_obscureConfirm)),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          AdminErrorBanner(message: _error!),
        ],
      ]),
    );
  }
}
