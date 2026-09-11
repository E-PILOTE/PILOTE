part of 'tutelle_reseau_screen.dart';

// ─── En-tête : QUI on supervise, et ce qu'on peut en faire ───────────────────

/// ⚠️ Il nomme le périmètre AVANT les chiffres, et il nomme aussi CE QUI EN EST
/// EXCLU.
///
/// Un ministère exploite ses propres établissements et supervise ceux des
/// autres. Cette page ne montre que les SECONDS. Sans la phrase qui le dit, un
/// administrateur du METP qui compte douze écoles sous « Mes écoles » et zéro
/// ici conclut à une panne, pas à un périmètre.
class _EnTeteTutelle extends StatelessWidget {
  const _EnTeteTutelle({
    required this.tutelle,
    required this.nbGroupes,
    required this.nbEcoles,
    required this.nbEcolesPropres,
    required this.onActualiser,
    required this.onExporter,
    required this.exportEnCours,
  });

  final String? tutelle;
  final int nbGroupes, nbEcoles, nbEcolesPropres;
  final VoidCallback onActualiser, onExporter;
  final bool exportEnCours;

  @override
  Widget build(BuildContext context) {
    final couleur = couleurTutelle(tutelle);
    final sigle = sigleTutelle(tutelle);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: couleur.withValues(alpha: 0.25)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: couleur.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(Icons.hub_rounded, color: couleur, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            sigle == null
                ? 'Les groupes scolaires que vous supervisez'
                : 'Les groupes scolaires sous tutelle $sigle',
            style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: kTextPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            '$nbGroupes groupe${nbGroupes > 1 ? 's' : ''} scolaire'
            '${nbGroupes > 1 ? 's' : ''} · $nbEcoles établissement'
            '${nbEcoles > 1 ? 's' : ''}. Ce sont des personnes morales que '
            'votre ministère agrée et supervise — il ne les administre pas.',
            style: TextStyle(fontSize: 11.5, color: kTextMuted, height: 1.45),
          ),
          const SizedBox(height: 6),
          // ⚠️ LA PHRASE QUI EMPÊCHE DE CONFONDRE LES DEUX PÉRIMÈTRES.
          Row(children: [
            Icon(Icons.call_split_rounded, size: 14, color: couleur),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                nbEcolesPropres == 0
                    ? 'Vos propres établissements ne figurent pas ici : ils se '
                        'gèrent sous « Mes écoles ».'
                    : 'Vos $nbEcolesPropres établissement'
                        '${nbEcolesPropres > 1 ? 's' : ''} ne figure'
                        '${nbEcolesPropres > 1 ? 'nt' : ''} PAS dans ces '
                        'chiffres : vous les exploitez, vous ne les supervisez '
                        'pas. Ils se gèrent sous « Mes écoles ».',
                style: TextStyle(
                    fontSize: 11,
                    color: couleur,
                    fontWeight: FontWeight.w600,
                    height: 1.4),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          Text(
            'Effectifs agrégés. Aucun nom d\'élève, aucune note, aucun '
            'paiement — la supervision n\'est pas la gestion.',
            style: TextStyle(fontSize: 10.5, color: kTextMuted, height: 1.4),
          ),
        ])),
        const SizedBox(width: 14),
        Column(mainAxisSize: MainAxisSize.min, children: [
          AdminPrimaryButton(
            label: 'État du réseau (PDF)',
            icon: Icons.picture_as_pdf_outlined,
            color: couleur,
            saving: exportEnCours,
            onTap: onExporter,
          ),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: onActualiser,
            icon: const Icon(Icons.refresh_rounded, size: 15),
            label: const Text('Actualiser'),
            style: TextButton.styleFrom(foregroundColor: kTextMuted),
          ),
        ]),
      ]),
    );
  }
}

// ─── Le cas d'un groupe qui n'a pas de tutelle à exercer ────────────────────

class _PasDeTutelle extends StatelessWidget {
  const _PasDeTutelle();

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.hub_outlined, size: 44, color: kTextMuted),
            const SizedBox(height: 14),
            Text('Réservé aux ministères de tutelle',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: kTextPrimary)),
            const SizedBox(height: 8),
            Text(
              'Cette page présente les groupes scolaires qu\'un ministère '
              'supervise. Votre groupe gère ses propres établissements : ils '
              'se trouvent sous « Mes écoles ».',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: kTextMuted, height: 1.5),
            ),
          ]),
        ),
      );
}

/// ⚠️ UN VIDE VRAI VAUT MIEUX QU'UN CHIFFRE FAUX.
///
/// C'est le cas du METP au 2026-09-02 : aucun groupe tiers ne lui est rattaché.
/// La page affichait alors « 12 écoles dans 1 groupe » — ses propres écoles,
/// sous un titre qui promettait « y compris celles que vous ne gérez pas ».
/// Elle dit désormais qu'il n'y a rien à superviser, et pourquoi.
class _AucunGroupeSupervise extends StatelessWidget {
  const _AucunGroupeSupervise({
    required this.tutelle,
    required this.nbEcolesPropres,
  });

  final String? tutelle;
  final int nbEcolesPropres;

  @override
  Widget build(BuildContext context) {
    final sigle = sigleTutelle(tutelle);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.hub_outlined, size: 46, color: couleurTutelle(tutelle)),
          const SizedBox(height: 16),
          Text(
            sigle == null
                ? 'Aucun groupe scolaire sous votre tutelle'
                : 'Aucun groupe scolaire sous tutelle $sigle',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: kTextPrimary),
          ),
          const SizedBox(height: 10),
          Text(
            'Cette page recense les groupes scolaires — publics comme privés — '
            'que votre ministère agrée et supervise sans les administrer. '
            'Aucun ne lui est rattaché pour le moment.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: kTextMuted, height: 1.55),
          ),
          if (nbEcolesPropres > 0) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kBorder),
              ),
              child: Row(children: [
                Icon(Icons.school_rounded, size: 16, color: kTextMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Vos $nbEcolesPropres établissement'
                    '${nbEcolesPropres > 1 ? 's' : ''} ne sont pas un vide : '
                    'vous les exploitez, ils se gèrent sous « Mes écoles ». '
                    'Cette page ne compte que ce que vous supervisez.',
                    style: TextStyle(
                        fontSize: 11.5, color: kTextPrimary, height: 1.45),
                  ),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Un groupe apparaît ici dès qu\'il est créé avec votre ministère '
            'pour tutelle — la tutelle se saisit sur le groupe, jamais sur '
            'l\'école.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: kTextMuted, height: 1.5),
          ),
          const SizedBox(height: 14),
          // ⚠️ Pas de bouton ici, et c'est cohérent : il n'y a personne à qui
          // écrire. Pour joindre ses PROPRES établissements, un ministère passe
          // par « Annonces & Agenda » ou par la messagerie, comme tout groupe.
          Text(
            'Pour écrire à vos propres établissements, utilisez « Annonces & '
            'Agenda » ou la messagerie.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10.5, color: kTextMuted, height: 1.45),
          ),
        ]),
      ),
    );
  }
}

/// ⚠️ Une erreur s'affiche COMME une erreur, jamais comme un réseau vide.
class _ErreurReseau extends StatelessWidget {
  const _ErreurReseau({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline_rounded, color: kRed, size: 40),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: kTextMuted, height: 1.5)),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
          ),
        ]),
      );
}

/// Rappel imprimé sous la liste quand une sélection est active.
///
/// ⚠️ Le PDF porte cette même phrase. Ici elle sert d'avertissement AVANT
/// l'export : on ne découvre pas au moment d'ouvrir le document que ses totaux
/// ne couvrent qu'un département.
class _RappelSelection extends StatelessWidget {
  const _RappelSelection({required this.texte, required this.onEffacer});
  final String texte;
  final VoidCallback onEffacer;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        decoration: BoxDecoration(
          color: kAccent.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kAccent.withValues(alpha: 0.22)),
        ),
        child: Row(children: [
          Icon(Icons.filter_alt_rounded, size: 15, color: kAccent),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              '$texte — les totaux ci-dessus et le document exporté portent '
              'sur cette sélection, pas sur le réseau entier.',
              style:
                  TextStyle(fontSize: 11.5, color: kTextPrimary, height: 1.4),
            ),
          ),
          TextButton(
            onPressed: onEffacer,
            style: TextButton.styleFrom(foregroundColor: kAccent),
            child: const Text('Tout afficher'),
          ),
        ]),
      );
}
