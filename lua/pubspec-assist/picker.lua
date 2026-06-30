local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local conf = require("telescope.config").values
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")

local config = require("pubspec-assist.config")
local installer = require("pubspec-assist.installer")
local preview = require("pubspec-assist.preview")
local pubdev = require("pubspec-assist.pubdev")
local utils = require("pubspec-assist.utils")

local M = {}

---@param package table
---@return string
local function display(package)
	if package.kind == "heading" then
		return package.name
	end

	local cfg = config.get()
	local parts = {
		string.format("%s %-32s", cfg.icons.package, package.name or ""),
		string.format("%s %s", cfg.icons.star, utils.compact_number(package.likes)),
	}

	if package.version and package.version ~= "" then
		table.insert(parts, "v" .. package.version)
	end
	if package.popularity then
		table.insert(parts, utils.bar(package.popularity) .. " " .. utils.percent(package.popularity))
	end
	if package.pub_points and package.pub_points > 0 then
		table.insert(parts, "Pub Points " .. package.pub_points)
	end
	if package.publisher and package.publisher ~= "" then
		table.insert(parts, "Publisher " .. package.publisher)
	end
	if package.installed then
		table.insert(parts, cfg.icons.check .. " Installed")
	end
	if package.update_available then
		table.insert(parts, cfg.icons.update .. " Update")
	end

	local line = table.concat(parts, "  ")
	if package.description and package.description ~= "" then
		return line .. "  -  " .. package.description
	end
	return line
end

---@param packages table[]
---@return table
local function finder(packages)
	return finders.new_table({
		results = packages,
		entry_maker = function(entry)
			return {
				value = entry,
				display = display(entry),
				ordinal = table.concat({
					entry.name or "",
					entry.description or "",
					entry.publisher or "",
				}, " "),
			}
		end,
	})
end

---@param packages table[]
---@return table[]
local function mark_installed(packages)
	local installed = utils.installed_map()
	for _, package in ipairs(packages) do
		package.installed = installed[package.name] == true
	end
	return packages
end

---@return table[]
local function read_history()
	local history = utils.read_json_file(config.get().history_file, {})
	if type(history) ~= "table" then
		return {}
	end
	return history
end

---@param query string
local function save_history(query)
	query = vim.trim(query or "")
	if query == "" then
		return
	end

	local history = read_history()
	local next_history = { query }
	for _, item in ipairs(history) do
		if item ~= query and #next_history < 25 then
			table.insert(next_history, item)
		end
	end
	utils.write_json_file(config.get().history_file, next_history)
end

---@return table
local function read_favorites()
	local favorites = utils.read_json_file(config.get().favorites_file, {})
	if type(favorites) ~= "table" then
		return {}
	end
	return favorites
end

---@param package string
local function save_favorite(package)
	local favorites = read_favorites()
	for _, name in ipairs(favorites) do
		if name == package then
			utils.notify(package .. " is already in favorites")
			return
		end
	end
	table.insert(favorites, package)
	table.sort(favorites)
	utils.write_json_file(config.get().favorites_file, favorites)
	utils.notify("Saved favorite " .. package)
end

---@param prompt_bufnr integer
---@return table|nil
local function selected(prompt_bufnr)
	local selection = action_state.get_selected_entry()
	if not selection or selection.value.kind then
		utils.notify("No package selected", vim.log.levels.WARN)
		return nil
	end
	return selection.value
end

---@param prompt_bufnr integer
---@param package table
local function with_full_package(prompt_bufnr, package, callback)
	if package.version and package.version ~= "" then
		callback(package)
		return
	end

	pubdev.full_package(package.name, function(full, err)
		if not full then
			utils.notify(err or "Package not found", vim.log.levels.ERROR)
			return
		end
		callback(full)
	end)
end

---@param prompt_bufnr integer
---@param mode string
local function attach_package_actions(prompt_bufnr, mode)
	actions.select_default:replace(function()
		local package = selected(prompt_bufnr)
		if not package then
			return
		end
		if mode == "project" then
			with_full_package(prompt_bufnr, package, preview.open_details)
		else
			actions.close(prompt_bufnr)
			installer.install(package.name)
		end
	end)

	local insert_maps = {
		["<C-p>"] = function()
			local package = selected(prompt_bufnr)
			if package then
				preview.open_readme(package)
			end
		end,
		["<C-l>"] = function()
			local package = selected(prompt_bufnr)
			if package then
				preview.open_changelog(package)
			end
		end,
		["<C-v>"] = function()
			local package = selected(prompt_bufnr)
			if package then
				pubdev.versions(package.name, function(versions, err)
					if not versions then
						utils.notify(err or "Versions not found", vim.log.levels.ERROR)
						return
					end
					preview.open_versions(versions, package.name)
				end)
			end
		end,
		["<C-d>"] = function()
			local package = selected(prompt_bufnr)
			if package then
				with_full_package(prompt_bufnr, package, preview.open_dependencies)
			end
		end,
		["<C-r>"] = function()
			local package = selected(prompt_bufnr)
			if package then
				actions.close(prompt_bufnr)
				installer.remove(package.name)
			end
		end,
		["<C-u>"] = function()
			local package = selected(prompt_bufnr)
			if package then
				actions.close(prompt_bufnr)
				installer.upgrade(package.name)
			end
		end,
		["<C-o>"] = function()
			local package = selected(prompt_bufnr)
			if package then
				utils.open_url("https://pub.dev/packages/" .. package.name)
			end
		end,
		["<C-y>"] = function()
			local package = selected(prompt_bufnr)
			if package then
				vim.fn.setreg("+", package.name)
				utils.notify("Copied " .. package.name)
			end
		end,
		["<C-f>"] = function()
			local package = selected(prompt_bufnr)
			if package then
				save_favorite(package.name)
			end
		end,
	}

	local normal_maps = vim.tbl_extend("force", insert_maps, {
		["i"] = function()
			local package = selected(prompt_bufnr)
			if package then
				with_full_package(prompt_bufnr, package, preview.open_details)
			end
		end,
		["o"] = function()
			local package = selected(prompt_bufnr)
			if package then
				utils.open_url("https://pub.dev/packages/" .. package.name)
			end
		end,
		["r"] = function()
			local package = selected(prompt_bufnr)
			if package then
				actions.close(prompt_bufnr)
				installer.remove(package.name)
			end
		end,
		["u"] = function()
			local package = selected(prompt_bufnr)
			if package then
				actions.close(prompt_bufnr)
				installer.upgrade(package.name)
			end
		end,
	})

	for lhs, rhs in pairs(insert_maps) do
		vim.keymap.set({ "i", "n" }, lhs, rhs, { buffer = prompt_bufnr, silent = true })
	end

	for lhs, rhs in pairs(normal_maps) do
		if not lhs:match("^<C%-") then
			vim.keymap.set("n", lhs, rhs, { buffer = prompt_bufnr, silent = true })
		end
	end
end

---@param title string
---@param packages table[]
---@param opts? table
local function open_static(title, packages, opts)
	opts = opts or {}
	pickers
		.new(opts, {
			prompt_title = title,
			finder = finder(mark_installed(packages)),
			sorter = conf.generic_sorter(opts),
			previewer = preview.telescope(),
			attach_mappings = function(prompt_bufnr)
				attach_package_actions(prompt_bufnr, opts.mode or "search")
				return true
			end,
		})
		:find()
end

---@return table[]
local function recent_entries()
	local entries = {}
	for _, query in ipairs(read_history()) do
		table.insert(entries, { name = query, description = "Recent search", kind = "recent" })
	end
	return entries
end

function M.search()
	local cfg = config.get()
	local current_jobs = {}
	local timer = vim.uv.new_timer()
	local last_query = nil
	local picker_ref
	local generation = 0

	local function cancel_jobs()
		for _, job in ipairs(current_jobs) do
			if job.cancel then
				job.cancel()
			end
		end
		current_jobs = {}
	end

	local function refresh(items)
		if not picker_ref then
			return
		end
		picker_ref:refresh(finder(mark_installed(items)), { reset_prompt = false })
	end

	local function run_query(query)
		query = vim.trim(query or "")
		if query == last_query then
			return
		end
		last_query = query
		generation = generation + 1
		local request_generation = generation
		cancel_jobs()

		if query == "" then
			local entries = recent_entries()
			if #entries > 0 then
				table.insert(entries, 1, { name = "Recent Searches", kind = "heading" })
				refresh(entries)
			end
			current_jobs = { pubdev.trending(function(packages, err)
				if request_generation ~= generation then
					return
				end
				if err then
					utils.notify(err, vim.log.levels.ERROR)
					return
				end
				table.insert(packages, 1, { name = cfg.icons.fire .. " Trending Packages", kind = "heading" })
				refresh(packages)
				vim.list_extend(current_jobs, pubdev.enrich(packages, function(updated)
					if request_generation == generation then
						refresh(updated)
					end
				end))
			end) }
			return
		end

		save_history(query)
		current_jobs = { pubdev.search(query, function(packages, err)
			if request_generation ~= generation then
				return
			end
			if err then
				utils.notify(err, vim.log.levels.ERROR)
			end
			refresh(packages)
			vim.list_extend(current_jobs, pubdev.enrich(packages, function(updated)
				if request_generation == generation then
					refresh(updated)
				end
			end))
		end) }
	end

	local function schedule_query(query)
		timer:stop()
		timer:start(cfg.debounce_ms, 0, function()
			vim.schedule(function()
				run_query(query)
			end)
		end)
	end

	pickers
		.new({}, {
			prompt_title = "Pub.dev",
			finder = finder(recent_entries()),
			sorter = conf.generic_sorter({}),
			previewer = preview.telescope(),
			on_input_filter_cb = function(prompt)
				schedule_query(prompt)
				return { prompt = prompt }
			end,
			attach_mappings = function(prompt_bufnr)
				picker_ref = action_state.get_current_picker(prompt_bufnr)
				attach_package_actions(prompt_bufnr, "search")

				vim.schedule(function()
					run_query("")
				end)

				vim.api.nvim_create_autocmd("BufWipeout", {
					buffer = prompt_bufnr,
					once = true,
					callback = function()
						if not timer:is_closing() then
							timer:stop()
							timer:close()
						end
						cancel_jobs()
					end,
				})

				return true
			end,
		})
		:find()
end

function M.installed()
	local packages = {}
	for _, name in ipairs(utils.installed_packages()) do
		table.insert(packages, { name = name, installed = true })
	end

	if #packages == 0 then
		utils.notify("No dependencies found in pubspec.yaml", vim.log.levels.WARN)
		return
	end

	open_static("Installed Packages", packages, { mode = "project" })
end

function M.project()
	M.installed()
end

function M.outdated()
	installer.outdated(function(packages, err)
		if err then
			utils.notify(err, vim.log.levels.ERROR)
			return
		end
		open_static("Outdated Packages", packages, { mode = "project" })
	end)
end

---@param package string
function M.info(package)
	pubdev.full_package(package, function(full, err)
		if not full then
			utils.notify(err or "Package not found", vim.log.levels.ERROR)
			return
		end
		preview.open_details(full)
	end)
end

return M
