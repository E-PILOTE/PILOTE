part of '../school_groups_screen.dart';

// ─── Sélecteur de ministère de tutelle ────────────────────────────────────────

/// Deux choix exclusifs, pas une liste déroulante.
///
/// ⚠️ CE CHAMP N'EST PAS UN CHAMP COMME LES AUTRES. Il décide de quel ministère
/// relève tout le groupe — donc quels types d'établissement, quelles filières et
/// quels diplômes seront proposés à ses écoles, et à quelle administration leurs
/// états sont remontés. Un groupe n'est jamais mixte : chaque ministère agrée
/// SES propres établissements privés, par sa propre commission (MEPSA : 1 192
/// dossiers d'enseignement général ; METP : 108 puis 151 pour le technique).
///
/// Il est donc présenté comme un choix qu'on lit, avec ce que chaque tutelle
/// recouvre écrit sous son nom — et non comme un menu qu'on déroule sans voir
/// ce qu'on choisit.
class _TutelleSelector extends StatelessWidget {
  const _TutelleSelector({
    required this.value,
    required this.onChanged,
    required this.ecolesConcernees,
    this.valeurInitiale,
  });

  final String? value;
  final ValueChanged<String?> onChanged;

  /// Nombre d'écoles du groupe — sert à dire ce qu'un changement entraîne.
  final int ecolesConcernees;

  /// Tutelle telle qu'elle était à l'ouverture. Sert à distinguer « on
  /// renseigne un groupe qui n'en avait pas » (anodin) de « on change celle
  /// d'un groupe qui en avait une » (à signaler).
  final String? valeurInitiale;

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      initialValue: value,
      // Sans ça, le message rouge resterait affiché après que l'utilisateur a
      // choisi — jusqu'au prochain appui sur « Créer ». Il lirait « choisissez
      // le ministère » alors qu'il vient de le faire.
      autovalidateMode: AutovalidateMode.onUserInteraction,
      // La validation vit ICI et pas dans `_save` : un `Form.validate()` ne
      // voit que les FormField. Un contrôle posé ailleurs laisserait le
      // bouton « Créer » enregistrer un groupe sans ministère.
      validator: (_) => tutelleConnue(value)
          ? null
          : 'Choisissez le ministère de tutelle du groupe',
      builder: (state) {
        final enErreur = state.hasError;
        final changement = valeurInitiale != null &&
            value != null &&
            value != valeurInitiale;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            for (final t in kTutelles) ...[
              Expanded(child: _TutelleCard(
                code: t,
                selected: value == t,
                enErreur: enErreur,
                onTap: () {
                  onChanged(t);
                  state.didChange(t);
                },
              )),
              if (t != kTutelles.last) const SizedBox(width: 12),
            ],
          ]),
          if (enErreur) Padding(
            padding: const EdgeInsets.only(top: 8, left: 2),
            child: Text(state.errorText!,
                style: const TextStyle(color: _kRed, fontSize: 11.5,
                    fontWeight: FontWeight.w600)),
          ),
          if (changement) Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _TutelleAvertissement(ecoles: ecolesConcernees),
          ),
        ]);
      },
    );
  }
}

class _TutelleCard extends StatelessWidget {
  const _TutelleCard({
    required this.code,
    required this.selected,
    required this.enErreur,
    required this.onTap,
  });

  final String code;
  final bool selected, enErreur;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final couleur = couleurTutelle(code);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      mouseCursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: selected ? couleur.withValues(alpha: 0.07) : _kSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? couleur
                : (enErreur ? _kRed.withValues(alpha: 0.6) : _kBorder),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(
            selected
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 17,
            color: selected ? couleur : _kMuted,
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sigleTutelle(code) ?? code.toUpperCase(),
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: selected ? couleur : _kText,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                domaineTutelle(code) ?? '',
                style: TextStyle(fontSize: 11, color: _kMuted, height: 1.35),
              ),
            ],
          )),
        ]),
      ),
    );
  }
}

/// Ce que changer la tutelle d'un groupe déjà peuplé entraîne réellement.
class _TutelleAvertissement extends StatelessWidget {
  const _TutelleAvertissement({required this.ecoles});
  final int ecoles;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: _kOrange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kOrange.withValues(alpha: 0.35)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.warning_amber_rounded, size: 16, color: _kOrange),
        const SizedBox(width: 9),
        Expanded(child: Text(
          ecoles == 0
              ? 'Ce groupe n\'a pas encore d\'école : le changement n\'affecte '
                'que le groupe lui-même.'
              : 'À l\'enregistrement, ${ecoles == 1 ? "l'unique école" : "les $ecoles écoles"} '
                'de ce groupe ${ecoles == 1 ? "changera" : "changeront"} de '
                'ministère. Leurs états de rentrée et leurs inscriptions aux '
                'examens seront remontés à l\'autre administration.',
          style: TextStyle(fontSize: 11.5, color: _kText, height: 1.4),
        )),
      ]),
    );
  }
}
