local M = {}

local layouts = {
    main = require("lavish-layouts.layouts.main"),
    stacked = require("lavish-layouts.layouts.stacked"),
    dynamic = require("lavish-layouts.layouts.dynamic"),
}

---@param name? string
---@return Layout?
function M.maybe_get_layout(name)
    return layouts[name]
end

---@param name LayoutName
---@return Layout
function M.get_layout(name)
    ---@diagnostic disable: unnecessary-assert
    local l = assert(M.maybe_get_layout(name))
    return l
end

return M
