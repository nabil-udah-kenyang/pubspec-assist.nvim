local M = {}

---@class PubspecAssistConfig
---@field debounce_ms integer
---@field cache_ttl integer
---@field max_results integer
---@field favorites_file string
---@field history_file string
---@field notify boolean
---@field icons table<string,string>

---@type PubspecAssistConfig
local defaults = {
	debounce_ms = 250,
	cache_ttl = 300,
	max_results = 20,
	favorites_file = vim.fn.stdpath("data") .. "/pubspec-assist/favorites.json",
	history_file = vim.fn.stdpath("data") .. "/pubspec-assist/history.json",
	notify = true,
	icons = {
		package = "󰏗",
		star = "",
		fire = "󰈸",
		check = "",
		update = "󰚰",
	},
}

---@type PubspecAssistConfig
local options = vim.deepcopy(defaults)

---@param user_config? PubspecAssistConfig
function M.setup(user_config)
	options = vim.tbl_deep_extend("force", vim.deepcopy(defaults), user_config or {})
end

---@return PubspecAssistConfig
function M.get()
	return options
end

return M
