extends SubViewportContainer
## Il tavolo in 3D: il tabellone della Terra di Mezzo su un tavolo di legno, con le sagome dei personaggi
## in piedi (come le figure di cartone del gioco), le truppe, i Nazgûl, l'Occhio di Sauron, rifugi e fortezze.
## Comandi: trascina con il tasto sinistro per ruotare, con il destro (o Maiusc+sinistro) per spostare;
## rotellina o pizzico per avvicinare; frecce o WASD per spostare; R o doppio clic per tornare alla vista iniziale.

var vista
var sv: SubViewport
var cam: Camera3D
var perno: Node3D
var dinamici: Node3D
var _mat := {}
var _rot := Vector2(-1.05, 0.0)
var _dist := 30.0
var _ruota := false
var _sposta := false
var _t := 0.0
var occhio3d: Node3D

## Tabellone: 3259 x 2796 pixel → 32.59 x 27.96 unità, centrato nell'origine.
const SCALA := 0.01
const DIM := Vector2(32.59, 27.96)


func _a3d(px: Vector2, y := 0.0) -> Vector3:
	return Vector3(px.x * SCALA - DIM.x / 2.0, y, px.y * SCALA - DIM.y / 2.0)


func _luogo3d(l: String, y := 0.0) -> Vector3:
	var d: Dictionary = Dati.luogo(l)
	return _a3d(Vector2(d["x"], d["y"]), y)


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	sv = SubViewport.new()
	sv.msaa_3d = Viewport.MSAA_4X
	sv.own_world_3d = true
	add_child(sv)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.04, 0.03)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.85, 0.75, 0.6)
	e.ambient_light_energy = 0.7
	env.environment = e
	sv.add_child(env)
	var sole := DirectionalLight3D.new()
	sole.rotation = Vector3(-1.0, 0.6, 0)
	sole.light_energy = 1.1
	sole.light_color = Color(1.0, 0.9, 0.75)
	sole.shadow_enabled = true
	sv.add_child(sole)
	perno = Node3D.new()
	sv.add_child(perno)
	cam = Camera3D.new()
	cam.fov = 45
	perno.add_child(cam)
	# tavolo di legno
	var tavolo := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(DIM.x + 14, 1.0, DIM.y + 10)
	tavolo.mesh = bm
	tavolo.position = Vector3(0, -0.52, 0)
	var mt := StandardMaterial3D.new()
	mt.albedo_color = Color(0.22, 0.13, 0.07)
	mt.roughness = 0.75
	tavolo.material_override = mt
	sv.add_child(tavolo)
	# tabellone
	var tb := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = DIM
	tb.mesh = pm
	tb.position = Vector3(0, 0.0, 0)
	var mb := StandardMaterial3D.new()
	mb.albedo_texture = UI.tex("res://assets/ui/tabellone.webp")
	mb.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mb.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	tb.material_override = mb
	sv.add_child(tb)
	var bordo := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(DIM.x + 0.3, 0.12, DIM.y + 0.3)
	bordo.mesh = bb
	bordo.position = Vector3(0, -0.07, 0)
	bordo.material_override = _colore(Color(0.1, 0.07, 0.05))
	sv.add_child(bordo)
	dinamici = Node3D.new()
	sv.add_child(dinamici)
	reimposta_vista()


func _process(delta: float) -> void:
	_t += delta
	if occhio3d != null:
		occhio3d.position.y = 3.2 + sin(_t * 1.6) * 0.25
		occhio3d.rotation.y = _rot.y
	if not visible or not has_focus():
		return
	var d := Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		d.x -= 1
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		d.x += 1
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		d.y -= 1
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		d.y += 1
	if d != Vector2.ZERO:
		_sposta_vista(d * delta * _dist * 0.8)


func _aggiorna_camera() -> void:
	_rot.x = clamp(_rot.x, -1.5, -0.3)
	_dist = clamp(_dist, 4.0, 60.0)
	perno.position.x = clamp(perno.position.x, -20.0, 20.0)
	perno.position.z = clamp(perno.position.z, -18.0, 18.0)
	perno.rotation = Vector3(0, _rot.y, 0)
	cam.position = Vector3(0, -sin(_rot.x) * _dist, cos(_rot.x) * _dist)
	cam.look_at(perno.global_position, Vector3.UP)
	# le sagome guardano sempre la camera (ruotano solo attorno all'asse verticale)
	for n in dinamici.get_children():
		if n.has_meta("sagoma"):
			n.rotation.y = _rot.y


func _sposta_vista(d: Vector2) -> void:
	var destra := Vector3(cos(_rot.y), 0, -sin(_rot.y))
	var giu := Vector3(sin(_rot.y), 0, cos(_rot.y))
	perno.position += destra * d.x + giu * d.y
	_aggiorna_camera()


func reimposta_vista() -> void:
	_rot = Vector2(-1.05, 0.0)
	_dist = 30.0
	perno.position = Vector3(0, 0, 1.0)
	_aggiorna_camera()


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP and ev.pressed:
			_dist *= 0.9
			_aggiorna_camera()
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN and ev.pressed:
			_dist *= 1.1
			_aggiorna_camera()
		elif ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				grab_focus()
				if ev.shift_pressed:
					_sposta = true
				else:
					_ruota = true
			else:
				if _ruota and not _mosso:
					_clic(ev.position)
				_ruota = false
				_sposta = false
				_mosso = false
			if ev.double_click:
				reimposta_vista()
		elif ev.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_sposta = ev.pressed
			if ev.pressed:
				grab_focus()
		accept_event()
	elif ev is InputEventMouseMotion:
		if _sposta:
			_mosso = true
			var k: float = _dist / max(1.0, size.y) * 0.85
			_sposta_vista(-ev.relative * k)
		elif _ruota:
			if ev.relative.length() > 1.5:
				_mosso = true
			_rot.y -= ev.relative.x * 0.006
			_rot.x -= ev.relative.y * 0.004
			_aggiorna_camera()
	elif ev is InputEventPanGesture:
		_sposta_vista(ev.delta * _dist * 0.02)
		accept_event()
	elif ev is InputEventMagnifyGesture:
		_dist /= ev.factor
		_aggiorna_camera()
		accept_event()
	elif ev is InputEventKey and ev.pressed and ev.keycode == KEY_R:
		reimposta_vista()


var _mosso := false


## Clic su un luogo: lo passa alla vista (come sulla mappa 2D).
func _clic(pos: Vector2) -> void:
	var from := cam.project_ray_origin(pos)
	var dir := cam.project_ray_normal(pos)
	var hit = Plane(Vector3.UP, 0.0).intersects_ray(from, dir)
	if hit == null:
		return
	var best := ""
	var bd := 0.8
	for l in Dati.luoghi():
		var d: float = (_luogo3d(l) - hit).length()
		if d < bd:
			bd = d
			best = l
	if best != "":
		vista._clic_luogo(best)


func _mat_tex(t: Texture2D) -> StandardMaterial3D:
	if t == null:
		return _colore(Color(0.5, 0.4, 0.3))
	if not _mat.has(t):
		var m := StandardMaterial3D.new()
		m.albedo_texture = t
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mat[t] = m
	return _mat[t]


func _colore(c: Color) -> StandardMaterial3D:
	var k := "c" + c.to_html()
	if not _mat.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.6
		_mat[k] = m
	return _mat[k]


## Sagoma verticale con base (come le figure di cartone del gioco).
func _sagoma(t: Texture2D, pos: Vector3, altezza: float) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.set_meta("sagoma", true)
	var ratio: float = float(t.get_width()) / max(1.0, float(t.get_height()))
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(altezza * ratio, altezza)
	q.mesh = qm
	q.position = Vector3(0, altezza / 2.0 + 0.06, 0)
	q.material_override = _mat_tex(t)
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	n.add_child(q)
	var base := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = minf(altezza * ratio * 0.42, altezza * 0.24)
	cm.bottom_radius = cm.top_radius
	cm.height = 0.08
	base.mesh = cm
	base.position.y = 0.04
	base.material_override = _colore(Color(0.12, 0.1, 0.08))
	n.add_child(base)
	n.rotation.y = _rot.y
	dinamici.add_child(n)
	return n


## Segnalino piatto appoggiato sul tabellone.
func _gettone(t: Texture2D, pos: Vector3, lato: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(lato, lato * float(t.get_height()) / max(1.0, float(t.get_width())))
	mi.mesh = pm
	mi.position = pos
	mi.material_override = _mat_tex(t)
	dinamici.add_child(mi)
	return mi


## Truppa: un blocchetto colorato con il simbolo sopra (come i pezzi di plastica, in piccolo).
func _truppa(armata: String, pos: Vector3) -> void:
	var col: Color = UI.COLORI_ARMATE.get(armata, Color(0.75, 0.1, 0.08))
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.32, 0.36, 0.22)
	mi.mesh = bm
	mi.position = pos + Vector3(0, 0.18, 0)
	mi.material_override = _colore(col)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	dinamici.add_child(mi)
	var testa := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.11
	sm.height = 0.22
	testa.mesh = sm
	testa.position = pos + Vector3(0, 0.45, 0)
	testa.material_override = _colore(col)
	dinamici.add_child(testa)


func _scritta(testo: String, pos: Vector3, size := 64, col := UI.PERGAMENA) -> void:
	var l := Label3D.new()
	l.text = testo
	l.font = UI.font_grassetto
	l.font_size = size
	l.pixel_size = 0.006
	l.modulate = col
	l.outline_size = 14
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = pos
	l.no_depth_test = true
	dinamici.add_child(l)


func evento(tipo: String, dati: Dictionary) -> void:
	if tipo == "dadi" and vista != null:
		vista._mostra_dadi(dati)


func aggiorna(m: Motore) -> void:
	if dinamici == null:
		return
	for c in dinamici.get_children():
		c.queue_free()
	occhio3d = null
	# rifugi conquistati e caduti
	for l in m.stato:
		var orig: String = Dati.luogo(l)["tipo"]
		var t: String = m.stato[l]["tipo"]
		if t == "rifugio" and orig != "rifugio":
			_gettone(UI.pedina("rifugio"), _luogo3d(l, 0.02), 1.15)
		elif t == "fortezza" and orig == "rifugio":
			_gettone(UI.pedina("fortezza"), _luogo3d(l, 0.02), 1.2)
		# truppe amiche in fila, Ombra in un mucchio rosso
		var k := 0
		for a in Dati.ARMATE:
			for j in m.stato[l]["truppe"][a]:
				var off := Vector3(-0.55 + (k % 4) * 0.36, 0.0, 0.42 + (k / 4) * 0.3)
				_truppa(a, _luogo3d(l) + off)
				k += 1
		var n: int = m.stato[l]["ombra"]
		for j in min(n, 8):
			var off := Vector3(0.45 + (j % 3) * 0.34, 0.0, -0.45 + (j / 3) * 0.28)
			_truppa("ombra", _luogo3d(l) + off)
		if n > 8:
			_scritta("%d" % n, _luogo3d(l, 1.2) + Vector3(0.8, 0, -0.4), 90, Color(1, 0.4, 0.3))
	# personaggi
	var per_luogo := {}
	for p in m.pg:
		if m.pg[p]["fuori"]:
			continue
		var l: String = m.pg[p]["luogo"]
		if not per_luogo.has(l):
			per_luogo[l] = []
		per_luogo[l].append(p)
	for l in per_luogo:
		var lista: Array = per_luogo[l]
		for k in lista.size():
			var p: String = lista[k]
			var tex := UI.pedina("gandalf_bianco" if p == "gandalf" and m.pg[p]["bianco"] else p)
			var pos := _luogo3d(l) + Vector3((k - (lista.size() - 1) / 2.0) * 0.55, 0, -0.1)
			_sagoma(tex, pos, 1.7 if p != m.attivo else 2.0)
	# Nazgûl sulle regioni
	for r in m.nazgul:
		var n: int = m.nazgul[r]
		var rr: Dictionary = Dati.d()["regioni"][r]
		for k in n:
			var pos := _a3d(Vector2(rr["x"], rr["y"])) + Vector3((k - (n - 1) / 2.0) * 0.75, 0, 0.25 * (k % 2))
			_sagoma(UI.pedina("nazgul"), pos, 0.95)
	# Occhio di Sauron sospeso sopra la regione
	var ro: Dictionary = Dati.d()["regioni"][m.occhio]
	occhio3d = Node3D.new()
	occhio3d.position = _a3d(Vector2(ro["x"], ro["y"]), 3.2)
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(1.8, 1.8)
	q.mesh = qm
	q.material_override = _mat_tex(UI.pedina("occhio"))
	occhio3d.add_child(q)
	var luce := OmniLight3D.new()
	luce.light_color = Color(1, 0.4, 0.1)
	luce.light_energy = 2.5
	luce.omni_range = 6.0
	occhio3d.add_child(luce)
	dinamici.add_child(occhio3d)
	_aggiorna_camera()
