local U = require("lazy-events.utils")
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
        if type(v) == "string" or type(v) == "table" then
            U.map_event(k, v)
        else
            vim.notify(
                string.format("invalid wrapper event %s=%s", k, vim.inspect(v)),
                vim.log.levels.ERROR
            )
        end
    end
end

---Register `LazyProject` events.
---
---These events are fired on `DirChanged` events when the given glob expression
---logic matches. On startup, the project type is checked once after the
---`VeryLazy` event fires.
---@param items table<string, { any?: string[], all?: string[] }>
function M.register_projects(items)
    local id = "LazyProject"
    local prefix = id .. ":"
    U.map_event(id, "User", prefix .. "*")

    -- normalize to make detection easier later
    local projects = {}
    for k, v in pairs(items) do
        local label = prefix .. k
        U.map_event(label)

        local exprs = { any = v.any or {}, all = v.all or {} }
        if type(v) == "string" then
            table.insert(exprs.any, v)
        elseif type(v) == "table" then
            for _, expr in ipairs(v) do
                table.insert(exprs.any, expr)
            end
        end

        if #exprs.any == 0 and #exprs.all == 0 then
            vim.notify(
                "lazy-events: `" .. k .. "` does not provide any glob expressions (skipped)",
                vim.log.levels.WARN
            )
        else
            projects[prefix .. k] = exprs
        end
    end

    local function detect()
        local detected = {}
        for k, exprs in pairs(projects) do
            exprs.any = exprs.any or {}
            exprs.all = exprs.all or {}

            local is_match = U.glob_any(exprs.any)
            if #exprs.all > 0 then
                is_match = is_match or U.glob_all(exprs.all)
            end

            detected[k] = is_match or nil
        end

        for k, _ in pairs(detected) do
            fire(k)
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
        if not item.event then
            vim.notify("custom event `" .. k .. "` must specify `event`", vim.log.leels.ERROR)
        elseif not item.cond then
            vim.notify("custom event `" .. k .. "` must specify `cond`", vim.log.leels.ERROR)
        else
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
        end
    end
end

function M.init()
    if vim.g.lazy_events_did_setup then
        return
    end
    vim.g.lazy_events_did_setup = true

    local opts = vim.g.lazy_events_config or {}
    M.register_simple(opts.simple or {})
    M.register_projects(opts.projects or {})
    M.register_custom(opts.custom or {})
end

return M
