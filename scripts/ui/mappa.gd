extends Control
## Mappa 2D: il tabellone con truppe, personaggi, Nazgûl, Occhio, rifugi e fortezze.
## Si ingrandisce con la rotellina (o con due dita), si sposta trascinando. I luoghi si possono cliccare:
## se la scelta in corso riguarda un luogo, il clic la fa.

signal luogo_cliccato(id: String)

const W := 3259.0
const H := 2796.0

## Spazi stampati sul tabellone (pixel dell'immagine).
const MINACCIA_X0 := 440.0
const MINACCIA_DX := 105.0
const MINACCIA_Y := 140.0
const SPERANZA_X := 205.0
const SPERANZA_Y8 := 1120.0
const SPERANZA_DY := 103.8
const RISERVE := {"gondor": Vector2(140, 295), "rohirrim": Vector2(140, 432), "elfi": Vector2(140, 570), "nani": Vector2(140, 706)}
## Mazzo dell'Ombra (in basso a sinistra) e mazzo dei giocatori (in basso a destra): centro e altezza della carta.
const OMBRA_PESCA := Vector2(300, 2450)
const OMBRA_RISOLVI := Vector2(690, 2450)
const OMBRA_SCARTI := Vector2(1110, 2450)
const H_OMBRA := 430.0
const GIOC_PESCA := Vector2(2700, 2545)
const GIOC_SCARTI := Vector2(3020, 2545)
const H_GIOC := 300.0


static func pos_minaccia(k: int) -> Vector2:
	return Vector2(MINACCIA_X0 + MINACCIA_DX * k, MINACCIA_Y)


static func pos_speranza(v: int) -> Vector2:
	return Vector2(SPERANZA_X, SPERANZA_Y8 + (8 - v) * SPERANZA_DY)

var motore: Motore
var vista
var zoom := 1.0
var offset := Vector2.ZERO
var _trascina := false
var _mosso := false
var _press := Vector2.ZERO
var tabellone: Texture2D
var evidenziati: Dictionary = {}     # luogo -> colore
var linea_evidenziata := ""
var sotto_mouse := ""
var _anim: Dictionary = {}           # chiave -> {da, a: Vector2, t, dur, arco}: pezzi che scorrono
var _voli: Array = []                # pezzi "fantasma" che volano tra due luoghi (truppe, Nazgûl)
var _foto: Dictionary = {}           # stato dei pezzi all'ultimo aggiornamento
var _carte_volo: Array = []          # carte che si girano e volano verso la loro casella
var ritmo := 1.0                     # durata delle animazioni (1 = normale, di più = più lente)
var _lampi: Array = []               # {pos, t, col}
var _carte_mappa: Array = []         # [{rect (pixel tabellone), id}] per l'ingrandimento
var _carta_sotto := -1


func _ready() -> void:
	mouse_exited.connect(func():
		_carta_sotto = -1
		sotto_mouse = ""
		if vista != null:
			vista._nascondi_zoom()
		queue_redraw())
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	tabellone = UI.tex("res://assets/ui/tabellone.webp")
	resized.connect(_adatta)
	_adatta.call_deferred()


func _adatta() -> void:
	if size.x <= 0 or size.y <= 0:
		return
	zoom = min(size.x / W, size.y / H)
	offset = (size - Vector2(W, H) * zoom) / 2.0
	queue_redraw()


func _limita() -> void:
	var minz: float = min(size.x / W, size.y / H) * 0.9
	zoom = clampf(zoom, minz, 1.6)
	var dim := Vector2(W, H) * zoom
	for k in 2:
		if dim[k] <= size[k]:
			offset[k] = (size[k] - dim[k]) / 2.0
		else:
			offset[k] = clampf(offset[k], size[k] - dim[k] - 60.0, 60.0)


func a_schermo(p: Vector2) -> Vector2:
	return offset + p * zoom


func da_schermo(p: Vector2) -> Vector2:
	return (p - offset) / zoom


func pos_luogo(l: String) -> Vector2:
	var d: Dictionary = Dati.luogo(l)
	return Vector2(d["x"], d["y"])


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP or ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if ev.pressed:
				var f := 1.12 if ev.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12
				var prima := da_schermo(ev.position)
				zoom *= f
				_limita()
				offset = ev.position - prima * zoom
				_limita()
				queue_redraw()
			accept_event()
		elif ev.button_index == MOUSE_BUTTON_LEFT or ev.button_index == MOUSE_BUTTON_RIGHT:
			if ev.pressed:
				_trascina = true
				_mosso = false
				_press = ev.position
			else:
				_trascina = false
				if not _mosso and ev.button_index == MOUSE_BUTTON_LEFT:
					var l := _luogo_a(ev.position)
					if l != "":
						luogo_cliccato.emit(l)
	elif ev is InputEventMouseMotion:
		if _trascina:
			if ev.position.distance_to(_press) > 6:
				_mosso = true
			if _mosso:
				offset += ev.relative
				_limita()
				queue_redraw()
		var cid := _carta_a(ev.position)
		if cid != _carta_sotto:
			_carta_sotto = cid
			if vista != null:
				if cid >= 0:
					vista._mostra_zoom_a(cid, get_global_rect().position + ev.position)
				else:
					vista._nascondi_zoom()
		var l := _luogo_a(ev.position) if cid < 0 else ""
		if l != sotto_mouse:
			sotto_mouse = l
			tooltip_text = _descrivi(l) if l != "" else ""
			queue_redraw()
	elif ev is InputEventMagnifyGesture:
		var prima := da_schermo(ev.position)
		zoom *= ev.factor
		_limita()
		offset = ev.position - prima * zoom
		_limita()
		queue_redraw()
	elif ev is InputEventPanGesture:
		offset -= ev.delta * 12.0
		_limita()
		queue_redraw()


func _carta_a(p: Vector2) -> int:
	var q := da_schermo(p)
	for x in _carte_mappa:
		if x["rect"].has_point(q):
			return int(x["id"])
	return -1


func _luogo_a(p: Vector2) -> String:
	var q := da_schermo(p)
	var best := ""
	var bd := 70.0
	for l in Dati.luoghi():
		var d := pos_luogo(l).distance_to(q)
		if d < bd:
			bd = d
			best = l
	return best


func _descrivi(l: String) -> String:
	if motore == null:
		return Dati.nome(l)
	var s: Dictionary = motore.stato[l]
	var t := "%s — %s" % [Dati.nome(l), Dati.nome_regione(Dati.regione(l))]
	match s["tipo"]:
		"rifugio":
			t += "\nRifugio"
		"fortezza":
			t += "\nRoccaforte ombra"
		"ombra":
			t += "\nLuogo dell'Ombra"
	var col: String = Dati.luogo(l)["arruolo"]
	if col != "":
		t += "\nSi radunano truppe %s" % Dati.NOMI_ARMATE[col]
	var tr: Array = []
	for a in Dati.ARMATE:
		if s["truppe"][a] > 0:
			tr.append("%d %s" % [s["truppe"][a], Dati.NOMI_ARMATE[a]])
	if not tr.is_empty():
		t += "\nTruppe amiche: " + ", ".join(tr)
	if s["ombra"] > 0:
		t += "\nTruppe ombra: %d" % s["ombra"]
	var pp := motore.personaggi_in(l)
	if not pp.is_empty():
		var nn: Array = []
		for p in pp:
			nn.append(motore.nome_pg(p))
		t += "\n" + ", ".join(nn)
	var reg := Dati.regione(l)
	if motore.nazgul[reg] > 0:
		t += "\nNazgûl nella regione: %d" % motore.nazgul[reg]
	var vic: Array = []
	for v in Dati.vicini(l):
		var e: Dictionary = Dati.collegamento(l, v)
		var c := ""
		for s2 in e["costo"]:
			c = " (%d %s)" % [e["costo"][s2], Dati.NOMI_SIMBOLI[s2]]
		vic.append(Dati.nome(v) + c)
	t += "\nCollegato a: " + ", ".join(vic)
	return t


func evidenzia(luoghi: Dictionary, linea := "") -> void:
	evidenziati = luoghi
	linea_evidenziata = linea
	queue_redraw()


## Il viaggio dei personaggi ora si anima da solo confrontando gli stati (vedi registra()).
func anima_viaggio(_pgs: Array, _da: String) -> void:
	pass


## Posizioni dei personaggi sul tabellone (in gruppo se sono nello stesso luogo).
func _pos_pg() -> Dictionary:
	var per_luogo := {}
	for p in motore.pg:
		if motore.pg[p]["fuori"]:
			continue
		var l: String = motore.pg[p]["luogo"]
		if not per_luogo.has(l):
			per_luogo[l] = []
		per_luogo[l].append(p)
	var r := {}
	for l in per_luogo:
		var lista: Array = per_luogo[l]
		for k in lista.size():
			r[lista[k]] = pos_luogo(l) + Vector2((k - (lista.size() - 1) / 2.0) * 58.0, -70)
	return r


func _istantanea() -> Dictionary:
	var f := {"pos": {}, "conti": {}}
	var pp := _pos_pg()
	for p in pp:
		f["pos"]["pg_" + p] = pp[p]
	f["pos"]["minaccia"] = pos_minaccia(motore.minaccia)
	f["pos"]["speranza"] = pos_speranza(motore.speranza)
	for a in Dati.ARMATE:
		var c := {"riserva": int(motore.riserva_truppe[a])}
		for l in motore.stato:
			if motore.stato[l]["truppe"][a] > 0:
				c[l] = int(motore.stato[l]["truppe"][a])
		f["conti"]["truppa_" + a] = c
	var co := {}
	for l in motore.stato:
		if motore.stato[l]["ombra"] > 0:
			co[l] = int(motore.stato[l]["ombra"])
	f["conti"]["truppa_ombra"] = co
	var cn := {}
	for r in motore.nazgul:
		if motore.nazgul[r] > 0:
			cn[r] = int(motore.nazgul[r])
	f["conti"]["nazgul"] = cn
	f["carte"] = {"risolte": motore.risolte.duplicate(), "so_n": motore.scarti_ombra.size(),
		"so_top": motore.scarti_ombra.back() if not motore.scarti_ombra.is_empty() else -1,
		"sg_n": motore.scarti.size(), "sg_top": motore.scarti.back() if not motore.scarti.is_empty() else -1,
		"mazzo_n": motore.mazzo.size()}
	return f


func _slot_risolta(k: int) -> Vector2:
	return OMBRA_RISOLVI + Vector2(k * 14, k * 22)


func _vola_carta(fronte: Texture2D, retro: Texture2D, da: Vector2, a: Vector2, h: float, dur: float, nascondi := "", ritardo := 0.0) -> void:
	_carte_volo.append({"fronte": fronte, "retro": retro, "da": da, "a": a, "h": h, "t": -ritardo / dur, "dur": dur, "nascondi": nascondi})


## Carte: quelle dell'Ombra si girano uscendo dal mazzo, gli scarti scivolano nella loro casella.
func _anima_carte(prima: Dictionary, dopo: Dictionary) -> void:
	var r0: Array = prima["risolte"]
	var r1: Array = dopo["risolte"]
	var rit := 0.0
	for k in r1.size():
		if k < r0.size() and r0[k] == r1[k]:
			continue
		var id: int = r1[k]
		var retro := UI.tex("res://assets/carte/dorso_%s.webp" % Dati.carta(id).get("retro", "bandiera"))
		_vola_carta(UI.carta_tex(id), retro, OMBRA_PESCA, _slot_risolta(k), H_OMBRA, 1.0 * ritmo, "risolte:%d" % k, rit)
		rit += 0.35 * ritmo
	if dopo["so_n"] > prima["so_n"] and dopo["so_top"] >= 0:
		# le risolte vanno negli scarti: scivolano una dopo l'altra
		var n_nuove: int = mini(dopo["so_n"] - prima["so_n"], 4)
		var j := 0
		for k in range(r0.size() - n_nuove, r0.size()):
			if k < 0:
				continue
			_vola_carta(UI.carta_tex(r0[k]), null, _slot_risolta(k), OMBRA_SCARTI, H_OMBRA, 0.7 * ritmo, "scarti_ombra" if k == r0.size() - 1 else "", j * 0.15 * ritmo)
			j += 1
		if j == 0:
			_vola_carta(UI.carta_tex(dopo["so_top"]), null, OMBRA_RISOLVI, OMBRA_SCARTI, H_OMBRA, 0.7 * ritmo, "scarti_ombra")
	if dopo["sg_n"] > prima["sg_n"] and dopo["sg_top"] >= 0 and dopo["sg_top"] != prima["sg_top"]:
		_vola_carta(UI.carta_tex(dopo["sg_top"]), null, Vector2(W + 250, H * 0.55), GIOC_SCARTI, H_GIOC, 0.8 * ritmo, "scarti")
	if dopo["mazzo_n"] < prima["mazzo_n"]:
		var dg := UI.tex("res://assets/carte/dorso_giocatori.webp")
		for k in mini(prima["mazzo_n"] - dopo["mazzo_n"], 2):
			_vola_carta(dg, null, GIOC_PESCA, Vector2(W + 300, H * 0.45), H_GIOC, 0.8 * ritmo, "", k * 0.25 * ritmo)


func _nascosta(chiave: String) -> bool:
	for c in _carte_volo:
		if c["nascondi"] == chiave:
			return true
	return false


func _disegna_carte_volo() -> void:
	for c in _carte_volo:
		var t: float = c["t"]
		if t < 0.0:
			continue
		var e := smoothstep(0.0, 1.0, t)
		var centro: Vector2 = c["da"].lerp(c["a"], e)
		var h: float = c["h"] * (1.0 + sin(t * PI) * 0.15)
		var tex: Texture2D = c["fronte"]
		var sx := 1.0
		if c["retro"] != null:
			# si gira a metà strada: prima il dorso, poi la faccia
			sx = absf(cos(t * PI))
			if t < 0.5:
				tex = c["retro"]
		if tex == null:
			continue
		var w: float = h * tex.get_width() / max(1.0, float(tex.get_height()))
		var r := Rect2(centro - Vector2(w * sx, h) / 2.0, Vector2(w * sx, h))
		draw_rect(Rect2(a_schermo(r.position + Vector2(10, 14)), r.size * zoom), Color(0, 0, 0, 0.35))
		draw_texture_rect(tex, Rect2(a_schermo(r.position), r.size * zoom), false)


## Dove si disegna un pezzo di quel tipo in quel luogo (pixel del tabellone).
func _pos_tipo(tipo: String, l: String) -> Vector2:
	if tipo == "nazgul":
		var rr: Dictionary = Dati.d()["regioni"][l]
		return Vector2(rr["x"], rr["y"])
	if l == "riserva":
		return RISERVE.get(tipo.trim_prefix("truppa_"), Vector2.ZERO)
	if tipo == "truppa_ombra":
		return pos_luogo(l) + Vector2(60, -44)
	return pos_luogo(l) + Vector2(-60, 40)


## Posizione mostrata adesso di un pezzo che scorre (o quella vera, se è fermo).
func _mostra(chiave: String, dest: Vector2) -> Vector2:
	if not _anim.has(chiave):
		return dest
	var an: Dictionary = _anim[chiave]
	var t: float = smoothstep(0.0, 1.0, an["t"])
	return an["da"].lerp(an["a"], t) + Vector2(0, -sin(an["t"] * PI) * an["arco"])


## Da chiamare a ogni cambio di stato: confronta con lo stato precedente e fa scorrere i pezzi.
func registra() -> void:
	if motore == null or motore.stato.is_empty():
		return
	var nuova := _istantanea()
	if _foto.is_empty() or not is_visible_in_tree():
		_foto = nuova
		_anim.clear()
		_voli.clear()
		return
	for k in nuova["pos"]:
		var a: Vector2 = nuova["pos"][k]
		if not _foto["pos"].has(k):
			continue
		var da: Vector2 = _mostra(k, _foto["pos"][k])
		if da.distance_to(a) < 1.0:
			continue
		var d := da.distance_to(a)
		_anim[k] = {"da": da, "a": a, "t": 0.0, "dur": clampf(0.35 + d / 1400.0, 0.35, 1.5) * ritmo, "arco": clampf(d * 0.15, 10.0, 70.0)}
	for tipo in nuova["conti"]:
		var prima: Dictionary = _foto["conti"].get(tipo, {})
		var dopo: Dictionary = nuova["conti"][tipo]
		var via: Array = []
		var arrivi: Array = []
		for l in prima:
			for k in max(0, int(prima[l]) - int(dopo.get(l, 0))):
				via.append(l)
		for l in dopo:
			for k in max(0, int(dopo[l]) - int(prima.get(l, 0))):
				arrivi.append(l)
		var tex := UI.pedina(tipo)
		var lato := 95.0 if tipo == "nazgul" else 56.0
		for l in arrivi:
			var a := _pos_tipo(tipo, l)
			if via.is_empty():
				_voli.append({"tex": tex, "da": a, "a": a, "t": 0.0, "dur": 0.6 * ritmo, "lato": lato, "modo": "compari"})
				continue
			var best := 0
			for q in via.size():
				if _pos_tipo(tipo, via[q]).distance_to(a) < _pos_tipo(tipo, via[best]).distance_to(a):
					best = q
			var da := _pos_tipo(tipo, via[best])
			via.remove_at(best)
			var d := da.distance_to(a)
			_voli.append({"tex": tex, "da": da, "a": a, "t": 0.0, "dur": clampf(0.6 + d / 900.0, 0.6, 2.2) * ritmo, "lato": lato,
				"modo": "vola", "arco": clampf(d * 0.2, 20.0, 160.0 if tipo == "nazgul" else 80.0)})
		for l in via:
			_voli.append({"tex": tex, "da": _pos_tipo(tipo, l), "a": _pos_tipo(tipo, l), "t": 0.0, "dur": 0.8 * ritmo, "lato": lato, "modo": "svanisci"})
	_anima_carte(_foto["carte"], nuova["carte"])
	_foto = nuova
	if not _anim.is_empty() or not _voli.is_empty() or not _carte_volo.is_empty():
		set_process(true)


func lampo(l: String, col: Color) -> void:
	_lampi.append({"pos": pos_luogo(l), "t": 0.0, "col": col})
	set_process(true)


func _process(delta: float) -> void:
	var attivo := false
	for p in _anim.keys():
		_anim[p]["t"] += delta / float(_anim[p]["dur"])
		if _anim[p]["t"] >= 1.0:
			_anim.erase(p)
		else:
			attivo = true
	for k in range(_carte_volo.size() - 1, -1, -1):
		_carte_volo[k]["t"] += delta / float(_carte_volo[k]["dur"])
		if _carte_volo[k]["t"] >= 1.0:
			_carte_volo.remove_at(k)
		else:
			attivo = true
	for k in range(_voli.size() - 1, -1, -1):
		_voli[k]["t"] += delta / float(_voli[k]["dur"])
		if _voli[k]["t"] >= 1.0:
			_voli.remove_at(k)
		else:
			attivo = true
	for k in range(_lampi.size() - 1, -1, -1):
		_lampi[k]["t"] += delta * 1.2
		if _lampi[k]["t"] >= 1.0:
			_lampi.remove_at(k)
		else:
			attivo = true
	queue_redraw()
	if not attivo:
		set_process(false)


func _draw() -> void:
	if tabellone == null:
		return
	draw_texture_rect(tabellone, Rect2(offset, Vector2(W, H) * zoom), false)
	if motore == null or motore.stato.is_empty():
		return
	var z := zoom
	var f := UI.font_grassetto
	# linea di battaglia evidenziata
	if linea_evidenziata != "":
		var p: Array = Dati.linea(linea_evidenziata)["percorso"]
		for k in p.size() - 1:
			draw_line(a_schermo(pos_luogo(p[k])), a_schermo(pos_luogo(p[k + 1])), Color(1, 0.15, 0.1, 0.85), max(3.0, 14 * z))
	_disegna_spazi(z)
	# Occhio sulla regione
	var ro: Dictionary = Dati.d()["regioni"][motore.occhio]
	var po := a_schermo(Vector2(ro["x"], ro["y"]) + Vector2(0, -110))
	var t_occhio := UI.pedina("occhio")
	var so := 170.0 * z
	draw_circle(po, so * 0.62, Color(1, 0.45, 0.05, 0.25))
	draw_texture_rect(t_occhio, Rect2(po - Vector2(so, so) / 2, Vector2(so, so)), false)
	# Nazgûl per regione
	var tn := UI.pedina("nazgul")
	for r in motore.nazgul:
		var n: int = motore.nazgul[r]
		if n <= 0:
			continue
		var rr: Dictionary = Dati.d()["regioni"][r]
		var base := Vector2(rr["x"], rr["y"])
		var sn := 95.0 * z
		for k in n:
			var pp := a_schermo(base + Vector2((k - (n - 1) / 2.0) * 62.0, 0))
			draw_texture_rect(tn, Rect2(pp - Vector2(sn * 0.65, sn) / 2, Vector2(sn * 0.65, sn)), false)
	# luoghi
	for l in Dati.luoghi():
		var c := a_schermo(pos_luogo(l))
		var s: Dictionary = motore.stato[l]
		var orig: String = Dati.luogo(l)["tipo"]
		if s["tipo"] == "rifugio" and orig != "rifugio":
			var tr := UI.pedina("rifugio")
			var sz := 112.0 * z
			draw_texture_rect(tr, Rect2(c - Vector2(sz, sz) / 2, Vector2(sz, sz)), false)
		elif s["tipo"] == "fortezza" and orig == "rifugio":
			var tf := UI.pedina("fortezza")
			var sz := 118.0 * z
			draw_texture_rect(tf, Rect2(c - Vector2(sz, sz) / 2, Vector2(sz, sz)), false)
		if evidenziati.has(l):
			var col: Color = evidenziati[l]
			draw_arc(c, 52 * z, 0, TAU, 40, col, max(3.0, 9 * z), true)
		if l == sotto_mouse:
			draw_arc(c, 46 * z, 0, TAU, 40, Color(1, 1, 1, 0.7), max(2.0, 5 * z), true)
		# truppe amiche: in basso a sinistra; Ombra: in basso a destra
		var x := -78.0
		for a in Dati.ARMATE:
			var n: int = s["truppe"][a]
			if n <= 0:
				continue
			var tt := UI.pedina("truppa_" + a)
			var tsz := 50.0 * z
			var pp := c + Vector2(x, 40) * z
			draw_texture_rect(tt, Rect2(pp - Vector2(tsz, tsz) / 2, Vector2(tsz, tsz)), false)
			if n > 1:
				_numero(pp + Vector2(16, 14) * z, n, z)
			x += 46.0
		if s["ombra"] > 0:
			var to := UI.pedina("truppa_ombra")
			var tsz := 56.0 * z
			var pp := c + Vector2(60, -44) * z
			draw_texture_rect(to, Rect2(pp - Vector2(tsz, tsz) / 2, Vector2(tsz, tsz)), false)
			_numero(pp + Vector2(20, 16) * z, s["ombra"], z, Color(0.55, 0.05, 0.03))
	# personaggi
	var pp := _pos_pg()
	for p in pp:
		var dest: Vector2 = _mostra("pg_" + p, pp[p])
		var tex := UI.pedina("gandalf_bianco" if p == "gandalf" and motore.pg[p]["bianco"] else p)
		if tex == null:
			continue
		var hh := 118.0 * z
		var ww: float = hh * tex.get_width() / max(1.0, float(tex.get_height()))
		var r := Rect2(a_schermo(dest) - Vector2(ww / 2, hh * 0.85), Vector2(ww, hh))
		if p == motore.attivo:
			draw_circle(a_schermo(dest) + Vector2(0, -hh * 0.3), ww * 0.75, Color(1, 0.85, 0.35, 0.35))
		draw_texture_rect(tex, r, false)
	# pezzi in volo
	for v in _voli:
		var t: float = v["t"]
		var tex: Texture2D = v["tex"]
		if tex == null:
			continue
		var c: Vector2
		var lato: float = v["lato"]
		var mod := Color.WHITE
		match v["modo"]:
			"vola":
				c = v["da"].lerp(v["a"], smoothstep(0.0, 1.0, t)) + Vector2(0, -sin(t * PI) * v["arco"])
				lato *= 1.0 + sin(t * PI) * 0.25
			"compari":
				c = v["a"]
				lato *= 1.6 - 0.6 * t
				mod.a = t
			_:
				c = v["a"] + Vector2(0, -40 * t)
				mod.a = 1.0 - t
		var sz := Vector2(lato * tex.get_width() / max(1.0, float(tex.get_height())), lato) * z
		draw_texture_rect(tex, Rect2(a_schermo(c) - sz / 2, sz), false, mod)
	# lampi
	for x in _lampi:
		var c := a_schermo(x["pos"])
		var col: Color = x["col"]
		col.a = 1.0 - x["t"]
		draw_arc(c, (40 + 120 * x["t"]) * z, 0, TAU, 48, col, max(3.0, 12 * z), true)
	_disegna_carte_volo()
	# nome del luogo sotto il mouse
	if sotto_mouse != "":
		var c := a_schermo(pos_luogo(sotto_mouse)) + Vector2(0, 70 * z + 18)
		var nome := Dati.nome(sotto_mouse)
		var w := f.get_string_size(nome, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		draw_rect(Rect2(c - Vector2(w / 2 + 8, 20), Vector2(w + 16, 28)), Color(0.08, 0.06, 0.04, 0.85))
		draw_string(f, c - Vector2(w / 2, 0), nome, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UI.PERGAMENA)


func _numero(p: Vector2, n: int, z: float, fondo := Color(0.1, 0.08, 0.05)) -> void:
	var r: float = max(9.0, 18.0 * z)
	draw_circle(p, r, fondo)
	draw_arc(p, r, 0, TAU, 24, UI.ORO, 1.5, true)
	var fs := int(max(11.0, 24.0 * z))
	var s := str(n)
	var w := UI.font_grassetto.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(UI.font_grassetto, p + Vector2(-w / 2, fs * 0.36), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


## Carta (o dorso) centrata su un punto del tabellone, alta h pixel.
func _carta(t: Texture2D, c: Vector2, h: float, id := -1, n := -1) -> void:
	if t == null:
		return
	var w: float = h * t.get_width() / max(1.0, float(t.get_height()))
	var r := Rect2(c - Vector2(w, h) / 2.0, Vector2(w, h))
	if n > 1:
		for k in range(min(n - 1, 4), 0, -1):
			draw_rect(Rect2(a_schermo(r.position + Vector2(k * 4, k * 4)), r.size * zoom), Color(0.05, 0.04, 0.03, 0.8))
	draw_texture_rect(t, Rect2(a_schermo(r.position), r.size * zoom), false)
	if id >= 0:
		_carte_mappa.append({"rect": r, "id": id})
	if n >= 0:
		_numero(a_schermo(r.position + Vector2(w - 36, h - 36)), n, zoom * 1.6)


func _gettone(t: Texture2D, c: Vector2, lato: float) -> void:
	if t == null:
		return
	var h: float = lato * t.get_height() / max(1.0, float(t.get_width()))
	draw_texture_rect(t, Rect2(a_schermo(c - Vector2(lato, h) / 2.0), Vector2(lato, h) * zoom), false)


func _disegna_spazi(z: float) -> void:
	_carte_mappa.clear()
	var m := motore
	# minaccia e speranza sulle loro tracce
	_gettone(UI.pedina("minaccia"), _mostra("minaccia", pos_minaccia(m.minaccia)), 92.0)
	_gettone(UI.pedina("speranza"), _mostra("speranza", pos_speranza(m.speranza)), 92.0)
	# riserve delle truppe amiche sui medaglioni delle razze
	for a in RISERVE:
		var n: int = m.riserva_truppe[a]
		var c: Vector2 = RISERVE[a]
		for k in min(n, 5):
			_gettone(UI.pedina("truppa_" + a), c + Vector2(-6 + k * 3, 10 - k * 6), 74.0)
		_numero(a_schermo(c + Vector2(38, 34)), n, z * 1.6)
	# mazzo dell'Ombra: pesca, risolvi, scarti
	var dorso_ombra := "dorso_bandiera"
	if not m.mazzo_ombra.is_empty():
		dorso_ombra = "dorso_" + Dati.carta(m.mazzo_ombra.back())["retro"]
		_carta(UI.tex("res://assets/carte/%s.webp" % dorso_ombra), OMBRA_PESCA, H_OMBRA, -1, m.mazzo_ombra.size())
	for k in m.risolte.size():
		if not _nascosta("risolte:%d" % k):
			_carta(UI.carta_tex(m.risolte[k]), _slot_risolta(k), H_OMBRA, m.risolte[k])
	if not m.scarti_ombra.is_empty():
		var so: int = m.scarti_ombra.size() - (1 if _nascosta("scarti_ombra") else 0)
		if so > 0:
			_carta(UI.carta_tex(m.scarti_ombra[so - 1]), OMBRA_SCARTI, H_OMBRA, m.scarti_ombra[so - 1], so)
	# mazzo dei giocatori
	if not m.mazzo.is_empty():
		_carta(UI.tex("res://assets/carte/dorso_giocatori.webp"), GIOC_PESCA, H_GIOC, -1, m.mazzo.size())
	if not m.scarti.is_empty():
		var sg: int = m.scarti.size() - (1 if _nascosta("scarti") else 0)
		if sg > 0:
			_carta(UI.carta_tex(m.scarti[sg - 1]), GIOC_SCARTI, H_GIOC, m.scarti[sg - 1], sg)
