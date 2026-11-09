local mod = game.mod_runtime[game.current_mod]
local common = require("civ_common")

-- Register mapgen postprocess hook (responsible for randomly spawning civilians)
game.add_hook("on_mapgen_postprocess", function(params)
  if mod.on_mapgen_postprocess then return mod.on_mapgen_postprocess(params) end
end)

-- Register hook every 10 turns (10 seconds) (responsible for checking and executing civilian corpse pulping)
gapi.add_on_every_x_hook(TimeDuration.from_turns(10), function(params)
  if mod and mod.on_every_10_turns_civilian_update then mod.on_every_10_turns_civilian_update() end
end)

gapi.register_action_menu_entry({
  id = "civilians_configure_options",
  name = "Configure Civilians",
  category = "misc",
  fn = function() mod.configure_options() end,
})

for type_id, civ_data in pairs(common.CIVILIANS) do
  if civ_data.recruitable then
    gdebug.log_info(string.format("Civilians: Registering %s.", type_id))
    game.monster_functions[type_id] = {
        get_examine_menu_entries = function(...) return mod.get_examine_menu_entries_civ(...) end,
        on_examine_menu_entry = function(...) return mod.on_examine_menu_entry_civ(...) end,
    }
	end
end

gdebug.log_info("Civilians: Preload complete. Hooks registered.")
