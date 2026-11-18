# XP-Planner
A quest tracker that tells you where your next XP is: your quests, quests to pick up, dungeons and spells to train.

XP Planner is a quest-tracker-style list, built to show what levels you fastest. It can sit under Blizzard's tracker or replace it, scrolls within a set height, and matches FlareUI's look when FlareUI is installed. It reads Questie's quest database and What's Training's spell list when those addons are installed; nothing from them is copied into XP Planner.

Features
- Active Quests: your quest log with the objectives still to do and XP, highest level first; the focused quest pinned and highlighted; untracked quests dimmed or hidden; optionally only quests in your current zone.
- Right-click an active quest: Blizzard's own tracker menu (focus, view, map, track, share, abandon).
- Quests to Pick Up (needs Questie): quests you can accept in your current zone, within your level range (-8 to +8), best XP chosen, with quest giver and zone.
- Right-click a quest to pick up: Show on Map (a map waypoint on the quest giver, plus TomTom's arrow if installed) or Ignore Quest, with an ignore list you can manage.
- Training (needs What's Training): spells and ranks you can train now, with costs and a total; next-level spells dimmed.
- Dungeons: dungeons whose level range fits you, optionally only those in your current zone.
- Zone / All switch on the Active Quests, Quests to Pick Up and Dungeons headings: one click between your current zone and every zone.
- Show or hide each section in dungeons and in combat.
- Look: FlareUI style or a brown-bordered backdrop, opacity, scale, max height with scrolling, lock in place, replace Blizzard's quest tracker.

Settings and commands
- /xpp: settings window in the tracker's own style, with tabs: Tracker (position and look), Lists (what to show and how many), Picking Quests (level range, zone filters, ignored quests) and Status (Questie, What's Training, FlareUI, TomTom).
- /xpp lock / unlock, /xpp replace, /xpp toggle, /xpp reset.
- /xpp zone: why each active quest counts as in your zone or not.
- Esc > Options > AddOns > XP Planner.

Requirements
- WoW: Forever (client 16001). Optional: Questie, What's Training, FlareUI, TomTom.

Known limits
- Without Questie, Quests to Pick Up falls back to the quests the map shows nearby, with no XP ranking or waypoints.
- Dungeon level ranges are classic ranges; Forever may tune them.

Changelogs
- 0.16.1: Inside a dungeon, its quests count as in your zone (by the dungeon's map or the quest log's dungeon heading). Each section can be hidden in dungeons and in combat (Tracker tab). Training no longer repeats "Next level" under spells (they stay dimmed, with their level shown). Active Quests hide finished objectives (option, on by default).
- 0.16.0: Dungeons can be limited to your current zone, with a Zone / All switch on their heading too.
- 0.15.2: Zone filter follows the game's own quest map (where it places each quest's current objective or turn-in), so Forever's own quests work too; otherwise Questie's markers and unfinished objectives. /xpp zone names what matched; /xpp qinfo <questID> shows the details.
- 0.15.1: "Only quests in my current zone" now uses Questie: quests ready to turn in show where their turn-in is, others where their objectives are; a Zone / All switch on the Active Quests and Quests to Pick Up headings; /xpp zone explains each quest.
- 0.15.0: Settings window redesigned in the tracker's style (FlareUI's when that style is on), organized into tabs.
- 0.14.2: Logo in the AddOns list.
- 0.14.0: Quests to Pick Up shows only your current zone; level range -8 to +8.
- 0.13.0: Option to show only active quests in your current zone.
- 0.12.0: Every section sorted by level, highest first.
- 0.11.1: Blizzard's tracker no longer reappears in combat; position fixed after reload.
- 0.11.0: Quests to Pick Up right-click menu: Show on Map, Ignore Quest, ignore list.
- 0.10.0: Training section from What's Training.
- 0.9.0: FlareUI style when FlareUI is installed.
- 0.8.0: Focus highlight and tracked / untracked display.
- 0.7.0: Blizzard's right-click menu on active quests.
- 0.6.0: Brown border, max height with scrolling, headers without "XP:".
- 0.4.0 – 0.5.0: Backdrop with opacity, soft edges, border.
- 0.3.0: Replace Blizzard's quest tracker.
- 0.2.0: Lock in place, settings window (/xpp), "Active Quests" naming.
- 0.1.0 – 0.1.2: First release; collapse and anchoring fixes.
