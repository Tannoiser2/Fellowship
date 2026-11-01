"""Controlla che ogni carattere scritto negli script e nei dati esista nei font del gioco.

Uso: python3 tools/controlla_glifi.py   (esce con errore se trova caratteri che apparirebbero come quadratini)
"""
import glob, json, re, sys
from fontTools.ttLib import TTFont

TESTO = ["assets/fonts/Alegreya-Regular.ttf", "assets/fonts/Alegreya-Bold.ttf", "assets/fonts/Alegreya-Italic.ttf"]
TITOLI = ["assets/fonts/Cinzel-Bold.ttf"]
cm_testo = [set(TTFont(f).getBestCmap().keys()) for f in TESTO]
cm_titoli = [set(TTFont(f).getBestCmap().keys()) for f in TITOLI]
logo = set(TTFont("assets/fonts/CinzelDecorative-Bold.ttf").getBestCmap().keys())
bad = {}


def controlla(testo, dove, cmaps):
    for ch in testo:
        if ch in "\n\t":
            continue
        for cm in cmaps:
            if ord(ch) not in cm:
                bad.setdefault(ch, []).append(dove)
                break


for f in glob.glob("scripts/**/*.gd", recursive=True):
    for n, line in enumerate(open(f, encoding="utf-8"), 1):
        code = line.split("#", 1)[0] if not line.lstrip().startswith("##") else ""
        for s in re.findall(r'"((?:[^"\\]|\\.)*)"', code):
            # i titoli usano Cinzel: controlla anche quello
            controlla(s, "%s:%d" % (f, n), cm_testo + cm_titoli)
# testi lunghi su più righe (regole)
for f in glob.glob("scripts/**/*.gd", recursive=True):
    src = open(f, encoding="utf-8").read()
    for s in re.findall(r'"""(.*?)"""', src, re.S):
        controlla(re.sub(r"\[[^\]]*\]", "", s), f + " (testo lungo)", cm_testo)
d = json.load(open("data/gioco.json", encoding="utf-8"))
def tutte(x, dove):
    if isinstance(x, str):
        controlla(x, dove, cm_testo + cm_titoli)
    elif isinstance(x, dict):
        for k, v in x.items():
            tutte(v, dove + "/" + str(k))
    elif isinstance(x, list):
        for i, v in enumerate(x):
            tutte(v, dove + "/" + str(i))
tutte(d, "gioco.json")
controlla("Il destino della Compagnia L'Ombra ha vinto L'Anello è distrutto!", "logo", [logo])
for ch, where in bad.items():
    print("MANCA %r U+%04X: %s" % (ch, ord(ch), ", ".join(sorted(set(where))[:5])))
print("glifi ok" if not bad else "%d caratteri non disponibili" % len(bad))
sys.exit(1 if bad else 0)
