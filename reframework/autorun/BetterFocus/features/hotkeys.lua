local Game = require("BetterFocus.core.game")
local Util = require("BetterFocus.core.util")

local build_weapon_action_type_names = Util.build_weapon_action_type_names
local build_weapon_subaction_type_names = Util.build_weapon_subaction_type_names

local M = {}

function M.create(app)
    local self = {}
    local move_input_threshold = 0.10
    local shortcut_focus_restore_delay = 0.05
    local shortcut_focus_restore_duration = 0.75
    local shortcut_focus_recent_window = 0.25

    local weapon_aim_idle_types = build_weapon_action_type_names("cAimIdle")
    local weapon_aim_walk_types = build_weapon_action_type_names("cAimWalk")
    local weapon_aim_walk_stop_types = build_weapon_action_type_names("cAimWalkStop")
    local weapon_aim_end_types = build_weapon_action_type_names("cAimEnd")
    local weapon_aim_end_subaction_types = build_weapon_subaction_type_names("cAimEnd")
    local extra_aim_walk_stop_types = {
        "app.WpCommonActions.cAimWalkStop",
        "app.WpGunActions.cAimWalkStop",
        "app.Wp04Action.cChargeAimWalkStop",
        "app.Wp08Action.cSwordAimWalkStop",
        "app.Wp09Action.cAxeAimWalkStop",
    }
    local extra_aim_end_types = {
        "app.WpCommonActions.cAimEnd",
        "app.WpCommonSubAction.cAimEnd",
        "app.Wp08SubAction.cSwordAimEnd",
        "app.Wp09SubAction.cAxeAimEnd",
    }
    local dash_retry_interval = 0.10
    local dash_sheathe_retry = {
        active = false,
        nextAttemptAt = 0,
    }

    local function clear_shortcut_focus_restore()
        app.state.status.restoreFocusAfterShortcut = false
        app.state.status.restoreFocusAfterShortcutAt = 0
        app.state.status.restoreFocusAfterShortcutUntil = 0
    end

    local function should_restore_shortcut_focus()
        return app.state.status.restoreFocusAfterShortcut
            and app.game.is_weapon_enabled()
            and not app.state.status.suppressFocusUntilWeaponDrawn
    end

    local function had_recent_focus_before_shortcut()
        return (os.clock() - (app.state.status.lastObservedFocusAt or 0)) <= shortcut_focus_recent_window
    end

    local function stop_dash_sheathe_retry()
        dash_sheathe_retry.active = false
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

    local function request_dash_sheathe(is_retry)
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
        local move_input_magnitude = app.game.get_move_input_magnitude()
        local effective_moving = app.state.status.isAimMoving == true
        if type(move_input_magnitude) == "number" then
            effective_moving = move_input_magnitude >= move_input_threshold
        end

        if app.config.misc.focusOffOnSheathe then
            app.focus.disable()
        end

        app.focus.sheathe_weapon(effective_moving)
        schedule_dash_if_enabled()
        dash_sheathe_retry.active = true
        dash_sheathe_retry.nextAttemptAt = now + dash_retry_interval
    end

    -- Aim-state hooks should still fire the initial sheathe request
    -- immediately. The retry loop only handles the "keep trying while held"
    -- behavior after that first request.
    function self.handle_dash_hotkey(moving)
        app.state.status.isAimMoving = moving

        if app.game.get_dash_input_state().any then
            if not dash_sheathe_retry.active then
                request_dash_sheathe(false)
            end
        end
    end

    function self.init()
        app.hooks.hook(
            "app.GUI020600",
            {
                "requestOpenPCShortcut(app.GUI020600.TYPE, System.Int32, System.Int32, app.GUI020600.MODE, via.gui.Rect)",
                "requestOpenPCShortcut",
            },
            function()
                if app.game.is_weapon_enabled()
                    and not app.state.status.suppressFocusUntilWeaponDrawn
                    and had_recent_focus_before_shortcut() then
                    app.state.status.restoreFocusAfterShortcut = true
                    app.state.status.restoreFocusAfterShortcutAt = -1
                    app.state.status.restoreFocusAfterShortcutUntil = 0
                else
                    clear_shortcut_focus_restore()
                end
            end
        )

        app.hooks.hook(
            "app.GUI020600",
            { "onHudClose()", "onHudClose" },
            function()
                if not app.state.status.restoreFocusAfterShortcut then
                    return
                end

                app.state.status.restoreFocusAfterShortcutAt = os.clock() + shortcut_focus_restore_delay
                app.state.status.restoreFocusAfterShortcutUntil = os.clock() + shortcut_focus_restore_duration
            end
        )

        app.hooks.hook("app.PlayerCommonAction.cSquatIdleTurn", { "doEnter()", "doEnter" }, function()
            app.state.status.lastCrouchTurnAt = os.clock()
            app.state.status.isCrouchTurn = true
        end)

        app.hooks.hook_owner("app.WpCommonActions.cAimIdle", { "doUpdate()", "doUpdate" }, function()
            self.handle_dash_hotkey(false)
        end)

        app.hooks.hook_owner("app.WpCommonActions.cAimWalk", { "doUpdate()", "doUpdate" }, function()
            self.handle_dash_hotkey(true)
        end)

        for _, type_name in ipairs(weapon_aim_idle_types) do
            app.hooks.hook_owner(type_name, { "doUpdate()", "doUpdate" }, function()
                self.handle_dash_hotkey(false)
            end)
        end

        for _, type_name in ipairs(weapon_aim_walk_types) do
            app.hooks.hook_owner(type_name, { "doUpdate()", "doUpdate" }, function()
                self.handle_dash_hotkey(true)
            end)
        end

        for _, type_name in ipairs(weapon_aim_walk_stop_types) do
            app.hooks.hook_owner(type_name, { "doUpdate()", "doUpdate" }, function()
                self.handle_dash_hotkey(false)
            end)
        end

        for _, type_name in ipairs(extra_aim_walk_stop_types) do
            app.hooks.hook_owner(type_name, { "doUpdate()", "doUpdate" }, function()
                self.handle_dash_hotkey(false)
            end)
        end

        -- Some weapons pass through a short aim-ending settle animation after
        -- movement input is released. Treat those end states as idle-sheathe
        -- candidates so dash-sheathe does not wait for the full pose reset.
        for _, type_name in ipairs(weapon_aim_end_types) do
            app.hooks.hook_owner(type_name, { "doUpdate()", "doUpdate" }, function()
                self.handle_dash_hotkey(false)
            end)
        end

        for _, type_name in ipairs(weapon_aim_end_subaction_types) do
            app.hooks.hook_owner(type_name, { "doUpdate()", "doUpdate" }, function()
                self.handle_dash_hotkey(false)
            end)
        end

        for _, type_name in ipairs(extra_aim_end_types) do
            app.hooks.hook_owner(type_name, { "doUpdate()", "doUpdate" }, function()
                self.handle_dash_hotkey(false)
            end)
        end
    end

    function self.update()
        local is_focus_active = app.game.is_focus_active()
        local is_targeting = app.game.is_camera_targeting()
        local overwrite_weapon_on_off_state = app.game.get_overwrite_weapon_on_off_state()
        local dash_input_state = app.game.get_dash_input_state()

        if is_focus_active or is_targeting then
            app.state.status.lastObservedFocusAt = os.clock()
        end

        if app.state.status.restoreFocusAfterShortcut then
            if app.state.status.restoreFocusAfterShortcutAt < 0 then
                -- Shortcut HUD is still open; wait for onHudClose to convert
                -- the armed state into an actual restore attempt.
            elseif not should_restore_shortcut_focus()
                or app.state.status.restoreFocusAfterShortcutUntil <= os.clock() then
                clear_shortcut_focus_restore()
            elseif app.state.status.restoreFocusAfterShortcutAt > 0
                and os.clock() >= app.state.status.restoreFocusAfterShortcutAt then
                if app.game.is_focus_active() then
                    clear_shortcut_focus_restore()
                else
                    app.focus.activate(true)
                    app.state.status.restoreFocusAfterShortcutAt = os.clock() + shortcut_focus_restore_delay
                end
            end
        end

        if app.state.status.wasOverwriteWeaponOnOffState == nil then
            app.state.status.wasOverwriteWeaponOnOffState = overwrite_weapon_on_off_state
        else
            local previous_state = app.state.status.wasOverwriteWeaponOnOffState
            -- This native state flips to OFF for both manual sheathes and the
            -- special sheath-ending moves that did not reliably update the old
            -- get_IsDraw() in time. Kept alongside the engine-level
            -- onWeaponOnStateChanged hook as a redundant signal for the
            -- transition-edge cases the engine hook may fire too late on.
            local OFF = Game.MOTION_SEQUENCE_ON_OFF.OFF
            if previous_state ~= OFF
                and overwrite_weapon_on_off_state == OFF
                and app.config.misc.focusOffOnSheathe
                and app.state.status.ignoreSheatheUntil <= os.clock() then
                app.focus.on_weapon_sheathed("overwrite_weapon_on_off_state")
            end
            app.state.status.wasOverwriteWeaponOnOffState = overwrite_weapon_on_off_state
        end

        -- The retry flag prevents duplicate requests from the aim-state
        -- hooks. Clear it once the weapon sheathes or dash is released so
        -- the hooks can initiate a new request next time.
        if dash_sheathe_retry.active then
            if not dash_input_state.any or not app.game.is_weapon_drawn() then
                stop_dash_sheathe_retry()
            end
        end

        if app.state.status.isCrouchTurn and (os.clock() - app.state.status.lastCrouchTurnAt) > 1 then
            app.state.status.isCrouchTurn = false
        end
    end

    return self
end

return M
