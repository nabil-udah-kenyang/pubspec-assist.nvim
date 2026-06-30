local M = {}

local function ok(message)
	vim.health.ok(message)
end

local function warn(message)
	vim.health.warn(message)
end

local function error(message)
	vim.health.error(message)
end

function M.check()
	vim.health.start("pubspec-assist.nvim")

	if vim.fn.has("nvim-0.10") == 1 then
		ok("Neovim >= 0.10")
	else
		error("Neovim >= 0.10 is required")
	end

	if pcall(require, "telescope") then
		ok("telescope.nvim is installed")
	else
		error("telescope.nvim is required")
	end

	if vim.fn.executable("curl") == 1 then
		ok("curl is available")
	else
		error("curl is required for pub.dev API requests")
	end

	if vim.fn.executable("flutter") == 1 then
		ok("flutter is available")
	else
		warn("flutter not found in PATH; install/remove/upgrade/outdated commands will fail")
	end

	if require("pubspec-assist.utils").find_pubspec() then
		ok("pubspec.yaml found")
	else
		warn("No pubspec.yaml found from the current buffer")
	end
end

return M
