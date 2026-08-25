part of 'inscriptions_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CE QUI RESTE EN PROPRE AU FORMULAIRE DE MODIFICATION DU GUICHET.
//
//  La carte tuteur, son brouillon et le sélecteur de photo ont quitté ce
//  fichier pour `widgets/tuteur_edit_card.dart` : ils y étaient écrits une
//  seconde fois, à la ligne près, dans l'éditeur du registre — lequel n'avait
//  pas reçu la correction du contact principal faite ici. Une seule fiche,
//  désormais, pour les deux écrans.
// ════════════════════════════════════════════════════════════════════════════

// ─── Bouton contour (Rejeter…) ───────────────────────────────────────────────
class _OutlineBtn extends StatelessWidget {
  const _OutlineBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.5)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 7),
              Text(label,
                  style: TextStyle(
                      color: color, fontSize: 13, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      );
}

/// TROISIÈME copie de la table des situations familiales, après celle de
/// l'assistant et celle du formulaire de modification. C'est cette dispersion
/// qui avait laissé le récapitulatif de l'assistant SANS aucune traduction, et
/// afficher « monoparentale_pere » juste avant d'enregistrer.
///
/// Elle vit maintenant dans `models/eleve_libelles.dart`, avec ses tests.
String _situationLabel(String code) => situationFamilialeLabel(code);
