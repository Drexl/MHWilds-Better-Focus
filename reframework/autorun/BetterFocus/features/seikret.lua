local M = {}

local function get_field_safe(object, field_name)
    local ok, value = pcall(function()
        return object:get_field(field_name)
    end)
    if ok then
        return value
    end
    return nil
end

function M.create(app)
    local self = {}
    local is_replaying_ride_judge = false
    local last_call_key_down = false
    local call_porter_action_category = 0
    local call_porter_action_index = 64
    local unarmed_call_attempt_duration = 0.60
    local delayed_replay_interval = 0.10
    local max_delayed_replay_attempts = 2

    local jump_window_start_types = {
        "app.WpCommonActions.cPorterDismountJumpOff",
        "app.PlayerCommonAction.cPorterDismountJumpOff",
        "app.PlayerCommonAction.cPorterDismountBase",
        "app.PlayerCommonAction.cPorterDismount",
        "app.PlayerCommonAction.cPorterDismountMoving",
        "app.PlayerCommonAction.cPorterDismountCombat",
        "app.PlayerCommonAction.cPorterDismountLand",
    }

    local jump_window_consumer_types = {
        "app.WpCommonActions.cBattleRideAttackWp",
        "app.WpCommonActions.cBattleRideFinishAttack",
    }

    local mount_start_types = {
        "app.PlayerCommonAction.cPorterRideStart",
        "app.PlayerCommonAction.cPorterRideStartJumpOnto",
    }

    local direct_focus_attack_types = {
        "app.WpCommonSubAction.cPorterRideDismountAttackStart",
        "app.WpCommonActions.cPorterRideDismountAttack",
        "app.WpCommonActions.cPorterRideDismountAttackLand",
    }

    local slinger_exit_types = {
        "app.PlayerCommonSubAction.cSlingerAimEnd",
        "app.PlayerCommonSubAction.cCallPorter",
        "app.WpCommonSubAction.cCallPorter",
    }

    function self.is_dismount_context_active()
        return os.clock() <= app.state.seikret.dismountContextUntil
    end

    function self.is_unarmed_focus_active()
        return app.state.status.isSlingerAimActive and not app.game.is_weapon_drawn()
    end

    function self.is_unarmed_call_attempt_active()
        return os.clock() <= app.state.seikret.unarmedCallAttemptUntil
    end

    function self.begin_unarmed_call_attempt()
        app.state.seikret.unarmedCallAttemptId = app.state.seikret.unarmedCallAttemptId + 1
        app.state.seikret.unarmedCallAttemptUntil = os.clock() + unarmed_call_attempt_duration
        app.state.seikret.lastUnarmedCallNudgeAt = 0
        app.state.seikret.unarmedCallPrepareSeen = false
        app.state.seikret.unarmedCallEnterSeen = false
        app.state.seikret.unarmedCallSuccessNudged = false
        app.state.seikret.restoreFocusOnSuccessfulUnarmedCall = self.is_unarmed_focus_active()
        app.state.seikret.pendingSuccessInputCheck = nil
        app.state.seikret.pendingSuccessCommandWork = nil
        app.state.seikret.pendingSuccessAt = 0
        app.state.seikret.pendingSuccessAttempts = 0
        app.state.seikret.pendingRideJudge = nil
        app.state.seikret.pendingRideJudgeCommandWork = nil
        app.state.seikret.pendingRideJudgeOptionArg = nil
        app.state.seikret.pendingRideJudgeAt = 0
        app.state.seikret.pendingRideJudgeAttempts = 0
        app.state.seikret.pendingSubActionRequestAt = 0
        app.state.seikret.pendingSubActionRequestAttempts = 0
        app.dev.trace_seikret("unarmedCallAttempt.begin", "id=" .. tostring(app.state.seikret.unarmedCallAttemptId))
    end

    function self.finish_unarmed_call_attempt(result_name)
        if app.state.seikret.unarmedCallAttemptUntil <= 0 then
            return
        end

        app.dev.trace_seikret(result_name, "id=" .. tostring(app.state.seikret.unarmedCallAttemptId))
        app.state.seikret.unarmedCallAttemptUntil = 0
        app.state.seikret.restoreFocusOnSuccessfulUnarmedCall = false
        app.state.seikret.pendingSuccessInputCheck = nil
        app.state.seikret.pendingSuccessCommandWork = nil
        app.state.seikret.pendingSuccessAt = 0
        app.state.seikret.pendingSuccessAttempts = 0
        app.state.seikret.pendingRideJudge = nil
        app.state.seikret.pendingRideJudgeCommandWork = nil
        app.state.seikret.pendingRideJudgeOptionArg = nil
        app.state.seikret.pendingRideJudgeAt = 0
        app.state.seikret.pendingRideJudgeAttempts = 0
        app.state.seikret.pendingSubActionRequestAt = 0
        app.state.seikret.pendingSubActionRequestAttempts = 0
    end

    -- Seikret call is blocked while the player is in the unarmed slinger/focus
    -- state. When a real porter-call attempt starts, Better Focus drops focus
    -- once so the game can accept the call.
    function self.try_allow_unarmed_call(reason)
        if not app.config.seikret.allowUnarmedFocusCall then
            app.dev.trace_seikret("tryAllowUnarmedCall.skipped", "reason=settingOff")
            return false
        end

        if not self.is_unarmed_focus_active() then
            app.dev.trace_seikret("tryAllowUnarmedCall.skipped", "reason=notUnarmedFocus")
            return false
        end

        if (os.clock() - app.state.seikret.lastUnarmedCallFocusDropAt) < 0.15 then
            app.dev.trace_seikret("tryAllowUnarmedCall.skipped", "reason=debounce")
            return false
        end

        app.state.seikret.lastUnarmedCallFocusDropAt = os.clock()
        app.dev.trace_seikret("tryAllowUnarmedCall.drop", "reason=" .. tostring(reason or "unknown"))
        app.focus.disable()
        return true
    end

    function self.try_begin_unarmed_call_attempt(reason)
        if self.is_unarmed_call_attempt_active() then
            return false
        end

        if not app.config.seikret.allowUnarmedFocusCall then
            return false
        end

        if not self.is_unarmed_focus_active() then
            return false
        end

        self.begin_unarmed_call_attempt()
        return self.try_allow_unarmed_call(reason)
    end

    -- Some Seikret actions and normal weapon-draw actions happen close together.
    -- This window keeps disabled-weapon Seikret dismounts from borrowing the
    -- normal draw-to-focus path.
    function self.should_suppress_disabled_dismount()
        return not app.game.is_weapon_enabled() and self.is_dismount_context_active()
    end

    -- Jumping off Seikret does not always mean an attack will happen, so this
    -- opens a short window and waits for a real follow-up attack before turning
    -- focus on.
    function self.begin_jump_attack_window()
        app.state.seikret.dismountContextUntil = os.clock() + app.state.seikret.jumpWindowDuration

        if not app.game.is_weapon_enabled() then
            app.state.seikret.jumpAttackUntil = 0
            return
        end

        app.state.seikret.jumpAttackUntil = app.state.seikret.dismountContextUntil
    end

    function self.consume_jump_attack_window()
        if os.clock() > app.state.seikret.jumpAttackUntil then
            return false
        end

        app.state.seikret.jumpAttackUntil = 0
        return true
    end

    function self.trigger_jump_attack_focus()
        if app.game.is_weapon_enabled() and app.state.seikret.jumpAttackUntil > 0 and self.consume_jump_attack_window() then
            app.focus.activate(true)
            return true
        end

        return false
    end

    function self.get_mount_behavior()
        return app.config.seikret.mountBehavior
    end

    function self.set_mount_behavior(mode)
        app.config.seikret.mountBehavior = mode
        app.save_config()
    end

    function self.apply_mount_behavior()
        local mode = self.get_mount_behavior()
        if mode == "alwaysOn" then
            app.focus.activate(true)
        elseif mode == "alwaysOff" then
            app.focus.disable()
        end
    end

    function self.init()
        app.hooks.hook_owner("app.PlayerCommonSubAction.cSlingerAim", { "doEnter()", "doEnter" }, function()
            app.state.status.isSlingerAimActive = true
        end)

        for _, type_name in ipairs(slinger_exit_types) do
            app.hooks.hook_owner(type_name, { "doEnter()", "doEnter" }, function()
                app.state.status.isSlingerAimActive = false
            end)
        end

        -- Input-check normal execution runs while the player is holding the
        -- porter-call input. Gating on the hold timer keeps the fix tied to a
        -- real call attempt instead of merely entering slinger aim.
        local call_porter_input_hooked = app.hooks.hook(
            "app.btable.PlCommand.cCallPorterInputCheck",
            {
                "executePrepareAction(app.cPlayerBTableCommandWork)",
                "executePrepareAction",
                "judge(app.cPlayerBTableCommandWork, app.btable.PlCommand.cOptionArg)",
                "judge",
            },
            function(args)
            local input_check = app.game.try_get_managed_object(args and args[2] or nil)
            local pressed_timer = input_check and get_field_safe(input_check, "_PressedTimer") or nil
            app.dev.trace_seikret("callPorterInput.executePrepareAction", "pressedTimer=" .. tostring(pressed_timer))
            if type(pressed_timer) == "number" and pressed_timer > 0 then
                self.try_begin_unarmed_call_attempt("callPorterInput")
            end
            if self.is_unarmed_call_attempt_active() and not app.state.seikret.unarmedCallPrepareSeen then
                app.state.seikret.unarmedCallPrepareSeen = true
                app.dev.trace_seikret("unarmedCallAttempt.prepareAction", "id=" .. tostring(app.state.seikret.unarmedCallAttemptId))
            end

            if self.is_unarmed_call_attempt_active()
                and not app.state.seikret.unarmedCallSuccessNudged
                and not app.state.seikret.unarmedCallEnterSeen
                and input_check
                and args
                and args[3] ~= nil
                and (os.clock() - app.state.seikret.lastUnarmedCallFocusDropAt) <= 1.0 then
                app.state.seikret.unarmedCallSuccessNudged = true
                app.state.seikret.pendingSuccessInputCheck = input_check
                app.state.seikret.pendingSuccessCommandWork = args[3]
                app.state.seikret.pendingSuccessAt = os.clock() + delayed_replay_interval
                app.state.seikret.pendingSuccessAttempts = 0
                app.state.seikret.pendingSubActionRequestAt = os.clock() + delayed_replay_interval
                app.state.seikret.pendingSubActionRequestAttempts = 0
                app.dev.trace_seikret("unarmedCallAttempt.queueSuccess", "id=" .. tostring(app.state.seikret.unarmedCallAttemptId))
            end
        end
        )
        app.dev.trace_seikret("hook.register", "callPorterInput=" .. tostring(call_porter_input_hooked))

        local ride_call_judge_hooked = app.hooks.hook(
            "app.btable.PlCommand.cRideCallPorterJudge",
            {
                "executePrepareAction(app.cPlayerBTableCommandWork, app.btable.PlCommand.cOptionArg)",
                "executePrepareAction",
                "judge(app.cPlayerBTableCommandWork, app.btable.PlCommand.cOptionArg)",
                "judge",
            },
            function(args)
            app.dev.trace_seikret("rideCallPorterJudge.executePrepareAction")
            if self.is_unarmed_call_attempt_active() and not app.state.seikret.unarmedCallPrepareSeen then
                app.state.seikret.unarmedCallPrepareSeen = true
                app.dev.trace_seikret("unarmedCallAttempt.prepareAction", "id=" .. tostring(app.state.seikret.unarmedCallAttemptId))
            end

            if self.is_unarmed_call_attempt_active()
                and not app.state.seikret.unarmedCallEnterSeen
                and not is_replaying_ride_judge
                and args
                and args[2] ~= nil
                and args[3] ~= nil
                and args[4] ~= nil
                and (os.clock() - app.state.seikret.lastUnarmedCallFocusDropAt) <= 1.0 then
                local judge = app.game.try_get_managed_object(args[2])
                if judge then
                    app.state.seikret.pendingRideJudge = judge
                    app.state.seikret.pendingRideJudgeCommandWork = args[3]
                    app.state.seikret.pendingRideJudgeOptionArg = args[4]
                    app.state.seikret.pendingRideJudgeAt = os.clock() + delayed_replay_interval
                    app.state.seikret.pendingRideJudgeAttempts = 0
                    app.dev.trace_seikret("unarmedCallAttempt.queueJudgeReplay", "id=" .. tostring(app.state.seikret.unarmedCallAttemptId))
                end
            end
        end
        )
        app.dev.trace_seikret("hook.register", "rideCallPorterJudge=" .. tostring(ride_call_judge_hooked))

        app.hooks.hook_owner("app.PlayerCommonSubAction.cCallPorter", { "doEnter()", "doEnter" }, function()
            app.dev.trace_seikret("playerCallPorter.doEnter")
            app.state.seikret.unarmedCallEnterSeen = true
            if app.state.seikret.restoreFocusOnSuccessfulUnarmedCall then
                app.focus.activate(true)
            end
            self.finish_unarmed_call_attempt("unarmedCallAttempt.success")
            app.state.status.isSlingerAimActive = false
        end)

        app.hooks.hook_owner("app.WpCommonSubAction.cCallPorter", { "doEnter()", "doEnter" }, function()
            app.dev.trace_seikret("weaponCallPorter.doEnter")
            app.state.seikret.unarmedCallEnterSeen = true
            if app.state.seikret.restoreFocusOnSuccessfulUnarmedCall then
                app.focus.activate(true)
            end
            self.finish_unarmed_call_attempt("unarmedCallAttempt.success")
            app.state.status.isSlingerAimActive = false
        end)

        local function hook_jump_window_start(type_name)
            app.hooks.hook_owner(type_name, { "doEnter()", "doEnter" }, function()
                self.begin_jump_attack_window()
            end)
        end

        local function hook_jump_window_consumer(type_name)
            app.hooks.hook_owner(type_name, { "doEnter()", "doEnter" }, function()
                self.trigger_jump_attack_focus()
            end)
        end

        local function hook_direct_focus_attack(type_name)
            app.hooks.hook_owner(type_name, { "doEnter()", "doEnter" }, function()
                if app.game.is_weapon_enabled() then
                    app.focus.activate(true)
                end
            end)
        end

        local function hook_mount_start(type_name)
            app.hooks.hook_owner(type_name, { "doEnter()", "doEnter" }, function()
                self.apply_mount_behavior()
            end)
        end

        for _, type_name in ipairs(jump_window_start_types) do
            hook_jump_window_start(type_name)
        end

        for _, type_name in ipairs(jump_window_consumer_types) do
            hook_jump_window_consumer(type_name)
        end

        for _, type_name in ipairs(direct_focus_attack_types) do
            hook_direct_focus_attack(type_name)
        end

        for _, type_name in ipairs(mount_start_types) do
            hook_mount_start(type_name)
        end

        -- This attack callback is a reliable way to confirm that the player has
        -- actually attacked during the jump window.
        app.hooks.hook("app.Weapon", "evAttackCollisionActive", function(args)
            local weapon = app.game.try_get_managed_object(args and args[2] or nil)
            if weapon and weapon:get_IsMaster() == true then
                self.trigger_jump_attack_focus()
            end
        end)
    end

    function self.update()
        local is_call_key_down = app.game.is_seikret_call_key_down()
        if is_call_key_down and not last_call_key_down then
            self.try_begin_unarmed_call_attempt("savedKey")
        end
        last_call_key_down = is_call_key_down

        if self.is_unarmed_call_attempt_active() then
            if app.state.seikret.pendingRideJudgeAt > 0
                and not app.state.seikret.unarmedCallEnterSeen
                and os.clock() >= app.state.seikret.pendingRideJudgeAt
                and app.state.seikret.pendingRideJudgeAttempts < max_delayed_replay_attempts then
                app.state.seikret.pendingRideJudgeAttempts = app.state.seikret.pendingRideJudgeAttempts + 1

                local judge_ok = pcall(function()
                    is_replaying_ride_judge = true
                    app.state.seikret.pendingRideJudge:call(
                        "judge(app.cPlayerBTableCommandWork, app.btable.PlCommand.cOptionArg)",
                        app.state.seikret.pendingRideJudgeCommandWork,
                        app.state.seikret.pendingRideJudgeOptionArg
                    )
                end)
                local prepare_ok = pcall(function()
                    app.state.seikret.pendingRideJudge:call(
                        "executePrepareAction(app.cPlayerBTableCommandWork, app.btable.PlCommand.cOptionArg)",
                        app.state.seikret.pendingRideJudgeCommandWork,
                        app.state.seikret.pendingRideJudgeOptionArg
                    )
                end)
                is_replaying_ride_judge = false
                app.dev.trace_seikret(
                    "unarmedCallAttempt.replayJudge",
                    "id=" .. tostring(app.state.seikret.unarmedCallAttemptId)
                        .. " attempt=" .. tostring(app.state.seikret.pendingRideJudgeAttempts)
                        .. " judgeOk=" .. tostring(judge_ok)
                        .. " prepareOk=" .. tostring(prepare_ok)
                )

                if app.state.seikret.unarmedCallEnterSeen or app.state.seikret.pendingRideJudgeAttempts >= max_delayed_replay_attempts then
                    app.state.seikret.pendingRideJudgeAt = 0
                else
                    app.state.seikret.pendingRideJudgeAt = os.clock() + delayed_replay_interval
                end
            end

            if app.state.seikret.pendingSubActionRequestAt > 0
                and not app.state.seikret.unarmedCallEnterSeen
                and os.clock() >= app.state.seikret.pendingSubActionRequestAt
                and app.state.seikret.pendingSubActionRequestAttempts < max_delayed_replay_attempts then
                app.state.seikret.pendingSubActionRequestAttempts = app.state.seikret.pendingSubActionRequestAttempts + 1
                local ok = app.game.request_player_sub_action(call_porter_action_category, call_porter_action_index)
                app.dev.trace_seikret(
                    "unarmedCallAttempt.requestAction",
                    "id=" .. tostring(app.state.seikret.unarmedCallAttemptId)
                        .. " attempt=" .. tostring(app.state.seikret.pendingSubActionRequestAttempts)
                        .. " ok=" .. tostring(ok)
                )

                if app.state.seikret.unarmedCallEnterSeen or app.state.seikret.pendingSubActionRequestAttempts >= max_delayed_replay_attempts then
                    app.state.seikret.pendingSubActionRequestAt = 0
                else
                    app.state.seikret.pendingSubActionRequestAt = os.clock() + delayed_replay_interval
                end
            end

            if app.state.seikret.pendingSuccessAt > 0
                and not app.state.seikret.unarmedCallEnterSeen
                and os.clock() >= app.state.seikret.pendingSuccessAt
                and app.state.seikret.pendingSuccessAttempts < max_delayed_replay_attempts then
                app.state.seikret.pendingSuccessAttempts = app.state.seikret.pendingSuccessAttempts + 1
                local ok = pcall(function()
                    app.state.seikret.pendingSuccessInputCheck:call(
                        "success(app.cPlayerBTableCommandWork)",
                        app.state.seikret.pendingSuccessCommandWork
                    )
                end)
                app.dev.trace_seikret(
                    "unarmedCallAttempt.forceSuccess",
                    "id=" .. tostring(app.state.seikret.unarmedCallAttemptId)
                        .. " attempt=" .. tostring(app.state.seikret.pendingSuccessAttempts)
                        .. " ok=" .. tostring(ok)
                )

                if app.state.seikret.unarmedCallEnterSeen or app.state.seikret.pendingSuccessAttempts >= max_delayed_replay_attempts then
                    app.state.seikret.pendingSuccessAt = 0
                else
                    app.state.seikret.pendingSuccessAt = os.clock() + delayed_replay_interval
                end
            end
        elseif app.state.seikret.unarmedCallAttemptUntil > 0 then
            self.finish_unarmed_call_attempt("unarmedCallAttempt.timeout")
        end

        if app.game.is_weapon_drawn() then
            app.state.status.isSlingerAimActive = false
        end

        if app.state.seikret.jumpAttackUntil > 0 and os.clock() > app.state.seikret.jumpAttackUntil then
            app.state.seikret.jumpAttackUntil = 0
        end

        if app.state.seikret.dismountContextUntil > 0 and os.clock() > app.state.seikret.dismountContextUntil then
            app.state.seikret.dismountContextUntil = 0
        end
    end

    return self
end

return M
