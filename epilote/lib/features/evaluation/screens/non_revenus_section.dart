// ════════════════════════════════════════════════════════════════════════════
//  NON REVENUS — ce que l'établissement CONSTATE
//
//  Les deux autres onglets portent des décisions ; celui-ci porte un fait :
//  des enfants attendus ne sont pas là. C'est le premier signal de déperdition
//  scolaire, et jusqu'ici il n'était écrit nulle part — l'inscription de l'an
//  dernier restait `active`, l'enfant restait compté dans un effectif où il
//  n'était plus.
//
//  ── DEUX PRÉCAUTIONS, ET ELLES COMPTENT PLUS QUE L'ÉCRAN ───────────────────
//  1. Tant que la rentrée n'est pas saisie, la liste dirait que TOUT le monde
//     a disparu. L'écran se tait alors, et dit pourquoi.
//  2. Le motif écrit est `non_reinscrit` — « l'école ignore ce qu'il est
//     devenu ». Jamais « abandon » : ce serait inventer une cause, et fausser
//     le seul chiffre que le ministère lira. Qui SAIT passe par la fiche de
//     l'élève, où toute la nomenclature est offerte.
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/ine.dart';
import '../../../core/widgets/admin_ui.dart';
import '../providers/non_revenus_provider.dart';
import '../../../core/utils/message_erreur.dart';

class NonRevenusSection extends ConsumerStatefulWidget {
  const NonRevenusSection({
    super.key,
    required this.yearId,
    required this.yearLabel,
    required this.canEdit,
  });

  final String yearId, yearLabel;
  final bool canEdit;

  @override
  ConsumerState<NonRevenusSection> createState() => _NonRevenusSectionState();
}

class _NonRevenusSectionState extends ConsumerState<NonRevenusSection> {
  final Set<String> _selection = {};
  bool _busy = false;

  Future<void> _prononcer(List<EleveNonRevenu> eleves) async {
    final choisis = eleves.where((e) => _selection.contains(e.enrollmentId)).toList();
    if (choisis.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.person_off_outlined, color: kRed, size: 32),
        title: Text('Prononcer ${choisis.length} non-retour'
            '${choisis.length > 1 ? 's' : ''} ?'),
        content: Text(
          'Leur inscription de ${widget.yearLabel} sera close avec le motif '
          '« Ne s\'est pas représenté ».\n\n'
          'C\'est une réponse honnête : l\'école ignore ce que ces enfants '
          'sont devenus. Si vous savez pourquoi l\'un d\'eux est parti — '
          'déménagement, transfert, raisons familiales — fermez plutôt son '
          'inscription depuis sa fiche, avec le bon motif.',
          style: const TextStyle(height: 1.45),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: kRed),
            child: const Text('Prononcer'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await prononcerNonRetour(choisis.map((e) => e.enrollmentId).toList());
      _selection.clear();
      ref.invalidate(nonRevenusProvider(widget.yearId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: kGreen,
          content: Text('${choisis.length} non-retour'
              '${choisis.length > 1 ? 's' : ''} enregistré'
              '${choisis.length > 1 ? 's' : ''}'),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: kRed, content: Text(messageErreur(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(nonRevenusProvider(widget.yearId));
    return async.when(
      loading: () => const Padding(
          padding: EdgeInsets.only(top: 60),
          child: Center(child: CircularProgressIndicator())),
      error: (e, _) => Padding(
          padding: const EdgeInsets.only(top: 40),
          child: Center(child: Text(messageErreur(e)))),
      data: (bilan) {
        if (!bilan.aUnPasse) {
          return const AdminEmptyState(
            icon: Icons.history_toggle_off_rounded,
            title: 'Première année de l\'établissement',
            message: 'Il n\'y a pas d\'année précédente à laquelle comparer : '
                'personne ne peut manquer à l\'appel.',
          );
        }
        if (!bilan.rentreeSaisie) return _RentreePasSaisie(bilan: bilan);
        if (bilan.eleves.isEmpty) {
          return AdminEmptyState(
            icon: Icons.verified_outlined,
            title: 'Tout le monde est revenu',
            message: 'Les ${bilan.effectifPrecedent} élèves de '
                '${bilan.labelPrecedent} ont tous une inscription cette '
                'année. C\'est rare, et c\'est une bonne nouvelle.',
          );
        }
        return _Liste(
          bilan: bilan,
          selection: _selection,
          busy: _busy,
          canEdit: widget.canEdit,
          onToggle: (id) => setState(() =>
              _selection.contains(id) ? _selection.remove(id) : _selection.add(id)),
          onToggleAll: () => setState(() {
            if (_selection.length == bilan.eleves.length) {
              _selection.clear();
            } else {
              _selection
                ..clear()
                ..addAll(bilan.eleves.map((e) => e.enrollmentId));
            }
          }),
          onPrononcer: () => _prononcer(bilan.eleves),
        );
      },
    );
  }
}

/// Le garde-fou. Une liste fausse ne se rattrape pas : on ne la croit plus.
class _RentreePasSaisie extends StatelessWidget {
  const _RentreePasSaisie({required this.bilan});
  final BilanRentree bilan;

  @override
  Widget build(BuildContext context) {
    final pct = (bilan.avancement * 100).round();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kAccent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kAccent.withValues(alpha: 0.25)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.hourglass_top_rounded, color: kAccent, size: 26),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('La rentrée n\'est pas encore saisie',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              bilan.effectifPrecedent == 0
                  ? 'Aucun effectif n\'est enregistré pour '
                      '${bilan.labelPrecedent}. Il n\'y a rien à comparer.'
                  : '${bilan.reinscritsCetteAnnee} élève'
                      '${bilan.reinscritsCetteAnnee > 1 ? 's' : ''} sur '
                      '${bilan.effectifPrecedent} ont une inscription cette '
                      'année, soit $pct %. Tant que les réinscriptions sont en '
                      'cours, cette liste désignerait comme « disparus » des '
                      'enfants qu\'on n\'a simplement pas encore saisis.',
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 10),
            Text(
              'L\'écran s\'ouvrira de lui-même au-delà de 30 % de '
              'réinscriptions. Rien n\'est perdu d\'ici là : les inscriptions '
              'de l\'an dernier restent en l\'état.',
              style: TextStyle(fontSize: 12, color: kTextMuted, height: 1.45),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Liste extends StatelessWidget {
  const _Liste({
    required this.bilan,
    required this.selection,
    required this.busy,
    required this.canEdit,
    required this.onToggle,
    required this.onToggleAll,
    required this.onPrononcer,
  });

  final BilanRentree bilan;
  final Set<String> selection;
  final bool busy, canEdit;
  final ValueChanged<String> onToggle;
  final VoidCallback onToggleAll, onPrononcer;

  @override
  Widget build(BuildContext context) {
    final taux = (bilan.tauxNonRetour * 100).toStringAsFixed(1);
    final filles = bilan.eleves.where((e) => e.gender == 'F').length;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // ── Ce que le chiffre veut dire ────────────────────────────────────
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kRed.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kRed.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          Icon(Icons.person_search_rounded, color: kRed, size: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${bilan.eleves.length} élève'
                  '${bilan.eleves.length > 1 ? 's' : ''} de '
                  '${bilan.labelPrecedent} sans inscription cette année',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              Text(
                'Soit $taux % de l\'effectif, dont $filles fille'
                '${filles > 1 ? 's' : ''}. '
                '${bilan.reinscritsCetteAnnee} sont déjà réinscrits.',
                style: TextStyle(fontSize: 12.5, color: kTextMuted),
              ),
            ]),
          ),
          if (canEdit)
            FilledButton.icon(
              onPressed: (busy || selection.isEmpty) ? null : onPrononcer,
              icon: busy
                  ? const SizedBox(
                      width: 15, height: 15,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.person_off_outlined, size: 17),
              label: Text(selection.isEmpty
                  ? 'Prononcer le non-retour'
                  : 'Prononcer (${selection.length})'),
              style: FilledButton.styleFrom(backgroundColor: kRed),
            ),
        ]),
      ),
      const SizedBox(height: 14),
      if (canEdit)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onToggleAll,
            icon: Icon(
                selection.length == bilan.eleves.length
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                size: 18),
            label: Text(selection.length == bilan.eleves.length
                ? 'Tout décocher'
                : 'Tout sélectionner'),
          ),
        ),
      for (final e in bilan.eleves)
        _LigneEleve(
          eleve: e,
          selected: selection.contains(e.enrollmentId),
          canEdit: canEdit,
          onToggle: () => onToggle(e.enrollmentId),
        ),
    ]);
  }
}

class _LigneEleve extends StatelessWidget {
  const _LigneEleve({
    required this.eleve,
    required this.selected,
    required this.canEdit,
    required this.onToggle,
  });

  final EleveNonRevenu eleve;
  final bool selected, canEdit;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
              color: selected ? kRed.withValues(alpha: 0.5) : kBorder),
        ),
        child: InkWell(
          onTap: canEdit ? onToggle : null,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              if (canEdit)
                Icon(
                    selected
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    size: 20,
                    color: selected ? kRed : kTextMuted),
              if (canEdit) const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(eleve.fullName,
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        // L'INE est ce qui permettra de le retrouver s'il
                        // réapparaît ailleurs : il vaut mieux qu'il soit lu ici.
                        eleve.ine == null
                            ? (eleve.matricule ?? '—')
                            : formatIne(eleve.ine),
                        style: TextStyle(fontSize: 11, color: kTextMuted),
                      ),
                    ]),
              ),
              Expanded(
                flex: 2,
                child: Text(eleve.className,
                    style: const TextStyle(fontSize: 12.5)),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  eleve.targetClassName == null
                      ? eleve.decisionLabel
                      : '${eleve.decisionLabel} → ${eleve.targetClassName}',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: eleve.decision == 'passe' ? kRed : kTextMuted,
                      fontWeight: eleve.decision == 'passe'
                          ? FontWeight.w600
                          : FontWeight.w400),
                ),
              ),
              SizedBox(
                width: 130,
                child: eleve.tutorPhone == null
                    ? Text('Pas de contact',
                        style: TextStyle(fontSize: 11.5, color: kTextMuted))
                    : Row(children: [
                        Icon(Icons.phone_outlined, size: 13, color: kTextMuted),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(eleve.tutorPhone!,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11.5)),
                        ),
                      ]),
              ),
            ]),
          ),
        ),
      );
}
