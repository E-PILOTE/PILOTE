import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'subs_style.dart';

// ─── Briques d'affichage de la fiche ─────────────────────────────────
//  Cartes, lignes libellé/valeur (copiables), puces et titres. Utilisées par
//  la fiche ET par ses trois onglets.

class SubModalIconBtn extends StatelessWidget {
  const SubModalIconBtn({
    super.key,
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: kSubSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kSubBorder),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    ),
  );
}

class SubDetailCard extends StatelessWidget {
  const SubDetailCard(this.rows, {super.key});
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      border: Border.all(color: kSubBorder),
      borderRadius: BorderRadius.circular(8),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(children: rows),
  );
}

class SubDetailRow extends StatelessWidget {
  const SubDetailRow(this.icon, this.label, this.value,
      {super.key, this.last = false, this.copyable = false, this.mono = false});
  final IconData icon;
  final String label, value;
  final bool last, copyable, mono;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    decoration: BoxDecoration(
      border: last ? null : Border(bottom: BorderSide(color: kSubBorder)),
    ),
    child: Row(children: [
      Icon(icon, size: 15, color: kSubNavy),
      const SizedBox(width: 10),
      Text(label, style: TextStyle(
          color: kSubMuted, fontSize: 12, fontWeight: FontWeight.w600)),
      const Spacer(),
      Flexible(child: Text(value, style: TextStyle(
          color: kSubText, fontSize: mono ? 11.5 : 13,
          fontWeight: FontWeight.w600,
          fontFamily: mono ? 'monospace' : null),
          textAlign: TextAlign.right,
          overflow: TextOverflow.ellipsis)),
      if (copyable) ...[
        const SizedBox(width: 8),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Tooltip(
            message: 'Copier',
            child: InkWell(
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: value));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Copié : $value'),
                    backgroundColor: kSubNavy,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ));
                }
              },
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(Icons.copy_rounded, size: 13, color: kSubNavy),
              ),
            ),
          ),
        ),
      ],
    ]),
  );
}

class SubMetaChip extends StatelessWidget {
  const SubMetaChip({super.key, required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 6),
      Flexible(child: Text(label, style: TextStyle(
          color: color, fontSize: 11.5, fontWeight: FontWeight.w700),
          overflow: TextOverflow.ellipsis)),
    ]),
  );
}

class SubDetailSectionTitle extends StatelessWidget {
  const SubDetailSectionTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: TextStyle(
      color: kSubNavy, fontSize: 13, fontWeight: FontWeight.w800));
}
