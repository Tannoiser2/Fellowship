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
var b3d: Button

var _richiesta := {}
var _in_attesa := false
var _da_aggiornare := false
var _ripresa := false
const SALVATAGGIO := "user://partita_in_corso.json"


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
	ps.custom_minimum_size.x = 300
	radice.add_child(ps)
	var scs := ScrollContainer.new()
	scs.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ps.add_child(scs)
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
	lbl_turno = UI.titolo("", 24, UI.ORO)
	hb.add_child(lbl_turno)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(sp)
	stato_online = UI.etichetta("", 18, UI.ORO)
	hb.add_child(stato_online)
	b3d = UI.bottone("Tavolo 3D", 17)
	b3d.toggle_mode = true
	b3d.toggled.connect(_imposta_3d)
	hb.add_child(b3d)
	var bc := UI.bottone("Centra", 17)
	bc.pressed.connect(func():
		mappa._adatta()
		if tavolo3d != null:
			tavolo3d.reimposta_vista())
	hb.add_child(bc)
	var br := UI.bottone("Regole", 17)
	br.pressed.connect(_mostra_regole)
	hb.add_child(br)
	var bm := UI.bottone("Menu", 17)
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
	pd.custom_minimum_size.x = 360
	radice.add_child(pd)
	var scd := ScrollContainer.new()
	scd.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pd.add_child(scd)
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
	var fasi := {"azioni": "azioni", "pesca": "si pescano le carte", "ombra": "carte dell'Ombra", "fine": "fine"}
	lbl_turno.text = "Turno %d — %s — %s" % [max(1, motore.turno), g["nome"], fasi.get(motore.fase, "")]
	_aggiorna_sx()
	_aggiorna_dx()
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
	# speranza
	_sezione(col_sx, "Speranza")
	var hs := HFlowContainer.new()
	for k in Dati.SPERANZA_MAX:
		var im := UI.immagine(UI.pedina("speranza"), 30, 30)
		if k >= motore.speranza:
			im.modulate = Color(0.3, 0.25, 0.2, 0.5)
		hs.add_child(im)
	hs.tooltip_text = "Speranza di Frodo: %d su %d. A 0 la partita è persa." % [motore.speranza, Dati.SPERANZA_MAX]
	hs.mouse_filter = Control.MOUSE_FILTER_PASS
	col_sx.add_child(hs)
	# minaccia
	_sezione(col_sx, "Minaccia")
	var hm := HBoxContainer.new()
	hm.add_theme_constant_override("separation", 4)
	for k in Dati.MINACCIA.size():
		var pnl := PanelContainer.new()
		var st := StyleBoxFlat.new()
		st.bg_color = UI.ROSSO_SCURO if k == motore.minaccia else Color(0.18, 0.14, 0.1)
		st.border_color = UI.ORO if k == motore.minaccia else UI.ORO_SCURO
		st.set_border_width_all(1)
		st.set_corner_radius_all(16)
		st.content_margin_left = 9
		st.content_margin_right = 9
		pnl.add_theme_stylebox_override("panel", st)
		pnl.add_child(UI.etichetta(str(Dati.MINACCIA[k]), 18, UI.PERGAMENA, true))
		hm.add_child(pnl)
	hm.tooltip_text = "Si girano %d carte dell'Ombra a fine turno. Sale di uno a ogni «Il cielo si oscura»." % motore.valore_minaccia()
	hm.mouse_filter = Control.MOUSE_FILTER_PASS
	col_sx.add_child(hm)
	var occ := UI.etichetta("L'Occhio è su: %s" % Dati.nome_regione(motore.occhio), 18, Color(1, 0.6, 0.3))
	col_sx.add_child(occ)
	if motore.in_gioco("frodo"):
		var n := motore.dadi_ricerca()
		col_sx.add_child(UI.etichetta("Frodo: %s (%d dad%s di ricerca)" % [Dati.nome(motore.luogo_frodo()), n, "o" if n == 1 else "i"], 17, UI.PERGAMENA))
	# obiettivi
	_sezione(col_sx, "Obiettivi")
	var hob := HFlowContainer.new()
	hob.add_theme_constant_override("h_separation", 4)
	hob.add_theme_constant_override("v_separation", 4)
	col_sx.add_child(hob)
	for o in motore.obiettivi:
		var ob := Dati.obiettivo(o["codice"])
		var t := _carta_ui(int(ob["id"]), 128, 88, true)
		if o["fatto"]:
			t.modulate = Color(0.55, 0.55, 0.5, 0.85)
			var spunta := UI.etichetta("Fatto", 16, UI.VERDE, true)
			spunta.position = Vector2(4, 60)
			t.add_child(spunta)
		var extra := ""
		if motore.su_carta.has(o["codice"]):
			extra = " — sulla carta: %d" % int(motore.su_carta[o["codice"]])
		if o["codice"] == "hobbit":
			extra = " — simboli coperti: %d/2" % motore.hobbit.size()
		if o["codice"] == "eowyn":
			extra = " — Nazgûl distrutti: %d/2" % motore.nazgul_eowyn
		t.tooltip_text = "%s%s\n%s\nCompletato se: %s\nEffetto: %s" % [ob["nome"], extra, ob["preparazione"], ob["condizione"], ob["effetto"]]
		hob.add_child(t)
	# mazzi
	_sezione(col_sx, "Mazzi")
	var hmz := HBoxContainer.new()
	hmz.add_theme_constant_override("separation", 8)
	col_sx.add_child(hmz)
	var dg := _dorso_ui("dorso_giocatori", 62, 90, "Mazzo dei giocatori: %d carte" % motore.mazzo.size(), motore.mazzo.size())
	hmz.add_child(dg)
	var top_ombra := "dorso_bandiera"
	if not motore.mazzo_ombra.is_empty():
		top_ombra = "dorso_" + Dati.carta(motore.mazzo_ombra.back())["retro"]
	var do := _dorso_ui(top_ombra, 62, 90, "Mazzo dell'Ombra: %d carte. Il dorso in cima decide quale metà della prossima carta si risolve: bandiera rossa = avanzata, stendardo nero = rinforzo." % motore.mazzo_ombra.size(), motore.mazzo_ombra.size())
	hmz.add_child(do)
	if motore.ultima_ombra >= 0:
		var u := _carta_ui(motore.ultima_ombra, 62, 90)
		hmz.add_child(u)
	# riserve
	_sezione(col_sx, "Riserva")
	var hr := HFlowContainer.new()
	hr.add_theme_constant_override("h_separation", 8)
	col_sx.add_child(hr)
	for a in Dati.ARMATE:
		hr.add_child(UI.contatore(UI.pedina("truppa_" + a), motore.riserva_truppe[a], 17, "Truppe %s nella riserva" % Dati.NOMI_ARMATE[a]))
	hr.add_child(UI.contatore(UI.pedina("truppa_ombra"), motore.riserva_ombra, 17, "Truppe dell'Ombra nella riserva"))
	var hsimb := HFlowContainer.new()
	hsimb.add_theme_constant_override("h_separation", 8)
	col_sx.add_child(hsimb)
	for s in Dati.SIMBOLI:
		hsimb.add_child(UI.contatore(UI.pedina(s), motore.riserva_simboli[s], 17, "Segnalini %s nella riserva" % Dati.NOMI_SIMBOLI[s]))


func _aggiorna_dx() -> void:
	_svuota(col_dx)
	for i in motore.giocatori.size():
		col_dx.add_child(_area_giocatore(i))


func _area_giocatore(i: int) -> Control:
	var g: Dictionary = motore.giocatori[i]
	var mio := i == motore.turno_di
	var p := UI.pannello(Color(0.16, 0.12, 0.08, 0.95) if mio else Color(0.12, 0.10, 0.07, 0.9), UI.ORO if mio else UI.ORO_SCURO)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	p.add_child(v)
	var h := HBoxContainer.new()
	v.add_child(h)
	h.add_child(UI.titolo(g["nome"] + (" (IA)" if g["ia"] else ""), 20, UI.ORO if mio else UI.PERGAMENA))
	# personaggi
	var hp := HBoxContainer.new()
	hp.add_theme_constant_override("separation", 6)
	v.add_child(hp)
	var lista: Array = g["pg"]
	if motore.solo:
		lista = ["frodo"] + motore._ordine_solo()
	for k in lista.size():
		var pid: String = lista[k]
		if not motore.pg.has(pid):
			continue
		var pc := Dati.personaggio(pid)
		var carta := int(pc["carta"])
		if pid == "gandalf" and motore.pg[pid]["bianco"]:
			carta = 4500
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 0)
		var t := _carta_ui(carta, 96 if not motore.solo else 62, 64 if not motore.solo else 42, true)
		if motore.pg[pid]["fuori"]:
			t.modulate = Color(0.4, 0.4, 0.4, 0.7)
		var tip := "%s — %s\n" % [motore.nome_pg(pid), Dati.nome(motore.pg[pid]["luogo"])]
		for a in pc["abilita"]:
			tip += "\n%s: %s" % [a["nome"], a["testo"]]
		t.tooltip_text = tip
		box.add_child(t)
		var lb := UI.etichetta(motore.nome_pg(pid).split(" ")[0], 14, UI.ORO if pid == motore.attivo else UI.CENERE, pid == motore.attivo)
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if motore.solo and k > 0 and k - 1 == motore.solo_indice % motore._ordine_solo().size():
			lb.text += " *"
			lb.tooltip_text = "Ha il segnalino del solitario: fa 4 azioni in questo turno."
		box.add_child(lb)
		hp.add_child(box)
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
	if t.tooltip_text == "":
		var c := Dati.carta(id)
		if c.get("tipo", "") == "evento":
			t.tooltip_text = "%s\n%s" % [c["nome"], c["testo"]]
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
	var c := Dati.carta(id)
	var tx := UI.carta_tex(id)
	if tx == null:
		return
	var orizz := tx.get_width() > tx.get_height()
	zoom_img.custom_minimum_size = Vector2(560, 370) if orizz else Vector2(330, 480)
	zoom_img.texture = tx
	var testo := ""
	match c.get("tipo", ""):
		"evento":
			testo = "%s — %s" % [c["nome"], c["testo"]]
		"obiettivo":
			testo = "%s\n%s\nCompletato se: %s\nEffetto: %s" % [c["nome"], c["preparazione"], c["condizione"], c["effetto"]]
		"ombra":
			testo = motore.descrivi_ombra(id) if not c.has("speciale") else "%s — %s" % [c["nome"], c["testo"]]
			if not c.has("speciale"):
				var ordini := {"occhio": "L'Occhio si volge sulla regione di Frodo (se c'è già, ricerca).", "nazgul2": "2 Nazgûl si avvicinano a Frodo.", "nazgul3": "3 Nazgûl da Mordor all'Occhio."}
				testo = "Sopra (bandiera rossa in cima al mazzo): avanzata lungo la linea %s.\nSotto (stendardo nero): +1 truppa dell'Ombra a %s, poi: %s" % [testo.split(" / ")[0], Dati.nome(c["rinforzo"]), ordini[c["ordine"]]]
				mappa.evidenzia({c["rinforzo"]: Color(0.9, 0.1, 0.1)}, c["linea"])
		"regione":
			testo = "%s — %s" % [Dati.nome_regione(c["regione"]), Dati.NOMI_SIMBOLI[c["simbolo"]]]
			var luoghi := {}
			for l in Dati.d()["regioni"][c["regione"]]["luoghi"]:
				luoghi[l] = Color(1, 0.85, 0.3)
			mappa.evidenzia(luoghi)
		"cieli":
			testo = "Il cielo si oscura: la minaccia sale, l'Occhio cerca Frodo (se c'è già, -2 speranza), 3 truppe dell'Ombra a %s, poi si rimescolano gli scarti dell'Ombra sul mazzo." % Dati.nome(c["luogo"])
	zoom_testo.text = testo
	zoom.visible = true
	zoom.reset_size()
	var r := sorgente.get_global_rect()
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
		"avanzata":
			mappa.evidenzia({}, dati["linea"])
			get_tree().create_timer(1.6).timeout.connect(func(): if mappa != null: mappa.evidenzia({}))
		"ombra":
			_segna_aggiornamento()
	if tavolo3d != null and vista3d:
		tavolo3d.evento(tipo, dati)


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
	var t := UI.titolo(("Ricerca" if dati["tipo"] == "ricerca" else "Battaglia") + " a " + Dati.nome(dati.get("luogo", "the_shire")), 26, UI.ORO)
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
		centro.add_child(tavolo3d)
	if tavolo3d != null:
		tavolo3d.visible = on
		if on:
			tavolo3d.aggiorna(motore)
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
