local M = {}

local augroup_name = "YetAnotherLine"
local augroup_id = nil
local icon_hl_cache = {}
local sl_bg = nil

local to_hex = function(color)
	return string.format("#%06x", color)
end

local function get_statusline_bg()
	local hl = vim.api.nvim_get_hl(0, { name = "StatusLine", link = false })
	if hl.bg then
		return to_hex(hl.bg)
	end
	return "#2E3440"
end

local function build_hl_colors(bg)
	return {
		YASNorMode = { bg = bg, fg = "#ec5f67" },
		YASInsertMode = { bg = bg, fg = "#98be65" },
		YASVisualMode = { bg = bg, fg = "#51afef" },
		YASReplaceMode = { bg = bg, fg = "#c678dd" },
		YASCmdMode = { bg = bg, fg = "#FF8800" },
		YASOtherMode = { bg = bg, fg = "#83a598" },
		YASGitAdded = { bg = bg, fg = "#98be65" },
		YASGitChanged = { bg = bg, fg = "#FF8800" },
		YASGitRemoved = { bg = bg, fg = "#ec5f67" },
		YASGitBranch = { bg = bg, fg = "#a9a1e1" },
		YASLspStatus = { bg = bg, fg = "#ec5f67" },
		YASLspError = { bg = bg, fg = "#ec5f67" },
		YASLspWarnings = { bg = bg, fg = "#FF8800" },
		YASLspHints = { bg = bg, fg = "#a9a1e1" },
		YASLspInfo = { bg = bg, fg = "#51afef" },
	}
end

local function setup_highlights()
	sl_bg = get_statusline_bg()
	icon_hl_cache = {}

	local hl_colors = build_hl_colors(sl_bg)
	for group, colors in pairs(hl_colors) do
		vim.api.nvim_set_hl(0, group, { fg = colors.fg, bg = colors.bg })
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

local severity = vim.diagnostic.severity

local function empty_space(length)
	return string.rep("%=", length or 0)
end

M.build_statusline = function()
	local mode = vim.api.nvim_get_mode().mode
	local hl = mode_hl[mode] or mode_hl.Unknown
	local file_name = vim.fn.expand("%:t")
	local file_ext = vim.fn.expand("%:e")

	local icon = ""
	local ok, devicons = pcall(require, "nvim-web-devicons")
	if ok then
		local ic, color = devicons.get_icon_color(file_name, file_ext, { default = true })
		local hl_group = "YASFileIcon" .. file_ext

		if not icon_hl_cache[file_ext] then
			vim.api.nvim_set_hl(0, hl_group, { fg = color, bg = sl_bg, bold = true })
			icon_hl_cache[file_ext] = true
		end

		icon = "%#" .. hl_group .. "#" .. ic
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
	for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
		if client.name ~= "copilot" then
			lsp = "%#YASLspStatus#  " .. client.name
			break
		end
	end

	local all_diags = vim.diagnostic.get(0)
	local counts = { 0, 0, 0, 0 }
	for _, d in ipairs(all_diags) do
		local s = d.severity
		if s then
			counts[s] = (counts[s] or 0) + 1
		end
	end

	local diags = ""
	if counts[severity.ERROR] > 0 then
		diags = diags .. "%#YASLspError# " .. counts[severity.ERROR] .. " "
	end
	if counts[severity.WARN] > 0 then
		diags = diags .. "%#YASLspWarnings# " .. counts[severity.WARN] .. " "
	end
	if counts[severity.HINT] > 0 then
		diags = diags .. "%#YASLspHints# " .. counts[severity.HINT] .. " "
	end
	if counts[severity.INFO] > 0 then
		diags = diags .. "%#YASLspInfo# " .. counts[severity.INFO] .. " "
	end

	return "%#"
		.. hl
		.. "# "
		.. icon
		.. " "
		.. file_name
		.. " "
		.. empty_space(1)
		.. git
		.. empty_space(20)
		.. diags
		.. lsp
		.. " %l:%c "
end

local function update_statusline()
	vim.o.laststatus = 3
	vim.o.statusline = "%!v:lua.require('yetanotherline').build_statusline()"
end

M.setup = function()
	setup_highlights()
	update_statusline()

	augroup_id = vim.api.nvim_create_augroup(augroup_name, { clear = true })

	vim.api.nvim_create_autocmd({ "WinNew", "WinEnter", "BufWinEnter" }, {
		group = augroup_id,
		callback = function()
			vim.wo.statusline = ""
			vim.o.laststatus = 3
		end,
	})

	vim.api.nvim_create_autocmd(
		{ "ModeChanged", "BufEnter", "WinEnter", "BufWritePost", "DiagnosticChanged" },
		{
			group = augroup_id,
			callback = update_statusline,
		}
	)

	vim.api.nvim_create_autocmd("ColorScheme", {
		group = augroup_id,
		callback = function()
			setup_highlights()
			update_statusline()
		end,
	})
end

M.disable = function()
	if augroup_id then
		vim.api.nvim_del_augroup_by_id(augroup_id)
		augroup_id = nil
	end
	vim.o.statusline = ""
	vim.o.laststatus = 2
end

return M
