# LightweightUnit - Shared Utilities, Types & Zap Protocol

## 1. Overview & Principles

The shared layer of **LightweightUnit** lives in `src/shared/` and `zap/`. In accordance with [architecture.md](file:///C:/Users/Thiago/source/repos/Roblox/rblx-rrw-template/docs/architecture.md), shared modules contain **only types, immutable archetype definitions, pure mathematical algorithms, data structures, and networking interfaces**.

Key Shared Components:
- `src/shared/Types/UnitTypes.luau`: Strict Luau types used by both client and server.
- `src/shared/Definitions/UnitDefinitions.luau`: Preset configurations for unit archetypes.
- `src/shared/Core/MathUtils.luau`: Native mathematical functions.
- `src/shared/Core/RingBuffer.luau`: $O(1)$ constant-time timeline queue.
- `src/shared/Core/Signal.luau`: Fast event emitter.
- `zap/unit-replication.zap`: Declarative network schema.

---

## 2. Universal Type Definitions: `UnitTypes.luau`

```lua
--!strict
local Signal = require(script.Parent.Parent.Core.Signal)

export type UnitId = number

export type UnitState = {
	position: Vector3,
	facingAngle: number,
	velocity: Vector3,
	isOnGround: boolean,
}

export type UnitConfig = {
	unitType: string,
	templateModel: Model,
	thinkHz: number,
	replicationHz: number,
	hitboxSize: Vector3,
	walkSpeed: number,
	walkAccel: number,
	turnSpeed: number,
	jumpPower: number,
	gravity: Vector3,
	stepHeight: number,
	groundTolerance: number,
	canCollide: boolean,
	animations: { [string]: number },
}

export type UnitInternal = {
	timeOfNextThink: number,
	timeOfNextReplicate: number,
	timeOfNextCullCheck: number,
	forceReplicate: boolean,
	deleteFlag: boolean,
	pendingAnimations: { [number]: number },
	playerVisibleMap: { [Player]: boolean },
}

export type UnitRecord = {
	unitId: UnitId,
	hitBox: Part,
	templateModel: Model,
	config: UnitConfig,
	internal: UnitInternal,
	position: Vector3,
	facingAngle: number,
	targetAngle: number,
	velocity: Vector3,
	motionVector: Vector3,
	isOnGround: boolean,
	jumpRequested: boolean,
	playingAnimations: { [number]: number },
	data: { [string]: any },
	onThink: Signal.Signal,
	onDeath: Signal.Signal,
	onCleanup: Signal.Signal,
}

export type PlayerRecord = {
	player: Player,
	isReady: boolean,
	visibleUnits: { [UnitId]: boolean },
}

export type TimelineSnapshot = {
	timestamp: number,
	cframe: CFrame,
}

export type ClientUnitRecord = {
	unitId: UnitId,
	model: Model,
	animator: Animator?,
	timeline: any, -- RingBuffer instance
	eventline: { [number]: { timestamp: number, animIndex: number, channel: number } },
	currentCFrame: CFrame,
	isPlaced: boolean,
	isLoaded: boolean,
	replicationHz: number,
	invHz: number,
}

return {}
```

---

## 3. Archetype Definitions: `UnitDefinitions.luau`

```lua
--!strict
local UnitTypes = require(script.Parent.Parent.Types.UnitTypes)

local DEFAULT_RIGS = game:GetService("ReplicatedStorage"):WaitForChild("Assets"):WaitForChild("Rigs")

local UnitDefinitions = {}

local DEFINITIONS: { [string]: UnitTypes.UnitConfig } = {
	Player = {
		unitType = "Player",
		templateModel = DEFAULT_RIGS:WaitForChild("Robert") :: Model,
		thinkHz = 10,
		replicationHz = 10,
		hitboxSize = Vector3.new(3, 6, 3),
		walkSpeed = 16,
		walkAccel = 20,
		turnSpeed = math.rad(360),
		jumpPower = 50,
		gravity = Vector3.new(0, -workspace.Gravity, 0),
		stepHeight = 2.5,
		groundTolerance = 0.5,
		canCollide = true,
		animations = { Idle = 1, Walk = 2, Run = 3 },
	},
	Goalkeeper = {
		unitType = "Goalkeeper",
		templateModel = DEFAULT_RIGS:WaitForChild("Robert") :: Model,
		thinkHz = 15,
		replicationHz = 10,
		hitboxSize = Vector3.new(3, 6, 3),
		walkSpeed = 14,
		walkAccel = 25,
		turnSpeed = math.rad(450),
		jumpPower = 65,
		gravity = Vector3.new(0, -workspace.Gravity, 0),
		stepHeight = 2.5,
		groundTolerance = 0.5,
		canCollide = true,
		animations = { Idle = 1, DiveLeft = 4, DiveRight = 5 },
	},
	Spectator = {
		unitType = "Spectator",
		templateModel = DEFAULT_RIGS:WaitForChild("Bob") :: Model,
		thinkHz = 2,
		replicationHz = 2,
		hitboxSize = Vector3.new(2, 5, 2),
		walkSpeed = 0,
		walkAccel = 0,
		turnSpeed = math.rad(90),
		jumpPower = 0,
		gravity = Vector3.new(0, -workspace.Gravity, 0),
		stepHeight = 1.0,
		groundTolerance = 0.5,
		canCollide = false,
		animations = { Sit = 10, Cheer = 11 },
	},
}

function UnitDefinitions.getDefinition(unitType: string): UnitTypes.UnitConfig?
	return DEFINITIONS[unitType]
end

return UnitDefinitions
```

---

## 4. Mathematics Helper Library: `MathUtils.luau`

```lua
--!strict
--!native
local TWO_PI = math.pi * 2

local MathUtils = {}

function MathUtils.angleAbs(angle: number): number
	angle = angle % TWO_PI
	if angle < 0 then
		angle += TWO_PI
	end
	return angle
end

function MathUtils.angleShortest(a0: number, a1: number): number
	local d1 = MathUtils.angleAbs(a1 - a0)
	local d2 = -MathUtils.angleAbs(a0 - a1)
	return (math.abs(d1) > math.abs(d2)) and d2 or d1
end

function MathUtils.playerVecToAngle(vec: Vector3): number
	return math.atan2(vec.X, vec.Z)
end

function MathUtils.flatVec(vec: Vector3): Vector3
	return Vector3.new(vec.X, 0, vec.Z)
end

function MathUtils.groundAccelerate(
	wishDir: Vector3,
	wishSpeed: number,
	accel: number,
	velocity: Vector3,
	dt: number
): Vector3
	local speed = velocity.Magnitude
	if speed > wishSpeed then
		velocity = velocity.Unit * wishSpeed
	end

	local wishVel = wishDir * wishSpeed
	local pushDir = wishVel - velocity
	local pushLen = pushDir.Magnitude

	local canPush = accel * dt * wishSpeed
	if canPush > pushLen then
		canPush = pushLen
	end

	if canPush < 0.00001 then
		return velocity
	end

	return velocity + (canPush * pushDir.Unit)
end

function MathUtils.smoothLerp<T>(variableA: T, variableB: T, fraction: number, deltaTime: number): T
	local f = 1.0 - math.pow(1.0 - fraction, deltaTime)
	if type(variableA) == "number" then
		return (((1 - f) * (variableA :: number)) + ((variableB :: number) * f)) :: any
	end
	return (variableA :: any):Lerp(variableB, f)
end

return MathUtils
```

---

## 5. Constant-Time Queue: `RingBuffer.luau`

To eliminate the $O(N)$ CPU bottleneck caused by `table.remove(timeline, 1)` in `LightweightNpcsClientModule.luau`, **LightweightUnit** uses a fixed-capacity ring buffer:

```lua
--!strict
local RingBuffer = {}
RingBuffer.__index = RingBuffer

export type RingBuffer<T> = {
	data: { T },
	capacity: number,
	head: number,
	tail: number,
	count: number,
	push: (self: RingBuffer<T>, item: T) -> (),
	pop: (self: RingBuffer<T>) -> T?,
	get: (self: RingBuffer<T>, index: number) -> T?,
	clear: (self: RingBuffer<T>) -> (),
}

function RingBuffer.new<T>(capacity: number): RingBuffer<T>
	local self = setmetatable({
		data = table.create(capacity),
		capacity = capacity,
		head = 1,
		tail = 1,
		count = 0,
	}, RingBuffer)
	return (self :: any) :: RingBuffer<T>
end

function RingBuffer:push(item: any)
	self.data[self.tail] = item
	self.tail = (self.tail % self.capacity) + 1
	if self.count < self.capacity then
		self.count += 1
	else
		self.head = (self.head % self.capacity) + 1 -- Overwrite oldest
	end
end

function RingBuffer:pop(): any?
	if self.count == 0 then
		return nil
	end
	local item = self.data[self.head]
	self.data[self.head] = nil
	self.head = (self.head % self.capacity) + 1
	self.count -= 1
	return item
end

function RingBuffer:get(index: number): any?
	if index < 1 or index > self.count then
		return nil
	end
	local actualIndex = ((self.head + index - 2) % self.capacity) + 1
	return self.data[actualIndex]
end

function RingBuffer:clear()
	table.clear(self.data)
	self.head = 1
	self.tail = 1
	self.count = 0
end

return RingBuffer
```

---

## 6. Zap Network Schema: `zap/unit-replication.zap`

```zap
opt server_output = "../src/server/Network/Generated/UnitReplicationServer.luau"
opt client_output = "../src/shared/Network/Generated/UnitReplicationClient.luau"
opt remote_scope = "UNIT_ENGINE"
opt casing = "camelCase"

type UnitTransform = struct {
	unitId: u16,
	position: vector(f32, f32, f32),
	angle: f16,
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
		transforms: UnitTransform[],
	}
}

event UnitAnimationBatch = {
	from: Server,
	type: Reliable,
	call: SingleAsync,
	data: struct {
		serverTime: f64,
		animations: UnitAnimationUpdate[],
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
```

---
*Cross-References*:
- [System Overview](file:///C:/Users/Thiago/source/repos/Roblox/rblx-rrw-template/docs/LightweightNpcs/in-depth/overview.md)
- [Server Subsystem](file:///C:/Users/Thiago/source/repos/Roblox/rblx-rrw-template/docs/LightweightNpcs/in-depth/server.md)
- [Client Subsystem](file:///C:/Users/Thiago/source/repos/Roblox/rblx-rrw-template/docs/LightweightNpcs/in-depth/client.md)
