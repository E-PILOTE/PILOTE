part of '../school_groups_screen.dart';

// ─── Le rôle de tutelle ───────────────────────────────────────────────────────

/// Fait de ce groupe LE ministère de tutelle de son enseignement.
///
/// ⚠️ CE N'EST PAS UNE CASE COMME LES AUTRES, et l'écran doit le dire. Ce
/// booléen (`administre_referentiel_national`, migration 0155) ouvre à lui
/// seul quatre choses qu'aucun autre réglage n'ouvre :
///
///   • ÉCRIRE le référentiel national des examens de sa tutelle ;
///   • VOIR tout le réseau du ministère — les écoles qu'il ne possède pas
///     comprises, avec le nom de leurs chefs d'établissement ;
///   • ÉMETTRE des circulaires qui descendent jusqu'aux écoles ;
///   • recevoir une licence de tutelle.
///
/// Il était posé par une migration et par rien d'autre : aucun écran ne
/// l'écrivait. Cet interrupteur est le premier — d'où l'index unique posé
/// AVANT lui (migration 0178), sans quoi deux groupes auraient pu se le voir
/// accorder pour le même ministère et écrire tous les deux la même session
/// d'examen d'État.
class _RoleDeTutelle extends StatelessWidget {
  const _RoleDeTutelle({
    required this.actif,
    required this.tutelle,
    required this.detenteur,
    required this.valeurInitiale,
    required this.onChanged,
  });

  /// État de l'interrupteur.
  final bool actif;

  /// Ministère choisi juste au-dessus. Sans lui, le rôle n'a pas d'objet :
  /// « être la tutelle » n'a de sens que rapporté à UN ministère.
  final String? tutelle;

  /// Nom du groupe qui détient déjà le rôle pour [tutelle], s'il y en a un
  /// autre que celui qu'on est en train de modifier.
  final String? detenteur;

  /// Ce que le rôle valait à l'ouverture. Sert à distinguer « on l'accorde »
  /// de « on le retire » — deux gestes qui ne se disent pas pareil.
  final bool valeurInitiale;

  final ValueChanged<bool> onChanged;

  /// Pourquoi l'interrupteur ne peut pas être ARMÉ, ou `null` s'il le peut.
  ///
  /// ⚠️ On ne bloque JAMAIS le retrait : déplacer le rôle d'un groupe vers un
  /// autre impose de le retirer au premier. Un blocage symétrique rendrait ce
  /// déplacement impossible, et c'est justement la manœuvre pour laquelle cet
  /// écran existe.
  String? get _blocage {
    if (actif) return null;
    if (!tutelleConnue(tutelle)) {
      return 'Choisissez d’abord le ministère de tutelle ci-dessus.';
    }
    if (detenteur != null) {
      return '« $detenteur » est déjà le ministère de tutelle '
          '${sigleTutelle(tutelle)}. Retirez-lui d’abord ce rôle : deux '
          'groupes de tutelle pour un même ministère écriraient tous les deux '
          'le référentiel national des examens.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bloque = _blocage;
    // ⚠️ Le rôle armé PUIS le ministère changé pour un ministère déjà pourvu :
    // l'interrupteur reste actif (il faut pouvoir le désarmer), mais la base
    // refusera l'enregistrement. On le dit ici plutôt que de laisser l'agent
    // le découvrir en cliquant « Enregistrer ».
    final conflit = actif && detenteur != null;
    final couleur = couleurTutelle(tutelle);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        decoration: BoxDecoration(
          color: actif ? couleur.withValues(alpha: 0.07) : _kSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: actif ? couleur : _kBorder,
            width: actif ? 1.6 : 1,
          ),
        ),
        child: Row(children: [
          Icon(Icons.account_balance_rounded,
              size: 18, color: actif ? couleur : _kMuted),
          const SizedBox(width: 11),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ce groupe EST un ministère de tutelle',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: bloque != null ? _kMuted : (actif ? couleur : _kText),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Il supervise alors tous les établissements de son ministère, '
                'y compris ceux qu’il ne possède pas.',
                style: TextStyle(fontSize: 11, color: _kMuted, height: 1.35),
              ),
            ],
          )),
          const SizedBox(width: 6),
          Switch(
            value: actif,
            activeThumbColor: couleur,
            onChanged: bloque != null ? null : onChanged,
          ),
        ]),
      ),
      if (bloque != null) _NoteRole(texte: bloque, couleur: _kMuted),
      if (conflit)
        _NoteRole(
          couleur: _kRed,
          icone: Icons.error_outline_rounded,
          texte: 'L’enregistrement sera refusé : « $detenteur » est déjà le '
              'ministère de tutelle ${sigleTutelle(tutelle) ?? ''}. Retirez ce '
              'rôle ici, ou retirez-le d’abord à l’autre groupe.',
        ),
      if (actif && !conflit && !valeurInitiale)
        _NoteRole(
          couleur: couleur,
          icone: Icons.info_outline_rounded,
          texte: 'À l’enregistrement, ce groupe pourra écrire le référentiel '
              'national des examens ${sigleTutelle(tutelle) ?? ''}, voir '
              'toutes les écoles de ce ministère et leur adresser des '
              'circulaires.',
        ),
      if (!actif && valeurInitiale)
        const _NoteRole(
          couleur: _kOrange,
          icone: Icons.warning_amber_rounded,
          texte: 'Ce groupe perdra le réseau de son ministère, l’émission de '
              'circulaires et l’écriture du référentiel national. Tant qu’il '
              'n’est accordé à aucun autre groupe, ce ministère n’a plus de '
              'tutelle sur la plateforme.',
        ),
    ]);
  }
}

/// Une ligne d'explication sous l'interrupteur.
class _NoteRole extends StatelessWidget {
  const _NoteRole({
    required this.texte,
    required this.couleur,
    this.icone,
  });

  final String texte;
  final Color couleur;
  final IconData? icone;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 9),
    child: Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: couleur.withValues(alpha: 0.30)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icone ?? Icons.lock_outline_rounded, size: 15, color: couleur),
        const SizedBox(width: 9),
        Expanded(child: Text(texte,
            style: TextStyle(fontSize: 11.5, color: _kText, height: 1.4))),
      ]),
    ),
  );
}
