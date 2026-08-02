local M = {}

local ALIGN_GIT = "%="
local ALIGN_RIGHT = string.rep("%=", 20)
local AUGROUP_NAME = "YetAnotherLine"
local STATUSLINE = "%!v:lua.require('yetanotherline').build_statusline()"

local HIGHLIGHTS = {
	YASCmdMode = "#FF8800",
	YASGitAdded = "#98be65",
	YASGitBranch = "#a9a1e1",
	YASGitChanged = "#FF8800",
	YASGitRemoved = "#ec5f67",
	YASInsertMode = "#98be65",
	YASLspError = "#ec5f67",
	YASLspHints = "#a9a1e1",
	YASLspInfo = "#51afef",
	YASLspStatus = "#ec5f67",
	YASLspWarnings = "#FF8800",
	YASNorMode = "#ec5f67",
	YASOtherMode = "#83a598",
	YASReplaceMode = "#c678dd",
	YASVisualMode = "#51afef",
}

local MODE_HIGHLIGHTS = {
	["\19"] = "YASOtherMode",
	["\22"] = "YASVisualMode",
	R = "YASReplaceMode",
	S = "YASOtherMode",
	V = "YASVisualMode",
	c = "YASCmdMode",
	i = "YASInsertMode",
	n = "YASNorMode",
	no = "YASNorMode",
	s = "YASOtherMode",
	t = "YASOtherMode",
	v = "YASVisualMode",
}

local DIAGNOSTICS = {
	{ vim.diagnostic.severity.ERROR, "YASLspError", "" },
	{ vim.diagnostic.severity.WARN, "YASLspWarnings", "" },
	{ vim.diagnostic.severity.HINT, "YASLspHints", "" },
	{ vim.diagnostic.severity.INFO, "YASLspInfo", "" },
}

local augroup_id
local devicons
local enabled = false
local icon_highlights = {}
local previous_laststatus
local previous_statusline
local statusline_background

local function to_hex(color)
	return string.format("#%06x", color)
end

local function get_statusline_background()
	local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
	local statusline = vim.api.nvim_get_hl(0, { name = "StatusLine", link = false })
	local background = statusline.bg or normal.bg
	if statusline.reverse then
		background = statusline.fg or normal.fg
	end
	if background then
		return to_hex(background)
	end
end

local function set_highlight(group, foreground, bold)
	vim.api.nvim_set_hl(0, group, {
		bg = statusline_background,
		bold = bold,
		fg = foreground,
	})
end

local function refresh_highlights()
	statusline_background = get_statusline_background()

	for group, foreground in pairs(HIGHLIGHTS) do
		set_highlight(group, foreground, false)
	end
	for group, foreground in pairs(icon_highlights) do
		set_highlight(group, foreground, true)
	end
end

local function schedule_highlight_refresh()
	vim.schedule(function()
		if not enabled then
			return
		end
		refresh_highlights()
		vim.cmd.redrawstatus()
	end)
end

local function escape_statusline(value)
	return value:gsub("%%", "%%%%")
end

local function get_file_info()
	local file_name = vim.fs.basename(vim.api.nvim_buf_get_name(0))
	local extension = file_name:match("^.+%.([^.]+)$")
	if not extension then
		extension = ""
	end
	return file_name, extension
end

local function load_devicons()
	if devicons then
		return devicons
	end

	local ok, module = pcall(require, "nvim-web-devicons")
	if ok then
		devicons = module
	end
	return devicons
end

local function get_file_icon(file_name, extension)
	local icons = load_devicons()
	if not icons then
		return ""
	end

	local icon, color = icons.get_icon_color(file_name, extension, { default = true })
	if not icon or not color then
		return ""
	end

	local group = "YASFileIcon" .. extension
	if icon_highlights[group] ~= color then
		icon_highlights[group] = color
		set_highlight(group, color, true)
	end

	return "%#" .. group .. "#" .. icon .. " "
end

local function append_git(parts)
	local git = vim.b.gitsigns_status_dict
	if not git then
		return
	end

	local head = git.head
	if not head then
		head = ""
	end
	parts[#parts + 1] = "%#YASGitBranch# " .. escape_statusline(head) .. " "

	if git.added and git.added > 0 then
		parts[#parts + 1] = "%#YASGitAdded# " .. tostring(git.added) .. " "
	end
	if git.changed and git.changed > 0 then
		parts[#parts + 1] = "%#YASGitChanged# " .. tostring(git.changed) .. " "
	end
	if git.removed and git.removed > 0 then
		parts[#parts + 1] = "%#YASGitRemoved# " .. tostring(git.removed) .. " "
	end
end

local function append_diagnostics(parts)
	local counts = vim.diagnostic.count(0)
	for _, diagnostic in ipairs(DIAGNOSTICS) do
		local count = counts[diagnostic[1]]
		if count and count > 0 then
			parts[#parts + 1] = "%#" .. diagnostic[2] .. "#" .. diagnostic[3] .. " " .. tostring(count) .. " "
		end
	end
end

local function append_lsp(parts)
	for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
		if client.name ~= "copilot" then
			parts[#parts + 1] = "%#YASLspStatus#  " .. escape_statusline(client.name)
			return
		end
	end
end

local function redraw_statusline()
	vim.cmd.redrawstatus()
end

M.build_statusline = function()
	local mode_highlight = MODE_HIGHLIGHTS[vim.api.nvim_get_mode().mode]
	if not mode_highlight then
		mode_highlight = "YASOtherMode"
	end

	local file_name, extension = get_file_info()
	local parts = {
		"%#",
		mode_highlight,
		"# ",
		get_file_icon(file_name, extension),
		escape_statusline(file_name),
		" ",
		ALIGN_GIT,
	}

	append_git(parts)
	parts[#parts + 1] = ALIGN_RIGHT
	append_diagnostics(parts)
	append_lsp(parts)
	parts[#parts + 1] = " %l:%c "

	return table.concat(parts)
end

M.setup = function()
	if not enabled then
		previous_laststatus = vim.o.laststatus
		previous_statusline = vim.o.statusline
	end
	enabled = true

	refresh_highlights()
	vim.o.laststatus = 3
	vim.o.statusline = STATUSLINE
	vim.wo.statusline = ""

	augroup_id = vim.api.nvim_create_augroup(AUGROUP_NAME, { clear = true })
	vim.api.nvim_create_autocmd({ "WinNew", "WinEnter", "BufWinEnter" }, {
		group = augroup_id,
		callback = function()
			vim.wo.statusline = ""
			redraw_statusline()
		end,
	})
	vim.api.nvim_create_autocmd(
		{ "ModeChanged", "BufEnter", "BufWritePost", "DiagnosticChanged", "LspAttach", "LspDetach" },
		{
			group = augroup_id,
			callback = redraw_statusline,
		}
	)
	vim.api.nvim_create_autocmd("ColorScheme", {
		group = augroup_id,
		callback = schedule_highlight_refresh,
	})
end

M.disable = function()
	if not enabled then
		return
	end
	enabled = false

	vim.api.nvim_del_augroup_by_id(augroup_id)
	augroup_id = nil
	vim.o.statusline = previous_statusline
	vim.o.laststatus = previous_laststatus
end

return M
