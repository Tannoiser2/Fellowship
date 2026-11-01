class_name IA
extends RefCounted
## Compagni IA: scelgono con regole pratiche, guardando lo stato della partita.
##
## Strategia: Frodo resta al sicuro nei rifugi e si avvicina a Minas Tirith raccogliendo Resistenza
## (le carte gliele passano gli altri con la Compagnia); gli altri personaggi difendono i rifugi minacciati,
## conquistano fortezze e completano gli obiettivi. Quando restano solo «Distruggere l'Anello» e Frodo ha
## 5 Resistenza, Frodo entra a Mordor per la strada più economica in Furtività.

var pausa := 0.35
## semplice: scelte rapide, senza simulazioni (si usa dentro le simulazioni stesse)
var semplice := false
var guarda_avanti := true


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

## Distanze pesate: i sentieri speciali costano come i simboli da spendere.
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


## Dijkstra dal luogo di Frodo: ogni passo costa 1 più la speranza attesa persa nella ricerca all'arrivo.
func _percorso_sicuro(m: Motore, da: String) -> Dictionary:
	var d := {da: 0.0}
	var aperti := [da]
	var chiusi := {}
	while not aperti.is_empty():
		var best := 0
		for k in aperti.size():
			if d[aperti[k]] < d[aperti[best]]:
				best = k
		var x: String = aperti.pop_at(best)
		chiusi[x] = true
		for y in Dati.vicini(x):
			if chiusi.has(y):
				continue
			var e: Dictionary = Dati.collegamento(x, y)
			var w := 1.0
			for s in e["costo"]:
				w += float(e["costo"][s]) * 1.2
			var dadi := float(mini(7, m.nazgul[Dati.regione(y)] + m.stato[y]["ombra"]))
			w += dadi * (0.34 + (0.0 if m.e_rifugio(y) else 0.17)) * 1.5
			if not d.has(y) or d[x] + w < d[y]:
				d[y] = d[x] + w
				if not aperti.has(y):
					aperti.append(y)
	return d


## Passi (sul grafo dei collegamenti) per uscire dalla regione r partendo da l.
## I sentieri speciali contano solo se chi ha Frodo può pagarli.
func _passi_fuori(r: String, l: String, m: Motore = null) -> int:
	var visti := {l: 0}
	var coda := [l]
	while not coda.is_empty():
		var x: String = coda.pop_front()
		for y in Dati.vicini(x):
			if visti.has(y):
				continue
			var costo: Dictionary = Dati.collegamento(x, y)["costo"]
			if not costo.is_empty() and (m == null or not m.in_gioco("frodo") or not m._puo_pagare(m.posto_di("frodo"), costo)):
				continue
			visti[y] = visti[x] + 1
			if Dati.regione(y) != r:
				return visti[y]
			coda.append(y)
	return 9


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
			var pf := _pericolo(m, m.regione_frodo()) + float(m.stato[m.luogo_frodo()]["ombra"])
			v += pf * 2.5 - 6.0
			# l'Occhio è su di lui e per uscire dalla regione serve più di un passo
			if m.occhio == m.regione_frodo() and _passi_fuori(m.regione_frodo(), m.luogo_frodo(), m) > 1:
				v += 12.0
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
	var mia_truppe: int = m.amiche(m.pg[p]["luogo"])
	for l in m.stato:
		var o: int = m.stato[l]["ombra"]
		var am := m.amiche(l)
		# rifugi minacciati: arruolare o portare truppe
		if m.e_rifugio(l):
			var vic := 0
			for v in Dati.vicini(l):
				vic += int(m.stato[v]["ombra"])
			var pericolo: float = o * 2.0 + vic * 0.6 - am * 0.8
			if pericolo > 0.5:
				r.append({"luogo": l, "v": 2.5 + pericolo})
		# battaglie possibili: truppe amiche e dell'Ombra nello stesso luogo
		if o > 0 and am > 0 and p != "gollum":
			r.append({"luogo": l, "v": 3.0 + o * 0.6 + (2.0 if m.e_rifugio(l) else 0.0)})
		# fortezze da conquistare: solo se ci si arriva con truppe o ce ne sono già
		if m.e_fortezza(l) and p != "gollum" and o == 0 and (am > 0 or mia_truppe > 1):
			var v := 4.0
			if l in ["isengard", "moria", "dol_guldur", "umbar", "minas_morgul"]:
				v += 2.0
			r.append({"luogo": l, "v": v})
		# luoghi d'arruolamento vicini all'Ombra
		if Dati.luogo(l)["arruolo"] != "" and p != "gollum" and not m.e_fortezza(l):
			var vic2 := 0
			for v in Dati.vicini(l):
				vic2 += int(m.stato[v]["ombra"])
			if vic2 + o > 0:
				r.append({"luogo": l, "v": 1.5 + (vic2 + o) * 0.4})
	# attaccare lontano da Frodo per distogliere l'Occhio
	if m.occhio == m.regione_frodo() and p != "gollum":
		for l in m.stato:
			if m.stato[l]["ombra"] > 0 and Dati.regione(l) != m.regione_frodo() and m.amiche(l) > 0:
				r.append({"luogo": l, "v": 7.0})
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
	if semplice or not guarda_avanti:
		return _azione_euristica(m, p, op)
	# sguardo avanti: prova ogni azione su copie della partita e valuta la situazione che ne esce
	var base := valuta(m)
	var best := op.size() - 1
	var bv := -1e18
	for k in op.size():
		var o: Dictionary = op[k]
		var v := 0.0
		if o["chiave"] == "fine":
			v = base - (0.3 if m.azioni_rimaste > 0 else 0.0)
		elif o["chiave"] in ["specchio"]:
			v = base - 2.0
		else:
			var campioni := 3 if o["chiave"] in ["attacca", "ob_balrog", "ob_shelob", "ob_anello"] or (o["chiave"] == "viaggio" and _con_frodo(m, p)) else 1
			var tot := 0.0
			for c in campioni:
				tot += _prova(m, p, o, 7919 * (k + 1) + c * 104729 + m.turno * 31)
			v = tot / campioni
			v += _valore(m, p, o) * 0.15
		if v > bv:
			bv = v
			best = k
	return best


func _con_frodo(m: Motore, p: String) -> bool:
	return p == "frodo" or (m.in_gioco("frodo") and m.pg["frodo"]["luogo"] == m.pg[p]["luogo"])


## Esegue l'azione su una copia (con scelte interne euristiche) e valuta il risultato.
func _prova(m: Motore, p: String, o: Dictionary, seme: int) -> float:
	var c := m.copia(seme)
	var ia2 := IA.new()
	ia2.semplice = true
	ia2.pausa = 0.0
	var ctl := ControlloIA.new()
	ctl.ia = ia2
	for i in c.giocatori.size():
		c.controllori.append(ctl)
	c._esegui_azione(p, o)
	c._controlla_obiettivi()
	var v := valuta(c)
	c.free()
	return v


## Valutazione della situazione: speranza, pericolo per Frodo, rifugi minacciati, truppe ombra, obiettivi.
func valuta(m: Motore) -> float:
	if m.esito == "vittoria":
		return 1e9
	if m.esito == "sconfitta" or m.speranza <= 0:
		return -1e9 + m.speranza
	var v: float = float(m.speranza) * 14.0
	# obiettivi
	var finale := true
	for o in m.obiettivi:
		if o["fatto"]:
			v += 40.0
		elif o["codice"] != "anello":
			finale = false
	# Frodo
	if m.in_gioco("frodo"):
		var l := m.luogo_frodo()
		var r := Dati.regione(l)
		var dadi := float(mini(7, m.nazgul[r] + m.stato[l]["ombra"]))
		var perdita := dadi * (0.34 + (0.0 if m.e_rifugio(l) else 0.17))
		var occhio := m.occhio == r
		v -= perdita * (9.0 if occhio else 4.0)
		if occhio:
			# l'Occhio sulla regione di Frodo: ricerche a ogni ordine dell'Ombra e -2 speranza al prossimo
			# Oscuramento dei Cieli. Frodo deve uscire dalla regione il prima possibile.
			# Ogni passo che manca per uscirne vale circa un turno in più sotto l'Occhio.
			var dadi_reg := float(mini(7, m.nazgul[r] + 1))
			v -= 22.0 + float(m.valore_minaccia()) * 1.5 + float(_passi_fuori(r, l, m)) * (8.0 + dadi_reg * 5.0)
		v -= float(m.nazgul[r]) * 1.5
		# potenziale: costo del percorso più sicuro verso un rifugio tranquillo (ogni passo pesa quanto la
		# ricerca che costerebbe), così Frodo esce in tempo dalle regioni dove i Nazgûl si radunano
		if not finale:
			var costi := _percorso_sicuro(m, l)
			var pot := 1e9
			for h in costi:
				if not m.e_rifugio(h) or m.stato[h]["ombra"] > 0:
					continue
				var rh := Dati.regione(h)
				var dz: float = float(m.nazgul[rh]) * 1.8 + (12.0 if m.occhio == rh else 0.0)
				for rv in Dati.regioni_vicine(rh):
					dz += float(m.nazgul[rv]) * 0.35
				pot = minf(pot, dz + costi[h])
			v -= pot * 3.0
		var res := m.disponibili(m.posto_di("frodo"), "resistenza")
		v += float(mini(res, 6)) * (3.0 if finale else 1.5)
		v += float(mini(m.disponibili(m.posto_di("frodo"), "furtivita"), 4)) * 1.2
		var dm: float = _dist("mount_doom").get(l, 30.0)
		if finale:
			v -= dm * (4.0 if res >= 5 else 1.0)
		else:
			v -= maxf(0.0, dm - 6.0) * 0.4
	# rifugi
	for l in m.stato:
		var o: int = m.stato[l]["ombra"]
		var am := m.amiche(l)
		if m.e_rifugio(l):
			var vic := 0
			for x in Dati.vicini(l):
				vic += int(m.stato[x]["ombra"])
			var minaccia := float(o) * 2.2 + float(vic) * 0.7 - float(am) * 1.1
			if minaccia > 0.0:
				v -= minaccia * 2.0
			if o > 0:
				v -= 6.0
		elif m.e_fortezza(l) and Dati.luogo(l)["tipo"] == "rifugio":
			v -= 5.0
		v -= float(o) * 1.1
		if o > 0 and am > 0:
			v -= float(mini(o, am)) * 0.5
		v += float(mini(am, 5)) * (2.6 if m.e_rifugio(l) else 1.6)
	v -= _rischio_rifugi(m) * 42.0
	if m.riserva_ombra < 10:
		v -= float(10 - m.riserva_ombra) * 3.0
	# conquiste e fortezze liberate
	for l in m.stato:
		if m.stato[l]["liberata"]:
			v += 6.0
	# simboli in mano e segnalini
	for i in m.giocatori.size():
		for s in Dati.SIMBOLI:
			v += float(m.giocatori[i]["gettoni"][s]) * 0.9
		v += float(m.giocatori[i]["mano"].size()) * 0.5
	# vicinanza dei personaggi agli obiettivi aperti
	for p in m.pg:
		if not m.in_gioco(p) or p == "frodo":
			continue
		var t := _obiettivo_pg(m, p)
		var d: float = _dist(m.pg[p]["luogo"]).get(t["luogo"], 30.0)
		v -= d * 0.25 * clampf(t["v"], 0.0, 4.0)
	# progressi verso gli obiettivi aperti: l'IA vede i passi intermedi (simboli raccolti, personaggi
	# sul posto, truppe radunate, Ombra scacciata) e non solo l'obiettivo finito
	for o in m.obiettivi:
		if not o["fatto"] and o["codice"] != "anello":
			v += _progresso(m, o["codice"]) * PESO_PROGRESSO
	return v


const PESO_PROGRESSO := 30.0


## Probabilità che ogni linea di battaglia avanzi al prossimo turno dell'Ombra, dalle carte rimaste nel mazzo.
func _prob_linee(m: Motore) -> Dictionary:
	var r := {}
	var n := m.mazzo_ombra.size()
	if n == 0:
		return r
	var pesca := float(mini(n, m.valore_minaccia()))
	for id in m.mazzo_ombra:
		var lid: String = Dati.carta(id).get("linea", "")
		if lid != "":
			r[lid] = r.get(lid, 0.0) + 0.5 * pesca / float(n)
	return r


## Rischio (in rifugi attesi persi) che un rifugio cada al prossimo turno dell'Ombra: truppe ombra già lì
## più quelle che le avanzate probabili porteranno, contro le truppe amiche che lo difendono.
func _rischio_rifugi(m: Motore) -> float:
	var pl := _prob_linee(m)
	var arrivi := {}
	for lid in pl:
		var p: Array = Dati.linea(lid)["percorso"]
		for k in range(1, p.size()):
			var o: int = m.stato[p[k - 1]]["ombra"]
			if o > 0 and m.e_rifugio(p[k]):
				arrivi[p[k]] = arrivi.get(p[k], 0.0) + float(o) * minf(1.0, pl[lid])
	var tot := 0.0
	for h in arrivi:
		var att: float = float(m.stato[h]["ombra"]) + arrivi[h]
		var am := float(m.amiche(h))
		tot += clampf((att - am * 0.9) / (att + 1.0), 0.0, 1.0) * minf(1.0, arrivi[h] + 0.3)
	for h in m.stato:
		if m.e_rifugio(h) and not arrivi.has(h) and m.stato[h]["ombra"] > 0:
			var o := float(m.stato[h]["ombra"])
			tot += clampf((o - float(m.amiche(h)) * 0.9) / (o + 1.0), 0.0, 1.0) * 0.5
	return tot


## Quanto un personaggio qualsiasi è vicino a un luogo (1 = è lì).
func _vicinanza(m: Motore, l: String, esclusi: Array = []) -> float:
	var best := 0.0
	for p in m.pg:
		if not m.in_gioco(p) or p in esclusi or (p == "frodo" and not m.solo):
			continue
		var d: float = _dist(m.pg[p]["luogo"]).get(l, 30.0)
		best = maxf(best, 1.0 / (1.0 + d * 0.45))
	return best


## Due personaggi nello stesso luogo, uno dei quali paga il costo.
func _prog_azione_luogo(m: Motore, l: String, costo: Dictionary) -> float:
	var vic := 0.0
	var secondo := 0.0
	var pagare := 0.0
	var vicini: Array = []
	for p in m.pg:
		if not m.in_gioco(p):
			continue
		var d: float = _dist(m.pg[p]["luogo"]).get(l, 30.0)
		vicini.append(1.0 / (1.0 + d * 0.45))
	vicini.sort()
	vicini.reverse()
	if vicini.size() > 0:
		vic = vicini[0]
	if vicini.size() > 1:
		secondo = vicini[1]
	var tot := 0
	for s in costo:
		tot += int(costo[s])
	for i in m.giocatori.size():
		var have := 0
		for s in costo:
			have += mini(int(costo[s]), m.disponibili(i, s))
		pagare = maxf(pagare, float(have) / float(maxi(1, tot)))
	return vic * 0.3 + secondo * 0.2 + pagare * 0.5


## Ombra scacciata da una regione (1 = libera).
func _prog_regione(m: Motore, r: String) -> float:
	var o := 0.0
	for l in Dati.d()["regioni"][r]["luoghi"]:
		o += float(m.stato[l]["ombra"]) + (3.0 if m.e_fortezza(l) else 0.0)
	return 1.0 / (1.0 + o * 0.35)


## Truppe di una razza raccolte in un luogo (rispetto a quante ne servono).
func _prog_truppe(m: Motore, l: String, a: String, n: int) -> float:
	return minf(1.0, float(m.stato[l]["truppe"][a]) / float(n))


## Un luogo da conquistare: Ombra assente o battibile, truppe amiche pronte.
func _prog_conquista(m: Motore, l: String) -> float:
	if m.e_rifugio(l):
		return 1.0
	var o := float(m.stato[l]["ombra"])
	var am := float(m.amiche(l))
	var vic := 0.0
	for x in Dati.vicini(l):
		vic = maxf(vic, float(m.amiche(x)))
	return 0.15 / (1.0 + o * 0.5) + 0.25 * minf(1.0, maxf(am, vic * 0.6) / maxf(2.0, o + 1.0)) + 0.1 * _vicinanza(m, l)


## Progresso (0..1) verso un obiettivo non ancora completato.
func _progresso(m: Motore, cod: String) -> float:
	match cod:
		"benedizione":
			return _prog_azione_luogo(m, "rivendell", {"amicizia": 3})
		"theoden":
			return _prog_azione_luogo(m, "edoras", {"amicizia": 2, "resistenza": 1})
		"denethor":
			return _prog_azione_luogo(m, "minas_tirith", {"furtivita": 2, "amicizia": 1, "valore": 1})
		"stendardo":
			var t: Dictionary = m.stato["minas_tirith"]["truppe"]
			var razze := 0.0
			for a in ["gondor", "rohirrim", "elfi", "nani"]:
				razze += 0.25 if t[a] > 0 else 0.0
			return razze * 0.6 + _vicinanza(m, "minas_tirith") * 0.4 if m.in_gioco("arwen") else 0.0
		"sauron":
			var l := "north_ithilien"
			return (_prog_truppe(m, l, "rohirrim", 2) * 2.0 + _prog_truppe(m, l, "elfi", 2) * 2.0 + _prog_truppe(m, l, "gondor", 3) * 3.0) / 7.0 * 0.8 + _vicinanza(m, l) * 0.2
		"saruman":
			return _prog_conquista(m, "isengard") * 0.5 + _prog_regione(m, "rohan") * 0.5
		"pozzi":
			return _prog_conquista(m, "dol_guldur") * 0.6 + _prog_truppe(m, "dol_guldur", "elfi", 3) * 0.4
		"balin":
			return _prog_conquista(m, "moria") * 0.6 + _prog_truppe(m, "moria", "nani", 2) * 0.4
		"freca":
			return _prog_conquista(m, "dunland") * 0.6 + _prog_truppe(m, "dunland", "rohirrim", 2) * 0.4
		"morgul":
			return _prog_conquista(m, "minas_morgul")
		"anduin":
			return _prog_conquista(m, "osgiliath")
		"umbar":
			return _prog_conquista(m, "umbar")
		"raminghi":
			var luoghi: Array = Dati.d()["regioni"]["eriador"]["luoghi"]
			var occ := 0.0
			for l in luoghi:
				occ += 1.0 if m.amiche(l) > 0 else 0.0
			return _prog_regione(m, "eriador") * 0.5 + occ / float(luoghi.size()) * 0.5
		"bosco_atro":
			var luoghi: Array = Dati.d()["regioni"]["mirkwood"]["luoghi"]
			var occ := 0.0
			for l in luoghi:
				occ += 1.0 if m.stato[l]["truppe"]["elfi"] > 0 else 0.0
			return _prog_regione(m, "mirkwood") * 0.5 + occ / float(luoghi.size()) * 0.5
		"nani":
			var o: float = float(m.stato["ered_luin"]["ombra"])
			return 0.3 / (1.0 + o) + _prog_truppe(m, "ered_luin", "nani", 4) * 0.4 + _prog_regione(m, "dale") * 0.3
		"eowyn":
			return float(mini(m.nazgul_eowyn, 2)) * 0.3 + _prog_regione(m, "rohan") * 0.4
		"eored":
			return float(mini(m.eored.size(), 4)) / 4.0
		"sei":
			return float(mini(int(m.su_carta.get("sei", 0)), 6)) / 6.0
		"hobbit":
			return float(mini(m.hobbit.size(), 2)) * 0.45
		"spergiuri":
			return (0.4 if m.aragorn_erech else 0.0) + _prog_regione(m, "gondor") * 0.6
		"balrog":
			return _vicinanza(m, "moria") * 0.6 if m.in_gioco("gandalf") else 0.0
	return 0.0


func _azione_euristica(m: Motore, p: String, op: Array) -> int:
	var best := op.size() - 1
	var bv := -1e9
	for k in op.size():
		var v := _valore(m, p, op[k])
		if v > bv:
			bv = v
			best = k
	return best


func _valore(m: Motore, p: String, o: Dictionary) -> float:
	var l: String = m.pg[p]["luogo"]
	var pos: int = m.posto_di(p)
	match o["chiave"]:
		"fine":
			return -1.2 if m.azioni_rimaste > 0 else 0.0
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
			var v: float = 4.0 + m.stato[l]["ombra"] * 0.5 + n * 0.7
			if m.e_rifugio(l):
				v += 2.0
			if m.occhio == m.regione_frodo() and Dati.regione(l) != m.regione_frodo():
				v += 6.0
			if m.e_rifugio(l) and m.stato[l]["ombra"] >= m.amiche(l):
				v += 3.0
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
	# scelte di luoghi: il rifugio più minacciato o il luogo con più truppe ombra
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
