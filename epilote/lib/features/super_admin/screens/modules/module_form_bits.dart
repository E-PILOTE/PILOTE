part of '../modules_screen.dart';

// Sélecteur d’emoji, en-tête, pied et bascule d’activation.

class _EmojiPickerRow extends StatelessWidget {
  const _EmojiPickerRow({required this.selected, required this.onSelect});
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(child: Container(
        width: 72, height: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _kNavy.withValues(alpha: 0.3), width: 2),
        ),
        child: Text(selected, style: const TextStyle(fontSize: 36)),
      )),
      const SizedBox(height: 12),
      Text('Icône', style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w700,
          color: _kMuted, letterSpacing: 0.5)),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kBorder),
        ),
        child: Wrap(spacing: 6, runSpacing: 6,
          children: _emojiSuggestions.map((e) {
            final sel = e == selected;
            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => onSelect(e),
                child: Container(
                  width: 34, height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: sel ? _kNavy.withValues(alpha: 0.12) : _kBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: sel ? _kNavy : _kBorder,
                        width: sel ? 1.5 : 1),
                  ),
                  child: Text(e, style: const TextStyle(fontSize: 18)),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    ]);
  }
}

// ─── En-tête / pied de formulaire partagés ────────────────────────────────────

class _FormHeader extends StatelessWidget {
  const _FormHeader({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title, subtitle;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(22, 16, 16, 16),
    decoration: BoxDecoration(
      color: kCardBg,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      border: Border(bottom: BorderSide(color: _kBorder)),
    ),
    child: Row(children: [
      Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [const Color(0xFF1A2F5A), _kNavy]),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [BoxShadow(color: _kNavy.withValues(alpha: 0.25),
              blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(
            color: _kText, fontSize: 15, fontWeight: FontWeight.w800)),
        Text(subtitle, style: TextStyle(color: _kMuted, fontSize: 11)),
      ]),
      const Spacer(),
      Builder(builder: (context) => InkWell(
        onTap: () => Navigator.pop(context),
        borderRadius: BorderRadius.circular(8),
        mouseCursor: SystemMouseCursors.click,
        child: Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kBorder),
          ),
          child: Icon(Icons.close_rounded, size: 15, color: _kMuted),
        ),
      )),
    ]),
  );
}

class _FormFooter extends StatelessWidget {
  const _FormFooter({required this.saving, required this.saveLabel, required this.onSave});
  final bool saving;
  final String saveLabel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
    decoration: BoxDecoration(
      color: _kSurface,
      border: Border(top: BorderSide(color: _kBorder)),
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
    ),
    child: Row(children: [
      MouseRegion(
        cursor: SystemMouseCursors.click,
        child: InkWell(
          onTap: () => Navigator.pop(context),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: _kBorder),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('Annuler', style: TextStyle(
                color: _kMuted, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ),
      ),
      const Spacer(),
      MouseRegion(
        cursor: saving ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
        child: InkWell(
          onTap: saving ? null : onSave,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: saving ? _kNavy.withValues(alpha: 0.5) : _kNavy,
              borderRadius: BorderRadius.circular(8),
              boxShadow: saving ? [] : [BoxShadow(
                color: _kNavy.withValues(alpha: 0.30),
                blurRadius: 8, offset: const Offset(0, 3),
              )],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (saving)
                const SizedBox(width: 13, height: 13,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              else
                const Icon(Icons.save_rounded, color: Colors.white, size: 15),
              const SizedBox(width: 8),
              Text(saving ? 'Enregistrement…' : saveLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      ),
    ]),
  );
}

class _ActiveToggleTile extends StatelessWidget {
  const _ActiveToggleTile({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: _kSurface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _kBorder),
    ),
    child: Row(children: [
      Icon(value ? Icons.check_circle_rounded : Icons.block_rounded,
          size: 18, color: value ? _kGreen : _kMuted),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value ? 'Module actif' : 'Module inactif', style: TextStyle(
            color: _kText, fontSize: 13, fontWeight: FontWeight.w700)),
        Text(value
            ? 'Visible et assignable aux plans d\'abonnement'
            : 'Masqué de la navigation et des plans',
            style: TextStyle(color: _kMuted, fontSize: 11)),
      ])),
      Switch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: _kGreen,
      ),
    ]),
  );
}

// ─── Modal détails — Fiche module ─────────────────────────────────────────────
