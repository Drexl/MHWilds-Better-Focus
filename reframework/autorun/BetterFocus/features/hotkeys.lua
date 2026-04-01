local M = {}

local VK_ESCAPE = 27
local IGNORED_CAPTURE_KEYS = {
    [1] = true,  -- LMB
    [2] = true,  -- RMB
    [27] = true, -- ESC is reserved for cancel
}

local KEY_NAMES = {
    [8] = "BACKSPACE",
    [9] = "TAB",
    [13] = "ENTER",
    [16] = "SHIFT",
    [17] = "CTRL",
    [18] = "ALT",
    [19] = "PAUSE",
    [20] = "CAPSLOCK",
    [32] = "SPACE",
    [33] = "PAGEUP",
    [34] = "PAGEDOWN",
    [35] = "END",
    [36] = "HOME",
    [37] = "LEFT",
    [38] = "UP",
    [39] = "RIGHT",
    [40] = "DOWN",
    [44] = "PRINTSCREEN",
    [45] = "INSERT",
    [46] = "DELETE",
    [91] = "LWIN",
    [92] = "RWIN",
    [93] = "MENU",
    [96] = "NUMPAD0",
    [97] = "NUMPAD1",
    [98] = "NUMPAD2",
    [99] = "NUMPAD3",
    [100] = "NUMPAD4",
    [101] = "NUMPAD5",
    [102] = "NUMPAD6",
    [103] = "NUMPAD7",
    [104] = "NUMPAD8",
    [105] = "NUMPAD9",
    [106] = "NUMPAD_MULTIPLY",
    [107] = "NUMPAD_ADD",
    [108] = "NUMPAD_SEPARATOR",
    [109] = "NUMPAD_SUBTRACT",
    [110] = "NUMPAD_DECIMAL",
    [111] = "NUMPAD_DIVIDE",
    [144] = "NUMLOCK",
    [145] = "SCROLLLOCK",
    [186] = "SEMICOLON",
    [187] = "EQUALS",
    [188] = "COMMA",
    [189] = "MINUS",
    [190] = "PERIOD",
    [191] = "SLASH",
    [192] = "GRAVE",
    [219] = "LBRACKET",
    [220] = "BACKSLASH",
    [221] = "RBRACKET",
    [222] = "APOSTROPHE",
}

for code = string.byte("0"), string.byte("9") do
    KEY_NAMES[code] = string.char(code)
end

for code = string.byte("A"), string.byte("Z") do
    KEY_NAMES[code] = string.char(code)
end

for offset = 0, 23 do
    KEY_NAMES[112 + offset] = string.format("F%d", offset + 1)
end

local function get_key_name(code)
    return KEY_NAMES[code] or string.format("VK_%d", code)
end

local function build_weapon_action_type_names(action_name)
    local type_names = {}
    for type_id = 0, 13 do
        type_names[#type_names + 1] = string.format("app.Wp%02dAction.%s", type_id, action_name)
    end
    return type_names
end

function M.create(app)
    local self = {}

    local weapon_aim_idle_types = build_weapon_action_type_names("cAimIdle")
    local weapon_aim_walk_types = build_weapon_action_type_names("cAimWalk")
    local dash_retry_interval = 0.10
    local dash_sheathe_retry = {
        active = false,
        moving = false,
        nextAttemptAt = 0,
    }

    local function stop_dash_sheathe_retry()
        dash_sheathe_retry.active = false
        dash_sheathe_retry.moving = false
        dash_sheathe_retry.nextAttemptAt = 0
    end

    local function schedule_dash_if_enabled()
        if not app.config.misc.autoDash then
            return
        end

        app.scheduler.cancel(app.state, "delayed_dash")
        app.scheduler.schedule(app.state, 1.0, function()
            app.focus.start_dash()
        end, "delayed_dash")
    end

    local function request_dash_sheathe(moving, is_retry)
        if not app.config.misc.sheatheOnDash then
            stop_dash_sheathe_retry()
            return
        end

        if not is_retry and (os.clock() - app.state.hotkeys.lastActionAt) < 0.20 then
            return
        end

        local now = os.clock()
        if not is_retry then
            app.state.hotkeys.lastActionAt = now
        end

        app.state.status.lastSheathingAt = now
        app.state.status.isSheathing = true

        if app.config.misc.focusOffOnSheathe then
            app.focus.disable()
        end

        app.focus.sheathe_weapon(moving)
        schedule_dash_if_enabled()
        dash_sheathe_retry.active = true
        dash_sheathe_retry.moving = moving
        dash_sheathe_retry.nextAttemptAt = now + dash_retry_interval
    end

    -- Aim-state hooks should still fire the initial sheathe request
    -- immediately. The retry loop only handles the "keep trying while held"
    -- behavior after that first request.
    function self.handle_dash_hotkey(moving)
        if app.game.get_dash_input_state().any then
            dash_sheathe_retry.moving = moving
            if not dash_sheathe_retry.active then
                request_dash_sheathe(moving, false)
            end
        end
    end

    local function try_capture_custom_key(binding_field, config_key_field, config_name_field)
        if not app.state.binding[binding_field] then
            return
        end

        if reframework:is_key_down(VK_ESCAPE) then
            app.state.binding[binding_field] = false
            return
        end

        for code = 8, 255 do
            if not IGNORED_CAPTURE_KEYS[code] and reframework:is_key_down(code) then
                app.config.hotkeys[config_key_field] = code
                app.config.hotkeys[config_name_field] = get_key_name(code)
                app.state.binding[binding_field] = false
                app.save_config()
                break
            end
        end
    end

    function self.init()
        app.hooks.hook("app.PlayerCommonAction.cSquatIdleTurn", { "doEnter()", "doEnter" }, function()
            app.state.status.lastCrouchTurnAt = os.clock()
            app.state.status.isCrouchTurn = true
        end)

        app.hooks.hook_owner("app.WpCommonActions.cAimIdle", { "doUpdate()", "doUpdate" }, function()
            self.handle_dash_hotkey(false)
        end)

        app.hooks.hook_owner("app.WpCommonActions.cAimWalk", { "doUpdate()", "doUpdate" }, function()
            self.handle_dash_hotkey(false)
        end)

        for _, type_name in ipairs(weapon_aim_idle_types) do
            app.hooks.hook_owner(type_name, { "doUpdate()", "doUpdate" }, function()
                self.handle_dash_hotkey(true)
            end)
        end

        for _, type_name in ipairs(weapon_aim_walk_types) do
            app.hooks.hook_owner(type_name, { "doUpdate()", "doUpdate" }, function()
                self.handle_dash_hotkey(true)
            end)
        end
    end

    function self.update()
        local is_weapon_drawn = app.game.is_weapon_drawn()
        local dash_input_state = app.game.get_dash_input_state()
        if app.state.status.wasWeaponDrawn == nil then
            app.state.status.wasWeaponDrawn = is_weapon_drawn
        else
            if app.state.status.wasWeaponDrawn and not is_weapon_drawn and app.config.misc.focusOffOnSheathe then
                app.focus.disable()
            end
            app.state.status.wasWeaponDrawn = is_weapon_drawn
        end

        if app.config.misc.sheatheOnDash and dash_input_state.any and is_weapon_drawn then
            -- If the player starts holding dash during a long recovery state
            -- that does not pass through the usual aim hooks, start the retry
            -- loop as long as Better Focus still considers this an active
            -- managed focus session.
            if not dash_sheathe_retry.active and app.state.status.managedFocusSession then
                request_dash_sheathe(dash_sheathe_retry.moving, false)
            -- Keep retrying on a timer while dash is still held and the weapon
            -- has not actually reached a sheathed state yet.
            elseif dash_sheathe_retry.active and os.clock() >= dash_sheathe_retry.nextAttemptAt then
                request_dash_sheathe(dash_sheathe_retry.moving, true)
            end
        elseif dash_sheathe_retry.active then
            stop_dash_sheathe_retry()
        end

        if app.state.status.isCrouchTurn and (os.clock() - app.state.status.lastCrouchTurnAt) > 1 then
            app.state.status.isCrouchTurn = false
        end

        if app.state.status.isSheathing and (os.clock() - app.state.status.lastSheathingAt) > 1 then
            app.state.status.isSheathing = false
        end

        try_capture_custom_key("dashCustomKey", "dashCustomKey", "dashCustomKeyName")
        try_capture_custom_key("seikretCustomKey", "seikretCustomKey", "seikretCustomKeyName")
    end

    return self
end

return M
