opt server_output = "../src/server/Network/Generated/Net_UnitServer.luau"
opt client_output = "../src/shared/Network/Generated/Net_UnitClient.luau"
opt remote_scope = "UNIT"
opt casing = "camelCase"

type UnitTransform = struct {
	unitId: u16,
	position: vector(f32, f32, f32),
	angle: f32,
}

type UnitAnimationUpdate = struct {
	unitId: u16,
	channel: u8,
	animIndex: u8,
}

event InitialUnitState = {
	from: Server,
	type: Reliable,
	call: SingleAsync,
	data: struct {
		unitId: u16,
		templateModel: Instance,
		replicationHz: u8,
		position: vector(f32, f32, f32),
		angle: f32,
	}
}

event UnitPositionBatch = {
	from: Server,
	type: Unreliable,
	call: SingleAsync,
	data: struct {
		serverTime: f64,
		transforms: UnitTransform[..50],
	}
}

event UnitAnimationBatch = {
	from: Server,
	type: Reliable,
	call: SingleAsync,
	data: struct {
		serverTime: f64,
		animations: UnitAnimationUpdate[..50],
	}
}

event UnitDespawn = {
	from: Server,
	type: Reliable,
	call: SingleAsync,
	data: struct {
		unitId: u16,
	}
}