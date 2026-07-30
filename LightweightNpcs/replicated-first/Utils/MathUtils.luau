--!strict
--!native

local THETA = math.pi * 2

export type MathUtils = {
	AngleAbs: (self: MathUtils, angle: number) -> number,
	AngleShortest: (self: MathUtils, a0: number, a1: number) -> number,
	LerpAngle: (self: MathUtils, a0: number, a1: number, frac: number) -> number,

	PlayerVecToAngle: (self: MathUtils, vec: Vector3) -> number,
	PlayerAngleToVec: (self: MathUtils, angle: number) -> Vector3,

	Friction: (self: MathUtils, val: number, fric: number, deltaTime: number) -> number,
	VelocityFriction: (self: MathUtils, vel: Vector3, fric: number, deltaTime: number) -> Vector3,

	FlatVec: (self: MathUtils, vec: Vector3) -> Vector3,

	GroundAccelerate: (
		self: MathUtils,
		wishDir: Vector3,
		wishSpeed: number,
		accel: number,
		velocity: Vector3,
		dt: number
	) -> Vector3,

	Accelerate: (
		self: MathUtils,
		wishDir: Vector3,
		wishSpeed: number,
		accel: number,
		velocity: Vector3,
		dt: number
	) -> Vector3,

	CapVelocity: (self: MathUtils, velocity: Vector3, maxSpeed: number) -> Vector3,

	ClipVelocity: (self: MathUtils, input: Vector3, normal: Vector3, overbounce: number) -> Vector3,

	-- SmoothLerp overloads
	SmoothLerp: <T>(
		self: MathUtils,
		variableA: T,
		variableB: T,
		fraction: number,
		deltaTime: number
	) -> T,

	ValidVector3: (self: MathUtils, vec: any) -> boolean,

	PickRandom: <T>(self: MathUtils, tab: { T }) -> T,

	AngleLerp: (a: number, b: number, fraction: number) -> number,
}

local MathUtils = {} :: MathUtils

function MathUtils:AngleAbs(angle: number): number
	angle = angle % THETA
	if angle < 0 then
		angle = angle + THETA
	end
	return angle
end

function MathUtils:AngleShortest(a0: number, a1: number): number
	local d1 = self:AngleAbs(a1 - a0)
	local d2 = -self:AngleAbs(a0 - a1)
	return (math.abs(d1) > math.abs(d2)) and d2 or d1
end

function MathUtils:LerpAngle(a0: number, a1: number, frac: number): number
	return a0 + self:AngleShortest(a0, a1) * frac
end

function MathUtils:PlayerVecToAngle(vec: Vector3): number
	return math.atan2(vec.X, vec.Z)
end

function MathUtils:PlayerAngleToVec(angle: number): Vector3
	return Vector3.new(math.sin(angle), 0, math.cos(angle))
end

-- dt variable decay function
function MathUtils:Friction(val: number, fric: number, deltaTime: number): number
	return (1 / (1 + (deltaTime / fric))) * val
end

function MathUtils:VelocityFriction(vel: Vector3, fric: number, deltaTime: number): Vector3
	local speed = vel.Magnitude
	speed = self:Friction(speed, fric, deltaTime)

	if speed < 0.001 then
		return Vector3.zero
	end

	return vel.Unit * speed
end

function MathUtils:FlatVec(vec: Vector3): Vector3
	return Vector3.new(vec.X, 0, vec.Z)
end

-- Redirects velocity
function MathUtils:GroundAccelerate(
	wishDir: Vector3,
	wishSpeed: number,
	accel: number,
	velocity: Vector3,
	dt: number
): Vector3
	-- Cap velocity
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

function MathUtils:Accelerate(
	wishDir: Vector3,
	wishSpeed: number,
	accel: number,
	velocity: Vector3,
	dt: number
): Vector3
	local speed = velocity.Magnitude

	local currentSpeed = velocity:Dot(wishDir)
	local addSpeed = wishSpeed - currentSpeed
	if addSpeed <= 0 then
		return velocity
	end

	local accelSpeed = accel * dt * wishSpeed
	if accelSpeed > addSpeed then
		accelSpeed = addSpeed
	end

	velocity = velocity + (accelSpeed * wishDir)

	-- If we're already going over max speed, don't go any faster than that
	-- Or you'll get strafe jumping!
	if speed > wishSpeed and velocity.Magnitude > speed then
		velocity = velocity.Unit * speed
	end

	return velocity
end

function MathUtils:CapVelocity(velocity: Vector3, maxSpeed: number): Vector3
	local mag = velocity.Magnitude
	mag = math.min(mag, maxSpeed)

	if mag > 0.01 then
		return velocity.Unit * mag
	end

	return Vector3.zero
end

function MathUtils:ClipVelocity(input: Vector3, normal: Vector3, overbounce: number): Vector3
	local backoff = input:Dot(normal)

	if backoff < 0 then
		backoff = backoff * overbounce
	else
		backoff = backoff / overbounce
	end

	local changex = normal.X * backoff
	local changey = normal.Y * backoff
	local changez = normal.Z * backoff

	return Vector3.new(input.X - changex, input.Y - changey, input.Z - changez)
end

-- Smoothlerp for Luau. "Zeno would be proud!"
-- Use it in a feedback loop over multiple frames to converge A towards B, in a deltaTime safe way
-- eg: cameraPos = SmoothLerp(cameraPos, target, 0.5, deltaTime)
-- Handles numbers and types that implement Lerp like Vector3 and CFrame
function MathUtils:SmoothLerp(variableA: any, variableB: any, fraction: number, deltaTime: number): any
	local f = 1.0 - math.pow(1.0 - fraction, deltaTime)

	if type(variableA) == "number" then
		return ((1 - f) * (variableA :: number)) + ((variableB :: number) * f)
	end

	-- Anything else must provide :Lerp(goal, alpha)
	return (variableA :: any):Lerp(variableB, f)
end

function MathUtils:AngleLerp(a: number, b: number, fraction: number): number
	-- normalize delta to (-pi, pi]
	local delta = (b - a + math.pi) % (2 * math.pi) - math.pi

	return a + delta * fraction
end

function MathUtils:ValidVector3(vec: any): boolean
	if vec == nil then
		return false
	end
	if typeof(vec) ~= "Vector3" then
		return false
	end
	local v = vec :: Vector3
	if v.X ~= v.X or v.Y ~= v.Y or v.Z ~= v.Z then
		return false
	end
	return true
end

function MathUtils:PickRandom<T>(tab: { T }): T
	local n = #tab
	assert(n > 0, "PickRandom called with empty table")
	return tab[math.random(1, n)]
end

return MathUtils
