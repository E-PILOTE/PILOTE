import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../user/widgets/staff_account_widgets.dart' show staffFmtDateTime;
import '../providers/mon_code_pin_provider.dart';
import '../providers/mon_profil_provider.dart';
import 'changer_code_pin_dialog.dart';
import 'ligne_securite.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LE CODE PIN DANS « MON PROFIL »
//
//  Le code s'obtenait à l'enrôlement, sur l'écran-verrou, et ne se changeait
//  plus jamais. Or c'est le secret le plus exposé du produit : quatre chiffres,
//  composés devant un guichet, sur un poste que trois personnes se partagent.
//  Le mot de passe, lui, avait sa carte depuis toujours — alors qu'il se tape
//  une fois par mois, seul devant sa machine.
//
//  L'écran dit trois choses, dans cet ordre, parce qu'aucune n'est devinable :
//    1. à quoi sert ce code (ouvrir sa session au clavier, sans internet) ;
//    2. qu'il ne vaut que sur CE poste ;
//    3. quand il a été posé ici — la seule date vraie dont on dispose.
//
//  ── L'ÉTAT « À REPOSER » N'EST PAS UNE ERREUR ─────────────────────────────
//  Quand un administrateur de groupe a demandé une réinitialisation, le code
//  local ne vaut plus rien mais reste stocké : l'agent le composerait sans
//  comprendre pourquoi on le refuse. La carte l'annonce ici, avant l'écran-
//  verrou, au moment calme — pas devant une file d'attente de parents.
// ════════════════════════════════════════════════════════════════════════════

class ProfilCodePin extends ConsumerWidget {
  const ProfilCodePin({super.key, required this.moi});
  final MonProfil moi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cible = (id: moi.profil.id, role: moi.profil.role);
    final etat = ref.watch(etatCodePinProvider(cible)).valueOrNull;

    // Tant que la lecture des préférences n'a pas répondu, on n'affiche rien :
    // une carte qui apparaît en « aucun code » puis se corrige en « posé le… »
    // ferait douter d'un code qui existe.
    if (etat == null || !etat.sApplique) return const SizedBox.shrink();

    final aPoser = etat.aPoser;

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: AdminCard(
        child: Column(children: [
          LigneSecurite(
            icone: Icons.pin_outlined,
            titre: 'Code de ce poste',
            detail: _detail(etat),
            action: BoutonSecurite(
              icone: aPoser ? Icons.add_rounded : Icons.password_rounded,
              libelle: aPoser ? 'Poser' : 'Changer',
              onPressed: () => _ouvrir(context, ref, cible, aPoser),
            ),
          ),
          if (etat.resetDemande) ...[
            const SizedBox(height: 12),
            const _Bandeau(
              texte: 'Un administrateur a demandé la réinitialisation de votre '
                  'code : l\'ancien ne fonctionne plus. Posez-en un nouveau.',
            ),
          ],
        ]),
      ),
    );
  }

  String _detail(EtatCodePin etat) {
    if (etat.aPoser) {
      return 'Quatre chiffres pour ouvrir votre session au clavier sur cet '
          'ordinateur, sans internet. Aucun code n\'est encore posé ici.';
    }
    final quand = etat.poseLe == null ? null : staffFmtDateTime(etat.poseLe);
    return 'Ouvre votre session au clavier sur CET ordinateur, sans internet. '
        'Il ne change pas sur les autres postes de l\'école.'
        '${quand == null ? '' : '\nPosé ici le $quand.'}';
  }

  Future<void> _ouvrir(
    BuildContext context,
    WidgetRef ref,
    ({String id, String role}) cible,
    bool aPoser,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) =>
          ChangerCodePinDialog(profilId: cible.id, aPoser: aPoser),
    );
    ref.invalidate(etatCodePinProvider(cible));
    if (ok != true || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: kGreen,
      content: Text(aPoser
          ? 'Code posé sur ce poste.'
          : 'Code changé sur ce poste. Les autres ordinateurs gardent '
              'l\'ancien.'),
    ));
  }
}

class _Bandeau extends StatelessWidget {
  const _Bandeau({required this.texte});
  final String texte;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: kAccent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kAccent.withValues(alpha: 0.35)),
        ),
        child: Row(children: [
          Icon(Icons.info_outline_rounded, size: 16, color: kAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(texte,
                style: TextStyle(
                    fontSize: 12.5, color: kTextPrimary, height: 1.35)),
          ),
        ]),
      );
}
