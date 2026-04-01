local M = {}

local function get_method(type_definition, method_names)
    if type(method_names) == "string" then
        return type_definition:get_method(method_names)
    end

    for _, method_name in ipairs(method_names) do
        local method = type_definition:get_method(method_name)
        if method then
            return method
        end
    end

    return nil
end

function M.create(app)
    local self = {}

    -- Hook lookup is one of the noisiest parts of REFramework scripting.
    -- Centralizing it here keeps feature files focused on behavior.
    function self.find_method(type_name, method_names)
        local type_definition = sdk.find_type_definition(type_name)
        if not type_definition then
            return nil
        end

        return get_method(type_definition, method_names)
    end

    function self.hook(type_name, method_names, pre_callback, post_callback)
        local method = self.find_method(type_name, method_names)
        if not method then
            return false
        end

        sdk.hook(method, pre_callback, post_callback)
        return true
    end

    -- Most gameplay hooks should only react to the master player's actions.
    function self.hook_owner(type_name, method_names, callback, post_callback)
        return self.hook(type_name, method_names, function(args)
            if app.game.object_owner_matches(args, type_name) then
                callback(args)
            end
        end, post_callback)
    end

    return self
end

return M
