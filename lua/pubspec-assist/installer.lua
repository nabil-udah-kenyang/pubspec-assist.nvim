local utils = require("pubspec-assist.utils")

local M = {}

---@param args string[]
---@param success string
local function run_flutter(args, success)
	local root = utils.project_root()
	if not root then
		utils.notify("Missing pubspec.yaml. Open a Flutter/Dart project first.", vim.log.levels.ERROR)
		return
	end

	if vim.fn.executable("flutter") ~= 1 then
		utils.notify("Flutter SDK not found in PATH.", vim.log.levels.ERROR)
		return
	end

	utils.notify(table.concat(vim.list_extend({ "flutter" }, args), " "))
	vim.system(vim.list_extend({ "flutter" }, args), { cwd = root, text = true }, function(result)
		vim.schedule(function()
			if result.code == 0 then
				utils.notify(success)
			else
				utils.notify(vim.trim(result.stderr ~= "" and result.stderr or result.stdout), vim.log.levels.ERROR)
			end
		end)
	end)
end

---@param package string
function M.install(package)
	run_flutter({ "pub", "add", package }, "Installed " .. package)
end

---@param package string
function M.remove(package)
	run_flutter({ "pub", "remove", package }, "Removed " .. package)
end

---@param package string
function M.upgrade(package)
	run_flutter({ "pub", "upgrade", package }, "Upgraded " .. package)
end

---@param callback fun(packages:table[], err?:string)
function M.outdated(callback)
	local root = utils.project_root()
	if not root then
		callback({}, "Missing pubspec.yaml. Open a Flutter/Dart project first.")
		return
	end

	if vim.fn.executable("flutter") ~= 1 then
		callback({}, "Flutter SDK not found in PATH.")
		return
	end

	vim.system({ "flutter", "pub", "outdated", "--json" }, { cwd = root, text = true }, function(result)
		vim.schedule(function()
			if result.code ~= 0 then
				callback({}, vim.trim(result.stderr ~= "" and result.stderr or result.stdout))
				return
			end

			local ok, decoded = pcall(vim.json.decode, result.stdout)
			if not ok then
				callback({}, "Unable to parse flutter pub outdated output.")
				return
			end

			local packages = {}
			for _, item in ipairs(decoded.packages or {}) do
				table.insert(packages, {
					name = item.package,
					current = item.current and item.current.version,
					upgradable = item.upgradable and item.upgradable.version,
					resolvable = item.resolvable and item.resolvable.version,
					latest = item.latest and item.latest.version,
					update_available = item.current and item.latest and item.current.version ~= item.latest.version,
				})
			end
			callback(packages)
		end)
	end)
end

return M
