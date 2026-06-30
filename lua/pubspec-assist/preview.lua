local previewers = require("telescope.previewers")
local utils = require("pubspec-assist.utils")

local M = {}

---@param value any
---@return string[]
local function dependency_lines(value)
	local lines = {}
	if type(value) ~= "table" then
		return lines
	end

	local names = vim.tbl_keys(value)
	table.sort(names)
	for _, name in ipairs(names) do
		local constraint = value[name]
		if type(constraint) == "string" then
			table.insert(lines, "- " .. name .. " " .. constraint)
		else
			table.insert(lines, "- " .. name)
		end
	end
	return lines
end

---@param package table
---@return string[]
function M.package_lines(package)
	local lines = {
		"# " .. (package.name or "Package"),
		"",
		package.description or "No description available.",
		"",
		"Latest Version: " .. (package.version ~= "" and package.version or "N/A"),
		"Publisher: " .. (package.publisher ~= "" and package.publisher or "N/A"),
		"Likes: " .. utils.compact_number(package.likes),
		"Popularity: " .. utils.percent(package.popularity),
		"Pub Points: " .. tostring(package.pub_points or "N/A"),
		"Repository: " .. ((package.repository and package.repository ~= "") and package.repository or "N/A"),
		"Homepage: " .. ((package.homepage and package.homepage ~= "") and package.homepage or "N/A"),
		"License: See pub.dev package page",
		"SDK Constraints: " .. ((package.sdk and package.sdk ~= "") and package.sdk or "N/A"),
		"Repository URL: " .. ((package.repository and package.repository ~= "") and package.repository or "N/A"),
		"Pub.dev URL: " .. (package.pub_url or ("https://pub.dev/packages/" .. package.name)),
		"Release Date: " .. (package.published or "N/A"),
		"",
		"## Dependencies",
	}

	local deps = dependency_lines(package.dependencies)
	if #deps == 0 then
		table.insert(lines, "- None")
	else
		vim.list_extend(lines, deps)
	end

	if package.dev_dependencies and next(package.dev_dependencies) then
		table.insert(lines, "")
		table.insert(lines, "## Dev Dependencies")
		vim.list_extend(lines, dependency_lines(package.dev_dependencies))
	end

	table.insert(lines, "")
	table.insert(lines, "## README")
	table.insert(lines, "README content is opened from pub.dev in the browser when full package docs are needed.")

	return lines
end

---@return table
function M.telescope()
	return previewers.new_buffer_previewer({
		title = "Package Details",
		define_preview = function(self, entry)
			local package = entry.value or {}
			vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, M.package_lines(package))
			vim.bo[self.state.bufnr].filetype = "markdown"
		end,
	})
end

---@param package table
function M.open_details(package)
	utils.float(package.name or "Package Details", M.package_lines(package), { filetype = "markdown" })
end

---@param package table
function M.open_dependencies(package)
	local lines = { "# " .. package.name .. " dependencies", "" }
	local deps = dependency_lines(package.dependencies)
	if #deps == 0 then
		table.insert(lines, "No dependencies found.")
	else
		vim.list_extend(lines, deps)
	end
	utils.float(package.name .. " dependencies", lines, { filetype = "markdown" })
end

---@param package table
function M.open_readme(package)
	utils.open_url("https://pub.dev/packages/" .. package.name)
end

---@param package table
function M.open_changelog(package)
	utils.open_url("https://pub.dev/packages/" .. package.name .. "/changelog")
end

---@param versions table
---@param package_name string
function M.open_versions(versions, package_name)
	local lines = { "# " .. package_name .. " versions", "" }
	for _, version in ipairs(versions.versions or {}) do
		table.insert(lines, "- " .. version.version .. (version.published and (" - " .. version.published) or ""))
	end
	utils.float(package_name .. " versions", lines, { filetype = "markdown" })
end

return M
