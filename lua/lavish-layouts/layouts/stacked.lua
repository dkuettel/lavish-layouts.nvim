---@class StackedLayout
local M = {}

---@param windows? integer[]
function M.arrange(windows)
    local view = vim.fn.winsaveview()

    -- windows = [top (most recent) of stack, next, next, ..., bottom (oldest) of stack]
    windows = windows or M.get_windows()

    -- stack windows so that oldest is the top most and newest is the bottom most
    for _, w in ipairs(windows) do
        vim.api.nvim_win_call(w, function()
            vim.cmd.wincmd("K")
        end)
    end

    -- make the current one use all the space, the others are squeezed
    vim.cmd.wincmd("_")

    vim.fn.winrestview(view)
end

function M.get_windows()
    return require("lavish-layouts.misc").get_windows("backward")
end

function M.new()
    local windows = M.get_windows()
    local view = vim.fn.winsaveview()
    vim.cmd.split()
    local window = vim.api.nvim_get_current_win()
    windows = { window, unpack(windows) }
    M.arrange(windows)
    vim.fn.winrestview(view) -- this should make the forked view exactly the same
end

function M.previous()
    -- TODO we want them to open right away, correct? should they restore the previous full view? no they are centered, or just top?
    -- for now I dont try to remember the full view geometry, and just do zt uniformly
    vim.cmd.wincmd("k")
    vim.cmd.wincmd("_")
    vim.wo.scrolloff = -1
    vim.cmd.normal { "zt", bang = true }
end

function M.next()
    vim.cmd.wincmd("j")
    vim.cmd.wincmd("_")
    vim.wo.scrolloff = -1
    vim.cmd.normal { "zt", bang = true }
end

function M.focus(window)
    local focus = window or vim.api.nvim_get_current_win()
    local windows = M.get_windows()
    if focus == windows[1] then
        focus = windows[2] or focus
    end
    windows = vim.tbl_filter(function(v)
        return v ~= focus
    end, windows)
    windows = { focus, unpack(windows) }
    vim.api.nvim_set_current_win(focus)
    M.arrange(windows)
    vim.api.nvim_set_current_win(focus)
end

function M.close()
    require("lavish-layouts").close_window_or_clear()
    M.arrange()
end

return M
