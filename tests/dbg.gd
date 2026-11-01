extends SceneTree
func _init() -> void:
	var m := Motore.new()
	root.add_child(m)
	m.prepara({"giocatori": [{"nome":"A","ia":true},{"nome":"B","ia":true}], "difficolta": "introduttivo", "seme": 1011})
	var ia := IA.new()
	print(ia._obiettivo_pg(m, "frodo"))
	print(ia._bersagli(m, "frodo"))
	m.attivo = "frodo"; m.azioni_rimaste = 4
	for o in m.opzioni_azione("frodo"):
		print(o["testo"], " -> ", ia._valore(m, "frodo", o))
	quit()
