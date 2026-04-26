# Blood Moon Mod — Design

Status: approved
Date: 2026-04-26
Branch: main (work to be done on a feature branch)

## Summary

A new content-mod (`data/mods/blood_moon`) plus one new engine-level Lua hook
(`on_hour_passed`). Every 7 in-game days the player gets a 6 PM warning popup
("blood moon rising") and at 10 PM that same day, four zombie hordes spawn at
the cardinal directions ~10 OMTs from the player and converge on them. Horde
size scales with the number of blood moons that have occurred (25 zombies per
event, capped at 200 total split across the four directions). Spawned monsters
follow the game's normal monstergroup time-gating (`GROUP_ZOMBIE`), so later
events naturally include later-game zombie variants — no special evolution
logic in the mod.

## Out of scope

- No JSON content (no custom monstergroups, weather, items).
- No mod options menu — tunables are constants in `main.lua`.
- No sky-tinting or other visuals — would require a weather-mod approach.
- No tests for the new Lua hook (no other Lua hook is unit-tested in this repo).

## Engine change: `on_hour_passed` hook

The mod is driven by a new general-purpose Lua hook that fires at the top of
every in-game hour, including during sleep, waiting, crafting, and any other
turn-advancing activity.

### Why a new hook (vs. existing options)

| Hook | Fires for avatar? | Fires during sleep? | Per-tick cost | Verdict |
|---|---|---|---|---|
| `on_creature_do_turn` | **No** — only fired in `monmove()` and `npcmove()` (`game.cpp:5317,5386`) | n/a | n/a | Unsuitable |
| `on_player_try_move` | Yes, but only on movement actions | **No** | low | Misses sleep |
| `on_character_reset_stats` | Yes (every turn, every character) | Yes | One Lua call/turn/character | Workable but heavy |
| `on_weather_updated` | n/a | Yes (sparse) | low | Cadence too irregular |
| **`on_hour_passed` (new)** | n/a (engine-driven) | **Yes** | 24 calls/in-game-day | **Cleanest** |

A dedicated hourly hook is also generally useful for other future mods.

### Implementation

**1. `src/catalua_hooks.cpp`** — add `"on_hour_passed"` to the `hook_names`
array (line 7-50).

**2. `src/catalua_bindings.cpp`** — add a documentation/typing stub near the
other hook docs (around line 572):

```cpp
DOC( "Called once at the top of every in-game hour, including during sleep/waiting." );
DOC( "The hook receives a table with keys:" );
DOC( "* `turn` (TimePoint): Current turn (top of the new hour)" );
DOC( "* `hour` (int): Hour of day (0-23)" );
DOC_PARAMS( "params" );
luna::set_fx( lib, "on_hour_passed", []( const sol::table & ) {} );
```

**3. `src/game.cpp` in `game::do_turn()`** — fire the hook immediately after
the turn increment (currently at line 1850, `calendar::turn += 1_turns;`):

```cpp
if( calendar::once_every( 1_hours ) ) {
    cata::run_hooks( "on_hour_passed", []( sol::table & params ) {
        params["turn"] = calendar::turn;
        params["hour"] = hour_of_day<int>( calendar::turn );
    } );
}
```

`calendar::once_every(1_hours)` is `(turn - turn_zero) % 1_hours == 0`, so
this fires exactly once per in-game hour boundary. `do_turn` advances
`calendar::turn` by exactly `1_turns` per call, so the modulo can never be
skipped over. Save/load is naturally idempotent — the modulo is computed from
the absolute turn count, not from any tracked "last fired" state.

### Hook firing semantics

- Fires once at the top of every in-game hour: 00:00, 01:00, ..., 23:00.
- Fires during sleep, waiting, crafting, autodrive — anything that calls
  `do_turn`.
- Fires inside `do_turn` after the turn increment, before per-creature
  processing.
- If a player save-scums across an hour boundary, the hook fires once on each
  replay of that boundary. This is acceptable; mod authors who care should
  guard with their own counters (the blood_moon mod does for the spawn).

## Mod: `blood_moon`

### File layout

```
data/mods/blood_moon/
├── modinfo.json        Mod metadata (lua_api_version=2, depends on bn)
├── preload.lua         Hook registration
└── main.lua            All logic
```

### State

All persistent state lives in `game.mod_storage[game.current_mod]`, which is
automatically serialized to the world save by
`catalua.cpp:save_world_lua_state` / `load_world_lua_state`. No avatar
`set_value`/`get_value` and no explicit save/load hooks needed.

```lua
local storage = game.mod_storage[game.current_mod]
storage.last_event_fired = storage.last_event_fired or 0
```

`last_event_fired` is the integer index of the most recent blood moon whose
horde spawn has been processed. Used as a defensive guard against
re-spawning if the hour is replayed (save-scum, etc.). The 6 PM popup is not
guarded — replaying a popup is harmless.

### Trigger logic

```lua
local mod     = game.mod_runtime[game.current_mod]
local storage = game.mod_storage[game.current_mod]

local TURNS_PER_DAY = 24 * 60 * 60   -- BN runs 1 turn per second

mod.on_hour_passed = function(params)
    local hour = params.hour
    if hour ~= 18 and hour ~= 22 then return end

    local now            = gapi.current_turn()
    local turns_elapsed  = now:to_turn() - gapi.turn_zero():to_turn()
    local day            = math.floor(turns_elapsed / TURNS_PER_DAY)
    if day < 7 then return end

    local event_n = math.floor(day / 7)   -- 1, 2, 3, ...

    if hour == 18 then
        show_blood_moon_popup()
    else  -- hour == 22
        if event_n <= (storage.last_event_fired or 0) then return end
        storage.last_event_fired = event_n
        gapi.add_msg(MsgType.bad,
            "The blood moon hangs heavy. You hear distant moans from every direction...")
        spawn_blood_moon_hordes(event_n)
    end
end
```

### Popup (6 PM)

Blocking modal via `query_popup`. Interrupts sleep so the player sees it.

```lua
local function show_blood_moon_popup()
    local popup = QueryPopup.new()
    popup:message_color(Color.c_red)
    popup:message(
        "The Blood Moon Rises\n\n" ..
        "A crimson glow bleeds across the sky. The dead will walk in force tonight.")
    popup:allow_any_key(true)
    popup:query()
end
```

### Horde spawning (10 PM)

```lua
local OFFSETS = {
    Tripoint.new( 0, -10, 0),  -- N
    Tripoint.new(10,   0, 0),  -- E
    Tripoint.new( 0,  10, 0),  -- S
    Tripoint.new(-10,  0, 0),  -- W
}

local function spawn_blood_moon_hordes(event_n)
    local population = math.min(200, 25 * event_n)
    local per_horde  = math.ceil(population / 4)

    local avatar     = gapi.get_avatar()
    local player_omt = avatar:global_omt_location()

    for _, offset in ipairs(OFFSETS) do
        local pos = Tripoint.new(
            player_omt.x + offset.x,
            player_omt.y + offset.y,
            player_omt.z)

        local mg = overmapbuffer.create_horde({
            type       = "GROUP_ZOMBIE",
            pos        = pos,
            population = per_horde,
            radius     = 2,
            horde      = true,
            behaviour  = "roam",
            target     = player_omt,
        })
        if mg then mg:set_interest(100) end
    end
end
```

Horde tuning rationale:
- `radius = 2` — a small spread so each horde feels like a single mass.
- `behaviour = "roam"` — `"city"` would pull them back toward cities; we want
  them to chase the player wherever they are.
- `target = player_omt` — initial target is the player's tile.
- `set_interest(100)` — max drive toward target.
- `population` capped at 200 total → 50 per horde at peak (event 8+).
- `population` floor: `math.ceil(25/4) = 7` at event 1, so each direction gets
  ≥1 zombie always.

### Monster evolution

`GROUP_ZOMBIE` entries in `data/json/monstergroups/zombies.json` are
time-gated via `starts` / `ends` / `replace_monster_group` /
`monster_group_time` fields. When the player encounters one of the spawned
hordes and the game rolls actual monsters from the group at that submap, the
roll respects current calendar time. So a blood moon on day 70 naturally
produces tougher zombies than one on day 7. No mod-side handling required.

### `modinfo.json`

```json
[
  {
    "type": "MOD_INFO",
    "id": "blood_moon",
    "name": "Blood Moon",
    "authors": [ "ChrisLR" ],
    "description": "Every 7 days, a Blood Moon rises and unleashes hordes of zombies upon the player from every direction. Horde size grows with each blood moon, capped at 200.",
    "category": "content",
    "dependencies": [ "bn" ],
    "lua_api_version": 2,
    "version": "1",
    "obsolete": false
  }
]
```

### `preload.lua`

```lua
local mod = game.mod_runtime[game.current_mod]

game.add_hook("on_hour_passed", function(...) return mod.on_hour_passed(...) end)
```

## Edge cases handled

| Case | Behavior |
|---|---|
| Player sleeps through 6 PM/10 PM | Popup is blocking → interrupts sleep. 10 PM spawn fires while still sleeping; player wakes naturally to monster sounds. |
| Player saves between 6 PM and 10 PM | On reload, `do_turn` resumes; the next 22:00 boundary fires the spawn once. |
| Player save-scums across 22:00 | `storage.last_event_fired` guard prevents duplicate spawns within the same `event_n`. |
| Player save-scums across 18:00 | Popup re-shows (cosmetic, harmless). |
| Day 0–6 | No event triggered (`event_n == 0` is filtered). |
| Save from a world without the mod, then add it | `storage.last_event_fired or 0` initializes to 0; first event fires at the next day-7 multiple. |

## Constants and tunables (in `main.lua`)

```lua
local DAYS_PER_EVENT      = 7
local POPULATION_PER_EVENT = 25
local POPULATION_MAX       = 200
local HORDE_DIRECTIONS     = 4
local HORDE_DISTANCE_OMT   = 10
local HORDE_RADIUS         = 2
local WARNING_HOUR         = 18
local SPAWN_HOUR           = 22
```

These are constants, not user-configurable settings.
