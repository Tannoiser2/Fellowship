class_name ControlloIA
extends RefCounted
## Le decisioni dei compagni IA in una partita su questo dispositivo: avvisa la vista e lascia decidere l'IA.

var vista
var ia: IA


func decide(m: Motore, posto: int, req: Dictionary):
	if vista != null:
		vista.mostra_pensiero(posto, req)
	var r = await ia.decide(m, posto, req)
	if ia.spiegazione != "":
		if vista != null and vista.has_method("nota_ia"):
			vista.nota_ia(ia.spiegazione)
		ia.spiegazione = ""
	return r
