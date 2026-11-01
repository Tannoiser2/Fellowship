# Il destino della Compagnia — versione digitale

Versione digitale amatoriale di **The Lord of the Rings: Fate of the Fellowship** (Matt Leacock, Z-Man
Games, 2025; in italiano «Il Signore degli Anelli: Il destino della Compagnia») per la ludoteca: un gioco
cooperativo nel sistema di Pandemic in cui la Compagnia porta Frodo e Sam al Monte Fato, mentre i popoli
liberi difendono i rifugi dall'Ombra e sfuggono all'Occhio di Sauron e ai Nove.

Si gioca nel browser: https://tannoiser2.github.io/Fellowship/

## Che cosa c'è

- **Regole complete** del gioco base (regolamento v1.4): azioni (viaggiare con percorsi speciali e linee
  di battaglia, Compagnia, preparare, arruolare, attaccare, conquistare), pescate con **Il cielo si
  oscura**, carte dell'Ombra con avanzata e rinforzo decise dal dorso in cima al mazzo, battaglie e
  ricerche con i dadi e le loro modifiche, rifugi che cadono, limiti della riserva, eventi in qualsiasi
  momento.
- **Tutti i 13 personaggi** con le loro abilità (e Gandalf il Bianco), **tutti i 24 obiettivi** con le
  loro regole speciali, **14 eventi**, **5 difficoltà** e i **6 scenari consigliati**; obiettivi e
  personaggi casuali come nel regolamento.
- **Solitario** (Frodo e altri 4 personaggi con il segnalino), **hotseat**, **compagni IA** e **partite
  online** con gli amici (Firebase, radice `fellowship/rooms`).
- **Mappa 2D** dal tabellone del modulo TTS, con luoghi cliccabili, ingrandimento e descrizione di ogni
  luogo; **tavolo 3D** con le sagome dei personaggi in piedi, le truppe, i Nazgûl e l'Occhio di Sauron.
- **Carte dalle scansioni dell'edizione italiana** (Ombra, regione, eventi, Oscuramento dei Cieli,
  20 obiettivi su 24, personaggi e dorsi), con i nomi e i termini ufficiali (Radunare, roccaforti
  ombra, sentieri speciali, tiro di combattimento…); passando il mouse si vedono le carte grandi.
  Quattro obiettivi non erano fra le scansioni e restano in inglese: Mettere a Nudo le Fosse,
  «Non Più Fanciulla dello Scudo», Assicurare il Passaggio dell'Anduin, Gli Spergiuri Adempiono al
  Loro Dovere.

## Struttura

- `tools/locs.py`, `tools/graph.py`, `tools/loc_xy.json`, `tools/carte_ombra.json` — la mappa trascritta
  a mano dal tabellone (52 luoghi, 89 collegamenti, 14 percorsi speciali, 24 linee di battaglia) e le
  48 carte dell'Ombra; `tools/compila_dati.py` aggiunge carte, personaggi e obiettivi in italiano e
  produce `data/gioco.json`.
- `scripts/core/motore.gd` — il motore delle regole (deterministico: stesso seme e stesse scelte, stessa
  partita, anche online).
- `scripts/core/ia.gd` — i compagni IA: provano ogni azione su una copia della partita e scelgono quella
  che lascia la situazione migliore (speranza, pericolo per Frodo, rifugi, obiettivi).
- `scripts/ui/` — menu, partita, mappa 2D, tavolo 3D, regole in italiano.
- `scripts/net/` — gioco online in lockstep su Firebase.
- `tests/` — partite automatiche (`sim.gd`), partita con l'interfaccia e schermate (`vivo.gd`,
  `umano.gd`), prova online con finto Firebase (`online_play.gd`, `firebase_mock.py`).

## Prove

```
godot --headless --path . -s tests/sim.gd -- 20                 # partite solo IA
xvfb-run godot --path . -s tests/vivo.gd -- /tmp/vivo          # schermate di menu, mappa, 3D, regole
xvfb-run godot --path . -s tests/umano.gd -- /tmp/umano 6      # una persona che preme i pulsanti
python3 tools/controlla_glifi.py                                # nessun carattere mancante nei font
```

## Pubblicazione

Il workflow `Pubblica` parte solo a mano (Actions → Pubblica → Run workflow) oppure con un commit su
`main` il cui messaggio contiene `[pubblica]`. Pubblica su GitHub Pages e, se ci sono i segreti
`CLOUDFLARE_API_TOKEN` e `CLOUDFLARE_ACCOUNT_ID`, sulla ludoteca privata
(`fellowship.ludoteca-digitale.com`).

## Scansioni italiane

Le carte sono in `assets/carte/` con il numero del modulo TTS (`<numero>.webp`): le scansioni sono state
ritagliate e abbinate automaticamente confrontandole con le carte del modulo, poi controllate a vista.
Per i quattro obiettivi mancanti basta salvare la scansione come 4201, 4212, 4215 e 4219.

## Materiale

Carte dalle scansioni dell'edizione italiana; tabellone e pedine dal modulo Tabletop Simulator «The Lord of the Rings: Fate of the Fellowship [Scripted]».
Font: Cinzel, Cinzel Decorative e Alegreya (SIL Open Font License). Uso personale e non commerciale.
