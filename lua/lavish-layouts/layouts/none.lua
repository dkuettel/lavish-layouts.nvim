---@namespace lavish-layouts

---@class NoneLayout
local M = {}

---@param windows? integer[] window handles in layout order
---@diagnostic disable-next-line: unused
function M.arrange(windows) end

---@return integer[] windows window handles in layout order
function M.get_windows()
    return require("lavish-layouts.misc").get_windows("forward")
end

function M.new()
    vim.cmd.split()
end

function M.previous()
    vim.cmd.wincmd("W")
end

function M.next()
    vim.cmd.wincmd("w")
end

---@param window? integer
---@diagnostic disable-next-line: unused
function M.focus(window) end

function M.context() end

function M.close()
    vim.cmd.wincmd("c")
end

return M
