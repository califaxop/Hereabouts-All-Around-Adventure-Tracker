#!/usr/bin/env python3
"""Hereabouts offline tests: python3 tests/run_tests.py  (needs: pip install lupa)

Loads the addon's files (in the toc's order) against a mock of the game client (tests/mock.lua)
and checks the logic: settings defaults and reset, session statistics, quest turn-in events, the
Questie set watcher, and the quest item buttons' association with their quests. What the real
client does is checked in game (DEVELOPMENT.md, "In-game checklist"), never claimed from these.
"""
import os, sys
from lupa.lua51 import LuaRuntime

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
FILES = [l.strip() for l in open(os.path.join(ROOT, 'Hereabouts.toc')) if l.strip().endswith('.lua') and not l.startswith('#')]


def load(saved=None, start=True):
    L = LuaRuntime()
    L.execute(open(os.path.join(HERE, 'mock.lua')).read())
    if saved:
        L.execute(saved)
    ns = L.eval('{}')
    run = L.eval('function(src, n, ns) return assert(loadstring(src, "@" .. n))("Hereabouts", ns) end')
    for f in FILES:
        run(open(os.path.join(ROOT, f)).read(), f, ns)
    L.globals().NS = ns
    if start:
        L.execute('MOCK.Fire("ADDON_LOADED", "Hereabouts"); MOCK.Fire("PLAYER_LOGIN"); MOCK.Fire("PLAYER_ENTERING_WORLD", true, false); MOCK.RunTimers()')
    return L


failures, count = [], 0


def test(name, saved=None):
    def wrap(fn):
        global count
        count += 1
        try:
            L = load(saved)
            L.execute(fn.__doc__)
            print('ok   ', name)
        except Exception as e:  # noqa
            failures.append(name); print('FAIL ', name, '\n     ', str(e).replace('\n', '\n      '))
        return fn
    return wrap


@test("loads: every file runs against the mock, settings are set up")
def _():
    """
    assert(NS.db and NS.db.maxQuests == 8, "settings loaded")
    """


# ---------------------------------------------------------------------------------------------
# B. Settings defaults and reset
# ---------------------------------------------------------------------------------------------
@test("defaults: changing a table setting leaves the default alone; reset restores every nested default")
def _():
    """
    local db, D = NS.db, NS.DEFAULTS
    assert(db.sessionStats ~= D.sessionStats and db.hideInCombat ~= D.hideInCombat, "copies, not the defaults")
    db.hideInInstance.quests = true; db.hideInCombat.pickup = true
    db.sessionStats.xph = nil; db.sessionStats.xp = true
    assert(D.hideInInstance.quests == nil and D.hideInCombat.pickup == nil, "1.6.1: the defaults changed with them")
    assert(D.sessionStats.xph == true and D.sessionStats.xp == nil)
    db.pos = { "TOPLEFT", 10, -20 }; db.ignoredQuests[123] = { name = "x", level = 5 }
    db.maxQuests = 3
    NS.ResetDB()
    db = NS.db
    assert(db.hideInInstance.quests == nil and db.hideInCombat.pickup == nil, "hide settings back to none")
    assert(db.sessionStats.xph == true and db.sessionStats.gph == true and db.sessionStats.xp == nil)
    assert(db.maxQuests == 8)
    assert(db.pos and db.pos[2] == 10 and db.ignoredQuests[123], "position and ignored quests kept")
    -- a nested default added later is copied too
    D.futureThing = { a = { b = 1 } }
    NS.ResetDB()
    NS.db.futureThing.a.b = 2
    assert(D.futureThing.a.b == 1, "nested deep copy")
    """

SAVED_OLD_SETTINGS = '''
HereaboutsDB = { maxQuests = 5, sessionStats = { xph = true }, borderVersion = 2, borderColor = { 1, 0, 0 } }
'''

@test("defaults: saved settings stay as they are (a missing stat stays off); missing ones are filled", saved=SAVED_OLD_SETTINGS)
def _():
    """
    local db = NS.db
    assert(db.maxQuests == 5 and db.sessionStats.xph == true and db.sessionStats.ttl == nil, "the player's own table untouched")
    assert(db.borderColor == nil and db.borderVersion == nil, "2.1.0: the border colour setting removed")
    assert(db.hideInCombat and next(db.hideInCombat) == nil and db.hideInCombat ~= NS.DEFAULTS.hideInCombat, "filled with a copy")
    """

# ---------------------------------------------------------------------------------------------
# A. Quest turn-in: XP, not money
# ---------------------------------------------------------------------------------------------
@test("turn-in: QUEST_TURNED_IN (questID, xpReward, moneyReward) counts the XP, never the money")
def _():
    """
    MOCK.xp, MOCK.xpMax = 0, 10000
    NS.Session.Reset()
    MOCK.Fire("QUEST_TURNED_IN", 123, 1000, 2500)
    local v = NS.Session.Values()
    assert(v.quests:find("1 quest", 1, true), v.quests)
    assert(v.quests:find("~10 to level", 1, true), "10000 left / 1000 XP a quest (the money would give ~4): " .. v.quests)
    MOCK.Fire("QUEST_TURNED_IN", 124, 3000, 7)
    v = NS.Session.Values()
    assert(v.quests:find("~5 to level", 1, true), "average 2000 XP: " .. v.quests)
    MOCK.Fire("QUEST_TURNED_IN", 125, 0, 9999)   -- a quest with no XP: counted, adds no XP
    v = NS.Session.Values()
    assert(v.quests:find("3 quests", 1, true) and v.quests:find("~8 to level", 1, true), v.quests)
    """

# ---------------------------------------------------------------------------------------------
# H. Session statistics
# ---------------------------------------------------------------------------------------------
@test("session: XP across one level-up is exact; several at once is marked approximate")
def _():
    """
    local S = NS.Session
    local d, short = S.Gain(800, 1000, 20, 150, 21); assert(d == 350 and not short, "200 to finish + 150")
    d, short = S.Gain(800, 1000, 20, 150, 22); assert(d == 350 and short, "the level in between isn't known")
    d, short = S.Gain(500, 1000, 20, 400, 20); assert(d == 0 and not short, "XP never goes down as a gain")
    d = S.Gain(500, 1000, 21, 600, 20); assert(d == 0, "a lower level: nothing counted")
    MOCK.level, MOCK.xp, MOCK.xpMax = 20, 800, 1000
    S.Reset()
    MOCK.level, MOCK.xp, MOCK.xpMax = 21, 150, 1100; MOCK.Fire("PLAYER_XP_UPDATE", "player")
    local v = S.Values(); assert(v.xp == "350 XP" and not v.approx, v.xp)
    MOCK.level, MOCK.xp, MOCK.xpMax = 23, 50, 1300; MOCK.Fire("PLAYER_XP_UPDATE", "player")
    v = S.Values(); assert(v.xp == "~1350 XP" and v.approx, "350, then 950 + 50 with the level in between unknown: " .. v.xp)
    """

@test("session: a /reload carries it on; bad or old saved data starts afresh (never half-restored)")
def _():
    """
    local S = NS.Session
    MOCK.xp, MOCK.money = 300, 5000
    S.Reset()
    MOCK.xp = 500; MOCK.Fire("PLAYER_XP_UPDATE", "player")
    MOCK.money = 6000; MOCK.Fire("PLAYER_MONEY")
    MOCK.Fire("QUEST_TURNED_IN", 1, 150, 10)
    MOCK.now = MOCK.now + 600
    MOCK.Fire("PLAYER_LOGOUT")
    local saved = HereaboutsCharDB.session
    assert(saved.gained == 200 and saved.earned == 1000 and saved.questXP == 150, "saved")
    -- the reload: a moment later, a little more XP during the loading screen
    MOCK.clock = MOCK.clock + 5; MOCK.xp = 520
    assert(S.Restore() == true)
    local v = S.Values()
    assert(v.xp == "220 XP" and v.gold:find("10s", 1, true), v.xp .. " " .. v.gold)
    -- bad saved data
    for _, bad in ipairs({ { elapsed = -5 }, { elapsed = 0/0 }, { elapsed = 60, gained = "lots" },
                           { elapsed = 60, lastLevel = 20.5 }, { elapsed = 60, earned = math.huge }, "nonsense" }) do
      HereaboutsCharDB.session = bad
      if type(bad) == "table" then bad.savedAt = MOCK.clock end
      assert(S.Restore() == false, "refused")
      if type(bad) == "table" then assert(S.restoreNote and S.restoreNote:find("bad"), tostring(S.restoreNote)) end
    end
    HereaboutsCharDB.session = { elapsed = 60, savedAt = MOCK.clock - 3600, gained = 10 }
    assert(S.Restore() == false, "an hour old: a real login, not a reload")
    """

@test("session: gold gained counts money in only; labels say so")
def _():
    """
    local S = NS.Session
    MOCK.money = 10000; S.Reset()
    MOCK.money = 15000; MOCK.Fire("PLAYER_MONEY")
    MOCK.money = 2000; MOCK.Fire("PLAYER_MONEY")     -- spent
    MOCK.money = 2500; MOCK.Fire("PLAYER_MONEY")
    assert(S.Values().gold == "+55s 0c", S.Values().gold)
    local labels = {}
    for _, st in ipairs(S.STATS) do labels[st[1]] = st[2] end
    assert(labels.gph == "Gold: per hour and gained" and labels.xph == "XP: per hour and time to level" and labels.gold == nil)
    """

# ---------------------------------------------------------------------------------------------
# D. Questie set watcher
# ---------------------------------------------------------------------------------------------
@test("questie: the set watcher tells every different set apart ({1,4} vs {2,3}), no false changes")
def _():
    """
    local Q = NS.Questie
    local snap = Q.Snapshot({ [1] = true, [4] = true })
    assert(not Q.SameSet({ [2] = true, [3] = true }, snap), "same count and sum, different quests")
    assert(Q.SameSet({ [4] = true, [1] = true }, snap), "the same set")
    assert(not Q.SameSet({ [1] = true }, snap) and not Q.SameSet({ [1] = true, [4] = true, [5] = true }, snap))
    assert(not Q.SameSet({}, nil), "nothing seen yet: a change")
    assert(Q.SameSet({}, Q.Snapshot({})))
    """

# ---------------------------------------------------------------------------------------------
# C. Quest item buttons
# ---------------------------------------------------------------------------------------------
@test("item buttons: each knows its quest; in combat a changed list marks it stale, never moves it")
def _():
    """
    local QI = NS.QuestItems
    local function Row(top) local r = MOCK.obj(); r._left, r._top = 100, top; return r end
    local rowA, rowB = Row(500), Row(470)
    QI.Update({ { itemID = 11, title = "A", questID = 1, row = rowA }, { itemID = 22, title = "B", questID = 2, row = rowB } })
    local b1, b2 = QI.buttons[1], QI.buttons[2]
    assert(b1.questID == 1 and b2.questID == 2 and b1._attr.item == "item:11" and b2._attr.item == "item:22")
    assert(b1.at.y == 500 and not b1.stale)
    MOCK.combat = true
    -- the same layout again (a redraw in combat): nothing stale
    QI.Update({ { itemID = 11, title = "A", questID = 1, row = Row(500) }, { itemID = 22, title = "B", questID = 2, row = Row(470) } })
    assert(not b1.stale and not b2.stale and b1._alpha == 1)
    -- quest A turned in during the fight: B's row moves up to where A was
    QI.Update({ { itemID = 22, title = "B", questID = 2, row = Row(500) } })
    assert(b1.stale and b2.stale, "A gone, B moved: both stale")
    assert(b1._alpha == 0.3 and b1._attr.item == "item:11" and b1.questID == 1, "dimmed, still A's item (nothing protected changed)")
    assert(b2._attr.item == "item:22", "B's button wasn't given A's place or item")
    -- combat ends: placed again for the new list
    MOCK.combat = false
    MOCK.Fire("PLAYER_REGEN_ENABLED")
    assert(b1.questID == 2 and b1._attr.item == "item:22" and not b1.stale and b1._alpha == 1, "B's item at the top")
    assert(not b2._shown and b2.questID == nil, "the second button hidden")
    """

@test("item buttons: an item used up, a quest abandoned or a scroll in combat: stale, then fixed after")
def _():
    """
    local QI = NS.QuestItems
    local function Row(top, shown) local r = MOCK.obj(); r._left, r._top = 100, top; if shown == false then r._shown = false end; return r end
    QI.Update({ { itemID = 11, title = "A", questID = 1, row = Row(500) } })
    local b = QI.buttons[1]
    MOCK.combat = true
    QI.Update({ { itemID = 11, title = "A", questID = 1, row = Row(500, false) } })  -- scrolled out of view
    assert(b.stale, "its row isn't visible")
    QI.Update({ { itemID = 11, title = "A", questID = 1, row = Row(500) } })        -- scrolled back
    assert(not b.stale and b._alpha == 1, "back beside its quest")
    QI.Update({})                                                                    -- abandoned
    assert(b.stale and b._shown, "still shown (can't hide in combat), marked")
    MOCK.combat = false; MOCK.Fire("PLAYER_REGEN_ENABLED")
    assert(not b._shown, "hidden once combat ends")
    """

# ---------------------------------------------------------------------------------------------
# Diagnostics
# ---------------------------------------------------------------------------------------------
@test("diagnostics: an error is printed once, counted after; /hab status and /hab errors report")
def _():
    """
    PRINTS = {}
    NS.NoteError("drawing the list", "boom"); NS.NoteError("drawing the list", "boom")
    assert(#PRINTS == 1 and NS.errors[1].n == 2, "printed once, counted twice")
    PRINTS = {}
    SlashCmdList.XPPLANNER("status")
    local all = table.concat(PRINTS, " / ")
    assert(all:find("Questie (off): Not installed", 1, true) and all:find("quest item buttons: 0 shown") and all:find("errors caught: 1"), all)
    PRINTS = {}; SlashCmdList.XPPLANNER("errors")
    assert(PRINTS[1]:find("drawing the list %(x2%): boom"), PRINTS[1])
    """


# ---------------------------------------------------------------------------------------------
# Milestone 2: quest location, objectives, combat focus
# ---------------------------------------------------------------------------------------------
@test("location: one rule over every source; Questie here beats the game's elsewhere; unknown stays unknown")
def _():
    """
    local D = NS.LocationDecide
    local here, why, src = D({ instance = { here = true, why = "in this dungeon" }, game = { here = false, where = "Westfall" } })
    assert(here == true and src == "game", "a dungeon's quest")
    here, why, src = D({ game = { here = true, where = "Elwynn Forest" } }); assert(here and src == "game" and why:find("Elwynn"))
    here, why, src = D({ onMap = true }); assert(here and src == "game")
    here, why, src = D({ game = { here = false, where = "Westfall" }, questie = { maps = { [1429] = "objective: Kobold (mob/NPC)" }, here = "objective: Kobold (mob/NPC)" } })
    assert(here == true and src == "questie" and why:find("Kobold"), "a quest over two zones: what's left is here (1.7.0: elsewhere)")
    here, why, src = D({ game = { here = false, where = "Westfall" } }); assert(here == false and src == "game" and why:find("Westfall"))
    here, why, src = D({ questie = { maps = { [1436] = "x" } } }); assert(here == false and src == "questie")
    here, why, src = D({ questie = { maps = {} }, heading = { text = "Elwynn Forest", zone = "Elwynn Forest" } })
    assert(here == true and src == "text", "Questie can't place what's left: the heading decides (1.7.0: elsewhere)")
    here, why, src = D({ heading = { text = "Westfall", zone = "Elwynn Forest" } }); assert(here == false and src == "text")
    here, why, src = D({ questie = { maps = {} } })
    assert(here == nil and src == "none" and why:find("Questie knows the quest"), "nothing places it: unknown, not elsewhere")
    here = D({}); assert(here == nil)
    """

@test("location: with 'only this zone' on, a quest no source can place stays listed; one placed elsewhere doesn't")
def _():
    """
    NS.db.activeZoneOnly = true
    NS.Questie.GameQuestZone = function() return nil end
    NS.Questie.ActiveQuestMaps = function() return nil end
    local quests = {
      { questID = 1, title = "Nowhere", level = 20, xp = 100, complete = false, objectives = {}, zone = nil },
      { questID = 2, title = "Over There", level = 20, xp = 100, complete = false, objectives = {}, zone = "Westfall" },
      { questID = 3, title = "Right Here", level = 20, xp = 100, complete = false, objectives = {}, zone = "Elwynn Forest" },
    }
    local s = NS.BuildSuggestions(quests)
    local shown = {}
    for _, q in ipairs(s.quests) do shown[q.title] = true end
    assert(shown["Nowhere"] and shown["Right Here"] and not shown["Over There"], "unknown listed, elsewhere not")
    assert(s.questsElsewhere == 1, tostring(s.questsElsewhere))
    """

@test("objectives: a name matches a finished objective exactly, never by part of it")
def _():
    """
    local keys = { [NS.ObjectiveKey("Wolf Pelt: 5/5")] = true, [NS.ObjectiveKey("Kobold Vermin slain: 10/10")] = true }
    assert(not NS.ObjectiveMatches("Wolf", keys), "Wolf isn't Wolf Pelt (1.7.0: it was)")
    assert(NS.ObjectiveMatches("Wolf Pelt", keys) and NS.ObjectiveMatches("kobold vermin", keys))
    assert(not NS.ObjectiveMatches("Kobold", keys) and not NS.ObjectiveMatches("", keys) and not NS.ObjectiveMatches(nil, keys))
    assert(NS.ObjectiveKey("1/8 Tumbled Crystal") == NS.ObjectiveKey("Tumbled Crystal: 1/8"))
    """

@test("combat focus: the fingerprint holds each quest's objectives (any order), not who you're fighting")
def _():
    """
    local a = NS.FocusKey({ ["Q1"] = { ["wolf"] = true, ["bear"] = true }, ["Q2"] = {} })
    local b = NS.FocusKey({ ["Q2"] = {}, ["Q1"] = { ["bear"] = true, ["wolf"] = true } })
    assert(a == b, "order doesn't matter")
    assert(NS.FocusKey({ ["Q1"] = { ["wolf"] = true } }) ~= a, "an objective changed: a new key (1.7.0: titles only, the same key)")
    assert(NS.FocusKey(nil) == "")
    """

@test("combat focus: enemies counted one by one; the threat API or the threat text, either is enough")
def _():
    """
    MOCK.combat = true
    local T = { title = 17, player = 18, obj = 8 }
    Enum = { TooltipDataLineType = { QuestTitle = T.title, QuestPlayer = T.player, QuestObjective = T.obj } }
    local tips = {}
    C_TooltipInfo = { GetUnit = function(u) return tips[u] end }
    local function mob(name, threatLine)
      local lines = { { leftText = name, type = 0 }, { leftText = "Wolf Hunt", type = T.title }, { leftText = "2/8 Wolf", type = T.obj } }
      if threatLine then lines[#lines + 1] = { leftText = "100% Threat", type = 0 } end
      return { lines = lines }
    end
    local plates = {}
    C_NamePlate = { GetNamePlates = function() return plates end }
    local onList = {}
    UnitThreatSituation = function(_, u) return onList[u] end
    tips["nameplate1"], tips["nameplate2"] = mob("Wolf", true), mob("Wolf", false)
    plates = { { namePlateUnitToken = "nameplate1" }, { namePlateUnitToken = "nameplate2" } }
    onList["nameplate2"] = 1
    local titles, label, how = NS.CombatQuests()
    assert(titles and titles["Wolf Hunt"]["wolf"], "the quest and its objective")
    assert(label == "Wolf x2", "two of one kind: " .. tostring(label))
    assert(how:find("threat API") and how:find("threat text"), how)
    tips["nameplate3"] = mob("Bear", true); plates[3] = { namePlateUnitToken = "nameplate3" }
    local _, label2 = NS.CombatQuests(); assert(label2 == "3 enemies", tostring(label2))
    onList["nameplate2"] = nil
    local _, label3 = NS.CombatQuests(); assert(label3 == "2 enemies", "not fighting you: left out: " .. tostring(label3))
    local report = table.concat(NS.CombatFocusReport(), " / ")
    assert(report:find("fighting 2 enemies") and report:find("Wolf Hunt: wolf"), report)
    """

@test("ranking: the focused quest first; by level when sorting by level, else finished then XP")
def _():
    """
    NS.db.activeZoneOnly = false
    local function Q(id, level, xp, extra) local q = { questID = id, title = "Q" .. id, level = level, xp = xp, complete = false, objectives = {} }
      for k, v in pairs(extra or {}) do q[k] = v end; return q end
    local list = { Q(1, 18, 500), Q(2, 21, 100), Q(3, 19, 900, { complete = true }), Q(4, 15, 50, { focused = true }) }
    NS.db.sortByLevel = true
    local s = NS.BuildSuggestions(list)
    local order = {}
    for i, q in ipairs(s.quests) do order[i] = q.questID end
    assert(table.concat(order, ",") == "4,2,1", "focused, then by level (the finished one is in Turn In): " .. table.concat(order, ","))
    NS.db.sortByLevel = false; NS.db.showTurnIn = false
    s = NS.BuildSuggestions({ Q(1, 18, 500), Q(2, 21, 100), Q(3, 19, 900, { complete = true }) })
    order = {}
    for i, q in ipairs(s.quests) do order[i] = q.questID end
    assert(table.concat(order, ",") == "3,1,2", "finished first, then XP: " .. table.concat(order, ","))
    """


# ---------------------------------------------------------------------------------------------
# Milestone 3: integrations
# ---------------------------------------------------------------------------------------------
@test("questie: its modules behind one boundary; nothing written into its tables; missing parts reported")
def _():
    """
    -- a Questie with its database and available set, a broken quest log and no map markers
    local QA = { __availableQuests = { [101] = true }, CalculateAndDrawAll = function() end }
    local QDB = { IsDoable = function() return true end,
      GetQuest = function(id) return { name = "Quest " .. id, level = 20, zoneOrSort = 12, Starts = {} } end,
      QuestPointers = {}, QueryNPCSingle = function() return nil end, QueryObjectSingle = function() return nil end,
      QueryQuestSingle = function() return nil end }
    local MODULES = { QuestieDB = QDB, QuestXP = { GetQuestLogRewardXP = function() return 500 end }, AvailableQuests = QA,
      QuestiePlayer = { currentQuestlog = "not a table" }, QuestieMap = {} }
    QuestieLoader = { ImportModule = function(_, name) return MODULES[name] end }
    Questie = { API = { RegisterOnReady = function(fn) fn() end } }
    local before = {}
    for k in pairs(QA) do before[k] = true end
    assert(NS.Questie.Init() and NS.Questie.Available(), "bound")
    MOCK.RunTimers()
    for k in pairs(QA) do assert(before[k], "wrote " .. tostring(k) .. " into Questie's module (1.8.0: xppHooked)") end
    assert(NS.Questie.Count() == 1, "the available set scanned: " .. NS.Questie.Count())
    local caps = {}
    for _, c in ipairs(NS.Questie.Capabilities()) do caps[c[1]] = c[2] end
    assert(caps["database"] and caps["available set"] and caps["quest XP"], "there")
    assert(not caps["its quest log"] and not caps["its map markers"] and not caps["zones"], "reported missing")
    local maps = NS.Questie.ActiveQuestMaps(101, false, {})   -- the broken quest log: no error
    local st = NS.Integrations()[1]
    assert(st[1] == "Questie" and st[2] == "partial" and st[3]:find("Missing: zones.", 1, true), "only zones (its quest log and markers are optional): " .. st[3])
    PRINTS = {}; NS.Questie.Diagnose(print)
    assert(table.concat(PRINTS, " "):find("its map markers.-not available"), table.concat(PRINTS, " / "))
    """

@test("what's training: a changed API empties only the Training section; the rest of the list is built")
def _():
    """
    WT_API = { IsReady = function() return true end }   -- no GetSpells, no Status
    local T = NS.Training
    assert(T.Ready() and #T.List(10) == 0, "no spells, no error")
    WT_API.IsReady = function() error("changed") end
    assert(T.Ready() == false, "an error is 'not ready'")
    local s = NS.BuildSuggestions({})
    assert(s and s.training, "the list is built")
    WT_API = { IsReady = function() return true end, GetSpells = function() return {} end, Status = {} }
    local miss = {}
    for _, c in ipairs(T.Capabilities()) do if not c[2] then miss[#miss + 1] = c[1] end end
    assert(table.concat(miss, ",") == "trainers,pet abilities,updates", table.concat(miss, ","))
    """

@test("tracker replacement: the tracker's parent and own alpha come back; an unreadable EllesmereUI setting isn't 'on'")
def _():
    """
    local f = MOCK.obj("ObjectiveTrackerFrame")
    f._parent = UIParent; f._alpha = 0.6
    f.SetParent = function(self, p) if MOCK.combat then error("blocked") end self._parent = p end
    f.GetParent = function(self) return self._parent end
    NS.db.replaceTracker = true; NS.ApplyReplace()
    assert(f._parent ~= UIParent and f._alpha == 0, "hidden away")
    NS.db.replaceTracker = false; NS.ApplyReplace()
    assert(f._parent == UIParent and f._alpha == 0.6, "its own alpha back (1.8.0: 1): " .. tostring(f._alpha))
    -- in combat: nothing moves until it ends
    NS.db.replaceTracker = true; MOCK.combat = true; NS.ApplyReplace()
    assert(f._parent == UIParent, "not in combat")
    MOCK.combat = false; MOCK.Fire("PLAYER_REGEN_ENABLED")
    assert(f._parent ~= UIParent and f._alpha == 0, "after combat")
    -- EllesmereUI's tracker setting
    _G._EQT_SetSuppressed = function() end
    EllesmereUIQuestTracker = { Cfg = function() error("changed") end }
    assert(NS.EUITrackerOn() == nil, "can't tell (1.8.0: true)")
    EllesmereUIQuestTracker.Cfg = function() return false end; assert(NS.EUITrackerOn() == false)
    EllesmereUIQuestTracker.Cfg = function() return true end; assert(NS.EUITrackerOn() == true)
    -- first login with an unreadable setting: replacing isn't switched on by itself
    EllesmereUIQuestTracker.Cfg = function() error("changed") end
    NS.db.replaceTracker = false; NS.db.trackerOffered = nil
    MOCK.Fire("PLAYER_ENTERING_WORLD", true, false)
    assert(NS.db.replaceTracker == false, "not switched on by an unreadable setting")
    """

@test("tomtom: one Hereabouts arrow at a time (the last one taken off first)")
def _():
    """
    local added, removed, uid = {}, {}, 0
    TomTom = { AddWaypoint = function(_, m, x, y, o) uid = uid + 1; added[#added + 1] = uid; return uid end,
      RemoveWaypoint = function(_, u) removed[#removed + 1] = u end }
    C_Map.SetUserWaypoint = nil
    NS.SetWaypoint({ map = 1429, x = 0.4, y = 0.5 }, "A")
    NS.SetWaypoint({ map = 1429, x = 0.6, y = 0.5 }, "B")
    assert(#added == 2 and #removed == 1 and removed[1] == 1, "the first arrow removed before the second")
    local tt
    for _, it in ipairs(NS.Integrations()) do if it[1] == "TomTom" then tt = it end end
    assert(tt[2] == "on", tt[2])
    """


# ---------------------------------------------------------------------------------------------
# Milestone 4: the location model
# ---------------------------------------------------------------------------------------------
WORLD = """
-- a world: each map is a 1000 x 1000 yard square on continent 1, placed side by side by map ID
CreateVector2D = function(x, y) return { x = x, y = y } end
C_Map.GetWorldPosFromMapPos = function(map, v)
  if map == 999 then return 2, { x = v.x * 1000, y = v.y * 1000 } end   -- another continent
  return 1, { x = (map % 100) * 1000 + v.x * 1000, y = v.y * 1000 }
end
C_Map.GetPlayerMapPosition = function() return { GetXY = function() return MOCK.px or 0.5, MOCK.py or 0.5 end } end
"""

@test("locations: checked map IDs and points; Questie's 0-100 spawns become 0-1; no point means somewhere on the map")
def _():
    """
    local L = NS.Locations
    assert(L.New("giver", 0, 0.5, 0.5) == nil and L.New("giver", 12.5) == nil and L.New("bogus", 1429) == nil)
    local a = L.New("giver", 1429, 0.5, 0.5, "Marshal Dughan"); assert(a.map == 1429 and a.x == 0.5 and a.source == "questie")
    local b = L.New("giver", 1429, -0.01, -0.01); assert(b and b.x == nil, "an instance spawn: on the map, no point")
    local spawns = { [12] = { { 41.5, 65.9 }, { -1, -1 } }, [40] = { { -1, -1 } }, [77] = { { 10, 10 } } }
    local toMap = function(area) return ({ [12] = 1429, [40] = 1436 })[area] end
    local list = L.FromSpawns(spawns, "objective", "Kobold", toMap)
    table.sort(list, function(p, q) return p.map < q.map end)
    assert(#list == 2, "area 77 has no map: left out")
    assert(list[1].map == 1429 and math.abs(list[1].x - 0.415) < 1e-9 and math.abs(list[1].y - 0.659) < 1e-9)
    assert(list[2].map == 1436 and list[2].x == nil, "only an instance spawn: somewhere on that map")
    local many = {}
    for i = 1, 60 do many[i] = { i, 50 } end
    assert(#L.FromSpawns({ [12] = many }, "objective", "x", toMap) == L.MAX_POINTS, "capped per area")
    local maps = L.Maps(list); assert(maps[1429] == "Kobold" and maps[1436] == "Kobold")
    assert(#L.Filter(list, { giver = true }) == 0 and #L.Filter(list, { objective = true }) == 2)
    """

@test("locations: distances on one continent, the nearest point, and a nearest-next route", saved=WORLD)
def _():
    """
    local L = NS.Locations
    local from = { 1, 29500, 500 }                    -- on map 1429 (x 29000-30000), its middle
    local near = L.New("objective", 1429, 0.6, 0.5, "near")
    local far = L.New("objective", 1429, 0.9, 0.5, "far")
    local other = L.New("objective", 999, 0.5, 0.5, "another continent")
    local nopoint = L.New("objective", 1429, nil, nil, "somewhere")
    assert(math.abs(L.Yards(near, from) - 100) < 1e-6 and L.Yards(other, from) == nil and L.Yards(nopoint, from) == nil)
    local best, yd = L.Nearest({ far, other, nopoint, near }, from)
    assert(best == near and math.abs(yd - 100) < 1e-6)
    local first = L.Nearest({ other, nopoint }, from, 999); assert(first == other, "nothing measurable: the one on the preferred map")
    local route = L.Route({ far, other, near }, from)
    assert(route[1] == near and route[2] == far and route[3] == other, "nearest next; unmeasurable last")
    """

QUESTIE_WORLD = WORLD + """
QDATA = {
  npcs = { [1] = { name = "Grom", spawns = { [33] = { { 50, 50 } } } },
           [2] = { name = "Naga Explorer", spawns = { [33] = { { 60, 50 }, { 90, 50 } } } },
           [3] = { name = "Wolf", spawns = { [33] = { { 55, 50 } } } } },
  items = { [10] = { name = "Akiris Reed", npcDrops = { 2 } }, [11] = { name = "Old Map", npcDrops = { 3 } } },
  quests = { [500] = { name = "Kill and Gather", Starts = { NPC = { 1 } } },
             [501] = { name = "The Old Map", Starts = { Item = { 11 } } } },
  fields = { [500] = { objectives = { { { 3 } }, {}, { { 10 } } }, finishedBy = { { 1 } } } },
}
local function single(t) return function(id, key) local e = QDATA[t][id]; return e and e[key] end end
MODULES = {
  QuestieDB = { IsDoable = function() return true end, QuestPointers = {},
    GetQuest = function(id) return QDATA.quests[id] end,
    QueryNPCSingle = single("npcs"), QueryObjectSingle = function() return nil end, QueryItemSingle = single("items"),
    QueryQuestSingle = function(id, key) local f = QDATA.fields[id]; return f and f[key] end },
  QuestXP = { GetQuestLogRewardXP = function() return 100 end },
  ZoneDB = { GetUiMapIdByAreaId = function(_, area) return area == 33 and 1434 or nil end },
  AvailableQuests = { __availableQuests = { [501] = true } },
}
QuestieLoader = { ImportModule = function(_, name) return MODULES[name] end }
Questie = { API = { RegisterOnReady = function(fn) fn() end } }
"""

@test("locations from Questie: givers, item starts, objectives, turn-ins; Show on Map for an item-started quest", saved=QUESTIE_WORLD)
def _():
    """
    NS.Questie.Init(); MOCK.RunTimers()
    local L = NS.Locations
    local all = NS.Questie.QuestLocations(500)
    local n = {}
    for _, l in ipairs(all) do n[l.kind] = (n[l.kind] or 0) + 1 end
    assert(n.giver == 1 and n.turnin == 1 and n.objective == 3, "giver, turn-in, wolf + 2 naga spawns (the reed)")
    -- an item-started quest: where its item drops (1.9.0: no location)
    local loc = NS.Questie.Location(501)
    assert(loc and loc.kind == "itemsource" and loc.label:find("starts from Old Map: Wolf", 1, true), loc and loc.label)
    NS.db.pickupZoneOnly = false
    local c
    for _, x in ipairs((NS.Questie.Ranked(10))) do if x.id == 501 then c = x end end
    assert(c and c.starter == "Starts from Old Map", tostring(c and c.starter))
    """

@test("active quests: places left exclude finished objectives; the waypoint goes to the nearest", saved=QUESTIE_WORLD)
def _():
    """
    NS.Questie.Init(); MOCK.RunTimers()
    MOCK.quests = { { questID = 500, title = "Kill and Gather", level = 40 } }
    local objs = { { text = "Wolf slain: 5/5", finished = true }, { text = "Akiris Reed: 2/10", finished = false } }
    C_QuestLog.GetQuestObjectives = function() return objs end
    local left = NS.QuestPlaces(500)
    for _, l in ipairs(left) do assert(l.name == "Akiris Reed", "the wolf is done: " .. tostring(l.name)) end
    assert(#left == 2, "both naga spawns")
    local set
    NS.SetWaypoint = function(l) set = l; return true end
    C_Map.GetBestMapForUnit = function() return 1434 end   -- you're on their map
    MOCK.px, MOCK.py = 0.85, 0.5
    NS.QuestWaypoint(500)
    assert(set and math.abs(set.x - 0.9) < 1e-9, "the nearest naga (90, 50) from (85, 50)")
    MOCK.quests[1].complete = true
    local turn, done = NS.QuestPlaces(500)
    assert(done and #turn == 1 and turn[1].kind == "turnin")
    local report = table.concat(NS.WhereReport(500), " / ")
    assert(report:find("turn-in: 1; nearest turn-in: Grom", 1, true) and report:find("to turn in: turn-in: Grom", 1, true), report)
    """


# ---------------------------------------------------------------------------------------------
# Milestone 5: progression
# ---------------------------------------------------------------------------------------------
@test("history: a session goes into the history when it ends (real login or reset), never on a /reload or zoning")
def _():
    """
    local S = NS.Session
    MOCK.xp, MOCK.level = 100, 20
    S.Reset()
    MOCK.xp = 600; MOCK.Fire("PLAYER_XP_UPDATE", "player")
    MOCK.now = MOCK.now + 1800
    MOCK.Fire("PLAYER_LOGOUT")
    MOCK.Fire("PLAYER_ENTERING_WORLD", false, true)          -- a /reload: carried on, not archived
    assert(#S.History() == 0)
    MOCK.Fire("PLAYER_ENTERING_WORLD", false, false)         -- a loading screen
    assert(#S.History() == 0)
    MOCK.Fire("PLAYER_LOGOUT")
    MOCK.Fire("PLAYER_ENTERING_WORLD", true, false)          -- the next real login
    local h = S.History()
    assert(#h == 1 and h[1].xp == 500 and h[1].dur >= 1800 and h[1].from == 20, "archived")
    assert(HereaboutsCharDB.session == nil, "and not archived again")
    MOCK.Fire("PLAYER_ENTERING_WORLD", true, false); assert(#S.History() == 1)
    -- a reset archives too; a short or empty session doesn't
    -- (the mock keeps this file's session across the "login" above; the game starts it afresh)
    S.Reset(); local n = #S.History()
    MOCK.now = MOCK.now + 30; MOCK.xp = 700; MOCK.Fire("PLAYER_XP_UPDATE", "player"); S.Reset()
    assert(#S.History() == n, "under a minute: not kept")
    MOCK.now = MOCK.now + 120; S.Reset(); assert(#S.History() == n, "nothing gained: not kept")
    MOCK.xp = 900; MOCK.Fire("PLAYER_XP_UPDATE", "player"); MOCK.now = MOCK.now + 120; S.Reset()
    assert(#S.History() == n + 1 and S.History()[1].xp == 200, "a reset keeps it")
    for i = 1, 30 do S.Archive({ at = i, elapsed = 600, gained = i }) end
    assert(#S.History() == S.HISTORY_MAX and S.History()[1].xp == 30, "newest first, capped")
    """

@test("progress: history totals, weapon skills against the level cap, skills from the game")
def _():
    """
    local P = NS.Progress
    local t = P.Totals({ { dur = 1800, xp = 6000, quests = 3, gold = 100, from = 20, to = 21 }, { dur = 1800, xp = 4000, quests = 1, gold = 50, from = 21, to = 21 } })
    assert(t.sessions == 2 and t.xp == 10000 and t.levels == 1 and math.abs(t.xph - 10000) < 1e-9 and t.quests == 4)
    assert(P.WeaponGap({ rank = 195 }, 40) == 5 and P.WeaponGap({ rank = 200 }, 40) == nil)
    C_SkillInfo = { GetSkillLineInfoByID = function(id)
      if id == 186 then return { name = "Mining", rank = 150, maxRank = 225, modifier = 0 } end
      if id == 160 then return { name = "Two-Handed Maces", rank = 209, maxRank = 220, modifier = 0 } end
      if id == 43 then return { name = "Swords", rank = 0, maxRank = 220 } end   -- not learned
      if id == 333 then error("no such line") end
      return nil
    end }
    local sk = P.Skills()
    assert(#sk.professions == 1 and sk.professions[1].name == "Mining" and #sk.weapons == 1, "only skills you have")
    MOCK.level = 44
    local all = table.concat(P.Report(), " / ")
    assert(all:find("Mining 150/225", 1, true) and all:find("Two-Handed Maces 209 (11 to go)", 1, true), all)
    assert(all:find("no past sessions yet", 1, true), all)
    """

@test("dungeons: your quests for each (by quest log heading, wings included); those first; the data unchanged")
def _():
    """
    assert(NS.DungeonQuests("Scarlet Monastery: Library", { ["Scarlet Monastery"] = 2, ["Westfall"] = 1 }) == 2)
    assert(NS.DungeonQuests("Gnomeregan", { ["Gnomeregan"] = 1, ["Gnomeregan Exiles"] = 3 }) == 1, "a whole name, not part of one")
    MOCK.level = 32
    NS.db.sortByLevel = false; NS.db.maxDungeons = 5
    local quests = { { questID = 1, title = "Q", level = 30, xp = 1, complete = false, objectives = {}, zone = "Gnomeregan" } }
    local s = NS.BuildSuggestions(quests)
    assert(s.dungeons[1].name == "Gnomeregan" and s.dungeons[1].quests == 1, "the one with your quest first: " .. s.dungeons[1].name)
    for _, d in ipairs(NS.DUNGEONS) do assert(d.quests == nil, "Dungeons.lua's data untouched") end
    """


# ---------------------------------------------------------------------------------------------
# Milestone 6: modules, layouts, presets
# ---------------------------------------------------------------------------------------------
@test("sections: the order is always every section once (old, damaged or missing orders work); moving one")
def _():
    """
    NS.db.sectionOrder = { "dungeons", "bogus", "quests", "quests" }
    local o = NS.SectionOrder()
    assert(table.concat(o, ",") == "dungeons,quests,turnin,pickup,training", table.concat(o, ","))
    NS.db.sectionOrder = nil
    assert(table.concat(NS.SectionOrder(), ",") == "quests,turnin,pickup,training,dungeons")
    NS.MoveSection("training", -1); NS.MoveSection("dungeons", 1); NS.MoveSection("quests", -1)
    assert(table.concat(NS.db.sectionOrder, ",") == "quests,turnin,training,pickup,dungeons", table.concat(NS.db.sectionOrder, ","))
    -- the list draws in any order without errors
    NS.db.sectionOrder = { "dungeons", "training", "pickup", "turnin", "quests" }
    MOCK.quests = { { questID = 1, title = "Q", level = 20 } }
    NS.Refresh(); MOCK.RunTimers()
    assert(#NS.errors == 0, NS.errors[1] and NS.errors[1].msg)
    """

@test("presets: set what shows (from the defaults), never the look; every preset applies")
def _():
    """
    NS.db.scale = 1.3; NS.db.bgAlpha = 0.9; NS.db.pos = { "TOPLEFT", 5, -5 }
    NS.db.showTraining = false
    assert(NS.ApplyPreset("minimal"))
    assert(NS.db.showTurnIn == false and NS.db.maxQuests == 5 and NS.db.showSession == false and NS.db.showActive == true)
    assert(NS.db.scale == 1.3 and NS.db.bgAlpha == 0.9 and NS.db.pos[2] == 5, "the look and place stay")
    assert(NS.ApplyPreset("questing") and NS.db.showTraining == true and NS.db.showTurnIn == true, "back to the defaults")
    assert(NS.ApplyPreset("dungeon") and NS.SectionOrder()[1] == "dungeons" and NS.db.hideInInstance.turnin == true)
    NS.db.hideInInstance.quests = true
    assert(NS.PRESETS[3][4].hideInInstance.quests == nil, "the preset itself unchanged (a copy)")
    for _, p in ipairs(NS.PRESETS) do assert(NS.ApplyPreset(p[1]), p[1]) end
    assert(not NS.ApplyPreset("nope"))
    """

@test("layouts: saved and loaded as copies; empty slots refuse; 'Reset to defaults' keeps them")
def _():
    """
    NS.db.showDungeons = false; NS.db.maxQuests = 12; NS.db.sectionOrder = { "pickup", "quests", "turnin", "training", "dungeons" }
    NS.SaveLayout(2)
    NS.db.maxQuests = 3; NS.db.sectionOrder[1] = "quests"
    assert(NS.db.layouts[2].values.maxQuests == 12 and NS.db.layouts[2].values.sectionOrder[1] == "pickup", "a copy")
    assert(NS.LoadLayout(2) and NS.db.maxQuests == 12 and NS.db.showDungeons == false and NS.SectionOrder()[1] == "pickup")
    assert(not NS.LoadLayout(1), "empty")
    NS.ResetDB()
    assert(NS.db.maxQuests == 8 and NS.db.layouts and NS.db.layouts[2], "reset: defaults, layouts kept")
    -- the settings window (its Layout page included) builds and refreshes
    NS.OpenOptions()
    assert(XPPlannerOptionsWindow, "built")
    XPPlannerOptionsWindow._shown = true
    NS.RefreshOptions()
    """


# ---------------------------------------------------------------------------------------------
# M7: migrations, combat, large scans, the report
# ---------------------------------------------------------------------------------------------
# what 1.6.1 saved (from the v1.6.1 tag: its settings, before sectionOrder and layouts; a session
# from before startLevel and approx). Older than 1.6: no borderVersion (the defaults test above).
SAVED_161 = """
HereaboutsDB = { maxQuests = 6, showTraining = false, borderVersion = 2, borderColor = { 0.5, 0.5, 0.5 },
  pos = { "TOPLEFT", "TOPLEFT", 40, -200 }, sessionStats = { xph = true, gph = true }, ignoredQuests = { [77] = true } }
HereaboutsCharDB = { session = { elapsed = 1800, gained = 4000, quests = 3, questXP = 2500, earned = 900,
  lastXP = 100, lastMax = 1000, lastLevel = 19, lastMoney = 5000, savedAt = 1699990000 } }
"""

@test("migration: 1.6.1 settings keep the player's choices; new ones filled; its session goes into the history", saved=SAVED_161)
def _():
    """
    local db = NS.db
    assert(db.maxQuests == 6 and db.showTraining == false and db.pos[3] == 40 and db.ignoredQuests[77], "kept")
    assert(db.borderColor == nil and db.sessionStats.gph and not db.sessionStats.ttl, "the player's stats (the border colour setting is gone)")
    assert(#NS.SectionOrder() == #NS.MODULES and db.sectionOrder[1] == "quests", "new settings filled")
    -- a real login (the harness fires it): 1.6.1's session archived, never restored
    local h = NS.Session.History()
    assert(#h == 1 and h[1].xp == 4000 and h[1].quests == 3 and h[1].from == nil and h[1].to == 19, "archived: " .. #h)
    assert(HereaboutsCharDB.session == nil)
    -- a /reload with a 1.6.1-shaped session (no startLevel, no approx): carried on, exact
    HereaboutsCharDB.session = { elapsed = 60, gained = 50, lastXP = 100, lastMax = 1000, lastLevel = 20, lastMoney = 5000, savedAt = MOCK.clock }
    assert(NS.Session.Restore() == true)
    local v = NS.Session.Values()
    assert(v.xp == "50 XP" and not v.approx, tostring(v.xp))
    """

@test("combat: a full rebuild, redraws and every event in combat touch no protected frame and raise no error")
def _():
    """
    GetQuestLogSpecialItemInfo = function(i) return "item:" .. (10 + MOCK.quests[i].questID), 134400 end
    MOCK.methods.GetLeft = function(s) return s._left or 100 end   -- the list's rows on screen
    MOCK.methods.GetTop = function(s) return s._top or 500 end
    MOCK.methods.GetBottom = function(s) return (s._top or 500) - 16 end
    MOCK.quests = { { questID = 1, title = "A", level = 20 }, { questID = 2, title = "B", level = 20 } }
    NS.Refresh("full"); MOCK.RunTimers()
    local QI = NS.QuestItems
    local b1 = QI.buttons[1]
    assert(b1 and b1._protected and b1.questID == 1 and b1._attr.item == "item:11", "set up out of combat")
    MOCK.combat = true; MOCK.Fire("PLAYER_REGEN_DISABLED")
    table.remove(MOCK.quests, 1)
    for _, e in ipairs({ "QUEST_LOG_UPDATE", "ZONE_CHANGED_NEW_AREA", "PLAYER_LEVEL_UP", "QUEST_TURNED_IN", "BAG_UPDATE_DELAYED" }) do
      MOCK.Fire(e, 1, 100, 0)
    end
    for _, k in ipairs({ "full", "log", "redraw" }) do NS.Refresh(k); MOCK.RunTimers() end
    NS.ResetDB(); NS.ApplyPreset("dungeon"); NS.Refresh("full"); MOCK.RunTimers()
    assert(#NS.errors == 0, "no error: " .. (NS.errors[1] and NS.errors[1].msg or ""))
    assert(b1._attr.item == "item:11" and b1.questID == 1 and b1.stale, "A's button: still A's, marked")
    MOCK.combat = false; MOCK.Fire("PLAYER_REGEN_ENABLED"); MOCK.RunTimers()
    assert(b1.questID == 2 and b1._attr.item == "item:12" and not b1.stale, "B's after combat")
    """

@test("questie: a large database scan runs in slices (none over 250 quests) and is timed for /hab perf")
def _():
    """
    local ptrs = {}
    for id = 1, 9000 do ptrs[id] = true end
    local QDB = { IsDoable = function() return true end,
      GetQuest = function(id) return { name = "Quest " .. id, level = 20, zoneOrSort = 12, Starts = {} } end,
      QuestPointers = ptrs, QueryNPCSingle = function() return nil end, QueryObjectSingle = function() return nil end,
      QueryQuestSingle = function() return nil end }
    local MODULES = { QuestieDB = QDB, QuestXP = { GetQuestLogRewardXP = function() return 500 end } }
    QuestieLoader = { ImportModule = function(_, name) return MODULES[name] end }
    Questie = { API = { RegisterOnReady = function(fn) fn() end } }
    local frames = 0
    local after = C_Timer.After
    C_Timer.After = function(d, fn) frames = frames + 1; return after(d, fn) end
    assert(NS.Questie.Init())
    for _ = 1, 100 do if #MOCK.timers == 0 then break end MOCK.RunTimers() end
    local s = NS.Questie.lastScan
    assert(s and s.ids == 9000 and s.from == "Questie's database", "scanned: " .. tostring(s and s.ids))
    assert(s.slices >= 36 and s.max <= s.ms, "in slices of at most 251: " .. s.slices)
    local L = NS.PerfReport()
    assert(table.concat(L, " "):find("last Questie scan: 9000 quests", 1, true), table.concat(L, " / "))
    assert(NS.perf.build == nil, "counting afresh after /hab perf")
    """

@test("report: /hab report is one line with version, integrations, locations, buttons, session, sections, errors")
def _():
    """
    MOCK.quests = { { questID = 1, title = "A", level = 20 } }
    NS.NoteError("testing", "a | bar")
    local r = NS.Report()
    for _, want in ipairs({ "Hereabouts test", "Questie (off)", "your quests: ", "quest item buttons:", "session:",
                            "sections: ", "error (testing" }) do
      assert(r:find(want, 1, true), want .. " missing: " .. r)
    end
    assert(not r:find("\\n") and r:find("a || bar", 1, true), "one line, | doubled")
    PRINTS = {}; SlashCmdList.XPPLANNER("perf")
    assert(PRINTS[1] and PRINTS[1]:find("in the last"), tostring(PRINTS[1]))
    SlashCmdList.XPPLANNER("report")
    local w = XPPlannerReportWindow
    assert(w and w._shown and w.line._text == NS.Report() and w.url:find("template=bug_report.yml&version=test", 1, true), "the report window")
    assert(w.urlBox._text == w.url and w.stats[3]._text:find("Errors caught: |cffffffff1", 1, true), w.stats[3]._text)
    assert(w.kindBtn._text == "Feedback / feature request")
    w.kindBtn._scripts.OnClick()
    assert(w.kind == "idea" and w.urlBox._text:find("feature_request", 1, true) and w.kindBtn._text == "Report a bug instead")
    """

# what 1.12.0 saved: each session value its own setting, also in a saved layout
SAVED_STATS = """
HereaboutsDB = { sessionStats = { ttl = true, gold = true, rested = true },
  layouts = { [1] = { savedAt = 1, values = { sessionStats = { quests = true, xph = true } } } } }
"""

@test("session bars (2.0.0): XP per hour + time to level one bar, gold per hour + gained another; old choices folded in", saved=SAVED_STATS)
def _():
    """
    local st = NS.db.sessionStats
    assert(st.xph and st.gph and st.rested and st.ttl == nil and st.gold == nil, "folded into the XP and gold bars")
    local l = NS.db.layouts[1].values.sessionStats
    assert(l.xp and l.xph and l.quests == nil, "a saved layout folded too")
    assert(NS.PRESETS[5][4].sessionStats.ttl == nil and NS.DEFAULTS.sessionStats.ttl == nil)
    -- the bars: one per stat turned on, each with both its values
    local S = NS.Session
    MOCK.xp = 100; S.Reset(); MOCK.now = MOCK.now + 600; MOCK.xp = 600; MOCK.Fire("PLAYER_XP_UPDATE", "player")
    NS.db.showSession = true; NS.db.sessionStats = { xph = true, gph = true }
    S.Paint()
    local b1, b2 = S.bars[1], S.bars[2]
    assert(b1.text._text:find("XP/h", 1, true) and b1.text._text:find("Level in", 1, true) and b1.kind == "xp", tostring(b1.text._text))
    assert(b2.text._text:find("/h", 1, true) and b2.text._text:find("+", 1, true) and b2.kind == "gold", tostring(b2.text._text))
    assert(not (S.bars[3] and S.bars[3]._shown), "two bars")
    -- hover: everything on XP, or everything on gold
    local lines = {}
    GameTooltip.AddDoubleLine = function(_, a, b) lines[#lines + 1] = a .. "=" .. tostring(b) end
    GameTooltip.AddLine = function() end
    b1._scripts.OnEnter(b1)
    local t = table.concat(lines, " | ")
    for _, want in ipairs({ "XP per hour", "Time to level", "XP this session", "Quests this session", "Rested XP" }) do
      assert(t:find(want, 1, true), want .. ": " .. t)
    end
    assert(not t:find("Gold per hour", 1, true), "no gold on the XP bar")
    lines = {}; b2._scripts.OnEnter(b2); t = table.concat(lines, " | ")
    assert(t:find("Gold per hour", 1, true) and t:find("Gold gained this session", 1, true) and not t:find("XP per hour", 1, true), t)
    -- with What's Training: the gold to train what's available now
    NS.Training.Installed = function() return true end; NS.Training.Ready = function() return true end
    NS.Training.List = function() return {}, 2, 15000 end
    MOCK.money = 5000
    lines = {}; b2._scripts.OnEnter(b2); t = table.concat(lines, " | ")
    assert(t:find("Gold to train now=1g 50s (2 spells), short by 1g 0s", 1, true), t)
    """

@test("settings window (2.1.0): six pages with tabs, framed groups, and a search index that knows each setting's page")
def _():
    """
    NS.OpenOptions()
    assert(XPPlannerOptionsWindow, "built")
    local idx = NS.OptionsIndex()
    local where, per = {}, {}
    for _, e in ipairs(idx) do where[e.label] = e.page; per[e.page] = (per[e.page] or 0) + 1 end
    assert(#NS.OPTION_PAGES == 6, "six pages")
    for i = 1, 6 do assert((per[i] or 0) >= 3, NS.OPTION_PAGES[i][1] .. " has searchable settings: " .. tostring(per[i])) end
    assert(where["Replace the quest tracker"] == 1 and where["Scale"] == 1, "Tracker")
    assert(where["Hide finished objectives"] == 2 and where["Layout 3"] == 3 and where["Current-zone bonus"] == 4, "Lists, Layout, Picking")
    assert(where["Show the session bar"] == 5 and where["Reset to defaults"] == 6, "Session, Status")
    for _, e in ipairs(idx) do assert(type(e.y) == "number" and e.y <= 0 and e.frame, e.label) end
    XPPlannerOptionsWindow._shown = true
    NS.RefreshOptions()
    """

@test("Zone / All (2.1.0): the game's red button with clean and classic headings; FlareUI's box with FlareUI")
def _():
    """
    local function zoneHeader()
      for _, h in ipairs(NS._headers) do if h._shown and (h.zoneBtn.key == "activeZoneOnly" or h.zone.key == "activeZoneOnly") then return h end end
    end
    MOCK.quests = { { questID = 1, title = "Q", level = 20 } }
    NS.db.showActive = true
    for _, classic in ipairs({ false, true }) do
      NS.db.classicHeaders = classic
      NS.Refresh(); MOCK.RunTimers()
      local h = zoneHeader()
      assert(h and h.zoneBtn._shown and not h.zone._shown, "red button, classic=" .. tostring(classic))
    end
    local flare = NS.UsingFlare
    NS.UsingFlare = function() return true end
    NS.Refresh(); MOCK.RunTimers()
    local h = zoneHeader()
    assert(h and h.zone._shown and not h.zoneBtn._shown, "FlareUI's box")
    NS.UsingFlare = flare
    NS.db.classicHeaders = false
    NS.Refresh()
    """

if __name__ == '__main__':
    print(f"\n{count - len(failures)}/{count} passed")
    sys.exit(1 if failures else 0)
