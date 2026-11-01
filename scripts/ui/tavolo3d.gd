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
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(-0.5, PI, 0)
	fill.light_energy = 0.55
	fill.light_color = Color(0.8, 0.85, 1.0)
	sv.add_child(fill)
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
	if dinamici != null:
		for p in get_tree().get_nodes_in_group("volteggia"):
			_volteggia(p)
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
		else:
			_puntamento(ev.position)
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
var _ultimo_id := -1


## Carta sotto il mouse (senza fisica: controllo dei rettangoli delle carte appoggiate).
func _puntamento(pos: Vector2) -> void:
	var from := cam.project_ray_origin(pos)
	var dir := cam.project_ray_normal(pos)
	var best := -1
	var best_d := 1e9
	for n in dinamici.get_children():
		if not n.has_meta("carta"):
			continue
		var hit = Plane(Vector3.UP, n.global_position.y).intersects_ray(from, dir)
		if hit == null:
			continue
		var loc: Vector3 = hit - n.global_position
		var half: Vector2 = n.get_meta("mezza")
		if abs(loc.x) <= half.x and abs(loc.z) <= half.y:
			var d: float = from.distance_to(hit)
			if d < best_d:
				best_d = d
				best = int(n.get_meta("carta"))
	if best != _ultimo_id:
		_ultimo_id = best
		if best >= 0:
			vista._mostra_zoom_a(best, get_global_rect().position + pos)
		else:
			vista._nascondi_zoom()


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


## Gettone sagomato come nel modulo: la forma viene dal contorno dell'immagine, con spessore e bordo.
var _mesh_gettoni := {}


func _mesh_gettone(t: Texture2D, spessore: float) -> Array:
	var key := "%s|%.2f" % [t.resource_path, spessore]
	if _mesh_gettoni.has(key):
		return _mesh_gettoni[key]
	var img := t.get_image()
	if img.is_compressed():
		img.decompress()
	var w := img.get_width()
	var h := img.get_height()
	var scala: float = 96.0 / max(w, h)
	var piccola := img.duplicate()
	piccola.resize(int(w * scala), int(h * scala))
	var bm := BitMap.new()
	bm.create_from_image_alpha(piccola, 0.5)
	var polys := bm.opaque_to_polygons(Rect2i(Vector2i.ZERO, bm.get_size()), 1.2)
	var pw := float(piccola.get_width())
	var ph := float(piccola.get_height())
	var asp: float = pw / ph
	var top := SurfaceTool.new()
	top.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lati := SurfaceTool.new()
	lati.begin(Mesh.PRIMITIVE_TRIANGLES)
	if polys.is_empty():
		polys = [PackedVector2Array([Vector2(0, 0), Vector2(pw, 0), Vector2(pw, ph), Vector2(0, ph)])]
	for poly in polys:
		var idx := Geometry2D.triangulate_polygon(poly)
		var pts: Array = []
		for q in poly:
			var u: float = q.x / pw
			var v: float = q.y / ph
			pts.append([Vector3((u - 0.5) * asp, spessore, v - 0.5), Vector2(u, v)])
		for k in idx:
			top.set_normal(Vector3.UP)
			top.set_uv(pts[k][1])
			top.add_vertex(pts[k][0])
		for k in poly.size():
			var a: Vector3 = pts[k][0]
			var b: Vector3 = pts[(k + 1) % poly.size()][0]
			var a0 := Vector3(a.x, 0, a.z)
			var b0 := Vector3(b.x, 0, b.z)
			var nrm := (b - a).cross(Vector3.DOWN).normalized()
			for vv in [a, b, b0, a, b0, a0]:
				lati.set_normal(nrm)
				lati.add_vertex(vv)
	var res := [top.commit(), lati.commit(), asp]
	_mesh_gettoni[key] = res
	return res


## Gettone del modulo: dim = lato più lungo (piatto) oppure altezza (in piedi), in unità del tavolo.
func _pezzo(t: Texture2D, pos: Vector3, dim: float, spessore := 0.08, bordo := Color(0.12, 0.1, 0.08), in_piedi := false) -> Node3D:
	if t == null:
		return null
	var asp: float = float(t.get_width()) / max(1.0, float(t.get_height()))
	var sc: float = dim if in_piedi else dim / max(asp, 1.0)
	var m := _mesh_gettone(t, spessore / sc)
	var n := Node3D.new()
	var a := MeshInstance3D.new()
	a.mesh = m[0]
	a.material_override = _mat_tex(t)
	a.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	n.add_child(a)
	var b := MeshInstance3D.new()
	b.mesh = m[1]
	b.material_override = _colore(bordo)
	n.add_child(b)
	n.scale = Vector3.ONE * sc
	if not in_piedi:
		n.position = pos
		dinamici.add_child(n)
		return n
	# in piedi su una basetta, sempre rivolto verso la camera
	var p := Node3D.new()
	p.position = pos
	p.set_meta("sagoma", true)
	n.rotation.x = PI / 2
	n.position = Vector3(0, sc * 0.5 + 0.06, -spessore * 0.5)
	p.add_child(n)
	var base := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = minf(sc * asp * 0.4, sc * 0.26)
	cm.bottom_radius = cm.top_radius
	cm.height = 0.07
	base.mesh = cm
	base.position.y = 0.035
	base.material_override = _colore(Color(0.1, 0.08, 0.06))
	p.add_child(base)
	p.rotation.y = _rot.y
	dinamici.add_child(p)
	return p


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


## Numero sospeso sopra il tavolo, sempre rivolto alla camera (cifre disegnate come immagini).
func _scritta(testo: String, pos: Vector3, size := 64, col := UI.PERGAMENA) -> void:
	var n := Node3D.new()
	n.position = pos
	var h: float = 0.42 * size / 64.0
	var w_tot := 0.0
	var cifre: Array = []
	for ch in testo:
		var t := UI.tex("res://assets/ui/cifra_%s.png" % ch)
		if t == null:
			continue
		var w: float = h * t.get_width() / float(t.get_height())
		cifre.append([t, w])
		w_tot += w * 0.92
	var x := -w_tot / 2.0
	for c in cifre:
		var sp := Sprite3D.new()
		sp.texture = c[0]
		sp.pixel_size = h / float(c[0].get_height())
		sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sp.no_depth_test = true
		sp.modulate = col
		sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sp.render_priority = 10
		sp.position = Vector3(x + c[1] / 2.0, 0, 0)
		n.add_child(sp)
		x += c[1] * 0.92
	dinamici.add_child(n)


func evento(tipo: String, dati: Dictionary) -> void:
	if tipo == "dadi" and vista != null:
		vista._mostra_dadi(dati)


## Carta (o dorso) appoggiata sul tabellone: centro e altezza in pixel del tabellone, con la pila sotto.
func _carta3d(t: Texture2D, c_px: Vector2, h_px: float, n := 1, id := -1, da_px := Vector2.INF, retro: Texture2D = null, ritardo := 0.0) -> void:
	if t == null:
		return
	var w_px: float = h_px * t.get_width() / max(1.0, float(t.get_height()))
	var spess: float = 0.006 * clampi(n, 1, 40)
	var pos := _a3d(c_px)
	var anima := da_px != Vector2.INF
	# la pila sotto la carta (se la carta arriva in volo, la pila è quella di prima)
	var n_pila: int = n - 1 if anima else n
	if n_pila > 1:
		var sp2: float = 0.006 * clampi(n_pila, 1, 40)
		var box := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(w_px * SCALA, sp2, h_px * SCALA)
		box.mesh = bm
		box.position = pos + Vector3(0, sp2 / 2.0, 0)
		box.material_override = _colore(Color(0.86, 0.82, 0.72))
		dinamici.add_child(box)
	var carta := Node3D.new()
	carta.position = pos + Vector3(0, spess + 0.004, 0)
	dinamici.add_child(carta)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(w_px, h_px) * SCALA
	mi.mesh = pm
	mi.material_override = _mat_tex(t)
	if id >= 0:
		carta.set_meta("carta", id)
		carta.set_meta("mezza", Vector2(w_px, h_px) * SCALA / 2.0)
	carta.add_child(mi)
	if retro != null:
		var mr := MeshInstance3D.new()
		var pr := PlaneMesh.new()
		pr.size = Vector2(w_px, h_px) * SCALA
		mr.mesh = pr
		mr.material_override = _mat_tex(retro)
		mr.rotation.z = PI
		mr.position.y = -0.003
		carta.add_child(mr)
	if anima:
		var a := carta.position
		var da := _a3d(da_px, a.y + 0.05)
		var gira := retro != null
		var dur := 1.0 * ritmo
		carta.position = da
		if gira:
			carta.rotation.z = PI
		var tw := carta.create_tween()
		if ritardo > 0.0:
			carta.visible = false
			tw.tween_interval(ritardo)
			tw.tween_callback(func(): carta.visible = true)
		tw.tween_method(func(x: float):
			carta.position = da.lerp(a, x) + Vector3(0, sin(x * PI) * 1.4, 0)
			if gira:
				carta.rotation.z = PI * (1.0 - x), 0.0, 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if n > 1:
		_scritta(str(n), pos + Vector3(w_px * SCALA * 0.35, spess + 0.3, h_px * SCALA * 0.38), 70, Color.WHITE)


var _nazgul_scena: PackedScene
var _scene_pg := {}
var _mat_pg: StandardMaterial3D
## Altezza delle miniature (unità del tavolo): gli hobbit più bassi, Éomer a cavallo più alto.
const ALTEZZA_PG := {"frodo": 1.1, "pipino": 1.1, "gollum": 0.85, "eomer": 1.8, "gimli": 1.2}


## Miniatura dipinta del personaggio (modello 3D con i colori nei vertici), su una basetta.
## Sta ferma come una miniatura vera: guarda verso il lato dei giocatori. null se il modello non c'è.
func _miniatura(chi: String, pos: Vector3, attivo: bool) -> Node3D:
	if not _scene_pg.has(chi):
		var path := "res://assets/modelli/pg_%s.glb" % chi
		_scene_pg[chi] = load(path) if ResourceLoader.exists(path) else null
	if _scene_pg[chi] == null:
		return null
	if _mat_pg == null:
		_mat_pg = StandardMaterial3D.new()
		_mat_pg.vertex_color_use_as_albedo = true
		_mat_pg.roughness = 0.55
		_mat_pg.rim_enabled = true
		_mat_pg.rim = 0.25
	var h: float = ALTEZZA_PG.get(chi.trim_suffix("_bianco"), 1.5) * (1.15 if attivo else 1.0)
	var p := Node3D.new()
	p.position = pos
	var n: Node3D = _scene_pg[chi].instantiate()
	n.scale = Vector3.ONE * h
	p.add_child(n)
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = _mat_pg
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# basetta; quella del personaggio attivo ha l'anello dorato
	var base := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.3 if chi not in ["frodo", "pipino", "eomer"] else 0.42
	cm.bottom_radius = cm.top_radius + 0.02
	cm.height = 0.05
	base.mesh = cm
	base.position.y = 0.025
	base.material_override = _colore(UI.ORO if attivo else Color(0.1, 0.08, 0.06))
	p.add_child(base)
	dinamici.add_child(p)
	return p
var _carte_prima := {}
var ritmo := 1.0
var _linea3d: Node3D


## Rotta di un'avanzata dell'Ombra: un nastro rosso luminoso sopra il tabellone ("" = toglila).
func evidenzia_linea(lid: String) -> void:
	if _linea3d != null and is_instance_valid(_linea3d):
		_linea3d.queue_free()
	_linea3d = null
	if lid == "" or sv == null:
		return
	_linea3d = Node3D.new()
	sv.add_child(_linea3d)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 0.15, 0.08, 0.75)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.render_priority = 5
	var p: Array = Dati.linea(lid)["percorso"]
	for k in p.size() - 1:
		var a := _luogo3d(p[k], 0.06)
		var b := _luogo3d(p[k + 1], 0.06)
		var seg := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.16, 0.02, a.distance_to(b))
		seg.mesh = bm
		seg.material_override = mat
		seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_linea3d.add_child(seg)
		seg.look_at_from_position((a + b) / 2.0, b, Vector3.UP)
	var tw := _linea3d.create_tween().set_loops()
	tw.tween_property(mat, "albedo_color:a", 0.35, 0.5)
	tw.tween_property(mat, "albedo_color:a", 0.8, 0.5)
var _scene_truppe := {}
var _mat_truppe := {}


## Truppa: il modello 3D del pezzo (sagoma in rilievo), del colore della sua armata, rivolto verso la camera.
func _truppa3d(a: String, pos: Vector3, h := 0.5) -> Node3D:
	if not _scene_truppe.has(a):
		var path := "res://assets/modelli/truppa_%s.glb" % a
		_scene_truppe[a] = load(path) if ResourceLoader.exists(path) else null
	if _scene_truppe[a] == null:
		return _pezzo(UI.pedina("truppa_" + a), pos, h, 0.07)
	if not _mat_truppe.has(a):
		var mt := StandardMaterial3D.new()
		mt.albedo_color = {"gondor": Color(0.25, 0.5, 0.85), "rohirrim": Color(0.55, 0.36, 0.2), "elfi": Color(0.3, 0.68, 0.3),
			"nani": Color(0.55, 0.55, 0.58), "ombra": Color(0.75, 0.1, 0.08)}[a]
		mt.roughness = 0.5
		mt.rim_enabled = true
		mt.rim = 0.35
		mt.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mat_truppe[a] = mt
	var p := Node3D.new()
	p.position = pos
	p.set_meta("sagoma", true)
	p.rotation.y = _rot.y
	var n: Node3D = _scene_truppe[a].instantiate()
	n.scale = Vector3.ONE * h
	p.add_child(n)
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = _mat_truppe[a]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	dinamici.add_child(p)
	return p


func _nazgul(pos: Vector3, rot: float, k := 0) -> Node3D:
	if _nazgul_scena == null and ResourceLoader.exists("res://assets/modelli/nazgul.glb"):
		_nazgul_scena = load("res://assets/modelli/nazgul.glb")
	if _nazgul_scena == null:
		push_warning("modello del Nazgûl non trovato")
		return _pezzo(UI.pedina("nazgul"), pos, 0.9, 0.08, Color(0.1, 0.1, 0.1), true)
	# il perno sta sulla regione (è lui che si sposta quando il Nazgûl cambia regione);
	# la bestia gli vola attorno in cerchio, in aria, fluttuando come l'Occhio
	var perno_n := Node3D.new()
	perno_n.position = pos
	perno_n.add_to_group("volteggia")
	perno_n.set_meta("raggio", 0.75 + (k % 3) * 0.4)
	perno_n.set_meta("quota", 1.5 + (k % 3) * 0.35 + (k / 3) * 0.3)
	perno_n.set_meta("fase", rot)
	perno_n.set_meta("vel", 0.45 + (k % 2) * 0.12)
	dinamici.add_child(perno_n)
	var n: Node3D = _nazgul_scena.instantiate()
	n.scale = Vector3.ONE * 0.75
	perno_n.add_child(n)
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = _mat_nazgul(k)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_volteggia(perno_n)
	return perno_n


## Posizione in volo di un Nazgûl attorno al suo perno: cerchio, su e giù, inclinato in virata.
func _volteggia(p: Node3D) -> void:
	if p.get_child_count() == 0:
		return
	var n: Node3D = p.get_child(0)
	var a: float = _t * float(p.get_meta("vel")) + float(p.get_meta("fase"))
	var r: float = p.get_meta("raggio")
	n.position = Vector3(cos(a) * r, float(p.get_meta("quota")) + sin(_t * 1.4 + float(p.get_meta("fase"))) * 0.18, sin(a) * r)
	# il muso del modello guarda verso -x: lo si gira lungo la tangente del cerchio
	n.rotation = Vector3(0, PI / 2.0 - a, 0.25)


var _mn: Array = []
var _mc: ShaderMaterial
var _mpozza: ShaderMaterial


func _mat_cono() -> ShaderMaterial:
	if _mc == null:
		_mc = ShaderMaterial.new()
		_mc.shader = load("res://assets/shader/cono_occhio.gdshader")
	return _mc


## Materiale della bestia alata: lo shader fa battere le ali, ognuna con la sua fase.
func _mat_nazgul(k: int) -> Material:
	if _mn.is_empty():
		var sh: Shader = load("res://assets/shader/nazgul.gdshader")
		for f in 5:
			var m := ShaderMaterial.new()
			m.shader = sh
			m.set_shader_parameter("fase", f * 1.3)
			m.set_shader_parameter("velocita", 3.0 + f * 0.25)
			_mn.append(m)
	return _mn[k % _mn.size()]


## Segna un pezzo per poterlo ritrovare all'aggiornamento successivo e farlo scorrere.
func _segna(n: Node3D, tipo: String, luogo := "") -> void:
	if n == null:
		return
	n.set_meta("tipo", tipo)
	n.set_meta("luogo", luogo)


## Fa volare un pezzo dalla posizione precedente a quella nuova, con un arco.
func _vola(n: Node3D, da: Vector3, arco: float) -> void:
	var a := n.position
	var d := da.distance_to(a)
	if d < 0.02:
		return
	var dur := clampf(0.5 + d * 0.1, 0.5, 2.2) * ritmo
	var h := arco * clampf(d / 3.0, 0.25, 1.0)
	n.position = da
	var tw := n.create_tween()
	tw.tween_method(func(t: float): n.position = da.lerp(a, t) + Vector3(0, sin(t * PI) * h, 0), 0.0, 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Un pezzo nuovo (senza provenienza) compare crescendo.
func _compari(n: Node3D) -> void:
	var sc := n.scale
	n.scale = sc * 0.01
	var tw := n.create_tween()
	tw.tween_property(n, "scale", sc, 0.45 * ritmo).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Confronta i pezzi di prima con quelli nuovi e anima gli spostamenti.
func _anima_spostamenti(vecchi: Dictionary) -> void:
	if vecchi.is_empty():
		return
	var nuovi := {}
	for c in dinamici.get_children():
		if c.is_queued_for_deletion() or not c.has_meta("tipo"):
			continue
		var tipo: String = c.get_meta("tipo")
		var l: String = c.get_meta("luogo")
		if not nuovi.has(tipo):
			nuovi[tipo] = {}
		if not nuovi[tipo].has(l):
			nuovi[tipo][l] = []
		nuovi[tipo][l].append(c)
	for tipo in nuovi:
		var prima: Dictionary = vecchi.get(tipo, {})
		var arco := 2.2 if tipo == "nazgul" else (0.6 if tipo.begins_with("truppa") else 1.0)
		# posizioni lasciate libere (pezzi andati via da un luogo)
		var liberi: Array = []
		for l in prima:
			var n_dopo: int = nuovi[tipo].get(l, []).size()
			for k in range(n_dopo, prima[l].size()):
				liberi.append(prima[l][k])
		for l in nuovi[tipo]:
			var lista: Array = nuovi[tipo][l]
			var vecchie: Array = prima.get(l, [])
			for k in lista.size():
				var n: Node3D = lista[k]
				if k < vecchie.size():
					_vola(n, vecchie[k], arco if l == "" else arco * 0.3)
				elif not liberi.is_empty():
					var best := 0
					for q in liberi.size():
						if liberi[q].distance_to(n.position) < liberi[best].distance_to(n.position):
							best = q
					_vola(n, liberi[best], arco)
					liberi.remove_at(best)
				elif not prima.is_empty() or tipo.begins_with("truppa"):
					_compari(n)


func aggiorna(m: Motore, anima := true) -> void:
	if dinamici == null:
		return
	var vecchi := {}
	for c in dinamici.get_children():
		if c.has_meta("tipo") and not c.is_queued_for_deletion():
			var tipo: String = c.get_meta("tipo")
			var l: String = c.get_meta("luogo")
			if not vecchi.has(tipo):
				vecchi[tipo] = {}
			if not vecchi[tipo].has(l):
				vecchi[tipo][l] = []
			vecchi[tipo][l].append(c.position)
		c.queue_free()
	occhio3d = null
	const MAPPA := preload("res://scripts/ui/mappa.gd")
	# minaccia e speranza sulle tracce
	_segna(_pezzo(UI.pedina("minaccia"), _a3d(MAPPA.pos_minaccia(m.minaccia)), 0.9, 0.12), "minaccia")
	_segna(_pezzo(UI.pedina("speranza"), _a3d(MAPPA.pos_speranza(m.speranza)), 0.9, 0.12), "speranza")
	# riserve delle razze
	for a in MAPPA.RISERVE:
		var n: int = m.riserva_truppe[a]
		for k in min(n, 6):
			_segna(_truppa3d(a, _a3d(MAPPA.RISERVE[a]) + Vector3(-0.4 + (k % 3) * 0.4, 0, -0.2 + (k / 3) * 0.4), 0.5), "truppa_" + a, "riserva")
		_scritta(str(n), _a3d(MAPPA.RISERVE[a], 0.9) + Vector3(0.75, 0, 0.1), 70)
	# mazzi: le carte nuove arrivano in volo (quelle dell'Ombra si girano uscendo dal mazzo)
	var prima: Dictionary = _carte_prima if anima else {}
	_carte_prima = {"risolte": m.risolte.duplicate(), "so_n": m.scarti_ombra.size(), "sg_n": m.scarti.size(),
		"sg_top": m.scarti.back() if not m.scarti.is_empty() else -1}
	if not m.mazzo_ombra.is_empty():
		var dorso: String = "dorso_" + Dati.carta(m.mazzo_ombra.back())["retro"]
		_carta3d(UI.tex("res://assets/carte/%s.webp" % dorso), MAPPA.OMBRA_PESCA, MAPPA.H_OMBRA, m.mazzo_ombra.size())
	var r0: Array = prima.get("risolte", m.risolte)
	var rit := 0.0
	for k in m.risolte.size():
		var id: int = m.risolte[k]
		var slot: Vector2 = MAPPA.OMBRA_RISOLVI + Vector2(k * 14, k * 22)
		if not prima.is_empty() and (k >= r0.size() or r0[k] != id):
			var retro := UI.tex("res://assets/carte/dorso_%s.webp" % Dati.carta(id).get("retro", "bandiera"))
			_carta3d(UI.carta_tex(id), slot, MAPPA.H_OMBRA, k + 1, id, MAPPA.OMBRA_PESCA, retro, rit)
			rit += 0.35 * ritmo
		else:
			_carta3d(UI.carta_tex(id), slot, MAPPA.H_OMBRA, k + 1, id)
	if not m.scarti_ombra.is_empty():
		var da := Vector2.INF
		if not prima.is_empty() and m.scarti_ombra.size() > int(prima["so_n"]):
			da = MAPPA.OMBRA_RISOLVI + Vector2(maxi(0, r0.size() - 1) * 14, maxi(0, r0.size() - 1) * 22)
		_carta3d(UI.carta_tex(m.scarti_ombra.back()), MAPPA.OMBRA_SCARTI, MAPPA.H_OMBRA, m.scarti_ombra.size(), m.scarti_ombra.back(), da)
	if not m.mazzo.is_empty():
		_carta3d(UI.tex("res://assets/carte/dorso_giocatori.webp"), MAPPA.GIOC_PESCA, MAPPA.H_GIOC, m.mazzo.size())
	if not m.scarti.is_empty():
		var da2 := Vector2.INF
		if not prima.is_empty() and m.scarti.size() > int(prima["sg_n"]) and m.scarti.back() != prima["sg_top"]:
			da2 = Vector2(MAPPA.W + 300, MAPPA.H * 0.55)
		_carta3d(UI.carta_tex(m.scarti.back()), MAPPA.GIOC_SCARTI, MAPPA.H_GIOC, m.scarti.size(), m.scarti.back(), da2)
	# rifugi conquistati e caduti
	for l in m.stato:
		var orig: String = Dati.luogo(l)["tipo"]
		var t: String = m.stato[l]["tipo"]
		if t == "rifugio" and orig != "rifugio":
			_pezzo(UI.pedina("rifugio"), _luogo3d(l, 0.01), 0.8, 0.08)
		elif t == "fortezza" and orig == "rifugio":
			_pezzo(UI.pedina("fortezza"), _luogo3d(l, 0.01), 0.85, 0.08)
		# truppe amiche a sinistra in pile per razza, Ombra a destra in pila
		var k_am := 0
		for a in Dati.ARMATE:
			for j in m.stato[l]["truppe"][a]:
				_segna(_truppa3d(a, _luogo3d(l) + Vector3(-0.75 + (k_am % 4) * 0.3, 0, 0.45 + (k_am / 4) * 0.32), 0.6), "truppa_" + a, l)
				k_am += 1
		var no: int = m.stato[l]["ombra"]
		for k in min(no, 9):
			_segna(_truppa3d("ombra", _luogo3d(l) + Vector3(0.45 + (k % 3) * 0.3, 0, -0.55 + (k / 3) * 0.3), 0.58), "truppa_ombra", l)
		if no > 3:
			_scritta(str(no), _luogo3d(l, 0.9) + Vector3(0.9, 0, -0.45), 70, Color(1, 0.45, 0.35))
	# personaggi in piedi
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
			var chi: String = "gandalf_bianco" if p == "gandalf" and m.pg[p]["bianco"] else p
			var pos := _luogo3d(l) + Vector3((k - (lista.size() - 1) / 2.0) * 0.75, 0, -0.1)
			var mini := _miniatura(chi, pos, p == m.attivo)
			if mini == null:
				mini = _pezzo(UI.pedina(chi), pos, 1.45 if p != m.attivo else 1.75, 0.09, Color(0.1, 0.08, 0.06), true)
			_segna(mini, "pg_" + p)
	# Nazgûl: il modello 3D sulle regioni
	for r in m.nazgul:
		var n: int = m.nazgul[r]
		var rr: Dictionary = Dati.d()["regioni"][r]
		for k in n:
			var pos := _a3d(Vector2(rr["x"], rr["y"]))
			_segna(_nazgul(pos, TAU * k / float(n) + k * 0.4, k), "nazgul", r)
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
	luce.light_energy = 1.2
	luce.omni_range = 5.0
	occhio3d.add_child(luce)
	# cono di luce soffusa verso la mappa
	var cono := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.12
	cm.bottom_radius = 2.1
	cm.height = 3.1
	cm.radial_segments = 32
	cm.rings = 1
	cm.cap_top = false
	cm.cap_bottom = false
	cono.mesh = cm
	cono.position.y = -1.65
	cono.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cono.material_override = _mat_cono()
	occhio3d.add_child(cono)
	var faro := SpotLight3D.new()
	faro.light_color = Color(1, 0.55, 0.2)
	faro.light_energy = 4.5
	faro.spot_range = 6.0
	faro.spot_angle = 30.0
	faro.spot_angle_attenuation = 1.5
	faro.rotation.x = -PI / 2
	occhio3d.add_child(faro)
	dinamici.add_child(occhio3d)
	# chiazza di luce sul tabellone, dove arriva il cono
	var pozza := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(4.6, 4.6)
	pozza.mesh = pm
	pozza.position = _a3d(Vector2(ro["x"], ro["y"]), 0.03)
	pozza.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _mpozza == null:
		_mpozza = ShaderMaterial.new()
		_mpozza.shader = load("res://assets/shader/pozza_occhio.gdshader")
	pozza.material_override = _mpozza
	dinamici.add_child(pozza)
	_segna(pozza, "occhio_luce")
	_segna(occhio3d, "occhio")
	if anima:
		_anima_spostamenti(vecchi)
	_aggiorna_camera()
