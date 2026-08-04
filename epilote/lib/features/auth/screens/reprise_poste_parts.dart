part of 'reprise_poste_screen.dart';

// ─── En-tête : d'abord son propre nom ───────────────────────────────────────
// Un poste qui ne se reconnaît plus est angoissant. Avant toute explication, on
// affiche le nom de l'école : c'est ce qui transforme « l'application est
// cassée » en « il faut simplement se reconnecter ».

class _EnTete extends StatelessWidget {
  const _EnTete({required this.ecole, required this.jours});
  final String? ecole;
  final int jours;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      congoFlag(barWidth: 18, height: 6, radius: 3),
      const SizedBox(height: 18),
      Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          color: kAuthAccent.withValues(alpha: 0.16),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.cloud_off_rounded, color: Colors.white, size: 30),
      ),
      const SizedBox(height: 16),
      Text(
        ecole == null ? 'Reprise du poste' : 'Poste de $ecole',
        textAlign: TextAlign.center,
        style: const TextStyle(
            fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
      ),
      const SizedBox(height: 10),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Text(
          'La session de ce poste avec le serveur a expiré. Vos données sont '
          'intactes sur cet ordinateur : rien n\'est perdu.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 14.5, height: 1.45, color: Colors.white.withValues(alpha: 0.82)),
        ),
      ),
      if (jours >= 1) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Dernier échange avec le serveur il y a $jours jour'
            '${jours > 1 ? 's' : ''}',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.75)),
          ),
        ),
      ],
    ]);
  }
}

// ─── Coque commune aux deux portes ──────────────────────────────────────────

class _Carte extends StatelessWidget {
  const _Carte({
    required this.icone,
    required this.titre,
    required this.sous,
    required this.enfants,
    this.accent = kAuthAccent,
  });

  final IconData icone;
  final String titre, sous;
  final List<Widget> enfants;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icone, size: 20, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(titre,
                  style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: kAuthTextPrimary)),
            ),
          ]),
          const SizedBox(height: 10),
          Text(sous,
              style: const TextStyle(
                  fontSize: 13, height: 1.45, color: kAuthSlate)),
          const SizedBox(height: 16),
          ...enfants,
        ]),
      );
}

Widget _erreurLigne(String message) => Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.error_outline_rounded, size: 17, color: kAuthDanger),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message,
              style: const TextStyle(
                  fontSize: 12.5, height: 1.4, color: kAuthDanger)),
        ),
      ]),
    );

// ─── Porte 1 : reprendre le travail hors ligne ──────────────────────────────

class _PorteReprise extends StatelessWidget {
  const _PorteReprise({
    required this.agents,
    required this.agentId,
    required this.pin,
    required this.erreur,
    required this.occupe,
    required this.onAgent,
    required this.onValider,
  });

  final List<_AgentDuPoste> agents;
  final String? agentId;
  final TextEditingController pin;
  final String? erreur;
  final bool occupe;
  final ValueChanged<String?> onAgent;
  final VoidCallback onValider;

  @override
  Widget build(BuildContext context) {
    final avecPin = exigePinPourReprise(agents.length);
    return _Carte(
      icone: Icons.play_circle_outline_rounded,
      titre: 'Reprendre le travail',
      accent: kAuthCongoGreen,
      sous: avecPin
          ? 'Ouvrez l\'application avec votre code habituel. Tout ce que vous '
              'saisirez sera conservé et envoyé au serveur dès la reconnexion.'
          : 'Aucun code n\'a été enregistré sur ce poste. Vous pouvez rouvrir '
              'le travail directement ; il sera envoyé au serveur dès la '
              'reconnexion.',
      enfants: [
        if (avecPin) ...[
          DropdownButtonFormField<String>(
            initialValue: agentId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Votre nom',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              for (final a in agents)
                DropdownMenuItem(
                  value: a.id,
                  child: Text(a.nom, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: occupe ? null : onAgent,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: pin,
            obscureText: true,
            enabled: !occupe,
            keyboardType: TextInputType.number,
            onSubmitted: (_) => onValider(),
            decoration: const InputDecoration(
              labelText: 'Votre code',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 14),
        ],
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: occupe ? null : onValider,
            style: FilledButton.styleFrom(
                backgroundColor: kAuthCongoGreen,
                padding: const EdgeInsets.symmetric(vertical: 14)),
            icon: const Icon(Icons.login_rounded, size: 18),
            label: const Text('Reprendre le travail'),
          ),
        ),
        if (erreur != null) _erreurLigne(erreur!),
      ],
    );
  }
}

// ─── Porte 2 : reconnecter le poste au serveur ──────────────────────────────

class _PorteReconnexion extends StatelessWidget {
  const _PorteReconnexion({
    required this.email,
    required this.mdp,
    required this.erreur,
    required this.occupe,
    required this.onValider,
  });

  final String email;
  final TextEditingController mdp;
  final String? erreur;
  final bool occupe;
  final VoidCallback onValider;

  @override
  Widget build(BuildContext context) => _Carte(
        icone: Icons.cloud_sync_outlined,
        titre: 'Reconnecter le poste',
        sous: 'Rétablit la synchronisation avec le serveur. Demande le mot de '
            'passe du compte de l\'établissement.',
        enfants: [
          // L'adresse n'est pas modifiable, et c'est délibéré : ouvrir une
          // session avec un AUTRE compte ferait changer l'appareil de main et
          // purgerait la base locale (règle multi-tenant). Ce n'est pas un
          // geste à proposer sur un écran de dépannage.
          TextFormField(
            initialValue: email,
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'Compte de ce poste',
              border: OutlineInputBorder(),
              isDense: true,
              suffixIcon: Icon(Icons.lock_outline_rounded, size: 17),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: mdp,
            obscureText: true,
            enabled: !occupe,
            onSubmitted: (_) => onValider(),
            decoration: const InputDecoration(
              labelText: 'Mot de passe',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: occupe ? null : onValider,
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              icon: const Icon(Icons.sync_rounded, size: 18),
              label: const Text('Se reconnecter'),
            ),
          ),
          if (erreur != null) _erreurLigne(erreur!),
        ],
      );
}

// ─── Le cas où aucune des deux portes ne s'ouvre ────────────────────────────
// Il fallait l'écrire : un écran de dépannage qui ne dit pas quoi faire quand
// il échoue renvoie l'établissement au silence.

class _AucuneDesDeux extends StatelessWidget {
  const _AucuneDesDeux();

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 660),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.support_agent_rounded,
                size: 20, color: Colors.white.withValues(alpha: 0.7)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Ni l\'un ni l\'autre ne fonctionne ? Signalez-le à '
                'l\'administration de votre réseau en indiquant le nom de '
                'votre établissement. Ne réinstallez pas l\'application et ne '
                'supprimez rien : le travail de ce poste est encore dessus, et '
                'une réinstallation le perdrait.',
                style: TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: Colors.white.withValues(alpha: 0.78)),
              ),
            ),
          ]),
        ),
      );
}
