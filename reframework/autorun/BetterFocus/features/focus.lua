local M = {}

local function get_focus_toggles(controller)
    if not controller then
        return nil
    end
    return controller
end

function M.create(app)
    local self = {}
    local window_refocus_restore_duration = 0.60
    local window_refocus_restore_interval = 0.10
    local logged_window_focus_unavailable = false

    local function mark_managed_focus_session()
        app.state.status.managedFocusSession = true
    end

    local function should_block_focus_activation()
        return app.state.status.suppressFocusUntilWeaponDrawn == true
    end

    local function should_restore_focus_on_window_refocus()
        return app.state.status.restoreFocusOnWindowRefocus
            and app.game.is_weapon_enabled()
            and not should_block_focus_activation()
    end

    local function is_refocus_restore_eligible()
        return app.game.is_weapon_enabled()
            and not should_block_focus_activation()
            and app.state.status.managedFocusSession
            and app.game.is_focus_active()
    end

    local function build_window_refocus_state_detail()
        return string.format(
            "drawn=%s targeting=%s focus=%s managed=%s suppress=%s restore=%s until=%.2f",
            tostring(app.game.is_weapon_drawn()),
            tostring(app.game.is_camera_targeting()),
            tostring(app.game.is_focus_active()),
            tostring(app.state.status.managedFocusSession),
            tostring(app.state.status.suppressFocusUntilWeaponDrawn),
            tostring(app.state.status.restoreFocusOnWindowRefocus),
            tonumber(app.state.status.restoreFocusOnWindowRefocusUntil) or 0
        )
    end

    local function clear_window_refocus_restore(reason)
        if reason ~= nil then
            app.dev.trace_window_refocus(
                "clear",
                string.format("reason=%s %s", tostring(reason), build_window_refocus_state_detail())
            )
        end

        app.state.status.restoreFocusOnWindowRefocus = false
        app.state.status.restoreFocusOnWindowRefocusUntil = 0
        app.state.status.lastWindowRefocusRestoreAt = 0
        app.state.status.refocusRestoreEligible = false
    end

    function self.on_weapon_sheathed(reason)
        app.state.status.longSwordIaiActive = false
        app.state.status.longSwordIaiUntil = 0
        app.state.status.suppressFocusUntilWeaponDrawn = true
        app.state.pending.weaponDrawStage = 0
        clear_window_refocus_restore()
        self.disable()
    end

    function self.on_weapon_drawn(reason)
        app.state.status.longSwordIaiActive = false
        app.state.status.longSwordIaiUntil = 0
        app.state.status.suppressFocusUntilWeaponDrawn = false
        clear_window_refocus_restore()
    end

    -- When Better Focus turns focus on itself, later hooks can avoid trying to
    -- "re-open" the same focus session again.
    function self.should_skip_managed_retoggle()
        return app.state.status.managedFocusSession
    end

    function self.enable_pc(force)
        local controller = app.game.get_player_controller()
        if not controller then
            return
        end

        if should_block_focus_activation() then
            return
        end

        if not force and self.should_skip_managed_retoggle() and app.game.is_camera_targeting() then
            if app.config.misc.disableTargetCameraSnap and app.state.camera.blockSnapBypassUntil <= os.clock() then
                app.camera.begin_suppress_window()
            end
            return
        end

        get_focus_toggles(controller)._ToggleAimPc = true
        mark_managed_focus_session()

        if app.config.misc.disableTargetCameraSnap and app.state.camera.blockSnapBypassUntil <= os.clock() then
            app.camera.begin_suppress_window()
        end
    end

    function self.enable_pad(force)
        local controller = app.game.get_player_controller()
        if not controller then
            return
        end

        if should_block_focus_activation() then
            return
        end

        if not force and self.should_skip_managed_retoggle() and app.game.is_camera_targeting() then
            if app.config.misc.disableTargetCameraSnap and app.state.camera.blockSnapBypassUntil <= os.clock() then
                app.camera.begin_suppress_window()
            end
            return
        end

        get_focus_toggles(controller)._ToggleAimPad = true
        mark_managed_focus_session()

        if app.config.misc.disableTargetCameraSnap and app.state.camera.blockSnapBypassUntil <= os.clock() then
            app.camera.begin_suppress_window()
        end
    end

    function self.disable()
        local controller = app.game.get_player_controller()
        app.state.camera.suppressUntil = 0
        app.state.status.managedFocusSession = false
        if not controller then
            return
        end

        controller._ToggleAimShooting = false
        controller._ToggleAimPc = false
        controller._ToggleAimPad = false
    end

    function self.activate(force)
        self.enable_pad(force)
        self.enable_pc(force)
    end

    -- Draw detection queues focus instead of enabling it immediately. Doing it
    -- one frame later is more reliable than fighting the same frame as the
    -- game's own draw transition.
    function self.queue_weapon_draw()
        if not app.game.is_weapon_enabled() then
            return
        end

        if app.state.status.isCrouchTurn or app.seikret.should_suppress_disabled_dismount() then
            return
        end

        if (os.clock() - app.state.pending.lastWeaponDrawRequestAt) < 0.10 then
            return
        end

        app.state.pending.lastWeaponDrawRequestAt = os.clock()
        app.state.pending.weaponDrawStage = 1
    end

    -- Native focus-entry hooks call this right before focus is about to open.
    -- That gives the camera module a chance to freeze the sight state and
    -- suppress target-camera snap for this focus session.
    function self.prepare_native_entry(reason)
        if should_block_focus_activation() then
            return
        end

        if not app.config.misc.disableTargetCameraSnap then
            return
        end

        app.state.status.managedFocusSession = true
        app.camera.capture_frozen_sight()
        app.camera.begin_suppress_window()
    end

    function self.sheathe_weapon(moving)
        local action_id = app.game.get_action_id(1, moving and 11 or 10)
        local player_character = app.game.get_player_character()
        if not player_character then
            return
        end

        player_character:call("changeActionRequest(app.AppActionDef.LAYER, ace.ACTION_ID, System.Boolean)", 0, action_id, false)
    end

    function self.start_dash()
        local controller = app.game.get_player_controller()
        if not controller then
            return
        end

        local ok_toggle = pcall(function()
            controller._ToggleDash = true
        end)
        if ok_toggle then
            return
        end

        pcall(function()
            controller:call("requestDash()")
        end)
    end

    -- Pending actions run here instead of inside hooks so multiple hooks can
    -- request the same behavior without stepping on each other.
    function self.update()
        local is_game_window_focused = app.game.is_game_window_focused()
        if is_game_window_focused == nil then
            if not logged_window_focus_unavailable then
                logged_window_focus_unavailable = true
                app.dev.trace_window_refocus("window_detector_unavailable", "reason=noForegroundWindowCheck")
            end
        else
            if is_game_window_focused then
                app.state.status.refocusRestoreEligible = is_refocus_restore_eligible()
            end

            if app.state.status.wasGameWindowFocused == nil then
                app.state.status.wasGameWindowFocused = is_game_window_focused
            elseif app.state.status.wasGameWindowFocused and not is_game_window_focused then
                app.state.status.restoreFocusOnWindowRefocus = app.state.status.refocusRestoreEligible
                app.state.status.restoreFocusOnWindowRefocusUntil = 0
                app.state.status.lastWindowRefocusRestoreAt = 0
                app.dev.trace_window_refocus(
                    "window_lost",
                    build_window_refocus_state_detail()
                )
            elseif not app.state.status.wasGameWindowFocused and is_game_window_focused then
                app.dev.trace_window_refocus(
                    "window_gained",
                    build_window_refocus_state_detail()
                )
                if should_restore_focus_on_window_refocus() then
                    app.state.status.restoreFocusOnWindowRefocusUntil = os.clock() + window_refocus_restore_duration
                    app.state.status.lastWindowRefocusRestoreAt = 0
                    app.dev.trace_window_refocus(
                        "arm_restore",
                        build_window_refocus_state_detail()
                    )
                    app.dev.trace_window_refocus(
                        "restore_attempt",
                        "reason=windowGained " .. build_window_refocus_state_detail()
                    )
                    self.activate(true)
                    app.state.status.lastWindowRefocusRestoreAt = os.clock()
                else
                    clear_window_refocus_restore("invalidOnRegain")
                end
            end

            app.state.status.wasGameWindowFocused = is_game_window_focused
        end

        if app.state.status.restoreFocusOnWindowRefocus and is_game_window_focused == true then
            if not should_restore_focus_on_window_refocus()
                or app.state.status.restoreFocusOnWindowRefocusUntil <= os.clock() then
                local reason = not should_restore_focus_on_window_refocus() and "invalidDuringRetry" or "timedOut"
                clear_window_refocus_restore(reason)
            elseif not app.game.is_focus_active()
                and (os.clock() - app.state.status.lastWindowRefocusRestoreAt) >= window_refocus_restore_interval then
                app.state.status.lastWindowRefocusRestoreAt = os.clock()
                app.dev.trace_window_refocus(
                    "restore_attempt",
                    build_window_refocus_state_detail()
                )
                self.activate(true)
            elseif app.game.is_focus_active() then
                clear_window_refocus_restore("focusRestored")
            end
        end

        if app.state.pending.blockSnapStage == 1 then
            self.disable()
            app.state.pending.blockSnapStage = 2
        elseif app.state.pending.blockSnapStage == 2 then
            self.activate(true)
            app.state.pending.blockSnapStage = 0
        end

        if app.state.pending.weaponDrawStage == 1 then
            app.state.pending.weaponDrawStage = 2
        elseif app.state.pending.weaponDrawStage == 2 then
            self.on_weapon_drawn("pending_weapon_draw")
            self.activate(true)
            app.state.pending.weaponDrawStage = 0
        end
    end

    return self
end

return M
