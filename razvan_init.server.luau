--!optimize 2
--!nolint DeprecatedApi

-- razvan_init
-- service manager for script builders

script.Parent = nil

local INIT_START = tick()

local script = script
local getfenv = getfenv
local setfenv = setfenv
local next = next
local tick = tick
local require = require
local game = game or workspace.Parent

local task = task
local task_spawn = task.spawn

local players = game:GetService('Players');
local run_service = game:GetService('RunService');
local http = game:GetService('HttpService');

local services = script:FindFirstChild("services")
local modules = script:FindFirstChild("modules")
local config = script:FindFirstChild("config")

local init_config = require(config:FindFirstChild("init.config"))

local running_services = {}
local CONSOLE_OUTPUT_PREFIXES = {
	ok = "[  OK  ] [razvan_init] >>",
	warning = "[ WARN ] [razvan_init] >>",
	fail = "[ FAIL ] [razvan_init] >>",
	info = "         [razvan_init] >>",
}

local output
do
	output = {}

	function output.ok(...)
		print(CONSOLE_OUTPUT_PREFIXES.ok, ...)
	end

	function output.warning(...)
		warn(CONSOLE_OUTPUT_PREFIXES.warning, ...)
	end

	function output.fail(...)
		warn(CONSOLE_OUTPUT_PREFIXES.fail, ...)
	end

	function output.info(...)
		print(CONSOLE_OUTPUT_PREFIXES.info, ...)
	end
end

local utils
do
	utils = {}

	function utils.shutdown_server(reason)
		local start = tick()
		output.warning("server is being forcibly shut down:", reason)

		for _, player in next, players:GetPlayers() do
			output.info("(shutdown) kicking player:", player.Name)
			player:Kick("[razvan_init] server is being forcibly shut down. reason: " .. reason)
		end

		players.PlayerAdded:Connect(function(player)
			output.info("(shutdown) kicking player:", player.Name)
			player:Kick(
				"[razvan_init] server has been forcibly shut down. reason: "
					.. reason
					.. ". if this persists, please wait 2 minutes."
			)
		end)

		output.info("(shutdown) stopping services...")
		for _, service in ipairs(running_services) do
			local service_name, _service_executable, service_object =
				service.service_name, service.service_executable, service.service_object

			output.info("(shutdown) stopping", service_name)
			local success, result = pcall(game.Destroy, service_object)

			if not success then
				output.fail("(shutdown) failed to stop", service_name, "with error:", result)
			else
				output.ok("(shutdown) successfully stopped", service_name)
			end
		end

		return output.ok("finished shutdown in", tick() - start, "seconds")
	end

	function utils.check_signal_behavior()
		local is_deferred = false

		local bindable = Instance.new("BindableEvent")
		local bindable_callback_ran = false

		bindable.Event:Connect(function()
			bindable_callback_ran = true
		end)

		bindable:Fire()
		bindable:Destroy()

		if not bindable_callback_ran then
			is_deferred = true
		end

		return is_deferred
	end
end

local internal_service_storage = setmetatable({}, {
	__metatable = "The metatable is locked",
})

task.spawn(function()
	print([[                                  
                                                     _       _ _   
                 _ __ __ _ ______   ____ _ _ __     (_)_ __ (_) |_ 
                | '__/ _` |_  /\ \ / / _` | '_ \    | | '_ \| | __|
                | | | (_| |/ /  \ V / (_| | | | |   | | | | | | |_ 
                |_|  \__,_/___|  \_/ \__,_|_| |_|___|_|_| |_|_|\__|
                                               |_____|             ]])
	warn("================================================================================")
end)

task.spawn(function()
	if not config then
		return output.fail("startup failed: config folder is non-existent"),
			utils.shutdown_server("NON_EXISTENT_CONFIG_FOLDER")
	end

	if not init_config then
		return output.fail("startup failed: config folder is missing init.config"),
			utils.shutdown_server("MISSING_INIT_CONFIG")
	end

	if typeof(init_config) ~= "table" then
		return output.fail("startup failed: init config is invalid (not a table)"),
			utils.shutdown_server("INVALID_INIT_CONFIG")
	end

	if not init_config["services"] then
		return output.fail("startup failed: init config is invalid (missing `services` config)"),
			utils.shutdown_server("INVALID_INIT_CONFIG")
	end

	if not modules then
		return output.fail("startup failed: modules folder is non-existent"),
			utils.shutdown_server("NON_EXISTENT_MODULES_FOLDER")
	end

	if not services then
		return output.fail("startup failed: services folder is non-existent"),
			utils.shutdown_server("NON_EXISTENT_SERVICES_FOLDER")
	end

	if not pcall(loadstring, "return 1") then
		return output.warning("loadstring is disabled, please enable it through ServerScriptService.LoadstringEnabled.")
	end

	if not utils.check_signal_behavior() then
		return output.warning("signal behavior is not deferred.")
	end

	if run_service:IsStudio() then
		return output.warning("server is running in studio")
	end

	if not pcall(http.GetAsync, "https://google.com") then
		return output.warning("HttpService is disabled, please enable it through the game's settings.")
	end

	return nil
end)

task.spawn(function()
	-- for the sake of preventing indexing of the main script

	-- also done before the anti-tamper is initialized so that 
	-- the service manager doesnt triger its own anti tamper
	config.Parent = nil
	modules.Parent = nil
	services.Parent = nil

	local function anti_tamper_callback()
		return output.warning("init has been tampered with, shutting down"),
			utils.shutdown_server("INIT_TAMPERING_FOUND")
	end

	script.Destroying:Connect(anti_tamper_callback)
	script.AncestryChanged:Connect(anti_tamper_callback)
	script.ChildAdded:Connect(anti_tamper_callback)
	script.ChildRemoved:Connect(anti_tamper_callback)
end)

task_spawn(function(...)
	for service_index, service_entry in next, init_config.services do
		-- reiterating over the services config instead of the services folder in order to support a priority system
		local service = services:FindFirstChild(service_index)

		if service then
			if typeof(service) == "Instance" then -- might be unnecessary to include this check since im calling the GetChildren API method, which only returns instances
				if service:IsA("ModuleScript") then
					service.Parent = nil -- to prevent indexing of the service manager's main script

					local start = tick()

					local service_name = (function()
						return string.gsub(service.Name, "service", "") .. "service"
					end)()

					local service_init_config = init_config.services[service.Name] or init_config.services[service_name]

					if not service_init_config then
						output.warning(service_name, "will not be started because it is missing an init config")
						continue
					end

					output.info("starting", service_name .. "...")

					local service_executable = require(service)
					local orig_service_env = getfenv(service_executable)

					if typeof(service_executable) ~= "function" then
						output.warning(
							service_name,
							"will not be started because it does not return an executable function"
						)

						continue
					end

					table.insert(running_services, {
						service_name = service_name,
						service_executable = service_executable,
						service_object = service,
					})

					local success, result = pcall(function(...)
						return setfenv(
							service_executable,
							setmetatable({
								modules = modules,
								config = config,
								output = {
									ok = setfenv(function(...)
										print("[  OK  ] [razvan_init / " .. service_name .. "] >>", ...)
									end, orig_service_env),
									warning = setfenv(function(...)
										warn("[ WARN ] [razvan_init / " .. service_name .. "] >>", ...)
									end, orig_service_env),
									fail = setfenv(function(...)
										warn("[ FAIL ] [razvan_init / " .. service_name .. "] >>", ...)
									end, orig_service_env),
									info = setfenv(function(...)
										print("         [razvan_init / " .. service_name .. "] >>", ...)
									end, orig_service_env),
								},
								utils = utils,
								service_name = service_name,
								internal_service_storage = internal_service_storage,
								remove_global_vars = setfenv(function()
									setfenv(
										service_executable,
										setmetatable({}, {
											__index = getfenv(0),
											__metatable = "The metatable is locked",
										})
									)

									return output.info("global variables have been removed from", service_name)
								end, orig_service_env),
								args = { ... },
							}, {
								__index = function(self, key)
									if key == "script" then
										return nil
									end

									return orig_service_env[key]
								end,
								__metatable = "The metatable is locked",
							})
						)(table.unpack(service_init_config.args))
					end)

					if not success then
						output.fail("failed to start", service_name, "with error:", result)
						return utils.shutdown_server("SERVICE_START_FAILED")
					end

					output.ok(service_name, "successfully started in", tick() - start, "seconds")
				end
			end
		end
	end

	return nil
end)

task.spawn(function()
	game:BindToClose(function(close_reason)
		local start = tick()
		output.warning("server is being closed with reason:", close_reason)

		output.info("(shutdown) stopping services...")
		for _, service in ipairs(running_services) do
			local service_name, _service_executable, service_object =
				service.service_name, service.service_executable, service.service_object

			output.info("(shutdown) stopping", service_name)
			local success, result = pcall(game.Destroy, service_object)

			if not success then
				output.fail("(shutdown) failed to stop", service_name, "with error:", result)
			else
				output.ok("(shutdown) successfully stopped", service_name)
			end
		end

		return output.ok("finished service shutdown in", tick() - start, "seconds")
	end)
end)

-- finish
return output.ok("finished startup to hand over control to services in", tick() - INIT_START, "seconds")
