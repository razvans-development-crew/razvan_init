-- init.config (without the .luau suffix)

return {
  services = {
    ["example.service"] = {
      args = {"hi", "these are", "arguments"}
    },
		["2nd_example.service"] = {
      args = {}
    }
  }
}
