part of '../school_groups_screen.dart';

/// Pied de page du formulaire de groupe : « Annuler » et le bouton d'action.
///
/// Il ne connaît du formulaire que trois choses — s'il s'agit d'une édition,
/// si un enregistrement est en cours, et quoi appeler. C'est délibéré : le
/// `build` du modal dépassait trois cents lignes, et rien de ce pied de page
/// n'a besoin de voir les contrôleurs de saisie.
///
/// ⚠️ Pendant l'enregistrement, le bouton n'est pas simplement DÉSACTIVÉ : il
/// est remplacé par un indicateur. Un bouton grisé se re-clique — et sur une
/// liaison congolaise, une seconde pression pendant l'attente créait un
/// deuxième groupe.
class _GroupFormFooter extends StatelessWidget {
  const _GroupFormFooter({
    required this.isEdit,
    required this.saving,
    required this.onSave,
  });

  final bool isEdit, saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
        border: Border(top: BorderSide(color: _kBorder)),
      ),
      child: Row(children: [
        TextButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded, size: 15),
          label: const Text('Annuler'),
          style: TextButton.styleFrom(
            foregroundColor: _kMuted,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        ),
        const Spacer(),
        if (saving)
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: _kNavy.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white)),
              SizedBox(width: 10),
              Text('Enregistrement…',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
            ]),
          )
        else
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: SizedBox(
              width: isEdit ? 230 : 200,
              child: AnimatedButton(
                onPress: onSave,
                text: isEdit ? 'Enregistrer' : 'Créer le groupe',
                isReverse: true,
                selectedBackgroundColor: Colors.white,
                selectedTextColor: _kNavy,
                backgroundColor: _kNavy,
                borderRadius: 8,
                borderColor: _kNavy,
                borderWidth: 2,
                height: 42,
                transitionType: TransitionType.LEFT_TO_RIGHT,
                textStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
      ]),
    );
  }
}
