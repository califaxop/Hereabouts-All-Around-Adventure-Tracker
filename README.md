# Hereabouts: All-Around Adventure Tracker

**Your quest tracker, filtered to where you are.**

Hereabouts shows only the quests you can work on in the zone you're in, judged by where their objectives and turn-ins are, not just the quest log heading. It also shows what to hand in, what to train and which dungeons fit your level. It works on its own; Questie and What's Training add more.

## Highlights
- **Zone-aware tracking:** active quests with objectives here, and quests ready to turn in here. One click on Zone / All switches to everywhere.
- **No tracking limit:** the zone filter decides what shows, not Blizzard's tracked-quest cap.
- **Quests to Turn In:** everything ready to hand in, in its own section.
- **Quests Nearby** (with Questie): the best-XP quests to pick up, with how far each quest giver is in yards and a one-click waypoint. Follows Questie's own settings.
- **Training** (with What's Training): what your trainer has for you, and what each city charges with your reputation.
- **Quest item buttons:** one click (or a keybind) for the usable items of your quests in this zone, focused quest first.
- **Session bars:** slim bars under the tracker: XP per hour and time to level, gold per hour and this session, XP and quests this session, rested XP. Your pick.
- **Dungeons:** the ones that fit your level, here or everywhere.
- **Your way:** hide sections in dungeons or combat, replace Blizzard's tracker, FlareUI style.

## What each add-on unlocks
| | On its own | + Questie | + What's Training |
|---|---|---|---|
| Active Quests, Quests to Turn In | Yes, via the game's quest map | Sharper zone matching | |
| Dungeons | Yes | | |
| Quests Nearby | | Yes | |
| Training | | | Yes |

## Quick start
1. Optional: install **Questie** and **What's Training** (see the table above).
2. Type `/hab` to set it up; drag a heading to move the list when unlocked.

## Commands
| Command | Does |
|---|---|
| `/hab` (or `/hereabouts`) | Open settings |
| `/hab lock` / `unlock` | Lock or move the list |
| `/hab replace` | Replace Blizzard's quest tracker |
| `/hab zone` | Why each quest counts as in this zone or not |
| `/hab session` | Reset the session bar's numbers |
| `/hab questie` | What Hereabouts sees of Questie |

## Good to know
- With Questie, which quests show in Quests Nearby follows Questie's own settings (level, low-level, repeatable, dungeon and PvP quests).
- Without Questie there's no Quests Nearby: the game itself doesn't list quests you could pick up.
- Dungeon level ranges are the classic ones; WoW: Forever may differ.
- Works on English clients for dungeon zone matching.

## Updates
New versions come out every **Wednesday at 12:00 UTC** (8 PM Philippine time, 8 AM US Eastern). Urgent fixes ship sooner.

## Feedback
Found a bug or have an idea? [Open an issue](https://github.com/califaxop/Hereabouts-All-Around-Adventure-Tracker/issues/new/choose): there's a short form for each. The settings window has a "Feedback" button with this link too.

## Recent changes
- **1.3.0:** In combat, the quest of what you're fighting (to kill it, or for what it drops) is marked light blue and moved to the top of Active Quests, with the objective it counts for lit up: your target first, else the enemies fighting you (from their nameplates, so a mob that jumps you counts too). Back to normal when combat ends (Lists, "In combat: mark my enemy's quests", on by default).
- **1.2.1:** Session stats survive a `/reload`: they only start over when you log in again (or reset them yourself).
- **1.2.0:** Cleaner section headings: the title with one bronze line under it, the game's own +/- to collapse, and Zone / All as a proper button. Prefer the earlier look? Tick "Classic section headings" in /hab, Tracker.
- **1.1.4:** Native look: the tracker, session bars and settings use the game's own tooltip border in bronze (without FlareUI style), and the session numbers are in the quest names' gold so they stand out from their labels.
- **1.1.3:** Lighter: the tracker skips rebuilding when a quest log update changes nothing it shows, and entering or leaving combat only redraws it.
- **1.1.2:** The "Report a bug / suggest" link box is solid now and stays put over the settings window until you close it.
- **1.1.1:** The old XPPlanner carry-over folder is gone (the CurseForge app removes it for you). If you never logged in with 1.1.0, your settings start fresh.
- **1.1.0:** The addon folder is now **Hereabouts**. Your settings come over automatically on first login (a small "XPPlanner" carry-over addon shipped alongside for that). Quest item keybinds stay as they were.
- **1.0.0:** First full release as Hereabouts: says hello on login ("Type /hab to set up Hereabouts") and the feedback button links to the new repo.
- **0.22.1:** New short command `/hab` (also `/hereabouts`); the old `/xpp` still works.
- **0.22.0:** XP Planner is now **Hereabouts**: same addon, same settings, a name that says what it does.
- **0.21.2:** Fix: the tracker shrinks again in combat when sections hide (the quest item buttons had locked its size).
- **0.21.1:** Quest colors (low-level grey, ready-to-turn-in green, far quest givers dimmed); Quests Nearby's distance moves to the right of the quest name.
- **0.21.0:** Quest item buttons (with keybinds) and session bars: XP per hour, time to level, gold per hour and more.
- **0.20.1:** Quests Nearby fills in by itself once Questie is ready (no more Rescan). New "Report a bug / suggest" button in the settings.
- **0.20.0:** Quests to Pick Up is now Quests Nearby, with distances in yards, and follows Questie's own settings. Active quests and turn-ins no longer need Questie.
- **0.19.0:** Quest tracking ticks no longer hide or dim quests (the Zone / All switch decides); "Show every quest I can take" for Quests to Pick Up (any level you can take, repeatable, no XP). Quests above your level to accept no longer show.
- **0.18.1:** Your focused quest stays in Active Quests, even when it's ready to turn in.
- **0.18.0:** New Quests to Turn In section, with its own Zone / All switch.
- **0.17.0:** Training shows what each city charges with your reputation.
- **0.16.3:** Works with Questie's latest update again; new `/hab questie` check.
- **0.16.2:** Click a quest to pick up for a map waypoint on its quest giver.
- **0.16.1:** Dungeon quests count inside the dungeon; hide sections in dungeons or combat; finished objectives hidden.
- **0.16.0:** Zone / All switch for Dungeons.
- **0.15.2:** Zone filter follows the game's quest map and your unfinished objectives.
