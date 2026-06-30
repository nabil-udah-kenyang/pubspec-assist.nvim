local config = require("pubspec-assist.config")

local M = {}

---@type table<string,{expires_at:number,value:any}>
local memory = {}

local function now()
	return vim.uv.now() / 1000
end

---@param key string
---@return any|nil
function M.get(key)
	local item = memory[key]
	if not item then
		return nil
	end

	if item.expires_at <= now() then
		memory[key] = nil
		return nil
	end

	return item.value
end

---@param key string
---@param value any
---@param ttl? integer
function M.set(key, value, ttl)
	memory[key] = {
		value = value,
		expires_at = now() + (ttl or config.get().cache_ttl),
	}
end

---@param key string
function M.delete(key)
	memory[key] = nil
end

function M.clear()
	memory = {}
end

return M
