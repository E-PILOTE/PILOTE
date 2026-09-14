# -*- coding: utf-8 -*-
"""Quels providers de ces deux espaces se jettent des qu'on quitte l'ecran ?

`autoDispose` sans `keepAlive()` = la donnee est detruite quand plus personne
ne la regarde. Revenir sur l'ecran = tout retelecharger.
"""
import io
import os
import re

RACINES = ['lib/features/super_admin/providers',
           'lib/features/admin_groupe/providers']

# Debut de declaration d'un provider asynchrone.
DEB = re.compile(r'^final\s+(\w+)\s*=\s*$|^final\s+(\w+)\s*=\s*(FutureProvider|StreamProvider)')

froids = []
for r in RACINES:
    for f in sorted(os.listdir(r)):
        if not f.endswith('.dart'):
            continue
        p = (r + '/' + f)
        src = io.open(p, encoding='utf-8').read()
        lignes = src.split('\n')
        for i, l in enumerate(lignes):
            m = re.match(r'^final\s+(\w+)\s*=', l)
            if not m:
                continue
            # Le corps du provider : jusqu'a la prochaine declaration `final` en
            # colonne 0, ou 90 lignes.
            j = i + 1
            while j < len(lignes) and j < i + 90 and not re.match(r'^final\s+\w+\s*=', lignes[j]):
                j += 1
            corps = '\n'.join(lignes[i:j])
            if 'autoDispose' not in corps:
                continue
            if 'FutureProvider' not in corps and 'StreamProvider' not in corps:
                continue
            if 'ref.keepAlive()' in corps:
                continue
            froids.append((p.replace('lib/features/', ''), m.group(1), i + 1))

print('providers qui se jettent en quittant l\'ecran :', len(froids))
print()
for p, nom, n in froids:
    print('%-52s %-38s L%s' % (p.replace('/providers', ''), nom, n))
