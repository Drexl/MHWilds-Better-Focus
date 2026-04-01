local M = {}

local TRACE_SEIKRET = false

local function starts_with(value, prefix)
    return type(value) == "string" and type(prefix) == "string" and value:sub(1, #prefix) == prefix
end

function M.create(_app)
    local self = {}
    local last_trace_by_event = {}

    local function should_trace_event(event_name)
        return starts_with(event_name, "resolveSavedKey")
            or starts_with(event_name, "aceKey.on")
            or starts_with(event_name, "aceKey.off")
            or starts_with(event_name, "unarmedCallAttempt")
            or starts_with(event_name, "tryAllowUnarmedCall")
            or starts_with(event_name, "callPorterInput")
            or starts_with(event_name, "rideCallPorterJudge")
            or starts_with(event_name, "playerCallPorter")
            or starts_with(event_name, "weaponCallPorter")
            or starts_with(event_name, "hook.register")
    end

    function self.update()
    end

    function self.draw()
    end

    function self.trace_seikret(event_name, detail)
        if not TRACE_SEIKRET or not should_trace_event(event_name) then
            return
        end

        local message = detail ~= nil and detail ~= "" and (tostring(event_name) .. " " .. tostring(detail))
            or tostring(event_name)
        if last_trace_by_event[event_name] == message then
            return
        end

        last_trace_by_event[event_name] = message
        print(string.format("[BetterFocus][Seikret] %s", message))
    end

    return self
end

return M
