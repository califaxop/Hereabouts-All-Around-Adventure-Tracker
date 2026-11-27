# Hereabouts: development notes

Hereabouts is a quest tracker and adventure companion for WoW: Forever (Interface 16001, a
Midnight 12.x client running Classic content): quests here, turn-ins, quests nearby (Questie),
training (What's Training), dungeons, quest item buttons, combat focus and session statistics.
This file holds the architecture, conventions, milestone plan and progress. Game and add-on APIs
and their verification status: [API_COMPATIBILITY.md](API_COMPATIBILITY.md). Where locations come
from and how far to trust them: [LOCATION_SOURCES.md](LOCATION_SOURCES.md). Player-facing changes:
[CHANGELOG.md](CHANGELOG.md).

## Milestones

| # | Milestone | Status |
|---|---|---|
| 1 | Reliability and data integrity | Done in 1.7.0, verified in game, reviewed |
| 2 | Quest and location intelligence | Done in 1.8.0, verified in game, reviewed |
| 3 | Integration compatibility (Questie / What's Training adapters, tracker replacement) | **Done in 1.9.0, verified in game, waiting for review** |
| 4 | Unified location engine | Not started |
| 5 | Character progression and analytics | Not started |
| 6 | Modular interface | Not started |
| 7 | Diagnostics and release | Not started |

## Conventions

- Evolve, don't rewrite. Saved variables (`HereaboutsDB`, `HereaboutsCharDB`) keep their shape;
  old saved data loads.
- No API, event, field or frame name is used before it's checked: API_COMPATIBILITY.md labels
  each one **Verified in WoW Forever**, **Verified through documentation / source**, **Inferred
  but untested**, or **Unsupported**. Untested behaviour is never reported as verified.
- Questie's and What's Training's modules are outside code: every use is protected (`pcall`,
  type checks) and has a fallback; Questie's tables are never written to.
- Protected frames (the quest item buttons, Blizzard's tracker) are never moved, shown, hidden or
  given attributes in combat. In combat only their look changes.
- A quest item button never appears to belong to another quest (see "Secure quest item buttons").
- Expensive work is sliced (Questie's scan: 250 quests a frame) or event-driven; periodic timers
  only where nothing else tells (listed below).
- No unused code or settings. Offline tests for logic (`tests/run_tests.py`); game behaviour is
  checked in game (checklists below), never claimed from the tests.

## Architecture (1.9.0)

Load order (Hereabouts.toc): Core → Dungeons → QuestieSource → Training → Suggest → Session →
QuestItems → Tracker → Integrations → Options → Replace. Bindings.xml: the first three quest item buttons.

| File | Module | Does |
|---|---|---|
| Core.lua | `ns` | Settings defaults (`ns.DEFAULTS`), `LoadDB` / `ResetDB` (deep copies), the ignore list, `IsTrivial`, the error log (`NoteError`) |
| Dungeons.lua | `ns.DUNGEONS` | Static dungeon list: name, entrance zone, level range (Classic ranges, not verified for Forever) |
| QuestieSource.lua | `ns.Questie` | Binds Questie's modules (`QuestieLoader:ImportModule`); quests to pick up (a sliced scan of Questie's available set or database); where active quests are done (`ActiveQuestMaps`, `TurnInZone`, `GameQuestZone`); the set watcher; `/hab questie`, `/hab qinfo` |
| Training.lua | `ns.Training` | What's Training (`WT_API`): spells to train, trainer cities and prices with reputation |
| Suggest.lua | — | The quest log (`LogQuests`), zone filter (`InZone`), the quest log fingerprint (`QuestLogStamp`), combat focus (`CombatQuests`, `CombatFocusKey`, `ObjectiveKey`), `BuildSuggestions` (ranking, sections) |
| Session.lua | `ns.Session` | Session statistics (XP, gold gained, quests, rested), saved across a `/reload`; the session bars |
| QuestItems.lua | `ns.QuestItems` | Secure quest item buttons beside their quests (out of combat placed; in combat marked stale when the list changes) |
| Tracker.lua | — | The tracker frame, skins (Blizzard / FlareUI / EllesmereUI), pools, sections, animations, waypoints, the refresh scheduler, events, `/hab` |
| Integrations.lua | — | Every add-on Hereabouts works with, in one list (`ns.Integrations`): state (on / partial / loading / off) and what it gives, for the settings window and `/hab status` (1.9.0) |
| Options.lua | — | The settings window |
| Replace.lua | — | Replacing Blizzard's, FlareUI's and EllesmereUI's trackers |

### Refresh path

Events → `ns.Refresh(kind)` (merged: 0.2 s) → `Run`:
- `redraw`: draw the last list again (combat changed which sections show);
- `log`: rebuild only if `QuestLogStamp` (quests, completion, tracking, focus, items, headers, XP,
  level, objective texts) changed;
- full: `BuildSuggestions` → `Render`. Since 1.7.0 every step is protected and errors go to
  `ns.NoteError` (printed once, `/hab errors`).

Timers: the session bar repaints every 2 s while shown; distances in the list every 1 s; Questie's
set is watched every 3 s (only while bound and not scanning); combat focus is checked at most
twice a second (only in combat, on target / threat / nameplate events).

### Saved variables

- `HereaboutsDB` (account): settings (`ns.DEFAULTS` keys), `pos`, `ignoredQuests` (questID →
  { name, level }), `collapsedSections`, `hidden`, `borderVersion`.
  `LoadDB` gives each missing setting a deep copy of its default; a table setting that's present
  stays as the player left it (in `sessionStats` and `hideIn*`, a missing key means off).
  `ResetDB` wipes and reloads the defaults, keeping `pos` and `ignoredQuests`.
- `HereaboutsCharDB` (per character): `session` (saved at `PLAYER_LOGOUT`, which also fires on
  `/reload`; restored when `PLAYER_ENTERING_WORLD` says it's a reload and it's under 15 minutes
  old and passes `Session.Check`).

## Path traces (M1)

**Session.** `PLAYER_LOGIN` → `Session.Reset` (baseline: XP, max, level, money).
`PLAYER_ENTERING_WORLD (isInitialLogin, isReloadingUi)` with a reload → `Restore` (checked) →
`OnXP` / `OnMoney` count what came in during the loading screen. `PLAYER_XP_UPDATE` → `OnXP`
(`Gain`: one level up exact, more than one marked approximate). `PLAYER_MONEY` → `OnMoney` (money
in only). `QUEST_TURNED_IN (questID, xpReward, moneyReward)` → `OnQuest(xpReward)`.
`PLAYER_LOGOUT` → `Save`. Values: XP/h and time to level from the session's XP rate (after its
first minute); quests to level from the session's average quest XP.

**Saved variables.** `ADDON_LOADED` → `LoadDB` → `PlaceFrame`, `CreateOptions`. Reset (settings
window) → `ResetDB` → `PlaceFrame`, rescan, restyle.

**Questie.** `PLAYER_LOGIN` → `Questie.Init` → `Bind` (imports QuestieDB, QuestXP, TrackerUtils,
ZoneDB, QuestiePlayer, QuestieMap, QuestieLib, AvailableQuests; needs `IsDoable`, `GetQuest`,
`GetQuestLogRewardXP`) → polls Questie's readiness → `Scan` (sliced) over `AvailableQuests.
__availableQuests` when present (Questie's own rules and settings), else `QuestieDB.QuestPointers`
checked with `IsDoable`. The watcher rescans when the available set changes (`SameSet` against the
last scan's snapshot); `QUEST_ACCEPTED` drops one, `QUEST_REMOVED` / turn-ins / level-ups and
Questie's `CalculateAndDrawAll` (hooked) rescan.

**Secure quest item buttons.** `BuildSuggestions` → `LogQuests` (`GetQuestLogSpecialItemInfo`
per log index) → `Render` adds `{ itemID, icon, title, questID, row }` for shown active quests →
`QuestItems.Update`. Out of combat: `Apply` places button i at its row's screen spot (a secure
button anchored to a row would protect the rows), sets `item`, and records `questID` and the spot
(`at`). In combat: the list is kept for later (`pending`) and each shown button is checked
(`IsStale`): its quest still in the list, its row visible at the same spot → as is; else stale
(alpha 0.3, desaturated, a tooltip line). `PLAYER_REGEN_ENABLED` → `Apply(pending)`. Counts and
cooldowns repaint on `BAG_UPDATE_DELAYED` / `BAG_UPDATE_COOLDOWN` (not protected).

## Milestone 1 audit (1.6.1 source)

Severity: High = wrong data or a misleading control in normal play; Medium = in some situations;
Low = cleanup.

### Confirmed defects, fixed in 1.7.0

| # | Sev. | Defect | Fix |
|---|---|---|---|
| 1 | High | `QUEST_TURNED_IN`: the handler takes the first argument (questID) as `arg1`, then `select(2, ...)` of the rest: the **money** reward. "Quests this session (~N to level)" divided by money. | `OnQuest((...))`: the XP reward (Tracker.lua) |
| 2 | High | `LoadDB` handed out the default tables themselves (`hideInInstance`, `hideInCombat`, `sessionStats`, `borderColor`): a changed setting changed the default, so "Reset to defaults" restored the player's own choices. | Deep copies (`ns.Copy`) on load and reset (Core.lua) |
| 3 | High | Quest item buttons in combat: the list redraws (a quest done, sections hidden in combat, combat focus, a scroll), the secure buttons can't move, so a button could sit beside another quest's title. | Each button keeps its quest and spot; in combat a button no longer beside its quest is marked stale (dimmed, tooltip); placed again when combat ends (QuestItems.lua, Tracker.lua passes `questID`) |
| 4 | Medium | Questie's set watcher compared count and ID sum: different sets with equal counts and sums ({1,4}, {2,3}) looked unchanged, so no rescan. | An exact snapshot of the set, compared ID by ID (`Snapshot`, `SameSet`): no sorting, stops at the first difference (QuestieSource.lua) |
| 5 | Medium | Saved session restored without checks: a non-number or negative value (a hand-edited or damaged file) went into the totals or errored. | `Session.Check`: every field a finite, non-negative number of a sane size, else a fresh session (with the reason in `/hab status`) |
| 6 | Medium | XP across several level-ups between two readings counted only the first and last levels, silently. | Counted the same, marked approximate ("~", tooltip, `/hab status`); `Session.Gain` (pure) |
| 7 | Low | "Gold this session" / "Gold per hour" count money in only (spending isn't taken off), which the labels didn't say. | "Gold gained…" labels and a tooltip line on what counts |
| 8 | Low | A drawing error after a successful build wasn't caught (`Render` outside `pcall` on a full rebuild); every error printed on every rebuild. | Every step protected; `ns.NoteError` prints once, counts after; `/hab errors`, `/hab status` |

### Confirmed defects for later milestones (not changed in M1)

| # | Defect | Milestone |
|---|---|---|
| L1 | `Bind` writes `QA.xppHooked = true` into Questie's AvailableQuests module to remember its hook (writes to Questie's tables). | Fixed in 1.9.0 |
| L2 | `ns.EUITrackerOn` returns true when EllesmereUI's setting can't be read (`not (ok and on == false)`): unreadable counts as enabled. | Fixed in 1.9.0 |
| L3 | Questie internals read directly: `QuestiePlayer.currentQuestlog`, `QuestieMap.questIdFrames`, `AvailableQuests.__availableQuests` (protected, with fallbacks, but not behind one boundary). | Fixed in 1.9.0 |

### Potential risks (to investigate)

| # | Risk | Milestone |
|---|---|---|
| R1 | Zone filter: the game's quest map (`GetQuestUiMapID`) wins over Questie when present; a quest whose objectives span zones counts only where the game places it. | 1.8.0: fixed (defect 10) |
| R2 | Objective matching by text (`ObjectiveKey`, `finished(name)` substring match in `ActiveQuestMaps`): similar names can match ("Wolf" in "Wolf Pelt"). | 1.8.0: fixed (defect 11) |
| R3 | Combat focus reads unit tooltips (`C_TooltipInfo.GetUnit`) and the English "Threat" text; other locales fall back to the target only. Its fingerprint (`CombatFocusKey`) holds quest IDs, not objectives. | 1.8.0: the threat API added (defect 13), objectives in the fingerprint (defect 12); the tooltip's quest lines remain the only source of which quests a unit is for |
| R4 | Dungeon ranges and trainer cities / weapon masters are static Classic data; the reputation discount (10% at Honored and above) isn't verified on Forever. | M3 / M5 |
| R5 | Tracker replacement: Blizzard's tracker is re-parented to a hidden frame out of combat, alpha 0 as a backup in combat; restoring alpha and parent, and other addons' trackers, not yet audited. | 1.9.0: audited (defects 17, L2); FlareUI's own "Never" setting can't be read, see M3 |
| R6 | Quest item buttons: `SetAlpha` and texture changes on a protected button in combat are assumed allowed (only position, size, shown state and attributes are protected). Inferred, to verify in game. | M1 check |
| R7 | A quest item that runs out mid-fight is shown desaturated until the list is rebuilt out of combat. | — (by design) |

## Milestone 2 (1.8.0)

Audit of the location and combat focus code (1.7.0):

| # | Sev. | Defect | Fix |
|---|---|---|---|
| 9 | High | A quest no source could place counted as **elsewhere**: hidden by "only this zone" though nothing said it was elsewhere ("no match", and Questie "what's left has no known place"). | Three answers: here, elsewhere, can't tell; can't tell stays listed (`ns.LocationDecide`) |
| 10 | Medium | When the game's map named a zone for a quest, Questie wasn't asked: a quest over two zones counted only where the game's map put it, though what was left to do was here. | Every source is gathered; here when the game or Questie places what's left here |
| 11 | Medium | A finished objective line containing a name finished it: "Wolf Pelt: 5/5" finished the "Wolf" objective, so its places dropped out. | Exact match of the objective's words (`ns.ObjectiveMatches`) |
| 12 | Medium | Combat focus's fingerprint held quest titles only: when the objectives you were fighting for changed, the highlighted objective didn't follow until another change. | Each quest with its objectives, sorted (`ns.FocusKey`, pure); who you're fighting is left out (it isn't shown) |
| 13 | Low | Enemies fighting you were found by the English "N% Threat" tooltip line only. | The threat API too (`UnitThreatSituation`: on its threat list); either is enough, neither rules a unit out |
| 14 | Low | Enemy counting compared each name with the first one only (A, B, B counted 3 kinds). | Counted one by one and by distinct name ("Wolf x2", "3 enemies") |

Changes:
- `Suggest.lua`: `ns.LocationDecide(evidence)` (pure: here / elsewhere / nil, why, source),
  `InZone` gathers the evidence; callers keep a can't-tell quest listed. `ns.ObjectiveMatches`.
  Combat focus: `Fighting` (threat API or text), counting, `ns.FocusKey`, `ns.CombatFocusReport`.
- `QuestieSource.lua`: finished objectives by exact match.
- `Tracker.lua`: `/hab zone` shows here / elsewhere / can't tell, why, and the source's confidence;
  `/hab focus`.

## Milestone 3 (1.9.0)

Audit of the integrations (1.8.0), besides L1-L3 above:

| # | Sev. | Defect | Fix |
|---|---|---|---|
| 15 | Medium | What's Training: a missing or changed part of its API (`Status`, `GetSpells`, `IsReady` erroring) errored inside the list build: the **whole** tracker stopped, not just the Training section. | Each part checked (`Training.Capabilities`); a missing one empties only what it's for |
| 16 | Medium | L2's consequence: on the first login with EllesmereUI, an unreadable tracker setting switched "replace the tracker" on by itself (and said EllesmereUI's tracker was replaced). | `EUITrackerOn`: true / false / nil (can't tell); only a readable "on" switches replacing on |
| 17 | Low | Turning replacing off set Blizzard's tracker to alpha 1, not to the alpha it had (another addon's fade). | Its alpha is kept when Hereabouts takes its place and given back |
| 18 | Low | Every "Show on Map" added another TomTom waypoint; they piled up. | The previous Hereabouts waypoint is removed first (`TomTom:RemoveWaypoint(uid)`) |
| 19 | Low | The settings window's "Connected addons" had no EllesmereUI row, and didn't say when Questie or What's Training worked without some parts. | One list (`ns.Integrations`), with "partial" and what's missing; `/hab status` uses it |

Questie boundary (QuestieSource.lua): every module is imported and checked in `Bind`; Questie's
internals are read only through `AvailableSet`, `QuestLogEntry` and `MarkerFrames` (type-checked);
nothing is written into Questie's tables (hooks are remembered in a local weak table);
`Questie.Capabilities()` lists the parts this Questie has (database, spawns, quest XP, zones,
quest levels, available set, its quest log, its map markers), shown in `/hab questie`, the settings
window and `/hab status`. Every missing part falls back as before (the game's quest log and maps).

Tracker replacement, as audited: out of combat Blizzard's tracker (`ObjectiveTrackerFrame`, or the
older `QuestWatchFrame` / `WatchFrame`) is re-parented to a hidden frame (its original parent and
alpha remembered), alpha 0 as a backup if Blizzard shows it in combat; in combat nothing is
re-parented (`pending`, applied after combat); applied at `PLAYER_ENTERING_WORLD` and again 2 s
later (FlareUI and EllesmereUI set up their trackers around login). FlareUI's tracker: `SetNever`
(and its own "Never" calls are overruled while replacing); turning replacing off calls
`SetNever(false)` only if Hereabouts set it. Limitation: whether the player had set FlareUI's
tracker to "Never" before Hereabouts did can't be read, so turning replacing off shows it again.
EllesmereUI's: `_EQT_SetSuppressed("Hereabouts", on)`, Hereabouts' own suppression only.

## Testing

### Offline

```
pip install lupa
python3 tests/run_tests.py
```

21 tests (1.9.0): the Questie boundary (nothing written into its tables, missing parts reported,
a broken quest log), What's Training's parts, tracker replacement (parent and alpha back, nothing in
combat, an unreadable EllesmereUI setting), TomTom's one arrow; the location rule (every source, unknown kept), the zone filter keeping a quest
it can't place, exact objective matching, the combat focus fingerprint, enemies and threat (API or
text), quest ordering; the files load against the mock client; nested defaults (copies, reset, saved
settings kept, future nested defaults); the turn-in event's XP and money; XP across level-ups;
session save / restore and bad saved data; gold gained; Questie set changes; quest item buttons
(association, stale in combat, nothing protected changed in combat, placed again after); errors
and `/hab status`. The mock raises an error on any protected change to a secure button in combat.

### In-game checklist (Milestone 1 → 2)

1. Install 1.7.0, `/reload`: the tracker, its sections and its look as before; no Lua errors.
2. `/hab status`: version 1.7.0; Questie and What's Training as you have them; "errors caught: 0".
3. Session: note "Quests this session (~N to level)", turn in a quest that gives XP and money;
   ~N should be about (XP to level) / (the quest's XP), not / its money. `/reload`: the session
   numbers carry on.
4. Settings: tick a few "hide in combat" / "hide in dungeons" boxes, untick a session stat, change
   the border colour; Reset to defaults: they're back to the defaults (border brown, XP/h, time to
   level, gold/h on, nothing hidden); position and ignored quests unchanged. `/reload`, reset
   again: the same.
5. Quest item buttons: with two quests that have items, start a fight and finish one quest (or
   scroll the list, or let combat hide a section) during it: a button not beside its quest
   dims, its tooltip says so; no button sits at full brightness beside another quest's title.
   After combat: every button beside its own quest. No "action blocked" message.
6. Questie (if installed): the Quests Nearby section updates after accepting / turning in quests
   and on level-up as before.
7. Any error: `/hab errors`, screenshot it.

Results (1.7.0 test build):
- 1, 2: pass. `/hab errors`: "no errors caught this session".
- 3 (first part): pass. After one quest: "1 quest (~54 to level)" with 1,650 XP this session and
  1 h 52 m to level at 46.9k XP/h (about 87k XP left): about 1,600 XP a quest, the quest's XP (the
  money reward would have given a very different number). The new tooltip lines show.
- 3 (`/reload` carry-over), 4, 5, 6: pass (reported by the author: the session carries over a
  `/reload`; Reset to defaults restores the hide-in-combat / in-dungeons choices, session stats and
  border colour, keeping position and ignored quests; quest item buttons dim when the list changes
  in combat and are back beside their quests after; Quests Nearby updates).

Milestone 1 verified in game and reviewed.

### In-game checklist (Milestone 2 → 3)

1. Install 1.8.0, `/reload`: the tracker as in 1.7.0; no Lua errors.
2. `/hab zone`: each quest says here / elsewhere / can't tell, why, and which source (authoritative,
   Questie's data, quest log heading, unknown). Note any that look wrong (screenshot with the quest).
3. With "Active Quests: only this zone" on: a quest whose objectives are here but which is filed
   under another zone's heading (or spans two zones) shows; a quest that's really elsewhere doesn't.
4. A quest with an item objective named like a mob ("Wolf Pelt" and "Wolf", if you have one): after
   finishing the pelts, the quest still counts as here where the wolves are.
5. Combat focus: fight a quest mob without targeting it (it pulls you), then one you target; `/hab
   focus` in the fight names it and how it was found ("threat API" or "threat text"); the quest is
   highlighted, and the objective you're fighting for lights up; when that objective finishes the
   highlight follows.
6. Two mobs of one kind on you: `/hab focus` says "Name x2"; two kinds: "2 enemies".

Results (1.8.0 test build):
- 2: pass. In Orgrimmar, 15 quests, every one elsewhere, each with its reason: 11 by the game's map
  ("…places it in Stranglethorn Vale; Questie agrees", authoritative; one Forever quest, 96988,
  "Source of Power", in Alterac Mountains), 4 by Questie's data alone (Shadowshard Fragments, Scarab
  Shells, Tiara of the Deep, Gahz'rilla: no game map for them). None "can't tell".
- 3: pass. In Stranglethorn Vale: Mok'thardin's Enchantment, Voodoo Dues, The Bloodsail Buccaneers
  "here: the game's map places it here" (authoritative); the rest elsewhere with their reasons
  (Necklace Recovery's game map moved from Badlands to Loch Modan as the quest progressed).
- 5 (target): pass. `/hab focus`: "fighting Maury "Club Foot" Wilkins (found by your target's
  tooltip): Voodoo Dues: maury's clubbed foot"; "fighting Naga Explorer: Mok'thardin's Enchantment:
  naga explorer; Akiris by the Bundle: akiris reed" (one mob, two quests: a kill and a drop).
- 1: pass (no Lua errors on 1.8.0).
- 5 (no target): pass. Two Naga Explorers on you, no target: "fighting Naga Explorer (found by
  enemy nameplates (threat API))", then "fighting Naga Explorer x2 (found by enemy nameplates (threat
  API))": the threat API answers solo on Forever.
- 6: pass ("Naga Explorer x2").

Milestone 2 verified in game; awaiting review before Milestone 3.

### In-game checklist (Milestone 3 → 4)

1. Install 1.9.0, `/reload`: the tracker as in 1.8.0; no Lua errors.
2. `/hab questie`: each Questie part green (there) or grey (not available); send the list.
3. `/hab` > Status: five rows (Questie, What's Training, FlareUI, EllesmereUI, TomTom), each with
   its state; nothing overlaps.
4. Quests Nearby and Training as before (with Questie and What's Training).
5. "Replace the quest tracker": on, then off: Blizzard's tracker comes back as it was (if another
   addon fades it, faded as before); try turning it on in combat: it happens when combat ends.
6. TomTom (if installed): "Show on Map" on two quests: one Hereabouts arrow, not two.

Results (1.9.0 test build):
- 2: Questie 12.15.0, bound, 311 quests to pick up; every part there except "its quest log"
  (`QuestiePlayer.currentQuestlog` isn't a table in this version). Not new: 1.x read it the same way
  and found nothing; its map markers and database did the job. The Status page showed Questie as
  "partial" for it: such stand-in parts are now optional (`Capabilities()` 4th field) and only a
  missing essential part makes it partial.
- 3: pass. Five rows, each with its state; nothing overlaps.
- 4: pass. Quests Nearby and Training as before.
- 6: pass (TomTom installed since): Status "TomTom: Connected"; Show on Map on The Cook in the Cage:
  one arrow ("Wendel Mathers, 2621 yards away"). The Questie row green after the optional-parts
  change ("Connected: 311 quests you can pick up.").
- Seen: Show on Map on quests that start from an item (The Monogrammed Sash, Cortello's Riddle):
  "no location known" (their start is an item, not a quest giver). For Milestone 4 (one location
  model: an item start can point at where the item drops).
- 5: replacing off: the tracker (FlareUI's / Blizzard's) came back; Hereabouts, dragged to the same
  place, sits over it (its position is the player's; "Move under quest tracker" puts it below).
  In combat: pass (turned on mid-fight: it waited, and took effect when combat ended; no "action
  blocked").

Milestone 3 verified in game; awaiting review before Milestone 4.

### Needs verification in WoW Forever

### Needs verification in WoW Forever

- `QUEST_TURNED_IN` arguments (questID, xpReward, moneyReward): consistent with check 3 (the
  quest's XP, not its money); confirmed when a turn-in with a known XP reward is compared.
- `SetAlpha` / `SetDesaturated` on a secure button in combat (R6): check 5.
- `PLAYER_ENTERING_WORLD (isInitialLogin, isReloadingUi)` on Forever: in use since 1.x, the session
  carry-over has been seen working; recheck with check 3.
- `UnitThreatSituation("player", nameplateN)` outside a group: verified (1.8.0 check 5: solo,
  "found by enemy nameplates (threat API)").
