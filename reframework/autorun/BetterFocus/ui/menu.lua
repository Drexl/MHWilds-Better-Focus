local Config = require("BetterFocus.core.config")

local M = {}

function M.create(app)
    local self = {}

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

        local changed
        local selected

        changed, app.config.misc.tooltipHelpers = imgui.checkbox('Enable tooltip helpers', app.config.misc.tooltipHelpers)
        if changed then app.save_config() end

        changed, app.config.hotkeys.controllerSupport = imgui.checkbox('Controller support', app.config.hotkeys.controllerSupport)
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
                changed, app.config.misc.autoDash = checkbox_with_tooltip('Auto dash', app.config.misc.autoDash, 'Useful if you use toggle-dash. Sends your "Dash (Press Once)" key, or the custom key set in hotkey settings, after the above two actions are complete.')
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

        if tree_with_tooltip('Hotkey Settings', 'Configure which keyboard keys Better Focus listens for.') then
            imgui.text('Dash key source')
            changed, selected = checkbox_with_tooltip('System Dash keys', app.config.hotkeys.dashKeySource == 'system', 'Listens for the "Dash (Press Once)" and "Dash (Hold)" keys from game keybind settings. Will ONLY read the global melee and ranged weapon profiles, not keybind profiles for specific weapons. Use custom key setting to override.')
            if changed and selected then
                app.config.hotkeys.dashKeySource = 'system'
                app.save_config()
            end
            changed, selected = checkbox_with_tooltip('Custom key##DashKeySource', app.config.hotkeys.dashKeySource == 'custom', 'Press any keyboard key to bind it. Press ESC to cancel.')
            if changed and selected then
                app.config.hotkeys.dashKeySource = 'custom'
                app.save_config()
            end
            if app.config.hotkeys.dashKeySource == 'custom' then
                imgui.indent(18)
                imgui.text('Dash custom key:')
                imgui.same_line()
                local dash_button_label = app.state.binding.dashCustomKey and 'Binding...' or app.config.hotkeys.dashCustomKeyName
                if imgui.small_button(dash_button_label) then
                    app.state.binding.dashCustomKey = true
                end
                imgui.unindent(18)
            end

            imgui.new_line()
            imgui.text('Seikret Call key source')
            changed, selected = checkbox_with_tooltip('System Call Seikret keys', app.config.hotkeys.seikretKeySource == 'system', 'Listens for the "Call Seikret (Auto)" and "Call Seikret (Manual)" keys from game keybind settings. Will ONLY read the global melee and ranged weapon profiles, not keybind profiles for specific weapons. Use custom key settings to override.')
            if changed and selected then
                app.config.hotkeys.seikretKeySource = 'system'
                app.save_config()
            end
            changed, selected = checkbox_with_tooltip('Custom key##SeikretKeySource', app.config.hotkeys.seikretKeySource == 'custom', 'Press any keyboard key to bind it. Press ESC to cancel.')
            if changed and selected then
                app.config.hotkeys.seikretKeySource = 'custom'
                app.save_config()
            end
            if app.config.hotkeys.seikretKeySource == 'custom' then
                imgui.indent(18)
                imgui.text('Seikret custom key:')
                imgui.same_line()
                local seikret_button_label = app.state.binding.seikretCustomKey and 'Binding...' or app.config.hotkeys.seikretCustomKeyName
                if imgui.small_button(seikret_button_label) then
                    app.state.binding.seikretCustomKey = true
                end
                imgui.unindent(18)
            end

            imgui.tree_pop()
        end

        imgui.new_line()
        imgui.tree_pop()
    end

    return self
end

return M
