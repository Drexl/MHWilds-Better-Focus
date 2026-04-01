local Config = require("BetterFocus.core.config")
local State = require("BetterFocus.core.state")
local Scheduler = require("BetterFocus.core.scheduler")
local Game = require("BetterFocus.core.game")
local Hooks = require("BetterFocus.core.hooks")
local Tooltips = require("BetterFocus.ui.tooltips")
local Menu = require("BetterFocus.ui.menu")
local dev_loaded, Dev = pcall(require, "BetterFocus.dev")
local Focus = require("BetterFocus.features.focus")
local Camera = require("BetterFocus.features.camera")
local Weapon = require("BetterFocus.features.weapon")
local Seikret = require("BetterFocus.features.seikret")
local Hotkeys = require("BetterFocus.features.hotkeys")

local M = {}

-- Build the Better Focus application once, then let REFramework drive it
-- through one frame loop and one UI loop. Keeping the wiring here makes the
-- feature files easier to read because they only contain behavior.
function M.init()
    local app = {
        config_module = Config,
        scheduler = Scheduler,
        config = Config.load(),
        state = State.new(),
    }

    app.game = Game.create(app)
    app.hooks = Hooks.create(app)
    app.tooltips = Tooltips.create(app)
    app.dev = dev_loaded and Dev.create(app) or {
        update = function() end,
        draw = function() end,
        trace_seikret = function() end,
    }
    app.focus = Focus.create(app)
    app.camera = Camera.create(app)
    app.weapon = Weapon.create(app)
    app.seikret = Seikret.create(app)
    app.hotkeys = Hotkeys.create(app)
    app.menu = Menu.create(app)

    app.save_config = function()
        Config.save(app.config)
    end

    app.camera.init()
    app.weapon.init()
    app.seikret.init()
    app.hotkeys.init()

    re.on_frame(function()
        app.scheduler.update(app.state)
        app.dev.update()
        app.camera.update()
        app.focus.update()
        app.seikret.update()
        app.hotkeys.update()
    end)

    re.on_draw_ui(function()
        app.menu.draw()
        app.tooltips.draw()
        app.dev.draw()
    end)
end

return M
