local U = require("lazy-events.utils")
local M = {}

local KEY = "lazy_events_config"

M.options = {}

function M.setup()
    local opts = vim.g[KEY]
    if not opts or type(opts) ~= "table" then
        -- stylua: ignore
        U.warn( "no config table found (did you set `vim.g.%s` before calling `lazy.setup`?)", KEY)
        return
    end
    opts = opts or {}
    local t = {
        simple = {},
        projects = {},
        custom = {},
    }

    for k, v in pairs(opts.simple or {}) do
        if type(v) == "string" then
            t.simple[k] = { v }
        elseif type(v) == "table" then
            t.simple[k] = v
        else
            U.err("invalid simple event %s=%s", k, v)
        end
    end

    for k, v in pairs(opts.projects or {}) do
        if type(v) ~= "table" then
            U.err("invalid custom event %s=%s", k, vim.inspect(v))
        else
            local exprs = { any = v.any or {}, all = v.all or {} }
            for _, expr in ipairs(v) do
                table.insert(exprs.any, expr)
            end

            if #exprs.any == 0 and #exprs.all == 0 then
                U.warn("project `%s` does not provide any expressions (skipped)", k)
            else
                t.projects[k] = exprs
            end
        end
    end

    for k, v in pairs(opts.custom or {}) do
        if type(v) ~= "table" then
            U.err("invalid custom event %s=%s", k, vim.inspect(v))
        elseif not v.event then
            U.err("custom event `%s` must specify `event`", k)
        elseif not v.cond then
            U.err("custom event `%s` must specify `cond`", k)
        else
            t.custom[k] = v
        end
    end

    M.options = t
    vim.g[KEY] = nil
end

return M
