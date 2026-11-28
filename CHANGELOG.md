# Changelog

## 2.1.0

- A new look for the settings window. The Hereabouts emblem sits in the corner, and each page has
  its title and what it's for. Settings are grouped in framed boxes, in two columns. The pages are
  icon tabs down the window's right edge (hover one for its name), and long pages scroll.
- Search: type part of a setting's name at the top right, then pick it (or press Enter) to jump to
  it, flashing.
- The window is bigger (640 x 600); it shrinks to fit smaller screens as before.

## 2.0.0 (the development plan: Milestones 1-7)

The first release of the development plan. 1.7.0 to 1.12.0 below were test builds of its
milestones (not published); 2.0.0 is all of them, plus Milestone 7:

- New "Bugs & Feedback" window (the button at the top right of the settings window, or `/hab report`), for bug reports, feedback and feature requests: the form's link
  at the top and one line to copy into it with everything a report needs: version and client, the
  connected add-ons and any missing parts, where your quests count (here, elsewhere, can't tell,
  and what decided), the quest item buttons, the session, your sections and the errors caught.
  Never your name, realm or guild.
- The session bar: XP per hour and time to level are one choice and one bar, gold per hour and
  gold gained another. Hover the XP bar for everything on XP (per hour, time to level, this
  session, quests, rested), the gold bar for everything on gold (per hour, gained, and what
  training costs now, with What's Training). Your earlier choices carry over.
- New: `/hab perf`: how long building and drawing the list takes, and the last Questie scan.

## 1.12.0 (Milestone 6: modular interface; test build)

- New Layout tab: put the sections in your own order (Up / Down) and show or hide each.
- Presets: Questing, This zone, Dungeons, Minimal, Leveling (they change what shows, never the
  look).
- Three slots to save your layouts and load them back; "Reset to defaults" keeps them.

## 1.11.0 (Milestone 5: character progression; test build)

- Session history: each session is kept when it ends (your next login, or a reset), up to 20;
  the session bar's tooltip shows the last one.
- New `/hab progress`: your level, this session, your past sessions' totals and XP an hour, your
  professions and weapon skills (and how far each weapon skill is below your level's cap).
- Dungeons say how many of your quests are for each, and (unless sorting by level) list those first.
- Training says how much you're short when your money doesn't cover it.

## 1.10.0 (Milestone 4: one location model; test build)

- Quests that start from an item have a place: Show on Map goes to where the item drops (it said
  "no location known"), and Quests Nearby's zone filter counts them there.
- Show on Map goes to the quest giver's nearest spawn, not the first one in your zone.
- Right-click an active quest: "Waypoint to the nearest objective" (what's still to do) or
  "Waypoint to the turn-in" (with Questie).
- New `/hab where <quest>`: every place known for a quest, the nearest of each kind, and what's
  left in nearest-first order.
- Under the hood: one location model for every place Hereabouts knows.

## 1.9.0 (Milestone 3: integration compatibility; test build)

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

## 1.8.0 (Milestone 2: quest and location intelligence; test build)

- With "only this zone" on, a quest Hereabouts can't place stays listed (it was hidden as
  "elsewhere").
- A quest over two zones shows where what's left to do is, not only where the game's map points.
- Fixed: finishing an item objective could drop a mob objective with a similar name ("Wolf Pelt"
  and "Wolf") from where the quest counts as here.
- Combat focus: the lit objective follows as objectives change; mobs fighting you are found by the
  game's threat information too (not only the English "Threat" line).
- `/hab zone` says here / elsewhere / can't tell, why, and how sure; new `/hab focus` shows what
  combat focus sees.

## 1.7.0 (Milestone 1: reliability and data integrity; test build)

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
