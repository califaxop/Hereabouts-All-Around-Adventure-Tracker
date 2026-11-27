# Hereabouts: location sources

Where Hereabouts gets its locations from, and how far each one can be trusted (1.7.0, as found in
the Milestone 1 audit; Milestone 2 adds explicit confidence to the code itself).

Confidence:
- **Authoritative**: the game says so for this quest right now.
- **Database**: Questie's database (spawns, quest givers): right for the quest in general, but a
  spawn list can span zones and doesn't follow your progress.
- **Derived**: worked out by Hereabouts from names or text (objective names, quest log headings).
- **Static**: written into Hereabouts (dungeons, trainer cities); Classic data, not verified for
  Forever.

## Active quests: "is it here?" (Suggest.lua `InZone`), in this order

| Order | Source | API / data | Confidence | Notes |
|---|---|---|---|---|
| 0 | In a dungeon: the game's map for the quest is this dungeon's, or the quest log heading names the dungeon | `GetQuestUiMapID`, `GetInstanceInfo` | Authoritative / Derived | |
| 1 | The game's map for the quest | `GetQuestUiMapID` (zone level) | Authoritative | wins when present (DEVELOPMENT.md R1) |
| 2 | Where Questie has drawn the quest's markers | `QuestieMap.questIdFrames` (internal) | Database (follows progress) | `FromQuestieMarkers` |
| 3 | Questie's own quest log: objectives and their spawns | `QuestiePlayer.currentQuestlog` (internal) | Database | `FromQuestieLog`, not for finished quests |
| 4 | Questie's database: turn-in NPC / object (finished), objectives' mobs, objects and item drops still to do; the quest's zone when none are known | `QueryNPCSingle`, `QueryObjectSingle` (spawns, zoneOrSort) | Database + Derived (finished objectives dropped by name, R2) | `ActiveQuestMaps` |
| 5 | The quest log's zone heading equals the zone's name | `C_QuestLog.GetInfo` headers, `GetRealZoneText` | Derived | |
| 6 | On the game's map for this zone | `C_QuestLog.GetQuestsOnMap` | Authoritative | |
| — | None of these | — | — | "no match": counted as elsewhere |

`/hab zone` prints each quest's decision and its source.

## Quests to turn in

`Questie.TurnInZone`: the turn-in NPC's or object's spawns (Database); else the game's map
(Authoritative).

## Quests to pick up (Quests Nearby)

`StartMaps`: where the quest giver (NPC or object) spawns (Database); a quest that starts from an
item: the quest's own zone (Database, `zoneOrSort`). Distances: from the quest giver's nearest
spawn on your map (`C_Map.GetWorldPosFromMapPos`).

## Combat focus

What you're fighting: your target's tooltip, then enemy nameplates with a threat line (English
"Threat" text, R3). Objectives matched by `ObjectiveKey` (lower case, numbers and punctuation
removed).

## Dungeons and training

| Data | Source | Confidence |
|---|---|---|
| Dungeon entrances and level ranges | Dungeons.lua | Static (Classic ranges) |
| Spells to train, weapon masters | What's Training (`WT_API`) | its data |
| Trainer cities per class and faction, reputation discount (10% at Honored+) | Training.lua | Static, not verified for Forever (R4) |
