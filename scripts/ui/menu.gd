extends Control
## Menu iniziale: giocatori (persone o IA), difficoltà, scenario, vista 2D/3D e gioco online.

var main
var giocatori: Array = []
var difficolta := "introduttivo"
var scenario := "primo"
var vista3d := false
var ritardo := 0.6

var box_giocatori: VBoxContainer
var opt_diff: OptionButton
var opt_scenario: OptionButton
var lbl_scenario: Label
var messaggio: Label
var on_code: LineEdit
var on_nome: LineEdit
var on_start: Button
var pannello_online: PanelContainer

const PRIMA_PARTITA := {
	1: [["frodo", "pipino", "eowyn", "legolas", "gandalf"]],
	2: [["frodo", "legolas"], ["pipino", "eowyn"]],
	3: [["frodo", "legolas"], ["pipino", "eowyn"], ["arwen", "aragorn"]],
	4: [["frodo", "legolas"], ["pipino", "eowyn"], ["arwen", "aragorn"], ["gandalf", "boromir"]],
	5: [["frodo", "legolas"], ["pipino", "eowyn"], ["arwen", "aragorn"], ["gandalf", "boromir"], ["gimli", "eomer"]],
}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var st: Dictionary = main.menu_state
	giocatori = st.get("giocatori", [{"nome": "Stefano", "ia": false}, {"nome": "Compagno", "ia": true}])
	difficolta = st.get("difficolta", "introduttivo")
	scenario = st.get("scenario", "primo")
	vista3d = st.get("vista3d", false)
	ritardo = st.get("ritardo", 0.6)
	_costruisci()
	if not main.lobby.is_empty():
		_pannello_online.call_deferred()


func _salva() -> void:
	main.menu_state = {"giocatori": giocatori, "difficolta": difficolta, "scenario": scenario, "vista3d": vista3d, "ritardo": ritardo}


func _costruisci() -> void:
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 40)
	add_child(m)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 40)
	m.add_child(h)
	# ---- colonna del titolo
	var sx := VBoxContainer.new()
	sx.custom_minimum_size.x = 640
	sx.add_theme_constant_override("separation", 6)
	h.add_child(sx)
	var sopra := UI.titolo("Il Signore degli Anelli", 34, UI.PERGAMENA)
	sx.add_child(sopra)
	var logo := Label.new()
	logo.text = "Il destino della Compagnia"
	logo.add_theme_font_override("font", UI.font_decorato)
	logo.add_theme_font_size_override("font_size", 64)
	logo.add_theme_color_override("font_color", UI.ORO)
	logo.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.02))
	logo.add_theme_constant_override("outline_size", 8)
	logo.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	logo.add_theme_constant_override("shadow_offset_y", 4)
	logo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sx.add_child(logo)
	sx.add_child(UI.etichetta("The Lord of the Rings: Fate of the Fellowship — un gioco di Matt Leacock", 20, UI.CENERE))
	var spieg := UI.testo_lungo("Cooperativo da 1 a 5 giocatori. Portate Frodo e Sam al Monte Fato con l'Unico Anello, completate gli obiettivi e difendete i rifugi dei popoli liberi, sfuggendo all'Occhio di Sauron e ai Nove.", 20, UI.PERGAMENA)
	spieg.custom_minimum_size.x = 600
	sx.add_child(spieg)
	sx.add_child(Control.new())
	var copertina := UI.immagine(UI.tex("res://assets/misc/copertina.webp"), 600, 360)
	sx.add_child(copertina)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sx.add_child(sp)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	sx.add_child(hb)
	var b_reg := UI.bottone("Regole in breve", 20)
	b_reg.pressed.connect(func(): _salva(); main.show_rules())
	hb.add_child(b_reg)
	# ---- colonna della configurazione
	var p := UI.pannello()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(p)
	var dx := VBoxContainer.new()
	dx.add_theme_constant_override("separation", 12)
	p.add_child(dx)
	dx.add_child(UI.titolo("Nuova partita", 38))
	dx.add_child(UI.etichetta("Giocatori (ognuno guida 2 personaggi; in solitario Frodo e altri 4)", 19, UI.CENERE))
	box_giocatori = VBoxContainer.new()
	box_giocatori.add_theme_constant_override("separation", 6)
	dx.add_child(box_giocatori)
	var hg := HBoxContainer.new()
	hg.add_theme_constant_override("separation", 10)
	dx.add_child(hg)
	var b_piu := UI.bottone("+ Giocatore", 18)
	b_piu.pressed.connect(func():
		if giocatori.size() < 5:
			giocatori.append({"nome": "Compagno %d" % (giocatori.size() + 1), "ia": true})
			_aggiorna_giocatori())
	hg.add_child(b_piu)
	var b_meno := UI.bottone("− Giocatore", 18)
	b_meno.pressed.connect(func():
		if giocatori.size() > 1:
			giocatori.pop_back()
			_aggiorna_giocatori())
	hg.add_child(b_meno)
	# difficoltà e scenario
	var hd := HBoxContainer.new()
	hd.add_theme_constant_override("separation", 14)
	dx.add_child(hd)
	hd.add_child(UI.etichetta("Difficoltà:", 20))
	opt_diff = OptionButton.new()
	var dd: Dictionary = Dati.d()["difficolta"]
	var kk := 0
	for k in dd:
		opt_diff.add_item("%s (%d «Il cielo si oscura», %d obiettivi)" % [dd[k]["nome"], dd[k]["cieli"], dd[k]["obiettivi"]])
		opt_diff.set_item_metadata(kk, k)
		if k == difficolta:
			opt_diff.select(kk)
		kk += 1
	opt_diff.item_selected.connect(func(i): difficolta = opt_diff.get_item_metadata(i); _aggiorna_scenario())
	hd.add_child(opt_diff)
	var hs := HBoxContainer.new()
	hs.add_theme_constant_override("separation", 14)
	dx.add_child(hs)
	hs.add_child(UI.etichetta("Obiettivi:", 20))
	opt_scenario = OptionButton.new()
	opt_scenario.add_item("Casuali")
	opt_scenario.set_item_metadata(0, "")
	var i := 1
	for s in Dati.d()["scenari"]:
		opt_scenario.add_item("%s (%s)" % [s["nome"], dd[s["difficolta"]]["nome"]])
		opt_scenario.set_item_metadata(i, s["codice"])
		if s["codice"] == scenario:
			opt_scenario.select(i)
		i += 1
	opt_scenario.item_selected.connect(func(x):
		scenario = opt_scenario.get_item_metadata(x)
		for s in Dati.d()["scenari"]:
			if s["codice"] == scenario:
				difficolta = s["difficolta"]
				for j in opt_diff.item_count:
					if opt_diff.get_item_metadata(j) == difficolta:
						opt_diff.select(j)
		_aggiorna_scenario())
	hs.add_child(opt_scenario)
	lbl_scenario = UI.testo_lungo("", 17, UI.CENERE)
	dx.add_child(lbl_scenario)
	# opzioni
	var ho := HBoxContainer.new()
	ho.add_theme_constant_override("separation", 20)
	dx.add_child(ho)
	var c3 := CheckBox.new()
	c3.text = "Tavolo 3D all'avvio"
	c3.button_pressed = vista3d
	c3.toggled.connect(func(on): vista3d = on)
	ho.add_child(c3)
	ho.add_child(UI.etichetta("Velocità dell'IA:", 19))
	var ov := OptionButton.new()
	for x in [["Lenta", 1.1], ["Normale", 0.6], ["Veloce", 0.25], ["Istantanea", 0.0]]:
		ov.add_item(x[0])
		ov.set_item_metadata(ov.item_count - 1, x[1])
		if is_equal_approx(float(x[1]), ritardo):
			ov.select(ov.item_count - 1)
	ov.item_selected.connect(func(x): ritardo = float(ov.get_item_metadata(x)))
	ho.add_child(ov)
	messaggio = UI.etichetta("", 19, UI.ORO)
	dx.add_child(messaggio)
	var sp2 := Control.new()
	sp2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dx.add_child(sp2)
	var hb2 := HBoxContainer.new()
	hb2.add_theme_constant_override("separation", 14)
	dx.add_child(hb2)
	var b_ini := UI.bottone("Inizia la partita", 26)
	b_ini.pressed.connect(_inizia)
	hb2.add_child(b_ini)
	var salv := preload("res://scripts/ui/partita.gd").salvataggio()
	if not salv.is_empty():
		var b_cont := UI.bottone("Continua la partita salvata", 22)
		b_cont.pressed.connect(func():
			var cfg: Dictionary = salv["config"]
			cfg["storia"] = salv["storia"]
			main.start_game(cfg))
		hb2.add_child(b_cont)
	var b_on := UI.bottone("Gioca online", 22)
	b_on.pressed.connect(_pannello_online)
	hb2.add_child(b_on)
	_aggiorna_giocatori()
	_aggiorna_scenario()


func _aggiorna_giocatori() -> void:
	for c in box_giocatori.get_children():
		c.queue_free()
	for i in giocatori.size():
		var g: Dictionary = giocatori[i]
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 10)
		box_giocatori.add_child(r)
		r.add_child(UI.etichetta("%d." % (i + 1), 20, UI.ORO, true))
		var le := LineEdit.new()
		le.text = g["nome"]
		le.custom_minimum_size.x = 280
		le.text_changed.connect(func(t): g["nome"] = t)
		r.add_child(le)
		var b := UI.bottone("IA" if g["ia"] else "Persona", 18)
		b.custom_minimum_size.x = 120
		b.pressed.connect(func():
			g["ia"] = not g["ia"]
			b.text = "IA" if g["ia"] else "Persona")
		r.add_child(b)
	_aggiorna_scenario()


func _aggiorna_scenario() -> void:
	if lbl_scenario == null:
		return
	if scenario == "":
		lbl_scenario.text = "«Distruggere l'Unico Anello» più obiettivi pescati a caso secondo la difficoltà; i personaggi sono a caso, con quelli richiesti dagli obiettivi."
		return
	for s in Dati.d()["scenari"]:
		if s["codice"] == scenario:
			var nomi: Array = []
			for c in s["obiettivi"]:
				nomi.append(Dati.obiettivo(c)["nome"])
			var t := "Obiettivi: " + "; ".join(nomi) + "."
			if scenario == "primo":
				t += " Personaggi consigliati per la prima partita; inizia chi ha Frodo."
			lbl_scenario.text = t


func _config() -> Dictionary:
	var gg := []
	for g in giocatori:
		var nm: String = String(g["nome"]).strip_edges()
		gg.append({"nome": nm if nm != "" else "Giocatore", "ia": g["ia"]})
	var cfg := {"giocatori": gg, "difficolta": difficolta, "vista3d": vista3d, "ritardo_ia": ritardo}
	if scenario != "":
		for s in Dati.d()["scenari"]:
			if s["codice"] == scenario:
				cfg["obiettivi"] = s["obiettivi"].duplicate()
		if scenario == "primo":
			cfg["personaggi"] = PRIMA_PARTITA[gg.size()]
			cfg["primo_frodo"] = true
	return cfg


func _inizia() -> void:
	_salva()
	main.start_game(_config())


# =================================================================== online

func _pannello_online() -> void:
	if pannello_online != null:
		pannello_online.queue_free()
	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.6)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.add_child(cc)
	pannello_online = UI.pannello(Color(0.11, 0.09, 0.06, 0.98), UI.ORO)
	pannello_online.custom_minimum_size.x = 780
	cc.add_child(pannello_online)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	pannello_online.add_child(v)
	v.add_child(UI.titolo("Gioca online", 40))
	v.add_child(UI.testo_lungo("Chi crea la stanza sceglie in questo menu difficoltà, obiettivi e giocatori (i giocatori «Persona» sono i posti per gli amici), poi crea la stanza e dà il codice. Ognuno guida i propri personaggi; i posti rimasti liberi li gioca l'IA.", 18, UI.CENERE))
	var hn := HBoxContainer.new()
	v.add_child(hn)
	hn.add_child(UI.etichetta("Il tuo nome:", 19))
	on_nome = LineEdit.new()
	on_nome.custom_minimum_size.x = 280
	var net: Net = main.get_net()
	on_nome.text = String(net.load_session().get("name", giocatori[0]["nome"]))
	hn.add_child(on_nome)
	var hc := HBoxContainer.new()
	hc.add_theme_constant_override("separation", 10)
	v.add_child(hc)
	var b_crea := UI.bottone("Crea una stanza", 20)
	b_crea.pressed.connect(_online_crea)
	hc.add_child(b_crea)
	on_code = LineEdit.new()
	on_code.placeholder_text = "Codice"
	on_code.max_length = 4
	on_code.custom_minimum_size.x = 120
	hc.add_child(on_code)
	var b_entra := UI.bottone("Entra", 20)
	b_entra.pressed.connect(_online_entra)
	hc.add_child(b_entra)
	on_start = UI.bottone("Inizia online", 22)
	on_start.visible = main.lobby.get("role", "") == "host"
	on_start.pressed.connect(_online_avvia)
	v.add_child(on_start)
	var stato := UI.testo_lungo("", 18, UI.ORO)
	stato.name = "Stato"
	v.add_child(stato)
	var b_chiudi := UI.bottone("Chiudi", 18)
	b_chiudi.pressed.connect(func():
		main.lobby = {}
		fondo.queue_free()
		pannello_online = null)
	v.add_child(b_chiudi)
	if not main.lobby.is_empty():
		on_code.text = main.lobby["code"]
		_lobby_poll(main.lobby["code"])
	else:
		var sess := net.load_session()
		var vecchia := String(sess.get("room", ""))
		if vecchia != "":
			on_code.text = vecchia
			_di("Eri nella stanza %s: premi Entra per rientrare." % vecchia)


func _di(t: String) -> void:
	if pannello_online != null:
		var l: Label = pannello_online.find_child("Stato", true, false)
		if l != null:
			l.text = t


func _online_crea() -> void:
	var cfg := _config()
	var nm := on_nome.text.strip_edges()
	if nm == "":
		_di("Scrivi il tuo nome.")
		return
	var seats := []
	for i in cfg["giocatori"].size():
		if not cfg["giocatori"][i]["ia"]:
			seats.append(i)
	if seats.is_empty():
		_di("Imposta almeno un giocatore come Persona: sono i posti della stanza.")
		return
	_salva()
	var net: Net = main.get_net()
	_di("Creo la stanza…")
	var code := await net.create_room(nm, seats)
	if code == "":
		_di("Non riesco a creare la stanza.\n%s" % net.last_error)
		return
	main.lobby = {"role": "host", "code": code, "seat": seats[0]}
	net.remember_room(code, seats[0])
	net._save({"name": nm})
	on_code.text = code
	on_start.visible = true
	_lobby_poll(code)


func _online_entra() -> void:
	var code := on_code.text.strip_edges().to_upper()
	var nm := on_nome.text.strip_edges()
	if code.length() != 4 or nm == "":
		_di("Scrivi il tuo nome e il codice di 4 lettere.")
		return
	var net: Net = main.get_net()
	_di("Entro nella stanza %s…" % code)
	var seat := await net.join_room(code, nm)
	if seat < 0:
		_di("Stanza %s non trovata, piena, oppure la partita è già iniziata.%s" % [code, ("\n" + net.last_error) if net.last_error != "" else ""])
		return
	var room: Dictionary = net.last_room
	main.lobby = {"role": "host" if room.get("host", "") == net.uid else "guest", "code": code, "seat": seat}
	net.remember_room(code, seat)
	net._save({"name": nm})
	if room.get("status", "") == "playing" and room.has("game"):
		_avvia(room["game"], true)
		return
	on_start.visible = main.lobby["role"] == "host"
	_lobby_poll(code)


func _lobby_poll(code: String) -> void:
	var net: Net = main.get_net()
	while is_inside_tree() and main.lobby.get("code", "") == code:
		var room := await net.room(code)
		if not is_inside_tree() or main.lobby.get("code", "") != code:
			return
		if room.is_empty():
			_di("La stanza %s non esiste più." % code)
			main.lobby = {}
			return
		var seats := Net._as_dict(room.get("seats", {}))
		var nomi := []
		for k in seats:
			nomi.append("%s (posto %d)" % [seats[k].get("name", "?"), int(k) + 1])
		if main.lobby["role"] == "host":
			_di("Stanza [ %s ]: dai il codice ai tuoi amici.\nPresenti: %s.\nQuando ci siete tutti premi Inizia online." % [code, ", ".join(nomi)])
		else:
			if room.get("status", "") == "playing" and room.has("game"):
				_avvia(room["game"], false)
				return
			_di("Sei nella stanza [ %s ] (posto %d). Presenti: %s.\nAspetta che chi l'ha creata avvii la partita." % [code, int(main.lobby["seat"]) + 1, ", ".join(nomi)])
		await get_tree().create_timer(2.0).timeout


func _online_avvia() -> void:
	var code: String = main.lobby["code"]
	var net: Net = main.get_net()
	var room := await net.room(code)
	if room.is_empty():
		_di("La stanza %s non esiste più." % code)
		main.lobby = {}
		return
	var seats_db := Net._as_dict(room.get("seats", {}))
	var cfg := _config()
	for i in cfg["giocatori"].size():
		var k := str(i)
		if seats_db.has(k) and seats_db[k] is Dictionary and not cfg["giocatori"][i]["ia"]:
			cfg["giocatori"][i]["nome"] = str(seats_db[k].get("name", cfg["giocatori"][i]["nome"]))
		else:
			cfg["giocatori"][i]["ia"] = true
	cfg["seme"] = 1 + randi() % 2000000000
	cfg.erase("vista3d")
	cfg.erase("ritardo_ia")
	var g := {"cfg": var_to_str(cfg)}
	if not await net.start_room(code, g):
		_di("Non riesco ad avviare la partita (%s)." % net.last_error)
		return
	_avvia(g, false)


func _avvia(g: Dictionary, rientro: bool) -> void:
	var net: Net = main.get_net()
	var lob: Dictionary = main.lobby
	var backlog: Array = []
	if rientro:
		backlog = await net.get_acts(lob["code"])
		net.set_away(lob["code"], int(lob["seat"]), false)
	var cfg = str_to_var(str(g.get("cfg", "")))
	if not (cfg is Dictionary):
		_di("Configurazione della partita non valida.")
		return
	var ses := SessioneOnline.new()
	ses.setup(net, lob["code"], int(lob["seat"]), lob["role"], backlog)
	cfg["online"] = ses
	cfg["vista3d"] = vista3d
	cfg["ritardo_ia"] = ritardo
	main.lobby = {}
	main.start_game(cfg)
