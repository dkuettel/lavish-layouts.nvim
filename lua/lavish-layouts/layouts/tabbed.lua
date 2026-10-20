---@namespace lavish-layouts

---@class TabbedLayout
local M = {}

local misc = require("lavish-layouts.misc")

---@return DynamicLayout
local function get()
    return require("lavish-layouts.layouts.dynamic")
end

local function desc()
    vim.g.LayoutDesc = "tabbed"
end

-- TODO hm window list between main and tabbed, very difficult
-- should tabbed just accept whats there?
-- switching to tabbed otherwise would flatten all
-- switching from tabbed would merge it all
-- could be desired? hard to say
-- i guess for now just to see if we like it, doesnt have to be super consistent
-- if we do it, we lose the ability to make a new tab for another workstream, just like that
-- but i guess we could open a new nvim? just a bit bumpy with session saving
-- the main question is how to deal with context here?
-- on some level, this doesnt fit quite into the layouts interface anymore?
-- if good, just make it a different interface, dont force it into the old one?

---@param windows? integer[]
function M.arrange(windows)
    get().arrange(windows)
    desc()
end

function M.get_windows()
    -- TODO technically, this should be all tabs. but we keep the switching between tabbed and other layouts a bit inconsistent now
    get().get_windows()
end

local function highlight()
    local back = {
        window = vim.api.nvim_get_current_win(),
        cursorline = vim.wo.cursorline,
        winhighlight = vim.wo.winhighlight,
    }

    vim.wo.cursorline = true
    -- the last entry overwrites earlier entries, you cannot have a leading comma
    if vim.wo.winhighlight == "" then
        vim.wo.winhighlight = "CursorLine:CursorLinePickerJumps"
    else
        vim.wo.winhighlight = vim.wo.winhighlight .. ",CursorLine:CursorLinePickerJumps"
    end
    vim.cmd.redraw()

    local function reset()
        vim.wo[back.window].cursorline = back.cursorline
        vim.opt.winhighlight = back.winhighlight
    end

    vim.defer_fn(reset, 500)
end

function M.new()
    -- TODO is this the next tab up, or the very last always?
    vim.cmd("tab split")
    highlight()
end

function M.previous()
    -- vim.cmd("-tabnext")
    get().previous()
end

function M.next()
    -- vim.cmd("+tabnext")
    get().next()
end

---@param window? integer
---@diagnostic disable-next-line: unused
function M.focus(window)
    get().focus(window)
    desc()
end

function M.close()
    -- vim.cmd("tabclose")
    require("lavish-layouts").close_window_or_clear()
    get().arrange()
    desc()
end

function M.context()
    -- TODO for now it just makes the current window a context in the previous tab, and closes the current tab (even if there are more windows left)
    local buf = vim.api.nvim_get_current_buf()
    local view = vim.fn.winsaveview()
    vim.cmd("tabclose")
    local windows = get().get_windows()
    local win = misc.assert_integer(windows[1])
    vim.api.nvim_tabpage_set_win(0, win)
    get().new()
    -- TODO not sure what that does to jump history
    vim.api.nvim_win_set_buf(win, buf)
    vim.fn.winrestview(view)
    desc()
end

return M
