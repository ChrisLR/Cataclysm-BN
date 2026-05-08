local mod     = game.mod_runtime[game.current_mod]
local storage = game.mod_storage[game.current_mod]

-- Tunables
local DAYS_PER_EVENT       = 7
local POPULATION_BASE      = 25     -- first event population (event_n == 1)
local POPULATION_PER_EVENT = 5      -- added per subsequent event
local POPULATION_MAX       = 200    -- hard cap
local HORDE_DIRECTIONS     = 4
local HORDE_DISTANCE_OMT   = 3      -- must clear the 5-submap reality bubble radius; 3 OMTs = 6 submaps
local HORDE_RADIUS         = 1      -- 1 keeps the whole population on one submap; >1 thins via add_mon_group's fractional spread
local WARNING_HOUR         = 18
local SPAWN_HOUR           = 22
local SUNRISE_HOUR         = 4      -- Blood moon ends at this hour
local TRACK_WANDER_FACTOR  = 3600   -- wandf for tracked monsters; comfortably covers an hour of moves
local TRACK_SIGNAL_POWER   = 100    -- "loudness" passed to signal_hordes during tracking
local DIRECT_SPAWN_RADIUS  = 30     -- tile radius for underground/elevated direct spawns

-- Approximate GROUP_ZOMBIE composition for direct spawning (underground/elevated).
-- Weighted toward common types; crawlers and dogs intentionally under-represented.
local DIRECT_SPAWN_TYPES = {
    "mon_zombie", "mon_zombie", "mon_zombie", "mon_zombie",
    "mon_zombie_fat", "mon_zombie_fat",
    "mon_zombie_tough",
    "mon_zombie_child",
    "mon_zombie_rot",
    "mon_zombie_crawler",
    "mon_zombie_dog",
}
local DIRECT_TYPE_COUNT = #DIRECT_SPAWN_TYPES

-- BN runs 1 turn per second.
local TURNS_PER_DAY = 24 * 60 * 60

-- Persistent state (auto-saved with the world via mod_storage).
storage.last_event_fired  = storage.last_event_fired or 0
storage.last_warned_event = storage.last_warned_event or 0
storage.blood_moon_active = storage.blood_moon_active or false

local function current_event_n()
    local now           = gapi.current_turn()
    local turns_elapsed = now:to_turn() - gapi.turn_zero():to_turn()
    local day           = math.floor(turns_elapsed / TURNS_PER_DAY)
    if day < DAYS_PER_EVENT then return 0 end
    return math.floor(day / DAYS_PER_EVENT)
end

local function show_blood_moon_popup()
    local popup = QueryPopup.new()
    popup:message_color(Color.c_red)
    popup:message(
        "The Blood Moon Rises\n\n" ..
        "A crimson glow bleeds across the sky. The dead will walk in force tonight.")
    popup:allow_any_key(true)
    popup:query()
end

local OFFSETS = {
    Tripoint.new( 0, -HORDE_DISTANCE_OMT, 0),  -- N
    Tripoint.new( HORDE_DISTANCE_OMT,  0, 0),  -- E
    Tripoint.new( 0,  HORDE_DISTANCE_OMT, 0),  -- S
    Tripoint.new(-HORDE_DISTANCE_OMT,  0, 0),  -- W
}

local function blood_moon_population(event_n)
    return math.min(POPULATION_MAX,
                    POPULATION_BASE + (event_n - 1) * POPULATION_PER_EVENT)
end

-- Returns true if the player is standing on open air (NO_FLOOR terrain) — i.e. in a
-- flying vehicle like a plane. A rooftop or upper floor of a building will have a real
-- floor tile and return false, meaning zombies could potentially climb up to them.
local function player_is_unreachable(avatar)
    local m         = gapi.get_map()
    local local_pos = m:get_local_ms(avatar:get_pos_ms())
    return m:get_ter_at(local_pos):obj():has_flag("NO_FLOOR")
end

-- Returns true if there is at least one staircase leading up within DIRECT_SPAWN_RADIUS
-- tiles of the player. If true, surface hordes can descend to the player via stairs so
-- we prefer the normal overmap horde system over direct spawning.
local function has_surface_path(avatar)
    local m          = gapi.get_map()
    local player_pos = m:get_local_ms(avatar:get_pos_ms())
    for _, pt in ipairs(m:points_in_radius(player_pos, DIRECT_SPAWN_RADIUS)) do
        if m:get_ter_at(pt):obj():has_flag("GOES_UP") then
            return true
        end
    end
    return false
end

-- Spawn individual monsters directly near the player (used when the overmap horde
-- system cannot reach them: underground or on an accessible upper floor).
local function spawn_direct_monsters(population, avatar)
    local m         = gapi.get_map()
    local local_pos = m:get_local_ms(avatar:get_pos_ms())
    for _ = 1, population do
        local mtype = DIRECT_SPAWN_TYPES[gapi.rng(1, DIRECT_TYPE_COUNT)]
        gapi.place_monster_around(mtype, local_pos, DIRECT_SPAWN_RADIUS)
    end
end

-- Spawn four overmap hordes around the player's surface position (z=0 only).
local function spawn_surface_hordes(event_n, avatar)
    local population  = blood_moon_population(event_n)
    local per_horde   = math.floor(population / HORDE_DIRECTIONS)
    local player_omt  = avatar:global_omt_location()
    -- Target is always the surface tile the player is above/below.
    local target_omt  = Tripoint.new(player_omt.x, player_omt.y, 0)

    for _, offset in ipairs(OFFSETS) do
        local pos = Tripoint.new(
            player_omt.x + offset.x,
            player_omt.y + offset.y,
            0)

        local mg = overmapbuffer.create_horde({
            type       = "GROUP_ZOMBIE",
            pos        = pos,
            population = per_horde,
            radius     = HORDE_RADIUS,
            horde      = true,
            behaviour  = "roam",
            target     = target_omt,
        })
        if mg then
            mg:set_interest(100)
            mg.speed_modifier = 3.0
        end
    end
end

-- Route the spawn to the right strategy based on the player's z-level.
local function spawn_blood_moon(event_n)
    local avatar = gapi.get_avatar()
    if not avatar then return end

    local z = avatar:global_omt_location().z

    if z == 0 then
        -- Surface: overmap hordes march in from four directions.
        spawn_surface_hordes(event_n, avatar)
    elseif z < 0 then
        -- Underground: if stairs lead up, surface hordes can descend via them.
        -- Only fall back to direct spawning when the player is truly sealed in.
        if has_surface_path(avatar) then
            spawn_surface_hordes(event_n, avatar)
        else
            spawn_direct_monsters(blood_moon_population(event_n), avatar)
        end
    else
        -- Elevated (upper floor, rooftop): spawn directly only if the player is
        -- standing on real terrain that zombies could climb to via stairs/ramps.
        -- NO_FLOOR means open air — a flying vehicle — so skip entirely.
        if not player_is_unreachable(avatar) then
            spawn_direct_monsters(blood_moon_population(event_n), avatar)
        end
    end
end

-- Hourly nudge that keeps both loaded monsters and unloaded hordes drawn to the player.
-- set_goal puts each loaded monster in active-chase mode so it will bash through obstacles;
-- signal_hordes keeps off-screen overmap hordes aimed at the player's submap position.
local function track_player_for_horde()
    local avatar = gapi.get_avatar()
    if not avatar then return end

    -- wander_to expects local-map (ms) coordinates: monster::wander_pos shifts with
    -- the reality bubble (monster.cpp:1237). Both avatar and monster inherit Creature
    -- so both have get_pos_ms (catalua_bindings_creature.cpp:120).
    -- Zombies have can_climb_stairs=true by default (monstergenerator.cpp), so the
    -- pathfinder will route them through stairs even when the goal is on a different z.
    local player_pos = avatar:get_pos_ms()
    for _, m in ipairs(gapi.get_all_monsters()) do
        -- Skip tamed pets and other friendlies.
        if m.friendly == 0 then
            -- set_goal puts the monster in active-chase mode so it will bash
            -- through windows and doors; wander_to only sets a heading and the
            -- engine skips bashing for wandering monsters (monmove.cpp:1276).
            m:set_goal(player_pos)
            -- Keep anger maxed so the monster never stops chasing between ticks.
            m.anger = 100
        end
    end

    -- Overmap hordes exist only at z=0; always signal them at the surface position
    -- so they converge toward the player's x/y regardless of the player's z-level.
    local player_sm = avatar:global_sm_location()
    local player_z  = avatar:global_omt_location().z
    local signal_sm = player_z < 0
        and Tripoint.new(player_sm.x, player_sm.y, 0)
        or  player_sm
    overmapbuffer.signal_hordes(signal_sm, TRACK_SIGNAL_POWER)
end

mod.on_game_load = function()
    if storage.blood_moon_active then
        gapi.set_weather_override("blood_moon", true)
    end
end

mod.on_hour_passed = function(params)
    local hour    = params.hour
    local event_n = current_event_n()

    -- 6 PM: announce the imminent blood moon (once per event cycle).
    if hour == WARNING_HOUR and event_n > storage.last_event_fired and event_n > storage.last_warned_event then
        storage.last_warned_event = event_n
        show_blood_moon_popup()
        return
    end

    -- 10 PM on a blood moon day: force the weather to blood moon and spawn.
    if hour == SPAWN_HOUR and event_n > 0 and event_n > storage.last_event_fired then
        storage.last_event_fired  = event_n
        storage.blood_moon_active = true
        gapi.set_weather_override("blood_moon", true)
        spawn_blood_moon(event_n)
        track_player_for_horde()
        return
    end

    -- 4 AM: end the blood moon and restore normal weather.
    if hour == SUNRISE_HOUR and storage.blood_moon_active then
        storage.blood_moon_active = false
        gapi.clear_weather_override()
        return
    end

    -- Any other hour while the blood moon is active: re-aim everything at the player.
    if storage.blood_moon_active then
        track_player_for_horde()
    end
end
