# Pubblicazione su CurseForge - contenuti del modulo

Testi pronti da incollare nel modulo di CurseForge (Create Project, poi Upload
File). CurseForge richiede titoli e descrizioni **in inglese**: i campi da
incollare sono in inglese, le note per chi pubblica in italiano.

Il progetto si crea a mano sul sito (sezioni 1 e 2). I file li carica il
workflow `.github/workflows/release.yml` al push di un tag `v*`
(`docs/RELEASING.md`); la sezione 3 riporta cosa imposta.

## 1. Progetto

| Campo | Valore |
|---|---|
| Game | World of Warcraft |
| Class | Addons |
| Name | `Forever Junk Items` |
| Summary | vedi sotto |
| Main category | Bags & Inventory |
| Additional categories | Professions, Quests & Leveling (solo categorie pertinenti) |
| License | MIT License |
| Logo | `docs/logo.png` (1254×1254 PNG, 1:1; minimo richiesto 400×400) |
| Source | `https://github.com/DoctorB/forever-junk-items` |
| Issues | `https://github.com/DoctorB/forever-junk-items/issues` |

### Summary

```text
Loots for you and leaves worthless junk on enemy corpses, so your bags last longer. Quest items, everything white or better and your profession materials are always picked up.
```

## 2. Description

Incollare nell'editor della descrizione in modalità Markdown.

```markdown
# Forever Junk Items

**Stop filling your bags with junk.**

Forever Junk Items loots enemies for you and leaves the worthless stuff on
the corpse, so your bags last much longer between trips to a vendor.

## What it picks up

- **Gold** and **quest items**, always.
- **Everything white or better**: cloth, leather, meat, herbs, potions and
  every green, blue or purple item.
- **Grey items worth something**: only when they sell for at least the
  amount you choose (5 silver by default, counting the whole stack).

Worthless grey items stay on the corpse.

## When your bags are almost full

With only a few free slots left, it gets choosier and keeps picking up just:

- quest items and everything green or better,
- the **materials for your own professions** (Linen Cloth for a tailor,
  Copper Ore for a miner...),
- **bags**, since they give you more room,
- anything that fits on a stack you already carry.

## Ready to skin

A corpse can only be skinned once it is empty. If you can skin, mine or
gather from a corpse, Forever Junk Items empties it completely so you can
use your profession straight away.

## Only enemies are filtered

Chests, herbs, ore veins, fishing and the containers you open in your bags
are always emptied completely. Hold **Shift** while looting to take
everything from a corpse, junk included.

## Your rules

Type **/fji** or click the **minimap button** to open the options
(right-click it to turn the filter on or off):

- the value a grey item needs to be picked up,
- how many free slots make it choosier,
- empty corpses you can skin, mine or gather from,
- a short chat line listing what was left behind,
- a chime when a **rare (blue) or better** item drops, so you do not miss it,
- **Always loot** and **Never loot** lists: drag an item from your bags onto
  a list.

## Good to know

- Forever Junk Items does the looting for you, so the game's Auto Loot
  option is switched off while it is on, and comes back as it was when you
  turn the add-on off.
- In a group, roll items, master loot and bind-on-pickup items open the
  normal loot window so you decide.
- An item the game hasn't described yet is always picked up: nothing useful
  is left behind by mistake.

## Commands

- `/fji` - options
- `/fji on` / `/fji off` - turn the filter on or off
- `/fji status` - your settings and professions
- `/fji always <item>` / `/fji never <item>` / `/fji remove <item>` - your lists
- `/fji minimap` - show or hide the minimap button
- `/fji sound` - hear the rare item sound (`/fji sound on` / `off`)

## Feedback

Bug reports and ideas are welcome on
[GitHub Issues](https://github.com/DoctorB/forever-junk-items/issues).
```

## 3. File (caricato dal workflow)

| Campo | Valore |
|---|---|
| File | ZIP verificato costruito dal workflow (`scripts/release.py package`) |
| Display Name | `Forever Junk Items <versione>` (es. `1.1.0`) |
| Release Type | dal suffisso della versione: senza suffisso **Release**, `-beta.N` Beta, `-alpha.N` Alpha. L'app CurseForge sincronizza un progetto solo dopo il primo file Release |
| Supported Version | la versione **Forever** del client 1.60.1 (Interface `16001`) |
| Related Projects | nessuno |
| Changelog | la sezione della versione in `CHANGELOG.md` |

## 4. Prima di pubblicare

- **Prove in gioco**: [RUNTIME_CHECKLIST.md](RUNTIME_CHECKLIST.md). Da lì la
  scelta tra Release e Beta per la 1.0.0.
- **Logo**: `docs/logo.png` (1254×1254). Se cambia, `python scripts/make_icon.py`
  rigenera l'icona del gioco (`Media/icon.tga`, 64×64).
- Dopo il rilascio: sincronizzare la pagina su lucabottani.dev.
