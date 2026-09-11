# -*- coding: utf-8 -*-
"""Compare les sync-rules DEPLOYEES aux sync-rules LOCALES, bucket par bucket.

Le service PowerSync REFORMATE le YAML qu'on lui envoie : les scalaires pliés
(`>-`) reviennent depliés. Comparer les chaines brutes fait donc apparaitre
des buckets "differents" qui sont en realite identiques -- et conduirait a
redeployer la production sans raison (un deploiement relance le service et
fait resynchroniser tous les postes).

On compare donc la STRUCTURE : chaque bucket, ses `parameters` et ses
requetes `data`, apres normalisation des espaces.
"""
import io
import re
import sys

import yaml

DEPLOYE = sys.argv[1]
LOCAL = sys.argv[2]


def normaliser(x):
    """Ecrase les espaces multiples et les fins de ligne d'un scalaire."""
    if isinstance(x, str):
        return re.sub(r'\s+', ' ', x).strip()
    if isinstance(x, list):
        return [normaliser(i) for i in x]
    if isinstance(x, dict):
        return {k: normaliser(v) for k, v in x.items()}
    return x


def buckets(texte):
    doc = yaml.safe_load(texte)
    return normaliser((doc or {}).get('bucket_definitions') or {})


enveloppe = yaml.safe_load(io.open(DEPLOYE, encoding='utf-8').read())
deploye = buckets(enveloppe['syncRules'])
local = buckets(io.open(LOCAL, encoding='utf-8').read())

noms_d, noms_l = set(deploye), set(local)

print('buckets deployes : %d' % len(noms_d))
print('buckets locaux   : %d' % len(noms_l))
print('')

ajoutes = sorted(noms_l - noms_d)
retires = sorted(noms_d - noms_l)
communs = sorted(noms_l & noms_d)

if ajoutes:
    print('+++ BUCKETS AJOUTES par ce deploiement (%d)' % len(ajoutes))
    for n in ajoutes:
        print('    + %s' % n)
    print('')
if retires:
    print('!!! BUCKETS RETIRES par ce deploiement (%d) -- A VERIFIER' % len(retires))
    for n in retires:
        print('    - %s' % n)
    print('')

modifies = []
for n in communs:
    if deploye[n] != local[n]:
        modifies.append(n)

if modifies:
    print('~~~ BUCKETS MODIFIES (%d)' % len(modifies))
    for n in modifies:
        d = deploye[n]
        l = local[n]
        print('')
        print('  ~ %s' % n)
        if d.get('parameters') != l.get('parameters'):
            print('      parameters :')
            print('        deploye : %s' % d.get('parameters'))
            print('        local   : %s' % l.get('parameters'))
        dd = d.get('data') or []
        ll = l.get('data') or []
        for q in ll:
            if q not in dd:
                print('        + %s' % q)
        for q in dd:
            if q not in ll:
                print('        - %s' % q)
else:
    print('=== aucun bucket commun modifie')

print('')
if not ajoutes and not retires and not modifies:
    print('>>> AUCUN ECART : ne PAS redeployer (le service redemarrerait pour rien).')
else:
    print('>>> ECARTS REELS : le deploiement est justifie.')
