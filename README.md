# Bonus Roll Ledger

**TL;DR:** remembers every bonus roll you make, on every character (boss, difficulty, loot spec, result). Type **`/brl`** to see them. Past rolls are imported from Simulationcraft automatically.

Which spec did I bonus roll on for this boss? **Bonus Roll Ledger** remembers every bonus roll you make, on every character, so you can see it with one click.

Your **loot spec** decides the bonus roll loot table, and each boss only gives each item once per difficulty. Knowing which specs you've already rolled on for a boss tells you where your next Voidcore is best spent.

## Install

- **CurseForge:** [curseforge.com/wow/addons/bonus-roll-ledger](https://www.curseforge.com/wow/addons/bonus-roll-ledger), or search for *Bonus Roll Ledger* in the app.
- **Manual:** download the latest zip from the [Releases page](https://github.com/EnosDei/BonusRollLedger/releases) and extract the `BonusRollLedger` folder into `World of Warcraft/_retail_/Interface/AddOns/`.

## Using it

Open the panel with **`/brl`** (or `/bonusrolls`), or click **Bonus Roll Ledger** in the addon compartment by the minimap.

- **Summary:** one line per boss and difficulty with how many rolls you've used on each loot spec, e.g. *The Coiled Altar (Heroic): Blood 1, Unholy 3*.
- **Roll list:** newest first, with the date, boss, difficulty, loot spec and result. Hover an item for its tooltip; shift-click to link it in chat, ctrl-click to preview it.
- **Characters:** the panel opens on the character you're playing. Click the name at the top to look at any other character's rolls.
- Drag the window to move it; Esc closes it.

## What it records

Every bonus roll from the moment the addon is installed: items, gold, and empty rolls. Rolls are stored per character in the addon's saved variables.

**Earlier rolls:** if you use [Simulationcraft](https://www.curseforge.com/wow/addons/simulationcraft), it has quietly been logging bonus rolls that gave an item. Bonus Roll Ledger imports that history for all your characters when you log in, so your past rolls show up right away (no duplicates, however many times you log in).

## License

MIT. See [LICENSE](LICENSE).
