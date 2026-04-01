local M = {}

-- Weapon settings use clear names instead of numeric IDs so the config file
-- is readable even if someone opens it without the UI.
M.weapon_order = {
    { key = "greatSword", label = "Great Sword", type_id = 0 },
    { key = "swordAndShield", label = "Sword & Shield", type_id = 1 },
    { key = "dualBlades", label = "Dual Blades", type_id = 2 },
    { key = "longSword", label = "Long Sword", type_id = 3 },
    { key = "hammer", label = "Hammer", type_id = 4 },
    { key = "huntingHorn", label = "Hunting Horn", type_id = 5 },
    { key = "lance", label = "Lance", type_id = 6 },
    { key = "gunlance", label = "Gunlance", type_id = 7 },
    { key = "switchAxe", label = "Switch Axe", type_id = 8 },
    { key = "chargeBlade", label = "Charge Blade", type_id = 9 },
    { key = "insectGlaive", label = "Insect Glaive", type_id = 10 },
    { key = "bow", label = "Bow", type_id = 11 },
    { key = "heavyBowgun", label = "Heavy Bowgun", type_id = 12 },
    { key = "lightBowgun", label = "Light Bowgun", type_id = 13 },
}

M.weapon_keys_by_type = {}
for _, weapon in ipairs(M.weapon_order) do
    M.weapon_keys_by_type[weapon.type_id] = weapon.key
end

local function merge_known(destination, source)
    for key, value in pairs(destination) do
        if type(value) == "table" and type(source[key]) == "table" then
            merge_known(value, source[key])
        elseif source[key] ~= nil then
            destination[key] = source[key]
        end
    end
end

function M.defaults()
    return {
        weapons = {
            greatSword = true,
            swordAndShield = true,
            dualBlades = true,
            longSword = true,
            hammer = true,
            huntingHorn = true,
            lance = true,
            gunlance = true,
            switchAxe = true,
            chargeBlade = true,
            insectGlaive = true,
            bow = false,
            heavyBowgun = false,
            lightBowgun = false,
        },
        seikret = {
            mountBehavior = "default",
            allowUnarmedFocusCall = true,
        },
        misc = {
            focusOffOnSheathe = true,
            sheatheOnDash = true,
            autoDash = true,
            disableTargetCameraSnap = false,
            snapToMonsterOnBlock = false,
            tooltipHelpers = true,
        },
        hotkeys = {
            controllerSupport = false,
            dashKeySource = "system",
            dashCustomKey = 16,
            dashCustomKeyName = "SHIFT",
            seikretKeySource = "system",
            seikretCustomKey = 9,
            seikretCustomKeyName = "TAB",
        },
    }
end

-- Load only known keys from disk so removed or misspelled settings do not
-- silently change runtime behavior.
function M.load()
    local config = M.defaults()
    local saved = json.load_file("BetterFocus_config.json")
    if type(saved) == "table" then
        merge_known(config, saved)

        if type(saved.hotkeys) == "table" then
            if saved.hotkeys.dashKey ~= nil then
                config.hotkeys.dashCustomKey = saved.hotkeys.dashKey
            end
            if type(saved.hotkeys.dashKeyName) == "string" then
                config.hotkeys.dashCustomKeyName = saved.hotkeys.dashKeyName
            end
            if saved.hotkeys.enableMouseKeyboard ~= nil then
                config.misc.sheatheOnDash = saved.hotkeys.enableMouseKeyboard == true
            end
            if saved.hotkeys.forceDash ~= nil then
                config.misc.autoDash = saved.hotkeys.forceDash == true
            end
        end
    else
        json.dump_file("BetterFocus_config.json", config)
    end
    return config
end

function M.save(config)
    json.dump_file("BetterFocus_config.json", config)
end

return M
