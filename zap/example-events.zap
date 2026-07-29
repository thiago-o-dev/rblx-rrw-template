-- You can create many of these, this is just an example
opt server_output = "../src/server/Network/Generated/Net_ExampleEventsServer.lua"
opt client_output = "../src/shared/Network/Generated/Net_ExampleEventsClient.lua"
-- They need specific remote_scopes
opt remote_scope = "EXAMPLE1"
-- To better follow the roblox naming conventions
opt casing = "camelCase"

type MatchStateData = struct {
	MatchId: string.utf8,
	CurrentPhase: string.utf8,
	TimeElapsedMiliseconds: u16,
	IsClockRunning: boolean,
	Scores: u8[1..],
	CurrentHalf: u8
}

event MatchStateStream = {
	from: Server,
	type: Reliable,
	call: ManyAsync,
	data: MatchStateData,
}

type BallData = struct {
	BallSpeedVector: vector(f32, f32, f32),
	BallRotationVector: vector(f32, f32, f32),
	BallCurrentPosition: vector(f32, f32, f32),
	Ball150Prediction: vector(f32, f32, f32),
}

event BallStream = {
	from: Server,
	type: Reliable,
	call: ManyAsync,
	data: BallData,
}

event StartCamera = {
	from: Server,
	type: Reliable,
	call: SingleAsync,
	data: struct {
		Center: vector(f32, f32, f32),
	}, -- Creating the data here is possible
}

event EndCamera = {
	from: Server,
	type: Reliable,
	call: SingleAsync,
	data: struct { } -- No payload needed, just a trigger
}