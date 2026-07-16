#!/usr/bin/env python3
"""`this.color = kNavy` en valeur par défaut → paramètre nullable résolu dans
la liste d'initialisation.

En Dart, une valeur par défaut DOIT être une constante de compilation, quelle
que soit la constness du constructeur : retirer `const` ne suffit pas. On
transforme donc

    Foo({this.color = kNavy});      →   Foo({Color? color}) : color = color ?? kNavy;

Le champ reste `final Color color;` (non-nullable) : AUCUN site d'usage ne
change. C'est la correction de plus petit diff à sémantique identique.
"""
import re
import subprocess
import sys
from collections import defaultdict

FLUTTER = "/home/melack/flutter/bin/flutter"
ERR_RE = re.compile(
    r"^\s*error • .* • (lib/[^ :]+\.dart):(\d+):(\d+) • non_constant_default_value$"
)
# `this.<nom> = <jeton>` — le jeton est l'un de nos 11 (tous préfixés `k`).
PARAM_RE = re.compile(r"this\.(\w+)\s*=\s*(k[A-Z]\w*)")


def analyze_sites():
    out = subprocess.run([FLUTTER, "analyze"], capture_output=True, text=True).stdout
    sites = defaultdict(list)
    for line in out.splitlines():
        m = ERR_RE.match(line)
        if m:
            sites[m.group(1)].append(int(m.group(2)))
    return sites


def ctor_end(text, start):
    """Index du `)` fermant la liste de paramètres ouverte après `start`."""
    depth = 0
    for i in range(start, len(text)):
        c = text[i]
        if c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                return i
    return -1


def fix_file(path, lines):
    with open(path) as fh:
        text = fh.read()

    # Chaque site : (nom, jeton, offset). On regroupe par constructeur pour
    # n'écrire qu'une seule liste d'initialisation même à plusieurs paramètres.
    edits = []
    for ln in sorted(set(lines)):
        off = sum(len(l) + 1 for l in text.split("\n")[: ln - 1])
        line_txt = text.split("\n")[ln - 1]
        m = PARAM_RE.search(line_txt)
        if not m:
            print(f"   ⚠️ {path}:{ln} motif non reconnu : {line_txt.strip()}")
            continue
        edits.append((off + m.start(), off + m.end(), m.group(1), m.group(2)))

    if not edits:
        return 0

    # Trouver le constructeur englobant : remonter au `(` ouvrant.
    by_ctor = defaultdict(list)
    for s, e, name, token in edits:
        depth = 0
        i = s
        while i > 0:
            if text[i] == ")":
                depth += 1
            elif text[i] == "(":
                if depth == 0:
                    break
                depth -= 1
            i -= 1
        by_ctor[i].append((s, e, name, token))

    # Éditer de la fin vers le début pour ne pas décaler les offsets.
    for open_paren in sorted(by_ctor, reverse=True):
        members = by_ctor[open_paren]
        close = ctor_end(text, open_paren)
        if close < 0:
            continue
        # `) ;` ou `) : super(…) ;` — insérer avant le `;` final.
        semi = text.index(";", close)
        tail = text[close + 1 : semi]
        inits = ", ".join(f"{n} = {n} ?? {t}" for _, _, n, t in members)
        new_tail = (f"{tail}, {inits}" if tail.strip().startswith(":")
                    else f"{tail} : {inits}")
        text = text[: close + 1] + new_tail + text[semi:]
        # Paramètres : `this.color = kNavy` → `Color? color`
        for s, e, name, _ in sorted(members, reverse=True):
            text = text[:s] + f"Color? {name}" + text[e:]

    with open(path, "w") as fh:
        fh.write(text)
    return len(edits)


def main():
    sites = analyze_sites()
    total = sum(fix_file(p, ls) for p, ls in sites.items())
    print(f"{total} valeurs par défaut converties dans {len(sites)} fichiers")
    return 0


if __name__ == "__main__":
    sys.exit(main())
