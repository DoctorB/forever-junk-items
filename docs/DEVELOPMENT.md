# Sviluppo

## Struttura

- `ForeverJunkItems/` è l'add-on installabile (solo ciò che va nello ZIP, in ordine di TOC).
  - `Core/Rules.lua`: le regole (pura, nessuna chiamata al client).
  - `Core/Looter.lua`: il flusso del loot (`LOOT_READY` → piano → `LootSlot` → chiusura).
  - `Core/Bags.lua`, `Core/Professions.lua`, `Core/Corpse.lua`: letture dal client.
  - `Core/Control.lua`: on/off e opzione Auto Loot del gioco.
  - `Data/Materials.lua`: **generato**, non modificare a mano.
- `tests/`: suite offline Lua 5.1 su un client finto (`tests/harness/wow.lua`) e test Python
  di packaging e rilascio. `tests/run.ps1` esegue tutto (come la CI).
- `scripts/`: `package.py` (ZIP riproducibile), `release.py` (gate e upload CurseForge),
  `check_attribution.py`, `make_materials.py`, `make_icon.py`.

## Dati delle professioni

`python scripts/make_materials.py --build <build>` scarica da wago.tools le tabelle del
client Forever (prodotto `wowf`: SkillLine, SkillLineAbility, SpellReagents, Item) e
rigenera `Data/Materials.lua`: un materiale appartiene a una professione se una sua
ricetta lo consuma; Herbalism, Skinning e Mining possiedono anche ciò che raccolgono
(sottoclassi Trade Goods 9, 6, 7). Le tabelle restano in `.cache/` (ignorata da git).
Da rifare a ogni patch di Forever; build attuale nell'intestazione del file.

## Icona

`docs/logo.png` è il logo (CurseForge e README). `python scripts/make_icon.py` ne ricava
`Media/icon.tga` (64×64, TGA 32 bit non compresso).

## Prima di ogni commit

```
powershell -File tests/run.ps1
python scripts/check_attribution.py HEAD
python scripts/package.py build
```
