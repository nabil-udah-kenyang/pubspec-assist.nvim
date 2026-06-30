local cache = require("pubspec-assist.cache")
local config = require("pubspec-assist.config")
local utils = require("pubspec-assist.utils")

local M = {}

local BASE_URL = "https://pub.dev/api"

---@class PubspecAssistJob
---@field cancel fun()

---@param path string
---@return string
local function url(path)
	return BASE_URL .. path
end

---@param key string
---@param request_url string
---@param callback fun(ok:boolean, data:any)
---@return PubspecAssistJob
local function request_json(key, request_url, callback)
	local cached = cache.get(key)
	if cached ~= nil then
		vim.schedule(function()
			callback(true, cached)
		end)
		return { cancel = function() end }
	end

	local done = false
	local job = vim.system({
		"curl",
		"--fail",
		"--silent",
		"--show-error",
		"--location",
		request_url,
	}, { text = true }, function(result)
		if done then
			return
		end
		done = true

		vim.schedule(function()
			if result.code ~= 0 then
				callback(false, (result.stderr ~= "" and result.stderr) or "Unable to reach pub.dev")
				return
			end

			local ok, decoded = pcall(vim.json.decode, result.stdout)
			if not ok then
				callback(false, "pub.dev returned invalid JSON")
				return
			end

			cache.set(key, decoded)
			callback(true, decoded)
		end)
	end)

	return {
		cancel = function()
			if done then
				return
			end
			done = true
			pcall(function()
				job:kill(15)
			end)
		end,
	}
end

---@param package string
---@return table
local function empty_package(package)
	return {
		name = package,
		description = "",
		version = "",
		publisher = "",
		likes = 0,
		popularity = 0,
		pub_points = 0,
	}
end

---@param package table
---@param detail table|nil
---@param score table|nil
---@return table
function M.normalize_package(package, detail, score)
	local pubspec = detail and detail.latest and detail.latest.pubspec or {}
	local latest = detail and detail.latest or {}
	local normalized = vim.tbl_deep_extend("force", empty_package(package.name or package.package), package)

	normalized.name = normalized.name or package.package
	normalized.description = pubspec.description or normalized.description or ""
	normalized.version = latest.version or normalized.version or ""
	normalized.publisher = (detail and detail.publisher) or normalized.publisher or ""
	normalized.repository = pubspec.repository or normalized.repository or ""
	normalized.homepage = pubspec.homepage or normalized.homepage or ""
	normalized.issue_tracker = pubspec.issue_tracker or normalized.issue_tracker or ""
	normalized.sdk = pubspec.environment and pubspec.environment.sdk or ""
	normalized.dependencies = pubspec.dependencies or {}
	normalized.dev_dependencies = pubspec.dev_dependencies or {}
	normalized.archive_url = latest.archive_url
	normalized.published = latest.published
	normalized.pub_url = "https://pub.dev/packages/" .. normalized.name

	if score then
		normalized.likes = score.likeCount or normalized.likes or 0
		normalized.popularity = score.popularityScore or normalized.popularity or 0
		normalized.pub_points = score.grantedPoints or normalized.pub_points or 0
		normalized.max_points = score.maxPoints or normalized.max_points or 0
	end

	return normalized
end

---@param query string
---@param callback fun(packages:table[], err?:string)
---@return PubspecAssistJob
function M.search(query, callback)
	query = vim.trim(query or "")
	if query == "" then
		vim.schedule(function()
			callback({})
		end)
		return { cancel = function() end }
	end

	local search_url = url("/search?q=" .. utils.url_encode(query))
	return request_json("search:" .. query:lower(), search_url, function(ok, data)
		if not ok then
			callback({}, data)
			return
		end

		local packages = {}
		for index, item in ipairs(data.packages or {}) do
			if index > config.get().max_results then
				break
			end
			table.insert(packages, empty_package(item.package))
		end
		callback(packages)
	end)
end

---@param package string
---@param callback fun(detail:table|nil, err?:string)
---@return PubspecAssistJob
function M.package(package, callback)
	return request_json("package:" .. package, url("/packages/" .. utils.url_encode(package)), function(ok, data)
		if not ok then
			callback(nil, data)
			return
		end
		callback(data)
	end)
end

---@param package string
---@param callback fun(score:table|nil, err?:string)
---@return PubspecAssistJob
function M.score(package, callback)
	return request_json("score:" .. package, url("/packages/" .. utils.url_encode(package) .. "/score"), function(ok, data)
		if not ok then
			callback(nil, data)
			return
		end
		callback(data)
	end)
end

---@param package string
---@param callback fun(versions:table|nil, err?:string)
---@return PubspecAssistJob
function M.versions(package, callback)
	return request_json("versions:" .. package, url("/packages/" .. utils.url_encode(package) .. "/versions"), function(ok, data)
		if not ok then
			callback(nil, data)
			return
		end
		callback(data)
	end)
end

---@param package string
---@param callback fun(package:table|nil, err?:string)
---@return PubspecAssistJob[]
function M.full_package(package, callback)
	local pending = 2
	local detail
	local score
	local first_error
	local jobs = {}

	local function finish()
		pending = pending - 1
		if pending > 0 then
			return
		end
		if not detail then
			callback(nil, first_error or "Package not found")
			return
		end
		callback(M.normalize_package({ name = package }, detail, score))
	end

	jobs[1] = M.package(package, function(data, err)
		detail = data
		first_error = first_error or err
		finish()
	end)

	jobs[2] = M.score(package, function(data, err)
		score = data
		first_error = first_error or err
		finish()
	end)

	return jobs
end

---@param packages table[]
---@param on_update fun(packages:table[])
---@return PubspecAssistJob[]
function M.enrich(packages, on_update)
	local jobs = {}
	for index, package in ipairs(packages) do
		if package.kind then
			goto continue
		end

		local name = package.name
		local pending = 2
		local detail
		local score

		local function finish()
			pending = pending - 1
			if pending > 0 then
				return
			end
			packages[index] = M.normalize_package(package, detail, score)
			on_update(packages)
		end

		table.insert(jobs, M.package(name, function(data)
			detail = data
			finish()
		end))
		table.insert(jobs, M.score(name, function(data)
			score = data
			finish()
		end))

		::continue::
	end
	return jobs
end

---@param callback fun(packages:table[], err?:string)
---@return PubspecAssistJob
function M.trending(callback)
	return M.search("flutter", function(packages, err)
		callback(packages, err)
	end)
end

return M
