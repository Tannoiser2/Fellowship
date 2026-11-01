class_name Motore
extends Node
## Motore di The Lord of the Rings: Fate of the Fellowship: stato della partita e regole complete.
##
## Il motore non conosce l'interfaccia: quando serve una scelta chiama `chiedi(posto, richiesta)`, che
## gira la domanda al "controllore" del posto (persona, IA o partita online). Tutti i tiri di dado e i
## mescolamenti usano il generatore con il seme della partita: con lo stesso seme e le stesse risposte
## la partita è identica ovunque (serve al gioco online e alla ripresa delle partite salvate).

signal cambiato
signal messaggio(testo: String)
signal evento(tipo: String, dati: Dictionary)
signal finita(esito: String)
signal scelta_registrata
signal ripresa_finita

var rng := RandomNumberGenerator.new()
var seme := 0
var controllori: Array = []

# --- configurazione
var solo := false
var difficolta := "introduttivo"

# --- stato
var giocatori: Array = []          # {nome, ia, mano: [id], gettoni: {simbolo: n}, pg: [pid]}
var pg: Dictionary = {}            # pid -> {luogo, posto, fuori, bianco}
var stato: Dictionary = {}         # luogo -> {truppe: {armata: n}, ombra, tipo, liberata}
var nazgul: Dictionary = {}        # regione -> n
var occhio := "eriador"
var speranza := Dati.SPERANZA_INIZIO
var minaccia := 0                  # indice sulla traccia Dati.MINACCIA
var riserva_truppe: Dictionary = {}
var riserva_ombra := 0
var riserva_simboli: Dictionary = {}
var mazzo: Array = []
var scarti: Array = []
var eventi_inutilizzati: Array = []
var mazzo_ombra: Array = []
var scarti_ombra: Array = []
var risolte: Array = []            # carte Ombra di questo turno (spazio «Risolvi»)
var obiettivi: Array = []          # {codice, fatto}
var su_carta: Dictionary = {}      # codice obiettivo -> truppe/segnalini sopra la carta
var eored: Dictionary = {}         # regione -> true (spazi occupati su «Cavalcare con gli Éored»)
var hobbit: Dictionary = {}        # tipo di rifugio -> true
var nazgul_eowyn := 0
var aragorn_erech := false
var gandalf_attesa := false        # Gandalf dopo il Balrog: torna alla prossima carta Oscuramento dei Cieli
var boromir_sostituire := false
var turno_di := 0
var turno := 0
var solo_indice := 0               # in solitario: personaggio con il segnalino
var esito := ""
var fase := "preparazione"
var registro: Array = []
var storia: Array = []
var da_rigiocare: Array = []
var ultima_ombra := -1             # ultima carta Ombra girata (per l'interfaccia)

# --- turno in corso
var attivo := ""                   # personaggio che sta facendo azioni
var azioni_rimaste := 0
var usi: Dictionary = {}           # abilità «una volta per turno» già usate
var lembas := 0
var azione_extra := 0
var in_battaglia := false


func _init() -> void:
	Dati.d()


# =====================================================================================
# PREPARAZIONE
# =====================================================================================

## config: {giocatori: [{nome, ia}], difficolta, scenario, obiettivi: [codici], personaggi: [[pid]], seme}
func prepara(config: Dictionary) -> void:
	var D := Dati.d()
	seme = int(config.get("seme", 0))
	if seme == 0:
		seme = randi()
	rng.seed = seme
	difficolta = config.get("difficolta", "introduttivo")
	var gg: Array = config.get("giocatori", [{"nome": "Giocatore 1", "ia": false}])
	solo = gg.size() == 1
	giocatori.clear()
	for g in gg:
		var gt := {}
		for s in Dati.SIMBOLI:
			gt[s] = 0
		giocatori.append({"nome": g.get("nome", "Giocatore"), "ia": g.get("ia", false), "mano": [], "gettoni": gt, "pg": []})
	# luoghi
	for l in D["luoghi"]:
		var t := {}
		for a in Dati.ARMATE:
			t[a] = 0
		stato[l] = {"truppe": t, "ombra": 0, "tipo": D["luoghi"][l]["tipo"], "liberata": false}
	for a in Dati.ARMATE:
		riserva_truppe[a] = int(D["riserva"][a])
		for l in D["truppe_inizio"][a]:
			stato[l]["truppe"][a] += int(D["truppe_inizio"][a][l])
			riserva_truppe[a] -= int(D["truppe_inizio"][a][l])
	riserva_ombra = int(D["riserva"]["ombra"])
	for l in D["ombra_inizio"]:
		stato[l]["ombra"] += int(D["ombra_inizio"][l])
		riserva_ombra -= int(D["ombra_inizio"][l])
	for s in Dati.SIMBOLI:
		riserva_simboli[s] = int(D["riserva"]["simboli"])
	for r in D["regioni"]:
		nazgul[r] = int(D["nazgul_inizio"].get(r, 0))
	occhio = "eriador"
	speranza = Dati.SPERANZA_INIZIO
	minaccia = 0
	# mazzo dell'Ombra: le 2 speciali negli scarti, le altre mescolate
	for c in D["carte_ombra"]:
		if c.has("speciale"):
			scarti_ombra.append(int(c["id"]))
		else:
			mazzo_ombra.append(int(c["id"]))
	_mescola(mazzo_ombra)
	# 9 carte Ombra: 1 truppa nel luogo indicato
	for k in 9:
		var id: int = mazzo_ombra.pop_back()
		var rl: String = Dati.carta(id)["rinforzo"]
		stato[rl]["ombra"] += 1
		riserva_ombra -= 1
		scarti_ombra.append(id)
	# obiettivi
	var scelti: Array = config.get("obiettivi", [])
	if scelti.is_empty():
		var n_ob: int = int(D["difficolta"][difficolta]["obiettivi"])
		var pool: Array = []
		for o in D["obiettivi"]:
			if o["codice"] != "anello":
				pool.append(o["codice"])
		_mescola(pool)
		var max_pg := 5 if solo else giocatori.size() * 2
		for tentativo in 50:
			scelti = pool.slice(0, n_ob - 1)
			scelti.append("anello")
			if _personaggi_richiesti(scelti).size() <= max_pg:
				break
			_mescola(pool)
	for c in scelti:
		obiettivi.append({"codice": c, "fatto": false})
	# preparazione degli obiettivi
	for o in obiettivi:
		match o["codice"]:
			"benedizione":
				su_carta["benedizione"] = 3
				riserva_truppe["elfi"] -= 3
			"theoden":
				su_carta["theoden"] = 4
				riserva_truppe["rohirrim"] -= 4
			"denethor":
				su_carta["denethor"] = 4
				riserva_truppe["gondor"] -= 4
			"saruman":
				_aggiungi_ombra_sicuro("isengard", 2)
			"nani":
				_aggiungi_ombra_sicuro("ered_luin", 1)
			"pozzi":
				_aggiungi_ombra_sicuro("dol_guldur", 1)
			"morgul":
				_aggiungi_ombra_sicuro("minas_morgul", 1)
			"bosco_atro":
				_aggiungi_ombra_sicuro("old_forest_road", 1)
				_aggiungi_ombra_sicuro("southern_mirkwood", 1)
			"anduin":
				_aggiungi_ombra_sicuro("osgiliath", 1)
			"sei", "eored":
				su_carta[o["codice"]] = 0
	# personaggi
	var assegnati: Array = config.get("personaggi", [])
	if assegnati.is_empty():
		assegnati = _assegna_personaggi(scelti)
	for i in giocatori.size():
		for p in assegnati[i]:
			giocatori[i]["pg"].append(p)
			pg[p] = {"luogo": Dati.personaggio(p)["partenza"], "posto": i, "fuori": false, "bianco": false}
	# Shelob: chi ha Frodo non può avere Gollum (si scambia con un altro giocatore)
	# carte dei giocatori
	var n_g := giocatori.size()
	var n_eventi: int = {1: 5, 2: 6, 3: 6, 4: 7, 5: 9}[n_g]
	var ev: Array = []
	for c in D["carte_evento"]:
		ev.append(int(c["id"]))
	_mescola(ev)
	var giocatore_carte: Array = []
	for c in D["carte_regione"]:
		giocatore_carte.append(int(c["id"]))
	for k in n_eventi:
		giocatore_carte.append(ev[k])
	eventi_inutilizzati = ev.slice(n_eventi)
	_mescola(giocatore_carte)
	var mano: int = {1: 4, 2: 4, 3: 3, 4: 2, 5: 2}[n_g]
	for i in n_g:
		for k in mano:
			giocatori[i]["mano"].append(giocatore_carte.pop_back())
	# mazzo a pile con Oscuramento dei Cieli
	var cieli: Array = []
	for c in D["carte_cieli"]:
		cieli.append(int(c["id"]))
	_mescola(cieli)
	var n_pile: int = int(D["difficolta"][difficolta]["cieli"])
	var pile: Array = []
	for k in n_pile:
		pile.append([])
	for k in giocatore_carte.size():
		pile[k % n_pile].append(giocatore_carte[k])
	mazzo.clear()
	# le pile più grandi stanno in cima: in cima = fine dell'array
	for k in range(n_pile - 1, -1, -1):
		var p: Array = pile[k]
		p.append(cieli[k])
		_mescola(p)
		mazzo.append_array(p)
	# primo giocatore: carta regione con il numero più basso
	var best := 1 << 30
	turno_di = 0
	for i in n_g:
		for id in giocatori[i]["mano"]:
			var c := Dati.carta(id)
			if c.get("tipo", "") == "regione" and int(c["numero"]) < best:
				best = int(c["numero"])
				turno_di = i
	if config.get("primo_frodo", false):
		turno_di = pg["frodo"]["posto"]
	fase = "azioni"
	_log("La Compagnia parte dalla Contea. Speranza %d, minaccia %d." % [speranza, valore_minaccia()])
	cambiato.emit()


func _aggiungi_ombra_sicuro(l: String, n: int) -> void:
	var k: int = min(n, riserva_ombra)
	stato[l]["ombra"] += k
	riserva_ombra -= k


func _personaggi_richiesti(cod: Array) -> Array:
	var r: Array = []
	for c in cod:
		var q: String = Dati.obiettivo(c).get("richiede", "")
		if q != "" and not r.has(q):
			r.append(q)
	return r


func _assegna_personaggi(cod: Array) -> Array:
	var n_g := giocatori.size()
	var totale := 5 if solo else n_g * 2
	var scelti := _personaggi_richiesti(cod)
	if not scelti.has("frodo"):
		scelti.push_front("frodo")
	var resto: Array = []
	for p in Dati.d()["personaggi"]:
		if not scelti.has(p):
			resto.append(p)
	_mescola(resto)
	while scelti.size() < totale:
		scelti.append(resto.pop_back())
	var out: Array = []
	if solo:
		out.append(scelti.slice(0, 5))
		return out
	# distribuzione a caso, poi Frodo e Gollum su giocatori diversi
	_mescola(scelti)
	for i in n_g:
		out.append([scelti[i * 2], scelti[i * 2 + 1]])
	for i in n_g:
		if out[i].has("frodo") and out[i].has("gollum") and n_g > 1:
			var j := (i + 1) % n_g
			var g: int = out[i].find("gollum")
			var t = out[j][0]
			out[j][0] = "gollum"
			out[i][g] = t
	return out


func _mescola(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


func _log(t: String) -> void:
	registro.append(t)
	if registro.size() > 400:
		registro.pop_front()
	messaggio.emit(t)


# =====================================================================================
# DOMANDE AI CONTROLLORI
# =====================================================================================

## richiesta: {tipo, titolo, testo, opzioni: [{testo, luogo?, carta?, ...}]}; risponde con l'indice scelto.
func chiedi(posto: int, richiesta: Dictionary) -> int:
	richiesta["posto"] = posto
	if richiesta.has("opzioni") and richiesta["opzioni"].size() == 1 and not richiesta.get("conferma", false):
		return 0
	if not da_rigiocare.is_empty():
		var v: int = int(da_rigiocare.pop_front())
		storia.append(v)
		if da_rigiocare.is_empty():
			ripresa_finita.emit()
		return v
	var ctl = controllori[posto] if posto < controllori.size() else null
	if ctl == null:
		return 0
	cambiato.emit()
	var r = await ctl.decide(self, posto, richiesta)
	r = clampi(int(r), 0, max(0, richiesta.get("opzioni", [0]).size() - 1))
	storia.append(r)
	scelta_registrata.emit()
	return r


func _si_no(posto: int, titolo: String, testo: String, si := "Sì", no := "No", tipo := "sino", extra := {}) -> bool:
	var req := {"tipo": tipo, "titolo": titolo, "testo": testo, "opzioni": [{"testo": si, "si": true}, {"testo": no}], "conferma": true}
	req.merge(extra)
	return await chiedi(posto, req) == 0


# =====================================================================================
# INTERROGAZIONI SULLO STATO
# =====================================================================================

func valore_minaccia() -> int:
	return Dati.MINACCIA[min(minaccia, Dati.MINACCIA.size() - 1)]


func amiche(l: String) -> int:
	var n := 0
	for a in Dati.ARMATE:
		n += int(stato[l]["truppe"][a])
	return n


func e_rifugio(l: String) -> bool:
	return stato[l]["tipo"] == "rifugio"


func e_fortezza(l: String) -> bool:
	return stato[l]["tipo"] == "fortezza"


func luogo_frodo() -> String:
	return pg["frodo"]["luogo"] if pg.has("frodo") else "the_shire"


func regione_frodo() -> String:
	return Dati.regione(luogo_frodo())


func in_gioco(p: String) -> bool:
	return pg.has(p) and not pg[p]["fuori"]


func personaggi_in(l: String) -> Array:
	var r: Array = []
	for p in pg:
		if not pg[p]["fuori"] and pg[p]["luogo"] == l:
			r.append(p)
	return r


func presente(p: String, l: String) -> bool:
	return in_gioco(p) and pg[p]["luogo"] == l


func nome_pg(p: String) -> String:
	if p == "gandalf" and pg.has("gandalf") and pg["gandalf"]["bianco"]:
		return "Gandalf il Bianco"
	return Dati.personaggio(p)["nome"]


## Simboli che un giocatore può spendere: segnalini + carte regione con quel simbolo.
func disponibili(posto: int, s: String) -> int:
	var n: int = int(giocatori[posto]["gettoni"][s])
	for id in giocatori[posto]["mano"]:
		var c := Dati.carta(id)
		if c.get("tipo", "") == "regione" and c["simbolo"] == s:
			n += 1
	return n


## In solitario c'è un'unica mano: tutti i personaggi pagano dallo stesso posto.
func posto_di(p: String) -> int:
	return int(pg[p]["posto"])


func obiettivo_attivo(cod: String) -> bool:
	for o in obiettivi:
		if o["codice"] == cod and not o["fatto"]:
			return true
	return false


func obiettivo_presente(cod: String) -> bool:
	for o in obiettivi:
		if o["codice"] == cod:
			return true
	return false


func obiettivi_fatti() -> int:
	var n := 0
	for o in obiettivi:
		if o["fatto"]:
			n += 1
	return n


func regione_libera(r: String) -> bool:
	for l in Dati.d()["regioni"][r]["luoghi"]:
		if stato[l]["ombra"] > 0 or e_fortezza(l):
			return false
	return true


# =====================================================================================
# SVOLGIMENTO
# =====================================================================================

func gioca() -> void:
	while esito == "":
		await _turno()
	fase = "fine"
	cambiato.emit()
	finita.emit(esito)


func _turno() -> void:
	turno += 1
	usi.clear()
	lembas = 0
	azione_extra = 0
	var g: Dictionary = giocatori[turno_di]
	_log("— Turno %d: %s —" % [turno, g["nome"]])
	fase = "azioni"
	await _fase_azioni()
	if esito != "":
		return
	fase = "pesca"
	await _pesca_carte()
	if esito != "":
		return
	fase = "ombra"
	await _carte_ombra()
	if esito != "":
		return
	if solo:
		solo_indice = (solo_indice + 1) % _ordine_solo().size()
	else:
		turno_di = (turno_di + 1) % giocatori.size()


## In solitario: i personaggi davanti al giocatore (tutti tranne Frodo), da sinistra a destra.
func _ordine_solo() -> Array:
	var r: Array = []
	for p in giocatori[0]["pg"]:
		if p != "frodo":
			r.append(p)
	return r


# -------------------------------------------------------------------------------------
# 1. AZIONI
# -------------------------------------------------------------------------------------

func _fase_azioni() -> void:
	var i := turno_di
	var miei: Array = []
	if solo:
		var ord := _ordine_solo()
		var p: String = ord[solo_indice % ord.size()]
		miei = [p, "frodo"]
	else:
		miei = giocatori[i]["pg"].duplicate()
	var vivi: Array = []
	for p in miei:
		if in_gioco(p):
			vivi.append(p)
	if vivi.is_empty():
		return
	# ordine e ripartizione 4 + 1
	var piani: Array = []
	if vivi.size() == 1:
		piani = [[vivi[0], 4]]
	elif solo:
		piani = [[vivi[0], 4, vivi[1], 1], [vivi[1], 1, vivi[0], 4]]
	else:
		piani = [[vivi[0], 4, vivi[1], 1], [vivi[1], 4, vivi[0], 1], [vivi[0], 1, vivi[1], 4], [vivi[1], 1, vivi[0], 4]]
	var piano: Array = piani[0]
	if piani.size() > 1:
		var op: Array = []
		for pp in piani:
			op.append({"testo": "%s: %d azion%s, poi %s: %d" % [nome_pg(pp[0]), pp[1], "i" if pp[1] > 1 else "e", nome_pg(pp[2]), pp[3]], "pg": pp[0], "n": pp[1]})
		piano = piani[await chiedi(i, {"tipo": "piano", "titolo": "Chi agisce per primo?", "testo": "Fai fino a 4 azioni con un personaggio e fino a 1 con l'altro.", "opzioni": op})]
	var k := 0
	while k < piano.size() and esito == "":
		var p: String = piano[k]
		var n: int = piano[k + 1]
		if in_gioco(p):
			await _azioni_di(p, n)
		k += 2
	attivo = ""


func _azioni_di(p: String, n: int) -> void:
	attivo = p
	azioni_rimaste = n
	usi["bonus_viaggio_" + p] = false
	while esito == "" and in_gioco(p):
		if azioni_rimaste <= 0 and azione_extra > 0 and p == "frodo":
			azioni_rimaste += azione_extra
			azione_extra = 0
		var opz := opzioni_azione(p)
		var r := await chiedi(turno_di, {"tipo": "azione", "titolo": "%s — azioni rimaste: %d" % [nome_pg(p), azioni_rimaste],
			"testo": "Scegli un'azione (puoi anche cliccare sulla mappa).", "opzioni": opz, "pg": p, "conferma": true})
		var o: Dictionary = opz[r]
		if o["chiave"] == "fine":
			break
		await _esegui_azione(p, o)
		_controlla_obiettivi()
		cambiato.emit()
		if azioni_rimaste <= 0 and not _ha_gratis(p) and azione_extra == 0:
			# ultima occasione per eventi e abilità gratuite
			if not _ha_mosse_libere():
				break


func _ha_gratis(p: String) -> bool:
	if p == "eomer" and not usi.get("bonus_viaggio_eomer", false):
		return true
	return false


func _ha_mosse_libere() -> bool:
	return not _opzioni_libere().is_empty()


## Tutte le azioni possibili del personaggio attivo (più eventi e abilità senza costo d'azione).
func opzioni_azione(p: String) -> Array:
	var o: Array = []
	var l: String = pg[p]["luogo"]
	if azioni_rimaste > 0 or (p == "eomer" and not usi.get("bonus_viaggio_eomer", false)):
		var gratis := azioni_rimaste <= 0
		for dest in _destinazioni(p):
			var c: Dictionary = dest["costo"]
			var t := "Viaggia a %s" % Dati.nome(dest["luogo"])
			if not c.is_empty():
				t += " (%s)" % _testo_costo(c)
			if dest.get("passi", 1) == 2:
				t += " — Ombromanto"
			if gratis:
				t += " — viaggio gratis di Éomer"
			o.append({"testo": t, "chiave": "viaggio", "luogo": dest["luogo"], "costo": c, "passi": dest.get("passi", 1), "gratis": gratis})
	if azioni_rimaste > 0:
		var pos: int = posto_di(p)
		# Compagnia
		if not solo:
			for q in personaggi_in(l):
				if q != p and posto_di(q) != pos:
					o.append({"testo": "Compagnia con %s (dare o prendere una carta)" % nome_pg(q), "chiave": "compagnia", "con": q})
		# Preparare
		if (e_rifugio(l) or p == "gollum"):
			var viste := {}
			for id in giocatori[pos]["mano"]:
				var c := Dati.carta(id)
				if c.get("tipo", "") != "regione" or viste.has(id):
					continue
				if solo and c["regione"] != Dati.regione(l) and not (p == "arwen" and not usi.get("consiglio_arwen", false)):
					continue
				if riserva_simboli[c["simbolo"]] <= 0:
					continue
				viste[id] = true
				o.append({"testo": "Prepara: scarta %s (%s) per un segnalino %s" % [Dati.nome_regione(c["regione"]), Dati.NOMI_SIMBOLI[c["simbolo"]], Dati.NOMI_SIMBOLI[c["simbolo"]]], "chiave": "prepara", "carta": id})
		# Arruolare
		var col: String = Dati.luogo(l)["arruolo"]
		if col != "" and p != "gollum" and riserva_truppe[col] > 0 and (_arruolo_gratis(p, col) or disponibili(pos, "amicizia") >= 1) and stato[l]["tipo"] != "fortezza":
			o.append({"testo": "Raduna: +%d truppa %s%s" % [2 if p == "gandalf" and riserva_truppe[col] > 1 else 1, Dati.NOMI_ARMATE[col], "" if _arruolo_gratis(p, col) else " (1 Amicizia)"], "chiave": "arruola", "luogo": l})
		# Attacco
		if p != "gollum" and amiche(l) > 0 and stato[l]["ombra"] > 0:
			for nd in range(1, min(3, amiche(l)) + 1):
				o.append({"testo": "Attacca con %d dad%s" % [nd, "i" if nd > 1 else "o"], "chiave": "attacca", "dadi": nd, "luogo": l})
		# Conquista
		var cc := _costi_conquista(p, l)
		for c in cc:
			o.append({"testo": "Conquista %s (%s)" % [Dati.nome(l), _testo_costo(c)], "chiave": "conquista", "costo": c, "luogo": l})
		# abilità con azione
		o.append_array(_azioni_speciali(p, l, pos))
		o.append_array(_azioni_obiettivi(p, l, pos))
	o.append_array(_opzioni_libere())
	o.append({"testo": "Fine delle azioni di %s" % nome_pg(p) if azioni_rimaste > 0 else "Avanti", "chiave": "fine"})
	return o


func _testo_costo(c: Dictionary) -> String:
	var parti: Array = []
	for s in c:
		parti.append("%d %s" % [c[s], Dati.NOMI_SIMBOLI[s]])
	return " + ".join(parti)


func _arruolo_gratis(p: String, col: String) -> bool:
	return (p == "arwen" and col == "elfi") or (p == "boromir" and col == "gondor") or (p == "eowyn" and col == "rohirrim") or (p == "gimli" and col == "nani")


func _puo_pagare(pos: int, c: Dictionary) -> bool:
	for s in c:
		if disponibili(pos, s) < int(c[s]):
			return false
	return true


## Destinazioni di viaggio: luoghi vicini (con eventuale costo) e, per Gandalf da solo, a due passi.
func _destinazioni(p: String) -> Array:
	var l: String = pg[p]["luogo"]
	var pos: int = posto_di(p)
	var r: Array = []
	var visti := {}
	for v in Dati.vicini(l):
		var e: Dictionary = Dati.collegamento(l, v)
		var c: Dictionary = e["costo"].duplicate()
		if p == "faramir" and not c.is_empty():
			var s: String = c.keys()[0]
			c[s] = int(c[s]) - 1
			if c[s] <= 0:
				c.erase(s)
		if not _puo_pagare(pos, c):
			continue
		r.append({"luogo": v, "costo": c, "passi": 1})
		visti[v] = true
	if p == "gandalf":
		for v in Dati.vicini(l):
			if not Dati.collegamento(l, v)["costo"].is_empty():
				continue
			for w in Dati.vicini(v):
				if w == l or visti.has(w) or not Dati.collegamento(v, w)["costo"].is_empty():
					continue
				visti[w] = true
				r.append({"luogo": w, "costo": {}, "passi": 2})
	return r


func _costi_conquista(p: String, l: String) -> Array:
	if p == "gollum" or amiche(l) < 1 or stato[l]["ombra"] > 0:
		return []
	var pos: int = posto_di(p)
	var c: Array = []
	var ok := e_fortezza(l)
	if l == "dunland" and obiettivo_attivo("freca") and not e_rifugio(l):
		ok = true
		c.append({"amicizia": 3})
	if l == "osgiliath" and obiettivo_attivo("anduin") and not e_rifugio(l):
		ok = true
		if p == "faramir":
			c.append({"resistenza": 2, "furtivita": 1})
	if l == "minas_morgul" and obiettivo_attivo("morgul"):
		c.append({"furtivita": 3})
	if l == "dol_guldur" and p == "galadriel" and obiettivo_attivo("pozzi"):
		c.append({"resistenza": 2, "valore": 1})
	if not ok:
		return []
	c.push_front({"valore": 2 if p == "boromir" else 3})
	var r: Array = []
	for x in c:
		if _puo_pagare(pos, x):
			r.append(x)
	return r


func _azioni_speciali(p: String, l: String, pos: int) -> Array:
	var o: Array = []
	match p:
		"aragorn":
			if not usi.get("anduril", false) and obiettivi_fatti() > 0 and stato[l]["ombra"] > 0:
				o.append({"testo": "Andúril: togli 1 truppa ombra qui", "chiave": "anduril"})
		"galadriel":
			if not mazzo.is_empty():
				o.append({"testo": "Specchio di Galadriel: guarda e riordina le prime 4 carte", "chiave": "specchio"})
		"gimli":
			if not usi.get("arte_nani", false) and riserva_simboli["valore"] > 0:
				o.append({"testo": "Arte Nanica: prendi 1 Valore", "chiave": "arte_nani"})
		"legolas":
			if not usi.get("passo_silenzioso", false) and riserva_simboli["furtivita"] > 0:
				o.append({"testo": "Camminare Silenziosamente: prendi 1 Furtività", "chiave": "passo_silenzioso"})
		"pipino":
			if not usi.get("amico_leale", false) and riserva_simboli["amicizia"] > 0:
				o.append({"testo": "Amici Fedeli: prendi 1 Amicizia", "chiave": "amico_leale"})
			if in_gioco("frodo") and pg["frodo"]["luogo"] == l and disponibili(pos, "amicizia") >= 3 and speranza < Dati.SPERANZA_MAX:
				o.append({"testo": "Dacci una Canzone! (3 Amicizia: +2 speranza)", "chiave": "canzone"})
		"gollum":
			if not usi.get("strisciante", false):
				for id in scarti:
					var c := Dati.carta(id)
					if c.get("tipo", "") == "regione" and c["simbolo"] == "furtivita":
						o.append({"testo": "Servile: prendi dagli scarti la carta Furtività (%s)" % Dati.nome_regione(c["regione"]), "chiave": "strisciante", "carta": id})
		"faramir":
			if not usi.get("eldar", false) and e_rifugio(l):
				for id in scarti:
					var c := Dati.carta(id)
					if c.get("tipo", "") == "regione" and c["simbolo"] == "resistenza" and c["regione"] == Dati.regione(l):
						o.append({"testo": "Saggezza degli Eldar: prendi la carta Resistenza (%s)" % Dati.nome_regione(c["regione"]), "chiave": "eldar", "carta": id})
	return o


func _azioni_obiettivi(p: String, l: String, pos: int) -> Array:
	var o: Array = []
	var altri := personaggi_in(l).size() > 1
	if obiettivo_attivo("benedizione") and l == "rivendell" and altri and disponibili(pos, "amicizia") >= 3:
		o.append({"testo": "Benedizione degli Elfi (3 Amicizia)", "chiave": "ob_benedizione"})
	if obiettivo_attivo("theoden") and l == "edoras" and altri and _puo_pagare(pos, {"amicizia": 2, "resistenza": 1}):
		o.append({"testo": "Liberare la mente di Théoden (2 Amicizia + 1 Resistenza)", "chiave": "ob_theoden"})
	if obiettivo_attivo("denethor") and l == "minas_tirith" and altri and _puo_pagare(pos, {"furtivita": 2, "amicizia": 1, "valore": 1}):
		o.append({"testo": "Spodestare Denethor (2 Furtività + 1 Amicizia + 1 Valore)", "chiave": "ob_denethor"})
	if obiettivo_attivo("sauron") and l == "north_ithilien" and stato[l]["truppe"]["rohirrim"] >= 2 and stato[l]["truppe"]["elfi"] >= 2 and stato[l]["truppe"]["gondor"] >= 3:
		o.append({"testo": "Sfidare Sauron", "chiave": "ob_sauron"})
	if obiettivo_attivo("stendardo") and p == "arwen" and l == "minas_tirith" and e_rifugio(l) and disponibili(pos, "amicizia") >= 1:
		var t: Dictionary = stato[l]["truppe"]
		if t["gondor"] > 0 and t["rohirrim"] > 0 and t["elfi"] > 0 and t["nani"] > 0:
			o.append({"testo": "Arwen spiega lo stendardo (1 Amicizia)", "chiave": "ob_stendardo"})
	if obiettivo_attivo("balrog") and p == "gandalf" and l == "moria":
		o.append({"testo": "Affrontare il Balrog (3 dadi di battaglia)", "chiave": "ob_balrog"})
	if obiettivo_attivo("shelob") and p == "frodo" and l == "minas_morgul" and presente("gollum", l):
		o.append({"testo": "La tana di Shelob (3 dadi di battaglia)", "chiave": "ob_shelob"})
	if obiettivo_attivo("hobbit") and p == "pipino" and e_rifugio(l):
		var tipo := _tipo_rifugio(l)
		if tipo != "" and not hobbit.has(tipo) and riserva_simboli["amicizia"] > 0:
			for id in giocatori[pos]["mano"]:
				var c := Dati.carta(id)
				if c.get("tipo", "") == "regione" and c["simbolo"] == "amicizia" and c["regione"] == Dati.regione(l):
					o.append({"testo": "Gli Hobbit giurano fedeltà: scarta %s (Amicizia)" % Dati.nome_regione(c["regione"]), "chiave": "ob_hobbit", "carta": id})
					break
	if obiettivo_attivo("anello") and p == "frodo" and l == "mount_doom" and disponibili(pos, "resistenza") >= 5:
		var altri_fatti := true
		for ob in obiettivi:
			if ob["codice"] != "anello" and not ob["fatto"]:
				altri_fatti = false
		if altri_fatti:
			o.append({"testo": "DISTRUGGI L'UNICO ANELLO (5 Resistenza + ricerca finale)", "chiave": "ob_anello"})
	return o


func _tipo_rifugio(l: String) -> String:
	if l in ["grey_havens", "rivendell", "lorien", "woodland_realm"]:
		return "elfi"
	if l == "erebor":
		return "nani"
	if l == "helms_deep":
		return "rohirrim"
	if l in ["minas_tirith", "dol_amroth"]:
		return "gondor"
	return ""


## Eventi in mano e abilità «in qualsiasi momento»: non costano azioni.
func _opzioni_libere() -> Array:
	var o: Array = []
	for i in giocatori.size():
		for id in giocatori[i]["mano"]:
			var c := Dati.carta(id)
			if c.get("tipo", "") != "evento":
				continue
			if c["codice"] == "lembas" and (fase != "azioni" or attivo == ""):
				continue
			if not _evento_utile(c["codice"]):
				continue
			o.append({"testo": "Evento: %s%s" % [c["nome"], "" if solo else " (%s)" % giocatori[i]["nome"]], "chiave": "evento", "carta": id, "da": i})
	if in_gioco("legolas"):
		var pos := posto_di("legolas")
		if disponibili(pos, "furtivita") >= 1:
			var l: String = pg["legolas"]["luogo"]
			var bersagli := [l]
			bersagli.append_array(Dati.vicini(l).keys())
			for b in bersagli:
				if stato[b]["ombra"] > 0:
					o.append({"testo": "Colpo Sicuro: togli 1 truppa ombra a %s (1 Furtività)" % Dati.nome(b), "chiave": "tiro_sicuro", "luogo": b})
			var r := Dati.regione(l)
			if nazgul[r] > 0 and r != "mordor":
				o.append({"testo": "Colpo Sicuro: rimanda a Mordor 1 Nazgûl (1 Furtività)", "chiave": "tiro_nazgul"})
	if in_gioco("pipino"):
		var pos := posto_di("pipino")
		var r := Dati.regione(pg["pipino"]["luogo"])
		if nazgul[r] < 4 and disponibili(pos, "amicizia") >= 1:
			for r2 in Dati.regioni_vicine(r):
				if nazgul[r2] > 0:
					o.append({"testo": "Distrarre: attira fino a 2 Nazgûl da %s (1 Amicizia)" % Dati.nome_regione(r2), "chiave": "distrarre", "da_regione": r2})
	if in_gioco("galadriel") and e_rifugio(pg["galadriel"]["luogo"]) and not eventi_inutilizzati.is_empty() and disponibili(posto_di("galadriel"), "furtivita") >= 1:
		o.append({"testo": "Dama della Luce: pesca un evento non usato (1 Furtività)", "chiave": "signora_luce"})
	return o


func _evento_utile(cod: String) -> bool:
	match cod:
		"tom_bombadil":
			return speranza < Dati.SPERANZA_MAX
		"lotte_orchi", "ordini_contrastanti":
			for l in stato:
				if stato[l]["ombra"] > 0:
					return true
			return false
	return true


func _esegui_azione(p: String, o: Dictionary) -> void:
	var l: String = pg[p]["luogo"]
	var pos: int = posto_di(p)
	var costa := true
	match o["chiave"]:
		"viaggio":
			if o.get("gratis", false):
				costa = false
				usi["bonus_viaggio_eomer"] = true
			await _viaggio(p, o["luogo"], o["costo"], o.get("passi", 1))
		"compagnia":
			await _compagnia(p, o["con"])
		"prepara":
			await _prepara(p, int(o["carta"]))
		"arruola":
			var col: String = Dati.luogo(l)["arruolo"]
			if not _arruolo_gratis(p, col):
				await paga(pos, {"amicizia": 1}, "Radunare")
			var n := 2 if p == "gandalf" else 1
			n = min(n, riserva_truppe[col])
			aggiungi_truppe(l, col, n)
			_log("%s raduna %d truppa %s a %s." % [nome_pg(p), n, Dati.NOMI_ARMATE[col], Dati.nome(l)])
			_controlla_gollum(l)
		"attacca":
			sposta_occhio(Dati.regione(l), "attacco a %s" % Dati.nome(l))
			_log("%s attacca a %s con %d dadi." % [nome_pg(p), Dati.nome(l), o["dadi"]])
			await battaglia(l, int(o["dadi"]), true, p)
		"conquista":
			await paga(pos, o["costo"], "Conquista")
			await _conquista(l, p)
		"anduril":
			usi["anduril"] = true
			togli_ombra(l, 1)
			_log("Andúril: Aragorn toglie 1 truppa ombra a %s." % Dati.nome(l))
		"specchio":
			await _riordina_cima(pos, 4, false, "Specchio di Galadriel")
		"arte_nani":
			usi["arte_nani"] = true
			prendi_simbolo(pos, "valore")
		"passo_silenzioso":
			usi["passo_silenzioso"] = true
			prendi_simbolo(pos, "furtivita")
		"amico_leale":
			usi["amico_leale"] = true
			prendi_simbolo(pos, "amicizia")
		"canzone":
			await paga(pos, {"amicizia": 3}, "Dacci una Canzone!")
			cambia_speranza(2, "Dacci una Canzone!")
		"strisciante":
			usi["strisciante"] = true
			scarti.erase(int(o["carta"]))
			await dai_carta(pos, int(o["carta"]))
		"eldar":
			usi["eldar"] = true
			scarti.erase(int(o["carta"]))
			await dai_carta(pos, int(o["carta"]))
		"evento":
			costa = false
			await gioca_evento(int(o["da"]), int(o["carta"]))
		"tiro_sicuro":
			costa = false
			await paga(posto_di("legolas"), {"furtivita": 1}, "Colpo Sicuro")
			togli_ombra(o["luogo"], 1)
			if obiettivo_attivo("sei"):
				su_carta["sei"] = int(su_carta.get("sei", 0)) + 1
				riserva_ombra -= 1
				_log("Colpo Sicuro: la truppa va su «Con Questo Fanno Sei!» (%d/6)." % su_carta["sei"])
			else:
				_log("Colpo Sicuro: Legolas toglie 1 truppa ombra a %s." % Dati.nome(o["luogo"]))
		"tiro_nazgul":
			costa = false
			await paga(posto_di("legolas"), {"furtivita": 1}, "Colpo Sicuro")
			var r := Dati.regione(pg["legolas"]["luogo"])
			nazgul[r] -= 1
			nazgul["mordor"] += 1
			_log("Colpo Sicuro: un Nazgûl torna a Mordor.")
		"distrarre":
			costa = false
			await paga(posto_di("pipino"), {"amicizia": 1}, "Distrarre")
			var r := Dati.regione(pg["pipino"]["luogo"])
			var n: int = min(2, nazgul[o["da_regione"]], 4 - nazgul[r])
			nazgul[o["da_regione"]] -= n
			nazgul[r] += n
			_log("Merry & Pipino attirano %d Nazgûl in %s." % [n, Dati.nome_regione(r)])
		"signora_luce":
			costa = false
			await paga(posto_di("galadriel"), {"furtivita": 1}, "Dama della Luce")
			var e: int = eventi_inutilizzati.pop_at(rng.randi_range(0, eventi_inutilizzati.size() - 1))
			_log("Galadriel pesca l'evento «%s»." % Dati.carta(e)["nome"])
			await dai_carta(posto_di("galadriel"), e)
		"ob_benedizione":
			await paga(pos, {"amicizia": 3}, "Benedizione")
			await completa("benedizione")
		"ob_theoden":
			await paga(pos, {"amicizia": 2, "resistenza": 1}, "Théoden")
			await completa("theoden")
		"ob_denethor":
			await paga(pos, {"furtivita": 2, "amicizia": 1, "valore": 1}, "Denethor")
			await completa("denethor")
		"ob_sauron":
			await completa("sauron")
		"ob_stendardo":
			await paga(pos, {"amicizia": 1}, "Stendardo")
			await completa("stendardo")
		"ob_balrog":
			await _balrog()
		"ob_shelob":
			await _shelob()
		"ob_hobbit":
			var id := int(o["carta"])
			giocatori[pos]["mano"].erase(id)
			scarti.append(id)
			hobbit[_tipo_rifugio(l)] = true
			riserva_simboli["amicizia"] -= 1
			_log("Gli Hobbit mettono un segnalino Amicizia sul simbolo %s." % Dati.NOMI_ARMATE[_tipo_rifugio(l)])
		"ob_anello":
			await _distruggi_anello()
	if costa and o["chiave"] != "evento":
		azioni_rimaste -= 1


# -------------------------------------------------------------------------------------
# VIAGGIO
# -------------------------------------------------------------------------------------

func _viaggio(p: String, dest: String, costo: Dictionary, passi: int, senza_ricerca := false) -> void:
	var da: String = pg[p]["luogo"]
	var pos: int = posto_di(p)
	var compagni: Array = []
	var truppe := {}
	for a in Dati.ARMATE:
		truppe[a] = 0
	var da_solo := passi == 2
	if not da_solo:
		# chi viene con te?
		var altri: Array = []
		for q in personaggi_in(da):
			if q != p:
				altri.append(q)
		var porta_truppe := p != "gollum" and amiche(da) > 0
		if not altri.is_empty() or porta_truppe:
			while true:
				var op: Array = [{"testo": "Parti", "chiave": "parti"}]
				for q in altri:
					op.append({"testo": ("Lascia qui %s" if compagni.has(q) else "Porta con te %s") % nome_pg(q), "chiave": "pg", "pg": q})
				if porta_truppe:
					for a in Dati.ARMATE:
						var disp: int = stato[da]["truppe"][a]
						if disp > 0:
							if truppe[a] < disp:
								op.append({"testo": "Porta 1 truppa %s (%d/%d)" % [Dati.NOMI_ARMATE[a], truppe[a], disp], "chiave": "truppa", "armata": a})
							if truppe[a] > 0:
								op.append({"testo": "Lascia 1 truppa %s" % Dati.NOMI_ARMATE[a], "chiave": "lascia", "armata": a})
				var r := await chiedi(turno_di, {"tipo": "accompagna", "titolo": "%s va a %s" % [nome_pg(p), Dati.nome(dest)],
					"testo": "Chi e che cosa porta con sé?", "opzioni": op, "conferma": true, "pg": p, "luogo": dest,
					"portate": truppe.values().reduce(func(a, b): return a + b, 0), "compagni": compagni.duplicate()})
				var x: Dictionary = op[r]
				if x["chiave"] == "parti":
					break
				elif x["chiave"] == "pg":
					if compagni.has(x["pg"]):
						compagni.erase(x["pg"])
					else:
						compagni.append(x["pg"])
				elif x["chiave"] == "truppa":
					truppe[x["armata"]] += 1
				else:
					truppe[x["armata"]] -= 1
	if not costo.is_empty():
		await paga(pos, costo, "Sentiero speciale")
	var con_frodo: bool = p == "frodo" or compagni.has("frodo")
	# muove tutti
	pg[p]["luogo"] = dest
	for q in compagni:
		pg[q]["luogo"] = dest
	var nt := 0
	for a in Dati.ARMATE:
		if truppe[a] > 0:
			stato[da]["truppe"][a] -= truppe[a]
			stato[dest]["truppe"][a] += truppe[a]
			nt += truppe[a]
	var chi := nome_pg(p)
	if not compagni.is_empty():
		var nn: Array = []
		for q in compagni:
			nn.append(nome_pg(q))
		chi += " con " + ", ".join(nn)
	_log("%s viaggia da %s a %s%s." % [chi, Dati.nome(da), Dati.nome(dest), "" if nt == 0 else " (%d truppe)" % nt])
	evento.emit("viaggio", {"pg": [p] + compagni, "da": da, "a": dest})
	if da_solo:
		pass
	_controlla_gollum(dest)
	await _controlla_aragorn_erech(p, da, dest)
	if con_frodo and not senza_ricerca:
		var furt := disponibili(turno_di if not solo else 0, "furtivita")
		var spende := false
		if furt > 0:
			spende = await _si_no(turno_di, "Frodo viaggia", "Spendi 1 Furtività per non tirare la ricerca a %s?" % Dati.nome(dest), "Spendi 1 Furtività", "Tira la ricerca", "furtivita_frodo", {"luogo": dest})
		if spende:
			await paga(turno_di, {"furtivita": 1}, "Frodo viaggia")
		else:
			await ricerca("viaggio di Frodo")
	# Faramir: Imboscata
	if p == "faramir" and nt > 0 and stato[dest]["ombra"] > 0 and amiche(dest) > 0 and esito == "":
		if await _si_no(turno_di, "Imboscata", "Faramir può fare un attacco gratis a %s. Attacca?" % Dati.nome(dest), "Attacca", "No", "imboscata"):
			sposta_occhio(Dati.regione(dest), "imboscata")
			await battaglia(dest, min(3, amiche(dest)), true, "faramir", true)


func _controlla_aragorn_erech(p: String, da: String, dest: String) -> void:
	if p == "aragorn" and da == "edoras" and dest == "erech" and obiettivo_attivo("spergiuri") and not aragorn_erech:
		aragorn_erech = true
		_log("Gli Spergiuri seguono Aragorn: l'Ombra si raccoglie a Pelargir, Gondor si arma a Erech.")
		await aggiungi_ombra("pelargir", 2, false)
		var n: int = stato["umbar"]["ombra"]
		stato["umbar"]["ombra"] = 0
		stato["pelargir"]["ombra"] += n
		var k: int = min(3, riserva_truppe["gondor"])
		aggiungi_truppe("erech", "gondor", k)
		await _controlla_rifugi()


## «Ci Hanno Ingannato!»: Gollum, Frodo e truppe amiche nello stesso luogo costano 1 speranza.
func _controlla_gollum(l: String) -> void:
	if in_gioco("gollum") and in_gioco("frodo") and pg["gollum"]["luogo"] == l and pg["frodo"]["luogo"] == l and amiche(l) > 0:
		cambia_speranza(-1, "Ci Hanno Ingannato! (Gollum, Frodo e truppe amiche a %s)" % Dati.nome(l))


# -------------------------------------------------------------------------------------
# COMPAGNIA, PREPARARE, CARTE
# -------------------------------------------------------------------------------------

func _compagnia(p: String, q: String) -> void:
	var a: int = posto_di(p)
	var b: int = posto_di(q)
	var reg := Dati.regione(pg[p]["luogo"])
	var libero: bool = p == "arwen" and e_rifugio(pg[p]["luogo"]) and not usi.get("consiglio_arwen", false)
	var boro: bool = p == "boromir" or q == "boromir"
	var op: Array = []
	for pair in [[a, b, "Dai"], [b, a, "Prendi"]]:
		for id in giocatori[pair[0]]["mano"]:
			var c := Dati.carta(id)
			if c.get("tipo", "") != "regione":
				continue
			if c["regione"] != reg and not libero:
				continue
			if boro and c["simbolo"] == "resistenza":
				continue
			op.append({"testo": "%s %s (%s, %s)" % [pair[2], Dati.nome_regione(c["regione"]), Dati.NOMI_SIMBOLI[c["simbolo"]], giocatori[pair[0]]["nome"]], "da": pair[0], "a": pair[1], "carta": id})
	if op.is_empty():
		_log("Nessuna carta di %s da scambiare." % Dati.nome_regione(reg))
		return
	var r := await chiedi(turno_di, {"tipo": "compagnia", "titolo": "Compagnia", "testo": "Quale carta passa di mano?", "opzioni": op})
	var x: Dictionary = op[r]
	var id: int = x["carta"]
	if libero and Dati.carta(id)["regione"] != reg:
		usi["consiglio_arwen"] = true
	giocatori[x["da"]]["mano"].erase(id)
	_log("%s passa %s a %s." % [giocatori[x["da"]]["nome"], Dati.nome_regione(Dati.carta(id)["regione"]), giocatori[x["a"]]["nome"]])
	await dai_carta(x["a"], id)


func _prepara(p: String, id: int) -> void:
	var pos: int = posto_di(p)
	var c := Dati.carta(id)
	var l: String = pg[p]["luogo"]
	if solo and p == "arwen" and c["regione"] != Dati.regione(l):
		usi["consiglio_arwen"] = true
	giocatori[pos]["mano"].erase(id)
	scarti.append(id)
	prendi_simbolo(pos, c["simbolo"])
	_log("%s prepara: scarta %s e prende un segnalino %s." % [nome_pg(p), Dati.nome_regione(c["regione"]), Dati.NOMI_SIMBOLI[c["simbolo"]]])
	if p == "frodo" and not usi.get("elrond", false) and e_rifugio(l) and c["regione"] == Dati.regione(l) and riserva_simboli["amicizia"] > 0:
		usi["elrond"] = true
		prendi_simbolo(pos, "amicizia")
		_log("Sostegno di Elrond: Frodo prende anche 1 Amicizia.")
	if p == "arwen" and stato[l]["truppe"]["elfi"] > 0:
		var op: Array = [{"testo": "Nessuno"}]
		for q in pg:
			if q != "arwen" and in_gioco(q) and Dati.regione(pg[q]["luogo"]) == c["regione"] and pg[q]["luogo"] != l:
				op.append({"testo": "Manda 1 truppa elfica da %s" % nome_pg(q), "pg": q, "luogo": pg[q]["luogo"]})
		if op.size() > 1:
			var r := await chiedi(turno_di, {"tipo": "scelta", "titolo": "Inviare Aiuto", "testo": "Arwen può mandare 1 truppa elfica a un personaggio nella regione della carta.", "opzioni": op, "conferma": true})
			if r > 0:
				stato[l]["truppe"]["elfi"] -= 1
				stato[op[r]["luogo"]]["truppe"]["elfi"] += 1
				_log("Arwen manda una truppa elfica a %s." % Dati.nome(op[r]["luogo"]))
	if p == "legolas" and not usi.get("vista_acuta", false) and not mazzo_ombra.is_empty():
		usi["vista_acuta"] = true
		var top: int = mazzo_ombra.back()
		_log("Vista Acuta: la prima carta dell'Ombra è «%s»." % descrivi_ombra(top))
		evento.emit("guarda_ombra", {"carte": [top]})
	if p == "gollum" and stato[l]["ombra"] > 0:
		var op: Array = [{"testo": "Nessuna"}]
		for v in Dati.vicini(l):
			op.append({"testo": "Sposta 1 truppa ombra a %s" % Dati.nome(v), "luogo": v})
		var r := await chiedi(turno_di, {"tipo": "scelta", "titolo": "Astuto", "testo": "Gollum può spostare 1 truppa ombra in un luogo vicino (senza battaglia).", "opzioni": op, "conferma": true})
		if r > 0:
			stato[l]["ombra"] -= 1
			stato[op[r]["luogo"]]["ombra"] += 1
			await _controlla_rifugi()


func prendi_simbolo(pos: int, s: String) -> void:
	if riserva_simboli[s] <= 0:
		return
	riserva_simboli[s] -= 1
	giocatori[pos]["gettoni"][s] += 1


## Dà una carta a un giocatore e fa rispettare il limite di 7 carte.
func dai_carta(pos: int, id: int) -> void:
	giocatori[pos]["mano"].append(id)
	await limite_mano(pos)


func limite_mano(pos: int) -> void:
	while giocatori[pos]["mano"].size() > 7 and esito == "":
		var op: Array = []
		for id in giocatori[pos]["mano"]:
			var c := Dati.carta(id)
			if c["tipo"] == "evento":
				op.append({"testo": "Gioca l'evento «%s»" % c["nome"], "carta": id, "gioca": true})
				op.append({"testo": "Scarta l'evento «%s»" % c["nome"], "carta": id})
			else:
				op.append({"testo": "Scarta %s (%s)" % [Dati.nome_regione(c["regione"]), Dati.NOMI_SIMBOLI[c["simbolo"]]], "carta": id})
		var r := await chiedi(pos, {"tipo": "scarta", "titolo": "Limite di 7 carte", "testo": "%s ha %d carte: scartane una (o gioca un evento)." % [giocatori[pos]["nome"], giocatori[pos]["mano"].size()], "opzioni": op})
		var x: Dictionary = op[r]
		if x.get("gioca", false):
			await gioca_evento(pos, int(x["carta"]))
		else:
			giocatori[pos]["mano"].erase(int(x["carta"]))
			scarti.append(int(x["carta"]))


## Paga simboli: per ogni unità chiede se usare un segnalino o una carta (quando c'è scelta).
func paga(pos: int, costo: Dictionary, motivo: String) -> void:
	for s in costo:
		for k in int(costo[s]):
			var op: Array = []
			if giocatori[pos]["gettoni"][s] > 0:
				op.append({"testo": "Segnalino %s" % Dati.NOMI_SIMBOLI[s], "gettone": true})
			var viste := {}
			for id in giocatori[pos]["mano"]:
				var c := Dati.carta(id)
				if c.get("tipo", "") == "regione" and c["simbolo"] == s and not viste.has(c["regione"]):
					viste[c["regione"]] = true
					op.append({"testo": "Carta %s (%s)" % [Dati.nome_regione(c["regione"]), Dati.NOMI_SIMBOLI[s]], "carta": id})
			if op.is_empty():
				return
			var r := await chiedi(pos, {"tipo": "paga", "titolo": "%s: paga 1 %s" % [motivo, Dati.NOMI_SIMBOLI[s]], "testo": "Con che cosa paghi?", "opzioni": op, "simbolo": s})
			var x: Dictionary = op[r]
			if x.get("gettone", false):
				giocatori[pos]["gettoni"][s] -= 1
				riserva_simboli[s] += 1
			else:
				giocatori[pos]["mano"].erase(int(x["carta"]))
				scarti.append(int(x["carta"]))
	cambiato.emit()


func _riordina_cima(pos: int, n: int, prendi: bool, titolo: String) -> void:
	var viste: Array = []
	for k in min(n, mazzo.size()):
		viste.append(mazzo.pop_back())
	if prendi:
		var op: Array = [{"testo": "Non prendere nulla"}]
		for id in viste:
			var c := Dati.carta(id)
			if c["tipo"] != "cieli":
				op.append({"testo": "Prendi %s" % _nome_carta(id), "carta": id})
		evento.emit("guarda_carte", {"carte": viste, "titolo": titolo})
		var r := await chiedi(turno_di, {"tipo": "scelta", "titolo": titolo, "testo": "Puoi prendere una delle carte.", "opzioni": op, "carte": viste, "conferma": true})
		if r > 0:
			viste.erase(int(op[r]["carta"]))
			await dai_carta(turno_di, int(op[r]["carta"]))
	# rimette in cima nell'ordine scelto (l'ultima scelta finisce in cima)
	var ordine: Array = []
	while not viste.is_empty():
		var op: Array = []
		for id in viste:
			op.append({"testo": "%s" % _nome_carta(id), "carta": id})
		var r := await chiedi(turno_di, {"tipo": "ordina", "titolo": titolo, "testo": "Scegli la carta da mettere più in fondo fra queste (l'ultima resterà in cima).", "opzioni": op, "carte": viste})
		ordine.append(viste[r])
		viste.remove_at(r)
	for id in ordine:
		mazzo.append(id)


func _nome_carta(id: int) -> String:
	var c := Dati.carta(id)
	match c.get("tipo", ""):
		"regione":
			return "%s (%s)" % [Dati.nome_regione(c["regione"]), Dati.NOMI_SIMBOLI[c["simbolo"]]]
		"evento":
			return "evento «%s»" % c["nome"]
		"cieli":
			return "Oscuramento dei Cieli"
	return str(id)


# -------------------------------------------------------------------------------------
# TRUPPE, OCCHIO, SPERANZA
# -------------------------------------------------------------------------------------

func aggiungi_truppe(l: String, a: String, n: int) -> void:
	var k: int = min(n, riserva_truppe[a])
	riserva_truppe[a] -= k
	stato[l]["truppe"][a] += k


func togli_amica(l: String, a: String, n := 1) -> void:
	var k: int = min(n, stato[l]["truppe"][a])
	stato[l]["truppe"][a] -= k
	riserva_truppe[a] += k


func togli_ombra(l: String, n: int) -> int:
	var k: int = min(n, stato[l]["ombra"])
	stato[l]["ombra"] -= k
	riserva_ombra += k
	return k


## Aggiunge truppe ombra (perdendo speranza per quelle che mancano) e, se richiesto, tira la battaglia.
func aggiungi_ombra(l: String, n: int, con_battaglia: bool) -> void:
	var k: int = min(n, riserva_ombra)
	stato[l]["ombra"] += k
	riserva_ombra -= k
	if k < n:
		cambia_speranza(-(n - k), "mancano truppe ombra nella riserva")
	if con_battaglia and amiche(l) > 0 and esito == "":
		await battaglia(l, min(3, stato[l]["ombra"]), false, "")
	await _controlla_rifugi()


func sposta_occhio(r: String, perche := "") -> void:
	if occhio != r:
		occhio = r
		_log("L'Occhio di Sauron si volge su %s%s." % [Dati.nome_regione(r), "" if perche == "" else " (%s)" % perche])
		evento.emit("occhio", {"regione": r})


func cambia_speranza(n: int, perche: String) -> void:
	if n == 0 or esito != "":
		return
	var prima := speranza
	speranza = clampi(speranza + n, 0, Dati.SPERANZA_MAX)
	if speranza == prima:
		return
	if n > 0:
		_log("+%d speranza: %s." % [speranza - prima, perche])
	else:
		_log("%d speranza: %s." % [speranza - prima, perche])
	evento.emit("speranza", {"delta": speranza - prima})
	if speranza <= 0:
		esito = "sconfitta"
		_log("Frodo ha perso ogni speranza. L'Ombra copre la Terra di Mezzo.")


## Rifugi caduti: truppe ombra e nessuna truppa amica → roccaforte ombra, -3 speranza.
func _controlla_rifugi() -> void:
	for l in stato:
		if e_rifugio(l) and stato[l]["ombra"] > 0 and amiche(l) == 0:
			stato[l]["tipo"] = "fortezza"
			_log("%s cade nelle mani dell'Ombra!" % Dati.nome(l))
			evento.emit("rifugio_caduto", {"luogo": l})
			cambia_speranza(-3, "%s è caduto" % Dati.nome(l))
	cambiato.emit()


func _conquista(l: String, p: String) -> void:
	stato[l]["tipo"] = "rifugio"
	if Dati.luogo(l)["tipo"] in ["fortezza", "ombra"]:
		stato[l]["liberata"] = true
	_log("%s conquista %s: ora è un rifugio!" % [nome_pg(p), Dati.nome(l)])
	evento.emit("conquista", {"luogo": l})
	sposta_occhio(Dati.regione(l), "conquista")
	cambia_speranza(2, "conquista di %s" % Dati.nome(l))
	_controlla_obiettivi()


# -------------------------------------------------------------------------------------
# BATTAGLIE
# -------------------------------------------------------------------------------------

func tira(n: int, facce: Array) -> Array:
	var r: Array = []
	for k in n:
		r.append(facce[rng.randi_range(0, facce.size() - 1)])
	return r


## Tira una battaglia nel luogo. dadi: quanti dadi. attacco: iniziata dai personaggi.
func battaglia(l: String, dadi: int, attacco: bool, chi: String, imboscata := false) -> void:
	if dadi <= 0 or esito != "":
		return
	in_battaglia = true
	var r := Dati.regione(l)
	var esiti := tira(dadi, Dati.FACCE_BATTAGLIA)
	evento.emit("dadi", {"tipo": "battaglia", "facce": esiti.duplicate(), "luogo": l})
	_log("Combattimento a %s: %s." % [Dati.nome(l), _testo_facce(esiti)])
	var presenti := personaggi_in(l)
	var tolte_ombra := 0
	var valore_speso := 0
	var tom := true
	# modifiche dopo il tiro
	while esito == "":
		var op: Array = [{"testo": "Risolvi il combattimento: %s" % _testo_facce(esiti), "chiave": "ok"}]
		var paganti := _paganti(presenti)
		for pos in paganti:
			var who := "" if solo else " (%s)" % giocatori[pos]["nome"]
			if disponibili(pos, "resistenza") > 0:
				for k in esiti.size():
					if esiti[k] != "rotta":
						op.append({"testo": "Ritira il dado %d (%s) con 1 Resistenza%s" % [k + 1, Dati.NOMI_FACCE[esiti[k]], who], "chiave": "ritira", "dado": k, "pos": pos})
			if disponibili(pos, "valore") > 0 and stato[l]["ombra"] - tolte_ombra > 0:
				op.append({"testo": "Mostra valore: togli 1 truppa ombra con 1 Valore%s" % who, "chiave": "valore", "pos": pos})
		if presente("gandalf", l) and disponibili(posto_di("gandalf"), "valore") > 0:
			var bianco: bool = pg["gandalf"]["bianco"]
			for k in esiti.size():
				if esiti[k] != "rotta":
					op.append({"testo": "Luce e Fiamme: dado %d in Rotta (1 Valore%s)" % [k + 1, ", tutti i dadi" if bianco else ""], "chiave": "fiamma", "dado": k})
					if bianco:
						break
		if presente("galadriel", l) and stato[l]["truppe"]["elfi"] > 0 and not usi.get("nenya_battaglia", false):
			for k in esiti.size():
				if esiti[k] != "rotta":
					op.append({"testo": "Nenya: ritira il dado %d gratis" % [k + 1], "chiave": "nenya", "dado": k})
		if imboscata and in_gioco("faramir") and disponibili(posto_di("faramir"), "furtivita") > 0:
			for k in esiti.size():
				if esiti[k] != "rotta":
					op.append({"testo": "Imboscata: dado %d in Rotta (1 Furtività)" % [k + 1], "chiave": "imboscata", "dado": k})
		if obiettivo_attivo("eowyn") and presente("eowyn", l) and disponibili(posto_di("eowyn"), "valore") >= 2 and nazgul[r] > 0:
			for k in esiti.size():
				if esiti[k] != "nazgul":
					op.append({"testo": "Éowyn: dado %d in Nazgûl! (2 Valore)" % [k + 1], "chiave": "eowyn", "dado": k})
		if tom:
			var t := _chi_ha_evento("tom_bombadil")
			if t >= 0:
				op.append({"testo": "Tom Bombadil: ritira fino a 3 dadi", "chiave": "tom", "pos": t})
		var sc := await chiedi(turno_di, {"tipo": "battaglia", "titolo": "Combattimento a %s" % Dati.nome(l), "testo": _testo_facce(esiti), "opzioni": op, "facce": esiti, "luogo": l})
		var x: Dictionary = op[sc]
		match x["chiave"]:
			"ok":
				break
			"ritira":
				await paga(int(x["pos"]), {"resistenza": 1}, "Ritirare un dado")
				esiti[x["dado"]] = tira(1, Dati.FACCE_BATTAGLIA)[0]
			"valore":
				await paga(int(x["pos"]), {"valore": 1}, "Mostrare valore")
				tolte_ombra += togli_ombra(l, 1)
				valore_speso += 1
			"fiamma":
				await paga(posto_di("gandalf"), {"valore": 1}, "Luce e Fiamme")
				if pg["gandalf"]["bianco"]:
					for k in esiti.size():
						esiti[k] = "rotta"
				else:
					esiti[x["dado"]] = "rotta"
			"nenya":
				usi["nenya_battaglia"] = true
				esiti[x["dado"]] = tira(1, Dati.FACCE_BATTAGLIA)[0]
			"imboscata":
				await paga(posto_di("faramir"), {"furtivita": 1}, "Imboscata")
				esiti[x["dado"]] = "rotta"
			"eowyn":
				await paga(posto_di("eowyn"), {"valore": 2}, "Non Più Fanciulla dello Scudo")
				esiti[x["dado"]] = "nazgul"
			"tom":
				tom = false
				await _scarta_evento("tom_bombadil")
				var k := 0
				for j in esiti.size():
					if esiti[j] != "rotta" and k < 3:
						esiti[j] = tira(1, Dati.FACCE_BATTAGLIA)[0]
						k += 1
		evento.emit("dadi", {"tipo": "battaglia", "facce": esiti.duplicate(), "luogo": l, "modifica": true})
	usi.erase("nenya_battaglia")
	# risoluzione
	var perdite := 0
	var togli := 0
	for f in esiti:
		match f:
			"rotta":
				togli += 2 if presente("aragorn", l) else 1
			"scambio":
				togli += 1
				perdite += 1
			"travolti":
				if not e_rifugio(l):
					perdite += 1
			"nazgul":
				if nazgul[r] > 0:
					if presente("eowyn", l):
						nazgul[r] -= 1
						nazgul_eowyn += 1
						_log("Éowyn distrugge un Nazgûl!")
					else:
						perdite += 2
	if presente("eomer", l) and stato[l]["truppe"]["rohirrim"] > 0 and perdite > 0:
		perdite -= 1
	var prima_amiche := amiche(l)
	var tolte := togli_ombra(l, togli)
	tolte_ombra += tolte
	if perdite > 0:
		await _perdi_amiche(l, perdite)
	_log("Esito: tolte %d truppe ombra, perse %d truppe amiche." % [tolte_ombra, min(perdite, prima_amiche)])
	# Cavalcare con l'éored
	if chi == "eomer" and attacco and obiettivo_attivo("eored") and tolte_ombra > 0 and prima_amiche > 0:
		var reg := Dati.regione(pg["eomer"]["luogo"])
		var spazi := ["rohan"] + Dati.regioni_vicine("rohan")
		if spazi.has(reg) and not eored.has(reg) and riserva_ombra > 0:
			eored[reg] = true
			riserva_ombra -= 1
			su_carta["eored"] = eored.size()
			_log("Una truppa ombra va sullo spazio %s di «Cavalcare con gli Éored» (%d/4)." % [Dati.nome_regione(reg), eored.size()])
	# Boromir riscatta il suo onore
	if obiettivo_attivo("boromir") and presente("boromir", l) and personaggi_in(l).size() > 1 and prima_amiche > 0 and amiche(l) == 0:
		await completa("boromir")
	in_battaglia = false
	await _controlla_rifugi()
	_controlla_obiettivi()


func _testo_facce(f: Array) -> String:
	var t: Array = []
	for x in f:
		t.append(Dati.NOMI_FACCE[x])
	return ", ".join(t) if not t.is_empty() else "nessun dado"


## I posti che possono spendere per i personaggi presenti (in solitario uno solo).
func _paganti(presenti: Array) -> Array:
	var r: Array = []
	for p in presenti:
		var pos := posto_di(p)
		if not r.has(pos):
			r.append(pos)
	return r


func _perdi_amiche(l: String, n: int) -> void:
	for k in n:
		var tipi: Array = []
		for a in Dati.ARMATE:
			if stato[l]["truppe"][a] > 0:
				tipi.append(a)
		if tipi.is_empty():
			return
		var a: String = tipi[0]
		if tipi.size() > 1:
			var op: Array = []
			for t in tipi:
				op.append({"testo": "Perdi 1 truppa %s (%d)" % [Dati.NOMI_ARMATE[t], stato[l]["truppe"][t]], "armata": t})
			a = op[await chiedi(turno_di, {"tipo": "perdita", "titolo": "Perdite a %s" % Dati.nome(l), "testo": "Quale truppa amica perdete? (%d di %d)" % [k + 1, n], "opzioni": op})]["armata"]
		togli_amica(l, a)


func _chi_ha_evento(cod: String) -> int:
	for i in giocatori.size():
		for id in giocatori[i]["mano"]:
			var c := Dati.carta(id)
			if c.get("tipo", "") == "evento" and c["codice"] == cod:
				return i
	return -1


func _scarta_evento(cod: String) -> void:
	for i in giocatori.size():
		for id in giocatori[i]["mano"]:
			var c := Dati.carta(id)
			if c.get("tipo", "") == "evento" and c["codice"] == cod:
				giocatori[i]["mano"].erase(id)
				scarti.append(id)
				_log("%s gioca «%s»." % [giocatori[i]["nome"], c["nome"]])
				return


# -------------------------------------------------------------------------------------
# RICERCHE
# -------------------------------------------------------------------------------------

func dadi_ricerca(extra := 0, ignora_ombra := false) -> int:
	if not in_gioco("frodo"):
		return 0
	var l := luogo_frodo()
	var n: int = nazgul[Dati.regione(l)] + (0 if ignora_ombra else int(stato[l]["ombra"])) + extra
	if presente("gollum", l):
		n -= 3
	return clampi(n, 0, 7)


func ricerca(perche: String, finale := false, extra := 0) -> bool:
	if esito != "" or not in_gioco("frodo"):
		return true
	var l := luogo_frodo()
	var r := Dati.regione(l)
	var pf := posto_di("frodo")
	var ignora := false
	if not finale and stato[l]["ombra"] > 0 and speranza > 1:
		if await _si_no(pf, "Indossare l'Anello", "Prima della ricerca (%s), Frodo può mettere l'Anello: ignora le %d truppe ombra, ma perde 1 speranza e l'Occhio si volge su di lui." % [perche, stato[l]["ombra"]], "Metti l'Anello", "No", "anello_ricerca"):
			ignora = true
			cambia_speranza(-1, "Frodo mette l'Anello")
			sposta_occhio(r, "l'Anello")
	var n := dadi_ricerca(extra, ignora)
	if n <= 0:
		_log("Tiro di ricerca (%s): nessun dado da tirare." % perche)
		return true
	var esiti := tira(n, Dati.FACCE_RICERCA)
	evento.emit("dadi", {"tipo": "ricerca", "facce": esiti.duplicate(), "luogo": l})
	_log("Tiro di ricerca (%s): %s." % [perche, _testo_facce(esiti)])
	var presenti := personaggi_in(l)
	var ignorati := 0
	var aragorn := presente("aragorn", l)
	var tom := true
	while esito == "":
		var op: Array = [{"testo": "Risolvi il tiro di ricerca: %s" % _testo_facce(esiti), "chiave": "ok"}]
		for pos in _paganti(presenti):
			if disponibili(pos, "resistenza") > 0:
				for k in esiti.size():
					if esiti[k] != "sfuggito":
						op.append({"testo": "Ritira il dado %d (%s) con 1 Resistenza%s" % [k + 1, Dati.NOMI_FACCE[esiti[k]], "" if solo else " (%s)" % giocatori[pos]["nome"]], "chiave": "ritira", "dado": k, "pos": pos})
		if aragorn:
			for k in esiti.size():
				if esiti[k] != "sfuggito":
					op.append({"testo": "Ramingo del Nord: ritira gratis il dado %d" % [k + 1], "chiave": "ramingo", "dado": k})
		if disponibili(pf, "amicizia") > 0:
			for k in esiti.size():
				if esiti[k] in ["stanchezza", "scoperto"]:
					op.append({"testo": "Aiuto di Sam: ignora il dado %d con 1 Amicizia" % [k + 1], "chiave": "sam", "dado": k})
		if tom:
			var t := _chi_ha_evento("tom_bombadil")
			if t >= 0:
				op.append({"testo": "Tom Bombadil: ritira fino a 3 dadi", "chiave": "tom"})
		var sc := await chiedi(turno_di, {"tipo": "ricerca", "titolo": "Tiro di ricerca: %s" % perche, "testo": _testo_facce(esiti), "opzioni": op, "facce": esiti, "luogo": l})
		var x: Dictionary = op[sc]
		match x["chiave"]:
			"ok":
				break
			"ritira":
				await paga(int(x["pos"]), {"resistenza": 1}, "Ritirare un dado")
				esiti[x["dado"]] = tira(1, Dati.FACCE_RICERCA)[0]
			"ramingo":
				aragorn = false
				esiti[x["dado"]] = tira(1, Dati.FACCE_RICERCA)[0]
			"sam":
				await paga(pf, {"amicizia": 1}, "Aiuto di Sam")
				esiti[x["dado"]] = "sfuggito"
			"tom":
				tom = false
				await _scarta_evento("tom_bombadil")
				var k := 0
				for j in esiti.size():
					if esiti[j] != "sfuggito" and k < 3:
						esiti[j] = tira(1, Dati.FACCE_RICERCA)[0]
						k += 1
		evento.emit("dadi", {"tipo": "ricerca", "facce": esiti.duplicate(), "luogo": l, "modifica": true})
	var persa := 0
	for f in esiti:
		match f:
			"stanchezza":
				persa += 1
			"scoperto":
				if not e_rifugio(l):
					persa += 1
			"richiamo":
				if r != "mordor" and nazgul[r] > 0:
					nazgul[r] -= 1
					nazgul["mordor"] += 1
					_log("Un Nazgûl viene richiamato a Mordor.")
	if persa > 0:
		cambia_speranza(-persa, "ricerca")
	cambiato.emit()
	return esito == ""


# -------------------------------------------------------------------------------------
# 2. PESCARE LE CARTE
# -------------------------------------------------------------------------------------

func _pesca_carte() -> void:
	var pos := turno_di
	var pescate: Array = []
	for k in 2:
		if mazzo.is_empty():
			cambia_speranza(-1, "il mazzo dei giocatori è finito")
			continue
		pescate.append(mazzo.pop_back())
	evento.emit("pesca", {"carte": pescate, "posto": pos})
	var cieli := 0
	for id in pescate:
		if Dati.carta(id)["tipo"] == "cieli":
			cieli += 1
	for id in pescate:
		if Dati.carta(id)["tipo"] == "cieli":
			await _cielo_si_oscura(id)
			if esito != "":
				return
	for id in pescate:
		if Dati.carta(id)["tipo"] != "cieli":
			giocatori[pos]["mano"].append(id)
			_log("%s pesca %s." % [giocatori[pos]["nome"], _nome_carta(id)])
	await limite_mano(pos)


func _cielo_si_oscura(id: int) -> void:
	var c := Dati.carta(id)
	_log("OSCURAMENTO DEI CIELI!")
	evento.emit("cieli", {"carta": id})
	# 1. l'Ombra cresce
	minaccia = min(minaccia + 1, Dati.MINACCIA.size() - 1)
	_log("La minaccia sale a %d." % valore_minaccia())
	# 2. Ti vedo!
	if occhio == regione_frodo():
		cambia_speranza(-2, "Ti vedo! L'Occhio era già su Frodo")
	else:
		sposta_occhio(regione_frodo(), "Ti vedo!")
	if esito != "":
		return
	# 3. Col favore delle tenebre
	_log("Col favore delle tenebre: 3 truppe ombra a %s." % Dati.nome(c["luogo"]))
	await aggiungi_ombra(c["luogo"], 3, true)
	# 4. Il pericolo aumenta
	_mescola(scarti_ombra)
	mazzo_ombra.append_array(scarti_ombra)
	scarti_ombra.clear()
	# Gandalf il Bianco
	if gandalf_attesa and pg.has("gandalf"):
		gandalf_attesa = false
		pg["gandalf"]["fuori"] = false
		pg["gandalf"]["bianco"] = true
		pg["gandalf"]["luogo"] = "lorien"
		_log("Gandalf torna a Lórien come Gandalf il Bianco!")
		cambia_speranza(2, "il ritorno di Gandalf")
	cambiato.emit()


# -------------------------------------------------------------------------------------
# 3. CARTE DELL'OMBRA
# -------------------------------------------------------------------------------------

func _carte_ombra() -> void:
	risolte.clear()
	# ultima occasione per eventi prima delle carte dell'Ombra
	await _finestra_libera("Prima delle carte dell'Ombra")
	for k in valore_minaccia():
		if esito != "":
			return
		if mazzo_ombra.is_empty():
			_mescola(scarti_ombra)
			mazzo_ombra = scarti_ombra.duplicate()
			scarti_ombra.clear()
		if mazzo_ombra.is_empty():
			return
		var id: int = mazzo_ombra.pop_back()
		ultima_ombra = id
		risolte.append(id)
		var c := Dati.carta(id)
		if c.has("speciale"):
			evento.emit("ombra", {"carta": id, "parte": "speciale"})
			await _ombra_speciale(c)
		else:
			# il dorso della carta ora in cima decide quale metà si risolve
			var parte := "avanzata"
			if not mazzo_ombra.is_empty():
				parte = "avanzata" if Dati.carta(mazzo_ombra.back())["retro"] == "bandiera" else "rinforzo"
			else:
				parte = "avanzata" if rng.randi() % 2 == 0 else "rinforzo"
			evento.emit("ombra", {"carta": id, "parte": parte})
			if parte == "avanzata":
				await avanzata(c["linea"])
			else:
				await rinforzo(c)
		cambiato.emit()
		if k < valore_minaccia() - 1:
			await _finestra_libera("Fra una carta dell'Ombra e l'altra")
	for id in risolte:
		scarti_ombra.append(id)
	risolte.clear()


## Momento in cui si possono giocare eventi e abilità gratuite fuori dalle azioni.
func _finestra_libera(titolo: String) -> void:
	while esito == "":
		var op := _opzioni_libere()
		if op.is_empty():
			return
		op.push_front({"testo": "Continua", "chiave": "fine"})
		var r := await chiedi(turno_di, {"tipo": "libera", "titolo": titolo, "testo": "Potete giocare eventi o abilità che non costano azioni.", "opzioni": op, "conferma": true})
		if op[r]["chiave"] == "fine":
			return
		await _esegui_azione(attivo if attivo != "" else "frodo", op[r])
		_controlla_obiettivi()
		cambiato.emit()


func descrivi_ombra(id: int) -> String:
	var c := Dati.carta(id)
	if c.has("speciale"):
		return c["nome"]
	var li: Dictionary = Dati.linea(c["linea"])
	return "da %s a %s / +1 a %s" % [Dati.nome(li["percorso"][0]), Dati.nome(li["percorso"][-1]), Dati.nome(c["rinforzo"])]


func avanzata(lid: String) -> void:
	var li: Dictionary = Dati.linea(lid)
	var p: Array = li["percorso"]
	_log("AVANZATA lungo la linea da %s a %s." % [Dati.nome(p[0]), Dati.nome(p[-1])])
	var mosse := false
	for k in range(p.size() - 2, -1, -1):
		var l: String = p[k]
		if e_rifugio(l) and stato[l]["liberata"] and k == 0:
			continue
		var n: int = stato[l]["ombra"]
		if n > 0:
			stato[l]["ombra"] = 0
			stato[p[k + 1]]["ombra"] += n
			mosse = true
	evento.emit("avanzata", {"linea": lid})
	if not mosse:
		_log("Nessuna truppa ombra su questa linea.")
	for k in range(p.size() - 1, -1, -1):
		var l: String = p[k]
		if stato[l]["ombra"] > 0 and amiche(l) > 0 and esito == "":
			await battaglia(l, min(3, stato[l]["ombra"]), false, "")
	await _controlla_rifugi()


func rinforzo(c: Dictionary) -> void:
	var l: String = c["rinforzo"]
	if stato[l]["liberata"] or e_rifugio(l):
		_log("RINFORZO a %s: il luogo è stato liberato, nessuna truppa." % Dati.nome(l))
	else:
		_log("RINFORZO: +1 truppa ombra a %s." % Dati.nome(l))
		await aggiungi_ombra(l, 1, true)
	if esito != "":
		return
	match c["ordine"]:
		"occhio":
			if occhio == regione_frodo():
				_log("Ordine: l'Occhio è già sulla regione di Frodo, si tira una ricerca.")
				await ricerca("l'Occhio di Sauron")
			else:
				sposta_occhio(regione_frodo(), "ordine dell'Ombra")
		"nazgul2":
			await nazgul_verso_frodo(2)
		"nazgul3":
			await schiera_nazgul(3)


## Sposta di una regione verso Frodo i n Nazgûl più vicini (fuori dalla sua regione), uno alla volta.
func nazgul_verso_frodo(n: int) -> void:
	var rf := regione_frodo()
	for k in n:
		var best := 99
		var cand: Array = []
		for r in nazgul:
			if r == rf or nazgul[r] <= 0:
				continue
			var dd := Dati.distanza_regioni(r, rf)
			if dd < best:
				best = dd
				cand = [r]
			elif dd == best:
				cand.append(r)
		if cand.is_empty():
			return
		var da: String = cand[0]
		if cand.size() > 1:
			var op: Array = []
			for r in cand:
				op.append({"testo": "Muovi un Nazgûl da %s" % Dati.nome_regione(r), "regione": r})
			da = op[await chiedi(turno_di, {"tipo": "nazgul", "titolo": "I Nazgûl si avvicinano", "testo": "Scegli da dove muove il Nazgûl (%d di %d)." % [k + 1, n], "opzioni": op})]["regione"]
		var verso: Array = []
		for r2 in Dati.regioni_vicine(da):
			if Dati.distanza_regioni(r2, rf) < best:
				verso.append(r2)
		var a: String = verso[0]
		if verso.size() > 1:
			var op2: Array = []
			for r2 in verso:
				op2.append({"testo": "Verso %s" % Dati.nome_regione(r2), "regione": r2})
			a = op2[await chiedi(turno_di, {"tipo": "nazgul", "titolo": "I Nazgûl si avvicinano", "testo": "Dove va il Nazgûl?", "opzioni": op2})]["regione"]
		nazgul[da] -= 1
		nazgul[a] += 1
		_log("Un Nazgûl si sposta da %s a %s." % [Dati.nome_regione(da), Dati.nome_regione(a)])
		evento.emit("nazgul", {"da": da, "a": a})


## Schiera n Nazgûl da Mordor all'Occhio (o li richiama se l'Occhio è su Mordor).
func schiera_nazgul(n: int) -> void:
	if occhio == "mordor":
		_log("Ordine: l'Occhio è su Mordor, %d Nazgûl vengono richiamati." % n)
		for k in n:
			var best := 0
			var cand: Array = []
			for r in nazgul:
				if r == "mordor":
					continue
				if nazgul[r] > best:
					best = nazgul[r]
					cand = [r]
				elif nazgul[r] == best and best > 0:
					cand.append(r)
			if cand.is_empty():
				return
			var da: String = await _scegli_regione(cand, "Da quale regione torna il Nazgûl?")
			nazgul[da] -= 1
			nazgul["mordor"] += 1
		return
	_log("Ordine: %d Nazgûl schierati su %s." % [n, Dati.nome_regione(occhio)])
	for k in n:
		var da := "mordor"
		if nazgul["mordor"] <= 0:
			var best := 0
			var cand: Array = []
			for r in nazgul:
				if r == occhio:
					continue
				if nazgul[r] > best:
					best = nazgul[r]
					cand = [r]
				elif nazgul[r] == best and best > 0:
					cand.append(r)
			if cand.is_empty():
				return
			da = await _scegli_regione(cand, "Da quale regione parte il Nazgûl?")
		nazgul[da] -= 1
		nazgul[occhio] += 1
		evento.emit("nazgul", {"da": da, "a": occhio})


func _scegli_regione(cand: Array, testo: String) -> String:
	if cand.size() == 1:
		return cand[0]
	var op: Array = []
	for r in cand:
		op.append({"testo": Dati.nome_regione(r), "regione": r})
	return op[await chiedi(turno_di, {"tipo": "nazgul", "titolo": "Nazgûl", "testo": testo, "opzioni": op})]["regione"]


func _ombra_speciale(c: Dictionary) -> void:
	_log("Carta speciale dell'Ombra: %s." % c["nome"])
	match c["speciale"]:
		"tamburi":
			for l in Dati.d()["regioni"]["mordor"]["luoghi"]:
				if e_fortezza(l):
					await aggiungi_ombra(l, 1, true)
		"saruman":
			var op: Array = []
			var tot := 0
			for l in stato:
				tot += amiche(l)
			if tot > 0:
				op.append({"testo": "Rompere il giuramento: togliete 2 truppe amiche", "chiave": "truppe"})
			for i in giocatori.size():
				var n: int = giocatori[i]["mano"].size()
				for s in Dati.SIMBOLI:
					n += giocatori[i]["gettoni"][s]
				if n >= 2:
					op.append({"testo": "Dubbio: %s scarta 2 carte o segnalini" % giocatori[i]["nome"], "chiave": "dubbio", "pos": i})
			op.append({"testo": "Disperazione: perdete 1 speranza", "chiave": "speranza"})
			var x: Dictionary = op[await chiedi(turno_di, {"tipo": "scelta", "titolo": c["nome"], "testo": c["testo"], "opzioni": op})]
			match x["chiave"]:
				"speranza":
					cambia_speranza(-1, "Disperazione")
				"truppe":
					for k in 2:
						var op2: Array = []
						for l in stato:
							for a in Dati.ARMATE:
								if stato[l]["truppe"][a] > 0:
									op2.append({"testo": "Togli 1 truppa %s a %s" % [Dati.NOMI_ARMATE[a], Dati.nome(l)], "luogo": l, "armata": a})
						if op2.is_empty():
							break
						var y: Dictionary = op2[await chiedi(turno_di, {"tipo": "scelta", "titolo": "Rompere il giuramento", "testo": "Quale truppa amica togliete?", "opzioni": op2})]
						togli_amica(y["luogo"], y["armata"])
					await _controlla_rifugi()
				"dubbio":
					var i: int = x["pos"]
					for k in 2:
						var op3: Array = []
						for s in Dati.SIMBOLI:
							if giocatori[i]["gettoni"][s] > 0:
								op3.append({"testo": "Segnalino %s" % Dati.NOMI_SIMBOLI[s], "simbolo": s})
						for id in giocatori[i]["mano"]:
							op3.append({"testo": _nome_carta(id), "carta": id})
						if op3.is_empty():
							break
						var y: Dictionary = op3[await chiedi(i, {"tipo": "scelta", "titolo": "Dubbio", "testo": "Che cosa scarti?", "opzioni": op3})]
						if y.has("simbolo"):
							giocatori[i]["gettoni"][y["simbolo"]] -= 1
							riserva_simboli[y["simbolo"]] += 1
						else:
							giocatori[i]["mano"].erase(int(y["carta"]))
							scarti.append(int(y["carta"]))


# =====================================================================================
# EVENTI
# =====================================================================================

func gioca_evento(pos: int, id: int) -> void:
	var c := Dati.carta(id)
	giocatori[pos]["mano"].erase(id)
	scarti.append(id)
	_log("%s gioca l'evento «%s»." % [giocatori[pos]["nome"], c["nome"]])
	evento.emit("evento_giocato", {"carta": id})
	match c["codice"]:
		"lotte_orchi":
			var op: Array = []
			for l in stato:
				if stato[l]["ombra"] > 0:
					op.append({"testo": "%s (%d truppe ombra)" % [Dati.nome(l), stato[l]["ombra"]], "luogo": l})
			if not op.is_empty():
				var l: String = op[await chiedi(turno_di, {"tipo": "luogo", "titolo": c["nome"], "testo": "Da dove togliete fino a 2 truppe ombra?", "opzioni": op})]["luogo"]
				togli_ombra(l, 2)
		"preveggenza_elrond":
			await _riordina_cima(turno_di, 4, true, c["nome"])
		"freccia_rossa":
			var op: Array = []
			for l in stato:
				if e_rifugio(l) and amiche(l) > 0:
					for l2 in stato:
						if l2 != l and e_rifugio(l2):
							op.append({"testo": "Da %s a %s" % [Dati.nome(l), Dati.nome(l2)], "da": l, "luogo": l2})
			if not op.is_empty():
				var x: Dictionary = op[await chiedi(turno_di, {"tipo": "luogo", "titolo": c["nome"], "testo": "Fino a 3 truppe amiche da un rifugio a un altro.", "opzioni": op})]
				var mosse := 0
				for k in 3:
					var tipi: Array = []
					for a in Dati.ARMATE:
						if stato[x["da"]]["truppe"][a] > 0:
							tipi.append(a)
					if tipi.is_empty():
						break
					var op2: Array = [{"testo": "Basta così"}]
					for a in tipi:
						op2.append({"testo": "Sposta 1 truppa %s" % Dati.NOMI_ARMATE[a], "armata": a})
					var r := await chiedi(turno_di, {"tipo": "scelta", "titolo": c["nome"], "testo": "Truppe spostate: %d/3" % mosse, "opzioni": op2, "conferma": true})
					if r == 0:
						break
					stato[x["da"]]["truppe"][op2[r]["armata"]] -= 1
					stato[x["luogo"]]["truppe"][op2[r]["armata"]] += 1
					mosse += 1
				await _battaglia_facoltativa(x["luogo"])
		"lembas":
			azioni_rimaste += 2
		"mantelli_elfici":
			var p := await _scegli_personaggio(c["nome"], "Chi viaggia da solo fino a 2 volte?")
			for k in 2:
				var dd := _destinazioni(p)
				var op: Array = [{"testo": "Fermati"}]
				for x in dd:
					if x.get("passi", 1) == 1:
						op.append({"testo": "Vai a %s%s" % [Dati.nome(x["luogo"]), "" if x["costo"].is_empty() else " (%s)" % _testo_costo(x["costo"])], "luogo": x["luogo"], "costo": x["costo"]})
				var r := await chiedi(turno_di, {"tipo": "viaggio_evento", "titolo": c["nome"], "testo": "%s: viaggio %d di 2" % [nome_pg(p), k + 1], "opzioni": op, "conferma": true, "pg": p})
				if r == 0:
					break
				if not op[r]["costo"].is_empty():
					await paga(posto_di(p), op[r]["costo"], "Sentiero speciale")
				var da: String = pg[p]["luogo"]
				pg[p]["luogo"] = op[r]["luogo"]
				_log("%s viaggia a %s." % [nome_pg(p), Dati.nome(op[r]["luogo"])])
				evento.emit("viaggio", {"pg": [p], "da": da, "a": op[r]["luogo"]})
				_controlla_gollum(op[r]["luogo"])
		"cavalli_rohan":
			var op: Array = []
			var visti := {}
			for p in pg:
				if in_gioco(p) and not visti.has(pg[p]["luogo"]):
					visti[pg[p]["luogo"]] = true
					op.append({"testo": Dati.nome(pg[p]["luogo"]), "luogo": pg[p]["luogo"]})
			var l: String = op[await chiedi(turno_di, {"tipo": "luogo", "titolo": c["nome"], "testo": "Da quale luogo partono i cavalieri?", "opzioni": op})]["luogo"]
			var gruppo := personaggi_in(l)
			for k in 3:
				var op2: Array = [{"testo": "Fermatevi"}]
				for v in Dati.vicini(l):
					if Dati.collegamento(l, v)["costo"].is_empty():
						op2.append({"testo": "Andate a %s" % Dati.nome(v), "luogo": v})
				var r := await chiedi(turno_di, {"tipo": "viaggio_evento", "titolo": c["nome"], "testo": "Viaggio %d di 3" % [k + 1], "opzioni": op2, "conferma": true})
				if r == 0:
					break
				var da := l
				l = op2[r]["luogo"]
				for p in gruppo:
					pg[p]["luogo"] = l
				evento.emit("viaggio", {"pg": gruppo, "da": da, "a": l})
				_log("I cavalieri raggiungono %s." % Dati.nome(l))
				if gruppo.has("frodo"):
					await ricerca("Rohan presta i cavalli")
					if esito != "":
						return
		"aquile":
			var p := await _scegli_personaggio(c["nome"], "Chi portano le Aquile?")
			var op: Array = []
			for l in stato:
				if l != pg[p]["luogo"]:
					op.append({"testo": Dati.nome(l), "luogo": l})
			var l: String = op[await chiedi(turno_di, {"tipo": "luogo", "titolo": c["nome"], "testo": "Dove portano %s?" % nome_pg(p), "opzioni": op, "pg": p})]["luogo"]
			var da: String = pg[p]["luogo"]
			pg[p]["luogo"] = l
			evento.emit("viaggio", {"pg": [p], "da": da, "a": l})
			_log("Le Aquile portano %s a %s." % [nome_pg(p), Dati.nome(l)])
			if p == "frodo":
				var rf := Dati.regione(l)
				for k in 7:
					var best := 99
					var da_r := ""
					for r in nazgul:
						if r != rf and nazgul[r] > 0 and Dati.distanza_regioni(r, rf) < best:
							best = Dati.distanza_regioni(r, rf)
							da_r = r
					if da_r == "":
						break
					nazgul[da_r] -= 1
					nazgul[rf] += 1
				sposta_occhio(rf, "le Aquile")
				await ricerca("le Aquile")
		"tom_bombadil":
			cambia_speranza(1, "Tom Bombadil")
		"gwaihir":
			var op: Array = []
			for l in stato:
				if amiche(l) > 0:
					for v in Dati.vicini(l):
						if Dati.collegamento(l, v)["costo"].is_empty():
							op.append({"testo": "Da %s a %s" % [Dati.nome(l), Dati.nome(v)], "da": l, "luogo": v})
			if not op.is_empty():
				var x: Dictionary = op[await chiedi(turno_di, {"tipo": "luogo", "titolo": c["nome"], "testo": "Quali truppe si spostano, e dove?", "opzioni": op})]
				var mosse := 0
				while true:
					var op2: Array = [{"testo": "Basta così"}]
					for a in Dati.ARMATE:
						if stato[x["da"]]["truppe"][a] > 0:
							op2.append({"testo": "Sposta 1 truppa %s" % Dati.NOMI_ARMATE[a], "armata": a})
					if op2.size() == 1:
						break
					var r := await chiedi(turno_di, {"tipo": "scelta", "titolo": c["nome"], "testo": "Truppe spostate: %d" % mosse, "opzioni": op2, "conferma": mosse > 0})
					if r == 0 and mosse > 0:
						break
					if r == 0:
						r = 1
					stato[x["da"]]["truppe"][op2[r]["armata"]] -= 1
					stato[x["luogo"]]["truppe"][op2[r]["armata"]] += 1
					mosse += 1
				await _controlla_rifugi()
				await _battaglia_facoltativa(x["luogo"])
		"entmoot":
			var n: int = min(3, riserva_truppe["elfi"])
			aggiungi_truppe("fangorn", "elfi", n)
			_log("Gli Ent si radunano a Fangorn (%d truppe)." % n)
			var op: Array = [{"testo": "Restano a Fangorn"}]
			for v in Dati.vicini("fangorn"):
				op.append({"testo": "Marciano su %s" % Dati.nome(v), "luogo": v})
			var r := await chiedi(turno_di, {"tipo": "luogo", "titolo": c["nome"], "testo": "Gli Ent (e i personaggi a Fangorn) si spostano?", "opzioni": op, "conferma": true})
			if r > 0:
				var v: String = op[r]["luogo"]
				stato["fangorn"]["truppe"]["elfi"] -= n
				stato[v]["truppe"]["elfi"] += n
				for p in personaggi_in("fangorn"):
					pg[p]["luogo"] = v
				_log("Gli Ent marciano su %s." % Dati.nome(v))
		"consiglio_elrond":
			for p in pg:
				if in_gioco(p) and pg[p]["luogo"] != "rivendell":
					if await _si_no(turno_di, c["nome"], "%s va a Gran Burrone?" % nome_pg(p), "Sì", "No", "consiglio", {"pg": p}):
						var da: String = pg[p]["luogo"]
						pg[p]["luogo"] = "rivendell"
						evento.emit("viaggio", {"pg": [p], "da": da, "a": "rivendell"})
			if solo:
				var op: Array = [{"testo": "Nessuna"}]
				for cid in giocatori[0]["mano"]:
					var cc := Dati.carta(cid)
					if cc["tipo"] == "regione" and riserva_simboli[cc["simbolo"]] > 0:
						op.append({"testo": "Prepara %s" % _nome_carta(cid), "carta": cid})
				var r := await chiedi(0, {"tipo": "scelta", "titolo": c["nome"], "testo": "Prepara gratis una carta.", "opzioni": op, "conferma": true})
				if r > 0:
					var scelta: int = op[r]["carta"]
					giocatori[0]["mano"].erase(scelta)
					scarti.append(scelta)
					prendi_simbolo(0, Dati.carta(scelta)["simbolo"])
		"palantir":
			var p := await _scegli_personaggio(c["nome"], "Su chi si volge l'Occhio?")
			var rr := Dati.regione(pg[p]["luogo"])
			sposta_occhio(rr, "il Palantír")
			for k in 3:
				var cand: Array = []
				for r in nazgul:
					if r != rr and nazgul[r] > 0:
						cand.append(r)
				if cand.is_empty():
					break
				var da: String = await _scegli_regione(cand, "Da dove arriva il Nazgûl (%d di 3)?" % [k + 1])
				nazgul[da] -= 1
				nazgul[rr] += 1
		"doni_elfi":
			var op: Array = []
			for i in giocatori.size():
				for s in Dati.SIMBOLI:
					if riserva_simboli[s] > 0:
						op.append({"testo": "%s a %s" % [Dati.NOMI_SIMBOLI[s], giocatori[i]["nome"]], "pos": i, "simbolo": s})
			if not op.is_empty():
				var x: Dictionary = op[await chiedi(turno_di, {"tipo": "scelta", "titolo": c["nome"], "testo": "Quale segnalino, e a chi?", "opzioni": op})]
				prendi_simbolo(x["pos"], x["simbolo"])
		"ordini_contrastanti":
			var op: Array = []
			for l in stato:
				if stato[l]["ombra"] > 0:
					op.append({"testo": "%s (%d)" % [Dati.nome(l), stato[l]["ombra"]], "luogo": l})
			if not op.is_empty():
				var l: String = op[await chiedi(turno_di, {"tipo": "luogo", "titolo": c["nome"], "testo": "Da quale luogo se ne vanno le truppe ombra?", "opzioni": op})]["luogo"]
				while stato[l]["ombra"] > 0:
					var op2: Array = []
					for v in Dati.vicini(l):
						op2.append({"testo": "1 truppa a %s" % Dati.nome(v), "luogo": v})
					var v: String = op2[await chiedi(turno_di, {"tipo": "luogo", "titolo": c["nome"], "testo": "Dove va la truppa? (ne restano %d)" % stato[l]["ombra"], "opzioni": op2})]["luogo"]
					stato[l]["ombra"] -= 1
					stato[v]["ombra"] += 1
				await _controlla_rifugi()
	_controlla_obiettivi()
	cambiato.emit()


func _battaglia_facoltativa(l: String) -> void:
	if stato[l]["ombra"] > 0 and amiche(l) > 0:
		if await _si_no(turno_di, "Combattimento", "Effettuate un tiro di combattimento a %s? (l'Occhio si volge su %s)" % [Dati.nome(l), Dati.nome_regione(Dati.regione(l))], "Tira", "No", "battaglia_facoltativa", {"luogo": l}):
			sposta_occhio(Dati.regione(l), "battaglia")
			await battaglia(l, min(3, amiche(l)), true, "")


func _scegli_personaggio(titolo: String, testo: String) -> String:
	var op: Array = []
	for p in pg:
		if in_gioco(p):
			op.append({"testo": "%s (%s)" % [nome_pg(p), Dati.nome(pg[p]["luogo"])], "pg": p, "luogo": pg[p]["luogo"]})
	return op[await chiedi(turno_di, {"tipo": "personaggio", "titolo": titolo, "testo": testo, "opzioni": op})]["pg"]


# =====================================================================================
# OBIETTIVI
# =====================================================================================

## Obiettivi che si completano da soli quando le condizioni sono vere.
func _controlla_obiettivi() -> void:
	if esito != "":
		return
	for o in obiettivi:
		if o["fatto"]:
			continue
		var ok := false
		match o["codice"]:
			"saruman":
				ok = e_rifugio("isengard") and regione_libera("rohan")
			"pozzi":
				ok = e_rifugio("dol_guldur") and stato["dol_guldur"]["truppe"]["elfi"] >= 3
			"balin":
				ok = e_rifugio("moria") and stato["moria"]["truppe"]["nani"] >= 2
			"raminghi":
				ok = regione_libera("eriador")
				if ok:
					for l in Dati.d()["regioni"]["eriador"]["luoghi"]:
						if amiche(l) == 0:
							ok = false
			"freca":
				ok = e_rifugio("dunland") and stato["dunland"]["truppe"]["rohirrim"] >= 2
			"umbar":
				ok = e_rifugio("umbar")
				if not ok:
					ok = true
					for l in Dati.d()["regioni"]["haradwaith"]["luoghi"]:
						if amiche(l) == 0 or stato[l]["ombra"] > 0:
							ok = false
			"nani":
				ok = stato["ered_luin"]["ombra"] == 0 and stato["ered_luin"]["truppe"]["nani"] >= 4 and regione_libera("dale")
			"eored":
				ok = eored.size() >= 4
			"bosco_atro":
				ok = true
				for l in Dati.d()["regioni"]["mirkwood"]["luoghi"]:
					if stato[l]["ombra"] > 0 or stato[l]["truppe"]["elfi"] == 0:
						ok = false
			"morgul":
				ok = e_rifugio("minas_morgul")
			"eowyn":
				ok = nazgul_eowyn >= 2 and regione_libera("rohan")
			"hobbit":
				ok = hobbit.size() >= 2
			"anduin":
				ok = e_rifugio("osgiliath")
			"sei":
				ok = int(su_carta.get("sei", 0)) >= 6
			"spergiuri":
				ok = aragorn_erech and regione_libera("gondor")
		if ok:
			completa(o["codice"])


func completa(cod: String) -> void:
	var o := {}
	for x in obiettivi:
		if x["codice"] == cod:
			o = x
	if o.is_empty() or o["fatto"]:
		return
	o["fatto"] = true
	var ob := Dati.obiettivo(cod)
	_log("OBIETTIVO COMPLETATO: %s!" % ob["nome"])
	evento.emit("obiettivo", {"codice": cod})
	match cod:
		"benedizione":
			riserva_truppe["elfi"] += int(su_carta.get("benedizione", 0))
			su_carta.erase("benedizione")
			for i in giocatori.size():
				for p in giocatori[i]["pg"]:
					if presente(p, "rivendell"):
						prendi_simbolo(i, "amicizia")
						break
			cambia_speranza(1, ob["nome"])
		"saruman":
			prendi_simbolo(turno_di, "resistenza")
		"sauron":
			sposta_occhio("ithilien", ob["nome"])
			var tot := 0
			for l in Dati.d()["regioni"]["mordor"]["luoghi"]:
				tot += stato[l]["ombra"]
				stato[l]["ombra"] = 0
			stato["udun"]["ombra"] = tot
		"boromir":
			togli_ombra(pg["boromir"]["luogo"], 2)
			pg["boromir"]["fuori"] = true
			boromir_sostituire = true
			_log("Boromir cade da eroe.")
		"pozzi":
			if presente("galadriel", "dol_guldur"):
				cambia_speranza(1, ob["nome"])
		"balin":
			for l in stato:
				if l != "moria":
					var n: int = stato[l]["truppe"]["nani"]
					stato[l]["truppe"]["nani"] = 0
					stato["moria"]["truppe"]["nani"] += n
			if stato["moria"]["truppe"]["nani"] >= 4:
				prendi_simbolo(turno_di, "valore")
				prendi_simbolo(turno_di, "valore")
		"raminghi":
			cambia_speranza(1, ob["nome"])
		"freca":
			aggiungi_truppe("dunland", "rohirrim", 1)
		"umbar":
			for l in Dati.d()["regioni"]["haradwaith"]["luoghi"]:
				for a in Dati.ARMATE:
					var n: int = stato[l]["truppe"][a]
					stato[l]["truppe"][a] = 0
					stato["pelargir"]["truppe"][a] += n
		"nani":
			prendi_simbolo(turno_di, "valore")
			prendi_simbolo(turno_di, "valore")
			cambia_speranza(1, ob["nome"])
		"eored":
			riserva_ombra += eored.size()
			cambia_speranza(1, ob["nome"])
		"balrog":
			pass
		"bosco_atro":
			cambia_speranza(1, ob["nome"])
		"theoden":
			riserva_truppe["rohirrim"] += int(su_carta.get("theoden", 0))
			su_carta.erase("theoden")
			aggiungi_truppe("edoras", "rohirrim", 2)
			cambia_speranza(1, ob["nome"])
		"morgul":
			prendi_simbolo(turno_di, "furtivita")
			prendi_simbolo(turno_di, "furtivita")
		"eowyn":
			cambia_speranza(1, ob["nome"])
		"hobbit":
			if in_gioco("pipino"):
				giocatori[posto_di("pipino")]["gettoni"]["amicizia"] += 2
			else:
				riserva_simboli["amicizia"] += 2
			cambia_speranza(1, ob["nome"])
		"anduin":
			aggiungi_truppe("osgiliath", "gondor", 1)
		"denethor":
			riserva_truppe["gondor"] += int(su_carta.get("denethor", 0))
			su_carta.erase("denethor")
			aggiungi_truppe("minas_tirith", "gondor", 3)
			cambia_speranza(1, ob["nome"])
		"sei":
			riserva_ombra += int(su_carta.get("sei", 0))
			su_carta["sei"] = 0
			cambia_speranza(1, ob["nome"])
		"stendardo":
			cambia_speranza(1, ob["nome"])
		"spergiuri":
			cambia_speranza(1, ob["nome"])
		"anello":
			esito = "vittoria"
			_log("L'Unico Anello è distrutto! Sauron è sconfitto e la Terra di Mezzo è salva.")
	# Boromir viene sostituito al prossimo obiettivo completato
	if boromir_sostituire and cod != "boromir":
		boromir_sostituire = false
		var liberi: Array = []
		for p in Dati.d()["personaggi"]:
			if not pg.has(p):
				liberi.append(p)
		if not liberi.is_empty():
			var nuovo: String = liberi[rng.randi_range(0, liberi.size() - 1)]
			var pos := posto_di("boromir")
			giocatori[pos]["pg"][giocatori[pos]["pg"].find("boromir")] = nuovo
			pg[nuovo] = {"luogo": Dati.personaggio(nuovo)["partenza"], "posto": pos, "fuori": false, "bianco": false}
			_log("%s prende il posto di Boromir." % nome_pg(nuovo))
	cambiato.emit()


func _balrog() -> void:
	var pos := posto_di("gandalf")
	var esiti := tira(3, Dati.FACCE_BATTAGLIA)
	evento.emit("dadi", {"tipo": "battaglia", "facce": esiti.duplicate(), "luogo": "moria"})
	_log("Gandalf affronta il Balrog: %s." % _testo_facce(esiti))
	var perdita := {"travolti": 1, "scambio": 2, "nazgul": 3, "rotta": 0}
	var tot := 0
	for f in esiti:
		tot += perdita[f]
	# Resistenza: ignora un dado; Valore: evita 1 speranza
	while tot > 0:
		var op: Array = [{"testo": "Accetta: -%d speranza" % tot}]
		if disponibili(pos, "resistenza") > 0:
			for k in esiti.size():
				if perdita[esiti[k]] > 0:
					op.append({"testo": "Ignora il dado %d (%s) con 1 Resistenza" % [k + 1, Dati.NOMI_FACCE[esiti[k]]], "dado": k, "s": "resistenza"})
		if disponibili(pos, "valore") > 0:
			op.append({"testo": "Evita 1 speranza persa con 1 Valore", "s": "valore"})
		var r := await chiedi(pos, {"tipo": "scelta", "titolo": "Affrontare il Balrog", "testo": _testo_facce(esiti), "opzioni": op, "facce": esiti})
		if r == 0:
			break
		await paga(pos, {op[r]["s"]: 1}, "Il Balrog")
		if op[r]["s"] == "resistenza":
			tot -= perdita[esiti[op[r]["dado"]]]
			esiti[op[r]["dado"]] = "rotta"
		else:
			tot -= 1
	cambia_speranza(-tot, "il Balrog")
	if esito == "":
		pg["gandalf"]["fuori"] = true
		gandalf_attesa = true
		await completa("balrog")


func _shelob() -> void:
	var pos := posto_di("frodo")
	var esiti := tira(3, Dati.FACCE_BATTAGLIA)
	evento.emit("dadi", {"tipo": "battaglia", "facce": esiti.duplicate(), "luogo": "minas_morgul"})
	_log("Sam affronta Shelob: %s." % _testo_facce(esiti))
	var perdita := {"travolti": 1, "scambio": 2, "nazgul": 3, "rotta": 0}
	var tot := 0
	for f in esiti:
		tot += perdita[f]
	var pg_pos := posto_di("gollum")
	if solo:
		for id in giocatori[0]["mano"]:
			var c := Dati.carta(id)
			if c.get("tipo", "") == "regione" and c["simbolo"] == "resistenza":
				tot += 1
	else:
		tot += disponibili(pg_pos, "resistenza")
	while tot > 0:
		var op: Array = [{"testo": "Accetta: -%d speranza" % tot}]
		if disponibili(pos, "resistenza") > 0:
			for k in esiti.size():
				if perdita[esiti[k]] > 0:
					op.append({"testo": "Ignora il dado %d (%s) con 1 Resistenza" % [k + 1, Dati.NOMI_FACCE[esiti[k]]], "dado": k, "s": "resistenza"})
		if disponibili(pos, "valore") > 0:
			op.append({"testo": "Evita 1 speranza persa con 1 Valore", "s": "valore"})
		var r := await chiedi(pos, {"tipo": "scelta", "titolo": "La tana di Shelob", "testo": _testo_facce(esiti), "opzioni": op, "facce": esiti})
		if r == 0:
			break
		await paga(pos, {op[r]["s"]: 1}, "Shelob")
		if op[r]["s"] == "resistenza":
			tot -= perdita[esiti[op[r]["dado"]]]
			esiti[op[r]["dado"]] = "rotta"
		else:
			tot -= 1
	var senza := tot <= 0
	cambia_speranza(-tot, "la tana di Shelob")
	if esito == "":
		await completa("shelob")
		if senza:
			azione_extra += 1
			_log("Frodo non ha perso speranza: un'azione in più.")


func _distruggi_anello() -> void:
	var pf := posto_di("frodo")
	await paga(pf, {"resistenza": 5}, "Distruggere l'Anello")
	_log("Frodo è sull'orlo del Monte Fato...")
	var mancanti := Dati.SPERANZA_MAX - speranza
	evento.emit("finale", {})
	var ok := await ricerca("ricerca finale al Monte Fato", true, mancanti)
	if ok and speranza > 0 and esito == "":
		await completa("anello")


# =====================================================================================
# COPIA (per lo sguardo avanti dell'IA)
# =====================================================================================

const _COPIA := ["solo", "difficolta", "giocatori", "pg", "stato", "nazgul", "occhio", "speranza", "minaccia",
	"riserva_truppe", "riserva_ombra", "riserva_simboli", "mazzo", "scarti", "eventi_inutilizzati", "mazzo_ombra",
	"scarti_ombra", "risolte", "obiettivi", "su_carta", "eored", "hobbit", "nazgul_eowyn", "aragorn_erech",
	"gandalf_attesa", "boromir_sostituire", "turno_di", "turno", "solo_indice", "esito", "fase", "attivo",
	"azioni_rimaste", "usi", "lembas", "azione_extra", "ultima_ombra"]


## Una copia indipendente dello stato, con un generatore casuale diverso (le carte coperte restano coperte
## solo per convenzione: l'IA non le guarda, perché le simulazioni non pescano carte).
func copia(seme_copia: int) -> Motore:
	var c := Motore.new()
	for k in _COPIA:
		var v = get(k)
		c.set(k, v.duplicate(true) if (v is Dictionary or v is Array) else v)
	c.rng.seed = seme_copia
	return c


# =====================================================================================
# SALVATAGGIO
# =====================================================================================

func istantanea() -> Dictionary:
	return {"seme": seme, "storia": storia.duplicate()}
