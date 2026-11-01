extends SceneTree
func _init() -> void:
	var cause := {}
	var n := 12
	for k in n:
		var m := Motore.new()
		root.add_child(m)
		m.messaggio.connect(func(t: String):
			if t.contains(" speranza: ") and t.begins_with("-"):
				var parti := t.split(" speranza: ")
				var c := parti[1]
				if c.contains("caduto"): c = "rifugio caduto"
				if c.begins_with("Ti vedo"): c = "Ti vedo"
				cause[c] = cause.get(c, 0) + int(parti[0]))
		m.prepara({"giocatori": [{"nome": "A", "ia": true}, {"nome": "B", "ia": true}], "difficolta": "introduttivo", "seme": 500 + k})
		var ia := IA.new()
		ia.pausa = 0.0
		var ctl := ControlloIA.new()
		ctl.ia = ia
		m.controllori = [ctl, ctl]
		m.gioca()
		while m.esito == "" and m.turno < 200:
			await process_frame
		m.queue_free()
	print(cause)
	quit()
