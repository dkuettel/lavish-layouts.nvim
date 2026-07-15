local M = {}

---@class StackedLayout
M.StackedLayout = {}

---@return StackedLayout
function M.StackedLayout.make()
    return setmetatable({}, { __index = M.StackedLayout })
end

---@param windows? integer[]
function M.StackedLayout:arrange(windows)
    -- windows = [top (most recent) of stack, next, next, ..., bottom (oldest) of stack]
    local window = vim.api.nvim_get_current_win()
    windows = windows or self:get_windows()
    for _, w in ipairs(windows) do
        vim.api.nvim_set_current_win(w)
        vim.cmd.wincmd("K")
    end
    vim.api.nvim_set_current_win(window)
    vim.cmd.wincmd("_")
end

function M.StackedLayout.get_windows()
    return require("lavish-layouts").get_windows("backward")
end

function M.StackedLayout:new()
    local windows = self:get_windows()
    local view = vim.fn.winsaveview()
    vim.cmd.split()
    local window = vim.api.nvim_get_current_win()
    windows = { window, unpack(windows) }
    self:arrange(windows)
    vim.fn.winrestview(view) -- this should make the forked view exactly the same
end

function M.StackedLayout.previous()
    vim.cmd.wincmd("k")
    vim.cmd.wincmd("_")
end

function M.StackedLayout.next()
    vim.cmd.wincmd("j")
    vim.cmd.wincmd("_")
end

function M.StackedLayout:focus(window)
    local focus = window or vim.api.nvim_get_current_win()
    local windows = self:get_windows()
    if focus == windows[1] then
        focus = windows[2] or focus
    end
    windows = vim.tbl_filter(function(v)
        return v ~= focus
    end, windows)
    windows = { focus, unpack(windows) }
    vim.api.nvim_set_current_win(focus)
    self:arrange(windows)
    vim.api.nvim_set_current_win(focus)
end

function M.StackedLayout:close()
    require("lavish-layouts").close_window_or_clear()
    self:arrange()
end

return M
