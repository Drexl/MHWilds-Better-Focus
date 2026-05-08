local Config = require("BetterFocus.core.config")

local M = {}

-- Range derived from Config.weapon_order so a future-game-update introducing a
-- 15th weapon type only requires editing config.weapon_order, not every loop.
local last_type_id = 0
for _, weapon in ipairs(Config.weapon_order) do
    if weapon.type_id > last_type_id then
        last_type_id = weapon.type_id
    end
end
M.WEAPON_LAST_TYPE_ID = last_type_id

-- Build the full set of per-weapon action type names for a given action name,
-- e.g. "cAimIdle" -> {"app.Wp00Action.cAimIdle", ..., "app.Wp13Action.cAimIdle"}.
function M.build_weapon_action_type_names(action_name)
    local type_names = {}
    for type_id = 0, last_type_id do
        type_names[#type_names + 1] = string.format("app.Wp%02dAction.%s", type_id, action_name)
    end
    return type_names
end

function M.build_weapon_subaction_type_names(action_name)
    local type_names = {}
    for type_id = 0, last_type_id do
        type_names[#type_names + 1] = string.format("app.Wp%02dSubAction.%s", type_id, action_name)
    end
    return type_names
end

return M
