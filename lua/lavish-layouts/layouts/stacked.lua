---@class StackedLayout
local M = {}

---@param windows? integer[]
function M.arrange(windows)
    -- windows = [top (most recent) of stack, next, next, ..., bottom (oldest) of stack]
    local window = vim.api.nvim_get_current_win()
    windows = windows or M.get_windows()
    for _, w in ipairs(windows) do
        vim.api.nvim_set_current_win(w)
        vim.cmd.wincmd("K")
    end
    vim.api.nvim_set_current_win(window)
    vim.cmd.wincmd("_")
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
    vim.cmd.wincmd("k")
    vim.cmd.wincmd("_")
end

function M.next()
    vim.cmd.wincmd("j")
    vim.cmd.wincmd("_")
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
