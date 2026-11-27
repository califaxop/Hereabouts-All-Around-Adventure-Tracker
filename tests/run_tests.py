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
    assert(db.sessionStats ~= D.sessionStats and db.borderColor ~= D.borderColor and db.hideInCombat ~= D.hideInCombat, "copies, not the defaults")
    db.hideInInstance.quests = true; db.hideInCombat.pickup = true
    db.sessionStats.xph = nil; db.sessionStats.gold = true
    db.borderColor[1] = 1
    assert(D.hideInInstance.quests == nil and D.hideInCombat.pickup == nil, "1.6.1: the defaults changed with them")
    assert(D.sessionStats.xph == true and D.sessionStats.gold == nil and D.borderColor[1] == 0.40)
    db.pos = { "TOPLEFT", 10, -20 }; db.ignoredQuests[123] = { name = "x", level = 5 }
    db.maxQuests = 3
    NS.ResetDB()
    db = NS.db
    assert(db.hideInInstance.quests == nil and db.hideInCombat.pickup == nil, "hide settings back to none")
    assert(db.sessionStats.xph == true and db.sessionStats.ttl == true and db.sessionStats.gph == true and db.sessionStats.gold == nil)
    assert(db.borderColor[1] == 0.40 and db.borderColor[2] == 0.33 and db.borderColor[3] == 0.22)
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
    assert(db.borderColor[1] == 1, "kept")
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
    assert(labels.gold == "Gold gained this session" and labels.gph == "Gold gained per hour")
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


if __name__ == '__main__':
    print(f"\n{count - len(failures)}/{count} passed")
    sys.exit(1 if failures else 0)
