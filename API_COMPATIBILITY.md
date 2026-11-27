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
| `C_Map.GetBestMapForUnit`, `GetMapInfo`, `GetAreaInfo`, `GetWorldPosFromMapPos` | zones, distances | Verified in WoW Forever |
| `C_SuperTrack.GetSuperTrackedQuestID` | the focused quest | Verified in WoW Forever |
| `C_TooltipInfo.GetUnit(unit)`, `Enum.TooltipDataLineType` | combat focus: a unit's quest lines, readable in combat | Verified in WoW Forever |
| `UnitThreatSituation("player", unit)` | combat focus: is a nameplate's mob fighting you (1.8.0, with the tooltip's threat text as the other way) | Verified in WoW Forever in a group (Holdfast); solo: Inferred but untested (`/hab focus` shows which way found it) |
| `C_NamePlate.GetNamePlates`, a plate's `namePlateUnitToken` | combat focus: enemies fighting you | Verified in WoW Forever |
| `UnitXP`, `UnitXPMax`, `UnitLevel`, `GetXPExhaustion`, `IsPlayerAtEffectiveMaxLevel`, `GetMoney` | session | Verified in WoW Forever |
| `UnitQuestTrivialLevelRange`, `GetQuestGreenRange` | grey quests | Documentation |
| `C_Item.GetItemCount`, `C_Container.GetItemCooldown`, `C_Item.GetItemIconByID` | quest item buttons | Verified in WoW Forever |
| `C_Reputation.GetFactionDataByID` (older `GetFactionInfoByID`) | training: city reputation | In use |

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
| `QuestXP:GetQuestLogRewardXP(id, false)` | XP of quests to pick up | Verified through source |
| `ZoneDB:GetUiMapIdByAreaId`, `TrackerUtils:GetZoneNameByID`, `QuestieLib.GetEffectiveQuestLevel` | zones, levels | Verified through source |
| `AvailableQuests.__availableQuests` (internal), `AvailableQuests.CalculateAndDrawAll` (hooked) | Questie's own available set; rescans | Internal: may change (DEVELOPMENT.md L1, L3) |
| `QuestiePlayer.currentQuestlog`, `QuestieMap.questIdFrames` (internal) | where active quests are done | Internal: may change (L3) |

Without Questie: Active Quests and Quests to Turn In work from the game's quest log and map;
Quests Nearby is off. `/hab questie` shows what's bound.

## What's Training

| API | Use | Status |
|---|---|---|
| `WT_API.IsReady`, `RegisterCallback` (`Event.READY`, `SPELLS_CHANGED`, `LEVEL_CHANGED`, `IGNORED_CHANGED`), `GetSource(spellID)` | spells to train, weapon masters | Verified through its public API; works on Forever |

## Other UIs

| UI | Use | Status |
|---|---|---|
| FlareUI: `FlareUI.ObjectiveTracker:SetNever`, its profile's `objectivetracker.enabled`, its media | hide its tracker when replacing; its look | Verified in WoW Forever |
| EllesmereUI: `_EQT_SetSuppressed`, `EllesmereUIQuestTracker.Cfg("enabled")`, its skin API | hide its tracker when replacing; its look | Verified in WoW Forever; an unreadable setting counts as enabled (L2, M3) |
| TomTom | waypoints (when installed) | In use |

## Testing an API in game

- `/hab status`: version, Questie and What's Training binding, the session, the quest item buttons,
  errors caught.
- `/hab errors`: every error caught this session.
- `/hab questie`, `/hab qinfo <questID>`: what's bound of Questie, and what each Questie source
  holds for one quest.
- `/hab zone`: each active quest: here / elsewhere / can't tell, why, and the source's confidence.
- `/hab focus`: in a fight: who combat focus sees, how it found them, their quests and objectives.
