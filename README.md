# Hereabouts: All-Around Adventure Tracker

**Your quest tracker, filtered to where you are.**

Hereabouts shows only the quests you can work on in the zone you're in, judged by where their objectives and turn-ins are, not just the quest log heading. It also shows what to hand in, what to train and which dungeons fit your level. It works on its own; Questie and What's Training add more.

## Highlights
- **Zone-aware tracking:** active quests with objectives here, and quests ready to turn in here. One click on Zone / All switches to everywhere.
- **No tracking limit:** the zone filter decides what shows, not Blizzard's tracked-quest cap.
- **Quests to Turn In:** everything ready to hand in, in its own section.
- **Quests Nearby** (with Questie): the best-XP quests to pick up, with how far each quest giver is in yards and a one-click waypoint. Follows Questie's own settings.
- **Training** (with What's Training): what your trainer has for you, and what each city charges with your reputation.
- **Quest item buttons:** a button beside each quest with a usable item, in the margin left of its title (the list doesn't move for it): one click (or a keybind for the first three) uses it.
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
| `/hab zone` | Why each quest counts as in this zone, elsewhere, or can't tell, and how sure |
| `/hab focus` | In a fight: what combat focus sees and how it found it |
| `/hab session` | Reset the session bar's numbers |
| `/hab questie` | What Hereabouts sees of Questie |
| `/hab status` | Version, Questie / What's Training, session, item buttons, errors (for bug reports) |
| `/hab errors` | Errors caught this session |

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
- **1.9.0:** Sturdier add-on connections. Fixed: a change in What's Training could stop the whole tracker (now only the Training section empties); with EllesmereUI, an unreadable tracker setting switched tracker replacement on by itself; turning replacement off brought Blizzard's tracker back fully shown even if another addon had faded it. Show on Map keeps one TomTom arrow. Hereabouts no longer writes into Questie's tables, and `/hab questie` and the Status page show which parts of Questie (and What's Training) are available.
- **1.8.0:** Smarter zone filter: a quest Hereabouts can't place stays listed instead of being hidden as "elsewhere", and a quest over two zones shows where what's left to do is. Fixed: finishing an item objective ("Wolf Pelt") could drop a similarly named mob objective ("Wolf") from the zone check. Combat focus follows objective changes and also uses the game's threat information to find mobs fighting you. `/hab zone` explains each decision and how sure it is; new `/hab focus`.
- **1.7.0:** Fixed: "Quests this session (~N to level)" counted each quest's money as its XP. Fixed: "Reset to defaults" didn't reset the hide-in-combat / in-dungeons choices, the session stats or the border colour. Fixed: in combat a quest item button could end up beside another quest when the list changed; it now dims (its tooltip says which quest it's for) and moves back when combat ends. Fixed: Quests Nearby could miss a change in Questie's quests. The session bar says "gold gained" (spending isn't taken off) and marks XP across several level-ups at once as approximate. New: `/hab status`, `/hab errors`.
- **1.6.1:** Quest item buttons are bigger (20 px, from 14) and sit in the margin left of their quest's title, so the Active Quests list no longer shifts right when a quest has an item. Fixed: with EllesmereUI installed, the list's text is readable again (EllesmereUI's quest tracker shrinks the game's tracker fonts to 1 px, and Hereabouts took its font sizes from them). No style settings any more: the tracker's look follows EllesmereUI or FlareUI on its own whenever one is installed.
- **1.6.0:** Quests to Turn In shows where to turn each quest in (its zone, or "here") when the section is set to All zones.
- **1.5.0:** Quest item buttons now sit beside their quest in Active Quests: a small button left of the quest's [level] (the active quests move over a little to make room, all aligned), instead of a separate bar. In combat, the quest of what you're fighting is highlighted where it is instead of moving to the top. Soft animations: an objective that progresses flashes its count, and the combat highlight fades in and out (Settings, Lists: Soft animations).
- **1.4.0:** Works with FlareUI and EllesmereUI: Hereabouts takes over their quest trackers (it turns itself on the first time it finds one; /hab to change), and in EllesmereUI's style the tracker, session bar and settings use its panel colour, accent and font (the settings window painted by EllesmereUI's own skinning API).
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
