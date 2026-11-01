extends Control
## Mappa 2D: il tabellone con truppe, personaggi, Nazgûl, Occhio, rifugi e fortezze.
## Si ingrandisce con la rotellina (o con due dita), si sposta trascinando. I luoghi si possono cliccare:
## se la scelta in corso riguarda un luogo, il clic la fa.

signal luogo_cliccato(id: String)

const W := 3259.0
const H := 2796.0

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
var _anim: Dictionary = {}           # pid -> {da: Vector2, t: float}
var _lampi: Array = []               # {pos, t, col}


func _ready() -> void:
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
		var l := _luogo_a(ev.position)
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
			t += "\nFortezza dell'Ombra"
		"ombra":
			t += "\nLuogo dell'Ombra"
	var col: String = Dati.luogo(l)["arruolo"]
	if col != "":
		t += "\nSi arruolano truppe %s" % Dati.NOMI_ARMATE[col]
	var tr: Array = []
	for a in Dati.ARMATE:
		if s["truppe"][a] > 0:
			tr.append("%d %s" % [s["truppe"][a], Dati.NOMI_ARMATE[a]])
	if not tr.is_empty():
		t += "\nTruppe amiche: " + ", ".join(tr)
	if s["ombra"] > 0:
		t += "\nTruppe dell'Ombra: %d" % s["ombra"]
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


func anima_viaggio(pgs: Array, da: String) -> void:
	for p in pgs:
		_anim[p] = {"da": pos_luogo(da), "t": 0.0}
	set_process(true)


func lampo(l: String, col: Color) -> void:
	_lampi.append({"pos": pos_luogo(l), "t": 0.0, "col": col})
	set_process(true)


func _process(delta: float) -> void:
	var attivo := false
	for p in _anim.keys():
		_anim[p]["t"] += delta * 2.2
		if _anim[p]["t"] >= 1.0:
			_anim.erase(p)
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
	var per_luogo := {}
	for p in motore.pg:
		if motore.pg[p]["fuori"]:
			continue
		var l: String = motore.pg[p]["luogo"]
		if not per_luogo.has(l):
			per_luogo[l] = []
		per_luogo[l].append(p)
	for l in per_luogo:
		var lista: Array = per_luogo[l]
		var c := pos_luogo(l)
		for k in lista.size():
			var p: String = lista[k]
			var dest := c + Vector2((k - (lista.size() - 1) / 2.0) * 58.0, -70)
			if _anim.has(p):
				var tt: float = _anim[p]["t"]
				dest = _anim[p]["da"].lerp(dest, ease(tt, -2.0)) + Vector2(0, -sin(tt * PI) * 60)
			var tex := UI.pedina("gandalf_bianco" if p == "gandalf" and motore.pg[p]["bianco"] else p)
			if tex == null:
				continue
			var hh := 118.0 * z
			var ww: float = hh * tex.get_width() / max(1.0, float(tex.get_height()))
			var r := Rect2(a_schermo(dest) - Vector2(ww / 2, hh * 0.85), Vector2(ww, hh))
			if p == motore.attivo:
				draw_circle(a_schermo(dest) + Vector2(0, -hh * 0.3), ww * 0.75, Color(1, 0.85, 0.35, 0.35))
			draw_texture_rect(tex, r, false)
	# lampi
	for x in _lampi:
		var c := a_schermo(x["pos"])
		var col: Color = x["col"]
		col.a = 1.0 - x["t"]
		draw_arc(c, (40 + 120 * x["t"]) * z, 0, TAU, 48, col, max(3.0, 12 * z), true)
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
