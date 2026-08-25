#!/usr/bin/env python3
"""Retire les `const` devenus invalides depuis que les jetons de couleur
(`kNavy`, `kSurface`…) sont des variables — le prix intrinsèque du thème.

L'ANALYSEUR EST L'ORACLE : le script ne devine rien, il ne corrige que les
sites que `flutter analyze` désigne, et la boucle s'arrête à 0 issue.

Pour chaque erreur, on retire le `const` ENGLOBANT le plus EXTERNE : dans une
expression const imbriquée, seul l'extérieur impose le contexte const. Les
`const` internes deviennent alors extérieurs à leur tour et sont traités au
tour suivant — d'où la convergence.

Les déclarations top-level (`const_initialized_with_non_constant_value`) sont
EXCLUES volontairement : les rendre `final` figerait la couleur au démarrage
(bug muet). Elles deviennent des getters, à la main.
"""
import re
import subprocess
import sys
from collections import defaultdict

FLUTTER = "/home/melack/flutter/bin/flutter"

# Codes traitables par retrait mécanique du `const` englobant.
AUTO_CODES = {
    "invalid_constant",
    "non_constant_list_element",
    "non_constant_map_value",
    "const_with_non_constant_argument",
    "non_constant_default_value",
}
# Traité à la main (Task 4) : un getter, pas un `final`.
MANUAL_CODES = {"const_initialized_with_non_constant_value"}

LINE_RE = re.compile(r"^\s*error • .* • (lib/[^ :]+\.dart):(\d+):(\d+) • (\w+)$")


def analyze():
    out = subprocess.run(
        [FLUTTER, "analyze"], capture_output=True, text=True, cwd="."
    ).stdout
    errors = []
    for line in out.splitlines():
        m = LINE_RE.match(line)
        if m:
            errors.append((m.group(1), int(m.group(2)), int(m.group(3)), m.group(4)))
    return errors


def offset_of(text, line, col):
    """(ligne, colonne) 1-based -> index absolu."""
    lines = text.split("\n")
    return sum(len(l) + 1 for l in lines[: line - 1]) + (col - 1)


def const_extent(text, start):
    """Fin de l'expression ouverte par le `const` à `start`.

    On avance en suivant la profondeur des () [] {} ; l'expression se termine
    quand on retombe à la profondeur 0 sur un `,` ou un `;`.
    """
    depth = 0
    i = start
    n = len(text)
    while i < n:
        c = text[i]
        if c in "([{":
            depth += 1
        elif c in ")]}":
            if depth == 0:
                return i
            depth -= 1
        elif c in ",;" and depth == 0:
            return i
        i += 1
    return n


def is_declaration(text, const_end):
    """`const _x = …` (déclaration) plutôt que `const Foo(…)` (expression) ?

    Discriminant : un `=` apparaît AVANT toute ouverture de parenthèse.
    Retirer le `const` d'une déclaration produirait `_x = …`, qui n'est plus
    une déclaration valide — et la rendre `final` figerait la couleur au
    démarrage. Ces sites deviennent des getters, à la main (Task 4).
    """
    for c in text[const_end : const_end + 200]:
        if c == "=":
            return True
        if c in "([{;":
            return False
    return False


def enclosing_const(text, err_off):
    """Le `const` le plus EXTERNE dont l'expression contient err_off.

    Renvoie (match, est_une_déclaration). Dans une expression const imbriquée,
    seul l'extérieur impose le contexte const : les `const` internes seront
    traités au tour suivant, une fois devenus extérieurs.
    """
    for m in re.finditer(r"\bconst\b", text):
        s = m.start()
        if s >= err_off:
            break
        if const_extent(text, m.end()) > err_off:
            return m, is_declaration(text, m.end())  # premier = le plus externe
    return None, False


def strip_pass():
    errors = analyze()
    auto = [e for e in errors if e[3] in AUTO_CODES]
    manual = [e for e in errors if e[3] in MANUAL_CODES]
    other = [e for e in errors if e[3] not in AUTO_CODES | MANUAL_CODES]
    if not auto:
        return 0, len(manual), other, set()

    by_file = defaultdict(list)
    for f, line, col, _ in auto:
        by_file[f].append((line, col))

    fixed = 0
    decls = set()
    for path, sites in by_file.items():
        with open(path) as fh:
            text = fh.read()
        # Dédupliquer les `const` à retirer, puis éditer de la fin vers le début
        # pour ne pas décaler les offsets restants.
        targets = set()
        for line, col in sites:
            m, decl = enclosing_const(text, offset_of(text, line, col))
            if m is None:
                continue
            if decl:
                decls.add(f"{path}:{text.count(chr(10), 0, m.start()) + 1}")
            else:
                targets.add((m.start(), m.end()))
        for s, e in sorted(targets, reverse=True):
            after = text[e:]
            cut = len(after) - len(after.lstrip(" "))  # avale l'espace suivant
            text = text[:s] + text[e + cut :]
            fixed += 1
        with open(path, "w") as fh:
            fh.write(text)
    return fixed, len(manual) + len(decls), other, decls


def main():
    all_decls = set()
    for i in range(1, 26):
        fixed, manual, other, decls = strip_pass()
        all_decls |= decls
        print(f"passe {i}: {fixed} const retirés | {manual} sites à la main | "
              f"{len(other)} autres erreurs")
        if fixed == 0:
            if all_decls:
                print(f"\n📌 {len(all_decls)} déclarations top-level → getters "
                      f"(à la main, Task 4) :")
                for d in sorted(all_decls):
                    print(f"   {d}")
            if other:
                print("\n⚠️ erreurs non mécaniques restantes :")
                for f, l, c, code in other[:20]:
                    print(f"   {f}:{l}:{c} • {code}")
            return 0
    print("⚠️ non convergé en 25 passes")
    return 1


if __name__ == "__main__":
    sys.exit(main())
