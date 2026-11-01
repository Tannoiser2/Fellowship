class_name IA
extends RefCounted
## Compagni IA: scelgono con regole pratiche, guardando lo stato della partita.
##
## Strategia: Frodo resta al sicuro nei rifugi e si avvicina a Minas Tirith raccogliendo Resistenza
## (le carte gliele passano gli altri con la Compagnia); gli altri personaggi difendono i rifugi minacciati,
## conquistano fortezze e completano gli obiettivi. Quando restano solo «Distruggere l'Anello» e Frodo ha
## 5 Resistenza, Frodo entra a Mordor per la strada più economica in Furtività.

var pausa := 0.35


func decide(m: Motore, posto: int, req: Dictionary):
	if pausa > 0.0 and m.is_inside_tree():
		await m.get_tree().create_timer(pausa).timeout
	return scegli(m, posto, req)


func scegli(m: Motore, posto: int, req: Dictionary) -> int:
	var op: Array = req.get("opzioni", [])
	if op.is_empty():
		return 0
	match req.get("tipo", ""):
		"piano":
			return _piano(m, op)
		"azione":
			return _azione(m, req, op)
		"accompagna":
			return _accompagna(m, req, op)
		"paga":
			return _paga(m, posto, op, req.get("simbolo", ""))
		"scarta":
			return _scarta(m, posto, op)
		"battaglia":
			return _battaglia(m, req, op)
		"ricerca":
			return _ricerca(m, op)
		"furtivita_frodo":
			# spende Furtività solo se la ricerca tirerebbe dadi e ne resta per Mordor
			var n := m.dadi_ricerca()
			var dest: String = req.get("luogo", m.luogo_frodo())
			var furt := m.disponibili(m.turno_di, "furtivita")
			var serve_mordor := 5 if _fase_finale(m) else 0
			if n >= 1 and furt > serve_mordor:
				return 0
			if n >= 3 and furt > 0:
				return 0
			return 1
		"anello_ricerca":
			return 0 if m.stato[m.luogo_frodo()]["ombra"] >= 3 and m.speranza >= 4 else 1
		"imboscata", "battaglia_facoltativa":
			return 0
		"perdita":
			var best := 0
			var n := -1
			var l: String = req.get("luogo", "")
			for k in op.size():
				var a: String = op[k]["armata"]
				var c: int = 0
				for x in m.stato:
					c += int(m.stato[x]["truppe"][a])
				if c > n:
					n = c
					best = k
			return best
		"compagnia":
			return _compagnia(m, op)
		"libera":
			return _libera(m, op)
		"consiglio":
			return 1
		"ordina":
			return 0
		"nazgul":
			return _nazgul(m, op)
	# scelte degli eventi e altro: prima opzione utile
	return _generica(m, req, op)


# -------------------------------------------------------------------------------------

## Distanze pesate: i percorsi speciali costano come i simboli da spendere.
var _cache_dist := {}


func _dist(a: String) -> Dictionary:
	if _cache_dist.has(a):
		return _cache_dist[a]
	var d := {a: 0.0}
	var aperti := [a]
	while not aperti.is_empty():
		var best := 0
		for k in aperti.size():
			if d[aperti[k]] < d[aperti[best]]:
				best = k
		var x: String = aperti.pop_at(best)
		for y in Dati.vicini(x):
			var e: Dictionary = Dati.collegamento(x, y)
			var w := 1.0
			for s in e["costo"]:
				w += float(e["costo"][s]) * 1.3
			if not d.has(y) or d[x] + w < d[y]:
				d[y] = d[x] + w
				if not aperti.has(y):
					aperti.append(y)
	_cache_dist[a] = d
	return d


func _fase_finale(m: Motore) -> bool:
	for o in m.obiettivi:
		if o["codice"] != "anello" and not o["fatto"]:
			return false
	return true


func _resistenza_compagnia(m: Motore) -> int:
	return m.disponibili(m.posto_di("frodo"), "resistenza") if m.in_gioco("frodo") else 0


func _piano(m: Motore, op: Array) -> int:
	# il personaggio più utile fa 4 azioni
	var best := 0
	var bv := -1e9
	for k in op.size():
		var p: String = op[k]["pg"]
		var n: int = op[k]["n"]
		var v: float = _utilita_pg(m, p) * (1.0 if n == 4 else 0.25)
		# Frodo: 4 azioni solo nella fase finale
		if p == "frodo" and n == 4 and not _fase_finale(m):
			var pf := _pericolo(m, m.regione_frodo())
			v += pf * 2.0 - 5.0
		if v > bv:
			bv = v
			best = k
	return best


func _utilita_pg(m: Motore, p: String) -> float:
	if p == "frodo":
		return 6.0 if _fase_finale(m) else 1.0
	var t := _obiettivo_pg(m, p)
	return 3.0 + float(t.get("v", 0.0))


## Luogo verso cui conviene andare per il personaggio (con un valore).
func _obiettivo_pg(m: Motore, p: String) -> Dictionary:
	var l: String = m.pg[p]["luogo"]
	var dist := _dist(l)
	var best := {"luogo": l, "v": 0.0}
	var bv := -1e9
	for x in _bersagli(m, p):
		var d: float = dist.get(x["luogo"], 30.0)
		var v: float = x["v"] / (1.0 + d * 0.7)
		if v > bv:
			bv = v
			best = {"luogo": x["luogo"], "v": v}
	return best


func _punteggio_frodo(m: Motore, l: String, dt: Dictionary) -> float:
	var k: float = 0.8 + _pericolo(m, m.regione_frodo()) * 0.25
	var v: float = -_pericolo(m, Dati.regione(l)) * 2.0 - float(dt.get(l, 30)) * k - float(m.stato[l]["ombra"]) * 1.0
	if m.e_rifugio(l):
		v += 0.6
	return v


func _dadi_in(m: Motore, l: String) -> int:
	return mini(7, m.nazgul[Dati.regione(l)] + m.stato[l]["ombra"])


func _pericolo(m: Motore, r: String) -> float:
	return float(m.nazgul[r]) * 1.5 + (2.5 if m.occhio == r else 0.0)


func _bersagli(m: Motore, p: String) -> Array:
	var r: Array = []
	if p == "frodo":
		if _fase_finale(m) and _resistenza_compagnia(m) >= 5:
			r.append({"luogo": "mount_doom", "v": 60.0})
			return r
		var dm := _dist("mount_doom")
		for h in m.stato:
			if not m.e_rifugio(h) or m.stato[h]["ombra"] > 0:
				continue
			var reg := Dati.regione(h)
			var v: float = 10.0 - _pericolo(m, reg) * 1.6 - float(dm.get(h, 20)) * (0.45 if _fase_finale(m) else 0.2)
			r.append({"luogo": h, "v": max(0.5, v)})
		return r
	# rifugi minacciati
	for l in m.stato:
		var o: int = m.stato[l]["ombra"]
		if m.e_rifugio(l):
			var vic := 0
			for v in Dati.vicini(l):
				vic += int(m.stato[v]["ombra"])
			var pericolo: float = o * 2.0 + vic * 0.6 - m.amiche(l) * 0.8
			if pericolo > 0.5:
				r.append({"luogo": l, "v": 2.0 + pericolo})
		elif o > 0 and m.amiche(l) > 0 and p != "gollum":
			r.append({"luogo": l, "v": 1.5 + o * 0.5})
		# fortezze da conquistare
		if m.e_fortezza(l) and p != "gollum":
			var v: float = 2.5 if o <= 1 else 1.0
			if l in ["isengard", "moria", "dol_guldur", "umbar", "minas_morgul"]:
				v += 1.5
			r.append({"luogo": l, "v": v})
	# attaccare lontano da Frodo per distogliere l'Occhio
	if m.occhio == m.regione_frodo() and p != "gollum":
		for l in m.stato:
			if m.stato[l]["ombra"] > 0 and Dati.regione(l) != m.regione_frodo():
				var vicine := m.amiche(l)
				for v in Dati.vicini(l):
					vicine += m.amiche(v)
				if vicine > 0:
					r.append({"luogo": l, "v": 6.0})
	# obiettivi
	for ob in m.obiettivi:
		if ob["fatto"]:
			continue
		match ob["codice"]:
			"benedizione":
				r.append({"luogo": "rivendell", "v": 6.0})
			"theoden":
				r.append({"luogo": "edoras", "v": 6.0})
			"denethor":
				r.append({"luogo": "minas_tirith", "v": 6.0})
			"saruman":
				r.append({"luogo": "isengard", "v": 5.0})
			"balin":
				r.append({"luogo": "moria", "v": 4.0})
			"balrog":
				if p == "gandalf":
					r.append({"luogo": "moria", "v": 9.0})
			"stendardo":
				if p == "arwen":
					r.append({"luogo": "minas_tirith", "v": 7.0})
			"sauron":
				r.append({"luogo": "north_ithilien", "v": 4.0})
			"morgul":
				r.append({"luogo": "minas_morgul", "v": 3.0})
			"anduin":
				r.append({"luogo": "osgiliath", "v": 4.0 if p == "faramir" else 2.0})
			"freca":
				r.append({"luogo": "dunland", "v": 4.0})
			"umbar":
				r.append({"luogo": "umbar", "v": 3.0})
			"pozzi":
				r.append({"luogo": "dol_guldur", "v": 6.0 if p == "galadriel" else 2.5})
			"spergiuri":
				if p == "aragorn" and not m.aragorn_erech:
					r.append({"luogo": "edoras" if m.pg["aragorn"]["luogo"] != "edoras" else "erech", "v": 7.0})
			"hobbit":
				if p == "pipino":
					for h in ["rivendell", "erebor", "helms_deep", "minas_tirith"]:
						if m.e_rifugio(h) and not m.hobbit.has(m._tipo_rifugio(h)):
							r.append({"luogo": h, "v": 5.0})
			"nani":
				r.append({"luogo": "ered_luin", "v": 3.0})
			"bosco_atro":
				r.append({"luogo": "southern_mirkwood", "v": 3.0})
			"raminghi":
				r.append({"luogo": "tharbad", "v": 2.5})
	# avvicinarsi a Frodo per passargli Resistenza
	if m.in_gioco("frodo") and not m.solo and m.posto_di(p) != m.posto_di("frodo"):
		var mie := 0
		for id in m.giocatori[m.posto_di(p)]["mano"]:
			var c := Dati.carta(id)
			if c.get("tipo", "") == "regione" and c["simbolo"] == "resistenza" and c["regione"] == Dati.regione(m.luogo_frodo()):
				mie += 1
		if mie > 0:
			r.append({"luogo": m.luogo_frodo(), "v": 4.0 * mie})
	return r


func _azione(m: Motore, req: Dictionary, op: Array) -> int:
	var p: String = req.get("pg", m.attivo)
	var best := op.size() - 1
	var bv := -1e9
	for k in op.size():
		var v: float = _valore(m, p, op[k])
		if v > bv:
			bv = v
			best = k
	return best


func _valore(m: Motore, p: String, o: Dictionary) -> float:
	var l: String = m.pg[p]["luogo"]
	var pos: int = m.posto_di(p)
	match o["chiave"]:
		"fine":
			return 0.0
		"viaggio":
			var t := _obiettivo_pg(m, p)
			var dt := _dist(t["luogo"])
			var prima: float = dt.get(l, 30.0)
			var dopo: float = dt.get(o["luogo"], 30.0)
			var v: float = float(prima - dopo) * (1.0 + t["v"] * 0.5)
			if p == "frodo":
				v = _punteggio_frodo(m, o["luogo"], dt) - _punteggio_frodo(m, l, dt)
				if m.disponibili(m.turno_di, "furtivita") == 0:
					var dd := _dadi_in(m, o["luogo"])
					v -= float(dd) * (0.42 if m.e_rifugio(o["luogo"]) else 0.55) * (1.0 + 6.0 / float(maxi(1, m.speranza)))
			if not o["costo"].is_empty():
				var tot := 0
				for s in o["costo"]:
					tot += int(o["costo"][s])
				v -= tot * 0.6
				if o["costo"].has("resistenza"):
					v -= 3.0
			if o.get("gratis", false):
				v += 0.5
			return v
		"compagnia":
			var q: String = o["con"]
			# conviene se si può dare Resistenza a chi ha Frodo
			var fp: int = m.posto_di("frodo") if m.in_gioco("frodo") else -1
			if fp == m.posto_di(q) or fp == pos:
				var reg := Dati.regione(l)
				var src: int = pos if fp == m.posto_di(q) else m.posto_di(q)
				for id in m.giocatori[src]["mano"]:
					var c := Dati.carta(id)
					if c.get("tipo", "") == "regione" and c["regione"] == reg and c["simbolo"] == "resistenza":
						return 6.0
			return -1.0
		"prepara":
			var c := Dati.carta(int(o["carta"]))
			var mano: int = m.giocatori[pos]["mano"].size()
			var v: float = 0.1 + maxi(0, mano - 4) * 0.5
			if c["simbolo"] == "furtivita" and m.in_gioco("frodo") and pos == m.posto_di("frodo"):
				v += 1.2 + _pericolo(m, m.regione_frodo()) * 0.3
			if c["simbolo"] == "resistenza":
				v += 1.5 if p == "frodo" or m.solo else -1.0
			if p == "frodo":
				v -= _pericolo(m, Dati.regione(l)) * 0.6
			return v
		"arruola":
			var col: String = Dati.luogo(l)["arruolo"]
			var v: float = 1.2
			if m.e_rifugio(l):
				var vic := 0
				for x in Dati.vicini(l):
					vic += int(m.stato[x]["ombra"])
				v += vic * 0.4 + m.stato[l]["ombra"] * 1.5
			if m._arruolo_gratis(p, col) or p == "gandalf":
				v += 1.0
			if m.amiche(l) >= 4:
				v -= 1.5
			return v
		"attacca":
			var n: int = o["dadi"]
			var v: float = 2.0 + m.stato[l]["ombra"] * 0.4 + n * 0.5
			if m.e_rifugio(l):
				v += 2.0
			if m.occhio == m.regione_frodo() and Dati.regione(l) != m.regione_frodo():
				v += 4.0
			if Dati.regione(l) == m.regione_frodo() and m.occhio != m.regione_frodo():
				v -= 4.0
			if m.nazgul[Dati.regione(l)] > 0 and not m.presente("eowyn", l):
				v -= (n - 1) * 0.6
			return v
		"conquista":
			return 9.0
		"anduril", "arte_nani", "passo_silenzioso", "amico_leale":
			return 2.5
		"canzone":
			return 3.0 + (7 - m.speranza) * 0.6
		"specchio":
			return 0.2
		"strisciante", "eldar":
			return 2.0
		"evento":
			return _valore_evento(m, Dati.carta(int(o["carta"]))["codice"])
		"tiro_sicuro":
			var b: String = o["luogo"]
			if m.e_rifugio(b) and m.stato[b]["ombra"] >= m.amiche(b):
				return 3.0
			if m.obiettivo_attivo("sei"):
				return 1.5
			return -0.5
		"tiro_nazgul":
			return 3.5 if Dati.regione(m.pg["legolas"]["luogo"]) == m.regione_frodo() else -0.5
		"distrarre":
			var r2: String = o["da_regione"]
			var rp := Dati.regione(m.pg["pipino"]["luogo"])
			if r2 == m.regione_frodo() and rp != m.regione_frodo():
				return 3.0
			return -1.0
		"signora_luce":
			return -1.0
		"ob_anello":
			return 100.0
		_:
			if str(o["chiave"]).begins_with("ob_"):
				return 12.0
	return 0.0


func _valore_evento(m: Motore, cod: String) -> float:
	match cod:
		"lembas":
			return 3.0 if m.azioni_rimaste >= 1 else -1.0
		"tom_bombadil":
			return 4.0 if m.speranza <= 4 else -1.0
		"lotte_orchi":
			for l in m.stato:
				if m.e_rifugio(l) and m.stato[l]["ombra"] >= 2:
					return 3.0
			return -1.0
		"doni_elfi":
			return 1.0
	return -2.0


func _accompagna(m: Motore, req: Dictionary, op: Array) -> int:
	var p: String = req.get("pg", "")
	var dest: String = req.get("luogo", "")
	var da: String = m.pg[p]["luogo"] if p != "" else ""
	# porta truppe solo verso una battaglia e se il luogo di partenza non è un rifugio
	var porta: bool = dest != "" and m.stato[dest]["ombra"] > 0
	var portate: int = req.get("portate", 0)
	var tenere := 0
	if m.e_rifugio(da):
		tenere = 1
		for v in Dati.vicini(da):
			if v != dest:
				tenere += int(m.stato[v]["ombra"])
	if portate >= mini(3, m.amiche(da) - tenere):
		porta = false
	if p != "frodo" and m.presente("frodo", da) and m.disponibili(m.turno_di, "furtivita") > 0:
		var t := _obiettivo_pg(m, "frodo")
		var dt := _dist(t["luogo"])
		for k in op.size():
			if op[k]["chiave"] == "pg" and op[k]["pg"] == "frodo" and not req.get("compagni", []).has("frodo"):
				if _punteggio_frodo(m, dest, dt) > _punteggio_frodo(m, da, dt) + 0.5:
					return k
	if porta:
		for k in op.size():
			if op[k]["chiave"] == "truppa":
				return k
	return 0


func _paga(m: Motore, posto: int, op: Array, s: String) -> int:
	var mano: int = m.giocatori[posto]["mano"].size()
	var gettone := -1
	var carta := -1
	for k in op.size():
		if op[k].get("gettone", false):
			gettone = k
		elif carta < 0:
			carta = k
	if s == "resistenza":
		return gettone if gettone >= 0 else carta
	if mano >= 5 and carta >= 0:
		return carta
	return gettone if gettone >= 0 else carta


func _scarta(m: Motore, posto: int, op: Array) -> int:
	var best := 0
	var bv := 1e9
	var conta := {}
	for id in m.giocatori[posto]["mano"]:
		var c := Dati.carta(id)
		if c.get("tipo", "") == "regione":
			conta[c["simbolo"]] = int(conta.get(c["simbolo"], 0)) + 1
	for k in op.size():
		var c := Dati.carta(int(op[k]["carta"]))
		var v: float = 0.0
		if op[k].get("gioca", false):
			v = 5.0 + _valore_evento(m, c["codice"])
		elif c["tipo"] == "evento":
			v = 2.0
		else:
			v = 3.0 - float(conta.get(c["simbolo"], 0)) * 0.5
			if c["simbolo"] == "resistenza":
				v += 4.0
		if v < bv:
			bv = v
			best = k
	return best


func _battaglia(m: Motore, req: Dictionary, op: Array) -> int:
	var l: String = req.get("luogo", "")
	var facce: Array = req.get("facce", [])
	var perdite := 0
	var togli := 0
	for f in facce:
		match f:
			"rotta":
				togli += 1
			"scambio":
				togli += 1
				perdite += 1
			"travolti":
				if not m.e_rifugio(l):
					perdite += 1
			"nazgul":
				if m.nazgul[Dati.regione(l)] > 0:
					perdite += 2
	var ombra_dopo: int = m.stato[l]["ombra"] - togli
	var amiche_dopo: int = m.amiche(l) - perdite
	var cade: bool = m.e_rifugio(l) and ombra_dopo > 0 and amiche_dopo <= 0
	for k in op.size():
		var c: String = op[k]["chiave"]
		if c in ["fiamma", "nenya", "imboscata"]:
			return k
		if cade and c == "valore":
			return k
	if cade:
		for k in op.size():
			if op[k]["chiave"] == "ritira" and _resistenza_compagnia(m) >= 6:
				return k
	return 0


func _ricerca(m: Motore, op: Array) -> int:
	for k in op.size():
		if op[k]["chiave"] == "ramingo":
			return k
	for k in op.size():
		if op[k]["chiave"] == "sam" and m.speranza <= 6:
			return k
		if op[k]["chiave"] == "tom" and m.speranza <= 3:
			return k
	return 0


func _compagnia(m: Motore, op: Array) -> int:
	var fp: int = m.posto_di("frodo") if m.in_gioco("frodo") else -1
	for k in op.size():
		var c := Dati.carta(int(op[k]["carta"]))
		if op[k]["a"] == fp and c["simbolo"] == "resistenza":
			return k
	return 0


func _libera(m: Motore, op: Array) -> int:
	for k in op.size():
		if op[k].get("chiave", "") == "tiro_sicuro":
			var b: String = op[k]["luogo"]
			if m.e_rifugio(b) and m.stato[b]["ombra"] >= m.amiche(b):
				return k
		if op[k].get("chiave", "") == "evento":
			var c := Dati.carta(int(op[k]["carta"]))
			if c["codice"] == "tom_bombadil" and m.speranza <= 3:
				return k
	return 0


func _nazgul(m: Motore, op: Array) -> int:
	# muove i Nazgûl lontano da dove va Frodo: sceglie la regione più lontana da Mordor
	var best := 0
	var bv := -1
	for k in op.size():
		var r: String = op[k].get("regione", "")
		var d := Dati.distanza_regioni(r, "mordor")
		if d > bv:
			bv = d
			best = k
	return best


func _generica(m: Motore, req: Dictionary, op: Array) -> int:
	# per le domande sì/no il «no» è la seconda opzione: l'IA accetta solo se conviene
	if req.get("conferma", false) and op.size() == 2 and op[0].get("si", false):
		return 1
	# scelte di luoghi: il rifugio più minacciato o il luogo con più truppe dell'Ombra
	var best := 0
	var bv := -1e9
	for k in op.size():
		var o: Dictionary = op[k]
		var v: float = 0.0
		if o.has("luogo") and m.stato.has(o["luogo"]):
			var l: String = o["luogo"]
			v = float(m.stato[l]["ombra"]) + (2.0 if m.e_rifugio(l) else 0.0)
		if o.has("pos") and o.has("simbolo"):
			v = (3.0 if o["simbolo"] == "resistenza" else 1.0) + (2.0 if m.in_gioco("frodo") and o["pos"] == m.posto_di("frodo") else 0.0)
		if v > bv:
			bv = v
			best = k
	return best
