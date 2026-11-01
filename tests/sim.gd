extends SceneTree
## Partite automatiche solo IA: godot --headless --path . -s tests/sim.gd -- <n> [giocatori] [difficolta]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 10
	var ng := int(args[1]) if args.size() > 1 else 0
	var diff: String = args[2] if args.size() > 2 else "introduttivo"
	var vinte := 0
	var turni := 0
	var cause := {}
	for k in n:
		var m := Motore.new()
		root.add_child(m)
		var gg: Array = []
		var npl := ng if ng > 0 else (k % 5) + 1
		for i in npl:
			gg.append({"nome": "IA %d" % (i + 1), "ia": true})
		m.prepara({"giocatori": gg, "difficolta": diff, "seme": 1000 + k})
		var ia := IA.new()
		ia.pausa = 0.0
		var ctl := ControlloIA.new()
		ctl.ia = ia
		for i in npl:
			m.controllori.append(ctl)
		var fine := [false]
		m.finita.connect(func(_e): fine[0] = true)
		m.gioca()
		var guard := 0
		while not fine[0] and guard < 20000:
			await process_frame
			guard += 1
			if m.turno > 400:
				break
		if m.esito == "vittoria":
			vinte += 1
		turni += m.turno
		var ob := 0
		for o in m.obiettivi:
			if o["fatto"]:
				ob += 1
		print("partita %d (%d giocatori, %s): %s al turno %d, obiettivi %d/%d, speranza %d, minaccia %d, Frodo a %s, scelte %d" % [k, npl, diff, m.esito if m.esito != "" else "(interrotta)", m.turno, ob, m.obiettivi.size(), m.speranza, m.valore_minaccia(), m.luogo_frodo(), m.storia.size()])
		m.queue_free()
	print("VINTE %d su %d, turni medi %.1f" % [vinte, n, float(turni) / max(1, n)])
	quit()
