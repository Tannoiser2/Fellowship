class_name Missioni
extends RefCounted
## Pianificatore di missioni su più turni per i compagni IA.
##
## Ogni personaggio (tranne Frodo) riceve una missione che dura finché non è compiuta o non serve più:
##   conquista  — prendere una roccaforte: radunare truppe, portarle sul posto, attaccare, spendere 3 Valore;
##   esercito   — riunire in un luogo le truppe richieste da un obiettivo (es. Sfidare Sauron: 2+2+3);
##   azione     — andare nel luogo dell'obiettivo (con un compagno se serve) e pagarne il costo;
##   compagno   — fare da secondo personaggio per un'azione in due;
##   liberare   — togliere le truppe ombra da una regione (es. Rohan per Saruman);
##   difesa     — correre a un rifugio che sta per cadere e rinforzarlo.
## Ogni missione propone l'azione del passo corrente; se nessuna azione utile è disponibile, decide l'IA normale.

var _ia_w: WeakRef
## L'IA che usa le missioni (per distanze e rischi); riferimento debole, per non creare cicli.
var ia:
	get:
		return _ia_w.get_ref() if _ia_w != null else null
	set(v):
		_ia_w = weakref(v)
var assegnate := {}        # pg -> missione {tipo, luogo, cod, ...}
var _turno_assegnazione := -1
var note: Array = []       # spiegazioni brevi per il registro

const COLORE_GRATIS := {"arwen": "elfi", "boromir": "gondor", "eowyn": "rohirrim", "gimli": "nani"}
const CONQUISTE := {"saruman": "isengard", "morgul": "minas_morgul", "anduin": "osgiliath", "umbar": "umbar",
	"pozzi": "dol_guldur", "balin": "moria", "freca": "dunland"}
## truppe da avere nel luogo dopo la conquista (o per compiere l'obiettivo)
const TRUPPE_OBIETTIVO := {"sauron": {"luogo": "north_ithilien", "truppe": {"rohirrim": 2, "elfi": 2, "gondor": 3}},
	"pozzi": {"luogo": "dol_guldur", "truppe": {"elfi": 3}}, "balin": {"luogo": "moria", "truppe": {"nani": 2}},
	"freca": {"luogo": "dunland", "truppe": {"rohirrim": 2}},
	"stendardo": {"luogo": "minas_tirith", "truppe": {"gondor": 1, "rohirrim": 1, "elfi": 1, "nani": 1}}}
const AZIONI := {"benedizione": {"luogo": "rivendell", "costo": {"amicizia": 3}, "due": true},
	"theoden": {"luogo": "edoras", "costo": {"amicizia": 2, "resistenza": 1}, "due": true},
	"denethor": {"luogo": "minas_tirith", "costo": {"furtivita": 2, "amicizia": 1, "valore": 1}, "due": true}}
## chi deve compiere l'obiettivo, se è legato a un personaggio
const CHI := {"pozzi": "galadriel", "anduin": "faramir", "stendardo": "arwen"}


# =====================================================================================
# ASSEGNAZIONE
# =====================================================================================

func aggiorna(m: Motore) -> void:
	if m.turno == _turno_assegnazione:
		return
	_turno_assegnazione = m.turno
	# tolte le missioni finite o non più possibili; finita la difesa si riprende la missione sospesa
	for p in assegnate.keys():
		if p.ends_with("#sospesa"):
			continue
		if not m.in_gioco(p) or not _ancora_valida(m, assegnate[p]):
			assegnate.erase(p)
	for k in assegnate.keys():
		if k.ends_with("#sospesa"):
			var base: String = k.trim_suffix("#sospesa")
			if not assegnate.has(base) and m.in_gioco(base) and _ancora_valida(m, assegnate[k]):
				assegnate[base] = assegnate[k]
				assegnate[base].erase("sospesa")
			if not (assegnate.has(base) and assegnate[base]["tipo"] == "difesa"):
				assegnate.erase(k)
	var liberi: Array = []
	for p in m.pg:
		if m.in_gioco(p) and p != "frodo" and p != "gollum" and not assegnate.has(p):
			liberi.append(p)
	# presidi: i rifugi dove nei prossimi turni arriveranno più truppe ombra di quante ne difendano
	var minacce := minaccia_rifugi(m)
	var hs: Array = minacce.keys()
	hs.sort_custom(func(a, b): return minacce[a] > minacce[b])
	var presidi := 0
	for q in assegnate:
		if not q.ends_with("#sospesa") and assegnate[q]["tipo"] == "presidio":
			presidi += 1
	for h in hs:
		if presidi >= 2 or minacce[h] < 1.5 or _difeso_da_qualcuno(h):
			continue
		var cand: Array = []
		for p in m.pg:
			if m.in_gioco(p) and p != "frodo" and p != "gollum":
				var mi: Dictionary = assegnate.get(p, {})
				if mi.is_empty() or mi["tipo"] in ["liberare_luogo", "liberare", "esercito"] or (mi["tipo"] == "compagno" and m.pg[p]["luogo"] != mi["luogo"]):
					cand.append(p)
		var chi := _vicino(m, h, cand)
		if chi == "" or ia._dist(m.pg[chi]["luogo"]).get(h, 30.0) > 7.0:
			continue
		if assegnate.has(chi):
			assegnate[chi + "#sospesa"] = assegnate[chi]
		assegnate[chi] = {"tipo": "presidio", "luogo": h, "dal": m.turno}
		liberi.erase(chi)
		presidi += 1
		note.append("%s va a presidiare %s." % [m.nome_pg(chi), Dati.nome(h)])
	# rifugi in pericolo: chi è vicino lascia la sua missione (se non è quasi compiuta) e corre a difenderlo
	var rischi: Dictionary = ia._rischi(m)
	for h in rischi:
		if rischi[h] < 0.45 or _difeso_da_qualcuno(h):
			continue
		var chi := ""
		var dmin := 3.5
		for p in m.pg:
			if not m.in_gioco(p) or p == "frodo" or p == "gollum":
				continue
			var mi: Dictionary = assegnate.get(p, {})
			if not mi.is_empty() and (mi["tipo"] == "difesa" or _quasi_fatta(m, p, mi)):
				continue
			var d: float = ia._dist(m.pg[p]["luogo"]).get(h, 30.0)
			if d < dmin:
				dmin = d
				chi = p
		if chi != "":
			if assegnate.has(chi):
				assegnate[chi]["sospesa"] = true
				assegnate[chi + "#sospesa"] = assegnate[chi]
			assegnate[chi] = {"tipo": "difesa", "luogo": h, "dal": m.turno}
			liberi.erase(chi)
			note.append("%s corre a difendere %s." % [m.nome_pg(chi), Dati.nome(h)])
	# obiettivi ancora da compiere: missioni per i personaggi liberi, prima quelli che si chiudono prima
	var lavori: Array = []
	for o in m.obiettivi:
		var cod: String = o["codice"]
		if o["fatto"] or cod == "anello":
			continue
		for mis in _missioni_per(m, cod):
			if not _gia_assegnata(mis):
				lavori.append(mis)
	lavori.sort_custom(func(a, b): return _costo_stimato(m, a) < _costo_stimato(m, b))
	for mis in lavori:
		if liberi.is_empty():
			break
		var chi := _scegli(m, mis, liberi)
		if chi == "":
			continue
		mis["dal"] = m.turno
		assegnate[chi] = mis
		liberi.erase(chi)
		note.append("%s: %s." % [m.nome_pg(chi), descrivi(mis)])
		# le azioni in due: serve un compagno (anche Frodo va bene, se è vicino)
		if mis["tipo"] == "azione" and mis.get("due", false):
			var cand: Array = liberi.duplicate()
			var q := _vicino(m, mis["luogo"], cand)
			# Frodo fa da compagno solo se è già vicino (ogni suo viaggio costa Furtività o una ricerca)
			if m.in_gioco("frodo") and not _frodo_occupato(m):
				var df: float = ia._dist(m.pg["frodo"]["luogo"]).get(mis["luogo"], 30.0)
				var dq: float = ia._dist(m.pg[q]["luogo"]).get(mis["luogo"], 30.0) if q != "" else 30.0
				if df <= 2.5 or (q == "" and df <= 5.0) or df + 3.0 < dq:
					q = "frodo"
			if q != "":
				assegnate[q] = {"tipo": "compagno", "luogo": mis["luogo"], "cod": mis["cod"], "di": chi, "dal": m.turno}
				liberi.erase(q)
	# fase finale: tutti gli altri obiettivi compiuti, si portano a Frodo le carte Resistenza
	var finale := true
	for o in m.obiettivi:
		if o["codice"] != "anello" and not o["fatto"]:
			finale = false
	if finale and m.in_gioco("frodo") and not m.solo:
		for p in liberi.duplicate():
			if m.posto_di(p) != m.posto_di("frodo") and _ha_resistenza(m, m.posto_di(p)):
				assegnate[p] = {"tipo": "rifornire", "luogo": m.luogo_frodo(), "dal": m.turno}
				liberi.erase(p)
	# chi resta libero va a fermare l'Ombra dove minaccia di più un rifugio
	for p in liberi:
		var b := _pila_minacciosa(m, p)
		if b != "":
			assegnate[p] = {"tipo": "liberare_luogo", "luogo": b, "dal": m.turno}


## Truppe ombra attese nei prossimi 3 turni in ogni rifugio, meno i difensori: le pile fino a 3 passi
## indietro sulle linee di battaglia arrivano con la probabilità che la linea avanzi abbastanza volte.
func minaccia_rifugi(m: Motore) -> Dictionary:
	var pl: Dictionary = ia._prob_linee(m)
	var r := {}
	for lid in pl:
		var per: Array = Dati.linea(lid)["percorso"]
		var q: float = minf(1.0, pl[lid])
		for k in range(1, per.size()):
			var h: String = per[k]
			if not m.e_rifugio(h):
				continue
			var att := 0.0
			for passi in range(1, mini(3, k) + 1):
				var o: int = m.stato[per[k - passi]]["ombra"]
				if o <= 0:
					continue
				# avanzate attese in 3 turni: 3*q; arrivo se almeno "passi" avanzate
				var atteso := 3.0 * q
				att += float(o) * clampf(atteso / float(passi), 0.0, 1.0)
			if att > 0.0:
				r[h] = r.get(h, 0.0) + att
	for h in r.keys():
		r[h] = r[h] + float(m.stato[h]["ombra"]) - float(m.amiche(h)) * 1.2
		if r[h] <= 0.0:
			r.erase(h)
	return r


func _missioni_per(m: Motore, cod: String) -> Array:
	var r: Array = []
	if AZIONI.has(cod):
		var a: Dictionary = AZIONI[cod]
		r.append({"tipo": "azione", "cod": cod, "luogo": a["luogo"], "costo": a["costo"], "due": a["due"]})
	if CONQUISTE.has(cod) and not m.e_rifugio(CONQUISTE[cod]):
		r.append({"tipo": "conquista", "cod": cod, "luogo": CONQUISTE[cod]})
	if TRUPPE_OBIETTIVO.has(cod):
		var t: Dictionary = TRUPPE_OBIETTIVO[cod]
		r.append({"tipo": "esercito", "cod": cod, "luogo": t["luogo"], "truppe": t["truppe"]})
		# Sfidare Sauron: l'esercito è grande, ci lavorano in due
		if cod == "sauron":
			r.append({"tipo": "esercito", "cod": cod, "luogo": t["luogo"], "truppe": t["truppe"], "secondo": true})
	if cod == "saruman":
		r.append({"tipo": "liberare", "cod": cod, "regione": "rohan", "luogo": "edoras"})
	if cod == "eowyn":
		r.append({"tipo": "liberare", "cod": cod, "regione": "rohan", "luogo": "edoras"})
	return r


func _ancora_valida(m: Motore, mi: Dictionary) -> bool:
	if mi.has("cod") and not m.obiettivo_attivo(mi["cod"]):
		return false
	match mi["tipo"]:
		"conquista":
			return not m.e_rifugio(mi["luogo"])
		"esercito":
			return _deficit(m, mi, "").values().reduce(func(a, b): return a + b, 0) > 0 or m.obiettivo_attivo(mi["cod"])
		"liberare":
			return not m.regione_libera(mi["regione"])
		"liberare_luogo":
			return m.stato[mi["luogo"]]["ombra"] > 0 and m.turno - int(mi["dal"]) < 5
		"presidio":
			return m.e_rifugio(mi["luogo"]) and minaccia_rifugi(m).get(mi["luogo"], 0.0) > 0.3 and m.turno - int(mi["dal"]) < 6
		"difesa":
			var r: float = ia._rischi(m).get(mi["luogo"], 0.0)
			return m.e_rifugio(mi["luogo"]) and (r > 0.15 or m.turno - int(mi["dal"]) < 2)
		"rifornire":
			return m.in_gioco("frodo") and _ha_resistenza(m, m.posto_di(_chi_di(mi)))
		"compagno":
			return assegnate.has(mi["di"]) and assegnate[mi["di"]].get("cod", "") == mi["cod"] and assegnate[mi["di"]]["tipo"] == "azione"
	return true


func _ha_resistenza(m: Motore, pos: int) -> bool:
	for id in m.giocatori[pos]["mano"]:
		var c := Dati.carta(id)
		if c.get("tipo", "") == "regione" and c["simbolo"] == "resistenza":
			return true
	return false


func _gia_assegnata(mis: Dictionary) -> bool:
	for p in assegnate:
		if p.ends_with("#sospesa"):
			continue
		var a: Dictionary = assegnate[p]
		if a.get("cod", "") == mis.get("cod", "") and a["tipo"] == mis["tipo"] and a.get("secondo", false) == mis.get("secondo", false):
			return true
	return false


func _chi_di(mi: Dictionary) -> String:
	for q in assegnate:
		if assegnate[q] == mi:
			return q
	return ""


func _difeso_da_qualcuno(h: String) -> bool:
	for p in assegnate:
		if p.ends_with("#sospesa"):
			continue
		if assegnate[p]["tipo"] in ["difesa", "presidio"] and assegnate[p]["luogo"] == h:
			return true
	return false


func _frodo_occupato(m: Motore) -> bool:
	return assegnate.has("frodo")


func _quasi_fatta(m: Motore, p: String, mi: Dictionary) -> bool:
	return m.pg[p]["luogo"] == mi.get("luogo", "") and mi["tipo"] in ["azione", "conquista"]


## Turni stimati per compiere la missione (per fare prima quelle che si chiudono prima).
func _costo_stimato(m: Motore, mi: Dictionary) -> float:
	var best := 30.0
	for p in m.pg:
		if m.in_gioco(p) and p != "frodo" and p != "gollum":
			best = minf(best, ia._dist(m.pg[p]["luogo"]).get(mi["luogo"], 30.0))
	var c := best / 4.0
	match mi["tipo"]:
		"conquista":
			c += 1.5 + float(m.stato[mi["luogo"]]["ombra"]) * 0.4
		"esercito":
			c += float(_deficit(m, mi, "").values().reduce(func(a, b): return a + b, 0)) * 0.5
		"azione":
			c += 0.5
		"liberare":
			c += 6.0
	return c


func _scegli(m: Motore, mi: Dictionary, liberi: Array) -> String:
	if CHI.has(mi.get("cod", "")) and mi["tipo"] != "esercito":
		var c: String = CHI[mi["cod"]]
		return c if c in liberi else ""
	var best := ""
	var bv := 1e9
	for p in liberi:
		var d: float = ia._dist(m.pg[p]["luogo"]).get(mi["luogo"], 30.0)
		# chi recluta gratis le truppe che servono è molto più utile
		if mi["tipo"] in ["conquista", "esercito", "liberare"]:
			var col: String = COLORE_GRATIS.get(p, "")
			if col != "" and (mi["tipo"] != "esercito" or mi["truppe"].has(col)):
				d -= 4.0
			if p == "gandalf":
				d -= 2.0
		if d < bv:
			bv = d
			best = p
	return best


func _vicino(m: Motore, l: String, cand: Array) -> String:
	var best := ""
	var bv := 1e9
	for p in cand:
		var d: float = ia._dist(m.pg[p]["luogo"]).get(l, 30.0)
		if d < bv:
			bv = d
			best = p
	return best


func _pila_minacciosa(m: Motore, p: String) -> String:
	var pl: Dictionary = ia._prob_linee(m)
	var best := ""
	var bv := 0.0
	for lid in pl:
		var per: Array = Dati.linea(lid)["percorso"]
		for k in range(0, per.size() - 1):
			var o: int = m.stato[per[k]]["ombra"]
			if o < 2 or m.e_fortezza(per[k]):
				continue
			var d: float = ia._dist(m.pg[p]["luogo"]).get(per[k], 30.0)
			var v: float = float(o) * pl[lid] / (1.0 + d * 0.3)
			if v > bv:
				bv = v
				best = per[k]
	return best


func descrivi(mi: Dictionary) -> String:
	match mi.get("tipo", ""):
		"conquista":
			return "conquistare %s" % Dati.nome(mi["luogo"])
		"esercito":
			var parti: Array = []
			for a in mi["truppe"]:
				parti.append("%d %s" % [mi["truppe"][a], Dati.NOMI_ARMATE[a]])
			return "portare %s a %s" % [", ".join(parti), Dati.nome(mi["luogo"])]
		"azione":
			return "compiere «%s» a %s" % [Dati.obiettivo(mi["cod"])["nome"], Dati.nome(mi["luogo"])]
		"compagno":
			return "accompagnare a %s" % Dati.nome(mi["luogo"])
		"liberare":
			return "liberare %s dall'Ombra" % Dati.nome_regione(mi["regione"])
		"liberare_luogo":
			return "fermare l'Ombra a %s" % Dati.nome(mi["luogo"])
		"difesa":
			return "difendere %s" % Dati.nome(mi["luogo"])
		"presidio":
			return "presidiare %s" % Dati.nome(mi["luogo"])
	return ""


# =====================================================================================
# ESECUZIONE: l'azione del passo corrente (indice nelle opzioni, -1 = decide l'IA normale)
# =====================================================================================

func azione(m: Motore, p: String, op: Array) -> int:
	var mi: Dictionary = assegnate.get(p, {})
	if mi.is_empty():
		return -1
	var l: String = m.pg[p]["luogo"]
	# l'obiettivo si compie appena si può
	for k in op.size():
		var c: String = op[k]["chiave"]
		if c.begins_with("ob_") and c != "ob_anello" and c != "ob_balrog" and c != "ob_shelob":
			return k
	match mi["tipo"]:
		"conquista":
			return _passo_conquista(m, p, op, mi, l)
		"esercito":
			return _passo_esercito(m, p, op, mi, l)
		"rifornire":
			var lf: String = m.luogo_frodo()
			if l == lf:
				for k in op.size():
					if op[k]["chiave"] == "compagnia" and op[k]["con"] == "frodo":
						return k
				return -1
			return _viaggia_verso(m, p, op, lf)
		"azione", "compagno":
			if l == mi["luogo"]:
				# una carta che serve all'obiettivo può passare di mano con la Compagnia
				var kc := _compagnia_utile(m, p, op, mi)
				if kc >= 0:
					return kc
				# sul posto si aspetta il compagno (o le carte), rinforzando il rifugio se si può
				var k := _trova(op, "arruola")
				if k >= 0 and m.amiche(l) < 3 and _amicizia_avanza(m, p, mi):
					return k
				return _trova(op, "fine")
			return _viaggia_verso(m, p, op, mi["luogo"])
		"liberare":
			return _passo_liberare(m, p, op, mi, l)
		"liberare_luogo":
			return _passo_attacco(m, p, op, mi["luogo"], l)
		"difesa", "presidio":
			var h: String = mi["luogo"]
			if l == h:
				var k := _trova(op, "arruola")
				if k >= 0 and (mi["tipo"] == "difesa" or _puo_reclutare_ora(m, p, l)):
					return k
				k = _attacco_buono(m, op, l)
				if k >= 0:
					return k
				return -1
			return _viaggia_verso(m, p, op, h)
	return -1


## Compagnia che porta al giocatore che compie l'azione un simbolo che gli manca.
func _compagnia_utile(m: Motore, p: String, op: Array, mi: Dictionary) -> int:
	var attore: String = p if mi["tipo"] == "azione" else mi.get("di", "")
	if attore == "" or not assegnate.has(attore):
		return -1
	var costo: Dictionary = assegnate[attore].get("costo", {})
	var pa := m.posto_di(attore)
	var reg := Dati.regione(m.pg[p]["luogo"])
	for k in op.size():
		if op[k]["chiave"] != "compagnia":
			continue
		var q: String = op[k]["con"]
		var altro := m.posto_di(q) if m.posto_di(p) == pa else m.posto_di(p)
		if altro == pa:
			continue
		for s in costo:
			if m.disponibili(pa, s) >= int(costo[s]):
				continue
			for id in m.giocatori[altro]["mano"]:
				var c := Dati.carta(id)
				if c.get("tipo", "") == "regione" and c["simbolo"] == s and c["regione"] == reg:
					return k
	return -1


func _amicizia_avanza(m: Motore, p: String, mi: Dictionary) -> bool:
	var serve: int = int(mi.get("costo", {}).get("amicizia", 0)) if mi["tipo"] == "azione" else 0
	return m.disponibili(m.posto_di(p), "amicizia") > serve or COLORE_GRATIS.get(p, "") == Dati.luogo(m.pg[p]["luogo"])["arruolo"]


func _passo_conquista(m: Motore, p: String, op: Array, mi: Dictionary, l: String) -> int:
	var t: String = mi["luogo"]
	if l == t:
		var k := _trova(op, "conquista")
		if k >= 0:
			return k
		if m.stato[t]["ombra"] > 0 and m.amiche(t) > 0:
			return _attacco_max(op)
		if m.stato[t]["ombra"] == 0 and m.amiche(t) > 0:
			return _trova(op, "fine")   # manca il Valore: si tiene la posizione
		# niente truppe: tornare a prenderne
		return _verso_reclutamento(m, p, op, _colore_utile(m, p, {}))
	var forza: int = m.amiche(l)
	var serve: int = clampi(m.stato[t]["ombra"] + 2, 2, 6)
	if forza >= serve:
		return _viaggia_verso(m, p, op, t)
	var k := _trova(op, "arruola")
	if k >= 0 and _puo_reclutare_ora(m, p, l):
		return k
	return _verso_reclutamento(m, p, op, _colore_utile(m, p, {}))


func _deficit(m: Motore, mi: Dictionary, p: String) -> Dictionary:
	var t: String = mi["luogo"]
	var d := {}
	for a in mi["truppe"]:
		d[a] = maxi(0, int(mi["truppe"][a]) - int(m.stato[t]["truppe"][a]))
	# le truppe che altri personaggi della stessa missione stanno già portando
	for q in assegnate:
		if q == p or q.ends_with("#sospesa") or not m.in_gioco(q):
			continue
		var a2: Dictionary = assegnate[q]
		if a2["tipo"] == "esercito" and a2.get("cod", "") == mi.get("cod", "") and m.pg[q]["luogo"] != t:
			for a in d:
				d[a] = maxi(0, d[a] - int(m.stato[m.pg[q]["luogo"]]["truppe"][a]))
	return d


func _passo_esercito(m: Motore, p: String, op: Array, mi: Dictionary, l: String) -> int:
	var t: String = mi["luogo"]
	var d := _deficit(m, mi, p)
	var mancano := 0
	var con_me := 0
	for a in d:
		mancano += d[a]
		if l != t:
			con_me += mini(d[a], int(m.stato[l]["truppe"][a]))
	if l == t:
		if mancano == 0:
			return _trova(op, "fine")
		# le truppe ombra sul posto vanno tolte prima
		var k := _attacco_buono(m, op, l)
		if k >= 0:
			return k
	if mancano > 0 and con_me >= mancano:
		return _viaggia_verso(m, p, op, t)
	# un colore che manca ancora (oltre a quelli che ho già con me)
	var colori := {}
	for a in d:
		var resta: int = d[a] - (int(m.stato[l]["truppe"][a]) if l != t else 0)
		if resta > 0:
			colori[a] = resta
	if colori.is_empty():
		return _viaggia_verso(m, p, op, t)
	var col_qui: String = Dati.luogo(l)["arruolo"]
	if colori.has(col_qui):
		var k := _trova(op, "arruola")
		if k >= 0 and _puo_reclutare_ora(m, p, l):
			return k
	return _verso_reclutamento(m, p, op, _colore_utile(m, p, colori))


func _passo_liberare(m: Motore, p: String, op: Array, mi: Dictionary, l: String) -> int:
	# la pila dell'Ombra più grande della regione (non nelle roccaforti, che sono un'altra missione)
	var best := ""
	var bv := 0
	for x in Dati.d()["regioni"][mi["regione"]]["luoghi"]:
		if m.stato[x]["ombra"] > bv and not m.e_fortezza(x):
			bv = m.stato[x]["ombra"]
			best = x
	if best == "":
		return -1
	return _passo_attacco(m, p, op, best, l)


## Andare dove c'è l'Ombra con abbastanza truppe e attaccarla.
func _passo_attacco(m: Motore, p: String, op: Array, t: String, l: String) -> int:
	if l == t:
		var k := _attacco_buono(m, op, l)
		if k >= 0:
			return k
		k = _trova(op, "arruola")
		if k >= 0 and _puo_reclutare_ora(m, p, l):
			return k
		return -1
	var serve: int = clampi(m.stato[t]["ombra"] + 1, 2, 5)
	if m.amiche(l) >= serve:
		return _viaggia_verso(m, p, op, t)
	var k := _trova(op, "arruola")
	if k >= 0 and _puo_reclutare_ora(m, p, l):
		return k
	return _verso_reclutamento(m, p, op, _colore_utile(m, p, {}))


# -------------------------------------------------------------------------------------

func _trova(op: Array, chiave: String) -> int:
	for k in op.size():
		if op[k]["chiave"] == chiave:
			return k
	return -1


func _attacco_max(op: Array) -> int:
	var best := -1
	var n := 0
	for k in op.size():
		if op[k]["chiave"] == "attacca" and int(op[k]["dadi"]) > n:
			n = int(op[k]["dadi"])
			best = k
	return best


## Attacco che conviene: truppe amiche almeno pari a quelle ombra, con meno dadi se ci sono Nazgûl.
func _attacco_buono(m: Motore, op: Array, l: String) -> int:
	var am := m.amiche(l)
	var o: int = m.stato[l]["ombra"]
	if o == 0 or am == 0:
		return -1
	if am < o and m.e_rifugio(l):
		return -1   # in un rifugio conviene aspettare: Invadere non colpisce, si arruola prima
	var nd := mini(3, am)
	if m.nazgul[Dati.regione(l)] > 0 and am <= 2:
		nd = 1
	for k in op.size():
		if op[k]["chiave"] == "attacca" and int(op[k]["dadi"]) == nd:
			return k
	return _attacco_max(op)


func _puo_reclutare_ora(m: Motore, p: String, l: String) -> bool:
	var col: String = Dati.luogo(l)["arruolo"]
	if col == "" or m.riserva_truppe[col] <= 0:
		return false
	if m._arruolo_gratis(p, col):
		return true
	# un'Amicizia si spende solo se ne resta per l'obiettivo in corso
	var serve := 0
	for q in assegnate:
		var a: Dictionary = assegnate[q]
		if a["tipo"] == "azione" and not q.ends_with("#sospesa") and m.in_gioco(q) and m.posto_di(q) == m.posto_di(p):
			serve += int(a.get("costo", {}).get("amicizia", 0))
	return m.disponibili(m.posto_di(p), "amicizia") > serve


func _colore_utile(m: Motore, p: String, colori: Dictionary) -> String:
	var gr: String = COLORE_GRATIS.get(p, "")
	if colori.is_empty():
		return gr
	if gr != "" and colori.has(gr):
		return gr
	var best := ""
	var bv := -1
	for a in colori:
		if colori[a] > bv:
			bv = colori[a]
			best = a
	return best


## Verso il luogo di reclutamento più vicino del colore (qualsiasi colore se vuoto).
func _verso_reclutamento(m: Motore, p: String, op: Array, col: String) -> int:
	var l: String = m.pg[p]["luogo"]
	var dist: Dictionary = ia._dist(l)
	var best := ""
	var bv := 1e9
	for x in m.stato:
		var c: String = Dati.luogo(x)["arruolo"]
		if c == "" or m.e_fortezza(x) or m.riserva_truppe[c] <= 0:
			continue
		if col != "" and c != col:
			continue
		if not m._arruolo_gratis(p, c) and m.disponibili(m.posto_di(p), "amicizia") <= 0:
			continue
		var d: float = dist.get(x, 30.0) + float(m.stato[x]["ombra"]) * 2.0
		if d < bv:
			bv = d
			best = x
	if best == "":
		return -1
	if best == l:
		return _trova(op, "arruola")
	return _viaggia_verso(m, p, op, best)


## Il viaggio che avvicina di più alla destinazione (solo sentieri che si possono pagare senza svenarsi).
func _viaggia_verso(m: Motore, p: String, op: Array, dest: String) -> int:
	var dd: Dictionary = ia._dist(dest)
	var qui: float = dd.get(m.pg[p]["luogo"], 30.0)
	var best := -1
	var bv := qui - 0.01
	for k in op.size():
		var o: Dictionary = op[k]
		if o["chiave"] != "viaggio":
			continue
		var costo := 0
		for s in o["costo"]:
			costo += int(o["costo"][s])
		if costo > 1:
			continue
		var v: float = dd.get(o["luogo"], 30.0) + float(costo) * 0.8
		if p == "frodo":
			# Frodo non entra dove la ricerca tirerebbe dadi, se non può spendere Furtività
			var dadi: int = m.nazgul[Dati.regione(o["luogo"])] + int(m.stato[o["luogo"]]["ombra"])
			if dadi > 0 and m.disponibili(m.posto_di("frodo"), "furtivita") <= 0:
				continue
			if dadi >= 3:
				continue
		if v < bv:
			bv = v
			best = k
	return best


## Simboli che un giocatore deve tenere per le missioni (costi delle azioni-obiettivo, 3 Valore per le conquiste).
func riservati(m: Motore, pos: int) -> Dictionary:
	var r := {}
	for q in assegnate:
		if q.ends_with("#sospesa") or not m.in_gioco(q) or m.posto_di(q) != pos:
			continue
		var a: Dictionary = assegnate[q]
		if a["tipo"] == "azione":
			for s in a["costo"]:
				r[s] = int(r.get(s, 0)) + int(a["costo"][s])
		elif a["tipo"] == "conquista":
			r["valore"] = int(r.get("valore", 0)) + 3
	return r


## Un'opzione che spenderebbe simboli tenuti da parte per una missione.
func spreca(m: Motore, p: String, o: Dictionary) -> bool:
	var costo := {}
	match o["chiave"]:
		"distrarre", "amico_leale":
			costo = {"amicizia": 1} if o["chiave"] == "distrarre" else {}
		"tiro_sicuro", "tiro_nazgul", "signora_luce":
			costo = {"furtivita": 1}
		"canzone":
			costo = {"amicizia": 3}
		"arruola":
			if not m._arruolo_gratis(p, Dati.luogo(m.pg[p]["luogo"])["arruolo"]):
				costo = {"amicizia": 1}
		"viaggio", "conquista":
			costo = o.get("costo", {})
	if costo.is_empty():
		return false
	var pos := m.posto_di(p)
	if o["chiave"] in ["distrarre", "tiro_sicuro", "tiro_nazgul", "signora_luce"]:
		pos = m.posto_di("pipino" if o["chiave"] == "distrarre" else ("galadriel" if o["chiave"] == "signora_luce" else "legolas"))
	var ris := riservati(m, pos)
	for s in costo:
		if ris.has(s) and m.disponibili(pos, s) - int(costo[s]) < int(ris[s]):
			# la conquista e il viaggio della missione stessa possono spendere
			if o["chiave"] == "conquista":
				return false
			return true
	return false


# =====================================================================================
# TRUPPE AL SEGUITO E RIPARTIZIONE DEL TURNO
# =====================================================================================

## Quali truppe porta con sé chi viaggia per la sua missione: {armata: quante} oppure {} (nessuna preferenza).
func truppe_da_portare(m: Motore, p: String, dest: String) -> Dictionary:
	var mi: Dictionary = assegnate.get(p, {})
	if mi.is_empty():
		return {}
	var da: String = m.pg[p]["luogo"]
	var verso: String = mi.get("luogo", "")
	if mi["tipo"] == "liberare":
		verso = dest
	var dd: Dictionary = ia._dist(verso)
	if dd.get(dest, 30.0) >= dd.get(da, 30.0) and dest != verso:
		return {"_niente": 0}
	# in un rifugio minacciato resta almeno una truppa
	var tenere := 0
	if m.e_rifugio(da):
		tenere = 1 if ia._rischi(m).get(da, 0.0) < 0.3 else 2
	var r := {}
	match mi["tipo"]:
		"esercito":
			var d := _deficit(m, mi, p)
			for a in d:
				r[a] = mini(d[a], int(m.stato[da]["truppe"][a]))
		"presidio":
			# si portano truppe solo da luoghi che non sono rifugi minacciati
			var n := maxi(0, m.amiche(da) - tenere - (1 if minaccia_rifugi(m).has(da) else 0))
			for a in Dati.ARMATE:
				var q := mini(n, int(m.stato[da]["truppe"][a]))
				if q > 0:
					r[a] = q
					n -= q
		"conquista", "liberare", "liberare_luogo", "difesa":
			var n := maxi(0, m.amiche(da) - tenere)
			for a in Dati.ARMATE:
				var q := mini(n, int(m.stato[da]["truppe"][a]))
				if q > 0:
					r[a] = q
					n -= q
		_:
			return {"_niente": 0}
	return r


## Peso di un personaggio per avere le 4 azioni del turno (più alto = più urgente).
func urgenza(m: Motore, p: String) -> float:
	var mi: Dictionary = assegnate.get(p, {})
	if mi.is_empty():
		return 0.0
	var d: float = ia._dist(m.pg[p]["luogo"]).get(mi.get("luogo", m.pg[p]["luogo"]), 30.0)
	match mi["tipo"]:
		"difesa":
			return 10.0 + ia._rischi(m).get(mi["luogo"], 0.0) * 5.0
		"presidio":
			return 6.5 + minaccia_rifugi(m).get(mi["luogo"], 0.0)
		"azione":
			return 6.0 if d > 0 else 3.0
		"conquista", "esercito":
			return 7.0
		"compagno":
			return 5.0 if d > 0 else 0.5
		"liberare", "liberare_luogo":
			return 5.0
	return 1.0
