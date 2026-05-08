local mod = game.mod_runtime[game.current_mod]

game.add_hook("on_game_load",   function(...) return mod.on_game_load(...) end)
game.add_hook("on_hour_passed", function(...) return mod.on_hour_passed(...) end)
