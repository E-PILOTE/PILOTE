#!/usr/bin/env python3
"""`Colors.white` utilisé comme FOND → `kCardBg` (qui suit le thème).

Le blanc en dur ne passe pas par les jetons : il reste blanc en Sombre/Melack.
Quand c'est un fond (en-tête, carte, feuille), le texte par-dessus — lui —
suit le thème et devient clair : blanc sur blanc, invisible.

⚠️ On ne convertit QUE les fonds. Le blanc de PREMIER PLAN (texte/icône sur
bandeau coloré) est correct dans les 3 thèmes et doit rester : le convertir
rendrait un titre blanc-sur-navy en titre noir-sur-navy.

Le tri se fait sur le constructeur englobant, pas sur le nom de la propriété :
`color:` ne dit rien à lui seul (TextStyle vs BoxDecoration).
"""
import re
import sys
from collections import Counter
from pathlib import Path

BG_CTORS = {
    "BoxDecoration", "Container", "Material", "Card", "CardThemeData",
    "Dialog", "AlertDialog", "BottomSheet", "Drawer", "Scaffold",
    "AppBar", "AppBarTheme", "PopupMenuThemeData", "DataTableThemeData",
    "InputDecoration", "InputDecorationTheme",  # fillColor = fond de champ
}
FG_CTORS = {  # explicitement laissés : blanc SUR une couleur
    "TextStyle", "Icon", "IconThemeData", "Text", "CircularProgressIndicator",
    "LinearProgressIndicator", "IconButton", "CircleAvatar",
}
PROPS = r"(?:color|backgroundColor|fillColor|surfaceTintColor|barrierColor)"
SITE = re.compile(rf"\b{PROPS}:\s*Colors\.white\b(?![.\d])")


def enclosing_ctor(text, pos):
    """Constructeur ouvert le plus proche (profondeur de parenthèses)."""
    depth = 0
    i = pos
    while i > 0:
        c = text[i]
        if c == ")":
            depth += 1
        elif c == "(":
            if depth == 0:
                m = re.search(r"([A-Za-z_]\w*)\s*$", text[:i])
                return m.group(1) if m else "?"
            depth -= 1
        i -= 1
    return "?"


def main():
    apply = "--apply" in sys.argv
    stats = Counter()
    changed = 0
    for path in Path("lib").rglob("*.dart"):
        text = path.read_text()
        out, last, hits = [], 0, 0
        for m in SITE.finditer(text):
            ctor = enclosing_ctor(text, m.start())
            if ctor in BG_CTORS:
                stats[f"CONVERTI ({ctor})"] += 1
                out.append(text[last : m.start()])
                out.append(m.group(0).replace("Colors.white", "kCardBg"))
                last = m.end()
                hits += 1
            elif ctor in FG_CTORS:
                stats[f"laissé ({ctor})"] += 1
            else:
                stats[f"?? À VOIR ({ctor})"] += 1
        if hits and apply:
            out.append(text[last:])
            path.write_text("".join(out))
            changed += 1

    for k, n in sorted(stats.items(), key=lambda kv: -kv[1]):
        print(f"{n:>4}  {k}")
    print(f"\n{'APPLIQUÉ' if apply else 'SIMULATION'} — {changed} fichiers modifiés")
    return 0


if __name__ == "__main__":
    sys.exit(main())
