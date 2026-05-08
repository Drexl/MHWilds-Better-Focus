local Util = require("BetterFocus.core.util")

local build_weapon_action_type_names = Util.build_weapon_action_type_names
local build_weapon_sub_action_type_names = Util.build_weapon_subaction_type_names

local M = {}

function M.create(app)
    local self = {}
    local draw_entry_sheathe_grace = 0.50
    local long_sword_special_sheathe_timeout = 5.0

    local native_focus_entry_types = {
        "app.WpCommonActions.cAimIdle",
        "app.WpCommonActions.cAimWalk",
    }

    local stealth_attack_types = {
        "app.WpCommonActions.cStealthAttack",
        "app.WpCommonActions.cStealthJumpAttack",
    }

    local long_sword_special_sheathe_types = {
        "app.Wp03Action.cIaiWpOff",
    }

    local long_sword_special_sheathe_cancel_types = {
        "app.PlayerCommonAction.cDodge",
        "app.PlayerCommonAction.cIdle",
        "app.Wp03Action.cIaiEnd",
    }

    local long_sword_special_sheathe_followup_types = {
        "app.Wp03Action.cIaiSlash",
        "app.Wp03Action.cIaiKijinSlash",
        "app.Wp03Action.cIaiKijinSlashRed",
        "app.Wp03Action.cIaiKijinSlashWhite",
        "app.Wp03Action.cIaiKijinSlashYellow",
    }

    local draw_entry_types = {
        "app.WpCommonActions.cWpMoveOn",
        "app.WpCommonActions.cWpStepOn",
    }

    local sheathe_types = {
        "app.WpCommonActions.cWpOff",
        "app.WpCommonActions.cWpDodgeOff",
        "app.WpCommonActions.cWpMoveOff",
        "app.WpCommonSubAction.cWpMoveOff",
    }

    local weapon_aim_idle_types = build_weapon_action_type_names("cAimIdle")
    local weapon_aim_walk_types = build_weapon_action_type_names("cAimWalk")
    local weapon_stealth_attack_types = build_weapon_action_type_names("cStealthAttack")
    local weapon_stealth_jump_attack_types = build_weapon_action_type_names("cStealthJumpAttack")
    local weapon_move_on_types = build_weapon_action_type_names("cWpMoveOn")
    local weapon_step_on_types = build_weapon_action_type_names("cWpStepOn")
    local weapon_off_types = build_weapon_action_type_names("cWpOff")
    local weapon_dodge_off_types = build_weapon_action_type_names("cWpDodgeOff")
    local weapon_move_off_types = build_weapon_action_type_names("cWpMoveOff")
    local weapon_move_off_subaction_types = build_weapon_sub_action_type_names("cWpMoveOff")

    -- Wilds confirms a successful weapon draw at the command-judge layer before
    -- later action states fully settle, so draw detection starts here.
    local function hook_draw_judge(type_name)
        app.hooks.hook(type_name, "judge(app.cPlayerBTableCommandWork, app.btable.PlCommand.cOptionArg)", function(args)
            local command_work = app.game.try_get_managed_object(args and args[3] or nil)
            if not command_work or not app.game.command_work_matches_player(command_work) then
                return
            end

            local wp_on = app.game.check_command_result(command_work, 0, 14)
            local wp_special_on = app.game.check_command_result(command_work, 0, 15)
            local wp_move_on = app.game.check_command_result(command_work, 0, 16)
            local wp_move_special_on = app.game.check_command_result(command_work, 0, 17)
            if wp_on or wp_special_on or wp_move_on or wp_move_special_on then
                app.state.status.ignoreSheatheUntil = os.clock() + draw_entry_sheathe_grace
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
            if not app.game.is_weapon_enabled() then
                -- Per-weapon toggles disable Better Focus automation for that
                -- weapon. They should not force native manual focus activation
                -- back off just because the mod's draw/sheathe latch was last
                -- updated by some other weapon state.
                return
            end

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

    local function hook_draw_entry(type_name)
        app.hooks.hook_owner(type_name, { "doEnter()", "doEnter" }, function()
            if app.game.is_weapon_enabled() then
                -- Some draw variants, notably moving bowgun unsheath, can miss
                -- the earlier command-judge path. Queue focus again here as a
                -- fallback; queue_weapon_draw's cooldown prevents duplicate
                -- requests when the judge hook already fired. Some weapons can
                -- still transition through sheath/off actions while the draw is
                -- settling, so give all sheath detectors a brief grace window.
                app.state.status.ignoreSheatheUntil = os.clock() + draw_entry_sheathe_grace
                app.focus.queue_weapon_draw()
            end
        end)
    end

    local function hook_focus_off_on_sheathe(type_name)
        app.hooks.hook_owner(type_name, { "doEnter()", "doEnter" }, function()
            if app.state.status.ignoreSheatheUntil > os.clock() then
                return
            end

            if app.config.misc.focusOffOnSheathe then
                app.focus.on_weapon_sheathed(type_name)
            end
        end)
    end

    local function hook_long_sword_special_sheathe(type_name)
        app.hooks.hook_owner(type_name, { "doEnter()", "doEnter" }, function()
            app.state.status.longSwordIaiActive = true
            app.state.status.longSwordIaiUntil = os.clock() + long_sword_special_sheathe_timeout
        end)
    end

    local function hook_long_sword_special_sheathe_cancel(type_name)
        app.hooks.hook_owner(type_name, { "doEnter()", "doEnter" }, function()
            if not app.state.status.longSwordIaiActive then
                return
            end

            app.state.status.longSwordIaiActive = false
            app.state.status.longSwordIaiUntil = 0

            if app.config.misc.focusOffOnSheathe then
                app.focus.on_weapon_sheathed(type_name)
            end
        end)
    end

    local function hook_long_sword_special_sheathe_followup(type_name)
        app.hooks.hook_owner(type_name, { "doEnter()", "doEnter" }, function()
            app.state.status.longSwordIaiActive = false
            app.state.status.longSwordIaiUntil = 0
        end)
    end

    -- Long Sword special sheathe should not leave a broad "armed" state
    -- hanging around indefinitely. If no explicit follow-up or end action was
    -- seen within the stance's practical lifetime, treat it as ended.
    function self.update()
        if not app.state.status.longSwordIaiActive then
            return
        end

        if app.state.status.longSwordIaiUntil > os.clock() then
            return
        end

        app.state.status.longSwordIaiActive = false
        app.state.status.longSwordIaiUntil = 0

        if app.config.misc.focusOffOnSheathe then
            app.focus.on_weapon_sheathed("longSwordIaiTimeout")
        end
    end

    -- Engine-level catch-all: the game calls onWeaponOnStateChanged on the
    -- HunterCharacter whenever _IsWeaponOn flips. This fires for every
    -- weapon-off transition including forced sheathes during stun, grab,
    -- paralysis, and other incapacitation recoveries that bypass the normal
    -- action-level cWpOff / cWpMoveOff hooks above.
    --
    -- The existing per-action hooks handle normal voluntary sheathes; this
    -- hook exists to close the gap where the engine sheathes the weapon
    -- without going through a player-initiated action state.
    local function hook_engine_weapon_state_change()
        local pending_character = nil

        app.hooks.hook("app.HunterCharacter",
            { "onWeaponOnStateChanged(System.Boolean)", "onWeaponOnStateChanged" },
            function(args)
                -- Pre-hook: capture this pointer, filter to master player.
                local character = app.game.try_get_managed_object(args and args[2] or nil)
                if character and character == app.game.get_player_character() then
                    pending_character = character
                else
                    pending_character = nil
                end
            end,
            function(retval)
                -- Post-hook: the state has been applied. Check is_weapon_drawn
                -- to see the new value rather than parsing the boolean arg.
                local character = pending_character
                pending_character = nil
                if not character then
                    return retval
                end

                if not app.game.is_weapon_drawn() then
                    -- Respect the draw-entry grace window: during weapon-draw
                    -- transitions the engine may briefly flip weapon-off before
                    -- the draw animation commits.
                    if app.state.status.ignoreSheatheUntil > os.clock() then
                        return retval
                    end

                    if app.config.misc.focusOffOnSheathe then
                        app.focus.on_weapon_sheathed("engine_weapon_off")
                    end
                end

                return retval
            end
        )
    end

    -- All weapon-driven behavior lives in one place so a reader can answer
    -- "what can my weapon do to focus mode?" without jumping files.
    function self.init()
        hook_engine_weapon_state_change()

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

        for _, type_name in ipairs(draw_entry_types) do
            hook_draw_entry(type_name)
        end

        for _, type_name in ipairs(weapon_move_on_types) do
            hook_draw_entry(type_name)
        end

        for _, type_name in ipairs(weapon_step_on_types) do
            hook_draw_entry(type_name)
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

        for _, type_name in ipairs(long_sword_special_sheathe_types) do
            hook_long_sword_special_sheathe(type_name)
        end

        for _, type_name in ipairs(long_sword_special_sheathe_cancel_types) do
            hook_long_sword_special_sheathe_cancel(type_name)
        end

        for _, type_name in ipairs(long_sword_special_sheathe_followup_types) do
            hook_long_sword_special_sheathe_followup(type_name)
        end

        for _, type_name in ipairs(weapon_off_types) do
            hook_focus_off_on_sheathe(type_name)
        end

        for _, type_name in ipairs(weapon_dodge_off_types) do
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
