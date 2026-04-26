local mod     = game.mod_runtime[game.current_mod]
local storage = game.mod_storage[game.current_mod]

-- Tunables
local DAYS_PER_EVENT       = 7
local POPULATION_BASE      = 25     -- first event population (event_n == 1)
local POPULATION_PER_EVENT = 5      -- added per subsequent event
local POPULATION_MAX       = 200    -- hard cap
local HORDE_DIRECTIONS     = 4
local HORDE_DISTANCE_OMT   = 10
local HORDE_RADIUS         = 1     -- 1 keeps the whole population on one submap; >1 thins via add_mon_group's fractional spread
local WARNING_HOUR         = 18
local SPAWN_HOUR           = 22
local SUNRISE_HOUR         = 4      -- Blood moon ends at this hour
local TRACK_WANDER_FACTOR  = 3600   -- wandf for tracked monsters; comfortably covers an hour of moves
local TRACK_SIGNAL_POWER   = 100    -- "loudness" passed to signal_hordes during tracking

-- BN runs 1 turn per second.
local TURNS_PER_DAY = 24 * 60 * 60

-- Persistent state (auto-saved with the world via mod_storage).
storage.last_event_fired  = storage.last_event_fired or 0
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

local function spawn_blood_moon_hordes(event_n)
    local population = blood_moon_population(event_n)
    local per_horde  = math.ceil(population / HORDE_DIRECTIONS)

    local avatar     = gapi.get_avatar()
    if not avatar then return end
    local player_omt = avatar:global_omt_location()

    -- Hordes live on the overmap surface (z=0). Vanilla place_mongroups hardcodes
    -- this; horde movement ignores z anyway. If the player is in a basement/upper
    -- floor when 22:00 hits, we still spawn at the surface OMT they're under/above.
    local target_omt = Tripoint.new(player_omt.x, player_omt.y, 0)

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
        if mg then mg:set_interest(100) end
    end
end

-- Hourly nudge that keeps both loaded monsters and unloaded hordes drawn to the player.
-- wander_to sets each monster's destination + wandf so it paths toward the player even
-- without line-of-sight; signal_hordes does the same at the overmap level for off-screen hordes.
local function track_player_for_horde()
    local avatar = gapi.get_avatar()
    if not avatar then return end

    local player_pos = avatar:global_square_location()
    for _, m in ipairs(gapi.get_all_monsters()) do
        -- Skip monsters on other z-levels: basement zombies, second-floor monsters,
        -- sewer creatures etc. would otherwise spam "Failed to find a trivial path
        -- across z-levels" and waste a wandf they can't act on.
        if m:global_square_location().z == player_pos.z then
            m:wander_to(player_pos, TRACK_WANDER_FACTOR)
        end
    end

    local player_sm = avatar:global_sm_location()
    overmapbuffer.signal_hordes(player_sm, TRACK_SIGNAL_POWER)
end

mod.on_hour_passed = function(params)
    local hour    = params.hour
    local event_n = current_event_n()

    -- 6 PM: announce the imminent blood moon.
    if hour == WARNING_HOUR and event_n > 0 then
        show_blood_moon_popup()
        return
    end

    -- 10 PM on a blood moon day: spawn the hordes and start tracking.
    if hour == SPAWN_HOUR and event_n > 0 and event_n > storage.last_event_fired then
        storage.last_event_fired  = event_n
        storage.blood_moon_active = true
        gapi.add_msg(MsgType.bad,
            "The blood moon hangs heavy. You hear distant moans from every direction...")
        spawn_blood_moon_hordes(event_n)
        track_player_for_horde()
        return
    end

    -- 4 AM: end the blood moon.
    if hour == SUNRISE_HOUR and storage.blood_moon_active then
        storage.blood_moon_active = false
        gapi.add_msg(MsgType.good,
            "Dawn breaks. The blood moon fades, and the world feels still.")
        return
    end

    -- Any other hour while the blood moon is active: re-aim everything at the player.
    if storage.blood_moon_active then
        track_player_for_horde()
    end
end
