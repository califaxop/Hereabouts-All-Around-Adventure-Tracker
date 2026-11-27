# Hereabouts: location sources

Where Hereabouts gets its locations from, and how far each one can be trusted (1.8.0: the code
says which source decided each answer; Milestone 4 turns this into one location model).

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

`StartMaps`: where the quest giver (NPC or object) spawns (Database); a quest that starts from an
item: the quest's own zone (Database, `zoneOrSort`). Distances: from the quest giver's nearest
spawn on your map (`C_Map.GetWorldPosFromMapPos`).

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
| Trainer cities per class and faction, reputation discount (10% at Honored+) | Training.lua | Static, not verified for Forever (R4) |
