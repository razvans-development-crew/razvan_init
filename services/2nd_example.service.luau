-- 2nd_example.service (without .luau suffix)
--!nolint DeprecatedApi

return function(...)
  local modules = getfenv().modules
  local output = getfenv().output
  local example_module = require(modules['example.module'])

  pcall(getfenv().remove_global_vars)
  return output.info(example_module.greet("razvan_init")
end
