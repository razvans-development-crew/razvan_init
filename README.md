# razvan_init
a simple service manager for ROBLOX script builders

## usage
1. create a server script in `ServerScriptService`, name could be `init` or `razvan_init` for example.
2. paste the contents of the `razvan_init.server.luau` script (which is located in this repository) into the script you just created.
3. the service manager expects the folders `services`, `modules` and `config` to be inside of the script. the service manager will shut down the server if they do not exist.
4. the service manager also expects a `ModuleScript` with the name of `init.config` to be inside of the `config` folder. the service manager will shut down the server if it does not exist, because it holds the configuration for the service manager and for the services themselves.
5. the service manager will automatically `require` `ModuleScripts` that are inside of the `services` folder and parent them to `nil` (which is a security precaution to prevent indexing of the main script). access to the `modules` and `config` folder will also be exposed to every service. if the service manager does not find configuration for a service, the service will not be ran.

## recommendations
- because the service manager exposes access to variables (such as `internal_service_storage`, `modules`, `config`, `output` and `utils`) through the function environment (usually retrieved through using `getfenv()`), it is strongly recommended to localize the variables you need, then remove them from the function environment. the service manager exposes a function (`remove_global_vars`) that removes access to the variables in the function environment so that you dont have to inline the same exact code into every service. this is required if you impose strict restrictions on script execution.

## tips
- in case you need to pass arguments to a service, change up the `args` value in the service's configuration entry in the `init.config` script. below is an example:
  
  ```luau
  -- init.config
  
  return {
  	services = {
  		["example.service"] = {
  			service_name = "example.service",
  			args = {"hi", "these are", "arguments"}
  		}
  	}
  }
  ```

  ```luau
  -- example.service

  return function(...)
    local output = getfenv().output
    pcall(getfenv().remove_global_vars)

    return output.info(...)
  end
  ```

  example output:
  
  ```
         [razvan_init] >> starting example.service...
         [razvan_init / example.service] >> hi these are arguments
  [ OK ] [razvan_init] >> example.service successfully started in 0.00154329019021349 seconds
  ```

## FAQ
### why do script builders need a service manager?
it's simple, the code is modular if it is separated in services.
