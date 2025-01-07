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
	["\\22"] = "YASVisualMode",
	R = "YASReplaceMode",
	c = "YASCmdMode",
	s = "YASOtherMode",
	S = "YASOtherMode",
	["\\19"] = "YASOtherMode",
	t = "YASOtherMode",
	Unknown = "YASOtherMode",
}

local function get_file_info()
	return vim.fn.expand("%:t"), vim.fn.expand("%:e")
end

M.mode = function()
	local mode = vim.api.nvim_get_mode().mode
	local hl = mode_hl[mode] or mode_hl.Unknown
	return {
		sl = "%#" .. hl .. "# ",
		events = { "ModeChanged" },
	}
end

M.file = function()
	local file_name, file_extension = get_file_info()
	local ok, devicons = pcall(require, "nvim-web-devicons")
	if not ok then
		return ""
	end

	local icon, color = devicons.get_icon_color(file_name, file_extension, { default = true })
	local hl_group = "YASFileIcon" .. file_extension
	local bg_color = vim.api.nvim_get_hl_by_name("YetAnotherLineBackground", true).background

	vim.api.nvim_set_hl(0, hl_group, { fg = color, bg = bg_color, bold = true })

	return {
		sl = "%#" .. hl_group .. "#" .. icon .. " " .. file_name,
		events = { "BufEnter", "BufWritePost" },
	}
end

M.git_info = function()
	local ok, dict = pcall(vim.api.nvim_buf_get_var, 0, "gitsigns_status_dict")
	if not ok then
		return { sl = "", events = { "BufEnter", "BufWritePost", "BufWinEnter" } }
	end

	local added = dict.added and dict.added > 0 and ("%#YASGitAdded# " .. dict.added .. " ") or ""
	local changed = dict.changed and dict.changed > 0 and ("%#YASGitChanged# " .. dict.changed .. " ") or ""
	local removed = dict.removed and dict.removed > 0 and ("%#YASGitRemoved# " .. dict.removed .. " ") or ""

	return {
		sl = "%#YASGitBranch# -> " .. (dict.head .. " " or "") .. added .. changed .. removed,
		events = { "BufEnter", "BufWritePost", "BufWinEnter" },
	}
end

M.lsp_server = function()
	for _, client in ipairs(vim.lsp.get_active_clients()) do
		if client.attached_buffers[vim.api.nvim_get_current_buf()] then
			return {
				sl = "%#YASLspStatus#  " .. client.name,
				events = { "BufEnter" },
			}
		end
	end
	return { sl = "", events = { "BufEnter" } }
end

M.lsp_diagnostics = function()
	local diagnostics = {
		errors = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.ERROR }),
		warnings = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.WARN }),
		hints = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.HINT }),
		info = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.INFO }),
	}

	local fmt = function(severity, icon)
		return diagnostics[severity] > 0
				and ("%#YASLsp" .. severity:sub(1, 1):upper() .. severity:sub(2) .. "#" .. icon .. " " .. diagnostics[severity] .. " ")
			or ""
	end

	return {
		sl = fmt("errors", "") .. fmt("warnings", "") .. fmt("hints", "ﯧ") .. fmt("info", ""),
		events = { "BufEnter", "BufWritePost", "DiagnosticChanged" },
	}
end

M.build_statusline = function()
	local modules = {
		M.mode(),
		M.file(),
		"%=",
		M.git_info(),
		"%=",
		M.lsp_diagnostics(),
		M.lsp_server(),
	}

	local statusline = ""
	for _, module in ipairs(modules) do
		if type(module) == "string" then
			statusline = statusline .. module
		elseif type(module) == "table" and module.sl then
			statusline = statusline .. module.sl
		end
	end

	return statusline
end

M.update_statusline = function()
	vim.wo.statusline = "%!v:lua.require('yetanotherline').build_statusline()"
end

M.setup = function()
	setup_highlights()
	vim.api.nvim_create_augroup("YetAnotherLine", { clear = true })
	for name, module in pairs(M) do
		if type(module) == "function" and name ~= "setup" and name ~= "update_statusline" then
			local mod_events = module().events
			if mod_events then
				for _, event in ipairs(mod_events) do
					vim.api.nvim_create_autocmd(event, {
						group = "YetAnotherLine",
						callback = M.update_statusline,
					})
				end
			end
		end
	end
end

return M
