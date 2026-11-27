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
    assert(all:find("Questie: installed false") and all:find("quest item buttons: 0 shown") and all:find("errors caught: 1"), all)
    PRINTS = {}; SlashCmdList.XPPLANNER("errors")
    assert(PRINTS[1]:find("drawing the list %(x2%): boom"), PRINTS[1])
    """


if __name__ == '__main__':
    print(f"\n{count - len(failures)}/{count} passed")
    sys.exit(1 if failures else 0)
