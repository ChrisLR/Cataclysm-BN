gdebug.log_info("Civilians: Initializing mod...")

local mod = game.mod_runtime[game.current_mod]
local options = require("options")
local common = require("civ_common")
local pulping = require("pulping")
local spawning = require("spawning")
local interactions = require("interactions")

function mod.on_every_10_turns_civilian_update()
  pulping.process_pulping()
end

gdebug.log_info("Civilians: Ready")
