local M = {}

-- NOTE when a window goes to the stack or "background", it usually gets smaller
-- the current behaviour is so that the view in that window shifts so that you
-- still see the cursor location, together with scrolloff that usually centers
-- the current line in that small view. when you later take that window again
-- back to main, there is no data to really exactly restore the view you had
-- before backgrounding it, and its then centered again. could be unintuitive?

---@alias LayoutName "main" | "stacked" | "dynamic"

local MainLayout = require("lavish-layouts.layouts.main").MainLayout
local StackedLayout = require("lavish-layouts.layouts.stacked").StackedLayout
local DynamicLayout = require("lavish-layouts.layouts.dynamic").DynamicLayout

---@alias Layout MainLayout|StackedLayout|DynamicLayout

---@type table<LayoutName, Layout>
M.layouts = { main = MainLayout.make(), stacked = StackedLayout.make(), dynamic = DynamicLayout.make() }

-- NOTE we have one global layout (saved as a name in vim.g.Layout)
-- that is applied to all tabs, we could also use vim.t.Layout and have it per tab
-- (we also then need to make sure sessions save it)
-- There is also vim.g.LayoutDesc that has a description of the current layout for the statusline.

-- TODO now with a global layout, we should probably use events like TabEnter TabLeave TabNew TabNewEntered TabClosed
-- similar to VimResized to relayout in the right moments? or leave it to the user on his tab switch mappings?

---@param name? LayoutName
---@return Layout
function get_layout(name)
    if name then
        return M.layouts[name] or M.layouts["main"]
    end
    return M.layouts[vim.g.Layout] or M.layouts["main"]
end

function M.setup()
    vim.opt.sessionoptions:append("globals") -- NOTE to restore the layout when re-loading sessions

    vim.g.Layout = vim.g.Layout or "main"

    local bg0_h = "#f9f5d7"
    vim.api.nvim_set_hl(0, "NormalCreated", { bg = bg0_h })

    vim.api.nvim_create_user_command("Layout", function(args)
        local name = args.fargs[1]
        if name == "main" or name == "stacked" or name == "dynamic" then
            M.switch(name)
        else
            vim.notify("unknown layout: '" .. name .. "'")
        end
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

function M.close_window_or_clear()
    if #vim.api.nvim_list_tabpages() > 1 or #vim.api.nvim_tabpage_list_wins(0) > 1 then
        vim.api.nvim_win_close(0, true)
    else
        vim.cmd([[:e .]])
    end
end

---@param order "forward" | "backward"
---@return integer[] windows window handles without floating windows
function M.get_windows(order)
    local windows
    if order == "forward" then
        -- TODO hm also here we get way too many windows than what I actually see
        -- the layouting process seems robust to that? or is the filter later working it out?
        windows = vim.api.nvim_tabpage_list_wins(0)
    else -- order=="backward"
        windows = vim.fn.reverse(vim.api.nvim_tabpage_list_wins(0))
    end
    windows = vim.tbl_filter(function(window)
        local config = vim.api.nvim_win_get_config(window)
        return config.relative == "" -- this means it is not a floating window
    end, windows)
    return windows
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

--- for the current window and rearrange
--- this makes a best effort to have the forked view at exactly the same viewport
function M.new_from_split()
    M.new()
end

return M
