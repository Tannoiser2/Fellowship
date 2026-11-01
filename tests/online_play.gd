extends SceneTree
## Prova del gioco online: due istanze (chi crea la stanza e un amico) giocano una partita intera sul
## finto Firebase (tests/firebase_mock.py); il terzo giocatore lo gioca l'IA.
## PL_ROLE=host|guest, PL_CODEFILE=file per il codice della stanza.
## Alla fine ognuno stampa l'impronta della partita: devono coincidere.

var main
var t0 := 0
var ia := IA.new()
var limite_turni := 3
var ultimo_log := 0

func _init() -> void:
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	t0 = Time.get_ticks_msec()
	_run()

func _wait(s: float) -> void:
	await create_timer(s).timeout

func _run() -> void:
	await _wait(0.5)
	var role := OS.get_environment("PL_ROLE")
	var cf := OS.get_environment("PL_CODEFILE")
	var menu = main.current
	menu.giocatori = [{"nome": "Host", "ia": false}, {"nome": "Ospite", "ia": false}, {"nome": "Gandalf", "ia": true}]
	menu.ritardo = 0.1
	menu._pannello_online()
	menu.on_nome.text = "Host" if role == "host" else "Ospite"
	if role == "host":
		await menu._online_crea()
		var code: String = main.lobby.get("code", "")
		print("PLTEST stanza ", code)
		var f := FileAccess.open(cf, FileAccess.WRITE)
		f.store_string(code)
		f.close()
		while true:
			var room: Dictionary = await main.net.room(code)
			if Net._as_dict(room.get("seats", {})).size() >= 2:
				break
			await _wait(0.5)
		await menu._online_avvia()
	else:
		var code := ""
		while code == "":
			if FileAccess.file_exists(cf):
				code = FileAccess.get_file_as_string(cf).strip_edges()
			await _wait(0.3)
		menu.on_code.text = code
		await menu._online_entra()
	while true:
		await process_frame
		if Time.get_ticks_msec() - t0 > 600000:
			print("PLTEST tempo scaduto")
			quit(2)
			return
		var view = main.current
		if Time.get_ticks_msec() - ultimo_log > 10000:
			ultimo_log = Time.get_ticks_msec()
			var st := "menu"
			if view != null and ("motore" in view) and view.motore != null:
				st = "turno %d fase %s attesa %s mosse %d %s" % [view.motore.turno, view.motore.fase, view._in_attesa, view.online.n if view.online else -1, view.stato_online.text]
			print("PLTEST stato ", st, " lobby ", main.lobby)
		if view == null or not ("motore" in view) or view.motore == null:
			continue
		var m: Motore = view.motore
		if view._in_attesa:
			view._premi(ia.scegli(m, view._richiesta["posto"], view._richiesta))
		if m.esito != "" or m.turno > limite_turni:
			var imp := "turno%d speranza%d minaccia%d occhio %s Frodo %s ombra %d" % [m.turno, m.speranza, m.minaccia, m.occhio, m.luogo_frodo(), m.riserva_ombra]
			print("PLTEST impronta | ", imp)
			quit(0)
			return
