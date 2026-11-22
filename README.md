# Hearth

Everyday items on [Deadbeat](https://github.com/manuelnagele/deadbeat)'s bar for **WoW: Forever**: the
things you glance at between pulls, each where it matters.

## What it shows

Hearth's items on the bar (each with its own tooltip; right-click for settings):

| Item | Shows | By default in |
|---|---|---|
| **Gold** | your gold, green when you're up today | world, cities |
| **Bags** | free slots (gold at 8 or fewer, red at 3); click opens your bags | everywhere |
| **Durability** | your most worn item (gold below 50 %, red below 25 %) | world, dungeons, farming |
| **Raid** | bosses killed this lockout and time inside (`5/8 · 0:42`) | raids |
| **Flask and food** | `ready`, or what's missing in red | raids |

On the shelf, to add in edit mode: **world buffs** (Onyxia/Nefarian, Rend, Zandalar, Songflower, Darkmoon, Dire Maul,
with minutes left), **mail**, **latency** (a dot), **time in a dungeon**.

Tooltips: gold at the start of today and now; free slots; the three most worn items; raid lockouts with their resets;
flask and food; each world buff with its time; mail senders; latency and frame rate.

## Settings

Arrange Hearth's items in Deadbeat's edit mode (right-click the gear); which places each shows in: Deadbeat's Bar
page. `/hearth` opens Hearth's page.

## Install

Copy the `Hearth` folder into `World of Warcraft/_forever_/Interface/AddOns/`. Needs
[Deadbeat](https://github.com/manuelnagele/deadbeat) 2.0 or later.

## Development

```
luajit tests/run.lua     # the everyday math
luajit tests/smoke.lua   # the whole addon on Deadbeat (needs ../deadbeat and ../deadbeat-spec)
```
Releases: push a tag `vX.Y.Z` matching the TOC's version; CI packages the zip onto GitHub Releases.
`deploy/` is the author's Linux setup that keeps a game install in sync with this repo (optional).

License: MIT.
