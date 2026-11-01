class_name SessioneOnline
extends Node
## Partita online in lockstep. Ogni decisione del motore (azione, viaggio, dadi da ritirare, carte da scartare…)
## diventa una mossa numerata nel database: acts/0, acts/1, …
## Tutti i dispositivi fanno girare lo stesso motore con lo stesso seme e applicano le stesse mosse
## nello stesso ordine, quindi la partita è identica ovunque e sul database viaggiano solo le scelte.
## - le decisioni del proprio posto le prende la persona davanti al dispositivo;
## - i posti IA li gioca il dispositivo di chi ha creato la stanza;
## - le altre si aspettano dal database. Se un giocatore tace per un minuto, al suo posto gioca l'IA.

var net: Net
var code := ""
var seat := -1
var role := "guest"
var n := 0
var backlog: Array = []
var catchup := false
var away := {}
var alive := true
var view
var locale              # controllore della persona davanti al dispositivo
var ia := IA.new()


func setup(p_net: Net, p_code: String, p_seat: int, p_role: String, p_backlog: Array) -> void:
	net = p_net
	code = p_code
	seat = p_seat
	role = p_role
	backlog = p_backlog
	catchup = not backlog.is_empty()


func _exit_tree() -> void:
	alive = false


func decide(m: Motore, s: int, req: Dictionary):
	if n < backlog.size():
		var a: Dictionary = backlog[n]
		n += 1
		return int(a.get("v", 0))
	if catchup:
		catchup = false
		if view != null:
			view.online_stato("Sei di nuovo in partita.")
	if s == seat:
		var r = await locale.decide(m, s, req)
		return await _pubblica(s, r)
	if role == "host" and (m.giocatori[s]["ia"] or away.has(s)):
		if away.has(s):
			var st := await net.seat(code, s)
			if not st.is_empty() and not st.get("away", false):
				away.erase(s)
				return await _aspetta(m, s, req)
		await get_tree().create_timer(0.6).timeout
		return await _pubblica(s, ia.scegli(m, s, req))
	return await _aspetta(m, s, req)


func _pubblica(s: int, r) -> int:
	var a := {"s": s, "v": int(r)}
	while alive:
		if await net.post_act(code, n, a):
			n += 1
			return int(r)
		var ex := await net.get_act(code, n)
		if not ex.is_empty() and not ex.has("_err"):
			n += 1
			return int(ex.get("v", 0))
		if view != null:
			view.online_stato("Rete non raggiungibile, riprovo… (%s)" % net.last_error)
		await get_tree().create_timer(2.0).timeout
	return int(r)


func _aspetta(m: Motore, s: int, req: Dictionary) -> int:
	var my_n := n
	var t0 := Time.get_ticks_msec()
	var last_seen = null
	var seen_t := t0
	var polls := 0
	if view != null:
		view.online_attesa(s)
	while alive:
		var a := await net.get_act(code, my_n)
		if not alive:
			break
		if not a.is_empty() and not a.has("_err"):
			n = my_n + 1
			if view != null:
				view.online_attesa(-1)
			return int(a.get("v", 0))
		var now := Time.get_ticks_msec()
		if role == "host" and not m.giocatori[s]["ia"] and polls % 4 == 0:
			var st := await net.seat(code, s)
			if not st.is_empty():
				var seen = st.get("seen", null)
				if seen != last_seen:
					last_seen = seen
					seen_t = now
				if st.get("away", false) or (now - seen_t > 45000 and now - t0 > 60000):
					await net.set_away(code, s, true)
					away[s] = true
					if view != null:
						view.online_attesa(-1)
						view.online_stato("%s non risponde: per ora gioca l'IA." % m.giocatori[s]["nome"])
					return await _pubblica(s, ia.scegli(m, s, req))
		polls += 1
		await get_tree().create_timer(1.2).timeout
	return ia.scegli(m, s, req)


func battito() -> void:
	while alive:
		net.heartbeat(code, seat)
		await get_tree().create_timer(5.0).timeout


func chiudi() -> void:
	if role == "host":
		net.set_status(code, "over")
	net.remember_room("")
