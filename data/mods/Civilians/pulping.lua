local common = require('civ_common')
local options = require('options')

local faction_civ_id = MonsterFactionId.new("civilians"):int_id()
local faction_zombie_id = MonsterFactionId.new("zombie"):int_id()

local FLAG_FIELD_DRESS_FAILED = JsonFlagId.new("FIELD_DRESS_FAILED")
local FLAG_PULPED = JsonFlagId.new("PULPED")

local function pos_as_key(tripoint)
    return string.format("%d:%d:%d", tripoint.x, tripoint.y, tripoint.z)
end

--- Process civilian corpse pulping behavior
local function process_civilian_corpse_pulping(monster, map, checked_positions)
    local m_pos = monster:get_pos_ms()
    ---@type Item?
    local found_corpse = nil
    ---@type TripointBubMs?
    local corpse_pos = nil

    -- 2. Scan surroundings for unpulped corpses (radius 8 tiles)
    local pulping_radius = options.pulping_radius.get_value()
    local points = map:points_in_radius(m_pos, pulping_radius, 0)
    for _, pt in ipairs(points) do
        local pos_key = pos_as_key(pt)
        if checked_positions[pos_key] == nil then
            checked_positions[pos_key] = true -- Do not check same position twice
            if map:has_items_at(pt) then
                local map_stack = map:get_items_at(pt)
                for _, item in ipairs(map_stack:items()) do
                    if item and not item:is_null() and item:is_corpse() then
                        -- Determine if the corpse has not been pulped yet
                        local is_pulped = item:has_flag(FLAG_PULPED) or item:has_flag(FLAG_FIELD_DRESS_FAILED)
                        local is_max_damage = item:get_damage() >= item:get_max_damage()

                        if not (is_pulped or is_max_damage) then
                            found_corpse = item
                            corpse_pos = pt
                            break
                        end
                    end
                end
            end
        end
        if found_corpse then break end
    end

    if not found_corpse or found_corpse == nil or not corpse_pos or corpse_pos == nil then return end
    ---@cast corpse_pos TripointBubMs

    -- 3. Determine distance and execute action
    local dist = coords.rl_dist(m_pos, corpse_pos) or math.maxinteger
    if dist <= 1 then
        -- Close enough, execute pulping action
        found_corpse:set_damage(found_corpse:get_max_damage())
        found_corpse:set_flag(FLAG_PULPED)

        -- Issue system message (only when the player can see this civilian)
        if gapi.get_avatar():sees(monster:get_pos_ms()) then
            gapi.add_msg(
                MsgType.info,
                string.format("<color_light_red>%s pulped the corpse on the ground!</color>", monster:get_name())
            )
        end

        -- Deduct some moves to simulate attack action
        monster:mod_moves(-100)
    else
        -- Too far, let the civilian walk over there
        monster:wander_to(corpse_pos, 100)
    end
end

-- Execute corpse pulping check for all civilians every 10 turns
local function process_pulping()
  if not options.pulping_enabled.get_value() then return end
  local map = gapi.get_map()
  if not map then return end
  local pulping_civ_limit = options.pulping_civ_limit.get_value()
  local civilians = gapi.get_monsters_if({ ["faction_ids"] = { faction_civ_id }, ["limit"] = pulping_civ_limit })
  -- Dont process if no civilians in sight
  if not civilians then return end

  local hostiles = gapi.get_monsters_if({
    ["faction_ids"] = { faction_zombie_id },
    ["within_range_of"] = { ["range"] = 10, ["monsters"] = civilians },
    ["sees"] = civilians,
    ["hostile_to"] = civilians,
    ["limit"] = 1,
  })

  -- Dont process if hostiles in sight
  if hostiles and #hostiles > 0 then return end

  local pulping_chance = options.pulping_chance.get_value()
  local checked_positions = {}
  for _, mon in ipairs(civilians) do
    if mon and not mon:is_dead() then
      local mon_id = mon:get_type():str()
      -- Only civilians in the whitelist will execute corpse pulping
      if common.CIVILIANS[mon_id].can_pulp then
        -- This means not all civilians will be pulping at the same time
        if gapi.rng(1, 100) <= pulping_chance then process_civilian_corpse_pulping(mon, map, checked_positions) end
      end
    end
  end
end


return {
  process_pulping = process_pulping
}
