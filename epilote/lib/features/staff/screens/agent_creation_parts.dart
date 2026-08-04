part of 'agent_creation_dialog.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Les blocs de l'enregistrement d'un agent : remise des identifiants, ligne
//  copiable, et l'écran d'empêchement qui dit AVANT la saisie ce qui bloquera.
// ════════════════════════════════════════════════════════════════════════════

/// La remise des identifiants — le seul moment où le mot de passe est lisible.
class _Identifiants extends StatelessWidget {
  const _Identifiants({required this.email, required this.mdp});
  final String email, mdp;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Remettez ces identifiants à l\'agent. Le mot de passe ne sera '
            'plus affiché : il n\'est conservé nulle part en clair.',
            style: TextStyle(fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 14),
          _Ligne(label: 'Adresse', valeur: email),
          const SizedBox(height: 8),
          _Ligne(label: 'Mot de passe', valeur: mdp),
          const SizedBox(height: 14),
          Row(children: [
            Icon(Icons.info_outline, size: 16, color: kTextMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Invitez-le à le changer à sa première connexion.',
                style: TextStyle(fontSize: 11.5, color: kTextMuted),
              ),
            ),
          ]),
        ],
      );
}

class _Ligne extends StatelessWidget {
  const _Ligne({required this.label, required this.valeur});
  final String label, valeur;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: kNavy.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kBorder),
        ),
        child: Row(children: [
          SizedBox(
            width: 108,
            child: Text(label,
                style: TextStyle(fontSize: 12, color: kTextMuted)),
          ),
          Expanded(
            child: SelectableText(valeur,
                style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace')),
          ),
          IconButton(
            tooltip: 'Copier',
            icon: const Icon(Icons.copy_rounded, size: 17),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: valeur));
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$label copié')));
            },
          ),
        ]),
      );
}

/// Ce qui empêche, dit avant la saisie plutôt qu'après.
class _Empechement extends StatelessWidget {
  const _Empechement({required this.message, this.icone});
  final String message;
  final IconData? icone;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icone ?? Icons.info_outline, color: kAccent, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Text(message,
                style: const TextStyle(fontSize: 13, height: 1.5)),
          ),
        ]),
      );
}
