class_name Dati
extends RefCounted
## Dati di gioco (data/gioco.json): mappa, linee di battaglia, carte, personaggi e obiettivi.

static var _d: Dictionary = {}
static var _adj: Dictionary = {}
static var _reg_adj: Dictionary = {}
static var _carte: Dictionary = {}

const SIMBOLI := ["amicizia", "valore", "furtivita", "resistenza"]
const NOMI_SIMBOLI := {"amicizia": "Amicizia", "valore": "Valore", "furtivita": "Furtività", "resistenza": "Resistenza"}
const ARMATE := ["gondor", "rohirrim", "elfi", "nani"]
const NOMI_ARMATE := {"gondor": "Gondor", "rohirrim": "Rohirrim", "elfi": "Elfi", "nani": "Nani"}
const FACCE_BATTAGLIA := ["rotta", "rotta", "scambio", "scambio", "travolti", "nazgul"]
const FACCE_RICERCA := ["sfuggito", "sfuggito", "stanchezza", "stanchezza", "scoperto", "richiamo"]
const NOMI_FACCE := {"rotta": "Rotta", "scambio": "Scambio", "travolti": "Travolti", "nazgul": "Nazgûl!",
	"sfuggito": "Sfuggito", "stanchezza": "Stanchezza", "scoperto": "Scoperto", "richiamo": "Richiamo"}
## valori della traccia della minaccia (si parte dal primo spazio)
const MINACCIA := [2, 2, 3, 3, 4, 4, 5]
const SPERANZA_MAX := 8
const SPERANZA_INIZIO := 6


static func d() -> Dictionary:
	if _d.is_empty():
		var f := FileAccess.open("res://data/gioco.json", FileAccess.READ)
		_d = JSON.parse_string(f.get_as_text())
		for c in _d["carte_regione"]:
			c["tipo"] = "regione"
			_carte[int(c["id"])] = c
		for c in _d["carte_evento"]:
			c["tipo"] = "evento"
			_carte[int(c["id"])] = c
		for c in _d["carte_cieli"]:
			c["tipo"] = "cieli"
			_carte[int(c["id"])] = c
		for c in _d["carte_ombra"]:
			c["tipo"] = "ombra"
			_carte[int(c["id"])] = c
		for o in _d["obiettivi"]:
			o["tipo"] = "obiettivo"
			_carte[int(o["id"])] = o
		for l in _d["luoghi"]:
			_adj[l] = {}
		for e in _d["collegamenti"]:
			_adj[e["a"]][e["b"]] = e
			_adj[e["b"]][e["a"]] = e
		for r in _d["regioni"]:
			_reg_adj[r] = {}
		for e in _d["collegamenti"]:
			var ra: String = _d["luoghi"][e["a"]]["regione"]
			var rb: String = _d["luoghi"][e["b"]]["regione"]
			if ra != rb:
				_reg_adj[ra][rb] = true
				_reg_adj[rb][ra] = true
	return _d


static func luoghi() -> Dictionary:
	return d()["luoghi"]


static func luogo(id: String) -> Dictionary:
	return d()["luoghi"][id]


static func nome(id: String) -> String:
	return d()["luoghi"][id]["nome"]


static func regione(id: String) -> String:
	return d()["luoghi"][id]["regione"]


static func nome_regione(r: String) -> String:
	return d()["regioni"][r]["nome"]


static func vicini(id: String) -> Dictionary:
	d()
	return _adj[id]


static func collegamento(a: String, b: String) -> Dictionary:
	d()
	return _adj[a].get(b, {})


static func regioni_vicine(r: String) -> Array:
	d()
	return _reg_adj[r].keys()


static func carta(id: int) -> Dictionary:
	d()
	return _carte.get(id, {})


static func linea(lid: String) -> Dictionary:
	return d()["linee"][lid]


static func personaggio(pid: String) -> Dictionary:
	return d()["personaggi"][pid]


static func obiettivo(codice: String) -> Dictionary:
	for o in d()["obiettivi"]:
		if o["codice"] == codice:
			return o
	return {}


## Distanza fra regioni (numero di confini da attraversare).
static func distanza_regioni(a: String, b: String) -> int:
	if a == b:
		return 0
	d()
	var seen := {a: 0}
	var coda := [a]
	while not coda.is_empty():
		var x: String = coda.pop_front()
		for y in _reg_adj[x]:
			if not seen.has(y):
				seen[y] = seen[x] + 1
				if y == b:
					return seen[y]
				coda.append(y)
	return 99


## Distanza fra luoghi in numero di passi (tutti i collegamenti).
static func distanze_da(a: String) -> Dictionary:
	d()
	var seen := {a: 0}
	var coda := [a]
	while not coda.is_empty():
		var x: String = coda.pop_front()
		for y in _adj[x]:
			if not seen.has(y):
				seen[y] = seen[x] + 1
				coda.append(y)
	return seen
