local mod = game.mod_runtime[game.current_mod]
local options = require("options")

TRY_TRIES = 5 -- Number of attempts to find a nearby empty tile
-- NPC exclusive area list (avoid spawning wild civilians in these areas)
---@type table<string>
local NPC_TERRAINS = {
  "refctr", -- Refugee center related
  "evac_center", -- Evac center related
  "robofachq", -- Hub 01 HQ
  "isherwood", -- Isherwood Farm
  "_ocu", -- Occupied Stronghold
  "cabin_strange", -- Strange Cabin
  "cabin_lapin", -- Lapin Cabin
  "lab",
  "microlab",
  "necropolis",
  "mil_base",
  "bunker",
  "outpost",
  "prison",
  "aircraft_carrier",

  -- MOD location
  "fema_evac", -- FEMA Evac
  "GKB_SCRAPBASE", -- Scrapper Base faction base
  "FO_PLAYER_VAULT", -- Vault-Tec friendly vault
  "FO_WASTETOWN", -- Wastetown settlement
  "ZhighSchool", -- Zombie High School map
  "Survivor_Holdout", -- Survivor Holdout defense line
  "Survivor_Encampment", -- Survivor various encampments
  "surv_camp", -- Wilderness special survivor camp
  "forest_slaghter", -- Forest slaughterhouse
  "makeshift_command_center", -- Makeshift command center
  "Plain_Slaughter", -- Plain slaughterhouse
}

-- Furniture list where civilians can spawn
---@type table<string, boolean>
local TARGET_FURNITURE = {
  ["f_locker"] = true,
  ["f_wardrobe"] = true,
  ["f_chair"] = true,
  ["f_sofa"] = true,
  ["f_stool"] = true,
  ["f_bench"] = true,
  ["f_bed"] = true,
  ["f_chair_folding"] = true,
  ["f_armchair"] = true,
}

local function is_valid_spawn_spot(map, p)
  local ter_id = map:get_ter_at(p)
  if ter_id:obj():get_movecost() <= 0 then return false end
  return true
end

local function find_nearby_free_tile(map, center_p)
  local map_size = map:get_map_size()
  for i = 1, TRY_TRIES do
    local dx = gapi.rng(-2, 2)
    local dy = gapi.rng(-2, 2)
    local tx = center_p.x + dx
    local ty = center_p.y + dy
    if tx >= 0 and tx < map_size and ty >= 0 and ty < map_size then
      local p = PointOmtMs.new(tx, ty)
      if is_valid_spawn_spot(map, p) then return p end
    end
  end
  return nil
end

local function decide_spawn_group()
  local days = (gapi.current_turn() - gapi.turn_zero()):to_days()
  local vanish_base_rate = options.vanish_base_rate.get_value()
  local vanish_period_days = options.vanish_period_days.get_value()
  local survival_chance = vanish_base_rate ^ (days / vanish_period_days)
  local rare_chance = options.rare_chance.get_value()

  if gapi.rng(1, 10000) > (survival_chance * 10000) then return nil end
  if gapi.rng(1, 100) <= rare_chance then
    return "GROUP_LUA_RARE_HUMANS"
  else
    return "GROUP_LUA_COMMON_HUMANS"
  end
end

mod.on_mapgen_postprocess = function(params)
    local map = params.map
    local omt_pos = params.omt

    -- Check if the currently generated map matches any NPC exclusive area prefix, if so skip directly
    if omt_pos then
        for _, prefix in ipairs(NPC_TERRAINS) do
            if overmapbuffer.check_ot(prefix, OtMatchType.CONTAINS, omt_pos) then return end
        end
    end

    local size = map:get_map_size()
    local current_chance = options.spawn_chance.get_value()
    for x = 0, size - 1 do
        for y = 0, size - 1 do
            local local_p = PointOmtMs.new(x, y)
            local furn = map:get_furn_at(local_p)

            if furn and furn:is_valid() then
                local furn_str = furn:str_id():str()
                if TARGET_FURNITURE[furn_str] then
                    if gapi.rng(1, 100) <= current_chance then
                        local group_id = decide_spawn_group()
                        if group_id then
                            local spawn_local_p = find_nearby_free_tile(map, local_p)
                            if spawn_local_p then map:place_spawns(group_id, 1, spawn_local_p, spawn_local_p, 1.0, true) end
                        end
                    end
                end
            end
        end
    end
end
