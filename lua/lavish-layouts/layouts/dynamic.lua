---@class DynamicLayout
local M = {}

---@type "main"|"stacked"
local current = "main"

local function get()
    return require("lavish-layouts.misc").get_layout(current)
end

---@param windows? integer[] window handles in layout order
function M.arrange(windows)
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

    if not windows and M.layout ~= layout then
        windows = get().get_windows()
    end

    M.layout = layout

    get().arrange(windows)
end

---@return integer[] windows window handles in layout order
function M.get_windows()
    return get().get_windows()
end

function M.new()
    get().new()
end

function M.previous()
    get().previous()
end

function M.next()
    get().next()
end

function M.focus(window)
    get().focus(window)
end

function M.close()
    get().close()
end

return M
