#!/usr/bin/env python3
"""Riassume i risultati di tests/banco_ia.gd: vittorie con intervallo di confidenza (Wilson 95%),
durata, cause della perdita di speranza, rifugi persi, obiettivi completati.
Uso: python3 tools/riassunto_banco.py risultati/*.jsonl"""
import json, sys, math, collections

def wilson(k, n, z=1.96):
    if n == 0:
        return (0.0, 0.0)
    p = k / n
    d = 1 + z * z / n
    c = (p + z * z / (2 * n)) / d
    h = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / d
    return (max(0.0, c - h), min(1.0, c + h))

gruppi = collections.defaultdict(list)
for nome in sys.argv[1:]:
    for riga in open(nome):
        riga = riga.strip()
        if riga:
            r = json.loads(riga)
            gruppi[(r["politica"], r["conf"])].append(r)

for (pol, conf), rr in sorted(gruppi.items()):
    n = len(rr)
    v = sum(1 for r in rr if r["esito"] == "vittoria")
    lo, hi = wilson(v, n)
    perdite = collections.Counter()
    for r in rr:
        perdite.update(r["perdite"])
    ob = collections.Counter(o for r in rr for o in r["obiettivi_fatti"])
    print(f"== {pol} / {conf}: {n} partite (semi {min(r['seme'] for r in rr)}-{max(r['seme'] for r in rr)})")
    print(f"   vittorie {v}/{n} = {100*v/n:.1f}%  (IC 95%: {100*lo:.1f}-{100*hi:.1f}%)")
    print(f"   turni medi {sum(r['turni'] for r in rr)/n:.1f}; rifugi persi per partita {sum(len(r['rifugi_persi']) for r in rr)/n:.2f}")
    print(f"   speranza persa per partita: " + ", ".join(f"{k} {c/n:.2f}" for k, c in perdite.most_common()))
    print(f"   obiettivi completati (su {n} partite): " + (", ".join(f"{k} {c}" for k, c in ob.most_common()) or "nessuno"))
    print(f"   resistenza di Frodo a fine partita: {sum(r['resistenza_frodo'] for r in rr)/n:.1f}; "
          f"risorse non usate: {sum(r['gettoni_finali'] for r in rr)/n:.1f} segnalini, {sum(r['carte_finali'] for r in rr)/n:.1f} carte; "
          f"secondi per partita {sum(r['secondi'] for r in rr)/n:.1f}")
