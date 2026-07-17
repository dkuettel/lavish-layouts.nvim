---@class MainLayout
local M = {}

-- TODO arranges seem to change views somehow, especially after a pair of wf wf, or after w space space and close, things move, unexpected
-- when a focused window moves to the stack, its smaller, so its not clear there what to show, you cant show the same
-- showing around the cursor makes most sense? that seems to have been the important part?
-- but then when that window becomes big again, what to show and at what view exactly? the info is lost
-- very clear, and maybe best testet in stacked layout, since they make the stacked view just one row in size
-- vim has some view safe functions, every layout does the logic for the important windows somehow? or for those windows with the same geometry?
-- but even so, even the main window can change, how does vim handle it natively in these cases? hm its quite proportional, even after squeezing, how can it keep the proportion then?
-- no, it seems to be off a bit when squeezing much, with large font
-- maybe the scroll-off is what breaks it? what can we expect from stacked, when its just one row anyway?
-- vim.fn.winsave view and winrestview works well when no geom changes, not sure how gracefully it handles it when you apply it to a differen size later
-- hm second time it messes up other windows too (no more stack sandwiches); ah no that is just the command buffer view that has this problem, another thing to solve
-- vim.fn.winrestview works reasonable when resizing and applying again, maybe thats it? we keep the original winsave, until you act on a window? and apply it everytime?
--    hmm on a second try, with a 1/3 window, it doesnt handle restore very well
-- what about vim.fn.winlayout()? its only half of it. at least it seems to give only actually visible windows
---@param windows? integer[] window handles in layout order: main, stack, stack, ...
function M.arrange(windows)
    windows = windows or M.get_windows() -- order: main, stack, stack, ...

    ---@type vim.fn.winsaveview.ret?
    local view1 = nil
    if windows[1] then
        vim.api.nvim_win_call(windows[1], function()
            view1 = vim.fn.winsaveview()
        end)
    end

    ---@type vim.fn.winsaveview.ret?
    local view2 = nil
    if windows[2] then
        vim.api.nvim_win_call(windows[2], function()
            view2 = vim.fn.winsaveview()
        end)
    end

    -- arrange
    for i, w in ipairs(windows) do
        if i > 1 then
            vim.api.nvim_win_call(w, function()
                vim.cmd.wincmd("J")
            end)
        end
    end
    if windows[1] then
        vim.api.nvim_win_call(windows[1], function()
            vim.cmd.wincmd("H")
        end)
    end

    -- restore main view
    if windows[1] and view1 then
        vim.api.nvim_win_call(windows[1], function()
            vim.fn.winrestview(view1)
            vim.wo.scrolloff = -1
        end)
    end

    -- restore stack view, if just one
    if #windows == 2 and windows[2] and view2 then
        vim.api.nvim_win_call(windows[2], function()
            vim.fn.winrestview(view2)
        end)
    end

    -- position stack views, if more than one
    if #windows >= 3 then
        for i, w in ipairs(windows) do
            if i > 1 then
                vim.api.nvim_win_call(w, function()
                    -- TODO when switching layouts, this can get forgotten, and stay on 0
                    vim.wo.scrolloff = 0
                    vim.cmd.normal { "zt", bang = true }
                    -- TODO cursorline to indicate? or we just know its always the top line?
                end)
            end
        end
    end
end

---@return integer[] windows window handles in layout order: main, stack, stack, ...
function M.get_windows()
    return require("lavish-layouts.misc").get_windows("forward")
end

-- TODO when running this, i see some flicker, can we hold drawing until all is done?
function M.new()
    local stack = M.get_windows()
    local current = vim.api.nvim_get_current_win()
    local view = nil
    if current == stack[1] then
        view = vim.fn.winsaveview()
    end
    vim.cmd.split()
    local main = vim.api.nvim_get_current_win()
    local windows = { main, unpack(stack) }
    M.arrange(windows)
    if view then
        vim.fn.winrestview(view)
    else
        vim.cmd.normal { "zt", bang = true }
    end
end

function M.previous()
    -- TODO in nvim 0.12 I think nvim_tabpage_list_wins is bugged, it returns all windows, not just the one from the tab
    -- local focus = vim.api.nvim_get_current_win()
    -- local windows = vim.api.nvim_tabpage_list_wins(0)
    -- if focus == windows[1] then
    --     return
    -- end
    vim.cmd.wincmd("W")
end

-- TODO what about we can only edit and focus the main window? the stack is only there to select and pull to main
function M.next()
    -- TODO in nvim 0.12 I think nvim_tabpage_list_wins is bugged, it returns all windows, not just the one from the tab
    -- local focus = vim.api.nvim_get_current_win()
    -- local windows = vim.api.nvim_tabpage_list_wins(0)
    -- if focus == windows[#windows] then
    --     return
    -- end
    vim.cmd.wincmd("w")
end

---@param window? integer
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
    if #windows > 2 then
        vim.cmd.normal { "zt", bang = true }
    end
end

function M.close()
    require("lavish-layouts").close_window_or_clear()
    M.arrange()
end

return M
