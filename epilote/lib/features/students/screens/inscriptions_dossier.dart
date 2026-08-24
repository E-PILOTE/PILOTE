part of 'inscriptions_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LA FICHE D'UN DOSSIER — lecture, actions, impression.
//
//  Détaché de `inscriptions_modals.dart`, qui dépassait 1 600 lignes. La coupe
//  suit une couture de cohésion : ce fichier CONSULTE un dossier et agit
//  dessus, `inscriptions_edit.dart` le MODIFIE, `inscriptions_frais_card.dart`
//  l'encaisse. Trois gestes, trois lecteurs, trois fichiers.
//
//  L'habillage reste celui du kit `inscription_form_kit.dart`, partagé avec
//  l'assistant d'inscription : cadre blanc, en-tête à icône dégradée, cartes
//  récap.
// ════════════════════════════════════════════════════════════════════════════

// ─── Badges colorés (statut / type) sur fond clair ───────────────────────────
Widget _statusBadge(String status) {
  final (label, color) = switch (status) {
    'active' => ('Validée', kGreen),
    'pending_validation' => ('En attente', kAccent),
    'rejected' => ('Rejetée', kRed),
    'withdrawn' => ('Retirée', kTextMuted),
    'transferred' => ('Transférée', kNavy),
    'graduated' => ('Diplômée', kGreen),
    _ => (status, kTextMuted),
  };
  return AdminBadge(label, color: color);
}

Widget _typeBadge(String type) {
  final (label, color) = switch (type) {
    'new' => ('Nouvelle', kGreen),
    'reinscription' => ('Réinscription', kNavy),
    'transfer' => ('Transfert', kAccent),
    _ => (type, kTextMuted),
  };
  return AdminBadge(label, color: color);
}

String _tutorRel(String code) => tutorRelationshipLabel(code);

// Convertit une classe en entrée de cascade Cycle ▸ Niveau ▸ Classe.
ClassPickerEntry _pickerEntry(ClassModel c) {
  final cyc = inscriptionCycleFromCode(c.cycleCode, c.name);
  return ClassPickerEntry(
    id: c.id,
    name: c.name,
    cycleCode: cyc.code,
    cycleLabel: cyc.label,
    cycleOrder: cyc.order,
    levelCode: c.levelCode ?? '',
    levelOrder: c.levelOrder ?? 999,
    capacity: c.capacity,
    count: c.studentCount,
  );
}


// ════════════════════════════════════════════════════════════════════════════
//  FICHE DÉTAIL (icône œil) — même habillage que l'inscription (en-tête blanc à
//  icône dégradée) + récap façon « Résumé », enrichi (photo, badges, actions).
// ════════════════════════════════════════════════════════════════════════════
class _InscriptionDetailModal extends ConsumerWidget {
  const _InscriptionDetailModal({
    required this.row,
    required this.onEdit,
    this.onValidate,
    this.onReject,
    this.onChangeClass,
    this.onWithdraw,
    this.onDelete,
    this.readOnly = false,
  });
  final InscriptionRow row;
  final VoidCallback onEdit;
  final VoidCallback? onValidate, onReject;
  final VoidCallback? onChangeClass, onWithdraw, onDelete;
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dossier = ref.watch(studentDossierProvider(row.studentId));
    return InscriptionModalFrame(
      maxHeight: 820,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        InscriptionHeader(
          icon: Icons.badge_outlined,
          title: row.fullName,
          subtitle: '${row.className} · ${row.matricule}',
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: dossier.when(
              loading: () => const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child:
                      Text(messageErreur(e), style: TextStyle(color: kRed))),
              data: (d) => _DossierBody(row: row, d: d),
            ),
          ),
        ),
        _DetailActionBar(
          readOnly: readOnly,
          // Imprimer la fiche est une LECTURE : elle reste offerte sur une
          // année archivée et sur un dossier rejeté. C'est même là qu'une
          // famille vient réclamer une trace.
          onPrintFiche: () => _printFiche(context, ref),
          isPending: row.status == 'pending_validation',
          onValidate: onValidate,
          onReject: onReject,
          onEdit: onEdit,
          onChangeClass: onChangeClass,
          onWithdraw: onWithdraw,
          onDelete: onDelete,
        ),
      ]),
    );
  }

  /// Ouvre l'aperçu de la fiche d'inscription — le récépissé que la famille
  /// emporte. Le tirage vit désormais dans `fiche_inscription_actions.dart` :
  /// il se déclenche aussi depuis la fin de l'assistant et depuis la sélection
  /// multiple, et il ne pouvait pas rester une méthode privée de ce modal.
  void _printFiche(BuildContext context, WidgetRef ref) =>
      ouvrirFicheInscription(context, ref, row);
}

// ─── Corps du dossier (bandeau identité + cartes récap façon inscription) ────
class _DossierBody extends ConsumerWidget {
  const _DossierBody({required this.row, required this.d});
  final InscriptionRow row;
  final StudentDossier d;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enroll =
        ref.watch(enrollmentDetailProvider(row.id)).valueOrNull ?? const {};
    final docs =
        ref.watch(studentDocumentsProvider(row.studentId)).valueOrNull ??
            const <StudentDocument>[];

    final dob = d.dob;
    final age = row.age;
    final naissance = dob == null
        ? '—'
        : '${dob.toIso8601String().substring(0, 10)}${age != null ? '  ($age ans)' : ''}';
    final adresse = [d.s('address'), d.s('city'), d.s('region')]
        .where((e) => e.isNotEmpty)
        .join(', ');
    final siblings = d.student['nombre_freres_soeurs'];
    final siblingsLabel =
        (siblings is int && siblings > 0) ? '$siblings' : '';

    final statuts = <(String, String)>[
      if (_b(d.student['is_boarder'])) ('Interne', '✓'),
      if (_b(d.student['is_affecte'])) ('Affecté MEPSA/METP', '✓'),
      if (_b(d.student['has_scholarship']))
        ('Boursier', _vOr(d.s('scholarship_type'), '✓')),
      if (_b(d.student['has_social_aid']))
        ('Aide sociale', _vOr(d.s('social_aid_type'), '✓')),
    ];

    final prevSchool = (enroll['previous_school_name'] as String?)?.trim() ?? '';
    final prevClass = (enroll['previous_class_name'] as String?)?.trim() ?? '';
    final notes = (enroll['notes'] as String?)?.trim() ?? '';
    final rejection = (enroll['rejection_reason'] as String?)?.trim() ?? '';
    final withdrawal = (enroll['withdrawal_reason'] as String?)?.trim() ?? '';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Bandeau identité (photo + badges) — le « mieux ».
      Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder),
        ),
        child: Row(children: [
          _Avatar(row: row, size: 54),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: kTextPrimary)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  _statusBadge(row.status),
                  _typeBadge(row.inscriptionType),
                  if (row.isRepeating)
                    AdminBadge('Redoublant', color: kRed),
                ]),
              ],
            ),
          ),
        ]),
      ),
      ResumeCard(
        title: 'Inscription',
        icon: Icons.how_to_reg_outlined,
        rows: [
          ('Matricule', row.matricule),
          ('Classe', row.className),
          ('Cycle', row.cycle.label),
          ('Niveau', _orDash(row.levelCode)),
          if (row.filiereLabel != null) ('Filière', row.filiereLabel!),
          ('Type', row.typeLabel),
          ('Statut', row.statusLabel),
          ('Redoublant', row.isRepeating ? 'Oui' : 'Non'),
          ('Date d\'inscription',
              row.enrollmentDate?.toIso8601String().substring(0, 10) ?? '—'),
          if (row.validatedAt != null)
            ('Validée le', row.validatedAt!.toIso8601String().substring(0, 10)),
          if (prevSchool.isNotEmpty) ('École précédente', prevSchool),
          if (prevClass.isNotEmpty) ('Classe précédente', prevClass),
          if (rejection.isNotEmpty) ('Motif du rejet', rejection),
          if (withdrawal.isNotEmpty) ('Motif du retrait', withdrawal),
          if (notes.isNotEmpty) ('Notes internes', notes),
        ],
      ),
      ResumeCard(
        title: 'Identité',
        icon: Icons.person_outline,
        rows: [
          (
            'Sexe',
            row.gender == 'F'
                ? 'Féminin'
                : row.gender == 'M'
                    ? 'Masculin'
                    : '—'
          ),
          ('Naissance', naissance),
          ('Lieu de naissance', _orDash(d.s('place_of_birth'))),
          ('Nationalité', _orDash(d.s('nationality'))),
          ('Situation familiale', _situationLabel(d.s('situation_familiale'))),
          if (siblingsLabel.isNotEmpty) ('Frères et sœurs', siblingsLabel),
          ('Groupe sanguin', _orDash(d.s('blood_group'))),
          if (d.s('allergies').isNotEmpty) ('Antécédents', d.s('allergies')),
          ('Adresse', _orDash(adresse)),
        ],
      ),
      if (statuts.isNotEmpty)
        ResumeCard(
          title: 'Statuts particuliers',
          icon: Icons.verified_outlined,
          rows: statuts,
        ),
      ResumeCard(
        title: 'Tuteurs (${d.tutors.length})',
        icon: Icons.family_restroom_outlined,
        rows: d.tutors.isEmpty
            ? [('Aucun tuteur enregistré', '')]
            : [
                for (final t in d.tutors)
                  (
                    t.isPrimary ? 'Principal' : _tutorRel(t.relationship),
                    [
                      t.fullName,
                      if ((t.phonePrimary ?? '').trim().isNotEmpty)
                        '· ${t.phonePrimary}',
                      if ((t.profession ?? '').trim().isNotEmpty)
                        '· ${t.profession}',
                      if (t.isEmergency) '· urgence',
                    ].join(' '),
                  ),
              ],
      ),
      // ── L'ARGENT, AU GUICHET ────────────────────────────────────────────
      // Le dossier disait tout de l'élève et rien de ce qu'il doit. Le chef
      // validait donc une inscription sans savoir si elle était payée — alors
      // que dans une école privée congolaise, c'est le versement qui FAIT
      // l'inscription.
      _FraisInscriptionCard(row: row),
      // La remise se décide au même endroit que l'encaissement : c'est le
      // guichet qui sait que l'enfant est boursier, et c'est là que l'écart
      // entre « déclaré boursier » et « exonéré de X % » doit sauter aux yeux.
      // Un dossier clos (retiré, transféré, diplômé) se consulte sans se
      // modifier — sa scolarité est un fait passé.
      ExonerationCard(
        enrollmentId: row.id,
        modifiable: row.status == 'active' || row.status == 'pending_validation',
      ),
      ResumeCard(
        title: 'Dossier (${docs.length} pièce${docs.length > 1 ? 's' : ''})',
        icon: Icons.folder_open_rounded,
        rows: docs.isEmpty
            ? [('Aucune pièce téléversée', '')]
            : [
                for (final doc in docs)
                  (
                    docTypeLabel(doc.documentType),
                    doc.isVerified ? '✓ vérifiée' : 'à vérifier',
                  ),
              ],
      ),
    ]);
  }

  static String _vOr(String v, String fallback) => v.isEmpty ? fallback : v;
  bool _b(Object? v) => v == 1 || v == true;
}


// ─── Barre d'actions de la fiche détail ──────────────────────────────────────
class _DetailActionBar extends StatelessWidget {
  const _DetailActionBar({
    required this.readOnly,
    required this.onPrintFiche,
    required this.isPending,
    required this.onValidate,
    required this.onReject,
    required this.onEdit,
    required this.onChangeClass,
    required this.onWithdraw,
    required this.onDelete,
  });
  final bool readOnly, isPending;
  final VoidCallback? onValidate, onReject, onChangeClass, onWithdraw, onDelete;
  final VoidCallback onEdit, onPrintFiche;

  @override
  Widget build(BuildContext context) {
    if (readOnly) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: kCardBg,
            border: Border(top: BorderSide(color: kBorder))),
        child: Row(children: [
          Icon(Icons.lock_outline_rounded, size: 16, color: kTextMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Année archivée — consultation seule.',
                style: TextStyle(fontSize: 12.5, color: kTextMuted)),
          ),
          _OutlineBtn(
            label: 'Fiche',
            icon: Icons.print_outlined,
            color: kNavy,
            onTap: onPrintFiche,
          ),
        ]),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
          color: kCardBg,
          border: Border(top: BorderSide(color: kBorder))),
      child: Row(children: [
        if (isPending && onValidate != null) ...[
          Expanded(
            child: AdminPrimaryButton(
              label: 'Valider',
              icon: Icons.check_rounded,
              color: kGreen,
              onTap: onValidate!,
            ),
          ),
          const SizedBox(width: 10),
        ],
        if (isPending && onReject != null) ...[
          _OutlineBtn(
            label: 'Rejeter',
            icon: Icons.close_rounded,
            color: kRed,
            onTap: onReject!,
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: AdminPrimaryButton(
            label: 'Modifier',
            icon: Icons.edit_outlined,
            color: kNavy,
            onTap: onEdit,
          ),
        ),
        const SizedBox(width: 10),
        _OutlineBtn(
          label: 'Fiche',
          icon: Icons.print_outlined,
          color: kNavy,
          onTap: onPrintFiche,
        ),
        const SizedBox(width: 10),
        _MoreMenu(
          onChangeClass: onChangeClass,
          onWithdraw: onWithdraw,
          onDelete: onDelete,
        ),
      ]),
    );
  }
}

class _MoreMenu extends StatelessWidget {
  const _MoreMenu({
    required this.onChangeClass,
    required this.onWithdraw,
    required this.onDelete,
  });
  final VoidCallback? onChangeClass, onWithdraw, onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Plus d\'actions',
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      offset: const Offset(0, 6),
      onSelected: (v) {
        switch (v) {
          case 'class':
            onChangeClass?.call();
          case 'withdraw':
            onWithdraw?.call();
          case 'delete':
            onDelete?.call();
        }
      },
      itemBuilder: (_) => [
        if (onChangeClass != null)
          const PopupMenuItem(
            value: 'class',
            child: _MenuRow(
                icon: Icons.swap_horiz_rounded, label: 'Changer de classe'),
          ),
        if (onWithdraw != null)
          const PopupMenuItem(
            value: 'withdraw',
            child: _MenuRow(
                icon: Icons.logout_rounded, label: 'Retirer de la classe'),
          ),
        if (onDelete != null) ...[
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'delete',
            child: _MenuRow(
                icon: Icons.delete_outline_rounded,
                label: 'Supprimer l\'inscription',
                color: kRed),
          ),
        ],
      ],
      child: Container(
        height: 44,
        width: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder),
        ),
        child: Icon(Icons.more_horiz_rounded, color: kTextMuted),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, this.color});
  final IconData icon;
  final String label;
  final Color? color;
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 18, color: color ?? kTextPrimary),
        const SizedBox(width: 10),
        Text(label,
            style: TextStyle(
                fontSize: 13.5,
                color: color ?? kTextPrimary,
                fontWeight: FontWeight.w600)),
      ]);
}

