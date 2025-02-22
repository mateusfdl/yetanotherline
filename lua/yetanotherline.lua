local M = {}

vim.api.nvim_command("highlight! YetAnotherLineBackground guibg=#2E3440 guifg=#2E3440")
local to_hex = function(color)
	return string.format("#%06x", color)
end
local sl_bg = to_hex(vim.api.nvim_get_hl_by_name("YetAnotherLineBackground", true).background)

local hl_colors = {
	YASNorMode = { bg = sl_bg, fg = "#ec5f67" },
	YASInsertMode = { bg = sl_bg, fg = "#98be65" },
	YASVisualMode = { bg = sl_bg, fg = "#51afef" },
	YASReplaceMode = { bg = sl_bg, fg = "#c678dd" },
	YASCmdMode = { bg = sl_bg, fg = "#FF8800" },
	YASOtherMode = { bg = sl_bg, fg = "#83a598" },
	YASGitAdded = { bg = sl_bg, fg = "#98be65" },
	YASGitChanged = { bg = sl_bg, fg = "#FF8800" },
	YASGitRemoved = { bg = sl_bg, fg = "#ec5f67" },
	YASGitBranch = { bg = sl_bg, fg = "#a9a1e1" },
	YASLspStatus = { bg = sl_bg, fg = "#ec5f67" },
	YASLspError = { bg = sl_bg, fg = "#ec5f67" },
	YASLspWarnings = { bg = sl_bg, fg = "#FF8800" },
	YASLspHints = { bg = sl_bg, fg = "#a9a1e1" },
	YASLspInfo = { bg = sl_bg, fg = "#51afef" },
}

local function setup_highlights()
	for hl_group, colors in pairs(hl_colors) do
		vim.api.nvim_set_hl(0, hl_group, { fg = colors.fg, bg = colors.bg })
	end
end

local mode_hl = {
	no = "YASNorMode",
	n = "YASNorMode",
	i = "YASInsertMode",
	v = "YASVisualMode",
	V = "YASVisualMode",
	["\22"] = "YASVisualMode",
	R = "YASReplaceMode",
	c = "YASCmdMode",
	s = "YASOtherMode",
	S = "YASOtherMode",
	["\19"] = "YASOtherMode",
	t = "YASOtherMode",
	Unknown = "YASOtherMode",
}

-- Reintroduce empty_space
M.empty_space = function(length)
	local spaces = ""
	local i = 0
	while i < (length or 0) do
		spaces = spaces .. "%="
		i = i + 1
	end
	return spaces
end

-- Build the statusline with separators
M.build_statusline = function()
	local mode = vim.api.nvim_get_mode().mode
	local hl = mode_hl[mode] or mode_hl.Unknown
	local file_name, file_ext = vim.fn.expand("%:t"), vim.fn.expand("%:e")
	local icon = ""
	local ok, devicons = pcall(require, "nvim-web-devicons")
	if ok then
		icon, color = devicons.get_icon_color(file_name, file_extension, { default = true })
		local hl_group = "YASFileIcon" .. file_ext
		vim.api.nvim_set_hl(0, hl_group, { fg = color, bg = bg_color, bold = true })

		icon = "%#" .. hl_group .. "#" .. icon
	end
	local git = ""
	local ok_git, dict = pcall(vim.api.nvim_buf_get_var, 0, "gitsigns_status_dict")
	if ok_git then
		local added = dict.added and dict.added > 0 and ("%#YASGitAdded# " .. dict.added .. " ") or ""
		local changed = dict.changed and dict.changed > 0 and ("%#YASGitChanged# " .. dict.changed .. " ") or ""
		local removed = dict.removed and dict.removed > 0 and ("%#YASGitRemoved# " .. dict.removed .. " ") or ""
		git = "%#YASGitBranch# " .. (dict.head or "") .. " " .. added .. changed .. removed
	end
	local lsp = ""
	for _, client in ipairs(vim.lsp.get_active_clients()) do
		if client.attached_buffers[vim.api.nvim_get_current_buf()] then
			lsp = "%#YASLspStatus#  " .. client.name
			break
		end
	end
	local diags = ""
	local diagnostics = {
		error = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.ERROR }),
		warnings = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.WARN }),
		hints = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.HINT }),
		info = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.INFO }),
	}
	if diagnostics.error > 0 then
		diags = diags .. "%#YASLspError# " .. diagnostics.error .. " "
	end
	if diagnostics.warnings > 0 then
		diags = diags .. "%#YASLspWarnings# " .. diagnostics.warnings .. " "
	end
	if diagnostics.hints > 0 then
		diags = diags .. "%#YASLspHints# " .. diagnostics.hints .. " "
	end
	if diagnostics.info > 0 then
		diags = diags .. "%#YASLspInfo# " .. diagnostics.info .. " "
	end

	return "%#"
		.. hl
		.. "# "
		.. icon
		.. " "
		.. file_name
		.. " "
		.. M.empty_space(1)
		.. git
		.. M.empty_space(20)
		.. diags
		.. lsp
		.. " %l:%c "
end

local function update_statusline()
	vim.o.laststatus = 3
	vim.o.statusline = "%!v:lua.require('yetanotherline').build_statusline()"
	-- for _, win in ipairs(vim.api.nvim_list_wins()) do
	-- 	vim.api.nvim_win_set_option(win, "statusline", "")
	-- end
end

M.setup = function()
	setup_highlights()
	update_statusline()

	vim.api.nvim_create_autocmd({ "WinNew", "WinEnter", "BufWinEnter" }, {
		group = vim.api.nvim_create_augroup("YetAnotherLine", { clear = true }),
		callback = function()
			vim.wo.statusline = ""
			vim.o.laststatus = 3
		end,
	})

	local events = { "ModeChanged", "BufEnter", "WinEnter", "BufWritePost", "DiagnosticChanged" }
	for _, event in ipairs(events) do
		vim.api.nvim_create_autocmd(event, {
			group = "YetAnotherLine",
			callback = update_statusline,
		})
	end
end

return M
