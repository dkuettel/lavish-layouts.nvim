local M = {}

---@class DynamicLayout
---@field layout "main"|"stacked"
M.DynamicLayout = {}

---@return DynamicLayout
function M.DynamicLayout.make()
    return setmetatable({ layout = "main" }, { __index = M.DynamicLayout })
end

---@param windows? integer[] window handles in layout order
function M.DynamicLayout:arrange(windows)
    ---@type LayoutName
    local layout
    if vim.o.columns > 190 then
        layout = "main"
    else
        layout = "stacked"
    end

    vim.g.LayoutDesc = "dynamic/" .. layout

    -- TODO it doesnt work for nvim -o ... because we get called on the first file, then splits are applied, but we dont use the event
    -- that was on purpose... should we try the event?
    -- BufWinEnter, VimEnter is probably it, the Win* events could be useful
    -- see SessionLoadPost maybe too
    -- vim.notify("arranging for " .. vim.o.columns .. " columns -> " .. layout)

    if not windows and self.layout ~= layout then
        windows = require("lavish-layouts").layouts[self.layout]:get_windows()
    end

    self.layout = layout

    require("lavish-layouts").layouts[layout]:arrange(windows)
end

---@return integer[] windows window handles in layout order
function M.DynamicLayout:get_windows()
    return require("lavish-layouts").layouts[self.layout]:get_windows()
end

function M.DynamicLayout:new()
    require("lavish-layouts").layouts[self.layout]:new()
end

function M.DynamicLayout:previous()
    require("lavish-layouts").layouts[self.layout]:previous()
end

function M.DynamicLayout:next()
    require("lavish-layouts").layouts[self.layout]:next()
end

function M.DynamicLayout:focus(window)
    require("lavish-layouts").layouts[self.layout]:focus(window)
end

function M.DynamicLayout:close()
    require("lavish-layouts").layouts[self.layout]:close()
end

return M
