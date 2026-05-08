local Util = require("BetterFocus.core.util")

local build_weapon_action_type_names = Util.build_weapon_action_type_names

local M = {}

local function clone_vec3(value)
    if not value then
        return nil
    end

    return {
        x = tonumber(value.x) or 0,
        y = tonumber(value.y) or 0,
        z = tonumber(value.z) or 0,
    }
end

local function apply_vec3(target, source)
    if not target or not source then
        return
    end

    target.x = source.x
    target.y = source.y
    target.z = source.z
end

function M.create(app)
    local self = {}

    local guard_types = build_weapon_action_type_names("cGuard")

    -- This feature keeps lock-on while preventing the camera from snapping onto
    -- the locked target. It works by clearing the camera's target-rotation and
    -- look-at requests for a short window after focus turns on.
    function self.request_suppress_target_snap()
        if not app.config.misc.disableTargetCameraSnap then
            return
        end

        local player_camera = app.game.get_player_camera()
        if not player_camera then
            return
        end

        local auto_rotator = player_camera._AutoRotator
        if auto_rotator then
            auto_rotator._IsDisableTargetMode = true
            pcall(function()
                auto_rotator._AddRot.x = 0
                auto_rotator._AddRot.y = 0
            end)
        end

        local mini_components = app.game.get_camera_mini_components()
        local mini_auto_rotate = mini_components and mini_components.AutoRotate or nil
        if mini_auto_rotate then
            mini_auto_rotate._IsValid = false
            mini_auto_rotate._IsRequestedBreak = true
            mini_auto_rotate._IsContinueEnable = false
            pcall(function()
                mini_auto_rotate._RotAmount.x = 0
                mini_auto_rotate._RotAmount.y = 0
                mini_auto_rotate._CaptureRotationDegree.x = 0
                mini_auto_rotate._CaptureRotationDegree.y = 0
            end)
        end

        local mini_smooth_control = mini_components and mini_components.SmoothControl or nil
        if mini_smooth_control then
            mini_smooth_control._IsEnable = false
            mini_smooth_control._IsRequestDisable = true
        end

        pcall(function()
            player_camera:call("requestDisableTargetRot()")
        end)

        for priority = 0, 64 do
            pcall(function()
                player_camera:call("requestCancelLookat(app.CameraDef.LOOK_AT_PRIORITY)", priority)
            end)
            pcall(function()
                player_camera:call("requestAutoRotateBreak(app.CameraDef.AUTO_ROTATE_PRIORITY)", priority)
            end)
        end
    end

    function self.restore_target_snap_behavior()
        local player_camera = app.game.get_player_camera()
        if not player_camera then
            return
        end

        local auto_rotator = player_camera._AutoRotator
        if auto_rotator then
            auto_rotator._IsDisableTargetMode = false
        end

        local mini_components = app.game.get_camera_mini_components()
        local mini_auto_rotate = mini_components and mini_components.AutoRotate or nil
        if mini_auto_rotate then
            mini_auto_rotate._IsRequestedBreak = false
        end

        local mini_smooth_control = mini_components and mini_components.SmoothControl or nil
        if mini_smooth_control then
            mini_smooth_control._IsRequestDisable = false
        end
    end

    -- The sight controller is frozen briefly so the camera does not lurch while
    -- target snap is being suppressed.
    function self.capture_frozen_sight()
        local sight_controller = app.game.get_sight_controller()
        if not sight_controller then
            return
        end

        app.state.camera.frozenSightEye = clone_vec3(sight_controller._CameraEyePos)
        app.state.camera.frozenSightPos = clone_vec3(sight_controller._SightPos)
        app.state.camera.frozenSightDir = clone_vec3(sight_controller._CameraLookAtDir)
        app.state.camera.frozenSightUntil = os.clock() + 0.20
    end

    function self.apply_frozen_sight()
        if app.state.camera.frozenSightUntil <= os.clock() then
            return
        end

        local sight_controller = app.game.get_sight_controller()
        if not sight_controller then
            return
        end

        pcall(function()
            apply_vec3(sight_controller._CameraEyePos, app.state.camera.frozenSightEye)
            apply_vec3(sight_controller._SightPos, app.state.camera.frozenSightPos)
            apply_vec3(sight_controller._CameraLookAtDir, app.state.camera.frozenSightDir)
        end)
    end

    function self.begin_suppress_window()
        if not app.config.misc.disableTargetCameraSnap then
            return
        end

        app.state.camera.suppressUntil = os.clock() + 0.20
        self.request_suppress_target_snap()
    end

    -- Block snap intentionally toggles focus off and back on so the target
    -- camera grabs the locked monster once at the start of a guard.
    function self.handle_block_snap()
        if app.state.status.isCrouchTurn or not app.config.misc.snapToMonsterOnBlock then
            return
        end

        if app.state.pending.blockSnapStage ~= 0 then
            return
        end

        if (os.clock() - app.state.pending.lastBlockSnapRequestAt) < 0.06 then
            return
        end

        app.state.pending.lastBlockSnapRequestAt = os.clock()
        app.state.camera.suppressUntil = 0
        app.state.camera.frozenSightUntil = 0
        self.restore_target_snap_behavior()
        app.state.pending.blockSnapStage = 1
        app.state.camera.isBlockGuardActive = true
        app.state.camera.blockSnapBypassUntil = os.clock() + 0.25
    end

    function self.init()
        local function hook_guard_update(type_name)
            app.hooks.hook_owner(type_name, { "doUpdate()", "doUpdate" }, function()
                app.state.camera.lastBlockGuardUpdateAt = os.clock()
                if app.config.misc.snapToMonsterOnBlock and not app.state.camera.isBlockGuardActive then
                    self.handle_block_snap()
                end
            end)
        end

        hook_guard_update("app.WpCommonActions.cGuard")
        for _, type_name in ipairs(guard_types) do
            hook_guard_update(type_name)
        end
    end

    -- Camera state is maintained every frame because the underlying camera can
    -- rebuild its own requests while focus stays active.
    function self.update()
        local is_targeting = app.game.is_camera_targeting()

        if app.state.camera.isBlockGuardActive and (os.clock() - app.state.camera.lastBlockGuardUpdateAt) > 0.06 then
            app.state.camera.isBlockGuardActive = false
        end

        if app.state.status.wasTargeting == nil then
            app.state.status.wasTargeting = is_targeting
        elseif app.config.misc.disableTargetCameraSnap and app.state.camera.blockSnapBypassUntil <= os.clock() and is_targeting and not app.state.status.wasTargeting then
            self.begin_suppress_window()
        end

        if app.state.camera.blockSnapBypassUntil > os.clock() then
            self.restore_target_snap_behavior()
        elseif app.config.misc.disableTargetCameraSnap and (app.state.camera.suppressUntil > os.clock() or is_targeting) then
            self.request_suppress_target_snap()
        else
            self.restore_target_snap_behavior()
        end

        self.apply_frozen_sight()
        app.state.status.wasTargeting = is_targeting
    end

    return self
end

return M
