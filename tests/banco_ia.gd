extends SceneTree
## Banco di prova riproducibile dell'IA.
##   godot --headless --path . -s tests/banco_ia.gd -- <politica> <configurazione> <primo_seme> <quante> <file_uscita>
## politica: casuale (mosse legali a caso) | base (solo regole pratiche, senza simulazioni) | missioni (missioni +
##   simulazione azione per azione) | piena (IA del gioco) | piani / piani2 (in più: ricerca di sequenze intere di
##   azioni, con 1 o 2 turni simulati dopo; sperimentale, spenta nel gioco)
## configurazione: intro2 (2 giocatori, obiettivi e personaggi introduttivi) | solo (solitario ufficiale,
##   obiettivi e personaggi introduttivi) | casuale3 (3 giocatori, obiettivi e personaggi a caso)
## Ogni partita scrive una riga JSON con esito, durata, cause della perdita di speranza, rifugi persi, risorse finali.
## Semi: sviluppo 1000-1999, verifica finale 5000-5999 (da non usare per regolare l'IA).

const INTRO_OBIETTIVI := ["benedizione", "saruman", "sauron", "anello"]
const INTRO_PG := {1: [["frodo", "pipino", "eowyn", "legolas", "gandalf"]], 2: [["frodo", "legolas"], ["pipino", "eowyn"]]}


class ControlloCasuale:
	extends RefCounted
	var rng := RandomNumberGenerator.new()

	func decide(_m: Motore, _posto: int, req: Dictionary):
		var op: Array = req.get("opzioni", [])
		return rng.randi_range(0, maxi(0, op.size() - 1))


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var politica: String = a[0]
	var conf: String = a[1]
	var da := int(a[2])
	var quante := int(a[3])
	var uscita: String = a[4]
	var f := FileAccess.open(uscita, FileAccess.WRITE)
	var re := RegEx.new()
	re.compile("^([+-]\\d+) speranza: (.*)\\.$")
	for seme in range(da, da + quante):
		var cfg := {"difficolta": "introduttivo", "seme": seme}
		match conf:
			"intro2":
				cfg["giocatori"] = [{"nome": "A", "ia": true}, {"nome": "B", "ia": true}]
				cfg["obiettivi"] = INTRO_OBIETTIVI
				cfg["personaggi"] = INTRO_PG[2]
				cfg["primo_frodo"] = true
			"solo":
				cfg["giocatori"] = [{"nome": "A", "ia": true}]
				cfg["obiettivi"] = INTRO_OBIETTIVI
				cfg["personaggi"] = INTRO_PG[1]
			"casuale3":
				cfg["giocatori"] = [{"nome": "A", "ia": true}, {"nome": "B", "ia": true}, {"nome": "C", "ia": true}]
		var m := Motore.new()
		root.add_child(m)
		m.prepara(cfg)
		var ctl
		if politica == "casuale":
			ctl = ControlloCasuale.new()
			ctl.rng.seed = seme * 7 + 3
		else:
			var ia := IA.new()
			ia.pausa = 0.0
			if politica == "base":
				ia.guarda_avanti = false
			if politica == "missioni":
				ia.cerca_piani = false
			if politica == "piani":
				ia.cerca_piani = true
			if politica == "piani2":
				ia.cerca_piani = true
				ia.orizzonte_piano = 2
			ctl = ControlloIA.new()
			ctl.ia = ia
		for i in m.giocatori.size():
			m.controllori.append(ctl)
		var perdite := {}
		var guadagni := {}
		var rifugi_persi: Array = []
		var ultima_causa := [""]
		m.messaggio.connect(func(t: String):
			var r := re.search(t)
			if r:
				var d := int(r.get_string(1))
				var c := r.get_string(2).split(" (")[0]
				if c.ends_with("è caduto"):
					rifugi_persi.append(c.trim_suffix(" è caduto"))
					c = "rifugio caduto"
				elif c.begins_with("conquista"):
					c = "conquista"
				elif c.begins_with("Ti vedo"):
					c = "Ti vedo"
				if d < 0:
					perdite[c] = perdite.get(c, 0) - d
					ultima_causa[0] = c
				else:
					guadagni[c] = guadagni.get(c, 0) + d)
		var fine := [false]
		m.finita.connect(func(_e): fine[0] = true)
		var t0 := Time.get_ticks_msec()
		m.gioca()
		var guardia := 0
		while not fine[0] and guardia < 100000 and m.turno < 200:
			await process_frame
			guardia += 1
		var fatti: Array = []
		var aperti: Array = []
		for o in m.obiettivi:
			(fatti if o["fatto"] else aperti).append(o["codice"])
		var gettoni := 0
		var carte := 0
		for g in m.giocatori:
			for s in Dati.SIMBOLI:
				gettoni += int(g["gettoni"][s])
			carte += g["mano"].size()
		var pf := m.posto_di("frodo") if m.pg.has("frodo") else 0
		var riga := {"seme": seme, "politica": politica, "conf": conf, "esito": m.esito if m.esito != "" else "interrotta",
			"turni": m.turno, "causa": ultima_causa[0], "perdite": perdite, "guadagni": guadagni,
			"rifugi_persi": rifugi_persi, "obiettivi_fatti": fatti, "obiettivi_aperti": aperti,
			"frodo": m.luogo_frodo() if m.pg.has("frodo") else "", "resistenza_frodo": m.disponibili(pf, "resistenza"),
			"furtivita_frodo": m.disponibili(pf, "furtivita"), "gettoni_finali": gettoni, "carte_finali": carte,
			"secondi": (Time.get_ticks_msec() - t0) / 1000.0}
		f.store_line(JSON.stringify(riga))
		f.flush()
		print(JSON.stringify(riga))
		m.queue_free()
		await process_frame
	f.close()
	quit()
