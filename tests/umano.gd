extends SceneTree
## Partita con una persona che preme i pulsanti dell'interfaccia (scelte dell'IA, ma passando dalla vista).
## xvfb-run godot --path . -s tests/umano.gd -- <cartella> [turni]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var dir: String = args[0] if args.size() > 0 else "/tmp/umano"
	var turni := int(args[1]) if args.size() > 1 else 6
	DirAccess.make_dir_recursive_absolute(dir)
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.start_game({"giocatori": [{"nome": "Stefano", "ia": false}], "difficolta": "standard", "ritardo_ia": 0.0, "seme": 77, "ritmo": 3})
	await process_frame
	var g = main.current
	var ia := IA.new()
	ia.semplice = true
	var premute := 0
	var foto := 0
	var t0 := Time.get_ticks_msec()
	while g.motore.turno <= turni and g.motore.esito == "" and Time.get_ticks_msec() - t0 < 120000:
		await process_frame
		if g._in_attesa:
			var req: Dictionary = g._richiesta
			var k := ia.scegli(g.motore, req["posto"], req)
			var bottoni: Array = g.scelta_opzioni.get_children()
			if premute % 25 == 0 and foto < 4:
				await process_frame
				g.get_viewport().get_texture().get_image().save_png("%s/umano_%d.png" % [dir, foto])
				foto += 1
			bottoni[k].emit_signal("pressed")
			premute += 1
	print("pulsanti premuti: %d, turno %d, esito '%s', speranza %d" % [premute, g.motore.turno, g.motore.esito, g.motore.speranza])
	quit()
