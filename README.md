# Forever Junk Items

<img src="docs/logo.png" alt="Forever Junk Items logo" width="160">

**Stop filling your bags with junk.** Forever Junk Items loots enemies for
you and leaves the worthless stuff on the corpse, so your bags last much
longer between trips to a vendor. Made for **WoW Forever**.

## What it picks up

- **Gold**, always.
- **Quest items**, always.
- **Everything white or better**: cloth, leather, meat, herbs, potions,
  green, blue and purple gear.
- **Grey items worth something**: a grey item is picked up only when it
  sells for at least the amount you choose (5 silver by default, counting
  the whole stack).

Grey items worth less than that stay on the corpse.

## When your bags are almost full

When only a few free slots are left (4 by default), Forever Junk Items gets
choosier. It still picks up:

- quest items and everything green or better,
- the **materials for your own professions**, for example Linen Cloth if you
  are a tailor or Copper Ore if you are a miner,
- **bags**, since they give you more room,
- anything that fits on a stack you already carry.

Everything else stays on the corpse until you make room.

## Skinning, mining and herbalism

A corpse can only be skinned once it is empty. If you can skin (or mine, or
gather herbs from) a corpse, Forever Junk Items empties it completely so you
can skin it straight away. You can turn this off in the options.

## Chests, herbs, ore and fishing

Only enemy corpses are filtered. Chests, herbs, ore veins, fishing and the
containers you open in your bags are always emptied completely.

## Taking everything

Hold **Shift** while you loot a corpse to take everything on it, junk
included.

## Options

Type **/fji** or click the **minimap button** to open the options
(right-click the button to turn the filter on or off):

- turn the filter on or off,
- the value a grey item needs to be picked up,
- how many free bag slots make the add-on choosier,
- empty corpses you can skin, mine or gather from,
- a short chat line listing what was left behind,
- a chime when a **rare (blue) or better** item drops, so you do not miss it,
- your **Always loot** and **Never loot** lists: drag an item from your bags
  onto a list, click it on the list to remove it,
- show or hide the minimap button.

The window also shows the professions it found for your character and how
many items it has left behind this session.

## Good to know

- Forever Junk Items does the looting for you, so the game's own Auto Loot
  option is switched off while the add-on is on. Turn the add-on off
  (`/fji off` or in the options) and the game's Auto Loot comes back as it
  was.
- When you are in a group, items up for a roll, master loot choices and
  items that bind when picked up open the normal loot window, so you decide.
- If an item can't be judged (the game hasn't told the add-on what it is
  worth yet), it is picked up: nothing useful is ever left behind by
  mistake.

## Commands

| Command | What it does |
|---|---|
| `/fji` | open the options |
| `/fji on` / `/fji off` | turn the filter on or off |
| `/fji status` | show your settings and professions |
| `/fji always <item>` | always loot an item (shift-click the item into the chat line) |
| `/fji never <item>` | never loot an item |
| `/fji remove <item>` | take an item off both lists |
| `/fji minimap` | show or hide the minimap button |
| `/fji sound` | hear the rare item sound; `/fji sound on` / `off` turns it on or off |

## Installation

1. Install **Forever Junk Items** with the CurseForge app, or download the
   ZIP and extract it into `World of Warcraft\_forever_\Interface\AddOns\`.
2. Log in. The first time, a chat line confirms it is working.

## Feedback

Bug reports and ideas are welcome on
[GitHub Issues](https://github.com/DoctorB/forever-junk-items/issues).

## License

MIT, see [LICENSE](LICENSE). The profession material lists are generated
from WoW Forever's own game data.
