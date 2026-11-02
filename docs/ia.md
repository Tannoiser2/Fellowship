# IA dei compagni

## Come decide

1. **Missioni su più turni** (`scripts/core/missioni.gd`). A ogni turno ogni personaggio (tranne Frodo) ha una missione che tiene finché non è compiuta:
   - *azione*: andare nel luogo di un obiettivo che si compie con un'azione (Benedizione degli Elfi, Théoden, Denethor) e pagarne il costo; *compagno*: il secondo personaggio richiesto. Sul posto le carte che mancano passano di mano con la Compagnia.
   - *conquista*: radunare truppe (prima i colori che il personaggio recluta gratis), portarle alla roccaforte, attaccare, spendere 3 Valore.
   - *esercito*: riunire in un luogo le truppe chieste da un obiettivo (Sfidare Sauron: 2 Rohirrim, 2 Elfi, 3 Gondor), anche in due personaggi.
   - *liberare*: togliere le truppe ombra da una regione (Rohan per Saruman).
   - *presidio*: rinforzare un rifugio dove nei prossimi 3 turni arriveranno più truppe ombra dei difensori (stima dalle linee di battaglia e dalle carte Ombra non ancora uscite).
   - *difesa*: correre a un rifugio che può cadere già al prossimo turno.
   - *rifornire*: nella fase finale, portare a Frodo le carte Resistenza.
   I simboli che servono alle missioni sono tenuti da parte: le scelte libere non li spendono.
2. **Controllo con simulazioni** (`scripts/core/ia.gd`). La mossa proposta dalla missione è confrontata con le alternative migliori giocando su copie della partita il resto del turno, la pesca, le carte dell'Ombra e il turno seguente (3 volte, mazzi coperti rimescolati, dorso pubblico della carta Ombra in cima rispettato). La missione ha un vantaggio fisso: viene scartata solo se costa molto (un rifugio, speranza, Frodo esposto).
3. **Dopo un tiro** di combattimento si calcola l'esito con le facce reali; Valore e Resistenza si spendono solo se salvano un rifugio (le 5 Resistenze del finale di Frodo restano protette finché la speranza lo permette).
4. Nel registro della partita compaiono brevi note dell'IA (in grigio) sulle scelte decisive.

L'IA vede solo ciò che vede un giocatore: le carte in mano (scoperte per regola), gli scarti, la composizione del mazzo dell'Ombra ricavata dagli scarti e il dorso della carta in cima; non l'ordine dei mazzi.

## Banco di prova

```
godot --headless --path . -s tests/banco_ia.gd -- <politica> <configurazione> <primo_seme> <quante> <file.jsonl>
python3 tools/riassunto_banco.py file.jsonl ...
```

- politiche: `casuale` (mosse legali a caso), `base` (regole pratiche, niente simulazioni), `piena` (IA completa);
- configurazioni: `intro2` (2 giocatori, obiettivi e personaggi introduttivi), `solo` (solitario ufficiale introduttivo), `casuale3`;
- semi di sviluppo da 1000, semi di verifica da 5000 (non usati per regolare l'IA);
- i risultati sono in `tests/risultati/`.
