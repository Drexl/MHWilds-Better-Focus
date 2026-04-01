local Config = require("BetterFocus.core.config")

local M = {}
local MELEE_SHARED_KEYBOARD_CONFIG_INDEX = 1
local RANGED_SHARED_KEYBOARD_CONFIG_INDEX = 2
local DASH_PRESS_KEYDATA_INDEX = 4
local DASH_HOLD_KEYDATA_INDEX = 5
local MELEE_SEIKRET_AUTO_CALL_KEYDATA_INDEX = 37
local MELEE_SEIKRET_MANUAL_CALL_KEYDATA_INDEX = 38
local RANGED_SEIKRET_AUTO_CALL_KEYDATA_INDEX = 33
local RANGED_SEIKRET_MANUAL_CALL_KEYDATA_INDEX = 34
local RANGED_WEAPON_TYPES = {
    [11] = true,
    [12] = true,
    [13] = true,
}
local GAMEPAD_DPAD_UP = 1
local GAMEPAD_DPAD_DOWN = 2
local GAMEPAD_LS = 4096

local function get_array_item_safe(array, index)
    if not array then
        return nil
    end

    local ok, value = pcall(function()
        return array:get_Item(index)
    end)
    if ok then
        return value
    end

    local ok_elements, elements = pcall(function()
        return array:get_elements()
    end)
    if ok_elements and elements then
        return elements[index + 1]
    end

    return nil
end

local function get_field_safe(object, field_name)
    local ok, value = pcall(function()
        return object:get_field(field_name)
    end)
    if ok then
        return value
    end
    return nil
end

local function try_call(object, method_name, ...)
    if not object then
        return nil
    end

    local ok, result = pcall(function(...)
        return object:call(method_name, ...)
    end, ...)
    if ok then
        return result
    end
    return nil
end

local function normalize_numeric_value(value)
    if type(value) == "number" then
        return value
    end

    local ok_int64, int64_value = pcall(function()
        return sdk.to_int64(value)
    end)
    if ok_int64 and type(int64_value) == "number" then
        return int64_value
    end

    local ok_number, numeric_value = pcall(function()
        return tonumber(value)
    end)
    if ok_number and type(numeric_value) == "number" then
        return numeric_value
    end

    return nil
end

-- Different action objects expose their owning character in slightly different
-- ways, so this helper checks the common patterns used by Wilds.
local function get_action_owner_character(object)
    if not object then
        return nil
    end

    local via_method = try_call(object, "get_Chara")
    if via_method then
        return via_method
    end

    local backing_field = get_field_safe(object, "<Chara>k__BackingField")
    if backing_field then
        return backing_field
    end

    local character_field = get_field_safe(object, "_Character")
    if character_field then
        return character_field
    end

    return nil
end

function M.create(app)
    local self = {}
    local check_command_result_method = nil
    local application_is_active_method = nil

    local function get_main_pad_from_manager()
        local pad_manager = sdk.get_managed_singleton("ace.PadManager")
        if not pad_manager then
            return nil
        end

        local main_pad = try_call(pad_manager, "get_MainPad")
        if main_pad then
            return main_pad
        end

        main_pad = try_call(pad_manager, "get_MainPad1008020")
        if main_pad then
            return main_pad
        end

        return get_field_safe(pad_manager, "_MainPad")
    end

    local function get_main_pad_device_from_manager()
        local main_pad = get_main_pad_from_manager()
        if not main_pad then
            return nil
        end

        pcall(function()
            main_pad:call("updateInputFromDevice")
        end)

        local device = get_field_safe(main_pad, "_Device")
        if device then
            return device
        end

        return nil
    end

    function self.get_player_character()
        local cached = app.state.caches.playerCharacter
        if cached and cached:get_address() ~= 0 then
            return cached
        end

        local player_manager = sdk.get_managed_singleton("app.PlayerManager")
        if not player_manager then
            return nil
        end

        local master_player = player_manager:getMasterPlayer()
        if not master_player then
            return nil
        end

        local player_character = master_player:get_Character()
        app.state.caches.playerCharacter = player_character
        return player_character
    end

    function self.get_player_controller()
        local cached = app.state.caches.playerController
        if cached and cached:get_address() ~= 0 then
            return cached
        end

        local player_manager = sdk.get_managed_singleton("app.PlayerManager")
        if not player_manager then
            return nil
        end

        local master_player = player_manager:getMasterPlayer()
        if not master_player then
            return nil
        end

        local entity = master_player:get_Entity()
        if not entity or not entity._ControllerEntityHolder then
            return nil
        end

        local controller = entity._ControllerEntityHolder:get_Master()
        app.state.caches.playerController = controller
        return controller
    end

    function self.get_player_sub_action_controller()
        local player_character = self.get_player_character()
        if not player_character then
            return nil
        end

        return try_call(player_character, "get_SubActionController")
    end

    function self.get_player_operation()
        local controller = self.get_player_controller()
        return controller and controller._Operation or nil
    end

    function self.get_player_command_result()
        local operation = self.get_player_operation()
        return operation and operation._CommandResult or nil
    end

    function self.get_move_input_magnitude()
        local command_result = self.get_player_command_result()
        if not command_result then
            return nil
        end

        return normalize_numeric_value(get_field_safe(command_result, "_LStickMagnitude"))
    end

    function self.get_camera_manager()
        local cached = app.state.caches.cameraManager
        if cached and cached:get_address() ~= 0 then
            return cached
        end

        local camera_manager = sdk.get_managed_singleton("app.CameraManager")
        app.state.caches.cameraManager = camera_manager
        return camera_manager
    end

    function self.get_ace_keyboard()
        local cached = app.state.caches.aceKeyboard
        if cached then
            return cached
        end

        local keyboard_manager = sdk.get_managed_singleton("ace.MouseKeyboardManager")
        if not keyboard_manager then
            return nil
        end

        local keyboard = try_call(keyboard_manager, "get_MainMouseKeyboard")
        if not keyboard then
            return nil
        end

        app.state.caches.aceKeyboard = keyboard
        return keyboard
    end

    function self.get_gamepad_button_state()
        if not app.config.hotkeys.controllerSupport then
            return nil
        end

        local gamepad = get_main_pad_device_from_manager()
        if not gamepad then
            return nil
        end

        local ok_managed, managed_button = pcall(function()
            return gamepad:call("get_Button")
        end)
        if ok_managed then
            local normalized = normalize_numeric_value(managed_button)
            if type(normalized) == "number" then
                return normalized
            end
        end

        return nil
    end

    function self.is_gamepad_button_down(button_mask)
        local button_down = self.get_gamepad_button_state()
        if type(button_down) ~= "number" then
            return false
        end

        if button_down == button_mask then
            return true
        end

        return (button_down & button_mask) ~= 0
    end

    function self.get_shared_gameplay_config_index()
        local weapon_type = self.get_weapon_type_id()
        if RANGED_WEAPON_TYPES[weapon_type] == true then
            return RANGED_SHARED_KEYBOARD_CONFIG_INDEX
        end

        return MELEE_SHARED_KEYBOARD_CONFIG_INDEX
    end

    function self.get_shared_keydata_index(melee_index, ranged_index)
        local weapon_type = self.get_weapon_type_id()
        if RANGED_WEAPON_TYPES[weapon_type] == true then
            return ranged_index
        end

        return melee_index
    end

    function self.get_player_camera()
        local camera_manager = self.get_camera_manager()
        return camera_manager and camera_manager._MasterPlCamera or nil
    end

    function self.get_camera_mini_components()
        local player_camera = self.get_player_camera()
        return player_camera and player_camera._MiniComponents or nil
    end

    function self.get_sight_controller()
        local controller = self.get_player_controller()
        return controller and controller._SightController or nil
    end

    function self.is_camera_targeting()
        local player_camera = self.get_player_camera()
        local targeting = try_call(player_camera, "get_IsUseTargeting()")
        return targeting == true
    end

    -- The controller keeps the authoritative aim toggles that Better Focus
    -- writes when it turns focus on. Those toggles survive better than camera
    -- targeting checks for restore logic and manual off/on detection.
    function self.is_focus_active()
        local controller = self.get_player_controller()
        if not controller then
            return false
        end

        return controller._ToggleAimPc == true
            or controller._ToggleAimPad == true
            or controller._ToggleAimShooting == true
    end

    -- Wilds already exposes whether the application is currently active. Using
    -- the engine's own flag is more reliable here than Lua FFI, which is not
    -- available in every REFramework environment.
    function self.is_game_window_focused()
        if not application_is_active_method then
            local application_type = sdk.find_type_definition("via.Application")
            if not application_type then
                return nil
            end

            application_is_active_method = application_type:get_method("get_Active")
            if not application_is_active_method then
                return nil
            end
        end

        local ok, result = pcall(function()
            return application_is_active_method:call(nil)
        end)
        if ok then
            return result == true
        end

        return nil
    end

    function self.is_weapon_drawn()
        local character_draw = try_call(self.get_player_character(), "get_IsDraw()")
        if character_draw ~= nil then
            return character_draw
        end

        local controller_draw = try_call(self.get_player_controller(), "get_IsDraw()")
        return controller_draw == true
    end

    function self.get_overwrite_weapon_on_off_state()
        local player_character = self.get_player_character()
        if not player_character then
            return nil
        end

        return normalize_numeric_value(get_field_safe(player_character, "_OverwriteWeaponOnOffState"))
    end

    function self.get_weapon_type_id()
        local player_character = self.get_player_character()
        if not player_character then
            return nil
        end

        return try_call(player_character, "get_WeaponType")
    end

    function self.get_weapon_key()
        local type_id = self.get_weapon_type_id()
        if type_id == nil then
            return nil
        end

        return Config.weapon_keys_by_type[type_id]
    end

    function self.is_ranged_weapon()
        local type_id = self.get_weapon_type_id()
        return RANGED_WEAPON_TYPES[type_id] == true
    end

    function self.is_weapon_enabled()
        local weapon_key = self.get_weapon_key()
        if not weapon_key then
            return false
        end

        return app.config.weapons[weapon_key] == true
    end

    function self.try_get_managed_object(argument)
        if argument == nil then
            return nil
        end

        local ok, object = pcall(function()
            return sdk.to_managed_object(argument)
        end)
        if ok then
            return object
        end
        return nil
    end

    -- Many hooks fire for more than one actor. This check keeps feature logic
    -- focused on the master player.
    function self.object_owner_matches(args, type_name)
        if not args or args[2] == nil then
            return false
        end

        local owner = self.try_get_managed_object(args[2])
        if not owner then
            return false
        end

        local type_definition = owner:get_type_definition()
        if not type_definition then
            return false
        end

        local type_matches = type_definition:get_full_name() == type_name or type_definition:is_a(type_name)
        return type_matches and get_action_owner_character(owner) == self.get_player_character()
    end

    function self.get_action_id(category, index)
        local action_id_type = sdk.find_type_definition("ace.ACTION_ID")
        local result = ValueType.new(action_id_type)
        sdk.set_native_field(result, action_id_type, "_Category", category)
        sdk.set_native_field(result, action_id_type, "_Index", index)
        return result
    end

    function self.request_player_sub_action(category, index)
        local controller = self.get_player_sub_action_controller()
        if not controller then
            return false
        end

        local action_id = self.get_action_id(category, index)
        local ok, result = pcall(function()
            return controller:call("changeActionRequest(ace.ACTION_ID)", action_id)
        end)
        if ok then
            return result == true
        end

        return false
    end

    -- Judge hooks receive a command-work object. This helper asks the game
    -- whether a specific command result is currently valid.
    function self.check_command_result(command_work, option, command_type)
        if not check_command_result_method then
            local type_definition = sdk.find_type_definition("app.PlayerUtil")
            if not type_definition then
                return nil
            end
            check_command_result_method = type_definition:get_method("checkCommandResult(app.cPlayerBTableCommandWork, app.HunterDef.BTABLE_COMMAND_OPTION, app.PlayerCommand.TYPE)")
        end

        if not check_command_result_method or not command_work then
            return nil
        end

        local ok, result = pcall(function()
            return check_command_result_method:call(nil, command_work, option, command_type)
        end)
        if ok then
            return result
        end
        return nil
    end

    function self.get_keyboard_config_list()
        local save_data_manager = sdk.get_managed_singleton("app.SaveDataManager")
        local system_save = try_call(save_data_manager, "get_SystemSaveData")
        local system_common = system_save and get_field_safe(system_save, "_SystemCommon") or nil
        return system_common and get_field_safe(system_common, "_KeyConfigKeyboard") or nil
    end

    function self.resolve_shared_main_key(config_index, keydata_index)
        local keyboard_config_list = self.get_keyboard_config_list()
        local key_configs = keyboard_config_list and get_field_safe(keyboard_config_list, "_KeyCon") or nil
        if type(config_index) ~= "number" or config_index < 0 then
            return nil
        end

        local active_config = self.try_get_managed_object(get_array_item_safe(key_configs, config_index))
        local key_data = active_config and get_field_safe(active_config, "_KeyData") or nil
        local key_entry = self.try_get_managed_object(get_array_item_safe(key_data, keydata_index))
        local ace_key_index = key_entry and get_field_safe(key_entry, "MainKey") or nil

        if type(ace_key_index) == "number" and ace_key_index >= 0 then
            return ace_key_index
        end

        return nil
    end

    function self.resolve_shared_main_keys(keydata_indices)
        local config_index = self.get_shared_gameplay_config_index()
        local keys = {}
        local seen = {}

        for _, keydata_index in ipairs(keydata_indices) do
            local ace_key_index = self.resolve_shared_main_key(config_index, keydata_index)
            if type(ace_key_index) == "number" and ace_key_index >= 0 and not seen[ace_key_index] then
                seen[ace_key_index] = true
                keys[#keys + 1] = ace_key_index
            end
        end

        return keys
    end

    function self.get_system_dash_press_key_index()
        local config_index = self.get_shared_gameplay_config_index()
        local keydata_index = self.get_shared_keydata_index(DASH_PRESS_KEYDATA_INDEX, DASH_PRESS_KEYDATA_INDEX)
        return self.resolve_shared_main_key(config_index, keydata_index)
    end

    function self.get_system_seikret_key_indices()
        local auto_index = self.get_shared_keydata_index(
            MELEE_SEIKRET_AUTO_CALL_KEYDATA_INDEX,
            RANGED_SEIKRET_AUTO_CALL_KEYDATA_INDEX
        )
        local manual_index = self.get_shared_keydata_index(
            MELEE_SEIKRET_MANUAL_CALL_KEYDATA_INDEX,
            RANGED_SEIKRET_MANUAL_CALL_KEYDATA_INDEX
        )
        return self.resolve_shared_main_keys({ auto_index, manual_index })
    end

    function self.is_custom_key_down(virtual_key_code)
        if type(virtual_key_code) ~= "number" then
            return false
        end

        local ok, is_down = pcall(function()
            return reframework:is_key_down(virtual_key_code)
        end)
        return ok and is_down == true
    end

    function self.is_any_ace_key_down(ace_key_indices)
        local keyboard = self.get_ace_keyboard()
        if not keyboard then
            return false
        end

        for _, ace_key_index in ipairs(ace_key_indices) do
            local is_down = try_call(keyboard, "isOn", ace_key_index)
            if is_down == true then
                return true
            end
        end

        return false
    end

    function self.get_dash_input_state()
        local state = {
            systemPress = false,
            systemHold = false,
            custom = false,
            controllerPress = false,
        }

        if app.config.hotkeys.dashKeySource == "custom" then
            state.custom = self.is_custom_key_down(app.config.hotkeys.dashCustomKey)
            if app.config.hotkeys.controllerSupport then
                state.controllerPress = self.is_gamepad_button_down(GAMEPAD_LS)
            end
            state.any = state.custom or state.controllerPress
            return state
        end

        local keyboard = self.get_ace_keyboard()
        if keyboard then
            local press_key_index = self.get_system_dash_press_key_index()
            if type(press_key_index) == "number" then
                state.systemPress = try_call(keyboard, "isOn", press_key_index) == true
            end

            local hold_key_index = self.resolve_shared_main_key(
                self.get_shared_gameplay_config_index(),
                self.get_shared_keydata_index(DASH_HOLD_KEYDATA_INDEX, DASH_HOLD_KEYDATA_INDEX)
            )
            if type(hold_key_index) == "number" then
                state.systemHold = try_call(keyboard, "isOn", hold_key_index) == true
            end
        end

        if app.config.hotkeys.controllerSupport then
            state.controllerPress = self.is_gamepad_button_down(GAMEPAD_LS)
        end

        state.any = state.systemPress or state.systemHold or state.controllerPress
        return state
    end

    function self.is_seikret_call_key_down()
        local controller_down = false
        if app.config.hotkeys.controllerSupport then
            controller_down = self.is_gamepad_button_down(GAMEPAD_DPAD_UP) or self.is_gamepad_button_down(GAMEPAD_DPAD_DOWN)
        end

        if app.config.hotkeys.seikretKeySource == "custom" then
            return self.is_custom_key_down(app.config.hotkeys.seikretCustomKey) or controller_down
        end

        return self.is_any_ace_key_down(self.get_system_seikret_key_indices()) or controller_down
    end

    return self
end

return M
