if vim.g.loaded_pubspec_assist == 1 then
	return
end

vim.g.loaded_pubspec_assist = 1

require("pubspec-assist.commands").setup()
