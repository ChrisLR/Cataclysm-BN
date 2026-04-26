local mod = game.mod_runtime[game.current_mod]

mod.on_hour_passed = function(params)
    gdebug.log_info("[blood_moon] on_hour_passed fired: hour=", params.hour)
end
