import 'package:flutter/material.dart';

import 'admin_tokens.dart';
import 'admin_modal.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LES TROIS FORMES DE MODALE — même chrome (`admin_modal.dart`), géométries
//  différentes, choisies par ce qu'il y a à montrer :
//   • `AdminFormDialog`     — boîte centrée : une saisie, une fiche ;
//   • `showAdminSidePanel`  — panneau latéral : une saisie longue ;
//   • `showAdminBottomModal`— feuille montante : un tableau, une liste large ;
//   • `showAdminConfirm`    — question courte, dont les gestes destructifs.
//
//  Aucune ne redéfinit son en-tête ni son pied : un changement de style se fait
//  une fois, dans `admin_modal.dart`, et aucune modale ne peut dériver seule.
// ════════════════════════════════════════════════════════════════════════════

// ════════════════════════════════════════════════════════════════════════════
//  MODAL FORMULAIRE — fond kCardBg radius 18 + ombre, en-tête à icône en
//  dégradé, corps défilant, pied « Annuler » + bouton primaire pilule.
//  Réutilisable : à privilégier pour tout nouveau formulaire admin_groupe.
// ════════════════════════════════════════════════════════════════════════════
class AdminFormDialog extends StatelessWidget {
  const AdminFormDialog({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.subtitle,
    this.footer,
    this.accent,
    this.headerTrailing,
    this.hero,
    this.width = kModalWidth,
    this.maxHeight = 720,
    this.scrollable = true,
    this.bodyPadding = const EdgeInsets.fromLTRB(24, 20, 24, 20),
    this.saving = false,
    this.submitLabel,
    this.submitIcon,
    this.submitColor,
    this.onSubmit,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget body;
  final Widget? footer;

  /// Couleur de l'en-tête (défaut `kNavy`).
  final Color? accent;
  final Widget? headerTrailing;

  /// Bandeau fixe entre l'en-tête et le corps défilant — pour ce qui doit
  /// rester visible pendant qu'on parcourt la fiche (un rang, un total).
  final Widget? hero;

  final double width;
  final double maxHeight;
  final bool scrollable;
  final EdgeInsets bodyPadding;
  // Pied par défaut (si [footer] est null et [onSubmit] fourni).
  final bool saving;
  final String? submitLabel;
  final IconData? submitIcon;
  final Color? submitColor;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final body0 = scrollable
        ? SingleChildScrollView(padding: bodyPadding, child: body)
        : Padding(padding: bodyPadding, child: body);

    Widget? foot = footer;
    foot ??= (onSubmit == null)
        ? null
        : AdminModalActions(
            submitLabel: submitLabel ?? 'Enregistrer',
            submitIcon: submitIcon,
            submitColor: submitColor,
            saving: saving,
            onSubmit: onSubmit!,
          );

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
      child: Container(
        width: width,
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(kModalRadius),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 40,
                offset: const Offset(0, 10)),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AdminModalHeader(
            icon: icon,
            title: title,
            subtitle: subtitle,
            accent: accent,
            trailing: headerTrailing,
          ),
          ?hero,
          Flexible(child: body0),
          if (foot != null) AdminModalFooter(child: foot),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  PANNEAU LATÉRAL — même chrome, autre géométrie.
//
//  Pour les saisies longues : une dizaine de champs à l'étroit dans une boîte
//  centrée oblige à faire défiler un formulaire dont on ne voit jamais ni le
//  début ni la fin. Un panneau pleine hauteur les tient tous et laisse la page
//  visible derrière — on garde sous les yeux ce sur quoi on travaille.
// ════════════════════════════════════════════════════════════════════════════
Future<T?> showAdminSidePanel<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) =>
    showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: 'Fermer',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, _, _) => builder(ctx),
      transitionBuilder: (_, anim, _, child) => SlideTransition(
        position: Tween(begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );

/// Corps d'un panneau latéral — à passer au `builder` de [showAdminSidePanel].
class AdminSidePanel extends StatelessWidget {
  const AdminSidePanel({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.subtitle,
    this.footer,
    this.accent,
    this.width = kModalWidth,
    this.bodyPadding = const EdgeInsets.fromLTRB(22, 18, 22, 10),
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget body;
  final Widget? footer;
  final Color? accent;

  /// Bornée : au-delà, les champs s'étirent et le formulaire devient plus dur
  /// à parcourir qu'une colonne étroite.
  final double width;
  final EdgeInsets bodyPadding;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: kCardBg,
          child: SizedBox(
            width: width,
            height: double.infinity,
            child: Column(children: [
              // Angles droits : le panneau est collé au bord de l'écran.
              AdminModalHeader(
                icon: icon,
                title: title,
                subtitle: subtitle,
                accent: accent,
                topRadius: 0,
              ),
              Flexible(
                child: SingleChildScrollView(
                    padding: bodyPadding, child: body),
              ),
              if (footer != null)
                AdminModalFooter(bottomRadius: 0, child: footer!),
            ]),
          ),
        ),
      );
}

// ════════════════════════════════════════════════════════════════════════════
//  FEUILLE MONTANTE — même chrome, entrée par le bas.
//
//  Pour ce qui se LIT en largeur : un classement, un tableau, une liste longue.
//  Une boîte centrée de 560 px y couperait les colonnes ; un panneau latéral
//  les empilerait. La feuille prend la largeur de la page et presque toute sa
//  hauteur, en laissant voir d'où elle sort — le geste mobile, sur desktop.
// ════════════════════════════════════════════════════════════════════════════
Future<T?> showAdminBottomModal<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) =>
    showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: 'Fermer',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (ctx, _, _) => builder(ctx),
      transitionBuilder: (_, anim, _, child) => SlideTransition(
        position: Tween(begin: const Offset(0, 1), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );

/// Corps d'une feuille montante — à passer au `builder` de
/// [showAdminBottomModal].
class AdminBottomModal extends StatelessWidget {
  const AdminBottomModal({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.subtitle,
    this.footer,
    this.accent,
    this.headerTrailing,
    this.hero,
    this.maxWidth = 1040,
    this.heightFactor = 0.88,
    this.bodyPadding = const EdgeInsets.fromLTRB(22, 18, 22, 22),
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget body;
  final Widget? footer;
  final Color? accent;
  final Widget? headerTrailing;

  /// Bandeau fixe sous l'en-tête (voir `AdminFormDialog.hero`).
  final Widget? hero;
  final double maxWidth;
  final double heightFactor;
  final EdgeInsets bodyPadding;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: size.width > maxWidth + 48 ? 24 : 12),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: maxWidth,
            height: size.height * heightFactor,
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(22)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 46,
                    offset: const Offset(0, -8)),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              // Poignée : dit d'un coup d'œil que la feuille se referme vers
              // le bas — le seul repère que ce n'est pas une page.
              Padding(
                padding: const EdgeInsets.only(top: 9, bottom: 2),
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: kTextMuted.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              AdminModalHeader(
                icon: icon,
                title: title,
                subtitle: subtitle,
                accent: accent,
                trailing: headerTrailing,
                topRadius: 0,
              ),
              ?hero,
              Flexible(
                child: SingleChildScrollView(
                    padding: bodyPadding, child: body),
              ),
              if (footer != null)
                AdminModalFooter(bottomRadius: 0, child: footer!),
            ]),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  CONFIRMATION — un geste qu'on ne rattrape pas mérite le même soin qu'une
//  saisie. Renvoie `true` seulement si l'utilisateur a validé.
// ════════════════════════════════════════════════════════════════════════════
Future<bool> showAdminConfirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmer',
  String cancelLabel = 'Annuler',
  IconData? icon,
  IconData? confirmIcon,

  /// Geste destructif : chrome rouge et message encadré. À réserver à ce qui
  /// ne se retrouve pas — une suppression, un retrait d'archive.
  bool danger = false,
}) async {
  final color = danger ? kRed : kNavy;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AdminFormDialog(
      icon: icon ??
          (danger ? Icons.warning_amber_rounded : Icons.help_outline_rounded),
      title: title,
      accent: color,
      width: 460,
      bodyPadding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      body: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: color.withValues(alpha: danger ? 0.07 : 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Text(message,
            style:
                TextStyle(fontSize: 13, color: kTextPrimary, height: 1.5)),
      ),
      footer: AdminModalActions(
        cancelLabel: cancelLabel,
        onCancel: () => Navigator.of(ctx).pop(false),
        submitLabel: confirmLabel,
        submitIcon: confirmIcon ?? (danger ? Icons.delete_outline_rounded : null),
        submitColor: color,
        onSubmit: () => Navigator.of(ctx).pop(true),
      ),
    ),
  );
  return ok ?? false;
}
