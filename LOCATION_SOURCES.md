# Hereabouts: location sources

Where Hereabouts gets its locations from, and how far each one can be trusted (1.8.0: the code
says which source decided each answer; 1.10.0: every place is one kind of location, Locations.lua).

## The location model (1.10.0)

`{ kind, map, x, y, label, source, name }`: kind giver / objective / turnin / itemsource; `map` the
game's map ID (uiMapID); `x, y` in 0-1 on that map, or none (somewhere on that map: an instance
spawn, -1,-1 in Questie's data); `source` game / questie / static. Questie's spawns ({ areaID → {
x, y } in 0-100 }) become locations through `Locations.FromSpawns` and Questie's `ZoneDB` (area →
map), at most 25 points per area and thing. Distances: world positions (`C_Map.
GetWorldPosFromMapPos`), on one continent only; nothing is guessed across continents.

Confidence:
- **Authoritative**: the game says so for this quest right now.
- **Database**: Questie's database (spawns, quest givers): right for the quest in general, but a
  spawn list can span zones and doesn't follow your progress.
- **Derived**: worked out by Hereabouts from names or text (objective names, quest log headings).
- **Static**: written into Hereabouts (dungeons, trainer cities); Classic data, not verified for
  Forever.

## Active quests: "is it here?" (1.8.0: Suggest.lua `InZone` gathers, `ns.LocationDecide` decides)

Sources gathered for each quest:

| Source | API / data | Confidence |
|---|---|---|
| In a dungeon: the game's map for the quest is this dungeon's, or the quest log heading names it | `GetQuestUiMapID`, `GetInstanceInfo` | Authoritative / Derived |
| The game's map for the quest (raised to its zone) | `GetQuestUiMapID` | Authoritative |
| On the game's map of this zone | `C_QuestLog.GetQuestsOnMap` | Authoritative |
| Where Questie places what's left (`ActiveQuestMaps`): its map markers (`QuestieMap.questIdFrames`, internal; follows progress), else its quest log's objectives and spawns (`QuestiePlayer.currentQuestlog`, internal), else its database: the turn-in NPC / object (finished), the objectives' mobs, objects and item drops still to do (finished ones dropped by exact name), the quest's zone when it lists no objectives | Questie | Database |
| The quest log's zone heading | `C_QuestLog.GetInfo` headers, `GetRealZoneText` | Derived |

The rule, in order:
1. In a dungeon and placed there: here.
2. Here if the game's map places it here, it's on the game's map of this zone, or Questie places
   something left to do here (a quest over two zones: the game's map names one of them).
3. Elsewhere if the game's map places it elsewhere, or Questie places all that's left elsewhere.
4. The quest log heading: the zone's name: here; another name: elsewhere (weak).
5. Nothing: **can't tell**, and the quest stays listed under "only this zone" (before 1.8.0 it
   counted as elsewhere). Questie knowing the quest but not where what's left is counts as nothing.

`/hab zone` prints each quest's answer, why, and the source's confidence.

## Quests to turn in

`Questie.TurnInZone`: the turn-in NPC's or object's spawns (Database); else the game's map
(Authoritative).

## Quests to pick up (Quests Nearby)

`StartLocations`: where the quest giver (NPC or object) spawns; a quest that starts from an item:
where that item drops (its NPCs and objects, 1.10.0); the quest's own zone only when none are known
(Database). Show on Map and distances: the nearest of those places on your continent.

## Active quests' places (1.10.0)

`Questie.QuestLocations(id)`: its quest giver, objectives (mobs, objects, item drops) and turn-in
(Database). What's left (`ns.QuestPlaces`): the objectives not finished (by exact name against the
quest log's finished lines), or the turn-in once it's complete. The "Waypoint to…" menu item and
`/hab where` use them; `Locations.Route` orders what's left nearest-next.

## Combat focus

What you're fighting: your target's tooltip (its quest lines), then enemy nameplates fighting you:
on the game's threat list (`UnitThreatSituation`) or with the "N% Threat" tooltip line (English);
either is enough. Which quests a unit is for comes only from its tooltip's quest lines (Verified in
WoW Forever). Objectives matched by `ObjectiveKey` (lower case, numbers and punctuation removed),
exactly.

## Dungeons and training

| Data | Source | Confidence |
|---|---|---|
| Dungeon entrances and level ranges | Dungeons.lua | Static (Classic ranges) |
| Spells to train, weapon masters | What's Training (`WT_API`) | its data |
| Trainer cities per class and faction, weapon masters' cities, reputation discount (10% at Honored+) | TrainerData.lua (1.11.0; from What's Training's Forever data) | Static, verified through its source, not city by city in game |
