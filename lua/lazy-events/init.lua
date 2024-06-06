local U = require("lazy-events.utils")
local Config = require("lazy-events.config")
local M = {}

local group = vim.api.nvim_create_augroup("lazy_events_nvim", { clear = true })

---@param name string
---@param data any
---@private
local function fire(name, data)
    vim.api.nvim_exec_autocmds("User", {
        pattern = name,
        modeline = false,
        data = data,
    })
end

---Register simple event wrappers.
---@param items table<string, string|string[]>
function M.register_simple(items)
    for k, v in pairs(items) do
        U.map_event(k, v)
    end
end

---Register `LazyProject` events.
---
---These events are fired on `DirChanged` events when the given glob expression
---logic matches. On startup, the project type is checked once after the
---`VeryLazy` event fires.
---@param items table<string, { any: string[], all: string[] }>
function M.register_projects(items)
    local id = "LazyProject"
    local prefix = id .. ":"
    U.map_event(id, "User", prefix .. "*")

    for k, _ in pairs(items) do
        U.map_event(prefix .. k)
    end

    local function detect()
        for k, v in pairs(items) do
            if U.match_project(v) then
                fire(prefix .. k)
            end
        end
    end

    vim.api.nvim_create_autocmd({ "DirChanged" }, {
        group = group,
        callback = detect,
        desc = "lazy-events: detect project",
    })

    -- make sure we check at least once after lazy finishes startup
    vim.api.nvim_create_autocmd({ "User" }, {
        group = group,
        pattern = "VeryLazy",
        once = true,
        callback = detect,
        desc = "lazy-events: detect project (once on VeryLazy)",
    })
end

---@alias CustomEvent { event: string|string[], cond: fun(e: table):(boolean), pattern?: string|string[], once?: boolean }

---Register custom events.
---@param items table<string, CustomEvent>
function M.register_custom(items)
    for k, item in pairs(items) do
        U.map_event(k)
        vim.api.nvim_create_autocmd(item.event, {
            group = group,
            once = item.once,
            pattern = item.pattern,
            desc = "lazy-events: custom event `" .. k .. "`",
            callback = function(e)
                if item.cond(e) == true then
                    fire(k)
                end
            end,
        })
        -- end
    end
end

function M.init()
    if vim.g.lazy_events_did_setup then
        return
    end
    vim.g.lazy_events_did_setup = true
    Config.setup()

    local opts = Config.options
    M.register_simple(opts.simple)
    M.register_projects(opts.projects)
    M.register_custom(opts.custom)
end

return M
