---@class CivData
---@field type_id string
---@field can_pulp boolean
---@field recruitable boolean
---@field recruit_skill_req number
---@field promotes_to string
---@field promote_difficulty number
---@field likes_alcohol boolean
---@field likes_drugs boolean

---@type table<string, CivData>
local CIVILIANS = {
    mon_civilian_panic = {
        type_id = "mon_civilian_panic",
        can_pulp = false,
        recruitable = true,
        recruit_skill_req = 3,
        promotes_to = "mon_civilian_zombiefighter",
        promote_difficulty = 1,
        likes_alcohol = true,
        likes_drugs = true,
    },
    mon_civilian_stationary = {
        type_id = "mon_civilian_stationary",
        can_pulp = false,
        recruitable = false,
        recruit_skill_req = 11,
        promotes_to = "mon_civilian_panic",
        promote_difficulty = 1,
        likes_alcohol = true,
        likes_drugs = true,
    },
    mon_civilian_police = {
        type_id = "mon_civilian_police",
        can_pulp = false,
        recruitable = true,
        recruit_skill_req = 4,
        promotes_to = "mon_civilian_survivor_pistol",
        promote_difficulty = 2,
        likes_alcohol = true,
        likes_drugs = false,
    },
    mon_civilian_zombiefighter = {
        type_id = "mon_civilian_zombiefighter",
        can_pulp = false,
        recruitable = true,
        recruit_skill_req = 4,
        promotes_to = "mon_civilian_survivor_fighter",
        promote_difficulty = 2,
        likes_alcohol = true,
        likes_drugs = true,
    },
    mon_civilian_icu = {
        type_id = "mon_civilian_icu",
        can_pulp = false,
        recruitable = false,
        recruit_skill_req = 11,
        promotes_to = "",
        promote_difficulty = 11,
        likes_alcohol = false,
        likes_drugs = false
    },
    mon_civilian_parent = {
        type_id = "mon_civilian_parent",
        can_pulp = false,
        recruitable = true,
        recruit_skill_req = 3,
        promotes_to = "mon_civilian_survivor_bow",
        promote_difficulty = 2,
        likes_alcohol = true,
        likes_drugs = true
    },
    mon_civilian_child = {
        type_id = "mon_civilian_child",
        can_pulp = false,
        recruitable = true,
        recruit_skill_req = 2,
        promotes_to = "mon_civilian_survivor_child",
        promote_difficulty = 2,
        likes_alcohol = false,
        likes_drugs = false
    },
   mon_civilian_survivor_child = {
        type_id = "mon_civilian_survivor_child",
        can_pulp = true,
        recruitable = true,
        recruit_skill_req = 5,
        promotes_to = "mon_civilian_survivor_child_elite",
        promote_difficulty = 4,
        likes_alcohol = false,
        likes_drugs = false
    },
    mon_civilian_survivor_bow = {
        type_id = "mon_civilian_survivor_bow",
        can_pulp = true,
        recruitable = true,
        recruit_skill_req = 5,
        promotes_to = "mon_civilian_survivor_elite_bow",
        promote_difficulty = 4,
        likes_alcohol = true,
        likes_drugs = true
    },
    mon_civilian_survivor_crossbow = {
        type_id = "mon_civilian_survivor_crossbow",
        can_pulp = true,
        recruitable = true,
        recruit_skill_req = 5,
        promotes_to = "mon_civilian_survivor_elite_crossbow",
        promote_difficulty = 4,
        likes_alcohol = true,
        likes_drugs = true
    },
    mon_civilian_survivor_pistol = {
        type_id = "mon_civilian_survivor_pistol",
        can_pulp = true,
        recruitable = true,
        recruit_skill_req = 5,
        promotes_to = "mon_civilian_survivor_elite_pistol",
        promote_difficulty = 4,
        likes_alcohol = true,
        likes_drugs = true
    },
    mon_civilian_survivor_fighter = {
        type_id = "mon_civilian_survivor_fighter",
        can_pulp = true,
        recruitable = true,
        recruit_skill_req = 5,
        promotes_to = "mon_civilian_survivor_elite_fighter",
        promote_difficulty = 4,
        likes_alcohol = true,
        likes_drugs = true
    },
    mon_civilian_survivor_guardian_shotgun = {
        type_id = "mon_civilian_survivor_guardian_shotgun",
        can_pulp = true,
        recruitable = true,
        recruit_skill_req = 6,
        promotes_to = "mon_civilian_survivor_guardian_elite_rifle",
        promote_difficulty = 5,
        likes_alcohol = true,
        likes_drugs = true
    },
    mon_civilian_survivor_guardian_smg = {
        type_id = "mon_civilian_survivor_guardian_smg",
        can_pulp = true,
        recruitable = true,
        recruit_skill_req = 6,
        promotes_to = "mon_civilian_survivor_guardian_elite_AR",
        promote_difficulty = 5,
        likes_alcohol = true,
        likes_drugs = true
    },
    mon_civilian_survivor_elite_bow = {
        type_id = "mon_civilian_survivor_elite_bow",
        can_pulp = true,
        recruitable = true,
        recruit_skill_req = 6,
        promotes_to = "npc",
        promote_difficulty = 6,
        likes_alcohol = true,
        likes_drugs = true
    },
    mon_civilian_survivor_elite_crossbow = {
        type_id = "mon_civilian_survivor_elite_crossbow",
        can_pulp = true,
        recruitable = true,
        recruit_skill_req = 6,
        promotes_to = "npc",
        promote_difficulty = 6,
        likes_alcohol = true,
        likes_drugs = true
    },
    mon_civilian_survivor_elite_pistol = {
        type_id = "mon_civilian_survivor_elite_pistol",
        can_pulp = true,
        recruitable = true,
        recruit_skill_req = 6,
        promotes_to = "npc",
        promote_difficulty = 6,
        likes_alcohol = true,
        likes_drugs = true
    },
    mon_civilian_survivor_elite_fighter = {
        type_id = "mon_civilian_survivor_elite_fighter",
        can_pulp = true,
        recruitable = true,
        recruit_skill_req = 6,
        promotes_to = "npc",
        promote_difficulty = 6,
        likes_alcohol = true,
        likes_drugs = true
    },
    mon_civilian_survivor_guardian_elite_rifle = {
        type_id = "mon_civilian_survivor_guardian_elite_rifle",
        can_pulp = true,
        recruitable = true,
        recruit_skill_req = 6,
        promotes_to = "npc",
        promote_difficulty = 6,
        likes_alcohol = true,
        likes_drugs = true
    },
    mon_civilian_survivor_guardian_elite_AR = {
        type_id = "mon_civilian_survivor_guardian_elite_AR",
        can_pulp = true,
        recruitable = true,
        recruit_skill_req = 6,
        promotes_to = "npc",
        promote_difficulty = 6,
        likes_alcohol = true,
        likes_drugs = true
    },
    mon_civilian_survivor_child_elite = {
        type_id = "mon_civilian_survivor_child_elite",
        can_pulp = true,
        recruitable = true,
        recruit_skill_req = 6,
        promotes_to = "npc",
        promote_difficulty = 6,
        likes_alcohol = true,
        likes_drugs = true
    }
}

---@class CivStatVar
---@field key string
---@field type type
---@field default string
---@field get function

---@param key string
---@param mon Monster
---@param default string
---@return number?
local get_number_var = function(key, mon, default)
    local str_val = mon:get_value(key)
    local int_val = tonumber(str_val)
    if int_val == nil or not int_val then
        int_val = tonumber(default)
        mon:set_value(key, default)
    end
    return int_val
end

---@param key string
---@param mon Monster
---@return TimePoint
local get_time_var = function(key, mon)
    local str_val = mon:get_value(key)
    local int_val = tonumber(str_val)
    ---@type TimePoint
    local time_val
    if int_val == nil or not int_val then
        time_val = gapi.turn_zero()
    else
        time_val = TimePoint.from_turn(int_val)
    end

    return time_val
end

---@class CivStats
---@field anger CivStatVar
---@field trust CivStatVar
---@field exp CivStatVar
---@field last_fed CivStatVar
---@field last_talk CivStatVar
---@field last_promote CivStatVar

---@type table<CivStatVar>
local CIV_STATS = {
  ANGER = {
      key = "civ_cst_anger",
      type = "number",
      default = "50",
  },
  TRUST = {
      key = "civ_cst_trust",
      type = "number",
      default = "50",
  },
  EXP = {
      key = "civ_cst_exp",
      type = "number",
      default = "0",
    },
  LAST_FED = {
      key = "civ_cst_last_fed",
      type = "TimePoint",
      default = "0",
    },
  LAST_TALK = {
      key = "civ_cst_last_talk",
      type = "TimePoint",
      default = "0",
    },
  LAST_PROMOTE = {
      key = "civ_cst_last_promote",
      type = "TimePoint",
      default = "0",
  }
}

---@class CivValues
---@field anger number
---@field trust number
---@field exp number
---@field last_fed TimePoint
---@field last_talk TimePoint
---@field last_promote TimePoint

---@param mon Monster
---@return CivValues
local get_civ_stats = function(mon)
    return {
        anger = get_number_var(CIV_STATS.ANGER.key, mon, CIV_STATS.ANGER.default),
        trust = get_number_var(CIV_STATS.TRUST.key, mon, CIV_STATS.TRUST.default),
        exp = get_number_var(CIV_STATS.EXP.key, mon, CIV_STATS.EXP.default),
        last_fed = get_time_var(CIV_STATS.LAST_FED.key, mon),
        last_talk = get_time_var(CIV_STATS.LAST_TALK.key, mon),
        last_promote = get_time_var(CIV_STATS.LAST_PROMOTE.key, mon)
    }
end



return {
    CIVILIANS = CIVILIANS,
    CIV_STATS = CIV_STATS,
    get_civ_stats = get_civ_stats,
}
