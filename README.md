# Hearth

Everyday information on [Deadbeat](https://github.com/manuelnagele/deadbeat)'s bar for **WoW: Forever**: the
things you glance at between pulls, each where it matters.

## What it shows

The bar adapts to where you are (Deadbeat's contexts):

| Where | On the bar |
|---|---|
| Open world, cities | the zone, your gold and today's change (`+18g today`) |
| Raids | the raid, time inside, bosses killed this lockout (`5/8`); `no flask · no food` when you're missing them |
| Dungeons | the instance and time inside |

Small badges, each switchable per place on Deadbeat's Bar page:
- **Bags:** free slots (gold at 8 or fewer, red at 3 or fewer)
- **Durability:** your most worn item (gold below 50 %, red below 25 %)
- **World buffs:** Onyxia/Nefarian, Rend, Zandalar, Songflower, Darkmoon, Dire Maul, with time left
- **Mail:** an envelope when you have new mail
- **Latency:** a dot (green, gold, red)

Hover the bar for details: gold at the start of today and now, bags, the three most worn items, world buffs with exact
times, consumables, raid lockouts with progress and reset times, mail senders, latency and FPS.

## Settings

The gear on Deadbeat's bar → **Hearth**: the gold line in the world and cities, the raid line. Which badges show where:
Deadbeat's Bar page. `/hearth` opens the page.

## Install

Copy the `Hearth` folder into `World of Warcraft/_forever_/Interface/AddOns/`. Needs
[Deadbeat](https://github.com/manuelnagele/deadbeat).

## Development

```
luajit tests/run.lua     # the everyday math
luajit tests/smoke.lua   # the whole addon on Deadbeat (needs ../deadbeat)
```
Releases: push a tag `vX.Y.Z` matching the TOC's version; CI packages the zip onto GitHub Releases.
`deploy/` is the author's Linux setup that keeps a game install in sync with this repo (optional).

License: MIT.
