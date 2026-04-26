local mod     = game.mod_runtime[game.current_mod]
local storage = game.mod_storage[game.current_mod]

-- Tunables
local DAYS_PER_EVENT       = 7
local POPULATION_BASE      = 25     -- first event population (event_n == 1)
local POPULATION_PER_EVENT = 5      -- added per subsequent event
local POPULATION_MAX       = 200    -- hard cap
local HORDE_DIRECTIONS     = 4
local HORDE_DISTANCE_OMT   = 10
local HORDE_RADIUS         = 2
local WARNING_HOUR         = 18
local SPAWN_HOUR           = 22

-- BN runs 1 turn per second.
local TURNS_PER_DAY = 24 * 60 * 60

-- Persistent state (auto-saved with the world via mod_storage).
storage.last_event_fired = storage.last_event_fired or 0

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

mod.on_hour_passed = function(params)
    local hour = params.hour
    if hour ~= WARNING_HOUR and hour ~= SPAWN_HOUR then return end

    local event_n = current_event_n()
    if event_n == 0 then return end

    if hour == WARNING_HOUR then
        show_blood_moon_popup()
    end
    -- SPAWN_HOUR handled in the next task
end
