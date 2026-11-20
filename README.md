# XP Planner

**Your next XP, at a glance: quests, pickups, dungeons and training in one tracker.**

A quest tracker built for leveling. It shows what's worth doing right where you are, and points you to it.

## Highlights
- **Active Quests:** only what's left to do, highest level first, focused quest pinned.
- **Quests to Turn In:** everything ready to hand in, in its own section.
- **Zone / All switch:** one click between this zone and everywhere, on quests, turn-ins, nearby quests and dungeons.
- **Quests Nearby:** quests you can pick up, best XP first, with how far each quest giver is (in yards). With Questie, its own list (by its settings); without it, what the game's map offers. Click for a map waypoint.
- **Training:** what your trainer has for you, and what each city charges with your reputation (via What's Training).
- **Dungeons:** the ones that fit your level.
- **Smart zone filter:** follows the game's own quest map (and Questie, when installed), dungeons included.
- **Your way:** hide sections in dungeons or combat, replace Blizzard's tracker, FlareUI style.

## Quick start
1. Optional: **Questie** for richer quest pickups, **What's Training** for the Training section. XP Planner works without either.
2. Type `/xpp` to set it up; drag a heading to move the list when unlocked.

## Commands
| Command | Does |
|---|---|
| `/xpp` | Open settings |
| `/xpp lock` / `unlock` | Lock or move the list |
| `/xpp replace` | Replace Blizzard's quest tracker |
| `/xpp zone` | Why each quest counts as in this zone or not |
| `/xpp questie` | What XP Planner sees of Questie |

## Good to know
- With Questie, which quests show in Quests Nearby follows Questie's own settings (level, low-level, repeatable, dungeon and PvP quests).
- Without Questie, Quests Nearby uses the game map's nearby quests (no XP figures).
- Dungeon level ranges are the classic ones; WoW: Forever may differ.
- Works on English clients for dungeon zone matching.

## Recent changes
- **0.20.0:** Questie is optional: Quests to Pick Up is now Quests Nearby, with distances in yards; it follows Questie's own settings when installed, and the game map's nearby quests otherwise.
- **0.19.0:** Quest tracking ticks no longer hide or dim quests (the Zone / All switch decides); "Show every quest I can take" for Quests to Pick Up (any level you can take, repeatable, no XP). Quests above your level to accept no longer show.
- **0.18.1:** Your focused quest stays in Active Quests, even when it's ready to turn in.
- **0.18.0:** New Quests to Turn In section, with its own Zone / All switch.
- **0.17.0:** Training shows what each city charges with your reputation.
- **0.16.3:** Works with Questie's latest update again; new `/xpp questie` check.
- **0.16.2:** Click a quest to pick up for a map waypoint on its quest giver.
- **0.16.1:** Dungeon quests count inside the dungeon; hide sections in dungeons or combat; finished objectives hidden.
- **0.16.0:** Zone / All switch for Dungeons.
- **0.15.2:** Zone filter follows the game's quest map and your unfinished objectives.
