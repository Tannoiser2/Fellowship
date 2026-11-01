extends SceneTree
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seed := int(args[0]) if args.size() > 0 else 1001
	var npl := int(args[1]) if args.size() > 1 else 2
	var m := Motore.new()
	root.add_child(m)
	var gg: Array = []
	for i in npl:
		gg.append({"nome": "IA %d" % (i + 1), "ia": true})
	m.messaggio.connect(func(t): print(t))
	m.prepara({"giocatori": gg, "difficolta": "introduttivo", "seme": seed})
	var ia := IA.new()
	ia.pausa = 0.0
	var ctl := ControlloIA.new()
	ctl.ia = ia
	for i in npl:
		m.controllori.append(ctl)
	var fine := [false]
	m.finita.connect(func(_e): fine[0] = true)
	for i in npl:
		print(m.giocatori[i]["nome"], " ", m.giocatori[i]["pg"])
	print(m.obiettivi)
	m.gioca()
	while not fine[0] and m.turno < 200:
		await process_frame
	quit()
