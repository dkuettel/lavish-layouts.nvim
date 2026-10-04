---@namespace lavish-layouts

---@class MainLayout
local M = {}

---@param windows integer[]
---@return table<integer,vim.fn.winsaveview.ret>
local function get_all_views(windows)
    local views = {}
    for i = 1, #windows do
        local w = windows[i]
        views[w] = vim.api.nvim_win_call(w, vim.fn.winsaveview)
    end
    return views
end

---@param views table<integer,vim.fn.winsaveview.ret>
local function apply_all_views(views)
    for win, view in pairs(views) do
        vim.api.nvim_win_call(win, function()
            vim.fn.winrestview(view)
        end)
    end
end

---@param windows integer[]
---@return vim.fn.winlayout.ret
local function get_target_winlayout(windows)
    local col = {}
    for i, w in ipairs(windows) do
        if i > 1 then
            table.insert(col, { "leaf", w })
        end
    end
    return {
        "row",
        {
            { "leaf", windows[1] },
            { "col", col },
        },
    }
end

---@param windows integer[]
local function contruct_target_winlayout(windows)
    for i, w in ipairs(windows) do
        if i > 1 then
            vim.api.nvim_win_call(w, function()
                pcall(vim.cmd.wincmd, "J") -- this can fail when there is not enough space
            end)
        end
    end
    if windows[1] then
        vim.api.nvim_win_call(windows[1], function()
            vim.cmd.wincmd("H")
        end)
    end
end

---@param windows integer[]
local function resize_target_winlayout(windows)
    local current = vim.api.nvim_get_current_win()
    if current == windows[1] then
        local passed = false
        for i = 1, #windows do
            vim.api.nvim_win_call(windows[i], function()
                if i == 1 then
                    vim.wo.winfixheight = false
                elseif i == 2 then
                    vim.wo.winfixheight = false
                    vim.cmd.resize(999)
                    if not vim.w.is_context then
                        passed = true
                    end
                elseif i >= 3 then
                    if vim.w.is_context and not passed then
                        vim.wo.winfixheight = false
                        vim.cmd.resize(999)
                    else
                        vim.wo.winfixheight = true
                        vim.cmd.resize(1)
                        passed = true
                    end
                end
            end)
        end
        vim.cmd("vertical wincmd =")
    else
        vim.api.nvim_win_call(current, function()
            vim.cmd.wincmd("_")
        end)
    end
end

-- TODO if new_window is a subset of all windows, or not from the same tab, i think arrange will mess things up
---@param new_windows? integer[] window handles in layout order: main, stack, stack, ...
function M.arrange(new_windows)
    local windows = new_windows or M.get_windows() -- order: main, stack, stack, ...
    local views = get_all_views(windows)

    local wl_have = vim.fn.winlayout()
    local wl_target = get_target_winlayout(windows)
    if not vim.deep_equal(wl_have, wl_target) then
        contruct_target_winlayout(windows)
    end

    resize_target_winlayout(windows)

    -- TODO seems like just re-applying all saved views works okay, even for the squeezed windows?
    apply_all_views(views)
end

---@return integer[] windows window handles in layout order: main, stack, stack, ...
function M.get_windows()
    return require("lavish-layouts.misc").get_windows("forward")
end

function M.new()
    local windows = M.get_windows()
    local original = vim.api.nvim_get_current_win()
    local view = vim.fn.winsaveview()
    vim.cmd.split()
    local new = vim.api.nvim_get_current_win()
    table.insert(windows, 1, new)
    M.arrange(windows)
    vim.fn.winrestview(view)
    vim.api.nvim_win_call(original, function()
        vim.fn.winrestview(view)
    end)
end

function M.previous()
    -- TODO in nvim 0.12 I think nvim_tabpage_list_wins is bugged, it returns all windows, not just the one from the tab
    -- local focus = vim.api.nvim_get_current_win()
    -- local windows = vim.api.nvim_tabpage_list_wins(0)
    -- if focus == windows[1] then
    --     return
    -- end
    vim.cmd.wincmd("W")
    M.arrange()
end

-- TODO what about we can only edit and focus the main window? the stack is only there to select and pull to main
function M.next()
    vim.cmd.wincmd("w")
    M.arrange()
end

---@param window? integer
function M.focus(window)
    local windows = M.get_windows()
    if not windows[1] or not windows[2] then
        return
    end
    local new_main = window or vim.api.nvim_get_current_win()
    local old_main = windows[1]
    if new_main == old_main then
        new_main = windows[2]
    end
    windows = vim.tbl_filter(function(v)
        return v ~= new_main
    end, windows)
    windows = { new_main, unpack(windows) }
    local old_view = vim.api.nvim_win_call(old_main, vim.fn.winsaveview)
    vim.api.nvim_set_current_win(new_main)
    local new_view = vim.fn.winsaveview()
    M.arrange(windows)
    vim.fn.winrestview(new_view)
    vim.api.nvim_win_call(old_main, function()
        vim.fn.winrestview(old_view)
    end)
end

function M.context()
    -- TODO we assume this was done in the main window right now
    vim.w.is_context = true
    local windows = M.get_windows()
    for i = 2, #windows do
        local w = windows[i]
        if not vim.w[w].is_context then
            -- NOTE this highlights the current one, which will become a context
            -- just wip, better highlight the visual of the context? because submodes would hide this cursorline now
            if vim.wo.winhighlight == "" then
                vim.wo.winhighlight = "CursorLine:CursorLineLavishLayoutContext"
            else
                vim.wo.winhighlight = vim.wo.winhighlight .. ",CursorLine:CursorLineLavishLayoutContext"
            end
            local r = table.remove(windows, i)
            table.insert(windows, 1, r)
            vim.api.nvim_set_current_win(r)
            M.arrange(windows)
            return
        end
    end
    vim.notify("No top of stack to attach context to.")
end

--- close current main and all context that was attached to it
function M.close()
    -- TODO wip, need to take care of clearing again, assuming now you close the top of the stack always
    -- require("lavish-layouts").close_window_or_clear()
    local windows = M.get_windows()
    for i = 1, #windows do
        local w = windows[i]
        if i == 1 then
            vim.api.nvim_win_close(w, true)
        elseif vim.w[w].is_context then
            vim.api.nvim_win_close(w, true)
        else
            break
        end
    end
    M.arrange()
end

return M
