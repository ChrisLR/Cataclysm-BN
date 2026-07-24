local mod = game.mod_runtime[game.current_mod]

-- Register mapgen postprocess hook (responsible for randomly spawning civilians)
game.add_hook("on_mapgen_postprocess", function(params)
  if mod.on_mapgen_postprocess then return mod.on_mapgen_postprocess(params) end
end)

--game.monster_attitude_functions["civilian_attitude"] = function(...)
--  return mod.civilian_attitude(...)
--end

game.add_hook("on_creature_attacked_by_character", function(...)
  if mod.on_creature_attacked_by_character then return mod.on_creature_attacked_by_character(...) end
end)

-- Register hook every 10 turns (10 seconds) (responsible for checking and executing civilian corpse pulping)
gapi.add_on_every_x_hook(TimeDuration.from_turns(10), function(params)
  if mod and mod.on_every_10_turns_civilian_update then mod.on_every_10_turns_civilian_update() end
end)

gdebug.log_info("Civilians: Preload complete. Hooks registered.")
