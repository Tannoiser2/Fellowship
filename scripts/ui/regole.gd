extends Control
## Regolamento in italiano, in breve (dal regolamento originale v1.4).

var main
var finestra := false

const REGOLE := """[font_size=28][color=#dcb05c]Lo scopo[/color][/font_size]
Il gioco è cooperativo: vincete o perdete tutti insieme. Vincete quando Frodo completa l'obiettivo [b]Distruggere l'Unico Anello[/b], che si può tentare solo dopo aver completato tutti gli altri obiettivi della partita. Perdete se la [b]speranza[/b] di Frodo arriva a 0.

[font_size=28][color=#dcb05c]Il turno[/color][/font_size]
[b]1. Azioni.[/b] Fai fino a 4 azioni con uno dei tuoi personaggi e fino a 1 con l'altro (prima tutte quelle di uno, poi quelle dell'altro).
[b]2. Pesca 2 carte giocatore.[/b] Il limite della mano è 7 carte. Se peschi [b]Il cielo si oscura[/b]: la minaccia sale di 1; se l'Occhio è già sulla regione di Frodo perdete 2 speranza, altrimenti l'Occhio va lì; 3 truppe dell'Ombra arrivano nel luogo indicato (con battaglia se ci sono truppe amiche); gli scarti dell'Ombra si rimescolano sopra il mazzo. Se il mazzo è finito, -1 speranza per ogni carta che non potete pescare.
[b]3. Carte dell'Ombra.[/b] Se ne girano tante quante dice la traccia della minaccia. Di ogni carta si risolve una sola metà, decisa dal dorso della carta che ora è in cima al mazzo: [b]bandiera rossa[/b]: la metà sopra (avanzata); [b]stendardo nero[/b]: la metà sotto (rinforzo).

[font_size=28][color=#dcb05c]Le azioni[/color][/font_size]
[b]Viaggiare[/b]: vai in un luogo collegato, portando con te se vuoi gli altri personaggi e le truppe amiche del luogo. I [b]percorsi speciali[/b] costano i simboli stampati. Quando viaggia Frodo si spende 1 Furtività oppure si tira una [b]ricerca[/b] nel luogo d'arrivo.
[b]Compagnia[/b]: con un personaggio di un altro giocatore nello stesso luogo, date o prendete una carta della regione in cui vi trovate (non i segnalini). Non si usa in solitario.
[b]Preparare[/b]: in un rifugio scarta una carta regione e prendi il segnalino con il suo simbolo. In solitario la carta deve essere della regione in cui ti trovi.
[b]Arruolare[/b]: in un luogo con il simbolo di Gondor, Rohirrim, Elfi o Nani spendi 1 Amicizia e aggiungi una truppa di quel colore.
[b]Attaccare[/b]: dove ci sono truppe amiche e dell'Ombra, l'Occhio si sposta in quella regione e tiri da 1 a 3 dadi di battaglia (al massimo uno per truppa amica).
[b]Conquistare[/b]: in una fortezza dell'Ombra senza truppe dell'Ombra e con almeno una truppa amica, spendi 3 Valore. Diventa un rifugio, l'Occhio va lì e guadagnate 2 speranza. Moria, Isengard, Dol Guldur e Umbar conquistate non ricevono più rinforzi.
Gli [b]eventi[/b] si giocano in qualsiasi momento e non costano azioni.

[font_size=28][color=#dcb05c]I simboli[/color][/font_size]
Si spendono scartando una carta regione con quel simbolo o restituendo un segnalino. [b]Amicizia[/b]: arruolare. [b]Valore[/b]: in battaglia toglie 1 truppa dell'Ombra; 3 per conquistare. [b]Furtività[/b]: Frodo viaggia senza ricerca. [b]Resistenza[/b]: ritira un dado di battaglia o di ricerca; Frodo ne spende 5 al Monte Fato (ce ne sono solo 12 in tutto il gioco!).

[font_size=28][color=#dcb05c]Battaglie[/color][/font_size]
Un attacco tira 1 dado per truppa amica (da 1 a 3); una battaglia causata dall'Ombra tira 1 dado per truppa dell'Ombra (massimo 3). [b]Rotta[/b]: -1 truppa dell'Ombra. [b]Scambio[/b]: -1 dell'Ombra e -1 amica. [b]Travolti[/b]: -1 amica (non nei rifugi). [b]Nazgûl![/b]: se ci sono Nazgûl nella regione, -2 amiche. Dopo il tiro i personaggi presenti possono spendere Resistenza per ritirare dadi e Valore per togliere truppe dell'Ombra. Se in un rifugio restano truppe dell'Ombra e nessuna amica, il rifugio cade: diventa una fortezza dell'Ombra e perdete 3 speranza.

[font_size=28][color=#dcb05c]Ricerche[/color][/font_size]
Si tira 1 dado per ogni Nazgûl nella regione di Frodo e per ogni truppa dell'Ombra nel suo luogo (al massimo 7). [b]Sfuggito[/b]: niente. [b]Stanchezza[/b]: -1 speranza. [b]Scoperto[/b]: -1 speranza, ma non in un rifugio. [b]Richiamo[/b]: un Nazgûl della regione torna a Mordor. I personaggi presenti possono spendere Resistenza per ritirare dadi.

[font_size=28][color=#dcb05c]L'Ombra[/color][/font_size]
[b]Avanzata[/b]: le truppe dell'Ombra sulla linea di battaglia indicata avanzano di un luogo (prima quelle più avanti), poi si combatte dove incontrano truppe amiche. [b]Rinforzo[/b]: +1 truppa dell'Ombra nel luogo indicato (con battaglia se ci sono truppe amiche), poi un ordine: l'Occhio si volge sulla regione di Frodo (se c'è già, ricerca), 2 Nazgûl si avvicinano a Frodo, oppure 3 Nazgûl vanno da Mordor all'Occhio (se l'Occhio è su Mordor, ne tornano 3 a Mordor). Se mancano truppe dell'Ombra nella riserva, -1 speranza per ognuna.

[font_size=28][color=#dcb05c]Il Monte Fato[/color][/font_size]
Completati gli altri obiettivi, Frodo al Monte Fato spende 5 Resistenza e affronta una ricerca finale con 1 dado in più per ogni speranza mancante (massimo 7). Se resta almeno 1 speranza, avete vinto!

[font_size=28][color=#dcb05c]Difficoltà e solitario[/color][/font_size]
Introduttiva: 4 «Il cielo si oscura», 4 obiettivi. Standard: 5 e 4. Eroica: 5 e 5. Epica: 6 e 5. Leggendaria: 6 e 6.
In solitario guidi Frodo e Sam e altri 4 personaggi, che hanno a turno il segnalino: chi lo ha fa 4 azioni, Frodo 1. La mano è unica.

[font_size=28][color=#dcb05c]In questa versione[/color][/font_size]
Le scelte compaiono nel pannello in basso (anche con i tasti 1–9); si può cliccare direttamente sui luoghi evidenziati della mappa. Passa il mouse su carte, personaggi e obiettivi per leggerli; su un luogo per vedere truppe e collegamenti. La rotellina ingrandisce la mappa, trascinando la si sposta. La partita si salva da sola: dal menu si può continuare.
"""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if finestra:
		var fondo := ColorRect.new()
		fondo.color = Color(0, 0, 0, 0.65)
		fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(fondo)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right"]:
		m.add_theme_constant_override("margin_" + s, 160)
	for s in ["top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 30)
	add_child(m)
	var p := UI.pannello(Color(0.10, 0.08, 0.05, 0.98), UI.ORO)
	m.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var h := HBoxContainer.new()
	v.add_child(h)
	h.add_child(UI.titolo("Le regole in breve", 46))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	var b := UI.bottone("Chiudi" if finestra else "Torna al menu", 21)
	b.pressed.connect(_chiudi)
	h.add_child(b)
	var t := RichTextLabel.new()
	t.bbcode_enabled = true
	t.size_flags_vertical = Control.SIZE_EXPAND_FILL
	t.add_theme_font_size_override("normal_font_size", 20)
	t.add_theme_font_size_override("bold_font_size", 20)
	t.text = REGOLE
	v.add_child(t)


func _chiudi() -> void:
	if finestra:
		queue_free()
	else:
		main.show_menu()
