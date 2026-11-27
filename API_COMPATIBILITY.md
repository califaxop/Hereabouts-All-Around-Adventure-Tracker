# Hereabouts: API compatibility (WoW: Forever, Interface 16001)

Status labels:
- **Verified in WoW Forever**: seen working in the game (author's reports, screenshots, `/hab`
  diagnostics).
- **Verified through documentation / source**: Blizzard's API documentation, or the add-on's own
  source; not yet observed on Forever.
- **Inferred but untested**: assumed from behaviour or from other clients.
- **Unsupported**: not available, or not used.

"In use since" notes behaviour released versions rely on; that alone isn't "verified" unless the
specific behaviour was observed.

## Game events

| Event | Arguments used | Use | Status |
|---|---|---|---|
| `QUEST_TURNED_IN` | questID, xpReward, moneyReward | session: quests and quest XP (1.7.0: the XP, not the money) | Verified in WoW Forever (1.7.0: ~N to level matches the quest's XP) |
| `PLAYER_ENTERING_WORLD` | isInitialLogin, isReloadingUi | carry the session over a `/reload` | Verified in WoW Forever (the carry-over works since 1.x) |
| `PLAYER_LOGOUT` | — | save the session (fires on `/reload` too) | Verified in WoW Forever |
| `PLAYER_XP_UPDATE`, `PLAYER_MONEY`, `PLAYER_LEVEL_UP` | — | session XP and gold; rescans | Verified in WoW Forever (session bars) |
| `QUEST_LOG_UPDATE`, `QUEST_ACCEPTED` (questID; older: logIndex, questID), `QUEST_REMOVED`, `QUEST_WATCH_LIST_CHANGED`, `SUPER_TRACKING_CHANGED`, `QUESTLINE_UPDATE` | — | rebuild the list | Verified in WoW Forever (the tracker follows the log) |
| `ZONE_CHANGED`, `ZONE_CHANGED_NEW_AREA` | — | zone filter | Verified in WoW Forever |
| `PLAYER_REGEN_DISABLED` / `_ENABLED` | — | combat: sections hidden in combat, combat focus, quest item buttons placed after combat | Verified in WoW Forever |
| `PLAYER_TARGET_CHANGED`, `UNIT_THREAT_LIST_UPDATE`, `NAME_PLATE_UNIT_ADDED` | — | combat focus | Verified in WoW Forever |
| `BAG_UPDATE_DELAYED`, `BAG_UPDATE_COOLDOWN` | — | quest item counts and cooldowns | Verified in WoW Forever |

## Game functions

| API | Use | Status |
|---|---|---|
| `C_QuestLog.GetNumQuestLogEntries`, `GetInfo`, `IsComplete`, `GetQuestObjectives`, `GetQuestWatchType`, `GetLogIndexForQuestID`, `IsQuestFlaggedCompleted` | the quest log | Verified in WoW Forever |
| `GetQuestLogRewardXP(questID)` | a quest's XP | Verified in WoW Forever |
| `GetQuestLogSpecialItemInfo(logIndex)` | a quest's usable item | Verified in WoW Forever (item buttons) |
| `C_QuestLog.GetQuestsOnMap(mapID)`, `GetQuestUiMapID` / `C_QuestLog.GetQuestUiMapID`, `C_QuestLog.GetNextWaypoint` | where the game places a quest | In use; see LOCATION_SOURCES.md |
| `C_Map.GetBestMapForUnit`, `GetMapInfo`, `GetAreaInfo`, `GetWorldPosFromMapPos`, `GetPlayerMapPosition` | zones, distances (Locations.lua) | Verified in WoW Forever |
| `C_Map.SetUserWaypoint`, `UiMapPoint.CreateFromCoordinates`, `C_SuperTrack.SetSuperTrackedUserWaypoint` | Show on Map, active quests' waypoints | Verified in WoW Forever (Show on Map) |
| `C_SuperTrack.GetSuperTrackedQuestID` | the focused quest | Verified in WoW Forever |
| `C_TooltipInfo.GetUnit(unit)`, `Enum.TooltipDataLineType` | combat focus: a unit's quest lines, readable in combat | Verified in WoW Forever |
| `UnitThreatSituation("player", unit)` | combat focus: is a nameplate's mob fighting you (1.8.0, with the tooltip's threat text as the other way) | Verified in WoW Forever, in a group (Holdfast) and solo (1.8.0: `/hab focus` "found by enemy nameplates (threat API)") |
| `C_NamePlate.GetNamePlates`, a plate's `namePlateUnitToken` | combat focus: enemies fighting you | Verified in WoW Forever |
| `UnitXP`, `UnitXPMax`, `UnitLevel`, `GetXPExhaustion`, `IsPlayerAtEffectiveMaxLevel`, `GetMoney` | session | Verified in WoW Forever |
| `UnitQuestTrivialLevelRange`, `GetQuestGreenRange` | grey quests | Documentation |
| `C_Item.GetItemCount`, `C_Container.GetItemCooldown`, `C_Item.GetItemIconByID` | quest item buttons | Verified in WoW Forever |
| `C_Reputation.GetFactionDataByID` (older `GetFactionInfoByID`) | training: city reputation | In use |
| `C_SkillInfo.GetSkillLineInfoByID(skillLine)` → { name, rank, maxRank, modifier } | professions and weapon skills (`/hab progress`, 1.11.0) | Verified in WoW Forever for weapon skill lines (Equip This!: "Two-Handed Maces 209/210"); profession lines: Verified in WoW Forever for 171 Alchemy, 185 Cooking, 129 First Aid, 182 Herbalism (1.11.0 `/hab progress`); 164 Blacksmithing, 333 Enchanting, 202 Engineering, 165 Leatherworking, 186 Mining, 393 Skinning, 197 Tailoring, 356 Fishing: same API, not yet seen (a line the game doesn't answer for isn't shown) |

## Secure frames

| Behaviour | Use | Status |
|---|---|---|
| `SecureActionButtonTemplate` with `type = "item"`, `item = "item:<id>"` | quest item buttons; keybinds `CLICK XPPlannerQuestItemN:LeftButton` | Verified in WoW Forever |
| Position, size, shown state and attributes of a secure button can't change in combat | the buttons are placed out of combat only | Verified (Blizzard's rules; the buttons work in combat) |
| `SetAlpha`, `SetDesaturated` on a secure button and its textures in combat | stale buttons dimmed (1.7.0) | Verified in WoW Forever (1.7.0 checklist 5: dimmed, no "action blocked") |
| Re-parenting Blizzard's tracker out of combat; alpha 0 in combat | tracker replacement | Verified in WoW Forever (replacement works) |

## Questie (outside code: every use protected, with a fallback)

| Module / field | Use | Status |
|---|---|---|
| `QuestieLoader:ImportModule(name)` | access to Questie's modules | Verified through source; works on Forever |
| `QuestieDB.IsDoable`, `GetQuest`, `QueryNPCSingle`, `QueryObjectSingle`, `QuestPointers` | quests to pick up, quest givers, spawns | Verified through source; works on Forever |
| `QuestieDB.QueryItemSingle(id, "name" / "npcDrops" / "objectDrops")`, a quest's `Starts.Item`, `QueryQuestSingle(id, "objectives" / "finishedBy")` | where items drop (item objectives, item-started quests), turn-ins | Verified through source; item drops in use since 1.x for the zone filter |
| `QuestXP:GetQuestLogRewardXP(id, false)` | XP of quests to pick up | Verified through source |
| `ZoneDB:GetUiMapIdByAreaId`, `TrackerUtils:GetZoneNameByID`, `QuestieLib.GetEffectiveQuestLevel` | zones, levels | Verified through source |
| `AvailableQuests.__availableQuests` (internal), `AvailableQuests.CalculateAndDrawAll` (hooked; the hook remembered locally, 1.9.0) | Questie's own available set; rescans | Internal: may change; read only through `AvailableSet` |
| `QuestiePlayer.currentQuestlog`, `QuestieMap.questIdFrames` (internal) | where active quests are done | Internal: may change; read only through `QuestLogEntry`, `MarkerFrames` (type-checked). Questie 12.15.0 on Forever: `questIdFrames` there, `currentQuestlog` not (seen with `/hab questie`); both optional |

`Questie.Capabilities()` (1.9.0) says which of these this Questie has: `/hab questie`, the settings
window's Status page and `/hab status` show them.

Without Questie: Active Quests and Quests to Turn In work from the game's quest log and map;
Quests Nearby is off. `/hab questie` shows what's bound.

## What's Training

| API | Use | Status |
|---|---|---|
| `WT_API.IsReady`, `GetSpells` + `Status`, `RegisterCallback` (`Event.READY`, `SPELLS_CHANGED`, `LEVEL_CHANGED`, `IGNORED_CHANGED`), `GetSource(spellID)`, `GetCatalog(class)` | spells to train, weapon masters, pet abilities | Verified through its public API; works on Forever. Each part checked (`Training.Capabilities`, 1.9.0): a missing one empties only what it's for |

## Other UIs

| UI | Use | Status |
|---|---|---|
| FlareUI: `FlareUI.ObjectiveTracker:SetNever`, its profile's `objectivetracker.enabled`, its media | hide its tracker when replacing; its look | Verified in WoW Forever |
| EllesmereUI: `_EQT_SetSuppressed`, `EllesmereUIQuestTracker.Cfg("enabled")`, its skin API | hide its tracker when replacing; its look | Verified in WoW Forever; since 1.9.0 an unreadable setting is "can't tell", never "on" |
| TomTom: `TomTom:AddWaypoint(map, x, y, opts)` → uid, `TomTom:RemoveWaypoint(uid)` | Show on Map's arrow, one at a time (1.9.0) | Verified in WoW Forever (1.9.0: one arrow after Show on Map on two quests) |

## Testing an API in game

- `/hab status`: version, Questie and What's Training binding, the session, the quest item buttons,
  errors caught.
- `/hab errors`: every error caught this session.
- `/hab questie`, `/hab qinfo <questID>`: what's bound of Questie, and what each Questie source
  holds for one quest.
- `/hab zone`: each active quest: here / elsewhere / can't tell, why, and the source's confidence.
- `/hab focus`: in a fight: who combat focus sees, how it found them, their quests and objectives.
