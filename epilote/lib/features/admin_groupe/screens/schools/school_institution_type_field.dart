part of '../admin_schools_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CE QUE L'ÉCOLE EST — type d'établissement, et le ministère dont il découle
//
//  ⚠️ TROIS NOTIONS QUE LA FICHE NE DOIT PAS MÉLANGER :
//   • le SECTEUR       — public / privé   → hérité du groupe (mig. 0060)
//   • le MINISTÈRE     — MEPSA / METP     → hérité du groupe (mig. 0153)
//   • le TYPE D'ÉTABL. — CEG, CET, lycée… → déclaré ICI      (mig. 0151)
//
//  Les deux premiers s'affichent, verrouillés. Le troisième se choisit — et
//  seuls les types du ministère du groupe sont proposés : offrir « lycée
//  technique » à un groupe MEPSA n'aurait aucun sens administratif, chaque
//  ministère agréant ses propres établissements par sa propre commission.
//
//  ⚠️ ET LE TYPE N'EST PAS UN DIPLÔME. CET ≠ CAP, CET ≠ BET : le CET est
//  l'établissement, le BET est ce qu'on y prépare.
// ════════════════════════════════════════════════════════════════════════════

/// Le SECTEUR juridique, hérité du groupe et non modifiable : une école ne
/// peut pas être d'un autre secteur que son propriétaire (verrou en base,
/// migration 0060). Il vit ici, avec le ministère et le type, parce que les
/// trois répondent à la même question — ce que l'école EST — et que deux
/// d'entre eux sont hérités pour la même raison.
class SchoolSecteurHerite extends ConsumerWidget {
  const SchoolSecteurHerite({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final secteur =
        ref.watch(adminSchoolsProvider).valueOrNull?.groupType ?? 'prive';
    return TextFormField(
      enabled: false,
      key: ValueKey('secteur_$secteur'),
      initialValue: secteur == 'public' ? 'Public' : 'Privé',
      decoration: schoolInputDec('Secteur (hérité du groupe)'),
    );
  }
}

class SchoolInstitutionTypeField extends ConsumerWidget {
  const SchoolInstitutionTypeField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tutelle = ref.watch(adminSchoolsProvider).valueOrNull?.tutelle;

    // Groupe sans ministère : on ne devine pas, on dit quoi faire. Proposer
    // les huit types toutes tutelles confondues laisserait ranger un CEG sous
    // le METP sans que rien ne l'empêche.
    if (tutelle == null) {
      return const Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [_EnTeteTypeEtab(), _TypeEtabIndisponible()]);
    }

    final async = ref.watch(institutionTypesProvider(tutelle));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _EnTeteTypeEtab(),
      Row(children: [
        Expanded(child: _MinistereHerite(tutelle: tutelle)),
        const SizedBox(width: 12),
        Expanded(child: async.when(
          loading: () => TextFormField(
            enabled: false,
            decoration: schoolInputDec('Type d\'établissement…'),
          ),
          error: (e, _) => TextFormField(
            enabled: false,
            decoration: schoolInputDec(
                messageErreur(e, contexte: 'Types d\'établissement')),
          ),
          data: (types) => _TypeEtabDropdown(
            types: types,
            value: value,
            onChanged: onChanged,
          ),
        )),
      ]),
      const SizedBox(height: 8),
      async.maybeWhen(
        data: (types) {
          final t = types.where((e) => e.id == value).firstOrNull;
          if (t == null) {
            return Text(
              'Non déclaré. Une école non typée ne peut pas être comptée par '
              'type dans un état ministériel.',
              style: TextStyle(fontSize: 11, color: kTextMuted, height: 1.4),
            );
          }
          return _TypeEtabResume(type: t);
        },
        orElse: () => const SizedBox.shrink(),
      ),
    ]);
  }
}

/// Le ministère, affiché et verrouillé — comme le secteur juste au-dessus.
class _MinistereHerite extends StatelessWidget {
  const _MinistereHerite({required this.tutelle});
  final String tutelle;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      enabled: false,
      key: ValueKey('ministere_$tutelle'),
      initialValue: sigleTutelleOuTiret(tutelle),
      decoration: schoolInputDec('Ministère (hérité du groupe)').copyWith(
        prefixIcon: Icon(Icons.account_balance_outlined,
            size: 16, color: couleurTutelle(tutelle)),
      ),
    );
  }
}

class _TypeEtabDropdown extends StatelessWidget {
  const _TypeEtabDropdown({
    required this.types,
    required this.value,
    required this.onChanged,
  });

  final List<InstitutionType> types;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    // Une valeur héritée d'une autre tutelle (le groupe a changé de ministère)
    // ne figure pas dans la liste : la passer telle quelle à `initialValue`
    // ferait planter le Dropdown. On retombe sur « non déclaré », ce que le
    // résumé sous le champ dit explicitement.
    final connu = types.any((t) => t.id == value);
    return DropdownButtonFormField<String?>(
      initialValue: connu ? value : null,
      isExpanded: true,
      decoration: schoolInputDec('Type d\'établissement'),
      items: [
        const DropdownMenuItem(value: null, child: Text('— Non déclaré —')),
        ...types.map((t) => DropdownMenuItem(
              value: t.id,
              child: Text(t.name, overflow: TextOverflow.ellipsis),
            )),
      ],
      onChanged: onChanged,
    );
  }
}

/// Ce que le type choisi implique, en une ligne — durée, cycle, et le rappel
/// du statut réglementaire quand il n'est pas `en_vigueur`.
class _TypeEtabResume extends StatelessWidget {
  const _TypeEtabResume({required this.type});
  final InstitutionType type;

  @override
  Widget build(BuildContext context) {
    final bouts = <String>[
      if (type.shortName != null) type.shortName!,
      if (type.dureeLabel != null) type.dureeLabel!,
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (bouts.isNotEmpty)
        Text(bouts.join(' · '),
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: couleurTutelle(type.tutelle))),
      if (type.description != null) ...[
        const SizedBox(height: 3),
        Text(type.description!,
            style: TextStyle(fontSize: 11, color: kTextMuted, height: 1.4)),
      ],
      // ⚠️ Un type qui n'est pas `en_vigueur` le DIT. La réforme adoptée en
      // Conseil des ministres le 20 janvier 2026 n'est pas promulguée : rien
      // ne doit être opposé à un établissement sur ce fondement.
      if (!type.enVigueur) ...[
        const SizedBox(height: 5),
        Row(children: [
          const Icon(Icons.info_outline_rounded, size: 13, color: _kOrange),
          const SizedBox(width: 5),
          Expanded(child: Text(
            switch (type.statut) {
              'projet_reforme' =>
                'Projet de réforme non promulgué — à titre indicatif.',
              'historique' => 'Régime abrogé, conservé pour lire les archives.',
              _ => 'Saisi sans source officielle confirmée.',
            },
            style: const TextStyle(fontSize: 10.5, color: _kOrange, height: 1.35),
          )),
        ]),
      ],
    ]);
  }
}

/// Groupe sans ministère : le champ ne s'affiche pas vide, il explique.
class _TypeEtabIndisponible extends StatelessWidget {
  const _TypeEtabIndisponible();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: _kOrange.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kOrange.withValues(alpha: 0.3)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.info_outline_rounded, size: 15, color: _kOrange),
        const SizedBox(width: 9),
        Expanded(child: Text(
          'Le ministère de tutelle de ce groupe n\'est pas renseigné. '
          'Les types d\'établissement en dépendent : demandez à '
          'l\'administrateur de la plateforme de le déclarer.',
          style: TextStyle(fontSize: 11.5, color: kTextPrimary, height: 1.4),
        )),
      ]),
    );
  }
}

/// Le titre de section et ce qu'il faut avoir lu avant de choisir.
class _EnTeteTypeEtab extends StatelessWidget {
  const _EnTeteTypeEtab();

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SchFormLabel("TYPE D'ÉTABLISSEMENT"),
      const SizedBox(height: 4),
      Text(
        "Ce que l'école EST — collège, lycée, centre. À distinguer du secteur "
        '(public / privé) et du diplôme préparé : un CET est un établissement, '
        "le BET est ce qu'on y prépare.",
        style: TextStyle(fontSize: 11.5, color: kTextMuted, height: 1.4),
      ),
      const SizedBox(height: 12),
    ]);
  }
}
