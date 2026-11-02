extends Control
## Vista della partita: mappa al centro, a sinistra speranza, minaccia, obiettivi e mazzi; a destra i giocatori
## con mani e segnalini; in basso le scelte e il registro.

signal scelta_fatta(indice: int)

var main
var config: Dictionary = {}
var motore: Motore
var ia := IA.new()
var locale := ControlloLocale.new()
var online: SessioneOnline = null

var mappa
var centro: Control
var tavolo3d = null
var vista3d := false
var box_speranza: HBoxContainer
var lbl_turno: Label
var box_minaccia: HBoxContainer
var col_sx: VBoxContainer
var col_dx: VBoxContainer
var scelta_titolo: Label
var scelta_testo: Label
var scelta_opzioni: HFlowContainer
var scelta_carte: HBoxContainer
var registro: RichTextLabel
var zoom: PanelContainer
var zoom_img: TextureRect
var zoom_testo: Label
var overlay_dadi: Control
var stato_online: Label
var box_info: HBoxContainer
var b3d: Button

var _richiesta := {}
var _in_attesa := false
var _da_aggiornare := false
var _ripresa := false
var _linea_id := 0
## Velocità della fase dell'Ombra e delle animazioni: nome, pausa del motore, durata animazioni.
const RITMI := [["Lento", 1.8, 1.7], ["Normale", 1.0, 1.0], ["Veloce", 0.45, 0.6], ["Istantaneo", 0.0, 0.35]]
var _ritmo := 1
var b_ritmo: Button
const SALVATAGGIO := "user://partita_in_corso.json"
const LARGHEZZA_SX := 400
const LARGHEZZA_DX := 400


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	locale.vista = self
	_costruisci()
	motore = Motore.new()
	add_child(motore)
	motore.cambiato.connect(_segna_aggiornamento)
	motore.messaggio.connect(_al_messaggio)
	motore.evento.connect(_al_evento)
	motore.finita.connect(_alla_fine)
	ia.pausa = float(config.get("ritardo_ia", 0.6))
	online = config.get("online", null)
	var gg: Array = config.get("giocatori", [])
	if online != null:
		add_child(online)
		online.view = self
		online.locale = locale
		for i in gg.size():
			motore.controllori.append(online)
	else:
		var cia := ControlloIA.new()
		cia.vista = self
		cia.ia = ia
		for g in gg:
			motore.controllori.append(cia if g.get("ia", false) else locale)
		motore.da_rigiocare = config.get("storia", []).duplicate()
		motore.scelta_registrata.connect(_salva)
		if not motore.da_rigiocare.is_empty():
			_ripresa = true
			motore.ripresa_finita.connect(func(): _ripresa = false; _segna_aggiornamento())
	var cfg := config.duplicate()
	cfg.erase("online")
	motore.prepara(cfg)
	mappa.motore = motore
	var cf := ConfigFile.new()
	if cf.load("user://impostazioni.cfg") == OK:
		_ritmo = clampi(int(cf.get_value("vista", "ritmo", 1)), 0, RITMI.size() - 1)
	if config.has("ritmo"):
		_ritmo = int(config["ritmo"])
	_applica_ritmo()
	_aggiorna()
	if config.get("vista3d", false):
		_imposta_3d(true)
	if online != null:
		online.battito()
	motore.gioca()


# =====================================================================================
# COSTRUZIONE
# =====================================================================================

func _costruisci() -> void:
	var sfondo := ColorRect.new()
	sfondo.color = Color(0.07, 0.055, 0.04)
	sfondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(sfondo)
	var radice := HBoxContainer.new()
	radice.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	radice.add_theme_constant_override("separation", 0)
	add_child(radice)
	# ---- colonna sinistra: stato della Terra di Mezzo
	var ps := UI.pannello(Color(0.10, 0.08, 0.06, 0.97))
	ps.custom_minimum_size.x = LARGHEZZA_SX
	radice.add_child(ps)
	var scs := ScrollContainer.new()
	scs.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ps.add_child(scs)
	scs.resized.connect(_segna_aggiornamento)
	col_sx = VBoxContainer.new()
	col_sx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_sx.add_theme_constant_override("separation", 8)
	scs.add_child(col_sx)
	# ---- centro: barra, mappa, scelte
	var vc := VBoxContainer.new()
	vc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vc.add_theme_constant_override("separation", 0)
	radice.add_child(vc)
	var barra := UI.pannello(Color(0.10, 0.08, 0.06, 0.97))
	vc.add_child(barra)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	barra.add_child(hb)
	lbl_turno = UI.titolo("", 21, UI.ORO)
	lbl_turno.clip_text = true
	lbl_turno.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lbl_turno.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_turno.mouse_filter = Control.MOUSE_FILTER_PASS
	hb.add_child(lbl_turno)
	box_info = HBoxContainer.new()
	box_info.add_theme_constant_override("separation", 9)
	hb.add_child(box_info)
	stato_online = UI.etichetta("", 18, UI.ORO)
	hb.add_child(stato_online)
	b_ritmo = UI.bottone("", 15)
	b_ritmo.tooltip_text = "Velocità delle animazioni e della fase dell'Ombra (clic per cambiarla)."
	b_ritmo.pressed.connect(func():
		_ritmo = (_ritmo + 1) % RITMI.size()
		_applica_ritmo())
	hb.add_child(b_ritmo)
	b3d = UI.bottone("Tavolo 3D", 15)
	b3d.toggle_mode = true
	b3d.toggled.connect(_imposta_3d)
	hb.add_child(b3d)
	var bc := UI.bottone("Centra", 15)
	bc.pressed.connect(func():
		mappa._adatta()
		if tavolo3d != null:
			tavolo3d.reimposta_vista())
	hb.add_child(bc)
	var br := UI.bottone("Regole", 15)
	br.pressed.connect(_mostra_regole)
	hb.add_child(br)
	var bm := UI.bottone("Menu", 15)
	bm.pressed.connect(_torna_menu)
	hb.add_child(bm)
	centro = Control.new()
	centro.size_flags_vertical = Control.SIZE_EXPAND_FILL
	centro.clip_contents = true
	vc.add_child(centro)
	mappa = preload("res://scripts/ui/mappa.gd").new()
	mappa.vista = self
	mappa.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mappa.luogo_cliccato.connect(_clic_luogo)
	centro.add_child(mappa)
	# pannello delle scelte
	var pc := UI.pannello(Color(0.11, 0.085, 0.06, 0.98), UI.ORO_SCURO)
	pc.custom_minimum_size.y = 250
	vc.add_child(pc)
	var hc := HBoxContainer.new()
	hc.add_theme_constant_override("separation", 12)
	pc.add_child(hc)
	var vs := VBoxContainer.new()
	vs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vs.add_theme_constant_override("separation", 4)
	hc.add_child(vs)
	scelta_titolo = UI.titolo("", 22, UI.ORO)
	vs.add_child(scelta_titolo)
	scelta_testo = UI.testo_lungo("", 18, UI.PERGAMENA)
	vs.add_child(scelta_testo)
	scelta_carte = HBoxContainer.new()
	scelta_carte.add_theme_constant_override("separation", 6)
	vs.add_child(scelta_carte)
	var so := ScrollContainer.new()
	so.size_flags_vertical = Control.SIZE_EXPAND_FILL
	so.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vs.add_child(so)
	scelta_opzioni = HFlowContainer.new()
	scelta_opzioni.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scelta_opzioni.add_theme_constant_override("h_separation", 6)
	scelta_opzioni.add_theme_constant_override("v_separation", 6)
	so.add_child(scelta_opzioni)
	registro = RichTextLabel.new()
	registro.custom_minimum_size.x = 430
	registro.scroll_following = true
	registro.add_theme_font_size_override("normal_font_size", 16)
	registro.add_theme_color_override("default_color", UI.CENERE)
	hc.add_child(registro)
	# ---- colonna destra: giocatori
	var pd := UI.pannello(Color(0.10, 0.08, 0.06, 0.97))
	pd.custom_minimum_size.x = LARGHEZZA_DX
	radice.add_child(pd)
	var scd := ScrollContainer.new()
	scd.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pd.add_child(scd)
	scd.resized.connect(_segna_aggiornamento)
	col_dx = VBoxContainer.new()
	col_dx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_dx.add_theme_constant_override("separation", 10)
	scd.add_child(col_dx)
	# ---- ingrandimento delle carte
	zoom = UI.pannello(Color(0.08, 0.06, 0.04, 0.97), UI.ORO)
	zoom.visible = false
	zoom.z_index = 50
	zoom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(zoom)
	var vz := VBoxContainer.new()
	zoom.add_child(vz)
	zoom_img = UI.immagine(null, 420, 600)
	vz.add_child(zoom_img)
	zoom_testo = UI.testo_lungo("", 17, UI.PERGAMENA)
	zoom_testo.custom_minimum_size.x = 420
	vz.add_child(zoom_testo)
	overlay_dadi = Control.new()
	overlay_dadi.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	overlay_dadi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_dadi.z_index = 40
	add_child(overlay_dadi)


# =====================================================================================
# AGGIORNAMENTO
# =====================================================================================

func _applica_ritmo() -> void:
	var r: Array = RITMI[_ritmo]
	b_ritmo.text = "Ritmo: %s" % r[0]
	if motore != null:
		motore.ritmo = r[1]
	mappa.ritmo = r[2]
	if tavolo3d != null:
		tavolo3d.ritmo = r[2]
	var cf := ConfigFile.new()
	cf.load("user://impostazioni.cfg")
	cf.set_value("vista", "ritmo", _ritmo)
	cf.save("user://impostazioni.cfg")


func _salva() -> void:
	var cfg := config.duplicate()
	cfg.erase("online")
	cfg.erase("storia")
	cfg["seme"] = motore.seme
	var f := FileAccess.open(SALVATAGGIO, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"config": cfg, "storia": motore.storia}))
		f.close()


static func salvataggio() -> Dictionary:
	if not FileAccess.file_exists(SALVATAGGIO):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(SALVATAGGIO))
	return d if d is Dictionary and d.has("config") else {}


static func cancella_salvataggio() -> void:
	if FileAccess.file_exists(SALVATAGGIO):
		DirAccess.remove_absolute(SALVATAGGIO)


func _segna_aggiornamento() -> void:
	if _ripresa:
		return
	if not _da_aggiornare:
		_da_aggiornare = true
		call_deferred("_aggiorna")


func _aggiorna() -> void:
	_da_aggiornare = false
	if motore == null or motore.giocatori.is_empty():
		return
	var g: Dictionary = motore.giocatori[motore.turno_di]
	var fasi := {"azioni": "azioni", "pesca": "pesca", "ombra": "carte dell'Ombra", "fine": "fine"}
	lbl_turno.text = "Turno %d — %s — %s" % [max(1, motore.turno), g["nome"], fasi.get(motore.fase, "")]
	lbl_turno.tooltip_text = lbl_turno.text
	_aggiorna_info()
	_aggiorna_sx()
	_aggiorna_dx()
	mappa.registra()
	mappa.queue_redraw()
	if tavolo3d != null and vista3d:
		tavolo3d.aggiorna(motore)


func _svuota(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()


func _sezione(dove: VBoxContainer, titolo: String) -> void:
	var l := UI.titolo(titolo, 19, UI.ORO)
	dove.add_child(l)


func _aggiorna_sx() -> void:
	_svuota(col_sx)
	_sezione(col_sx, "Obiettivi")
	var griglia := GridContainer.new()
	griglia.columns = 2
	griglia.add_theme_constant_override("h_separation", 6)
	griglia.add_theme_constant_override("v_separation", 6)
	col_sx.add_child(griglia)
	var w_col: float = LARGHEZZA_SX - 30.0
	var w: float = floorf((w_col - 6) / 2.0)
	# se le righe non stanno in altezza, le carte si rimpiccioliscono
	var righe: int = int(ceil(motore.obiettivi.size() / 2.0))
	var h_disp: float = (col_sx.get_parent().size.y if col_sx.get_parent().size.y > 100 else 900.0) - 40
	var h: float = minf(w * 1.51, (h_disp - righe * 32) / max(1, righe))
	w = h / 1.51
	for o in motore.obiettivi:
		var ob := Dati.obiettivo(o["codice"])
		var cella := VBoxContainer.new()
		cella.add_theme_constant_override("separation", 0)
		var t := _carta_ui(int(ob["id"]), w, h)
		if o["fatto"]:
			t.modulate = Color(0.5, 0.5, 0.46, 0.9)
			var fatto := UI.titolo("Completato", 20, UI.VERDE)
			fatto.position = Vector2(w * 0.08, h * 0.42)
			fatto.rotation = -0.35
			t.add_child(fatto)
		var extra := ""
		if motore.su_carta.has(o["codice"]) and int(motore.su_carta[o["codice"]]) > 0:
			extra = "Sulla carta: %d" % int(motore.su_carta[o["codice"]])
		if o["codice"] == "hobbit" and not motore.hobbit.is_empty():
			extra = "Simboli coperti: %d/2" % motore.hobbit.size()
		if o["codice"] == "eowyn" and motore.nazgul_eowyn > 0:
			extra = "Nazgûl distrutti: %d/2" % motore.nazgul_eowyn
		cella.add_child(t)
		var le := UI.etichetta(extra, 14, UI.ORO, true)
		le.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		le.custom_minimum_size.x = w
		cella.add_child(le)
		griglia.add_child(cella)


func _aggiorna_info() -> void:
	_svuota(box_info)
	var n := motore.dadi_ricerca()
	var l := UI.etichetta("Occhio: %s" % Dati.nome_regione(motore.occhio), 16, Color(1, 0.6, 0.3))
	l.tooltip_text = "L'Occhio di Sauron è su questa regione."
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	box_info.add_child(l)
	if motore.in_gioco("frodo"):
		var lr := UI.etichetta("Ricerca: %d dad%s" % [n, "o" if n == 1 else "i"], 16, UI.PERGAMENA)
		lr.tooltip_text = "Dadi che l'Ombra tira per cercare Frodo."
		lr.mouse_filter = Control.MOUSE_FILTER_PASS
		box_info.add_child(lr)
	box_info.add_child(UI.contatore(UI.pedina("truppa_ombra"), motore.riserva_ombra, 16, "Truppe ombra nella riserva"))
	for s in Dati.SIMBOLI:
		box_info.add_child(UI.contatore(UI.pedina(s), motore.riserva_simboli[s], 16, "Segnalini %s nella riserva" % Dati.NOMI_SIMBOLI[s]))


var _scheda := 0            # giocatore mostrato nella colonna destra (versione a schede)
var _turno_visto := -1


## Personaggi mostrati per il giocatore i (nel solitario Frodo e Sam più i quattro compagni).
func _pg_di(i: int) -> Array:
	if motore.solo:
		return ["frodo"] + motore._ordine_solo()
	return motore.giocatori[i]["pg"]


func _aggiorna_dx() -> void:
	_svuota(col_dx)
	var n_g: int = motore.giocatori.size()
	var w_col: float = LARGHEZZA_DX - 36.0
	var h_col: float = col_dx.get_parent().size.y if col_dx.get_parent().size.y > 100 else 1000.0
	# altezza delle carte personaggio se tutti i giocatori stanno nella colonna
	var n_pg := 0
	var extra := 0.0
	for i in n_g:
		n_pg += _pg_di(i).size()
		extra += 150.0 + ceil(motore.giocatori[i]["mano"].size() / 6.0) * 79.0
	var h_tutti: float = (h_col - extra - n_g * 10) / max(1, n_pg) - 6
	var schede := n_g > 1 and h_tutti < 120.0
	if not schede:
		for i in n_g:
			col_dx.add_child(_area_giocatore(i, h_tutti, w_col))
		return
	# versione a schede: una per giocatore, si apre da sola quando tocca a lui
	if motore.turno_di != _turno_visto:
		_turno_visto = motore.turno_di
		_scheda = motore.turno_di
	_scheda = clampi(_scheda, 0, n_g - 1)
	var barra := HBoxContainer.new()
	barra.add_theme_constant_override("separation", 3)
	col_dx.add_child(barra)
	for i in n_g:
		var g: Dictionary = motore.giocatori[i]
		var b := UI.bottone(g["nome"], 15)
		b.toggle_mode = true
		b.button_pressed = i == _scheda
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		if i == motore.turno_di:
			b.add_theme_color_override("font_color", UI.ORO)
			b.add_theme_color_override("font_pressed_color", UI.ORO)
		b.tooltip_text = g["nome"] + (" (di turno)" if i == motore.turno_di else "")
		b.pressed.connect(func():
			_scheda = i
			_aggiorna_dx())
		barra.add_child(b)
	var g2: Dictionary = motore.giocatori[_scheda]
	var h_uno: float = (h_col - 45 - 150.0 - ceil(g2["mano"].size() / 6.0) * 79.0) / max(1, _pg_di(_scheda).size()) - 6
	col_dx.add_child(_area_giocatore(_scheda, h_uno, w_col))


func _area_giocatore(i: int, h_carta: float, w_col: float) -> Control:
	var g: Dictionary = motore.giocatori[i]
	var mio := i == motore.turno_di
	var p := UI.pannello(Color(0.16, 0.12, 0.08, 0.95) if mio else Color(0.12, 0.10, 0.07, 0.9), UI.ORO if mio else UI.ORO_SCURO)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	p.add_child(v)
	v.add_child(UI.titolo(g["nome"] + (" (IA)" if g["ia"] else ""), 20, UI.ORO if mio else UI.PERGAMENA))
	# personaggi, uno sopra l'altro
	var lista: Array = _pg_di(i)
	var w_max: float = w_col - 24
	var hc: float = clampf(h_carta, 60.0, w_max / 1.5)
	var wc: float = hc * 1.5
	for k in lista.size():
		var pid: String = lista[k]
		if not motore.pg.has(pid):
			continue
		var pc := Dati.personaggio(pid)
		var carta := int(pc["carta"])
		if pid == "gandalf" and motore.pg[pid]["bianco"]:
			carta = 4500
		var cornice := PanelContainer.new()
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0, 0, 0, 0)
		st.set_border_width_all(3)
		st.border_color = UI.ORO if pid == motore.attivo else Color(0, 0, 0, 0)
		st.set_corner_radius_all(6)
		cornice.add_theme_stylebox_override("panel", st)
		cornice.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var t := _carta_ui(carta, wc, hc, true)
		if motore.pg[pid]["fuori"]:
			t.modulate = Color(0.4, 0.4, 0.4, 0.7)
		cornice.add_child(t)
		if motore.solo and k > 0 and k - 1 == motore.solo_indice % motore._ordine_solo().size():
			var seg := UI.etichetta("4 azioni", 15, UI.ORO, true)
			seg.add_theme_color_override("font_outline_color", Color.BLACK)
			seg.add_theme_constant_override("outline_size", 6)
			seg.position = Vector2(wc - 72, 4)
			seg.tooltip_text = "Ha il segnalino del solitario: fa 4 azioni in questo turno."
			seg.mouse_filter = Control.MOUSE_FILTER_PASS
			t.add_child(seg)
		v.add_child(cornice)
	# segnalini
	var hs := HBoxContainer.new()
	hs.add_theme_constant_override("separation", 10)
	v.add_child(hs)
	for s in Dati.SIMBOLI:
		var c := UI.contatore(UI.pedina(s), g["gettoni"][s], 18, "Segnalini %s (in tutto, con le carte: %d)" % [Dati.NOMI_SIMBOLI[s], motore.disponibili(i, s)])
		if g["gettoni"][s] == 0:
			c.modulate = Color(1, 1, 1, 0.45)
		hs.add_child(c)
	# mano
	var hm := HFlowContainer.new()
	hm.add_theme_constant_override("h_separation", 3)
	hm.add_theme_constant_override("v_separation", 3)
	v.add_child(hm)
	for id in g["mano"]:
		hm.add_child(_carta_ui(id, 52, 76))
	v.add_child(UI.etichetta("%d carte in mano (massimo 7)" % g["mano"].size(), 14, UI.CENERE))
	return p


func _carta_ui(id: int, w: float, h: float, orizzontale := false) -> TextureRect:
	var t := UI.immagine(UI.carta_tex(id), w, h)
	t.mouse_filter = Control.MOUSE_FILTER_PASS
	t.mouse_entered.connect(_mostra_zoom.bind(id, t))
	t.mouse_exited.connect(_nascondi_zoom)
	return t


func _dorso_ui(nome: String, w: float, h: float, tip: String, n: int) -> Control:
	var t := UI.immagine(UI.tex("res://assets/carte/%s.webp" % nome), w, h)
	t.mouse_filter = Control.MOUSE_FILTER_PASS
	t.tooltip_text = tip
	var l := UI.etichetta(str(n), 18, Color.WHITE, true)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	l.position = Vector2(4, h - 28)
	t.add_child(l)
	return t


func _mostra_zoom(id: int, sorgente: Control) -> void:
	_mostra_zoom_rect(id, sorgente.get_global_rect())


func _mostra_zoom_a(id: int, pos: Vector2) -> void:
	_mostra_zoom_rect(id, Rect2(pos, Vector2(24, 24)))


## Ingrandimento della carta (solo l'immagine: le carte sono già in italiano).
func _mostra_zoom_rect(id: int, r: Rect2) -> void:
	var c := Dati.carta(id)
	var tx := UI.carta_tex(id)
	if tx == null:
		return
	var orizz := tx.get_width() > tx.get_height()
	zoom_img.custom_minimum_size = Vector2(620, 410) if orizz else Vector2(380, 560)
	zoom_img.texture = tx
	zoom_testo.visible = false
	if c.get("tipo", "") == "ombra" and not c.has("speciale"):
		mappa.evidenzia({c["rinforzo"]: Color(0.9, 0.1, 0.1)}, c["linea"])
	elif c.get("tipo", "") == "regione":
		var luoghi := {}
		for l in Dati.d()["regioni"][c["regione"]]["luoghi"]:
			luoghi[l] = Color(1, 0.85, 0.3)
		mappa.evidenzia(luoghi)
	zoom.visible = true
	zoom.reset_size()
	var pos := r.position + Vector2(r.size.x + 12, 0)
	if pos.x + zoom.size.x > size.x:
		pos.x = r.position.x - zoom.size.x - 12
	pos.y = clampf(pos.y - zoom.size.y / 3.0, 8, size.y - zoom.size.y - 8)
	zoom.position = pos


func _nascondi_zoom() -> void:
	zoom.visible = false
	if mappa != null:
		_evidenzia_richiesta()


# =====================================================================================
# DECISIONI DELLA PERSONA
# =====================================================================================

func chiedi_persona(_m: Motore, posto: int, req: Dictionary) -> int:
	_richiesta = req
	_in_attesa = true
	_mostra_richiesta(posto, req)
	_aggiorna()
	var r: int = await scelta_fatta
	_in_attesa = false
	_richiesta = {}
	_svuota(scelta_opzioni)
	_svuota(scelta_carte)
	mappa.evidenzia({})
	scelta_titolo.text = ""
	scelta_testo.text = ""
	return r


func _mostra_richiesta(posto: int, req: Dictionary) -> void:
	var nome: String = motore.giocatori[posto]["nome"]
	scelta_titolo.text = req.get("titolo", "")
	var persone := 0
	for g in motore.giocatori:
		if not g["ia"]:
			persone += 1
	scelta_testo.text = (("Tocca a %s. " % nome) if persone > 1 else "") + req.get("testo", "")
	_svuota(scelta_opzioni)
	_svuota(scelta_carte)
	for c in req.get("carte", []):
		scelta_carte.add_child(_carta_ui(int(c), 58, 86))
	if req.has("facce"):
		for f in req["facce"]:
			scelta_carte.add_child(_faccia(f, 54))
	var opz: Array = req.get("opzioni", [])
	for k in opz.size():
		var b := UI.bottone(("%d. " % (k + 1) if k < 9 else "") + opz[k]["testo"], 17)
		var ch: String = opz[k].get("chiave", "")
		if ch == "fine" or ch == "ok" or ch == "parti":
			b.add_theme_color_override("font_color", UI.ORO)
		if ch == "ob_anello":
			b.add_theme_color_override("font_color", Color(1, 0.5, 0.2))
		b.pressed.connect(_premi.bind(k))
		if opz[k].has("luogo") and Dati.luoghi().has(opz[k]["luogo"]):
			var l: String = opz[k]["luogo"]
			b.mouse_entered.connect(func(): mappa.evidenzia({l: Color(1, 1, 1)}))
			b.mouse_exited.connect(_evidenzia_richiesta)
		if opz[k].has("carta"):
			var id := int(opz[k]["carta"])
			b.mouse_entered.connect(_mostra_zoom.bind(id, b))
			b.mouse_exited.connect(_nascondi_zoom)
		scelta_opzioni.add_child(b)
	_evidenzia_richiesta()


func _evidenzia_richiesta() -> void:
	var ev := {}
	for o in _richiesta.get("opzioni", []):
		if o.has("luogo") and Dati.luoghi().has(o["luogo"]):
			var col := Color(0.4, 1, 0.4)
			match o.get("chiave", ""):
				"attacca", "conquista":
					col = Color(1, 0.35, 0.25)
				"viaggio":
					col = Color(1, 0.85, 0.3) if o.get("costo", {}).is_empty() else Color(0.6, 0.8, 1)
			ev[o["luogo"]] = col
	mappa.evidenzia(ev)


func _clic_luogo(l: String) -> void:
	if not _in_attesa:
		return
	var opz: Array = _richiesta.get("opzioni", [])
	for k in opz.size():
		if opz[k].get("luogo", "") == l and opz[k].get("chiave", "viaggio") in ["viaggio", "", "luogo"]:
			_premi(k)
			return
	for k in opz.size():
		if opz[k].get("luogo", "") == l:
			_premi(k)
			return


## Mentre un compagno IA decide, il pannello lo dice.
func mostra_pensiero(posto: int, req: Dictionary) -> void:
	if _in_attesa:
		return
	scelta_titolo.text = "%s ci pensa…" % motore.giocatori[posto]["nome"]
	scelta_testo.text = String(req.get("titolo", ""))
	_svuota(scelta_opzioni)
	_svuota(scelta_carte)
	if req.has("facce"):
		for f in req["facce"]:
			scelta_carte.add_child(_faccia(f, 54))


func _unhandled_key_input(ev: InputEvent) -> void:
	if not _in_attesa or not (ev is InputEventKey) or not ev.pressed or ev.echo:
		return
	var n: int = ev.keycode - KEY_1
	if n >= 0 and n < 9 and n < _richiesta.get("opzioni", []).size():
		_premi(n)
		get_viewport().set_input_as_handled()


func _premi(k: int) -> void:
	if not _in_attesa:
		return
	_nascondi_zoom()
	scelta_fatta.emit(k)


# =====================================================================================
# EVENTI DEL MOTORE
# =====================================================================================

## Nota dell'IA sulle scelte importanti (in grigio, nel registro).
func nota_ia(t: String) -> void:
	if registro != null and not _ripresa:
		registro.append_text("\n[color=#8f8a7c][i]IA: %s[/i][/color]" % t)


func _al_messaggio(t: String) -> void:
	if registro == null:
		return
	if t.begins_with("—"):
		registro.append_text("\n[color=#dcb05c][b]%s[/b][/color]" % t)
	elif t.begins_with("OBIETTIVO") or t.begins_with("IL CIELO") or t.begins_with("AVANZATA") or t.begins_with("RINFORZO"):
		registro.append_text("\n[b]%s[/b]" % t)
	else:
		registro.append_text("\n" + t)


func _al_evento(tipo: String, dati: Dictionary) -> void:
	if _ripresa:
		return
	match tipo:
		"dadi":
			if not vista3d:
				_mostra_dadi(dati)
		"viaggio":
			mappa.anima_viaggio(dati["pg"], dati["da"])
		"rifugio_caduto":
			mappa.lampo(dati["luogo"], UI.ROSSO)
			_lampo(UI.ROSSO_SCURO)
		"conquista":
			mappa.lampo(dati["luogo"], UI.ORO)
		"cieli":
			_lampo(Color(0.05, 0.02, 0.08))
		"obiettivo":
			_lampo(UI.ORO)
		"linea":
			# la rotta dell'avanzata resta evidenziata finché le truppe non hanno finito di muoversi
			mappa.evidenzia({}, dati["linea"])
			_linea_id += 1
			var mio := _linea_id
			get_tree().create_timer(4.0 * maxf(0.5, motore.ritmo)).timeout.connect(func():
				if mappa != null and mio == _linea_id:
					mappa.evidenzia({})
					if tavolo3d != null:
						tavolo3d.evidenzia_linea(""))
		"ombra":
			_segna_aggiornamento()
	if tavolo3d != null and vista3d:
		tavolo3d.evento(tipo, dati)
		if tipo == "linea":
			tavolo3d.evidenzia_linea(dati["linea"])


func _lampo(col: Color) -> void:
	var r := ColorRect.new()
	r.color = Color(col.r, col.g, col.b, 0.0)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.z_index = 30
	add_child(r)
	var tw := create_tween()
	tw.tween_property(r, "color:a", 0.35, 0.15)
	tw.tween_property(r, "color:a", 0.0, 0.6)
	tw.tween_callback(r.queue_free)


func _faccia(f: String, s: float) -> Control:
	var p := PanelContainer.new()
	var st := StyleBoxFlat.new()
	var ricerca := f in ["sfuggito", "stanchezza", "scoperto", "richiamo"]
	st.bg_color = Color(0.08, 0.08, 0.08) if ricerca else Color(0.95, 0.93, 0.88)
	st.set_corner_radius_all(int(s * 0.18))
	st.border_color = UI.ORO_SCURO
	st.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", st)
	p.custom_minimum_size = Vector2(s, s)
	p.tooltip_text = Dati.NOMI_FACCE[f]
	if f != "sfuggito":
		p.add_child(UI.immagine(UI.pedina("d_" + f), s - 6, s - 6))
	return p


func _mostra_dadi(dati: Dictionary) -> void:
	_svuota(overlay_dadi)
	var facce: Array = dati["facce"]
	var p := UI.pannello(Color(0.08, 0.06, 0.04, 0.95), UI.ORO)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_dadi.add_child(p)
	var v := VBoxContainer.new()
	p.add_child(v)
	var t := UI.titolo(("Tiro di ricerca" if dati["tipo"] == "ricerca" else "Combattimento") + " a " + Dati.nome(dati.get("luogo", "the_shire")), 26, UI.ORO)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 12)
	v.add_child(h)
	for f in facce:
		var d := _faccia(f, 84)
		d.pivot_offset = Vector2(42, 42)
		if not dati.get("modifica", false):
			d.rotation = randf_range(-2.5, 2.5)
			var tw := create_tween()
			tw.tween_property(d, "rotation", randf_range(-0.12, 0.12), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		h.add_child(d)
	var l := UI.etichetta(motore._testo_facce(facce), 18, UI.PERGAMENA)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	p.position = Vector2(-p.get_combined_minimum_size().x / 2, -260)
	p.modulate.a = 0.0
	var tw2 := create_tween()
	tw2.tween_property(p, "modulate:a", 1.0, 0.15)
	tw2.tween_interval(1.8)
	tw2.tween_property(p, "modulate:a", 0.0, 0.4)
	tw2.tween_callback(p.queue_free)


func _alla_fine(esito: String) -> void:
	if online != null:
		online.chiudi()
	else:
		cancella_salvataggio()
	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.65)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.z_index = 60
	add_child(fondo)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.add_child(cc)
	var p := UI.pannello(Color(0.10, 0.08, 0.05, 0.98), UI.ORO)
	cc.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(v)
	var vinto := esito == "vittoria"
	var t := Label.new()
	t.text = "L'Anello è distrutto!" if vinto else "L'Ombra ha vinto"
	t.add_theme_font_override("font", UI.font_decorato)
	t.add_theme_font_size_override("font_size", 60)
	t.add_theme_color_override("font_color", UI.ORO if vinto else UI.ROSSO)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var testo := "Sauron è sconfitto e la Terra di Mezzo è salva." if vinto else "Frodo ha perso ogni speranza."
	testo += "\nTurni giocati: %d. Obiettivi completati: %d su %d. Speranza rimasta: %d." % [motore.turno, motore.obiettivi_fatti(), motore.obiettivi.size(), motore.speranza]
	var lt := UI.etichetta(testo, 22, UI.PERGAMENA)
	lt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(lt)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 16)
	v.add_child(hb)
	var b1 := UI.bottone("Rivedi la mappa", 22)
	b1.pressed.connect(fondo.queue_free)
	hb.add_child(b1)
	var b2 := UI.bottone("Torna al menu", 22)
	b2.pressed.connect(_torna_menu)
	hb.add_child(b2)


# =====================================================================================
# VISTA 3D, REGOLE, MENU, ONLINE
# =====================================================================================

func _imposta_3d(on: bool) -> void:
	vista3d = on
	if b3d.button_pressed != on:
		b3d.set_pressed_no_signal(on)
	if on and tavolo3d == null:
		tavolo3d = preload("res://scripts/ui/tavolo3d.gd").new()
		tavolo3d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tavolo3d.vista = self
		tavolo3d.ritmo = RITMI[_ritmo][2]
		centro.add_child(tavolo3d)
	if tavolo3d != null:
		tavolo3d.visible = on
		if on:
			tavolo3d.aggiorna(motore, false)
	mappa.visible = not on


func _mostra_regole() -> void:
	var w := preload("res://scripts/ui/regole.gd").new()
	w.finestra = true
	w.z_index = 70
	add_child(w)


func _torna_menu() -> void:
	if online != null:
		online.alive = false
	main.show_menu()


func online_attesa(s: int) -> void:
	stato_online.text = "" if s < 0 else "In attesa di %s…" % motore.giocatori[s]["nome"]


func online_stato(t: String) -> void:
	stato_online.text = t
