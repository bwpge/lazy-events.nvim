local M = {}

M.unpack = unpack or table.unpack

---@param id string
---@param event? string|string[]
---@param pattern? string|string[]
---@private
function M.map_event(id, event, pattern)
    if not event then
        event = "User"
    end
    if not pattern and event == "User" then
        pattern = id
    end

    local Event = require("lazy.core.handler.event")
    Event.mappings[id] = { id = id, event = event, pattern = pattern }
    Event.mappings["User " .. id] = Event.mappings[id]
end

---@param exprs string[]
---@return boolean
---@private
function M.glob_all(exprs)
    if #exprs == 0 then
        return true
    end

    for _, expr in pairs(exprs) do
        if #vim.fn.glob(expr) <= 0 then
            return false
        end
    end

    return true
end

---@param exprs string[]
---@return boolean
---@private
function M.glob_any(exprs)
    if #exprs == 0 then
        return false
    end

    for _, expr in pairs(exprs) do
        if #vim.fn.glob(expr) > 0 then
            return true
        end
    end

    return false
end

---@param exprs { any: string[], all: string[] }
function M.match_project(exprs)
    local is_match = M.glob_any(exprs.any)
    if #exprs.all > 0 then
        is_match = is_match or M.glob_all(exprs.all)
    end

    return is_match
end

---@param fmt string
---@param ... any
function M.warn(fmt, ...)
    vim.notify(string.format(fmt, ...), vim.log.levels.WARN, { title = "lazy-events" })
end

---@param fmt string
---@param ... any
function M.err(fmt, ...)
    vim.notify(string.format(fmt, ...), vim.log.levels.ERROR, { title = "lazy-events" })
end

return M
