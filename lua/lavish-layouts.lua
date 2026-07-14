local M = {}

-- NOTE when a window goes to the stack or "background", it usually gets smaller
-- the current behaviour is so that the view in that window shifts so that you
-- still see the cursor location, together with scrolloff that usually centers
-- the current line in that small view. when you later take that window again
-- back to main, there is no data to really exactly restore the view you had
-- before backgrounding it, and its then centered again. could be unintuitive?

-- TODO the dynamic layout should be a table that configures the conditions
---@alias LayoutName "main" | "stacked" | "tiled" | "dynamic"

-- TODO should type the any part here, classes?
---@type table<LayoutName, any>
M.layouts = { main = {}, stacked = {}, tiled = {}, dynamic = {} }

-- NOTE we have one global layout (saved as a name in vim.g.Layout)
-- that is applied to all tabs, we could also use vim.t.Layout and have it per tab
-- (we also then need to make sure sessions save it)
-- There is also vim.g.LayoutDesc that has a description of the current layout for the statusline.

-- TODO now with a global layout, we should probably use events like TabEnter TabLeave TabNew TabNewEntered TabClosed
-- similar to VimResized to relayout in the right moments? or leave it to the user on his tab switch mappings?

---@param name? LayoutName
---@return any
function get_layout(name)
    if name == nil then
        ---@type LayoutName
        name = vim.g.Layout or "main"
    end
    return M.layouts[name]
end

function M.setup()
    local bg0_h = "#f9f5d7"
    vim.opt.sessionoptions:append("globals") -- NOTE to restore the layout when re-loading sessions
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

    vim.api.nvim_create_autocmd({ "VimEnter" }, {
        callback = function()
            get_layout():arrange()
        end,
        once = true,
    })

    -- TODO to check if things bounce around and are not idempotent
    function again()
        vim.notify("bounce")
        get_layout():arrange()
        vim.defer_fn(again, 1000)
    end
    vim.defer_fn(again, 1000)
end

-- TODO when is a session loaded? after we set the default with this or before?
---@param name LayoutName
function M.switch(name)
    local windows = get_layout():get_windows()
    vim.g.Layout = name
    vim.g.LayoutDesc = name
    get_layout():arrange(windows)
end

---@param blink? boolean
function M.new(blink)
    get_layout():new()
    if blink then
        vim.wo.winhighlight = "Normal:NormalCreated"
        local function reset()
            -- TODO we might not be in the same window anymore, and or other things might have been in this value?
            vim.wo.winhighlight = ""
        end
        vim.defer_fn(reset, 250)
    end
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
        -- TODO hm also here we get way too many windows than what I actually see
        -- the layouting process seems robust to that? or is the filter later working it out?
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
function M.layouts.main:arrange(windows)
    local focus = vim.api.nvim_get_current_win()
    -- TODO emmylua doesnt understand self? and then the windows type is broken; hm no probably just because I didnt really make it a class yet; the type is any for M.layouts.main
    ---@type integer[]
    windows = windows or self:get_windows() -- order: main, stack, stack, ...
    local view = nil
    if windows[1] then
        vim.api.nvim_win_call(windows[1], function()
            view = vim.fn.winsaveview()
        end)
    end
    -- vim.notify("arranging main for " .. vim.inspect(windows))
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
            if view then
                vim.fn.winrestview(view)
            end
            vim.wo.scrolloff = -1
        end)
    end
    -- TODO actually when just two windows, then we want to restore views, starting with 3, we want the top-policy
    for i, w in ipairs(windows) do
        if i > 1 then
            vim.api.nvim_win_call(w, function()
                vim.wo.scrolloff = 0
                vim.cmd.normal { "zt", bang = true }
            end)
        end
    end
    vim.api.nvim_set_current_win(focus)
end

---@return integer[] windows window handles in layout order: main, stack, stack, ...
function M.layouts.main:get_windows()
    return get_windows("forward")
end

-- TODO when running this, i see some flicker, can we hold drawing until all is done?
function M.layouts.main:new()
    local stack = self:get_windows()
    local current = vim.api.nvim_get_current_win()
    local view = nil
    if current == stack[1] then
        view = vim.fn.winsaveview()
    end
    vim.cmd.split()
    local main = vim.api.nvim_get_current_win()
    local windows = { main, unpack(stack) }
    self:arrange(windows)
    if view then
        vim.fn.winrestview(view)
    else
        vim.cmd.normal { "zt", bang = true }
    end
end

function M.layouts.main:previous()
    -- TODO in nvim 0.12 I think nvim_tabpage_list_wins is bugged, it returns all windows, not just the one from the tab
    -- local focus = vim.api.nvim_get_current_win()
    -- local windows = vim.api.nvim_tabpage_list_wins(0)
    -- if focus == windows[1] then
    --     return
    -- end
    vim.cmd.wincmd("W")
end

-- TODO what about we can only edit and focus the main window? the stack is only there to select and pull to main
function M.layouts.main:next()
    -- TODO in nvim 0.12 I think nvim_tabpage_list_wins is bugged, it returns all windows, not just the one from the tab
    -- local focus = vim.api.nvim_get_current_win()
    -- local windows = vim.api.nvim_tabpage_list_wins(0)
    -- if focus == windows[#windows] then
    --     return
    -- end
    vim.cmd.wincmd("w")
end

---@param window? integer
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
    vim.cmd.normal { "zt", bang = true }
end

function M.layouts.main:close()
    close_window_or_clear()
    self:arrange()
end

function M.layouts.stacked:arrange(windows)
    -- vim.notify("arranging stack")
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

function M.layouts.stacked:new()
    local windows = self:get_windows()
    local view = vim.fn.winsaveview()
    vim.cmd.split()
    local window = vim.api.nvim_get_current_win()
    windows = { window, unpack(windows) }
    self:arrange(windows)
    vim.fn.winrestview(view) -- this should make the forked view exactly the same
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

function M.layouts.tiled:new()
    -- TODO how to restore view? when 1 -> restore, when 2 -> restore, for the stacked once, make the top behavior?
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

local current_dynamic_layout = nil

---@param windows? integer[] window handles in layout order
function M.layouts.dynamic:arrange(windows)
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
    if not windows and current_dynamic_layout ~= layout then
        windows = M.layouts[current_dynamic_layout]:get_windows()
    end
    current_dynamic_layout = layout
    M.layouts[current_dynamic_layout]:arrange(windows)
end

---@return integer[] windows window handles in layout order
function M.layouts.dynamic:get_windows()
    return M.layouts[current_dynamic_layout]:get_windows()
end

function M.layouts.dynamic:new()
    M.layouts[current_dynamic_layout]:new()
end

function M.layouts.dynamic:previous()
    M.layouts[current_dynamic_layout]:previous()
end

function M.layouts.dynamic:next()
    M.layouts[current_dynamic_layout]:next()
end

function M.layouts.dynamic:focus(window)
    M.layouts[current_dynamic_layout]:focus(window)
end

function M.layouts.dynamic:close()
    M.layouts[current_dynamic_layout]:close()
end

function M.switch_dynamic()
    M.switch("dynamic")
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

--- for the current window and rearrange
--- this makes a best effort to have the forked view at exactly the same viewport
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
