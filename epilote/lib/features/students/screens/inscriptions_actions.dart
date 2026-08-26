part of 'inscriptions_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LES GESTES SUR UN DOSSIER — changer de classe, retirer, supprimer, rouvrir,
//  valider, rejeter, exporter, imprimer.
//
//  ── POURQUOI UNE EXTENSION, ET POURQUOI C'EST LÉGITIME ICI ─────────────────
//  Sortis de `inscriptions_screen.dart`, qui dépassait 980 lignes. Aucun de ces
//  gestes ne touche l'état de l'écran : ni `setState`, ni les filtres, ni la
//  sélection. Ils ne se servent de la page que pour trois choses — `ref`,
//  `context` et `mounted` — ce qui en fait un bloc DÉTACHABLE, et c'est
//  précisément ce qui autorise l'extension.
//
//  ⚠️ Les actions de LOT (`_bulkValidate`, `_bulkReject`) sont restées dans
//  l'écran : elles vident `_selected` par `setState`. Une extension n'étant pas
//  « membre d'instance d'une sous-classe », l'y déplacer déclencherait
//  `invalid_use_of_protected_member` — la même impasse que pour les pages du
//  formulaire de modification (cf. `inscriptions_edit.dart`).
//
//  Le déplacement est PUR : pas une signature changée, pas un appel réécrit.
//  C'est ce qui permet de le relire — ces gestes touchent la suppression et le
//  retrait d'un élève.
// ════════════════════════════════════════════════════════════════════════════

extension _InscriptionsActions on _InscriptionsBodyState {
  // ── Verrou LICENCE ─────────────────────────────────────────────────────────
  // Les gestes ci-dessous portent déjà leur propre `try` et leur propre
  // bandeau : on ne peut pas les passer par `runModuleWrite` sans afficher deux
  // messages pour un seul échec. On pose donc le MÊME verrou à la main, en tête
  // de chaque geste — avant la boîte de dialogue, pour ne pas faire saisir un
  // motif de rejet qui sera refusé ensuite.
  //
  // Il manquait ici, et ici seulement : le tiroir élève, l'annuaire, les
  // transferts et les dossiers passaient par `runModuleWrite`. Une école dont
  // l'abonnement avait expiré continuait donc d'inscrire, de valider et de
  // rejeter des dossiers — c'est-à-dire de faire entrer des élèves — pendant
  // que le reste de l'application était en lecture seule.

  Future<void> _changeClass(InscriptionRow r) async {
    if (writeRefusedForLicense(context)) return;
    // ⚠️ `.future` : `.valueOrNull` sur une famille `autoDispose` non écoutée
    // rendrait `null`, et l'écran annoncerait « aucune autre classe » alors
    // qu'il y en a.
    final classes = await ref.read(classesForModuleProvider(_kSlug).future);
    // La lecture ci-dessus est asynchrone : l'écran a pu partir entre-temps.
    if (!mounted) return;
    final others = classes.where((c) => c.id != r.classId).toList();
    if (others.isEmpty) {
      _snack('Aucune autre classe disponible.', kTextMuted);
      return;
    }
    final picked = await showDialog<ClassModel>(
      context: context,
      builder: (ctx) => SimpleDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Réaffecter ${r.fullName}'),
        children: [
          for (final c in others)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, c),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Icon(Icons.meeting_room_outlined,
                      size: 18, color: kNavy),
                  const SizedBox(width: 10),
                  Expanded(child: Text(c.name)),
                  Text('${c.studentCount ?? 0}'
                      '${c.capacity != null ? '/${c.capacity}' : ''}',
                      style: TextStyle(
                          fontSize: 12, color: kTextMuted)),
                ]),
              ),
            ),
        ],
      ),
    );
    if (picked == null) return;
    try {
      await changeEnrollmentClass(enrollmentId: r.id, newClassId: picked.id);
      _snack('Élève réaffecté dans ${picked.name}', kGreen);
    } catch (e) {
      _snack(messageErreur(e), kRed);
    }
  }

  Future<void> _withdraw(InscriptionRow r) async {
    if (writeRefusedForLicense(context)) return;
    final ctrl = TextEditingController();
    // Le motif normalisé est OBLIGATOIRE : c'est lui qui se compte. Le champ
    // libre reste à côté, pour le cas particulier. Sans catégorie, cette
    // sortie deviendrait une ligne de plus dans un total qu'on ne sait pas
    // ventiler — et la déperdition scolaire ne se lit nulle part ailleurs.
    String? motif;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Retirer de la classe'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            initialValue: motif,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Motif *'),
            items: [
              for (final m in motifsPour(transfert: false))
                DropdownMenuItem(value: m.code, child: Text(m.label)),
            ],
            onChanged: (v) => setLocal(() => motif = v),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: ctrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Précision (facultatif)',
              hintText: 'Ce que la catégorie ne dit pas',
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kAccent),
            onPressed:
                motif == null ? null : () => Navigator.pop(ctx, true),
            child: const Text('Retirer'),
          ),
        ],
        ),
      ),
    );
    if (ok != true) { ctrl.dispose(); return; }
    try {
      await withdrawStudent(
        enrollmentId: r.id,
        motif: motif!,
        reason: ctrl.text.trim().isEmpty ? '' : ctrl.text.trim(),
      );
      _snack('Élève retiré de la classe', kTextMuted);
    } catch (e) {
      _snack(messageErreur(e), kRed);
    }
    ctrl.dispose();
  }

  Future<void> _delete(InscriptionRow r) async {
    if (writeRefusedForLicense(context)) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Supprimer l\'inscription ?'),
        content: Text(
            'L\'inscription de ${r.fullName} pour cette année sera définitivement '
            'supprimée. La fiche élève (identité, tuteurs) est conservée.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await deleteEnrollment(r.id);
      _snack('Inscription supprimée', kTextMuted);
    } catch (e) {
      _snack(messageErreur(e), kRed);
    }
  }

  /// Pièces obligatoires manquantes au dossier de l'élève, en clair.
  ///
  /// Valider une inscription, c'est faire entrer l'élève dans l'effectif —
  /// et c'est le dernier moment où l'on regarde son dossier. On pouvait le
  /// faire sans acte de naissance ni certificat médical, sans qu'aucun écran
  /// ne le signale ; le manque ne se découvrait qu'au contrôle, des mois plus
  /// tard. On avertit, sans interdire : un dossier se complète souvent après
  /// la rentrée, et bloquer l'entrée d'un enfant pour une photo serait pire
  /// que le mal.
  ///
  /// ── ⚠️ POURQUOI C'EST `await …future` ET NON ` read().valueOrNull` ────────
  /// `studentDocumentsProvider` est un `StreamProvider.autoDispose` : lu sans
  /// écoute préalable, il rend `AsyncLoading`, donc `valueOrNull == null`, donc
  /// « pas encore lu : on ne présume rien », donc AUCUNE pièce manquante.
  ///
  /// Or le chemin normal de la validation est le bouton de la LIGNE
  /// (`inscriptions_screen.dart` → `onValidate: _validate`), où rien n'écoute
  /// ce provider. L'avertissement « Dossier incomplet » ne s'ouvrait donc
  /// jamais là où on valide vraiment — il ne fonctionnait que depuis la fiche
  /// détail, qui, elle, fait un `watch`, et encore par accident : le `pop()`
  /// précède l'appel et ne dispose le provider qu'à la frame suivante.
  ///
  /// La lecture attend maintenant la première valeur. Le geste juste était
  /// déjà écrit dans le fichier d'à côté (`eleves_actions_parts.dart`,
  /// `await ref.read(studentDossierProvider(row.id).future)`).
  Future<List<String>> _missingRequiredDocs(String studentId) async {
    final List<StudentDocument> docs;
    try {
      docs = await ref.read(studentDocumentsProvider(studentId).future);
    } catch (_) {
      // Le dossier est illisible (base locale en défaut) : on ne présume rien
      // et surtout on ne barre pas l'entrée d'un enfant pour une lecture ratée.
      return const [];
    }
    final present = {for (final d in docs) d.documentType};
    return [
      for (final t in kRequiredDocTypes)
        if (!present.contains(t)) docTypeLabel(t),
    ];
  }

  /// Le frais d'inscription de ce dossier, ou `null` s'il est illisible.
  ///
  /// Même piège que pour les pièces : `fraisInscriptionProvider` est un
  /// `FutureProvider.autoDispose`, et `read().valueOrNull` rendait `null` —
  /// donc « rien à signaler » — sur le chemin depuis la liste. La réserve de
  /// caisse ne s'affichait pas plus que celle du dossier.
  Future<FraisInscription?> _fraisInscription(String enrollmentId) async {
    try {
      return await ref.read(fraisInscriptionProvider(enrollmentId).future);
    } catch (_) {
      return null; // barème illisible : on n'invente pas une dette.
    }
  }

  /// `true` si l'on peut poursuivre (rien à signaler, ou l'agent assume).
  ///
  /// ── Deux réserves, un seul écran ────────────────────────────────────────
  /// Valider une inscription fait entrer l'élève dans l'effectif : c'est le
  /// dernier moment où l'on regarde le dossier. Deux choses peuvent manquer —
  /// des pièces, et l'argent — et il n'y a aucune raison de les signaler dans
  /// deux boîtes successives.
  ///
  /// ⚠️ On AVERTIT, on ne bloque JAMAIS. Barrer l'entrée d'un enfant à l'école
  /// pour un acte de naissance en retard ou un versement non fait serait pire
  /// que le mal — et ce serait, en pratique, transformer le module en outil de
  /// sélection par l'argent. C'est déjà la doctrine retenue pour les pièces ;
  /// elle vaut à plus forte raison pour la caisse.
  Future<bool> _confirmIncompleteDossier(InscriptionRow r) async {
    final missing = await _missingRequiredDocs(r.studentId);
    final frais = await _fraisInscription(r.id);
    final impaye = frais != null && frais.baremeDefini && frais.reste > 0;
    if (missing.isEmpty && !impaye) return true;
    if (!mounted) return false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(missing.isEmpty
            ? 'Frais d\'inscription non soldés'
            : 'Dossier incomplet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (missing.isNotEmpty) ...[
              Text('Il manque au dossier de ${r.fullName} :',
                  style: TextStyle(color: kTextPrimary)),
              const SizedBox(height: 8),
              for (final m in missing)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(children: [
                    Icon(Icons.circle, size: 6, color: kAccent),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(m, style: TextStyle(color: kTextPrimary))),
                  ]),
                ),
              const SizedBox(height: 10),
            ],
            if (impaye) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: kAccent.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kAccent.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  Icon(Icons.payments_outlined, size: 17, color: kAccent),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Il reste ${frais.reste} F à encaisser sur '
                      '${frais.du} F de frais d\'inscription.',
                      style: TextStyle(
                          fontSize: 12.5, color: kTextPrimary, height: 1.4),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 10),
            ],
            Text(
              missing.isEmpty
                  ? 'Vous pouvez valider quand même : le solde reste suivi '
                      'dans le dossier et dans le module Paiements.'
                  : 'Vous pouvez valider quand même — ce qui manque reste '
                      'signalé dans le dossier de l\'élève.',
              style: TextStyle(fontSize: 12.5, color: kTextMuted, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kGreen),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Valider quand même'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  /// Remet un dossier rejeté en attente de validation, sans effacer le rejet.
  Future<void> _reopen(InscriptionRow r) async {
    if (writeRefusedForLicense(context)) return;
    // `enrollmentDetailProvider` est lui aussi un `FutureProvider.autoDispose` :
    // lu sans écoute, il rendait `null`, et la boîte « Reprendre le dossier ? »
    // taisait le motif du rejet — c'est-à-dire la seule chose qu'elle avait à
    // rappeler à l'agent avant qu'il ne le remette dans le circuit.
    Map<String, dynamic>? motif;
    try {
      motif = await ref.read(enrollmentDetailProvider(r.id).future);
    } catch (_) {
      motif = null;
    }
    if (!mounted) return;
    final raison = (motif?['rejection_reason'] as String?)?.trim();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Reprendre le dossier ?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'L\'inscription de ${r.fullName} repassera « en attente de '
              'validation ». Le motif du rejet est conservé dans les notes '
              'internes du dossier.',
              style: TextStyle(color: kTextPrimary, height: 1.45),
            ),
            if (raison != null && raison.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: kRed.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kRed.withValues(alpha: 0.25)),
                ),
                child: Text('Motif du rejet : $raison',
                    style: TextStyle(fontSize: 12.5, color: kTextPrimary)),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reprendre'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final me = ref.read(authNotifierProvider).valueOrNull;
    try {
      await reopenRejectedEnrollment(
        enrollmentId: r.id,
        actorName: [me?.firstName, me?.lastName]
                .whereType<String>()
                .where((s) => s.trim().isNotEmpty)
                .join(' ')
                .trim()
                .isEmpty
            ? 'le secrétariat'
            : '${me?.firstName ?? ''} ${me?.lastName ?? ''}'.trim(),
      );
      ref.invalidate(enrollmentDetailProvider(r.id));
      _snack('Dossier repris — en attente de validation', kAccent);
    } catch (e) {
      _snack(messageErreur(e), kRed);
    }
  }

  Future<void> _validate(InscriptionRow r) async {
    if (writeRefusedForLicense(context)) return;
    if (!await _confirmIncompleteDossier(r)) return;
    final me = _actorOrComplain();
    if (me == null) return;
    try {
      await validateEnrollment(enrollmentId: r.id, validatedBy: me);
      _snack('Inscription validée', kGreen);
    } catch (e) {
      _snack(messageErreur(e), kRed);
    }
  }

  Future<void> _reject(InscriptionRow r) async {
    if (writeRefusedForLicense(context)) return;
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Rejeter l\'inscription'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Motif du rejet',
            hintText: 'Ex. : Dossier incomplet, quota atteint…',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rejeter'),
          ),
        ],
      ),
    );
    if (ok != true) { ctrl.dispose(); return; }
    final me = _actorOrComplain();
    if (me == null) { ctrl.dispose(); return; }
    try {
      await rejectEnrollment(
        enrollmentId: r.id,
        rejectionReason:
            ctrl.text.trim().isEmpty ? 'Aucun motif précisé' : ctrl.text.trim(),
        validatedBy: me,
      );
      _snack('Inscription rejetée', kTextMuted);
    } catch (e) {
      _snack(messageErreur(e), kRed);
    }
    ctrl.dispose();
  }

  Future<void> _export(List<InscriptionRow> rows) async {
    if (rows.isEmpty) return;
    try {
      final path = await exportInscriptionsCsv(rows);
      _snack('Export CSV : ${rows.length} ligne(s) → $path', kGreen);
    } catch (e) {
      _snack(messageErreur(e, contexte: 'Export'), kRed);
    }
  }

  void _previewPdf(List<InscriptionRow> rows) {
    if (rows.isEmpty) return;
    final year = ref.read(activeYearProvider)?.label;
    showPdfPreviewDialog(
      context,
      title: 'Inscriptions',
      subtitle: '${rows.length} inscription${rows.length > 1 ? 's' : ''}'
          '${year != null ? ' · $year' : ''}',
      pdfFileName: 'Inscriptions.pdf',
      build: (format) =>
          InscriptionsPdfService.buildPdf(rows: rows, yearLabel: year),
      onDownload: () =>
          InscriptionsPdfService.downloadDoc(rows: rows, yearLabel: year),
    );
  }

  void _snack(String msg, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: c));
  }

  /// L'agent qui valide, ou `null` si son identité n'est pas résolue.
  ///
  /// `class_enrollments.validated_by` est un `uuid` NOT NULL avec clé étrangère
  /// vers `profiles`. Le motif `?? ''` qui régnait ici écrivait une chaîne vide :
  /// SQLite l'accepte, le badge passait « Validée », puis le serveur répondait
  /// `22P02` et PowerSync abandonnait le LOT ENTIER. L'inscription restait « en
  /// attente » partout ailleurs et l'élève n'entrait jamais dans l'effectif — en
  /// emportant au passage tout ce qui avait été saisi dans la même fenêtre.
  /// En validation groupée, la même chaîne vide partait sur N lignes d'un coup.
  String? _actorOrComplain() {
    final id = ref.read(authNotifierProvider).valueOrNull?.id;
    if (isUsableId(id)) return id!.trim();
    _snack(writeIdentityMessage(const ['agent']), kRed);
    return null;
  }
}
