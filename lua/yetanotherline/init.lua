local M = {}

local bg = "#cccccd"
local fg = "#2E3440"
vim.api.nvim_command("highlight! YetAnotherLine guibg=" .. bg .. " guifg=" .. fg)

local hl_colors = {
	YASNorMode = { bg = bg, fg = "#fb4934" },
	YASInsertMode = { bg = bg, fg = "#268bd2" },
	YASVisualMode = { bg = bg, fg = "#50a14f" },
	YASReplaceMode = { bg = bg, fg = "#a48ec7" },
	YASCmdMode = { bg = bg, fg = "#FF6A00" },
	YASOtherMode = { bg = bg, fg = "#83a598" },
}
local setup_hl = function()
	for hl_group, colors in pairs(hl_colors) do
		vim.api.nvim_command("highlight " .. hl_group .. " guifg=" .. colors.fg .. " guibg=" .. colors.bg)
	end
end

local mode_hl = {
	no = "YASNorMode",
	n = "YASNorMode",
	i = "YASInsertMode",
	I = "YASInsertMode",
	v = "YASVisualMode",
	V = "YASVisualMode",
	[""] = "YASVisualMode",
	R = "YASReplaceMode",
	c = "YASCmdMode",
	s = "YASOtherMode",
	S = "YASOtherMode",
	[""] = "YASOtherMode",
	t = "YASOtherMode",
	Unknown = "YASOtherMode",
}

local events = {
	"ColorScheme",
	"FileType",
	"BufWinEnter",
	"BufReadPost",
	"BufWritePost",
	"BufEnter",
	"WinEnter",
	"FileChangedShellPost",
	"VimResized",
	"TermOpen",
	"ModeChanged",
}

local function get_file_info()
	return vim.fn.expand("%:t"), vim.fn.expand("%:e")
end

M.fileIcon = function()
	local file_name, file_extension = get_file_info()
	local ok, devicons = pcall(require, "nvim-web-devicons")
	if not ok then
		return ""
	end
	local icon, color = devicons.get_icon_color(file_name, file_extension, { default = true })
	if color then
		vim.api.nvim_command("highlight! YASFileIcon guifg=" .. color .. " guibg=" .. bg)
	end

	return "%#YASFileIcon#" .. icon
end

M.mode = function()
	local mode = vim.api.nvim_get_mode().mode

	local hl = mode_hl[mode]

	if hl == nil then
		hl = mode_hl["Unknown"]
	end

	return "%#" .. hl .. "#" .. " "
end

local iter_line = vim.loop.new_async(vim.schedule_wrap(function()
	local mod = require("yetanotherline")
	local statusline = ""
	statusline = table.concat({
		mod.mode(),
		mod.fileIcon(),
		"%=",
	})
	setup_hl()

	vim.wo.statusline = statusline
end))

M.update_statusline = function()
	iter_line:send()
end

M.setup = function()
	vim.api.nvim_command("augroup yetanotherline")
	vim.api.nvim_command("autocmd!")
	for _, event in ipairs(events) do
		vim.api.nvim_command("autocmd " .. event .. " * lua require('yetanotherline').update_statusline()")
	end
	vim.api.nvim_command("augroup END")
end

return M
