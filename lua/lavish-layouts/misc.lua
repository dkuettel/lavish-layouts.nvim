local M = {}

local layouts = {
    main = require("lavish-layouts.layouts.main"),
    stacked = require("lavish-layouts.layouts.stacked"),
    dynamic = require("lavish-layouts.layouts.dynamic"),
}

-- TODO can i type the module return? or the interface?
---@param name? string
function M.maybe_get_layout(name)
    return layouts[name]
end

---@param name "main"|"stacked"|"dynamic"
function M.get_layout(name)
    return assert(M.maybe_get_layout(name))
end

return M
