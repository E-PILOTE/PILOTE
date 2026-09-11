# -*- coding: utf-8 -*-
"""Combien de LECTURES reseau une ouverture d'ecran declenche-t-elle ?

Le comptage naif (`grep .from(`) melange lectures et ecritures : les actions
d'un ecran (insert/update/delete/rpc) vivent dans le meme fichier. On ne
compte donc que ce qui se trouve dans le CORPS d'un provider asynchrone.
"""
import io
import os
import re

RACINES = ['lib/features/super_admin/providers',
           'lib/features/admin_groupe/providers']

DEBUT = re.compile(r'^final\s+(\w+)\s*=')
LECTURE = re.compile(r"\.(from|rpc)\('")
ECRITURE = re.compile(r'\.(insert|update|delete|upsert)\(')

resultats = []
for r in RACINES:
    for f in sorted(os.listdir(r)):
        if not f.endswith('.dart'):
            continue
        p = r + '/' + f
        lignes = io.open(p, encoding='utf-8').read().split('\n')
        for i, l in enumerate(lignes):
            m = DEBUT.match(l)
            if not m:
                continue
            j = i + 1
            while j < len(lignes) and not DEBUT.match(lignes[j]):
                j += 1
            corps = lignes[i:j]
            entete = '\n'.join(corps[:4])
            if 'FutureProvider' not in entete and 'StreamProvider' not in entete:
                continue
            n = 0
            for k, c in enumerate(corps):
                if not LECTURE.search(c):
                    continue
                # une ecriture dans les 3 lignes suivantes => ce n'est pas une lecture
                voisin = '\n'.join(corps[k:k + 4])
                if ECRITURE.search(voisin):
                    continue
                n += 1
            if n >= 3:
                chaud = 'ref.keepAlive()' in '\n'.join(corps)
                resultats.append((n, m.group(1),
                                  p.replace('lib/features/', '').replace('/providers', ''),
                                  'chaud' if chaud else 'FROID'))

resultats.sort(reverse=True)
print('%-4s %-38s %-30s %s' % ('lect', 'provider', 'fichier', 'etat'))
for n, nom, p, chaud in resultats:
    print('%-4s %-38s %-30s %s' % (n, nom, os.path.basename(p), chaud))
print()
print('total providers a 3 lectures ou plus :', len(resultats))
