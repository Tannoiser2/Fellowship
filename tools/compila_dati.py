"""Compila data/gioco.json: mappa, linee di battaglia, carte, personaggi e obiettivi di
The Lord of the Rings: Fate of the Fellowship, trascritti dal modulo TTS e tradotti in italiano.

Uso: python3 tools/compila_dati.py
"""
import json, os, sys

QUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, QUI)
exec(open(os.path.join(QUI, "graph.py"), encoding="utf-8").read())
exec(open(os.path.join(QUI, "locs.py"), encoding="utf-8").read())
XY = json.load(open(os.path.join(QUI, "loc_xy.json")))
OMBRA = json.load(open(os.path.join(QUI, "carte_ombra.json")))

# Nomi italiani dei luoghi (traduzione Alliata/Principe dove esiste; si possono correggere qui).
NOMI = {
    "ered_luin": "Ered Luin", "the_shire": "La Contea", "grey_havens": "Porti Grigi", "bree": "Brea",
    "weather_hills": "Colline Vento", "sarn_ford": "Guado Sarn", "tharbad": "Tharbad", "rivendell": "Gran Burrone",
    "hollin": "Agrifogliere", "moria": "Moria", "dunland": "Dunland", "isengard": "Isengard",
    "fangorn": "Foresta di Fangorn", "lorien": "Lórien", "carrock": "Carroccia", "gladden_fields": "Campi Iridati",
    "woodland_realm": "Reame Boscoso", "erebor": "Erebor", "iron_hills": "Colli Ferrosi", "lake_town": "Pontelagolungo",
    "old_forest_road": "Strada della Vecchia Foresta", "southern_mirkwood": "Bosco Atro Meridionale",
    "dol_guldur": "Dol Guldur", "dorwinion": "Dorwinion", "rhun": "Rhûn", "brown_lands": "Terre Brune",
    "emyn_muil": "Emyn Muil", "dagorlad": "Dagorlad", "eastemnet": "Estemnet", "druwaith_iaur": "Drúwaith Iaur",
    "fords_of_isen": "Guadi dell'Isen", "helms_deep": "Fosso di Helm", "edoras": "Edoras", "erech": "Erech",
    "pinnath_gelin": "Pinnath Gelin", "dol_amroth": "Dol Amroth", "lamedon": "Lamedon",
    "druadan_forest": "Foresta di Drúadan", "minas_tirith": "Minas Tirith", "pelargir": "Pelargir",
    "north_ithilien": "Nord Ithilien", "osgiliath": "Osgiliath", "south_ithilien": "Sud Ithilien",
    "udun": "Udûn", "barad_dur": "Barad-dûr", "mount_doom": "Monte Fato", "gorgoroth": "Pianoro di Gorgoroth",
    "minas_morgul": "Minas Morgul", "nurn": "Núrn", "harondor": "Harondor", "umbar": "Umbar",
    "near_harad": "Vicino Harad",
}
NOMI_REGIONI = {
    "eriador": "Eriador", "rhudaur": "Rhudaur", "enedwaith": "Enedwaith", "misty_mountains": "Montagne Nebbiose",
    "rohan": "Rohan", "gondor": "Gondor", "ithilien": "Ithilien", "haradwaith": "Haradwaith", "mordor": "Mordor",
    "mirkwood": "Bosco Atro", "dale": "Valle", "rhovanion": "Rhovanion",
}
# posizione della scritta della regione sul tabellone (pixel dell'immagine 3259x2796): ci si mettono i Nazgûl
POS_REGIONI = {
    "eriador": (560, 860), "rhudaur": (1240, 430), "enedwaith": (760, 1000), "misty_mountains": (1430, 720),
    "rohan": (1720, 1010), "gondor": (1140, 1700), "ithilien": (2260, 1950), "haradwaith": (1850, 2280),
    "mordor": (2780, 1900), "mirkwood": (2050, 560), "dale": (2490, 150), "rhovanion": (2600, 900),
}
# Nazgûl e Occhio stampati sul tabellone all'inizio
NAZGUL_INIZIO = {"eriador": 2, "rhudaur": 1, "misty_mountains": 1, "gondor": 1, "mordor": 4}
REGIONE = {l: r for r, ls in REGIONS.items() for l in ls}
COLORE_ARRUOLO = {k: v[4] for k, v in L.items()}
TIPO = {k: v[3] for k, v in L.items()}

luoghi = {}
for k, v in L.items():
    luoghi[k] = {"nome": NOMI[k], "x": XY[k][0], "y": XY[k][1], "regione": REGIONE[k],
                 "tipo": {"n": "normale", "h": "rifugio", "s": "fortezza", "r": "ombra"}[TIPO[k]],
                 "arruolo": COLORE_ARRUOLO[k] or ""}

collegamenti = {}
for lid, (col, seq) in LINES.items():
    for a, b in zip(seq, seq[1:]):
        collegamenti.setdefault(tuple(sorted((a, b))), {"a": min(a, b), "b": max(a, b), "costo": {}, "linee": []})["linee"].append(lid)
for a, b in NORMAL:
    collegamenti.setdefault(tuple(sorted((a, b))), {"a": min(a, b), "b": max(a, b), "costo": {}, "linee": []})
for a, b, s, c in SPECIAL:
    collegamenti.setdefault(tuple(sorted((a, b))), {"a": min(a, b), "b": max(a, b), "costo": {}, "linee": []})["costo"] = {s: c}

linee = {k: {"colore": v[0], "percorso": v[1]} for k, v in LINES.items()}

# --- carte Ombra: a quale linea porta ciascuna (alcune coppie origine/destinazione hanno due linee)
DOPPIE = {2907: "rhun_wr_ar", 2933: "rhun_wr_ar", 2934: "rhun_wr_rosa", 2936: "rhun_wr_rosa",
          2908: "nh_helms_blu", 2945: "nh_helms_blu", 2918: "nh_helms_ar", 2946: "nh_helms_ar",
          2927: "umb_helms_ar", 2941: "umb_helms_ar", 2940: "umb_helms_blu", 2943: "umb_helms_blu"}
carte_ombra = []
for c in OMBRA:
    a, b = c["linea"]
    if c["id"] in DOPPIE:
        lid = DOPPIE[c["id"]]
    else:
        lid = [k for k, v in LINES.items() if v[1][0] == a and v[1][-1] == b]
        assert len(lid) == 1, (c, lid)
        lid = lid[0]
    assert LINES[lid][1][0] == a and LINES[lid][1][-1] == b
    carte_ombra.append({"id": c["id"], "linea": lid, "rinforzo": c["rinforzo"], "ordine": c["ordine"],
                        "retro": c["retro"]})
carte_ombra.append({"id": 3039, "speciale": "saruman", "nome": "Le Ruote di Saruman", "retro": "stendardo",
                    "testo": "Scegliete una cosa: Rompere il giuramento (togliete 2 truppe amiche qualsiasi), "
                             "Dubbio (un giocatore scarta in tutto 2 carte e/o segnalini simbolo) o "
                             "Disperazione (perdete 1 speranza)."})
carte_ombra.append({"id": 3049, "speciale": "tamburi", "nome": "I Tamburi di Guerra", "retro": "bandiera",
                    "testo": "Aggiungete 1 truppa ombra in ogni roccaforte ombra di Mordor."})

# --- carte Regione: id -> (regione, simbolo, numero)
R = {
    2100: ("haradwaith", "resistenza", 99), 2101: ("ithilien", "resistenza", 7000), 2102: ("mirkwood", "resistenza", 95),
    2103: ("rhudaur", "resistenza", 2), 2104: ("dale", "furtivita", 50), 2105: ("misty_mountains", "furtivita", 30),
    2106: ("haradwaith", "valore", 15), 2110: ("misty_mountains", "resistenza", 21), 2111: ("mordor", "resistenza", 1),
    2112: ("rhovanion", "resistenza", 5), 2113: ("rohan", "resistenza", 42), 2114: ("enedwaith", "furtivita", 11),
    2115: ("mordor", "furtivita", 9), 2116: ("ithilien", "valore", 150), 2120: ("eriador", "furtivita", 4),
    2121: ("gondor", "furtivita", 28), 2122: ("haradwaith", "furtivita", 87), 2123: ("ithilien", "furtivita", 10),
    2124: ("mirkwood", "furtivita", 131), 2125: ("rhovanion", "furtivita", 18), 2126: ("mirkwood", "valore", 33),
    2130: ("rhudaur", "furtivita", 458), 2131: ("rohan", "furtivita", 105), 2132: ("dale", "valore", 111),
    2133: ("enedwaith", "valore", 12), 2134: ("eriador", "valore", 19), 2135: ("gondor", "valore", 93),
    2136: ("misty_mountains", "valore", 200), 2140: ("mordor", "valore", 3019), 2141: ("rhovanion", "valore", 20),
    2142: ("rhudaur", "valore", 464), 2143: ("rohan", "valore", 10000), 2159: ("dale", "amicizia", 13),
    2160: ("enedwaith", "amicizia", 400), 2161: ("eriador", "amicizia", 144), 2162: ("gondor", "amicizia", 26),
    2163: ("haradwaith", "amicizia", 130), 2164: ("ithilien", "amicizia", 3000), 2165: ("mirkwood", "amicizia", 14),
    2166: ("misty_mountains", "amicizia", 27), 2167: ("mordor", "amicizia", 589), 2168: ("rhovanion", "amicizia", 8),
    2169: ("rhudaur", "amicizia", 49), 2800: ("rohan", "amicizia", 45), 2801: ("eriador", "resistenza", 17),
    2802: ("dale", "resistenza", 7), 2803: ("gondor", "resistenza", 6), 2804: ("enedwaith", "resistenza", 3),
}
assert len(R) == 48
carte_regione = [{"id": k, "regione": v[0], "simbolo": v[1], "numero": v[2]} for k, v in sorted(R.items())]

SKIES = {2109: "north_ithilien", 2119: "south_ithilien", 2129: "southern_mirkwood", 2139: "tharbad",
         2151: "dorwinion", 2152: "druadan_forest", 2153: "druwaith_iaur", 2154: "emyn_muil",
         2155: "fangorn", 2156: "gladden_fields", 2157: "hollin", 2158: "mount_doom"}
carte_cieli = [{"id": k, "luogo": v} for k, v in sorted(SKIES.items())]

EVENTI = [
    (2107, "lotte_orchi", "Lotta Interna tra Orchi", "Togliete fino a 2 truppe ombra da un solo luogo."),
    (2108, "preveggenza_elrond", "La Preveggenza di Elrond", "Il giocatore di turno guarda fino a 4 carte in cima al mazzo dei giocatori. Può prenderne 1 in mano (non una carta Oscuramento dei Cieli) e rimette le altre in cima nell'ordine che vuole."),
    (2117, "freccia_rossa", "La Freccia Rossa", "Spostate fino a 3 truppe amiche che si trovano nello stesso rifugio in un altro rifugio. Poi, se volete, tirate un combattimento lì (e spostate l'Occhio in quella regione)."),
    (2118, "lembas", "Lembas", "Si gioca durante le azioni. Il giocatore di turno può fare 2 azioni in più con uno dei suoi personaggi in questo turno."),
    (2127, "mantelli_elfici", "Mantello e Corda Elfica", "Scegliete un personaggio: può viaggiare da solo fino a 2 volte, senza tirare ricerche (paga i sentieri speciali come al solito e non porta con sé altri personaggi né truppe)."),
    (2128, "cavalli_rohan", "Rohan Presta i Cavalli", "Scegliete un luogo: i personaggi che si trovano lì possono viaggiare tutti insieme fino a 3 volte, senza truppe e senza sentieri speciali. Se Frodo viaggia così, dopo ogni viaggio si tira una ricerca e non si può spendere Furtività per evitarla."),
    (2137, "aquile", "Aquile", "Spostate un personaggio in un luogo qualsiasi. Se è Frodo, spostate i 7 Nazgûl più vicini direttamente nella sua regione e l'Occhio su di lui, poi tirate una ricerca."),
    (2138, "tom_bombadil", "Tom Bombadil", "Scegliete: guadagnate 1 speranza, oppure ritirate fino a 3 dadi di un solo lancio."),
    (2144, "gwaihir", "Gwaihir Porta Buone Notizie", "Scegliete un luogo vicino a truppe amiche: spostateci una o più di quelle truppe (senza sentieri speciali). Poi, se volete, tirate un combattimento lì (e spostate l'Occhio in quella regione)."),
    (2145, "entmoot", "Entaconsulta", "Aggiungete fino a 3 truppe degli Ent (truppe elfiche) nella Foresta di Fangorn. Poi potete spostarle, con i personaggi che vogliono seguirle, in un luogo vicino, anche Isengard, senza spendere Furtività; in quel caso non si tirano ricerche né battaglie."),
    (2146, "consiglio_elrond", "Il Consiglio di Elrond", "Spostate quanti personaggi volete a Gran Burrone, senza truppe e senza tirare ricerche. Un giocatore con un personaggio a Gran Burrone può poi passare 1 segnalino simbolo a un altro giocatore con un personaggio lì. In solitario: preparate gratis 1 carta, anche se non è della regione."),
    (2147, "palantir", "Scrutare in un Palantír", "Scegliete un personaggio: spostate l'Occhio nella sua regione, poi spostate lì 3 Nazgûl qualsiasi."),
    (2148, "doni_elfi", "Doni dagli Elfi", "Prendete dalla riserva un segnalino simbolo qualsiasi e datelo a un giocatore."),
    (2150, "ordini_contrastanti", "Ordini in Conflitto", "Scegliete un luogo e spostate tutte le sue truppe ombra nei luoghi vicini che volete. Non si tirano battaglie; se ora ci sono truppe ombra in un rifugio senza truppe amiche, il rifugio cade."),
]
carte_evento = [{"id": i, "codice": c, "nome": n, "testo": t} for i, c, n, t in EVENTI]

PERSONAGGI = [
    ("aragorn", 500, "Aragorn", "weather_hills", "viola", [
        ("Ramingo del Nord", "Se Aragorn è presente quando si tira una ricerca, potete ritirare 1 dado di ricerca."),
        ("Capitano dell'Ovest", "Se Aragorn è presente a un combattimento, ogni Rotta toglie fino a 2 truppe ombra dal suo luogo invece di 1."),
        ("Andúril", "Azione (una volta per turno): se è stato completato almeno un obiettivo, togliete 1 truppa ombra dal luogo di Aragorn.")]),
    ("arwen", 501, "Arwen", "rivendell", "verde", [
        ("Stella del Vespro", "Quando Arwen raduna in un luogo elfico non spende Amicizia."),
        ("Inviare Aiuto", "Quando Arwen prepara, se un personaggio si trova nella regione della carta potete spostare 1 truppa elfica dal luogo di Arwen al luogo di quel personaggio."),
        ("Dare Consiglio", "Una volta nel vostro turno, quando Arwen usa la Compagnia in un rifugio, la carta data o presa non deve essere della sua regione. In solitario: una volta per turno, quando Arwen prepara, la carta scartata non deve essere della sua regione.")]),
    ("boromir", 504, "Boromir", "minas_tirith", "blu", [
        ("Erede del Sovrintendente", "Quando Boromir raduna in un luogo di Gondor non spende Amicizia."),
        ("Eroe di Gondor", "Quando Boromir conquista spende 1 Valore in meno."),
        ("Tentato dal Potere", "Quando Boromir partecipa alla Compagnia non si possono dare (né prendere da lui) carte Resistenza.")]),
    ("eomer", 505, "Éomer", "eastemnet", "marrone", [
        ("Cavaliere di Rohan", "Una volta per turno, quando Éomer fa le sue azioni, può fare 1 viaggio in più gratis."),
        ("Maresciallo del Mark", "Se Éomer e almeno una truppa dei Rohirrim sono presenti a un combattimento, ignorate la perdita di 1 truppa amica.")]),
    ("eowyn", 508, "Éowyn", "edoras", "bianco", [
        ("Fanciulla d'Arme di Rohan", "Quando Éowyn raduna in un luogo dei Rohirrim non spende Amicizia."),
        ("Io Non Sono un Uomo Vivente!", "Se Éowyn è presente a un combattimento, ogni risultato Nazgûl! toglie dal gioco 1 Nazgûl della sua regione (e non si perdono le 2 truppe amiche).")]),
    ("faramir", 509, "Faramir", "minas_tirith", "azzurro", [
        ("Imboscata", "Quando Faramir viaggia con almeno una truppa amica può fare un attacco gratis nel luogo d'arrivo; per ogni Furtività spesa cambiate 1 dado di combattimento in Rotta."),
        ("Furtivo", "Quando Faramir percorre un sentiero speciale spende 1 simbolo in meno."),
        ("Saggezza degli Eldar", "Azione (una volta per turno): se Faramir è in un rifugio, prende dagli scarti dei giocatori una carta Resistenza della regione in cui si trova.")]),
    ("frodo", 502, "Frodo & Sam", "the_shire", "giallo", [
        ("Il viaggio di Frodo", "Quando Frodo viaggia o partecipa a un viaggio, il giocatore di turno spende 1 Furtività oppure tira una ricerca nel luogo d'arrivo di Frodo."),
        ("Sostegno di Elrond", "Una volta per turno, quando Frodo prepara in un rifugio della regione della carta, prende anche 1 segnalino Amicizia."),
        ("Aiuto di Sam", "Quando si tira una ricerca, potete spendere Amicizia per ignorare altrettanti risultati Stanchezza o Scoperto."),
        ("Indossare l'Anello", "Prima di tirare una ricerca potete ignorare tutte le truppe ombra presenti: perdete 1 speranza e spostate l'Occhio nella regione di Frodo.")]),
    ("galadriel", 506, "Galadriel", "lorien", "verde scuro", [
        ("Dama della Luce", "In qualsiasi momento (non è un'azione): se è in un rifugio, spende 1 Furtività per pescare a caso uno degli eventi non usati nella preparazione."),
        ("Lo Specchio di Galadriel", "Azione: guarda le prime 4 carte del mazzo dei giocatori e le rimette in cima nell'ordine che vuole."),
        ("Nenya", "Se Galadriel e almeno una truppa elfica sono presenti a un combattimento, potete ritirare 1 dado di combattimento.")]),
    ("gandalf", 510, "Gandalf", "tharbad", "grigio", [
        ("Mithrandir", "Quando Gandalf raduna aggiunge fino a 2 truppe nel suo luogo invece di 1."),
        ("Ombromanto", "Quando Gandalf viaggia da solo può spostarsi di 2 luoghi, ma non su sentieri speciali."),
        ("Luce e Fiamme", "Se Gandalf è presente a un combattimento, potete spendere Valore per cambiare altrettanti dadi di combattimento nel risultato che volete.")]),
    ("gimli", 512, "Gimli", "erebor", "grigio scuro", [
        ("Figlio di Glóin", "Quando Gimli raduna in un luogo dei Nani non spende Amicizia."),
        ("Arte Nanica", "Azione (una volta per turno): prende 1 segnalino Valore dalla riserva.")]),
    ("gollum", 513, "Gollum", "moria", "nero", [
        ("Limiti", "Gollum non può radunare, attaccare né conquistare, e quando viaggia non porta con sé truppe amiche."),
        ("Ci Hanno Ingannato!", "Quando Gollum, Frodo o truppe amiche entrano o vengono aggiunti in un luogo, se lì ci sono tutti e tre perdete 1 speranza."),
        ("Guida", "Se Gollum è presente quando si tira una ricerca, tirate 3 dadi in meno (si possono comunque tirare fino a 7 dadi)."),
        ("Servile", "Azione (una volta per turno): prende dagli scarti dei giocatori una carta Furtività qualsiasi."),
        ("Astuto", "Gollum può preparare anche fuori da un rifugio. Quando prepara può spostare 1 truppa ombra presente in un luogo vicino (senza battaglia).")]),
    ("legolas", 514, "Legolas", "woodland_realm", "verde chiaro", [
        ("Camminare Silenziosamente", "Azione (una volta per turno): prende 1 segnalino Furtività dalla riserva."),
        ("Colpo Sicuro", "In qualsiasi momento (non è un'azione): spende 1 Furtività per togliere 1 truppa ombra dal suo luogo o da un luogo vicino, oppure per rimandare a Mordor 1 Nazgûl della sua regione."),
        ("Vista Acuta", "Una volta per turno, quando Legolas prepara, guarda la prima carta del mazzo dell'Ombra.")]),
    ("pipino", 503, "Merry & Pipino", "the_shire", "arancio", [
        ("Amici Fedeli", "Azione (una volta per turno): prendono 1 segnalino Amicizia dalla riserva."),
        ("Distrarre", "In qualsiasi momento (non è un'azione): se nella loro regione ci sono meno di 4 Nazgûl, spendono 1 Amicizia per attirare lì fino a 2 Nazgûl."),
        ("Dacci una Canzone!", "Azione: se sono nel luogo di Frodo, spendono 3 Amicizia per guadagnare 2 speranze.")]),
]
personaggi = {}
for pid, carta, nome, part, col, ab in PERSONAGGI:
    personaggi[pid] = {"carta": carta, "nome": nome, "partenza": part, "colore": col,
                       "abilita": [{"nome": a, "testo": t} for a, t in ab]}
personaggi["gandalf"]["bianco"] = {"carta": 4500, "nome": "Gandalf il Bianco",
                                   "testo": "Luce e fiamma: spendendo 1 Valore potete cambiare quanti dadi di combattimento volete."}

OBIETTIVI = [
    (2000, "benedizione", "Ottenere la Benedizione degli Elfi", "", True,
     "Preparazione: 3 truppe elfiche su questa carta (non si usano finché l'obiettivo non è completato).",
     "Come azione, un personaggio a Gran Burrone spende 3 Amicizia mentre c'è almeno un altro personaggio.",
     "Le truppe della carta vanno nella riserva; ogni giocatore con un personaggio a Gran Burrone prende 1 Amicizia; +1 speranza."),
    (2001, "saruman", "«Saruman, il Tuo Bastone è Rotto»", "", True,
     "Preparazione: 2 truppe ombra in più a Isengard.",
     "Isengard è un rifugio e il Rohan è libero da truppe e roccaforti ombra.",
     "Il giocatore di turno prende 1 Resistenza dalla riserva."),
    (2002, "sauron", "Sfidare Sauron", "", True, "",
     "Un personaggio spende un'azione nell'Nord Ithilien quando ci sono almeno 2 truppe dei Rohirrim, 2 elfiche e 3 di Gondor.",
     "L'Occhio va nell'Ithilien e tutte le truppe ombra di Mordor vanno a Udûn."),
    (2003, "anello", "Distruggere l'Unico Anello", "frodo", False,
     "Preparazione: si usano Frodo e Sam.",
     "Completati tutti gli altri obiettivi, come azione Frodo spende 5 Resistenza al Monte Fato e sopravvive a una ricerca finale con 1 dado in più per ogni speranza mancante (al massimo 7 dadi).",
     "Sauron è sconfitto: vincete tutti!"),
    (4200, "boromir", "Boromir Rivendica il Suo Onore", "boromir", False, "Preparazione: si usa Boromir.",
     "Boromir e almeno un altro personaggio sono in un luogo dove un combattimento toglie l'ultima truppa amica.",
     "Togliete fino a 2 truppe ombra dal luogo di Boromir; Boromir esce dal gioco. Al prossimo obiettivo completato un personaggio a caso lo sostituisce."),
    (4201, "pozzi", "Mettere a Nudo le Fosse", "galadriel", False,
     "Preparazione: si usa Galadriel; 1 truppa ombra in più a Dol Guldur.",
     "Dol Guldur è un rifugio e ci sono almeno 3 truppe elfiche. Galadriel può conquistare Dol Guldur spendendo 3 Valore oppure 2 Resistenza e 1 Valore.",
     "Se Galadriel è a Dol Guldur, +1 speranza."),
    (4202, "balin", "Vendicare Balin!", "", False, "",
     "Moria è un rifugio e ci sono almeno 2 truppe dei Nani.",
     "Spostate a Moria le truppe dei Nani che volete; se ce ne sono almeno 4, il giocatore di turno prende 2 Valore."),
    (4203, "raminghi", "I Raminghi Liberano l'Eriador", "", False, "",
     "L'Eriador è libero da truppe e roccaforti ombra e c'è almeno una truppa amica in ogni suo luogo.",
     "Spostate le truppe amiche dell'Eriador che volete ai Colline Vento o a Tharbad; +1 speranza."),
    (4204, "freca", "Occuparsi degli Eredi di Freca", "", False, "",
     "Dunland è un rifugio e ci sono almeno 2 truppe dei Rohirrim. Si può conquistare Dunland (anche se non è una fortezza) spendendo 3 Valore oppure 3 Amicizia.",
     "Potete aggiungere 1 truppa dei Rohirrim a Dunland."),
    (4205, "umbar", "Sottomettere Umbar", "", False, "",
     "Umbar è un rifugio, oppure c'è una truppa amica in ogni luogo dell'Haradwaith e nessuna truppa ombra.",
     "Spostate a Pelargir le truppe amiche dell'Haradwaith che volete."),
    (4206, "nani", "Sollevare l'Ombra dalle Terre Naniche", "gimli", False,
     "Preparazione: si usa Gimli; 1 truppa ombra ai Ered Luin.",
     "Nessuna truppa ombra ai Ered Luin, almeno 4 truppe dei Nani lì, e nessuna truppa o roccaforte ombra nella Valle.",
     "Il giocatore di turno prende 2 Valore; +1 speranza."),
    (4207, "eored", "Cavalcare con gli Éored", "eomer", False, "Preparazione: si usa Éomer.",
     "Quando Éomer attacca con i Rohirrim e toglie truppe ombra, ne mette 1 sullo spazio della sua regione (Rohan e regioni vicine, una per spazio). Completato con 4 truppe sulla carta.",
     "Le truppe tornano nella riserva; +1 speranza."),
    (4208, "balrog", "Affrontare il Balrog", "gandalf", False, "Preparazione: si usa Gandalf.",
     "Gandalf spende un'azione a Moria e tira 3 dadi di combattimento (Travolti: -1 speranza, Scambio: -2, Nazgûl!: -3, Rotta: niente). Ogni Resistenza ignora un dado, ogni Valore evita 1 speranza persa.",
     "Gandalf esce dalla mappa: alla prossima carta Oscuramento dei Cieli torna a Lórien come Gandalf il Bianco e +2 speranze."),
    (4209, "bosco_atro", "Portare la Luce al Bosco Atro", "", False,
     "Preparazione: 1 truppa ombra nella Strada della Vecchia Foresta e nel Bosco Atro Meridionale.",
     "Il Bosco Atro è libero da truppe ombra (non serve conquistare Dol Guldur) e c'è una truppa elfica in ogni suo luogo.",
     "Scegliete un luogo del Bosco Atro e spostateci le truppe elfiche del Bosco Atro che volete; +1 speranza."),
    (4210, "theoden", "Liberare la Mente di Théoden", "", False,
     "Preparazione: 4 truppe dei Rohirrim su questa carta.",
     "Come azione, un personaggio a Edoras spende 2 Amicizia e 1 Resistenza mentre c'è almeno un altro personaggio.",
     "Le truppe della carta vanno nella riserva; aggiungete fino a 2 truppe dei Rohirrim a Edoras; +1 speranza."),
    (4211, "morgul", "Infiltrarsi a Minas Morgul", "", False,
     "Preparazione: 1 truppa ombra in più a Minas Morgul.",
     "Minas Morgul è un rifugio. Si può conquistare spendendo 3 Valore oppure 3 Furtività.",
     "Il giocatore di turno prende 2 Furtività; guardate le prime 2 carte dell'Ombra e togliete dal gioco quelle che volete."),
    (4212, "eowyn", "«Non Più Fanciulla dello Scudo»", "eowyn", False,
     "Preparazione: si usa Éowyn. Se Éowyn è presente a un combattimento può spendere 2 Valore per cambiare 1 dado in Nazgûl!.",
     "Éowyn ha distrutto almeno 2 Nazgûl e il Rohan è libero da truppe e roccaforti ombra.",
     "+1 speranza."),
    (4213, "hobbit", "Gli Hobbit Giurano la Loro Fedeltà", "pipino", False, "Preparazione: si usano Merry e Pipino.",
     "In un rifugio Merry e Pipino possono scartare con un'azione una carta Amicizia della loro regione per mettere 1 Amicizia sul simbolo del rifugio (Elfi, Nani, Rohirrim, Gondor). Completato con 2 simboli coperti.",
     "Merry e Pipino prendono i 2 segnalini Amicizia; +1 speranza."),
    (4214, "shelob", "La Tana di Shelob", "gollum", False,
     "Preparazione: si usa Gollum (non può averlo chi ha Frodo).",
     "Sam spende un'azione a Minas Morgul con Gollum presente e tira 3 dadi di combattimento (Travolti: -1 speranza, Scambio: -2, Nazgûl!: -3, Rotta: niente); si perde anche 1 speranza per ogni Resistenza del giocatore di Gollum. Ogni Resistenza ignora un dado, ogni Valore evita 1 speranza persa.",
     "Se Frodo non ha perso speranza può fare un'azione in più in questo turno."),
    (4215, "anduin", "Assicurare il Passaggio dell'Anduin", "faramir", False,
     "Preparazione: si usa Faramir; 1 truppa ombra a Osgiliath.",
     "Osgiliath è un rifugio. Faramir può conquistarla spendendo 3 Valore oppure 2 Resistenza e 1 Furtività.",
     "Potete aggiungere 1 truppa di Gondor a Osgiliath."),
    (4216, "denethor", "Deporre Denethor", "", False,
     "Preparazione: 4 truppe di Gondor su questa carta.",
     "Come azione, un personaggio a Minas Tirith spende 2 Furtività, 1 Amicizia e 1 Valore mentre c'è almeno un altro personaggio.",
     "Le truppe della carta vanno nella riserva; aggiungete fino a 3 truppe di Gondor a Minas Tirith; +1 speranza."),
    (4217, "sei", "«Con Questo Fanno Sei!»", "legolas", False, "Preparazione: si usa Legolas.",
     "Quando Legolas toglie una truppa ombra con Tiro sicuro, la mette su questa carta. Completato con 6 truppe sulla carta.",
     "Le truppe tornano nella riserva; +1 speranza."),
    (4218, "stendardo", "Arwen Dispiega lo Stendardo", "arwen", False, "Preparazione: si usa Arwen.",
     "Arwen spende un'azione e 1 Amicizia a Minas Tirith, che è un rifugio, con almeno una truppa di Gondor, una dei Rohirrim, una elfica e una dei Nani.",
     "+1 speranza."),
    (4219, "spergiuri", "Gli Spergiuri Adempiono al Loro Dovere", "aragorn", False,
     "Preparazione: si usa Aragorn. Una volta per partita Aragorn viaggia da Edoras a Erech: aggiungete 2 truppe ombra a Pelargir, spostate lì tutte quelle di Umbar e aggiungete fino a 3 truppe di Gondor a Erech.",
     "Aragorn ha fatto quel viaggio e il Gondor è libero da truppe e roccaforti ombra.",
     "+1 speranza."),
]
obiettivi = [{"id": i, "codice": c, "nome": n, "richiede": rq, "primo": pr, "preparazione": prep,
              "condizione": cond, "effetto": eff} for i, c, n, rq, pr, prep, cond, eff in OBIETTIVI]

SCENARI = [
    ("primo", "La vostra prima partita", ["benedizione", "saruman", "sauron", "anello"], "introduttivo"),
    ("oscurita", "Tenere a bada l'oscurità", ["balrog", "spergiuri", "umbar", "anello"], "standard"),
    ("rohan", "I Cavalieri di Rohan", ["eored", "theoden", "freca", "eowyn", "anello"], "eroico"),
    ("elfi", "Il destino degli Elfi", ["sei", "stendardo", "pozzi", "bosco_atro", "anello"], "eroico"),
    ("sovrintendente", "I figli del Sovrintendente", ["boromir", "anduin", "denethor", "morgul", "anello"], "epico"),
    ("piccoli", "Nessun eroe è troppo piccolo", ["balin", "nani", "raminghi", "hobbit", "shelob", "anello"], "leggendario"),
]
DIFFICOLTA = {"introduttivo": {"nome": "Introduttiva", "cieli": 4, "obiettivi": 4},
              "standard": {"nome": "Standard", "cieli": 5, "obiettivi": 4},
              "eroico": {"nome": "Eroica", "cieli": 5, "obiettivi": 5},
              "epico": {"nome": "Epica", "cieli": 6, "obiettivi": 5},
              "leggendario": {"nome": "Leggendaria", "cieli": 6, "obiettivi": 6}}

dati = {
    "luoghi": luoghi, "regioni": {k: {"nome": NOMI_REGIONI[k], "luoghi": v, "x": POS_REGIONI[k][0], "y": POS_REGIONI[k][1]}
                                  for k, v in REGIONS.items()},
    "collegamenti": list(collegamenti.values()), "linee": linee,
    "carte_ombra": carte_ombra, "carte_regione": carte_regione, "carte_cieli": carte_cieli, "carte_evento": carte_evento,
    "personaggi": personaggi, "obiettivi": obiettivi,
    "scenari": [{"codice": c, "nome": n, "obiettivi": o, "difficolta": d} for c, n, o, d in SCENARI],
    "difficolta": DIFFICOLTA, "nazgul_inizio": NAZGUL_INIZIO,
    "truppe_inizio": {"nani": {"ered_luin": 1, "erebor": 1, "iron_hills": 1},
                      "elfi": {"grey_havens": 1, "rivendell": 1, "lorien": 1, "woodland_realm": 1},
                      "rohirrim": {"helms_deep": 1, "edoras": 1, "eastemnet": 1},
                      "gondor": {"minas_tirith": 2, "dol_amroth": 2, "pelargir": 1}},
    "ombra_inizio": {"dunland": 1, "isengard": 1, "moria": 2, "dol_guldur": 1, "rhun": 3, "minas_morgul": 2,
                     "barad_dur": 2, "nurn": 3, "umbar": 1, "near_harad": 2},
    "riserva": {"nani": 8, "elfi": 9, "rohirrim": 8, "gondor": 10, "ombra": 48, "simboli": 9},
}
assert sum(dati["ombra_inizio"].values()) == 18
os.makedirs(os.path.join(QUI, "..", "data"), exist_ok=True)
json.dump(dati, open(os.path.join(QUI, "..", "data", "gioco.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print("data/gioco.json: %d luoghi, %d collegamenti, %d linee, %d carte Ombra" % (len(luoghi), len(collegamenti), len(linee), len(carte_ombra)))
