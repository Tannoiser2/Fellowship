extends SceneTree
## Partita con l'interfaccia e schermate: xvfb-run godot --path . -s tests/vivo.gd -- <cartella> [3d]

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
	main.start_game({"giocatori": [{"nome": "Stefano", "ia": args.has("ia")}, {"nome": "Compagno", "ia": true}], "difficolta": "introduttivo",
		"obiettivi": ["benedizione", "saruman", "sauron", "anello"], "personaggi": [["frodo", "legolas"], ["pipino", "eowyn"]],
		"primo_frodo": true, "ritardo_ia": 0.05, "seme": 4242, "vista3d": tre_d})
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
	g.tavolo3d._dist = 14.0
	g.tavolo3d._rot = Vector2(-0.7, 0.3)
	g.tavolo3d.perno.position = Vector3(-8, 0, -6)
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
