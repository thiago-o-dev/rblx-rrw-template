-- You can create many of these, this is just an example
opt server_output = "../src/server/Network/Generated/Net_ExampleEvents2Server.lua"
opt client_output = "../src/shared/Network/Generated/Net_ExampleEvents2Client.lua"
-- They need specific remote_scopes, cannot repeat
opt remote_scope = "EXAMPLE2"
opt casing = "camelCase"

event ExampleTrigger = {
	from: Server,
	type: Reliable,
	call: SingleAsync,
	data: struct { } -- No payload needed, just a trigger
}