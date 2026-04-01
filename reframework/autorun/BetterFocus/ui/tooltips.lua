local M = {}

function M.create(app)
    local self = {}

    local function wrap_text(text, max_chars)
        if not text then
            return text
        end

        max_chars = max_chars or 52
        local wrapped = {}
        for raw_line in string.gmatch(text, '[^\r\n]+') do
            local current = ''
            for word in string.gmatch(raw_line, '%S+') do
                local candidate = current == '' and word or (current .. ' ' .. word)
                if #candidate > max_chars and current ~= '' then
                    table.insert(wrapped, current)
                    current = word
                else
                    current = candidate
                end
            end
            if current ~= '' then
                table.insert(wrapped, current)
            end
        end
        return table.concat(wrapped, '\n')
    end

    -- UI items call capture() immediately after they are drawn. If that item is
    -- hovered, the tooltip system stores the text and position for this frame.
    function self.capture(text)
        if not app.config.misc.tooltipHelpers or not text or not imgui.is_item_hovered() then
            return
        end

        app.state.tooltip.text = wrap_text(text)

        local ok, mouse = pcall(function()
            return imgui.get_mouse()
        end)
        if ok and mouse then
            app.state.tooltip.position = Vector2f.new(mouse.x + 18, mouse.y - 12)
        else
            app.state.tooltip.position = nil
        end
    end

    function self.reset()
        app.state.tooltip.text = nil
        app.state.tooltip.position = nil
    end

    -- Tooltips are drawn in their own window so color, wrapping, and position
    -- can be controlled independently from the default REFramework tooltip.
    function self.draw()
        if not app.state.tooltip.text then
            return
        end

        if app.state.tooltip.position then
            imgui.set_next_window_pos(app.state.tooltip.position)
        end
        imgui.begin_window('##BetterFocusTooltip', true, 64)
        imgui.text_colored(app.state.tooltip.text, 0xFFFFBE78)
        imgui.end_window()
    end

    return self
end

return M
