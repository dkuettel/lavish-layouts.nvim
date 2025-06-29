local M = {}

M.layouts = { main = {}, stacked = {}, tiled = {} }

M.layout = M.layouts.main

function M.setup()
    local bg0_h = "#f9f5d7"
    vim.api.nvim_set_hl(0, "NormalCreated", { bg = bg0_h })
    vim.api.nvim_create_user_command("Layout", function(args)
        M.switch(M.layouts[args.fargs[1]])
    end, { nargs = 1, desc = "switch layout" })
end

function M.switch(layout)
    local windows = M.layout:get_windows()
    M.layout = layout
    M.layout:arrange(windows)
end

function M.new()
    M.layout:new()
    vim.wo.winhighlight = "Normal:NormalCreated"
    local function reset()
        -- TODO we might not be in the same window anymore, and or other things might have been in this value?
        vim.wo.winhighlight = ""
    end
    vim.defer_fn(reset, 250)
end

function M.next()
    M.layout:next()
end

function M.previous()
    M.layout:previous()
end

---@param window? integer window to focus on (defaults to current)
function M.focus(window)
    M.layout:focus(window)
end

function M.close()
    M.layout:close()
end

function M.close_and_delete()
    local buffer = vim.api.nvim_get_current_buf()
    M.layout:close()
    vim.api.nvim_buf_delete(buffer, { force = true })
end

local function close_window_or_clear()
    if #vim.api.nvim_tabpage_list_wins(0) > 1 then
        vim.api.nvim_win_close(0, true)
    else
        vim.cmd.enew()
    end
end

---@param windows? integer[] window handles in layout order
function M.layouts.main:arrange(windows)
    -- windows = [main, stack, stack, ...]
    local window = vim.api.nvim_get_current_win()
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
    vim.api.nvim_set_current_win(window)
end

---@return integer[] windows window handles in layout order
function M.layouts.main:get_windows()
    return vim.api.nvim_tabpage_list_wins(0)
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
        vim.cmd.wincmd("w")
        focus = vim.api.nvim_get_current_win()
    end
    windows = vim.tbl_filter(function(v)
        return v ~= focus
    end, windows)
    windows = { focus, unpack(windows) }
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
    return vim.fn.reverse(vim.api.nvim_tabpage_list_wins(0))
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
        vim.cmd.wincmd("w")
        focus = vim.api.nvim_get_current_win()
    end
    windows = vim.tbl_filter(function(v)
        return v ~= focus
    end, windows)
    windows = { focus, unpack(windows) }
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
    return vim.api.nvim_tabpage_list_wins(0)
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
        vim.cmd.wincmd("w")
        focus = vim.api.nvim_get_current_win()
    end
    windows = vim.tbl_filter(function(v)
        return v ~= focus
    end, windows)
    windows = { focus, unpack(windows) }
    self:arrange(windows)
    vim.api.nvim_set_current_win(focus)
end

function M.layouts.tiled:close()
    close_window_or_clear()
    self:arrange()
end

function M.switch_main()
    M.switch(M.layouts.main)
end

function M.switch_stacked()
    M.switch(M.layouts.stacked)
end

function M.switch_tiled()
    M.switch(M.layouts.tiled)
end

-- TODO remove?
function M.new_from_split()
    M.new(vim.cmd.split)
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
