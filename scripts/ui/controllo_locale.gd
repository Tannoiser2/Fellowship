class_name ControlloLocale
extends RefCounted
## Le decisioni dei posti giocati da una persona su questo dispositivo: le mostra la vista di gioco.

var vista


func decide(m: Motore, posto: int, req: Dictionary):
	return await vista.chiedi_persona(m, posto, req)
