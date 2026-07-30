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
	if type(variableA) == "number" and type(variableB) == "number" then
		return (((1 - f) * (variableA :: number)) + ((variableB :: number) * f)) :: any
	end
	return (variableA :: any):Lerp(variableB, f)
end

return MathUtils
