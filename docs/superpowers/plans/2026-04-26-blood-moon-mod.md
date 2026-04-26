# Blood Moon Mod Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a new general-purpose Lua hook `on_hour_passed` to the engine, then build a `blood_moon` mod on top of it that triggers a horde-spawn event every 7 in-game days.

**Architecture:** Engine change in 3 C++ files (hook registration + binding stub + firing site in `do_turn`). Mod is pure Lua under `data/mods/blood_moon/` with state persisted via the standard `game.mod_storage[game.current_mod]` table.

**Tech Stack:** C++ (Cataclysm-BN engine, sol/luna Lua bindings), Lua 5.x mods, CMake/Make build.

**Spec:** `docs/superpowers/specs/2026-04-26-blood-moon-mod-design.md` — read this first.

---

## Notes for the implementer

- This codebase has no automated tests for Lua hooks. Verification is **build-clean + manual smoke-test in-game**.
- Use `gdebug.log_info("...")` in Lua to write to the game log for testing — visible via the in-game debug menu.
- For time-travel during testing, use the debug menu: `~ menu → Test Items / Player → Set Date / Time` (path may vary; the menu is searchable).
- Build command throughout: assume `make -j$(nproc) TILES=1 SOUND=1` (or your standard flags). On macOS, `make -j$(sysctl -n hw.ncpu) TILES=1 SOUND=1`. Adjust to match your local setup. CMake users: `cmake --build build -j` after configuring.
- Each task ends with a build to confirm no regression. Engine changes warrant a full game launch to confirm the hook fires.
- `docs/superpowers/specs/2026-04-26-blood-moon-mod-design.md` already references all the file:line locations you'll be editing.

---

### Task 1: Register `on_hour_passed` in the hook registry

**Files:**
- Modify: `src/catalua_hooks.cpp` (line 7-50, the `hook_names` array)

- [ ] **Step 1: Add the hook name to the array**

Open `src/catalua_hooks.cpp`. The `hook_names` array starts at line 7. Add `"on_hour_passed",` as a new entry. Place it right before `"on_mapgen_postprocess"` so related lifecycle hooks stay grouped.

Resulting snippet (showing the surrounding context):

```cpp
    "on_character_try_move",
    "on_hour_passed",
    "on_mapgen_postprocess",
```

- [ ] **Step 2: Build and verify clean compile**

Run:
```bash
make -j$(sysctl -n hw.ncpu) TILES=1 SOUND=1
```
Expected: compiles cleanly. The hook is referenced only inside its own array at this point, so a clean build means the change is syntactically valid.

- [ ] **Step 3: Commit**

```bash
git add src/catalua_hooks.cpp
git commit -m "feat(catalua): register on_hour_passed hook name"
```

---

### Task 2: Add the documentation/binding stub for `on_hour_passed`

**Files:**
- Modify: `src/catalua_bindings.cpp` (around line 572, near the `on_weather_updated` doc block)

- [ ] **Step 1: Add the doc stub**

Find the `on_weather_updated` block in `src/catalua_bindings.cpp` (around line 561-572). Right after `luna::set_fx( lib, "on_weather_updated", []( const sol::table & ) {} );`, insert:

```cpp
    DOC( "Called once at the top of every in-game hour, including during sleep/waiting." );
    DOC( "The hook receives a table with keys:" );
    DOC( "* `turn` (TimePoint): Current turn (top of the new hour)" );
    DOC( "* `hour` (int): Hour of day (0-23)" );
    DOC_PARAMS( "params" );
    luna::set_fx( lib, "on_hour_passed", []( const sol::table & ) {} );
```

- [ ] **Step 2: Build and verify**

Run:
```bash
make -j$(sysctl -n hw.ncpu) TILES=1 SOUND=1
```
Expected: compiles cleanly. If you see "unknown hook 'on_hour_passed'" or similar, check that Task 1 was completed and the array entry is spelled identically (`on_hour_passed`, no trailing whitespace).

- [ ] **Step 3: Commit**

```bash
git add src/catalua_bindings.cpp
git commit -m "feat(catalua): add on_hour_passed doc/binding stub"
```

---

### Task 3: Fire the hook from `game::do_turn()`

**Files:**
- Modify: `src/game.cpp` (after `calendar::turn += 1_turns;` at line 1850)

- [ ] **Step 1: Add the hook firing block**

Open `src/game.cpp`. Find `game::do_turn()` (starts at line 1832). At the end of the `else` branch that does `calendar::turn += 1_turns;` (around line 1851), immediately after that line, add:

```cpp
        if( calendar::once_every( 1_hours ) ) {
            cata::run_hooks( "on_hour_passed", []( sol::table & params ) {
                params["turn"] = calendar::turn;
                params["hour"] = hour_of_day<int>( calendar::turn );
            } );
        }
```

The surrounding context (after edit):
```cpp
    if( new_game ) {
        new_game = false;
    } else {
        gamemode->per_turn();
        calendar::turn += 1_turns;
        if( calendar::once_every( 1_hours ) ) {
            cata::run_hooks( "on_hour_passed", []( sol::table & params ) {
                params["turn"] = calendar::turn;
                params["hour"] = hour_of_day<int>( calendar::turn );
            } );
        }
    }
```

Note: `cata::run_hooks` and `hour_of_day` are both already used elsewhere in `game.cpp` (e.g. line 5317 and other run_hooks call sites; calendar helpers via `calendar.h`). The required headers are already included.

- [ ] **Step 2: Build and verify**

Run:
```bash
make -j$(sysctl -n hw.ncpu) TILES=1 SOUND=1
```
Expected: compiles cleanly.

- [ ] **Step 3: Commit**

```bash
git add src/game.cpp
git commit -m "feat(catalua): fire on_hour_passed hook from game::do_turn"
```

---

### Task 4: Create the `blood_moon` mod scaffold (modinfo + preload + logging-only main.lua)

**Files:**
- Create: `data/mods/blood_moon/modinfo.json`
- Create: `data/mods/blood_moon/preload.lua`
- Create: `data/mods/blood_moon/main.lua`

The first version of `main.lua` is a logging-only stub. This lets us verify the new hook fires before any game logic depends on it.

- [ ] **Step 1: Create `modinfo.json`**

Write to `data/mods/blood_moon/modinfo.json`:

```json
[
  {
    "type": "MOD_INFO",
    "id": "blood_moon",
    "name": "Blood Moon",
    "authors": [ "ChrisLR" ],
    "description": "Every 7 days, a Blood Moon rises and unleashes hordes of zombies upon the player from every direction. The first event spawns 25 zombies, with 5 more added each event, capped at 200.",
    "category": "content",
    "dependencies": [ "bn" ],
    "lua_api_version": 2,
    "version": "1",
    "obsolete": false
  }
]
```

- [ ] **Step 2: Create `preload.lua`**

Write to `data/mods/blood_moon/preload.lua`:

```lua
local mod = game.mod_runtime[game.current_mod]

game.add_hook("on_hour_passed", function(...) return mod.on_hour_passed(...) end)
```

- [ ] **Step 3: Create logging-only `main.lua`**

Write to `data/mods/blood_moon/main.lua`:

```lua
local mod = game.mod_runtime[game.current_mod]

mod.on_hour_passed = function(params)
    gdebug.log_info("[blood_moon] on_hour_passed fired: hour=", params.hour)
end
```

- [ ] **Step 4: Smoke test in-game**

1. Launch the game.
2. New world → enable the **Blood Moon** mod.
3. Start a new character.
4. Open debug menu (`~`), advance time by 1+ hours (Test Items / Player → Set Date / Time, or use `Wait`).
5. Open the message log / debug log and confirm `[blood_moon] on_hour_passed fired: hour=...` entries appear, one per hour boundary crossed.

If no log lines appear: re-check Task 1-3 (especially that the array entry, doc stub, and firing site all use the exact same name `on_hour_passed`).

- [ ] **Step 5: Commit**

```bash
git add data/mods/blood_moon/
git commit -m "feat(blood_moon): mod scaffold with on_hour_passed logging"
```

---

### Task 5: Implement scheduling logic + 6 PM popup

**Files:**
- Modify: `data/mods/blood_moon/main.lua`

- [ ] **Step 1: Replace `main.lua` with scheduling + popup**

Overwrite `data/mods/blood_moon/main.lua`:

```lua
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
```

- [ ] **Step 2: Smoke test the popup**

1. Launch the game. Load (or start) a save with the **Blood Moon** mod active.
2. Use the debug menu to advance the calendar to Day 7, hour 17:55 (or any time just before 18:00).
3. Use `Wait` (`|`) and pick "Wait until specific time" → 18:01, or just step time forward.
4. Expected: at the 18:00 boundary, the modal popup `"The Blood Moon Rises..."` appears in red. Press any key to dismiss.
5. Test pre-day-7: rewind to day 3, advance through 18:00 — popup must NOT appear.
6. Test off-hours: advance from 19:00 to 20:00 — popup must NOT appear.

- [ ] **Step 3: Commit**

```bash
git add data/mods/blood_moon/main.lua
git commit -m "feat(blood_moon): 6 PM warning popup on day-7 cycle"
```

---

### Task 6: Implement 10 PM horde spawn + log message

**Files:**
- Modify: `data/mods/blood_moon/main.lua`

- [ ] **Step 1: Add the spawn function and wire it into the hook handler**

In `data/mods/blood_moon/main.lua`, **above** the `mod.on_hour_passed = ...` definition, add:

```lua
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

    for _, offset in ipairs(OFFSETS) do
        local pos = Tripoint.new(
            player_omt.x + offset.x,
            player_omt.y + offset.y,
            player_omt.z)

        local mg = overmapbuffer.create_horde({
            type       = "GROUP_ZOMBIE",
            pos        = pos,
            population = per_horde,
            radius     = HORDE_RADIUS,
            horde      = true,
            behaviour  = "roam",
            target     = player_omt,
        })
        if mg then mg:set_interest(100) end
    end
end
```

Then replace the `mod.on_hour_passed` body so the `SPAWN_HOUR` branch fires the spawn:

```lua
mod.on_hour_passed = function(params)
    local hour = params.hour
    if hour ~= WARNING_HOUR and hour ~= SPAWN_HOUR then return end

    local event_n = current_event_n()
    if event_n == 0 then return end

    if hour == WARNING_HOUR then
        show_blood_moon_popup()
        return
    end

    -- hour == SPAWN_HOUR
    if event_n <= storage.last_event_fired then return end
    storage.last_event_fired = event_n
    gapi.add_msg(MsgType.bad,
        "The blood moon hangs heavy. You hear distant moans from every direction...")
    spawn_blood_moon_hordes(event_n)
end
```

- [ ] **Step 2: Smoke test the spawn**

1. Launch, load a save with the mod active.
2. Debug menu → set time to Day 7, hour 21:55. Step to 22:00.
3. Expected: red message in the log: *"The blood moon hangs heavy. You hear distant moans from every direction..."*.
4. Open the overmap (`m`). Look ~10 OMTs N, E, S, W of the player. You should see horde markers (red `Z` symbols on tiles, faint trails, depending on tileset).
5. Wait several turns (or rest a few minutes in-game). Hordes should drift toward the player tile.

Verification of population scaling:
- Repeat the test on a fresh world, set time to Day 14, hour 22:00. Population should be 30 → ceil(30/4) = 8 per direction (32 total).
- Day 21: 35 → 9 per direction (36 total).
- Day 252+ (event 36+): cap → 50 per direction (200 total).

- [ ] **Step 3: Save/load guard test**

1. Trigger a spawn at Day 7, 22:00 as above.
2. Save the game.
3. Reload the save (still at 22:00 or just after).
4. Step time forward through another hour.
5. Expected: NO additional spawn for the same `event_n`. The `storage.last_event_fired` guard prevents duplicates.

- [ ] **Step 4: Commit**

```bash
git add data/mods/blood_moon/main.lua
git commit -m "feat(blood_moon): 10 PM horde spawn from 4 directions, scaled by event"
```

---

### Task 7: End-to-end verification across edge cases

This task runs no code changes — just confirms the design's claimed edge-case handling holds. Use a fresh world per scenario when needed to keep tests independent.

- [ ] **Scenario 1: Sleep through 6 PM/10 PM**

Load a save on Day 6, hour 17:00. Lay down a bed, sleep. Expected:
- 18:00 popup appears, sleep is interrupted.
- Player can dismiss popup, choose to continue sleeping.
- 22:00 spawn fires; player wakes naturally to monster sounds (or stays asleep until something nearby is loud enough).

- [ ] **Scenario 2: Day-7 boundary respect**

Load a fresh save on Day 6, hour 17:00. Step through 18:00. Expected: NO popup.

- [ ] **Scenario 3: Off-hour quiet**

Step through any non-{18, 22} hour boundary. Expected: nothing happens (no popup, no spawn, no message).

- [ ] **Scenario 4: First-turn behavior**

On a brand-new game, `do_turn()` short-circuits the calendar increment (and therefore the hook fire) when `new_game == true`. So the very first `do_turn` does NOT fire the hook. The next `do_turn` increments `calendar::turn` and the hook fires only when an hour boundary is crossed. Expected on day 0: nothing happens (no popup, no spawn) until the first hour boundary is crossed, and even then the `event_n == 0` guard suppresses the mod's logic until day 7+.

- [ ] **Scenario 5: Mod added to existing save**

Take an existing world without `blood_moon`, save it, enable the mod, reload. Expected:
- `storage.last_event_fired` initializes to 0 via the `or 0` lazy default.
- Game continues normally; first event fires at the next 7-day boundary that crosses 18:00 / 22:00.

- [ ] **Scenario 6: Unmodded world is unaffected**

Start a new world without `blood_moon`. Confirm: `on_hour_passed` is registered as a hook (it's there in the C++ array), but no Lua mod subscribes, so nothing fires Lua callbacks. Game behaves exactly as before. (Sanity check that the engine change is no-op when no mods consume it.)

If any scenario fails, write down what you saw and decide between (a) fixing the mod logic, or (b) updating the spec to reflect actual behavior.

---

## Self-review (already performed by plan author)

**Spec coverage check:**
- Engine: hook in `hook_names` (Task 1), doc stub (Task 2), firing site (Task 3) — all spec sections covered.
- Mod scaffold: modinfo, preload, main.lua skeleton (Task 4) — covered.
- Schedule + popup: day arithmetic, hour gate, popup function, color, blocking — covered (Task 5).
- Spawn: 4-direction offsets, population formula, capped, monster group, behaviour, interest — covered (Task 6).
- Persistence via mod_storage with `last_event_fired` guard — covered (Tasks 5/6).
- Edge cases (sleep, save/load, save-scum, day < 7, mod added late, unmodded) — covered as test scenarios in Task 7.

**Placeholder scan:** no TBD/TODO/"similar to" references. Each step has the actual code or commands. Confirmed.

**Type/name consistency:**
- `on_hour_passed` (Tasks 1, 2, 3, 4, preload.lua) — same exact spelling.
- `params.turn` / `params.hour` keys defined in Task 3, consumed in Tasks 4-6.
- `storage.last_event_fired` introduced and used consistently in Tasks 5/6.
- Constants: `POPULATION_BASE` / `POPULATION_PER_EVENT` / `POPULATION_MAX` / `HORDE_DISTANCE_OMT` / `HORDE_DIRECTIONS` / `HORDE_RADIUS` defined in Task 5, all used by Task 6.
