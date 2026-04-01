local M = {}

local function get_focus_toggles(controller)
    if not controller then
        return nil
    end
    return controller
end

function M.create(app)
    local self = {}

    local function mark_managed_focus_session()
        app.state.status.managedFocusSession = true
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
    function self.prepare_native_entry()
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
            self.activate(true)
            app.state.pending.weaponDrawStage = 0
        end
    end

    return self
end

return M
