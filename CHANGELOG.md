# Changelog

## 1.10.0 (Milestone 4: one location model)

- Quests that start from an item have a place: Show on Map goes to where the item drops (it said
  "no location known"), and Quests Nearby's zone filter counts them there.
- Show on Map goes to the quest giver's nearest spawn, not the first one in your zone.
- Right-click an active quest: "Waypoint to the nearest objective" (what's still to do) or
  "Waypoint to the turn-in" (with Questie).
- New `/hab where <quest>`: every place known for a quest, the nearest of each kind, and what's
  left in nearest-first order.
- Under the hood: one location model for every place Hereabouts knows.

## 1.9.0 (Milestone 3: integration compatibility)

- Fixed: a change in What's Training could stop the whole tracker; now only its Training section
  empties.
- Fixed: with EllesmereUI, a tracker setting Hereabouts couldn't read switched "replace the quest
  tracker" on by itself.
- Fixed: turning tracker replacement off brought Blizzard's tracker back fully shown, even if
  another addon had faded it.
- Show on Map keeps one TomTom arrow from Hereabouts instead of adding one each time.
- Questie: Hereabouts no longer writes into Questie's own tables, reads its internals in one
  checked place, and `/hab questie` and the Status page show which of Questie's parts are there.
- The Status page lists EllesmereUI too, and says when an add-on works without some of its parts.

## 1.8.0 (Milestone 2: quest and location intelligence)

- With "only this zone" on, a quest Hereabouts can't place stays listed (it was hidden as
  "elsewhere").
- A quest over two zones shows where what's left to do is, not only where the game's map points.
- Fixed: finishing an item objective could drop a mob objective with a similar name ("Wolf Pelt"
  and "Wolf") from where the quest counts as here.
- Combat focus: the lit objective follows as objectives change; mobs fighting you are found by the
  game's threat information too (not only the English "Threat" line).
- `/hab zone` says here / elsewhere / can't tell, why, and how sure; new `/hab focus` shows what
  combat focus sees.

## 1.7.0 (Milestone 1: reliability and data integrity)

- Fixed: "Quests this session (~N to level)" used each quest's money reward as its XP.
- Fixed: "Reset to defaults" didn't reset the "hide in combat / in dungeons" choices, the session
  stats shown or the border colour (changing them changed the defaults too).
- Fixed: in combat, a quest item button could end up beside another quest when the list changed
  (a quest finished, a section hidden in combat, a scroll). Such a button now dims, its tooltip
  says which quest it's for, and it moves back beside its quest when combat ends.
- Fixed: Quests Nearby could miss a change in Questie's available quests and not update.
- The session survives damaged saved data (it starts afresh instead), and XP across more than one
  level-up at once is marked approximate ("~").
- Gold in the session bar is "gold gained": money in, spending not taken off (the labels say so).
- Errors are shown once and kept: `/hab errors`. New: `/hab status`.

Earlier versions: see "Recent changes" in README.md.
