# Prove in gioco (1.0.0)

Le suite offline coprono le regole e il flusso con un client finto. Queste
sono le cose che solo il client WoW Forever può confermare. Ogni riga:
cosa fare, cosa deve succedere. Segnare data ed esito.

La fattibilità si basa sul codice di add-on Forever già pubblicati
(`LOOT_READY`, `GetLootSlotInfo`, `LootSlot`, `LootFrame:UnregisterEvent`
usati su Interface 16001), non su prove nostre.

| # | Prova | Atteso | Esito |
|---|---|---|---|
| 1 | Primo login con l'add-on | Riga in chat "now loots for you..."; Interfaccia → Controlli: Auto Loot disattivato | Riga in chat OK (2026-11-18, screenshot); opzione Auto Loot da guardare |
| 2 | Uccidere un mob con un grigio sotto i 5s e un bianco | Bianco e soldi in borsa, grigio resta nel cadavere (luccica ancora), nessuna finestra di loot, riga "left behind" in chat | |
| 3 | Ri-aprire quel cadavere | Si vede solo il grigio; si chiude da solo | |
| 4 | Shift + click sul cadavere | Raccoglie tutto, grigio compreso | |
| 5 | `/fji off` | Auto Loot del gioco torna come prima (attivo se lo era) | |
| 6 | Grigio da 5s o più | Raccolto | |
| 7 | Borse con 4 slot liberi o meno, mob con stoffa e un bianco qualsiasi | Sarto: stoffa raccolta, bianco lasciato | |
| 8 | Scuoiatore su un mob scuoiabile con grigi | Cadavere svuotato del tutto e scuoiabile subito | |
| 9 | Stesso mob senza Skinning | Grigio lasciato | |
| 10 | Erba, vena, cassa, pesca | Tutto raccolto | |
| 11 | Oggetto BoP (verde/blu) | Si apre la finestra di loot con la domanda di conferma | |
| 12 | Gruppo con oggetto in tiro | Finestra di loot normale | |
| 13 | Borse piene, verde nel cadavere | Riga rossa "no room in your bags for ..." | |
| 14 | `/fji` | Finestra opzioni: professioni rilevate, - e + funzionano, trascinare un oggetto su "Always loot" lo aggiunge, clic sulla riga lo toglie | 2026-11-18: finestra OK, professioni "None found" (corretto in c6fccdc: su Forever si leggono con GetProfessions); da ricontrollare |
| 15 | Header "Professions" chiuso nella finestra abilità (K) | Le professioni restano quelle viste prima | |
| 16 | Primo grigio mai visto dall'avvio del gioco | Deciso dopo un attimo (prezzo non in cache), nessun errore | |
| 17 | Logout e login con l'add-on attivo | Dopo il login l'Auto Loot del gioco è di nuovo spento e il filtro funziona (al logout il valore originale viene rimesso per chi disinstalla) | |
| 18 | Mob ucciso mentre si guarda un altro cadavere scuoiabile | Il filtro usa il cadavere giusto | |

## Punti da osservare

- **Tooltip "Skinnable"**: il riconoscimento usa le stringhe
  `UNIT_SKINNABLE_*` del client e `GetLootSourceInfo`. Se su Forever i testi
  o le funzioni differiscono, la prova 8 fallisce in modo sicuro (il grigio
  resta, il cadavere non è scuoiabile): annotare il testo esatto del tooltip.
- **Finestra di loot**: se una volta compare per un istante e sparisce, è il
  caso in cui `LOOT_OPENED` arriva prima di `LOOT_READY`; annotarlo.
