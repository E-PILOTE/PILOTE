import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/message_erreur.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/list_chrome.dart';
import '../providers/circulaires_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LES CIRCULAIRES REÇUES
//
//  Ce qu'une tutelle a adressé aux établissements de CE groupe, et l'accusé
//  de lecture de chacun d'eux.
//
//  ⚠️ L'ACCUSÉ SE DONNE PAR ÉCOLE, PAS PAR GROUPE. Un groupe de trois écoles
//  qui accuserait « pour tout le monde » d'un seul clic produirait une preuve
//  fausse : rien ne dit que les trois chefs d'établissement ont lu. La liste
//  nomme donc chaque école et son état.
//
//  ⚠️ La date du premier accusé ne se réécrit jamais (RPC `circulaire_accuser`).
//  Rappuyer sur le bouton ne repousse pas la preuve dans le temps.
// ════════════════════════════════════════════════════════════════════════════

class CirculairesRecuesScreen extends ConsumerWidget {
  const CirculairesRecuesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => const AppShell(
        title: 'Circulaires de la tutelle',
        child: _Corps(),
      );
}

class _Corps extends ConsumerWidget {
  const _Corps();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(circulairesRecuesProvider);
    return async.when(
      skipLoadingOnRefresh: true,
      loading: () => const ListShimmer(),
      // Pas de repli sur liste vide : « aucune circulaire » à cause d'une
      // panne réseau se lirait comme « la tutelle ne m'a rien envoyé », et
      // c'est exactement le message qu'il ne faut pas donner par erreur.
      error: (e, _) => _Erreur(
        message: messageErreur(e, contexte: 'Circulaires'),
        onRetry: () => ref.invalidate(circulairesRecuesProvider),
      ),
      data: (list) {
        if (list.isEmpty) return const _Vide();
        final aRepondre = list
            .where((c) => c.accuseRequis && !c.toutesLues)
            .length;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (aRepondre > 0) _BandeauEnAttente(nombre: aRepondre),
              const SizedBox(height: 4),
              for (final c in list) ...[
                _CarteRecue(circulaire: c),
                const SizedBox(height: 12),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _BandeauEnAttente extends StatelessWidget {
  const _BandeauEnAttente({required this.nombre});
  final int nombre;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFF6B35).withValues(alpha: .08),
          border: Border.all(color: const Color(0xFFFF6B35).withValues(alpha: .35)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          const Icon(Icons.mark_email_unread_rounded,
              size: 18, color: Color(0xFFFF6B35)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$nombre circulaire${nombre > 1 ? 's' : ''} '
              '${nombre > 1 ? 'attendent' : 'attend'} encore un accusé de '
              'lecture pour une ou plusieurs de vos écoles.',
              style: const TextStyle(fontSize: 12.5, height: 1.4),
            ),
          ),
        ]),
      );
}

class _CarteRecue extends ConsumerStatefulWidget {
  const _CarteRecue({required this.circulaire});
  final Circulaire circulaire;

  @override
  ConsumerState<_CarteRecue> createState() => _CarteRecueState();
}

class _CarteRecueState extends ConsumerState<_CarteRecue> {
  bool _ouvert = false;
  String? _enCours;

  Future<void> _accuser(CirculaireEcole ecole) async {
    setState(() => _enCours = ecole.schoolId);
    try {
      final res = await accuserCirculaire(
          ref, widget.circulaire.id, ecole.schoolId);
      if (!mounted) return;
      ref.invalidate(circulairesRecuesProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['deja_lu'] == true
            ? 'Cette école avait déjà accusé réception.'
            : 'Accusé de lecture enregistré pour ${ecole.nom}.'),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(messageErreur(e, contexte: 'Accusé de lecture')),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _enCours = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.circulaire;
    final couleur = _couleurPriorite(c.priorite);
    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        border: Border.all(
            color: c.accuseRequis && !c.toutesLues
                ? couleur.withValues(alpha: .45)
                : kBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: () => setState(() => _ouvert = !_ouvert),
          borderRadius: BorderRadius.circular(12),
          mouseCursor: SystemMouseCursors.click,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: couleur.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(Icons.description_rounded, size: 17, color: couleur),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        if (c.priorite != CirculairePriorite.normale)
                          _Etiquette(
                              texte: prioriteLabel(c.priorite).toUpperCase(),
                              couleur: couleur),
                        if (c.reference != null) ...[
                          if (c.priorite != CirculairePriorite.normale)
                            const SizedBox(width: 6),
                          _Etiquette(texte: c.reference!, couleur: kTextMuted),
                        ],
                      ]),
                      if (c.priorite != CirculairePriorite.normale ||
                          c.reference != null)
                        const SizedBox(height: 6),
                      Text(c.objet,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                        '${c.emetteurNom ?? 'Tutelle'} · '
                        '${_date(c.publieeLe)}'
                        '${c.echeance != null ? ' · échéance ${_date(c.echeance)}' : ''}',
                        style: TextStyle(fontSize: 11.5, color: kTextMuted),
                      ),
                    ]),
              ),
              const SizedBox(width: 12),
              _EtatAccuse(circulaire: c),
              const SizedBox(width: 8),
              Icon(_ouvert ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  size: 20, color: kTextMuted),
            ]),
          ),
        ),
        if (_ouvert) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(c.corps,
                      style: const TextStyle(fontSize: 13, height: 1.55)),
                  const SizedBox(height: 18),
                  Text('ACCUSÉ DE LECTURE, ÉTABLISSEMENT PAR ÉTABLISSEMENT',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .6,
                          color: kTextMuted)),
                  const SizedBox(height: 10),
                  for (final e in c.mesEcoles)
                    _LigneEcole(
                      ecole: e,
                      accuseRequis: c.accuseRequis,
                      enCours: _enCours == e.schoolId,
                      onAccuser: () => _accuser(e),
                    ),
                ]),
          ),
        ],
      ]),
    );
  }
}

class _LigneEcole extends StatelessWidget {
  const _LigneEcole({
    required this.ecole,
    required this.accuseRequis,
    required this.enCours,
    required this.onAccuser,
  });

  final CirculaireEcole ecole;
  final bool accuseRequis, enCours;
  final VoidCallback onAccuser;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Icon(
            ecole.lue
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 16,
            color: ecole.lue ? kGreen : kTextMuted,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(ecole.nom, style: const TextStyle(fontSize: 12.5))),
          if (ecole.lue)
            Text('Lu le ${_dateHeure(ecole.luLe)}',
                style: TextStyle(fontSize: 11, color: kGreen))
          else if (!accuseRequis)
            Text('Aucun accusé demandé',
                style: TextStyle(fontSize: 11, color: kTextMuted))
          else if (enCours)
            const SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(strokeWidth: 2))
          else
            TextButton(
              onPressed: onAccuser,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Accuser réception',
                  style: TextStyle(fontSize: 11.5)),
            ),
        ]),
      );
}

class _EtatAccuse extends StatelessWidget {
  const _EtatAccuse({required this.circulaire});
  final Circulaire circulaire;

  @override
  Widget build(BuildContext context) {
    final c = circulaire;
    if (!c.accuseRequis) {
      return Text('Pour information',
          style: TextStyle(fontSize: 11, color: kTextMuted));
    }
    final total = c.mesEcoles.length;
    final lues = c.nbMesEcolesLues;
    final complet = total > 0 && lues == total;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: (complet ? kGreen : const Color(0xFFFF6B35)).withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('$lues / $total lu${lues > 1 ? 's' : ''}',
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: complet ? kGreen : const Color(0xFFFF6B35))),
    );
  }
}

class _Etiquette extends StatelessWidget {
  const _Etiquette({required this.texte, required this.couleur});
  final String texte;
  final Color couleur;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: couleur.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(texte,
            style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: .4,
                color: couleur)),
      );
}

class _Vide extends StatelessWidget {
  const _Vide();
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.mark_email_read_rounded, size: 40, color: kTextMuted),
            const SizedBox(height: 14),
            const Text('Aucune circulaire',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'Votre tutelle ne vous a encore rien adressé. Cette page vous '
              'préviendra dès qu\'une circulaire arrivera.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: kTextMuted, height: 1.5),
            ),
          ]),
        ),
      );
}

class _Erreur extends StatelessWidget {
  const _Erreur({required this.message, required this.onRetry});
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

Color _couleurPriorite(CirculairePriorite p) => switch (p) {
      CirculairePriorite.urgente => const Color(0xFFEF4444),
      CirculairePriorite.importante => const Color(0xFFFF6B35),
      CirculairePriorite.normale => kNavy,
    };

String _date(DateTime? d) => d == null
    ? '—'
    : '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';

String _dateHeure(DateTime? d) => d == null
    ? '—'
    : '${_date(d)} à ${d.hour.toString().padLeft(2, '0')}h'
        '${d.minute.toString().padLeft(2, '0')}';
