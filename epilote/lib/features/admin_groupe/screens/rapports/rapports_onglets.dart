part of '../admin_reports_screen.dart';

// Onglets de section.

class _SectionTabs extends StatelessWidget {
  const _SectionTabs({required this.current, required this.onChanged});
  final _Section current;
  final ValueChanged<_Section> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _kSections.map((e) {
          final sel = e.$1 == current;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onChanged(e.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? kNavy : kCardBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: sel ? kNavy : kBorder),
                  boxShadow: sel
                      ? [
                          BoxShadow(
                              color: kNavy.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 2))
                        ]
                      : null,
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(e.$3,
                      size: 16, color: sel ? Colors.white : kTextMuted),
                  const SizedBox(width: 7),
                  Text(e.$2,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: sel ? Colors.white : kTextMuted,
                      )),
                ]),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  KPI (cartes animées génériques)
// ════════════════════════════════════════════════════════════════════════════
