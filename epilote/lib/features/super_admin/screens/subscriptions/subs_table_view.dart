import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/licence_statut.dart';
import '../../../../core/widgets/admin_ui.dart';
import '../../providers/comptes_admin_provider.dart';
import '../../providers/subscriptions_provider.dart';
import 'subs_badges.dart';
import 'subs_style.dart';

// ─── Vue tableau ─────────────────────────────────────────────────────
//  La ligne porte DEUX corrections vues à l'écran le 2026-09-04 : l'adresse
//  affichée est le compte de connexion (pas l'e-mail de contact), et la
//  colonne « contrat » montre le marché d'un ministère, pas le tarif à 0 F de
//  son plan support.

class SubTableView extends StatelessWidget {
  const SubTableView({
    super.key,
    required this.subs,
    required this.onView,
    required this.onEdit,
    required this.onLicence,
  });

  final List<SubscriptionDetail> subs;
  final ValueChanged<SubscriptionDetail> onView, onEdit, onLicence;

  static const _iconW    = 48.0;
  static const _statusW  = 100.0;
  static const _actionsW = 76.0;

  static Widget _hdr(String label, int flex, {bool center = false}) => Expanded(
    flex: flex,
    child: Align(
      alignment: center ? Alignment.center : Alignment.centerLeft,
      child: Text(label, style: TextStyle(
          color: kSubMuted, fontSize: 11,
          fontWeight: FontWeight.w700, letterSpacing: 0.4),
          overflow: TextOverflow.ellipsis),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (subs.isEmpty) return const SubEmptyState();

    return Container(
      decoration: BoxDecoration(
        color: kSubBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kSubBorder),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(children: [
          Container(
            height: 38,
            color: kSubSurface,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              const SizedBox(width: _iconW),
              _hdr('Groupe scolaire', 3),
              _hdr('Plan',            2),
              _hdr('Type',            2),
              _hdr('Échéance',        3),
              _hdr('Écoles',          1),
              SizedBox(width: _statusW,
                child: Text('Statut', style: TextStyle(
                    color: kSubMuted, fontSize: 11,
                    fontWeight: FontWeight.w700, letterSpacing: 0.4))),
              SizedBox(width: _actionsW,
                child: Center(child: Text('Actions', style: TextStyle(
                    color: kSubMuted, fontSize: 11,
                    fontWeight: FontWeight.w700, letterSpacing: 0.4)))),
            ]),
          ),
          Divider(height: 1, color: kSubBorder),
          ...subs.asMap().entries.map((e) => _TableRow(
            sub:      e.value,
            isOdd:    e.key.isOdd,
            iconW:    _iconW,
            statusW:  _statusW,
            actionsW: _actionsW,
            onView:    () => onView(e.value),
            onEdit:    () => onEdit(e.value),
            onLicence: () => onLicence(e.value),
          )),
        ]),
      ),
    );
  }
}

class _TableRow extends ConsumerStatefulWidget {
  const _TableRow({
    required this.sub,
    required this.isOdd,
    required this.iconW,
    required this.statusW,
    required this.actionsW,
    required this.onView,
    required this.onEdit,
    required this.onLicence,
  });
  final SubscriptionDetail sub;
  final bool         isOdd;
  final double       iconW, statusW, actionsW;
  final VoidCallback onView, onEdit, onLicence;

  @override
  ConsumerState<_TableRow> createState() => _TableRowState();
}

class _TableRowState extends ConsumerState<_TableRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.sub;
    final compteAdmin = ref.watch(comptesAdminParGroupeProvider).maybeWhen(
          data: (m) => compteDeConnexion(m, s.id),
          orElse: () => null,
        );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: _hovered
              ? kSubNavy.withValues(alpha: 0.04)
              : widget.isOdd
                  ? kSubSurface.withValues(alpha: 0.5)
                  : kSubBg,
          border: Border(
            bottom: BorderSide(color: kSubBorder.withValues(alpha: 0.6)),
          ),
        ),
        child: Row(children: [
          SizedBox(width: widget.iconW, child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: widget.onView,
              child: SubGroupGlyph(sub: s, size: 38),
            ),
          )),
          Expanded(flex: 3, child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: widget.onView,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(s.groupName,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kSubText),
                      overflow: TextOverflow.ellipsis),
                  // ⚠️ CE QU'ON LIT ICI, C'EST UN IDENTIFIANT.
                  // C'était `admin_email`, une colonne de CONTACT saisie dans
                  // le formulaire du groupe — jamais un compte. Le fondateur
                  // a lu cette ligne pour ouvrir l'espace d'un client, et la
                  // connexion a échoué : sur les huit administrateurs de la
                  // base, AUCUNE des deux adresses ne coïncidait. C'est
                  // pourtant cet écran qu'on ouvre quand un client appelle
                  // parce qu'il n'arrive pas à se connecter.
                  Text(compteAdmin ?? s.adminEmail,
                      style: TextStyle(fontSize: 10.5, color: kSubMuted),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          )),
          // ⚠️ Un ministère affichait « Licence de tutelle · Gratuit » — soit
          // l'inverse exact de la vérité : quarante millions. Et sa licence
          // n'était visible que dans Économie, un autre écran. Ici, la ligne
          // porte l'état RÉEL du contrat.
          Expanded(flex: 2, child: _ColonneContrat(sub: s)),
          Expanded(flex: 2, child: SubTypeBadge(type: s.groupType)),
          Expanded(flex: 3, child: Row(children: [
            Icon(Icons.schedule_rounded, size: 13,
                color: s.isOverdue ? kSubRed : (s.isExpiringSoon ? kSubOrange : kSubMuted)),
            const SizedBox(width: 4),
            Flexible(child: Text(s.remainingLabel,
                style: TextStyle(fontSize: 11.5,
                    color: s.isOverdue ? kSubRed : (s.isExpiringSoon ? kSubOrange : kSubText),
                    fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis)),
          ])),
          Expanded(flex: 1, child: Row(children: [
            Icon(Icons.school_rounded, size: 13, color: kSubNavy),
            const SizedBox(width: 4),
            Text('${s.schoolsCount}',
                style: TextStyle(fontSize: 12.5, color: kSubText,
                    fontWeight: FontWeight.w600)),
          ])),
          SizedBox(
            width: widget.statusW,
            child: Align(
              alignment: Alignment.centerLeft,
              child: SubStatusBadge(status: s.status),
            ),
          ),
          SizedBox(
            width: widget.actionsW,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _ActionBtn(icon: Icons.visibility_rounded, color: kSubBlue, tooltip: 'Voir la fiche', onTap: widget.onView),
              const SizedBox(width: 4),
              if (s.estMinistere)
                _ActionBtn(
                    icon: Icons.gavel_rounded,
                    color: kSubPurple,
                    tooltip: s.licence == null
                        ? 'Créer la licence'
                        : 'Gérer la licence',
                    onTap: widget.onLicence)
              else
                _ActionBtn(icon: Icons.edit_rounded, color: kSubNavy, tooltip: 'Modifier', onTap: widget.onEdit),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Ce que le groupe porte VRAIMENT : un plan mensuel, ou une licence.
///
/// ⚠️ Un ministère affichait « Licence de tutelle » avec le tarif du plan —
/// c'est-à-dire « Gratuit », soit l'inverse exact de la vérité : quarante
/// millions. Le montant du plan support ne veut rien dire pour lui ; celui de
/// son marché, si.
class _ColonneContrat extends StatelessWidget {
  const _ColonneContrat({required this.sub});

  final SubscriptionDetail sub;

  @override
  Widget build(BuildContext context) {
    if (!sub.estMinistere) {
      return Text(sub.planName ?? '—',
          style: TextStyle(
              fontSize: 12.5,
              color: sub.planName == null ? kSubMuted : kSubText,
              fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis);
    }
    final l = sub.licence;
    // Sans licence, la ligne le DIT en ambre : un ministère sans marché saisi
    // est une facturation qui n'existe pas, pas un détail de présentation.
    if (l == null) {
      return const Row(children: [
        Icon(Icons.gavel_rounded, size: 13, color: kSubOrange),
        SizedBox(width: 5),
        Flexible(
          child: Text('Aucune licence',
              style: TextStyle(
                  fontSize: 12.5, color: kSubOrange, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis),
        ),
      ]);
    }
    final couleur = couleurStatutLicence(l.statut);
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('${subMoney(l.montantXaf)} F',
              style: TextStyle(
                  fontSize: 12.5,
                  color: kSubText,
                  fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis),
          Row(children: [
            Container(
              width: 6,
              height: 6,
              decoration:
                  BoxDecoration(color: couleur, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                  'Licence ${libelleStatutLicenceOuTiret(l.statut).toLowerCase()}',
                  style: TextStyle(fontSize: 10.5, color: couleur),
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
        ]);
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final Color    color;
  final String   tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.20)),
          ),
          child: Icon(icon, size: 13, color: color),
        ),
      ),
    ),
  );
}
