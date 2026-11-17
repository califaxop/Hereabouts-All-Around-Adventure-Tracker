# XP-Planner
A quest tracker that tells you where your next XP is: your quests, quests to pick up, dungeons and spells to train.

XP Planner is a quest-tracker-style list, built to show what levels you fastest. It can sit under Blizzard's tracker or replace it, scrolls within a set height, and matches FlareUI's look when FlareUI is installed. It reads Questie's quest database and What's Training's spell list when those addons are installed; nothing from them is copied into XP Planner.

Features
- Active Quests: your quest log with objectives and XP, highest level first; the focused quest pinned and highlighted; untracked quests dimmed or hidden; optionally only quests in your current zone.
- Right-click an active quest: Blizzard's own tracker menu (focus, view, map, track, share, abandon).
- Quests to Pick Up (needs Questie): quests you can accept in your current zone, within your level range (-8 to +8), best XP chosen, with quest giver and zone.
- Right-click a quest to pick up: Show on Map (a map waypoint on the quest giver, plus TomTom's arrow if installed) or Ignore Quest, with an ignore list you can manage.
- Training (needs What's Training): spells and ranks you can train now, with costs and a total; next-level spells dimmed.
- Dungeons: dungeons whose level range fits you.
- Look: FlareUI style or a brown-bordered backdrop, opacity, scale, max height with scrolling, lock in place, replace Blizzard's quest tracker.

Settings and commands
- /xpp: settings window (sections, sorting, counts, level range, zone filters, look, ignored quests, status of Questie and What's Training).
- /xpp lock / unlock, /xpp replace, /xpp toggle, /xpp reset.
- Esc > Options > AddOns > XP Planner.

Requirements
- WoW: Forever (client 16001). Optional: Questie, What's Training, FlareUI, TomTom.

Known limits
- Without Questie, Quests to Pick Up falls back to the quests the map shows nearby, with no XP ranking or waypoints.
- Dungeon level ranges are classic ranges; Forever may tune them.
