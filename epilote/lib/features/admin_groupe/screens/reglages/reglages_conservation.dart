part of '../admin_settings_screen.dart';

// Conservation des données : ce que la plateforme tient vraiment.

class _ConservationCard extends StatelessWidget {
  const _ConservationCard();

  @override
  Widget build(BuildContext context) => const AdminCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AdminSectionTitle('Conservation des données',
              icon: Icons.inventory_2_outlined,
              subtitle: 'Ce que la plateforme garantit'),
          SizedBox(height: 10),
          _ReglePermanente(
            icon: Icons.workspace_premium_outlined,
            titre: 'Bulletins — 10 ans',
            texte: 'Aucun bulletin n\'est supprimé. Clôturer une année '
                'scolaire scelle définitivement les siens.',
          ),
          _ReglePermanente(
            icon: Icons.receipt_long_outlined,
            titre: 'Données financières — 5 ans',
            texte: 'Encaissements et dépenses se corrigent tant que l\'année '
                'est ouverte ; sa clôture les scelle.',
          ),
          _ReglePermanente(
            icon: Icons.history_edu_outlined,
            titre: 'Journal d\'audit — conservé',
            texte: 'Il n\'est effaçable depuis aucun écran, y compris '
                'celui-ci : un journal que l\'audité peut vider n\'est '
                'pas un journal.',
          ),
          _ReglePermanente(
            icon: Icons.delete_forever_outlined,
            titre: 'Aucune purge automatique',
            texte: 'Rien n\'efface de dossier au bout d\'un délai. '
                'Effacer les données d\'un enfant est une décision '
                'juridique, pas un réglage — elle se demande au support.',
          ),
        ]),
      );
}

class _ReglePermanente extends StatelessWidget {
  const _ReglePermanente(
      {required this.icon, required this.titre, required this.texte});
  final IconData icon;
  final String titre, texte;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: kNavy),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titre,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: kTextPrimary)),
                  const SizedBox(height: 3),
                  Text(texte,
                      style: TextStyle(
                          fontSize: 12, color: kTextMuted, height: 1.4)),
                ]),
          ),
        ]),
      );
}
