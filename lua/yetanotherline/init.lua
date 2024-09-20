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
	YASGitAdded = { bg = bg, fg = "#50a14f" },
	YASGitChanged = { bg = bg, fg = "#FF6A00" },
	YASGitRemoved = { bg = bg, fg = "#fb4934" },
	YASGitBranch = { bg = bg, fg = "#a48ec7" },
	YASLspStatus = { bg = bg, fg = "#fb4934" },
	YASLspError = { bg = bg, fg = "#fb4934" },
	YASLspWarning = { bg = bg, fg = "#FF6A00" },
	YASLspHints = { bg = bg, fg = "#a48ec7" },
	YASLspInfo = { bg = bg, fg = "#268bd2" },
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

M.mode = function()
	local mode = vim.api.nvim_get_mode().mode

	local hl = mode_hl[mode]

	if hl == nil then
		hl = mode_hl["Unknown"]
	end

	return "%#" .. hl .. "#" .. " "
end

M.file = function()
	local file_name, file_extension = get_file_info()
	local ok, devicons = pcall(require, "nvim-web-devicons")
	if not ok then
		return ""
	end
	local icon, color = devicons.get_icon_color(file_name, file_extension, { default = true })
	if color then
		vim.api.nvim_command("highlight! YASFileIcon guifg=" .. color .. " guibg=" .. bg .. " gui=bold")
	end

	return "%#YASFileIcon#" .. icon .. " " .. file_name
end

M.git_info = function()
	local ok, dict = pcall(vim.api.nvim_buf_get_var, 0, "gitsigns_status_dict")
	if not ok then
		return ""
	end

	local added = (dict.added and dict.added ~= 0) and (" %#YASGitAdded# " .. dict.added) or ""
	local changed = (dict.changed and dict.changed ~= 0) and (" %#YASGitChanged# " .. dict.changed) or ""
	local removed = (dict.removed and dict.removed ~= 0) and (" %#YASGitRemoved# " .. dict.removed) or ""

	return "    %#YASGitBranch#  -> " .. added .. changed .. removed
end

M.lsp_server = function()
	for _, client in ipairs(vim.lsp.get_active_clients()) do
		if client.attached_buffers[vim.api.nvim_get_current_buf()] then
			return (vim.o.columns > 70 and "%#YASLspStatus#" .. "  " .. client.name .. " ") or "   LSP "
		end
	end

	return ""
end

M.lsp_diagnostics = function()
	local errors = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.ERROR })
	local warnings = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.WARN })
	local hints = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.HINT })
	local info = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.INFO })

	errors = (errors and errors > 0) and ("%#YASLspError#" .. " " .. errors .. " ") or ""
	warnings = (warnings and warnings > 0) and ("%#YASLspWarning#" .. "  " .. warnings .. " ") or ""
	hints = (hints and hints > 0) and ("%#YASLspHints#" .. "ﯧ " .. hints .. " ") or ""
	info = (info and info > 0) and ("%#YASLspInfo#" .. " " .. info .. " ") or ""

	return errors .. warnings .. hints .. info
end

local iter_line = vim.loop.new_async(vim.schedule_wrap(function()
	local mod = require("yetanotherline")
	local statusline = ""
	statusline = table.concat({
		mod.mode(),
		mod.file(),
		"%=",
		mod.git_info(),
		"%=",
		mod.lsp_diagnostics(),
		"%=",
		mod.lsp_server(),
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
