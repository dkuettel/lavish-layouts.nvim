---@namespace lavish-layouts

---@class MainLayout
local M = {}

--[[ draft
i want to enforce a strict stack semantics, you can only push and pop
you can fork, but not refocus a lower window when you go and look at it, as done with "wf" right now
that stack works well for drilling down and keeping a "todo" list
but often you need to get some context, check how something was done somewhere else
and then see that while working on the real top of the stack
that doesnt quite work in stack fashion
somehow you want to flip those windows, to keep the active editing in the main view
but that is unstacky, and all the context-windows should not get flat, so you can actually see
would be nice if some windows are marked as context, maybe visually, and that will be visible, not just one line, when collapsed, and if possible
would tabs be the right thing then?
its natural to just ww, find what you need, and then wf or so to get the real thing again
instead wf might mark as context and pop the stack? and it is attached to the previous as context?
and it will close when you pop that one?
and maybe tabs could keep the top and all the context?
--]]

-- TODO arranges seem to change views somehow, especially after a pair of wf wf, or after w space space and close, things move, unexpected
-- when a focused window moves to the stack, its smaller, so its not clear there what to show, you cant show the same
-- showing around the cursor makes most sense? that seems to have been the important part?
-- but then when that window becomes big again, what to show and at what view exactly? the info is lost
-- very clear, and maybe best testet in stacked layout, since they make the stacked view just one row in size
-- vim has some view safe functions, every layout does the logic for the important windows somehow? or for those windows with the same geometry?
-- but even so, even the main window can change, how does vim handle it natively in these cases? hm its quite proportional, even after squeezing, how can it keep the proportion then?
-- no, it seems to be off a bit when squeezing much, with large font
-- maybe the scroll-off is what breaks it? what can we expect from stacked, when its just one row anyway?
-- vim.fn.winsave view and winrestview works well when no geom changes, not sure how gracefully it handles it when you apply it to a different size later
-- hm second time it messes up other windows too (no more stack sandwiches); ah no that is just the command buffer view that has this problem, another thing to solve
-- vim.fn.winrestview works reasonable when resizing and applying again, maybe thats it? we keep the original winsave, until you act on a window? and apply it everytime?
--    hmm on a second try, with a 1/3 window, it doesnt handle restore very well
-- what about vim.fn.winlayout()? its only half of it. at least it seems to give only actually visible windows
-- looks like this { "row", { { "leaf", 1057 }, { "col", { { "leaf", 1056 }, { "leaf", 1055 }, { "leaf", 1011 } } } } }
---@param windows? integer[] window handles in layout order: main, stack, stack, ...
function M.arrange(windows)
    -- TODO if windows was not given, then we know already that some things cannot have changed
    -- TODO if the list of windows is shorter than the actual list, dont we just ignore it but not really change or remove it?
    windows = windows or M.get_windows() -- order: main, stack, stack, ...
    local current = vim.api.nvim_get_current_win()

    ---@type vim.fn.winsaveview.ret?
    local view1 = nil
    if windows[1] then
        vim.api.nvim_win_call(windows[1], function()
            view1 = vim.fn.winsaveview()
        end)
    end

    -- TODO hm a stack second view would be good to restore, but it could also be contexts
    ---@type vim.fn.winsaveview.ret?
    local view2 = nil
    -- if windows[2] then
    --     vim.api.nvim_win_call(windows[2], function()
    --         view2 = vim.fn.winsaveview()
    --     end)
    -- end

    -- arrange
    for i, w in ipairs(windows) do
        if i > 1 then
            vim.api.nvim_win_call(w, function()
                -- TODO this can fail when there is not a enough space and then things become jumbled up
                -- and the layout will get messed up, because it just doesnt fit, pcall at least doesnt spam the user
                -- should we try to then hide the windows? not impossible, but very cumbersome
                pcall(vim.cmd.wincmd, "J")
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

    if current == windows[1] then
        -- TODO winfixwidth winheight winminheight could make some of this smooth?
        -- but in general, how to not re-arrange when not needed? or does unrendered rearrangement not forget anything?
        -- from winrestcmd(): 1resize 53|vert 1resize 128|2resize 17|vert 2resize 127|3resize 17|vert 3resize 127|4resize 17|vert 4resize 127|1resize 53|vert 1resize 128|2resize 17|vert 2resize 127|3resize 17|vert 3resize 127|4resize 17|vert 4resize 127|
        local passed = false
        -- vim.cmd("vertical wincmd =")
        for i = 1, #windows do
            vim.api.nvim_win_call(windows[i], function()
                if i == 1 then
                    vim.wo.winfixheight = false
                elseif i == 2 then
                    -- vim.cmd.wincmd("_")
                    -- vim.cmd.resize(999)
                    vim.wo.winfixheight = false
                    vim.cmd.resize(999)
                    if not vim.w.is_context then
                        passed = true
                    end
                elseif i >= 3 then
                    -- vim.wo.winfixheight = true
                    -- vim.cmd.resize(1)
                    if vim.w.is_context and not passed then
                        -- vim.cmd.resize(999)
                        vim.wo.winfixheight = false
                        vim.cmd.resize(999)
                    else
                        -- vim.cmd.wincmd("_")
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
    -- if #windows >= 2 and windows[2] then
    --     vim.api.nvim_win_call(windows[2], function()
    --         vim.cmd.wincmd("_")
    --     end)
    -- end

    -- restore stack view, if just one
    if #windows == 2 and windows[2] and view2 then
        vim.api.nvim_win_call(windows[2], function()
            vim.fn.winrestview(view2)
        end)
    end

    -- position stack views, if more than one
    -- if #windows >= 3 then
    --     for i, w in ipairs(windows) do
    --         if i > 1 then
    --             vim.api.nvim_win_call(w, function()
    --                 -- TODO when switching layouts, this can get forgotten, and stay on 0
    --                 -- vim.wo.scrolloff = 0
    --                 vim.cmd.normal { "zt", bang = true }
    --                 -- TODO cursorline to indicate? or we just know its always the top line?
    --             end)
    --         end
    --     end
    -- end
end

---@return integer[] windows window handles in layout order: main, stack, stack, ...
function M.get_windows()
    return require("lavish-layouts.misc").get_windows("forward")
end

-- TODO when running this, i see some flicker, can we hold drawing until all is done? lazyredraw?
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
    if vim.fn.winnr() > 1 then
        vim.cmd.wincmd("_")
    else
        M.arrange()
    end
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
    if vim.fn.winnr() > 1 then
        vim.cmd.wincmd("_")
    else
        M.arrange()
    end
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
