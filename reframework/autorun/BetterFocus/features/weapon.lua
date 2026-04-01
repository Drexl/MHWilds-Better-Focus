local M = {}

local function build_weapon_action_type_names(action_name)
    local type_names = {}
    for type_id = 0, 13 do
        type_names[#type_names + 1] = string.format("app.Wp%02dAction.%s", type_id, action_name)
    end
    return type_names
end

local function build_weapon_sub_action_type_names(action_name)
    local type_names = {}
    for type_id = 0, 13 do
        type_names[#type_names + 1] = string.format("app.Wp%02dSubAction.%s", type_id, action_name)
    end
    return type_names
end

function M.create(app)
    local self = {}

    local native_focus_entry_types = {
        "app.WpCommonActions.cAimIdle",
        "app.WpCommonActions.cAimWalk",
    }

    local stealth_attack_types = {
        "app.WpCommonActions.cStealthAttack",
        "app.WpCommonActions.cStealthJumpAttack",
    }

    local sheathe_types = {
        "app.WpCommonActions.cWpOff",
        "app.WpCommonActions.cWpMoveOff",
        "app.WpCommonSubAction.cWpMoveOff",
    }

    local weapon_aim_idle_types = build_weapon_action_type_names("cAimIdle")
    local weapon_aim_walk_types = build_weapon_action_type_names("cAimWalk")
    local weapon_stealth_attack_types = build_weapon_action_type_names("cStealthAttack")
    local weapon_stealth_jump_attack_types = build_weapon_action_type_names("cStealthJumpAttack")
    local weapon_off_types = build_weapon_action_type_names("cWpOff")
    local weapon_move_off_types = build_weapon_action_type_names("cWpMoveOff")
    local weapon_move_off_subaction_types = build_weapon_sub_action_type_names("cWpMoveOff")

    -- Wilds confirms a successful weapon draw at the command-judge layer before
    -- later action states fully settle, so draw detection starts here.
    local function hook_draw_judge(type_name)
        app.hooks.hook(type_name, "judge(app.cPlayerBTableCommandWork, app.btable.PlCommand.cOptionArg)", function(args)
            local command_work = app.game.try_get_managed_object(args and args[3] or nil)
            if not command_work then
                return
            end

            local wp_on = app.game.check_command_result(command_work, 0, 14)
            local wp_special_on = app.game.check_command_result(command_work, 0, 15)
            local wp_move_on = app.game.check_command_result(command_work, 0, 16)
            local wp_move_special_on = app.game.check_command_result(command_work, 0, 17)
            if wp_on or wp_special_on or wp_move_on or wp_move_special_on then
                app.focus.queue_weapon_draw()
            end
        end)
    end

    -- These aim-entry hooks only exist so the camera module can prepare for a
    -- focus session before target-camera suppression begins.
    local function hook_native_focus_entry(type_name)
        app.hooks.hook_owner(type_name, { "doEnter()", "doEnter" }, function()
            if app.game.is_weapon_enabled() and not app.state.status.isCrouchTurn then
                app.focus.prepare_native_entry(type_name)
            end
        end, function()
            -- Some moves can transition through native focus-entry actions even
            -- though the weapon has effectively sheathed. Re-assert focus-off
            -- after the game's own doEnter logic if the player is still not
            -- drawn and the user wants focus cleared on sheathe.
            if app.config.misc.focusOffOnSheathe
                and app.state.status.suppressFocusUntilWeaponDrawn
                and not app.game.is_weapon_drawn() then
                app.focus.disable()
            end
        end)
    end

    local function hook_stealth_attack(type_name)
        app.hooks.hook_owner(type_name, { "doEnter()", "doEnter" }, function()
            if app.game.is_weapon_enabled() then
                -- Stealth attacks can begin from a sheathed state without going
                -- through the normal draw-judge path, so clear the suppress
                -- latch before forcing focus on.
                app.focus.on_weapon_drawn("stealth_attack")
                app.focus.activate(true)
            end
        end)
    end

    local function hook_focus_off_on_sheathe(type_name)
        app.hooks.hook_owner(type_name, { "doEnter()", "doEnter" }, function()
            if app.config.misc.focusOffOnSheathe then
                app.focus.on_weapon_sheathed(type_name)
            end
        end)
    end

    -- All weapon-driven behavior lives in one place so a reader can answer
    -- "what can my weapon do to focus mode?" without jumping files.
    function self.init()
        hook_draw_judge("app.btable.PlCommand.cWpOnJudge")
        hook_draw_judge("app.btable.PlCommand.cWpFlyOnJudge")

        for _, type_name in ipairs(native_focus_entry_types) do
            hook_native_focus_entry(type_name)
        end

        for _, type_name in ipairs(weapon_aim_idle_types) do
            hook_native_focus_entry(type_name)
        end

        for _, type_name in ipairs(weapon_aim_walk_types) do
            hook_native_focus_entry(type_name)
        end

        for _, type_name in ipairs(stealth_attack_types) do
            hook_stealth_attack(type_name)
        end

        for _, type_name in ipairs(weapon_stealth_attack_types) do
            hook_stealth_attack(type_name)
        end

        for _, type_name in ipairs(weapon_stealth_jump_attack_types) do
            hook_stealth_attack(type_name)
        end

        for _, type_name in ipairs(sheathe_types) do
            hook_focus_off_on_sheathe(type_name)
        end

        for _, type_name in ipairs(weapon_off_types) do
            hook_focus_off_on_sheathe(type_name)
        end

        for _, type_name in ipairs(weapon_move_off_types) do
            hook_focus_off_on_sheathe(type_name)
        end

        for _, type_name in ipairs(weapon_move_off_subaction_types) do
            hook_focus_off_on_sheathe(type_name)
        end
    end

    return self
end

return M
