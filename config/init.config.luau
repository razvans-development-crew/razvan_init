-- init.config (without the .luau suffix)

return {
	services = {
		["example.service"] = {
			service_name = "example.service",
			args = {"hi", "these are", "arguments"}
		}
	}
}
