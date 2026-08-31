import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/message_erreur.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/list_chrome.dart';
import '../../admin_groupe/providers/referentiel_national_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../tutelle/providers/tutelle_filtres.dart';
import '../../tutelle/providers/tutelle_reseau_provider.dart';
import '../providers/circulaires_provider.dart';

part 'circulaire_form_dialog.dart';

// ════════════════════════════════════════════════════════════════════════════
//  ÉMETTRE UNE CIRCULAIRE
//
//  Le pendant écrit de « Réseau sous tutelle » : après avoir compté son
//  réseau, un ministère doit pouvoir lui écrire.
//
//  ── LA COLONNE QUI COMPTE ─────────────────────────────────────────────────
//  Le taux de lecture. Une circulaire dont on ne peut pas prouver la réception
//  n'a aucune valeur administrative ; tout le reste de cet écran n'est que la
//  mise en forme de cette colonne.
//
//  ── DEUX TEMPS, DÉLIBÉRÉMENT ──────────────────────────────────────────────
//  On RÉDIGE (brouillon), puis on PUBLIE. La publication fige la liste des
//  destinataires et ne se refait pas. Un bouton unique « envoyer » aurait
//  rendu irréversible un geste qu'on fait souvent trop vite.
//
//  ⚠️ La publication AFFICHE le nombre d'établissements touchés. « Publiée »
//  tout court laisserait le rédacteur sans moyen de vérifier que son ciblage
//  désignait bien qui il croyait — et un ciblage trop étroit ne se voit pas.
// ════════════════════════════════════════════════════════════════════════════

class CirculairesEmisesScreen extends ConsumerWidget {
  const CirculairesEmisesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => const AppShell(
        title: 'Circulaires de tutelle',
        child: _Corps(),
      );
}

class _Corps extends ConsumerWidget {
  const _Corps();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peut =
        ref.watch(groupeAdministreReferentielProvider).valueOrNull ?? false;
    if (!peut) return const _PasDeTutelle();

    final async = ref.watch(circulairesEmisesProvider);
    return async.when(
      skipLoadingOnRefresh: true,
      loading: () => const ListShimmer(),
      error: (e, _) => _ErreurBloc(
        message: messageErreur(e, contexte: 'Circulaires'),
        onRetry: () => ref.invalidate(circulairesEmisesProvider),
      ),
      data: (list) {
        final publiees = list.where((c) => c.publiee).toList();
        final brouillons = list.where((c) => !c.publiee).toList();
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _EnTete(
                nbPubliees: publiees.length,
                nbBrouillons: brouillons.length,
                onNouvelle: () => _ouvrirForm(context, ref),
              ),
              const SizedBox(height: 20),
              if (list.isEmpty)
                const _Vide()
              else ...[
                if (brouillons.isNotEmpty) ...[
                  const _Titre('BROUILLONS — rien n\'est parti'),
                  const SizedBox(height: 10),
                  for (final c in brouillons) ...[
                    _CarteEmise(circulaire: c),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 14),
                ],
                if (publiees.isNotEmpty) ...[
                  const _Titre('PUBLIÉES'),
                  const SizedBox(height: 10),
                  for (final c in publiees) ...[
                    _CarteEmise(circulaire: c),
                    const SizedBox(height: 10),
                  ],
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

Future<void> _ouvrirForm(BuildContext context, WidgetRef ref,
    {Circulaire? edition}) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _CirculaireFormDialog(edition: edition),
  );
  ref.invalidate(circulairesEmisesProvider);
}

class _EnTete extends StatelessWidget {
  const _EnTete({
    required this.nbPubliees,
    required this.nbBrouillons,
    required this.onNouvelle,
  });

  final int nbPubliees, nbBrouillons;
  final VoidCallback onNouvelle;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: kCardBg,
          border: Border.all(color: kBorder),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: kNavy.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(Icons.mark_as_unread_rounded, size: 20, color: kNavy),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Écrire aux établissements de votre réseau',
                      style: TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                    'Une circulaire est descendante et accusée. Elle s\'adresse '
                    'aux établissements — jamais aux élèves ni aux parents.',
                    style: TextStyle(
                        fontSize: 12, color: kTextMuted, height: 1.4),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$nbPubliees publiée${nbPubliees > 1 ? 's' : ''}'
                    '${nbBrouillons > 0 ? ' · $nbBrouillons brouillon${nbBrouillons > 1 ? 's' : ''}' : ''}',
                    style: TextStyle(fontSize: 11.5, color: kTextMuted),
                  ),
                ]),
          ),
          const SizedBox(width: 14),
          FilledButton.icon(
            onPressed: onNouvelle,
            icon: const Icon(Icons.add_rounded, size: 17),
            label: const Text('Nouvelle circulaire'),
          ),
        ]),
      );
}

class _CarteEmise extends ConsumerStatefulWidget {
  const _CarteEmise({required this.circulaire});
  final Circulaire circulaire;

  @override
  ConsumerState<_CarteEmise> createState() => _CarteEmiseState();
}

class _CarteEmiseState extends ConsumerState<_CarteEmise> {
  bool _busy = false;

  Future<void> _publier() async {
    final c = widget.circulaire;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Publier cette circulaire ?'),
        content: Text(
          'La liste des destinataires sera FIGÉE à cet instant et la '
          'circulaire ne pourra plus être modifiée ni republiée.\n\n'
          '« ${c.objet} »',
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Publier')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final res = await publierCirculaire(ref, c.id);
      if (!mounted) return;
      ref.invalidate(circulairesEmisesProvider);
      // Le nombre EST le compte rendu : sans lui, un ciblage trop étroit
      // passerait pour un envoi réussi.
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Circulaire publiée : ${res['etablissements']} '
            'établissement(s) dans ${res['groupes']} groupe(s).'),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(messageErreur(e, contexte: 'Publication')),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _supprimer() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce brouillon ?'),
        content: const Text('Il n\'a jamais été envoyé ; rien ne sera perdu '
            'côté destinataires.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444)),
              child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await supprimerBrouillon(ref, widget.circulaire.id);
      if (mounted) ref.invalidate(circulairesEmisesProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(messageErreur(e)),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.circulaire;
    final taux = c.tauxLecture;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (c.reference != null) ...[
                Text(c.reference!,
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: kTextMuted)),
                const SizedBox(width: 8),
              ],
              if (c.priorite != CirculairePriorite.normale)
                Text(prioriteLabel(c.priorite).toUpperCase(),
                    style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .4,
                        color: c.priorite == CirculairePriorite.urgente
                            ? const Color(0xFFEF4444)
                            : const Color(0xFFFF6B35))),
            ]),
            const SizedBox(height: 5),
            Text(c.objet,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              c.publiee
                  ? 'Publiée le ${_dateFr(c.publieeLe)} · ${_ciblage(c)}'
                  : 'Brouillon créé le ${_dateFr(c.createdAt)} · ${_ciblage(c)}',
              style: TextStyle(fontSize: 11.5, color: kTextMuted),
            ),
            if (c.publiee && !c.accuseRequis) ...[
              const SizedBox(height: 6),
              Text('Pour information — aucun accusé demandé',
                  style: TextStyle(fontSize: 11, color: kTextMuted)),
            ],
          ]),
        ),
        const SizedBox(width: 16),
        if (c.publiee)
          _TauxLecture(taux: taux, lus: c.nbLus, total: c.nbDestinataires)
        else if (_busy)
          const SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2))
        else
          Row(children: [
            IconButton(
              onPressed: () => _ouvrirForm(context, ref, edition: c),
              icon: const Icon(Icons.edit_rounded, size: 17),
              tooltip: 'Modifier',
            ),
            IconButton(
              onPressed: _supprimer,
              icon: const Icon(Icons.delete_outline_rounded, size: 17),
              tooltip: 'Supprimer',
            ),
            const SizedBox(width: 4),
            FilledButton.icon(
              onPressed: _publier,
              icon: const Icon(Icons.send_rounded, size: 15),
              label: const Text('Publier'),
            ),
          ]),
      ]),
    );
  }
}

class _TauxLecture extends StatelessWidget {
  const _TauxLecture({
    required this.taux,
    required this.lus,
    required this.total,
  });

  final double? taux;
  final int lus, total;

  @override
  Widget build(BuildContext context) {
    // ⚠️ `null` ≠ 0 %. Une circulaire sans destinataire n'a pas « 0 % de
    // lecture » : elle n'a rien à lire. Les deux se peignent différemment.
    if (taux == null) {
      return Text('Aucun destinataire',
          style: TextStyle(fontSize: 11.5, color: kTextMuted));
    }
    final couleur = taux! >= 80
        ? kGreen
        : taux! >= 40
            ? const Color(0xFFFF6B35)
            : const Color(0xFFEF4444);
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text('${taux!.round()} %',
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w800, color: couleur)),
      const SizedBox(height: 2),
      Text('$lus / $total lus',
          style: TextStyle(fontSize: 11, color: kTextMuted)),
      const SizedBox(height: 6),
      SizedBox(
        width: 90,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: taux! / 100,
            minHeight: 5,
            backgroundColor: kBorder,
            valueColor: AlwaysStoppedAnimation(couleur),
          ),
        ),
      ),
    ]);
  }
}

class _Titre extends StatelessWidget {
  const _Titre(this.texte);
  final String texte;

  @override
  Widget build(BuildContext context) => Text(texte,
      style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: .6,
          color: kTextMuted));
}

class _Vide extends StatelessWidget {
  const _Vide();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(children: [
          Icon(Icons.drafts_rounded, size: 38, color: kTextMuted),
          const SizedBox(height: 12),
          const Text('Aucune circulaire',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            'Rédigez la première : elle atteindra tous les établissements de '
            'votre tutelle, y compris ceux que vous n\'exploitez pas.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: kTextMuted, height: 1.5),
          ),
        ]),
      );
}

class _PasDeTutelle extends StatelessWidget {
  const _PasDeTutelle();
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.lock_outline_rounded, size: 36, color: kTextMuted),
            const SizedBox(height: 14),
            const Text('Réservé aux tutelles',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'Seul un ministère qui administre un référentiel national émet '
              'des circulaires vers son réseau.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: kTextMuted, height: 1.5),
            ),
          ]),
        ),
      );
}

class _ErreurBloc extends StatelessWidget {
  const _ErreurBloc({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_rounded, size: 36, color: Color(0xFFEF4444)),
            const SizedBox(height: 14),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, height: 1.5)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Réessayer'),
            ),
          ]),
        ),
      );
}

String _ciblage(Circulaire c) {
  final bouts = <String>[];
  if (c.cibleSecteur != null) {
    bouts.add(c.cibleSecteur == 'public' ? 'écoles publiques' : 'écoles privées');
  }
  if (c.cibleDepartement != null) bouts.add(c.cibleDepartement!);
  return bouts.isEmpty ? 'tout le réseau' : bouts.join(' · ');
}

String _dateFr(DateTime? d) => d == null
    ? '—'
    : '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
