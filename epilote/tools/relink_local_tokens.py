#!/usr/bin/env python3
"""Rebranche les palettes LOCALES sur les jetons globaux.

Plusieurs espaces (super_admin surtout) redéfinissent leur propre palette en
dur, fichier par fichier : `const _kNavy = Color(0xFF1E3A5F);`. Ces jetons
dupliquent au hex près la palette canonique — ils ne suivraient donc jamais le
thème, et l'espace resterait clair pendant que le reste passe au sombre.

On les transforme en getters qui délèguent au jeton global :
    const _kNavy = Color(0xFF1E3A5F);   →   Color get _kNavy => kNavy;

Un getter, pas un `final` : `final` figerait la couleur au démarrage.

Les couleurs PROPRES à un écran (violet, orange… : accents décoratifs sans
équivalent canonique) restent `const` — elles n'ont pas de contrepartie dans
la palette et fonctionnent sur fond clair comme sombre.
"""
import re
import sys
from collections import Counter
from pathlib import Path

# hex canonique (palette Clair) → jeton global
CANON = {
    "0xFF091828": "kNavyDeep",
    "0xFF0F2340": "kNavyDark",
    "0xFF1E3A5F": "kNavy",
    "0xFF009A44": "kGreen",
    "0xFFFBBC04": "kAccent",
    "0xFFDC2626": "kRed",
    "0xFFF0F4F8": "kSurface",
    "0xFF0F172A": "kTextPrimary",
    "0xFF64748B": "kTextMuted",
    "0xFFE2E8F0": "kBorder",
}
DECL = re.compile(
    r"^const\s+(?:Color\s+)?(_k\w+)\s*=\s*(?:Color\((0x[0-9A-Fa-f]{8})\)|(Colors\.white))\s*;",
    re.M,
)


def main():
    apply = "--apply" in sys.argv
    roots = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("-") else "lib"
    stats = Counter()
    touched = []
    for path in Path(roots).rglob("*.dart"):
        text = path.read_text()
        new, changed = [], False
        last = 0
        for m in DECL.finditer(text):
            name, hexv, white = m.group(1), m.group(2), m.group(3)
            token = "kCardBg" if white else CANON.get(hexv)
            if not token:
                stats[f"laissé (couleur propre) {hexv}"] += 1
                continue
            new.append(text[last : m.start()])
            new.append(f"Color get {name} => {token};")
            last = m.end()
            changed = True
            stats[f"{name} → {token}"] += 1
        if changed:
            new.append(text[last:])
            out = "".join(new)
            # import admin_ui si absent (les jetons doivent être visibles)
            if "admin_ui.dart" not in out:
                depth = len(path.relative_to("lib").parts) - 1
                rel = "../" * depth + "core/widgets/admin_ui.dart"
                m = re.search(r"^import 'package:flutter/material\.dart';$", out, re.M)
                out = out[: m.end()] + f"\n\nimport '{rel}';" + out[m.end() :]
            touched.append(str(path))
            if apply:
                path.write_text(out)

    for k, n in sorted(stats.items(), key=lambda kv: -kv[1])[:16]:
        print(f"{n:>3} × {k}")
    print(f"\n{'APPLIQUÉ' if apply else 'SIMULATION'} — {len(touched)} fichiers")
    return 0


if __name__ == "__main__":
    sys.exit(main())
