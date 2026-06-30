local M = {}

---@param opts? table
function M.setup(opts)
	require("pubspec-assist.config").setup(opts)
end

function M.search()
	require("pubspec-assist.picker").search()
end

function M.installed()
	require("pubspec-assist.picker").installed()
end

function M.project()
	require("pubspec-assist.picker").project()
end

function M.outdated()
	require("pubspec-assist.picker").outdated()
end

---@param package string
function M.info(package)
	require("pubspec-assist.picker").info(package)
end

return M
