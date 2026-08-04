import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../services/powersync/powersync_service.dart';
import 'admin_ui.dart';

/// Boîte de reconnexion : l'adresse est celle du poste, seul le mot de passe
/// est demandé. On ne propose pas de changer de compte ici — ouvrir une session
/// avec un AUTRE compte ferait changer l'appareil de main et purgerait la base
/// locale, donc les saisies en attente.
Future<void> _reconnecter(BuildContext context, WidgetRef ref) async {
  final identite = ref.read(repriseProposeeProvider);
  await showDialog<void>(
    context: context,
    builder: (_) => _ReconnexionDialog(email: identite?.email ?? ''),
  );
}

class _ReconnexionDialog extends ConsumerStatefulWidget {
  const _ReconnexionDialog({required this.email});
  final String email;
  @override
  ConsumerState<_ReconnexionDialog> createState() => _ReconnexionState();
}

class _ReconnexionState extends ConsumerState<_ReconnexionDialog> {
  // ⚠️ Le contrôleur appartient à la boîte, pas à l'appelant. Le libérer depuis
  // l'extérieur, juste après `showDialog`, le détruisait pendant que le champ
  // s'effaçait encore à l'écran — la fermeture partait en assertion du
  // framework. Ici il vit et meurt avec l'écran qui s'en sert.
  final _mdp = TextEditingController();
  bool _occupe = false;
  String? _erreur;

  @override
  void dispose() {
    _mdp.dispose();
    super.dispose();
  }

  Future<void> _valider() async {
    setState(() { _occupe = true; _erreur = null; });
    await ref
        .read(authNotifierProvider.notifier)
        .signIn(widget.email, _mdp.text);
    final etat = ref.read(authNotifierProvider);
    if (!mounted) return;
    if (etat.hasError) {
      setState(() { _erreur = '${etat.error}'; _occupe = false; });
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        icon: Icon(Icons.cloud_sync_outlined, color: kNavy, size: 28),
        title: const Text('Reconnecter le poste'),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              'Les saisies faites hors ligne partiront dès la reconnexion. '
              'Rien n\'est perdu en attendant.',
              style: TextStyle(fontSize: 13, height: 1.4, color: kTextMuted),
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: widget.email,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Compte de ce poste',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _mdp,
              obscureText: true,
              autofocus: true,
              enabled: !_occupe,
              onSubmitted: (_) => _valider(),
              decoration: const InputDecoration(
                labelText: 'Mot de passe',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            if (_erreur != null) ...[
              const SizedBox(height: 12),
              AdminErrorBanner(message: _erreur!),
            ],
          ]),
        ),
        actions: [
          TextButton(
            onPressed: _occupe ? null : () => Navigator.pop(context),
            child: const Text('Plus tard'),
          ),
          FilledButton(
            onPressed: _occupe ? null : _valider,
            child: Text(_occupe ? 'Connexion…' : 'Se reconnecter'),
          ),
        ],
      );
}

/// Bandeau permanent : le poste travaille sur sa base locale, sans session
/// serveur (cf. `session_keeper.dart` et l'écran « Reprise du poste »).
///
/// Il ne s'acquitte pas et ne se referme pas : tant que la session n'est pas
/// rétablie, rien ne remonte au ministère. Ce n'est pas une alerte — le travail
/// est conservé — mais ce n'est pas non plus un état normal, et une école qui
/// resterait des mois dans cet état sans le savoir serait la vraie panne.
///
/// Il dit le NOMBRE d'écritures en attente : « rien ne remonte » est abstrait,
/// « 143 saisies attendent » se comprend tout de suite.
class RepriseBanner extends ConsumerWidget {
  const RepriseBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(modeHorsLigneProvider)) return const SizedBox.shrink();

    return FutureBuilder<PendingLocalWork>(
      future: pendingLocalWork(),
      builder: (context, snap) {
        final n = snap.data?.total ?? 0;
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: kAccent.withValues(alpha: 0.12),
            border: Border(bottom: BorderSide(color: kAccent.withValues(alpha: 0.35))),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
          child: Row(children: [
            Icon(Icons.cloud_off_rounded, size: 16, color: kAccent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                n == 0
                    ? 'Ce poste travaille hors ligne. Reconnectez-le pour que '
                        'les saisies remontent au serveur.'
                    : 'Ce poste travaille hors ligne : $n saisie'
                        '${n > 1 ? 's' : ''} attend'
                        '${n > 1 ? 'ent' : ''} d\'être envoyée'
                        '${n > 1 ? 's' : ''} au serveur.',
                style: TextStyle(
                    fontSize: 12, color: kAccent, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 10),
            TextButton(
              // Une boîte, pas une navigation : l'agent est peut-être au milieu
              // d'une saisie. Reconnecter le poste ne doit rien lui faire
              // perdre de ce qu'il a sous les yeux.
              onPressed: () => _reconnecter(context, ref),
              style: TextButton.styleFrom(
                  foregroundColor: kAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 30)),
              child: const Text('Reconnecter',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ]),
        );
      },
    );
  }
}
