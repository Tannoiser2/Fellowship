extends SceneTree
## Partita con l'interfaccia e schermate: xvfb-run godot --path . -s tests/vivo.gd -- <cartella> [3d] [ia] [n=1..5]

var dir := "/tmp/vivo"

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		dir = args[0]
	var tre_d := args.has("3d")
	DirAccess.make_dir_recursive_absolute(dir)
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await _attendi(1.0)
	await _foto("01_menu")
	var n_g := 2
	for a in args:
		if a.begins_with("n="):
			n_g = int(a.substr(2))
	var gg: Array = [{"nome": "Stefano", "ia": args.has("ia")}]
	for k in n_g - 1:
		gg.append({"nome": ["Compagno", "Anna", "Marco", "Giulia"][k], "ia": true})
	main.start_game({"giocatori": gg, "difficolta": "introduttivo",
		"obiettivi": ["benedizione", "saruman", "sauron", "anello"], "personaggi": preload("res://scripts/ui/menu.gd").PRIMA_PARTITA[n_g],
		"primo_frodo": true, "ritardo_ia": 0.05, "seme": 4242, "vista3d": tre_d, "ritmo": 2})
	await _attendi(2.5)
	await _foto("02_inizio")
	await _attendi(8.0)
	await _foto("03_dopo")
	var g = main.current
	g.mappa.zoom = 0.75
	g.mappa.offset = Vector2(-300, -100)
	g.mappa.queue_redraw()
	await _attendi(0.3)
	await _foto("04_zoom")
	g._imposta_3d(true)
	await _attendi(1.5)
	await _foto("05_3d")
	var ro: Dictionary = Dati.d()["regioni"][g.motore.occhio]
	g.tavolo3d._dist = 9.0
	g.tavolo3d._rot = Vector2(-0.45, 0.2)
	g.tavolo3d.perno.position = g.tavolo3d._a3d(Vector2(ro["x"], ro["y"]))
	g.tavolo3d._aggiorna_camera()
	await _attendi(0.5)
	await _foto("06_3d_vicino")
	g._imposta_3d(false)
	g._mostra_regole()
	await _attendi(0.5)
	await _foto("07_regole")
	quit()


func _attendi(s: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < s * 1000:
		await process_frame


func _foto(nome: String) -> void:
	await process_frame
	await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [dir, nome])
	print("foto ", nome)
