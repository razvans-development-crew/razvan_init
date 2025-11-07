# razvan_init
a simple, fast service manager for ROBLOX script builders

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
      {
        service_name = "example.service",
        args = {"hi", "these are", "arguments"}
      }
    }
  }
  ```

  ```luau
  -- example.service
  --!nolint DeprecatedApi

  return function(...)
    local output = getfenv().output
    pcall(getfenv().remove_global_vars)

    return output.info(...)
  end
  ```

  example output:
  
  ```
  20:11:08.407           [razvan_init] >> starting example.service...  -  Server
  20:11:08.407  [  OK  ] [razvan_init] >> global variables have been removed from example.service  -  Server
  20:11:08.407           [razvan_init / example.service] >> hi these are arguments  -  Server
  20:11:08.408  [  OK  ] [razvan_init] >> example.service successfully started in 0.0013179779052734375 seconds  -  Server
  ```
- modules can be put inside the `modules` folder. the service manager will expose the `modules` folder to every service through the function environment (as mentioned earlier)
  ```luau
  -- example.module

  return {
    greet = function(name)
        return "hi "..name
    end
  }
  ```

  ```luau
  -- init.config

  return {
    services = {
      {
        service_name = "2nd_example.service",
        args = {}
      }
    }
  }
  ```

  ```luau
  -- 2nd_example.service
  --!nolint DeprecatedApi

  return function(...)
    local modules = getfenv().modules
    local output = getfenv().output
    local example_module = require(modules['example.module'])

    pcall(getfenv().remove_global_vars)
    return output.info(example_module.greet("razvan_init"))
  end
  ```

  example output:

  ```
  20:11:08.405           [razvan_init] >> starting 2nd_example.service...  -  Server
  20:11:08.405  [  OK  ] [razvan_init] >> global variables have been removed from 2nd_example.service  -  Server
  20:11:08.406           [razvan_init / 2nd_example.service] >> hi razvan_init  -  Server
  20:11:08.406  [  OK  ] [razvan_init] >> 2nd_example.service successfully started in 0.0014750957489013672 seconds  -  Server
  ```
- services will start depending on how they're ordered in the `init.config` script. for example, if `example.service` is on the first index of the `services` configuration entry and `2nd_example.service` is on the second index, `example.service` will always start first.
- the service manager will remove access to the global variables (`modules`, `config` and so on) after 5 seconds if they havent been removed yet.
  ```
  20:07:51.117           [razvan_init] >> starting 2nd_example.service...  -  Server
  20:07:51.119           [razvan_init / 2nd_example.service] >> hi razvan_init  -  Server
  20:07:51.120  [  OK  ] [razvan_init] >> 2nd_example.service successfully started in 0.003445863723754883 seconds  -  Server
  20:07:51.120           [razvan_init] >> starting example.service...  -  Server
  20:07:51.121  [  OK  ] [razvan_init] >> global variables have been removed from example.service  -  Server
  20:07:51.121           [razvan_init / example.service] >> hi these are arguments  -  Server
  20:07:51.122  [  OK  ] [razvan_init] >> example.service successfully started in 0.0014312267303466797 seconds  -  Server
  20:07:51.122  [  OK  ] [razvan_init] >> finished startup to hand over control to services in 0.007096052169799805 seconds  -  Server
  20:07:56.148  [ WARN ] [razvan_init] >> global variables have not been removed from 2nd_example.service within the timeframe of 5 seconds, removing...  -  Server
  20:07:56.148  [  OK  ] [razvan_init] >> global variables have been removed from 2nd_example.service  -  Server
  ```
- you can share objects or data across services using the `internal_service_storage` table. basically, it acts as `_G`, difference being that its only public to the services.

## FAQ
### why do script builders need a service manager?
it's simple, the code is modular if it is separated in services.
