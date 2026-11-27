-- Trainer data (1.11.0: kept apart from the code that uses it, Training.lua). From What's
-- Training's Forever data (MIT license, github.com/fusionpit/WhatsTraining): verified through its
-- source, not checked city by city on Forever (API_COMPATIBILITY.md).
local _, ns = ...
ns.TRAINER_DATA = {}
ns.TRAINER_DATA.CITIES = {
  -- [factionID] = name if the game can't tell us
  [47] = "Ironforge", [54] = "Gnomeregan", [69] = "Darnassus", [72] = "Stormwind",
  [68] = "Undercity", [76] = "Orgrimmar", [81] = "Thunder Bluff", [530] = "Darkspear Trolls",
}
ns.TRAINER_DATA.ROLES = {
  DRUID   = { Alliance = { 69, 72 },          Horde = { 81 } },
  HUNTER  = { Alliance = { 47, 69, 72 },      Horde = { 76, 81, 530 } },
  MAGE    = { Alliance = { 47, 54, 69, 72 },  Horde = { 68, 76, 530 } },
  PALADIN = { Alliance = { 47, 72 },          Horde = { 68 } },
  PET     = { Alliance = { 47, 69, 72 },      Horde = { 76, 81 } },
  PRIEST  = { Alliance = { 47, 54, 69, 72 },  Horde = { 68, 76, 530 } },
  ROGUE   = { Alliance = { 47, 54, 69, 72 },  Horde = { 68, 76, 81, 530 } },
  SHAMAN  = { Alliance = { 47 },              Horde = { 76, 81 } },
  WARLOCK = { Alliance = { 47, 54, 72 },      Horde = { 68, 76 } },
  WARRIOR = { Alliance = { 47, 54, 69, 72 },  Horde = { 68, 76, 81 } },
}
-- weapon masters -> their city
ns.TRAINER_DATA.WEAPON_NPCS = { [2704] = 530, [11865] = 47, [11866] = 69, [11867] = 72, [11868] = 76, [11869] = 81, [11870] = 68, [13084] = 47 }

-- the city discount with reputation: Honored or better (reaction 6+) takes 10% off (What's
-- Training's rule on Forever)
ns.TRAINER_DATA.DISCOUNT = { reaction = 6, pct = 10 }
