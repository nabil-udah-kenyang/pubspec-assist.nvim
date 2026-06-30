local M = {}

---@param message string
---@param level? integer
function M.notify(message, level)
	if require("pubspec-assist.config").get().notify then
		vim.notify(message, level or vim.log.levels.INFO, { title = "pubspec-assist.nvim" })
	end
end

---@param value string
---@return string
function M.url_encode(value)
	return (tostring(value):gsub("([^%w%-%_%.%~])", function(char)
		return string.format("%%%02X", string.byte(char))
	end))
end

---@param value number|nil
---@return string
function M.compact_number(value)
	value = tonumber(value) or 0
	if value >= 1000000 then
		return string.format("%.1fM", value / 1000000)
	end
	if value >= 1000 then
		return string.format("%.1fK", value / 1000)
	end
	return tostring(value)
end

---@param percent number|nil
---@return string
function M.percent(percent)
	if not percent then
		return "N/A"
	end
	return tostring(math.floor((percent * 100) + 0.5)) .. "%"
end

---@param percent number|nil
---@return string
function M.bar(percent)
	local filled = math.floor(((percent or 0) * 10) + 0.5)
	filled = math.max(0, math.min(10, filled))
	return string.rep("█", filled) .. string.rep("░", 10 - filled)
end

---@param path string
---@return boolean
function M.file_exists(path)
	return vim.uv.fs_stat(path) ~= nil
end

---@return string|nil
function M.find_pubspec()
	local current = vim.fn.expand("%:p:h")
	if current == "" then
		current = vim.uv.cwd()
	end
	local found = vim.fs.find("pubspec.yaml", { upward = true, path = current })[1]
	return found
end

---@return string|nil
function M.project_root()
	local pubspec = M.find_pubspec()
	if not pubspec then
		return nil
	end
	return vim.fs.dirname(pubspec)
end

---@return boolean
function M.is_flutter_project()
	local pubspec = M.find_pubspec()
	if not pubspec then
		return false
	end
	local lines = vim.fn.readfile(pubspec)
	for _, line in ipairs(lines) do
		if line:match("^%s*flutter%s*:") or line:match("^%s*sdk%s*:%s*flutter%s*$") then
			return true
		end
	end
	return false
end

---@param path string
---@return table<string,boolean>
local function read_yaml_sections(path)
	local installed = {}
	local section = nil
	local lines = vim.fn.readfile(path)

	for _, line in ipairs(lines) do
		local top = line:match("^([%w_%-]+):%s*$")
		if top then
			section = top
		end

		if section == "dependencies" or section == "dev_dependencies" then
			local name = line:match("^%s%s([%w_%-]+)%s*:")
			if name and name ~= "sdk" and name ~= "flutter" then
				installed[name] = true
			end
		elseif top then
			section = top
		end
	end

	return installed
end

---@return table<string,boolean>
function M.installed_map()
	local pubspec = M.find_pubspec()
	if not pubspec then
		return {}
	end
	return read_yaml_sections(pubspec)
end

---@return string[]
function M.installed_packages()
	local packages = {}
	for name, _ in pairs(M.installed_map()) do
		table.insert(packages, name)
	end
	table.sort(packages)
	return packages
end

---@param file string
---@param fallback any
---@return any
function M.read_json_file(file, fallback)
	if not M.file_exists(file) then
		return fallback
	end
	local ok, decoded = pcall(vim.json.decode, table.concat(vim.fn.readfile(file), "\n"))
	if not ok then
		return fallback
	end
	return decoded
end

---@param file string
---@param value any
function M.write_json_file(file, value)
	vim.fn.mkdir(vim.fs.dirname(file), "p")
	vim.fn.writefile({ vim.json.encode(value) }, file)
end

---@param title string
---@param lines string[]
---@param opts? table
function M.float(title, lines, opts)
	opts = opts or {}
	local width = opts.width or math.floor(vim.o.columns * 0.72)
	local height = opts.height or math.floor(vim.o.lines * 0.72)
	width = math.max(40, math.min(width, vim.o.columns - 4))
	height = math.max(10, math.min(height, vim.o.lines - 4))

	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	vim.bo[buf].filetype = opts.filetype or "markdown"

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		style = "minimal",
		border = "rounded",
		title = " " .. title .. " ",
		title_pos = "center",
		width = width,
		height = height,
		row = math.floor((vim.o.lines - height) / 2),
		col = math.floor((vim.o.columns - width) / 2),
	})

	vim.keymap.set("n", "q", function()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end, { buffer = buf, nowait = true, silent = true })
	vim.keymap.set("n", "<Esc>", function()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end, { buffer = buf, nowait = true, silent = true })
end

---@param url string
function M.open_url(url)
	if vim.ui and vim.ui.open then
		vim.ui.open(url)
		return
	end

	local command = vim.fn.has("mac") == 1 and "open" or "xdg-open"
	vim.system({ command, url }, { text = true }, function(result)
		if result.code ~= 0 then
			vim.schedule(function()
				M.notify("Unable to open " .. url, vim.log.levels.ERROR)
			end)
		end
	end)
end

return M
