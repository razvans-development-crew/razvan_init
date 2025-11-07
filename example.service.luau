-- example.service (without the .luau suffix)
--!nolint DeprecatedApi

return function(...)
  local output = getfenv().output
  pcall(getfenv().remove_global_vars)

  return output.info(...)
end
