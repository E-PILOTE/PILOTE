import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_ui.dart';
import '../utils/politique_mot_de_passe.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CHANGER SON MOT DE PASSE — en prouvant d'abord qu'on est bien soi
//
//  ── CE QUI MANQUAIT (2026-09-04) ──────────────────────────────────────────
//  Ce dialogue demandait un nouveau mot de passe, deux fois, et l'appliquait.
//  Rien ne vérifiait l'ANCIEN. L'écran « Mon profil » de l'espace super_admin
//  allait plus loin : il AFFICHAIT un champ « Mot de passe actuel » que le
//  code ne lisait jamais — une garde décorative, la pire sorte.
//
//  Conséquence concrète, dans une école : un poste laissé déverrouillé une
//  minute suffisait pour changer le mot de passe du compte et en verrouiller
//  le propriétaire dehors. Supabase n'exige pas l'ancien mot de passe pour
//  `updateUser` : c'est à l'application de le demander.
//
//  ── COMMENT LA VÉRIFICATION EST FAITE ─────────────────────────────────────
//  On rejoue une connexion avec l'adresse de la session et le mot de passe
//  saisi. S'il est faux, `signInWithPassword` lève et la session en cours reste
//  intacte — rien n'est modifié. S'il est bon, la session est simplement
//  rafraîchie pour la MÊME personne, et le changement suit.
// ════════════════════════════════════════════════════════════════════════════

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
  final _actuel = TextEditingController();
  final _pwd = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  bool _obscureActuel = true;
  bool _obscurePwd = true;
  bool _obscureConfirm = true;
  String? _error;

  static const _offlineMessage =
      'Connexion internet requise pour changer le mot de passe';

  @override
  void dispose() {
    _actuel.dispose();
    _pwd.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_actuel.text.isEmpty) {
      setState(() => _error = 'Saisissez votre mot de passe actuel');
      return;
    }
    // La politique du groupe quand elle existe, le défaut sinon — la même
    // règle que les deux autres portes qui posent un mot de passe.
    final refus = ref.read(politiqueMotDePasseProvider).refus(_pwd.text);
    if (refus != null) {
      setState(() => _error = refus);
      return;
    }
    if (_pwd.text != _confirm.text) {
      setState(() => _error = 'Les mots de passe ne correspondent pas');
      return;
    }
    if (_pwd.text == _actuel.text) {
      setState(() => _error = 'Le nouveau mot de passe doit être différent');
      return;
    }
    final client = Supabase.instance.client;
    final email = client.auth.currentUser?.email;
    if (email == null || email.isEmpty) {
      setState(() => _error =
          'Session sans adresse e-mail : le mot de passe ne peut pas être '
          'changé depuis cet appareil.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // 1. Prouver l'identité. En cas d'échec, RIEN n'est modifié et la session
      //    en cours reste celle qu'elle était.
      await client.auth
          .signInWithPassword(email: email, password: _actuel.text);
      // 2. Puis seulement, appliquer.
      await client.auth.updateUser(UserAttributes(password: _pwd.text));
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: kGreen,
            content: const Text('Mot de passe modifié.')));
      }
    } on AuthRetryableFetchException {
      _onOffline(); // serveur injoignable → hors ligne
    } on AuthApiException catch (e) {
      // Identifiants refusés : le message brut d'Auth est en anglais et parle
      // de « credentials », ce qui laisse croire à un problème de compte.
      final mauvaisMdp = e.statusCode == '400' ||
          e.message.toLowerCase().contains('credentials');
      if (mounted) {
        setState(() => _error = mauvaisMdp
            ? 'Mot de passe actuel incorrect.'
            : e.message);
      }
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: kRed, content: const Text(_offlineMessage)));
  }

  InputDecoration _pwdDecoration(
          String label, bool obscure, VoidCallback onEye) =>
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
          controller: _actuel,
          obscureText: _obscureActuel,
          autofocus: true,
          decoration: _pwdDecoration('Mot de passe actuel', _obscureActuel,
              () => setState(() => _obscureActuel = !_obscureActuel)),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
              'Demandé pour vérifier que c\'est bien vous : sans lui, un poste '
              'laissé ouvert suffirait à vous verrouiller dehors.',
              style: TextStyle(fontSize: 11.5, color: kTextMuted, height: 1.35)),
        ),
        Divider(height: 22, color: kBorder),
        TextField(
          controller: _pwd,
          obscureText: _obscurePwd,
          decoration: _pwdDecoration('Nouveau mot de passe', _obscurePwd,
              () => setState(() => _obscurePwd = !_obscurePwd)),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(ref.watch(politiqueMotDePasseProvider).exigence,
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
