local Config = require("BetterFocus.core.config")

local M = {}

function M.create(app)
    local self = {}
    local keyboard_shortcut_setting_present = nil
    local warning_color = 0xFF6060FF

    local function detect_keyboard_shortcut_setting()
        if keyboard_shortcut_setting_present ~= nil then
            return keyboard_shortcut_setting_present
        end

        local config = json.load_file("Keyboard_Shortcut_Setting.json")
        if type(config) == "table" then
            keyboard_shortcut_setting_present = true
            return true
        end

        keyboard_shortcut_setting_present = false
        return false
    end

    local function should_show_keyboard_shortcut_setting_notice()
        if app.config.misc.keyboardShortcutSettingNoticeDismissed then
            return false
        end

        if not detect_keyboard_shortcut_setting() then
            return false
        end

        return true
    end

    local function draw_keyboard_shortcut_setting_notice()
        if not should_show_keyboard_shortcut_setting_notice() then
            return
        end

        imgui.separator()
        imgui.text_colored('COMPATABILITY NOTICE', warning_color)
        imgui.text_colored('Better Focus has detected that you are using', warning_color)
        imgui.text_colored('the mod "Keyboard Shortcut Setting".', warning_color)
        imgui.text_colored('To avoid potentially jarring camera behavior', warning_color)
        imgui.text_colored('when performing certain actions from the', warning_color)
        imgui.text_colored('shortcut menu, please do not lower Shortcut', warning_color)
        imgui.text_colored('Display Time below 0.8 in that mod\'s settings.', warning_color)
        imgui.text_colored('Some weapons can get away with a lower value.', warning_color)
        imgui.new_line()

        if imgui.button("OK") then
            app.config.misc.keyboardShortcutSettingNoticeDismissed = true
            app.save_config()
        end

        imgui.separator()
        imgui.new_line()
    end

    local function checkbox_with_tooltip(label, value, tooltip)
        local changed, selected = imgui.checkbox(label, value)
        app.tooltips.capture(tooltip)
        return changed, selected
    end

    local function tree_with_tooltip(label, tooltip)
        local open = imgui.tree_node(label)
        app.tooltips.capture(tooltip)
        return open
    end

    -- Keep UI code here so the behavior files stay focused on gameplay logic.
    function self.draw()
        app.tooltips.reset()

        if not imgui.tree_node('Better Focus') then
            return
        end

        draw_keyboard_shortcut_setting_notice()

        local changed
        local selected

        changed, app.config.misc.tooltipHelpers = imgui.checkbox('Enable tooltip helpers', app.config.misc.tooltipHelpers)
        if changed then app.save_config() end

        changed, app.config.hotkeys.controllerSupport = imgui.checkbox('Controller support (limited/experimental)', app.config.hotkeys.controllerSupport)
        if changed then app.save_config() end

        if tree_with_tooltip('Weapon Draw Settings', "Governs whether focus mode should be enabled for configured weapons when drawn. Should apply to all ways you draw your weapon. Report if you find a situation that doesn't work.") then
            for _, weapon in ipairs(Config.weapon_order) do
                changed, app.config.weapons[weapon.key] = imgui.checkbox(weapon.label, app.config.weapons[weapon.key])
                if changed then app.save_config() end
            end
            imgui.new_line()
            imgui.tree_pop()
        end

        if tree_with_tooltip('Seikret Settings', 'Configures Seikret-related focus features.') then
            local mount_behavior = app.config.seikret.mountBehavior

            imgui.text('Mounting Behaviour')
            changed, selected = checkbox_with_tooltip('Default', mount_behavior == 'default', 'Keeps the previous focus state when mounting.')
            if changed then
                app.seikret.set_mount_behavior('default')
            end

            changed, selected = checkbox_with_tooltip('Always off', mount_behavior == 'alwaysOff', 'Always turns focus off when mounting.')
            if changed then
                app.seikret.set_mount_behavior(selected and 'alwaysOff' or 'default')
            end

            changed, selected = checkbox_with_tooltip('Always on', mount_behavior == 'alwaysOn', 'Always turns focus on when mounting.')
            if changed then
                app.seikret.set_mount_behavior(selected and 'alwaysOn' or 'default')
            end

            imgui.new_line()
            imgui.text('Other')
            changed, app.config.seikret.allowUnarmedFocusCall = checkbox_with_tooltip('Allow Seikret call from unarmed focus', app.config.seikret.allowUnarmedFocusCall, 'This fixes a vanilla design oversight and is recommended to be left on.')
            if changed then app.save_config() end

            imgui.new_line()
            imgui.tree_pop()
        end

        if imgui.tree_node('Misc Settings') then
            changed, app.config.misc.focusOffOnSheathe = imgui.checkbox('Focus off on sheathe', app.config.misc.focusOffOnSheathe)
            if changed then app.save_config() end

            changed, app.config.misc.sheatheOnDash = imgui.checkbox('Sheathe on dash', app.config.misc.sheatheOnDash)
            if changed then app.save_config() end
            if app.config.misc.sheatheOnDash then
                imgui.indent(18)
                changed, app.config.misc.autoDash = checkbox_with_tooltip('Auto dash', app.config.misc.autoDash, 'Useful if you like toggle-dash. Automatically toggles dash after the above two actions are complete. Works even if no key is bound to "Dash (Press Once)".')
                if changed then app.save_config() end
                imgui.unindent(18)
            end

            changed, app.config.misc.disableTargetCameraSnap = checkbox_with_tooltip('Disable focus/target camera snap', app.config.misc.disableTargetCameraSnap, 'To be used with disabled focus camera in game settings. This also disables the target camera snap-to-monster feature. Likely the only reason to use this is if you use lock-on as a signal for tracking monster HP in Hunter Pie.')
            if changed then app.save_config() end

            changed, app.config.misc.snapToMonsterOnBlock = checkbox_with_tooltip('Snap to monster on block', app.config.misc.snapToMonsterOnBlock, 'Force disables and enables focus mode so that the target camera snaps to the monster on block. Requires a monster to be locked on. Will put you in focus mode.')
            if changed then app.save_config() end

            imgui.new_line()
            imgui.tree_pop()
        end

        imgui.new_line()
        imgui.tree_pop()
    end

    return self
end

return M
