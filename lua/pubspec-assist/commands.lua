local M = {}

function M.setup()
	vim.api.nvim_create_user_command("PubspecSearch", function()
		require("pubspec-assist").search()
	end, { desc = "Search pub.dev packages" })

	vim.api.nvim_create_user_command("PubspecInstalled", function()
		require("pubspec-assist").installed()
	end, { desc = "Show dependencies from pubspec.yaml" })

	vim.api.nvim_create_user_command("PubspecProject", function()
		require("pubspec-assist").project()
	end, { desc = "Manage project dependencies" })

	vim.api.nvim_create_user_command("PubspecOutdated", function()
		require("pubspec-assist").outdated()
	end, { desc = "Show packages reported by flutter pub outdated" })

	vim.api.nvim_create_user_command("PubspecInfo", function(opts)
		local package = vim.trim(opts.args or "")
		if package == "" then
			vim.notify("Usage: :PubspecInfo package_name", vim.log.levels.ERROR, { title = "pubspec-assist.nvim" })
			return
		end
		require("pubspec-assist").info(package)
	end, {
		nargs = 1,
		complete = function()
			return require("pubspec-assist.utils").installed_packages()
		end,
		desc = "Show package information",
	})
end

return M
