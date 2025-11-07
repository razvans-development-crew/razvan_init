-- init.config (without the .luau suffix)

return {
  services = {
    {
	  service_name = "example.service",
      args = {"hi", "these are", "arguments"}
    },
	{
	  service_name = "2nd_example.service",
      args = {}
    }
  }
}
