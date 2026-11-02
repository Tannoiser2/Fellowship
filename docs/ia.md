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

## Prove scartate (2 novembre 2026)

Provate e misurate, poi tolte perché sui semi di verifica 5000-5019 non miglioravano (test3_*.jsonl contro test2_dopo_*.jsonl):
- esercito che prende truppe già sulla mappa (lasciando 1-2 truppe nei rifugi) e tiene la posizione mentre un compagno porta il resto;
- numero di presidi proporzionale alla minaccia totale (da 1 a 3) e soglia più bassa;
- Frodo compagno per la Benedizione quando parte insieme a chi la compie (sui semi di sviluppo: Benedizione da 14 a 10 su 20, partite più corte per le ricerche).
Risultato in verifica: 2 giocatori Benedizione 14 (prima 15), Saruman 7 (prima 9), rifugi persi 1,60 (prima 1,40); solitario rifugi persi 2,05 (prima 1,60).

## Ricerca di sequenze intere (sperimentale, spenta: `cerca_piani = false`)

Per i blocchi di 2-4 azioni l'IA può cercare la sequenza migliore con una ricerca a fascio (4 sequenze per passo, tutte le azioni legali, le azioni con dadi provate due volte tenendo l'esito peggiore), poi giocare le 5 sequenze migliori fino al turno dopo (o ai due turni dopo) 3-4 volte con i mazzi rimescolati. Frodo e chi viaggia con lui ne sono esclusi.
Misure sui semi di sviluppo 1000-1019 (20 partite per configurazione), confronto con l'IA del gioco (`missioni`):

| | 2 giocatori: Benedizione / Saruman / rifugi persi / turni | solitario: Benedizione / Saruman / rifugi persi / turni |
|---|---|---|
| missioni (IA del gioco) | 15 / 6 / 1,70 / 16,9 | 14 / 8 / 1,90 / 16,8 |
| sequenze, 1 turno dopo (v10, Frodo incluso) | 12 / 5 / 1,20 / 14,6 | 13 / 4 / 2,05 / 15,8 |
| sequenze, 1 turno dopo (v11) | 16 / 5 / 1,50 / 18,2 | 15 / 6 / 1,85 / 16,9 |
| sequenze, 2 turni dopo (v12) | 14 / 3 / 1,25 / 15,9 | 13 / 2 / 1,50 / 16,0 |

Vittorie 0/20 in tutte le prove. Guardare più avanti difende un po' meglio i rifugi ma chiude meno obiettivi: la ricerca ottimizza la valutazione della posizione, che non è ancora allineata alla vittoria.
