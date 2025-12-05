local M = {}

-- NOTE when a window goes to the stack or "background", it usually gets smaller
-- the current behaviour is so that the view in that window shifts so that you
-- still see the cursor location, together with scrolloff that usually centers
-- the current line in that small view. when you later take that window again
-- back to main, there is no data to really exactly restore the view you had
-- before backgrounding it, and its then centered again. could be unintuitive?

---@alias LayoutName "main" | "stacked" | "tiled"

-- TODO should type the any part here, classes?
---@type table<LayoutName, any>
M.layouts = { main = {}, stacked = {}, tiled = {} }

-- NOTE we have one global layout (saved as a name in vim.g.Layout)
-- that is applied to all tabs, we could also use vim.t.Layout and have it per tab
-- (we also then need to make sure sessions save it)

-- TODO now with a global layout, we should probably use events like TabEnter TabLeave TabNew TabNewEntered TabClosed
-- similar to VimResized to relayout in the right moments? or leave it to the user on his tab switch mappings?

function M.setup()
    local bg0_h = "#f9f5d7"
    vim.opt.sessionoptions:append("globals") -- NOTE to restore the layout when loading session
    vim.g.Layout = vim.g.Layout or "main"
    vim.api.nvim_set_hl(0, "NormalCreated", { bg = bg0_h })
    vim.api.nvim_create_user_command("Layout", function(args)
        M.switch(M.layouts[args.fargs[1]])
    end, { nargs = 1, desc = "switch layout" })
    -- TODO if you :bd yourself, then layouts wont know, we could work with events, if really needed
    -- but i cant find a good event for that, plus events have a tendency to make layouts do double or triple work
    vim.api.nvim_create_autocmd({ "VimResized" }, {
        desc = "lavish-layouts",
        callback = function()
            get_layout():arrange()
        end,
        nested = true,
    })
end

---@param name? LayoutName
---@return any
function get_layout(name)
    if name == nil then
        ---@type LayoutName
        name = vim.g.Layout or "main"
    end
    return M.layouts[name]
end

-- TODO when is a session loaded? after we set the default with this or before?
---@param name LayoutName
function M.switch(name)
    local windows = get_layout():get_windows()
    vim.g.Layout = name
    get_layout():arrange(windows)
end

function M.new()
    get_layout():new()
    vim.wo.winhighlight = "Normal:NormalCreated"
    local function reset()
        -- TODO we might not be in the same window anymore, and or other things might have been in this value?
        vim.wo.winhighlight = ""
    end
    vim.defer_fn(reset, 250)
end

function M.next()
    get_layout():next()
end

function M.previous()
    get_layout():previous()
end

---@param window? integer window to focus on (defaults to current), and if already focused, it will flip with the secondary focused window
function M.focus(window)
    get_layout():focus(window)
end

function M.close()
    get_layout():close()
end

--close the window and delete the buffer, similar to :bd
--but open "e ." (maybe with oil), if last buffer
function M.close_and_delete()
    vim.api.nvim_buf_delete(0, { force = true })
    if vim.api.nvim_buf_get_name(0) == "" then
        vim.cmd([[:e .]])
    end
    get_layout():arrange()
end

local function close_window_or_clear()
    if #vim.api.nvim_list_tabpages() > 1 or #vim.api.nvim_tabpage_list_wins(0) > 1 then
        vim.api.nvim_win_close(0, true)
    else
        vim.cmd([[:e .]])
    end
end

---@param order "forward" | "backward"
---@return integer[] windows window handles without floating windows
local function get_windows(order)
    local windows
    if order == "forward" then
        windows = vim.api.nvim_tabpage_list_wins(0)
    elseif order == "backward" then
        windows = vim.fn.reverse(vim.api.nvim_tabpage_list_wins(0))
    else
        assert(false)
    end
    windows = vim.tbl_filter(function(window)
        local config = vim.api.nvim_win_get_config(window)
        return config.relative == "" -- this means it is not a floating window
    end, windows)
    return windows
end

---@param windows? integer[] window handles in layout order
function M.layouts.main:arrange(windows)
    -- windows = [main, stack, stack, ...]
    local focus = vim.api.nvim_get_current_win()
    windows = windows or self:get_windows()
    for i, w in ipairs(windows) do
        if i > 1 then
            vim.api.nvim_set_current_win(w)
            vim.cmd.wincmd("J")
        end
    end
    -- TODO we set focuses, could that interfere?
    vim.api.nvim_set_current_win(windows[1])
    vim.cmd.wincmd("H")
    -- TODO make this relative to current terminal size, and how to re-arrange when things change?
    vim.cmd.wincmd("10>")
    vim.api.nvim_set_current_win(focus)
end

---@return integer[] windows window handles in layout order
function M.layouts.main:get_windows()
    return get_windows("forward")
end

function M.layouts.main:new()
    local stack = self:get_windows()
    vim.cmd.split()
    local main = vim.api.nvim_get_current_win()
    local windows = { main, unpack(stack) }
    self:arrange(windows)
end

function M.layouts.main:previous()
    local focus = vim.api.nvim_get_current_win()
    local windows = vim.api.nvim_tabpage_list_wins(0)
    if focus == windows[1] then
        return
    end
    vim.cmd.wincmd("W")
end

function M.layouts.main:next()
    local focus = vim.api.nvim_get_current_win()
    local windows = vim.api.nvim_tabpage_list_wins(0)
    if focus == windows[#windows] then
        return
    end
    vim.cmd.wincmd("w")
end

function M.layouts.main:focus(window)
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

function M.layouts.main:close()
    close_window_or_clear()
    self:arrange()
end

function M.layouts.stacked:arrange(windows)
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

function M.layouts.stacked:get_windows()
    return get_windows("backward")
end

function M.layouts.stacked:new(make)
    local windows = self:get_windows()
    vim.cmd.split()
    local window = vim.api.nvim_get_current_win()
    windows = { window, unpack(windows) }
    self:arrange(windows)
end

function M.layouts.stacked:previous()
    vim.cmd.wincmd("k")
    vim.cmd.wincmd("_")
end

function M.layouts.stacked:next()
    vim.cmd.wincmd("j")
    vim.cmd.wincmd("_")
end

function M.layouts.stacked:focus(window)
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

function M.layouts.stacked:close()
    close_window_or_clear()
    self:arrange()
end

function M.layouts.tiled:arrange(windows)
    -- windows = [main, side, stack, stack, ....]
    local window = vim.api.nvim_get_current_win()
    windows = windows or self:get_windows()
    for i, w in ipairs(windows) do
        if i == 1 then
            vim.api.nvim_set_current_win(w)
            vim.cmd.wincmd("L")
        elseif i == 3 then
            vim.api.nvim_set_current_win(w)
            vim.cmd.wincmd("J")
        else
            vim.api.nvim_win_set_config(w, { win = windows[i - 1], vertical = true, split = "right" })
        end
    end
    vim.cmd.wincmd("=")
    if #windows > 2 then
        vim.cmd.wincmd("5-")
    end
    vim.api.nvim_set_current_win(window)
end

function M.layouts.tiled:get_windows()
    return get_windows("forward")
end

function M.layouts.tiled:new(make)
    local windows = self:get_windows()
    vim.cmd.split()
    local window = vim.api.nvim_get_current_win()
    windows = { window, unpack(windows) }
    self:arrange(windows)
end

function M.layouts.tiled:previous()
    local focus = vim.api.nvim_get_current_win()
    local windows = vim.api.nvim_tabpage_list_wins(0)
    if focus == windows[1] then
        return
    end
    vim.cmd.wincmd("W")
end

function M.layouts.tiled:next()
    local focus = vim.api.nvim_get_current_win()
    local windows = vim.api.nvim_tabpage_list_wins(0)
    if focus == windows[#windows] then
        return
    end
    vim.cmd.wincmd("w")
end

function M.layouts.tiled:focus(window)
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

function M.layouts.tiled:close()
    close_window_or_clear()
    self:arrange()
end

function M.switch_main()
    M.switch("main")
end

function M.switch_stacked()
    M.switch("stacked")
end

function M.switch_tiled()
    M.switch("tiled")
end

function M.new_from_split()
    M.new()
end

-- TODO but how to make it when the picker is not a file? ah wait always files, but the line?
-- TODO remove, right?
function M.new_from_picker(picker, opts)
    local success, _ = pcall(require, "telescope")
    if not success then
        vim.cmd.echomsg([["no telescope"]])
        return
    end
    if type(picker) == "string" then
        picker = require("telescope.builtin")[picker]
    end
    opts = opts or {}
    local actions = require("telescope.actions")
    local state = require("telescope.actions.state")
    opts = vim.tbl_deep_extend("force", opts, {
        -- TODO see again, we just want to overwrite the default action, whatever it is
        attach_mappings = function(_, map)
            map("i", "<enter>", function(prompt_bufnr)
                local selection = state.get_selected_entry()
                actions.close(prompt_bufnr)
                local function make()
                    -- TODO sometimes we want to jump to a line too
                    vim.cmd.split(selection[1])
                end
                M.new(make)
            end)
            return true
        end,
    })
    picker(opts)
end

return M
