local M = {}

-- The scheduler runs delayed tasks from the main frame loop. This keeps all
-- timing logic in one place and avoids scattering tiny timers across files.
function M.schedule(state, delay_seconds, callback, tag)
    table.insert(state.scheduled, {
        runAt = os.clock() + delay_seconds,
        callback = callback,
        tag = tag,
    })
end

function M.cancel(state, tag)
    if not tag then
        return
    end

    for index = #state.scheduled, 1, -1 do
        if state.scheduled[index].tag == tag then
            table.remove(state.scheduled, index)
        end
    end
end

function M.update(state)
    local now = os.clock()
    for index = #state.scheduled, 1, -1 do
        local task = state.scheduled[index]
        if now >= task.runAt then
            table.remove(state.scheduled, index)
            pcall(task.callback)
        end
    end
end

return M
