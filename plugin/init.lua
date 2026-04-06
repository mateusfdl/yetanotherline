if vim.g.loaded_yetanotherline then
	return
end
vim.g.loaded_yetanotherline = true

require("yetanotherline").setup()
