local M = {}

local layouts = {
    main = require("lavish-layouts.layouts.main"),
    stacked = require("lavish-layouts.layouts.stacked"),
    dynamic = require("lavish-layouts.layouts.dynamic"),
}

---@param name? string
---@return Layout?
function M.maybe_get_layout(name)
    return layouts[name]
end

---@param name LayoutName
---@return Layout
function M.get_layout(name)
    ---@diagnostic disable: unnecessary-assert
    local l = assert(M.maybe_get_layout(name))
    return l
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

return M
