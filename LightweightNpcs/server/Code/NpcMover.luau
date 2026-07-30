local module = {}

local NpcTypes = require(game.ServerScriptService.LightweightNpcs.Code.NpcTypes)
local MathUtils = require(game.ReplicatedFirst.LightweightNpcsClient.Utils.MathUtils)

-- Basic ultralightweight character controller
-- This controller follows one simple rule: the position of the character is only ever moved
-- to a location that has been guarenteed to be "clear" via a collision sweep.
-- It handles ramps and stairs via "StepUp" - whereby incomplete steps forward (we hit a step)
-- 	are repeated a small distance in the air.

local castParams = RaycastParams.new()
castParams.CollisionGroup = "NpcMovement"
castParams.RespectCanCollide = true

export type NpcMover = {
	HandleFallingState: (self: NpcMover, npcRecord: NpcTypes.npcRecordType, dt: number) -> (),
	ProcessMotionVectorIntoVelocity: (self: NpcMover, npcRecord: NpcTypes.npcRecordType, dt: number) -> (),
	HandleWalkingState: (self: NpcMover, npcRecord: NpcTypes.npcRecordType, dt: number) -> (),
	ProcessMovement: (self: NpcMover, npcRecord: NpcTypes.npcRecordType, dt: number) -> (),
	UpdateFacingAngle: (self: NpcMover, npcRecord: NpcTypes.npcRecordType, dt: number) -> (),
}

local function SweepMove(
	origin: Vector3,
	direction: Vector3,
	size: Vector3,
	params: RaycastParams?
): (Vector3, RaycastResult?)
	local mag = direction.Magnitude
	if mag < 0.001 then
		return origin, nil
	end

	local margin = 0.1
	local castSize = Vector3.new(size.X - margin, size.Y - margin, size.Z - margin) -- Don't use small sizes!

	local useParams = params or castParams

	-- Cast!
	local hitResults = game.Workspace:Blockcast(CFrame.new(origin), castSize, direction, useParams)

	if hitResults then
		-- Ground hit
		local distanceCovered = hitResults.Distance - margin
		return origin + (direction.Unit * distanceCovered), hitResults
	else
		-- We hit nothing, so it was a clean sweep? (at least for the smaller box)
		local distanceCovered = mag - margin
		return origin + (direction.Unit * distanceCovered), nil
	end
end

function module:HandleFallingState(npcRecord: NpcTypes.npcRecordType, dt: number)
	-- fall
	local previousVelocity = npcRecord.velocity
	npcRecord.velocity += npcRecord.configuration.gravity * dt

	--If the velocity was previously going up but is now going down
	--we apogeed and need to insert a replication point
	if previousVelocity.Y > 0 and npcRecord.velocity.Y <= 0 then
		npcRecord:ForceReplicate()
	end

	local velocity = npcRecord.velocity * dt

	-- Sweep
	local hitResults: RaycastResult?
	npcRecord.position, hitResults = SweepMove(npcRecord.position, velocity, npcRecord.configuration.motionSize)

	if hitResults then
		npcRecord.velocity = Vector3.new(npcRecord.velocity.X, 0, npcRecord.velocity.Z)
		npcRecord.onCrashland:Fire()
		--Make sure we push out a replication asap so we dont "mush" into the ground
		npcRecord:ForceReplicate()
	end
end

function module:ProcessMotionVectorIntoVelocity(npcRecord: NpcTypes.npcRecordType, dt: number)
	local moveVec: Vector3 = MathUtils:FlatVec(npcRecord.motionVector)
	local mag: number = moveVec.Magnitude

	--if mag > 0 then
	npcRecord.velocity = MathUtils:GroundAccelerate(
		moveVec,
		npcRecord.configuration.walkSpeed,
		npcRecord.configuration.walkAccel,
		npcRecord.velocity,
		dt
	)
	--end
end

function module:UpdateFacingAngle(npcRecord: NpcTypes.npcRecordType, dt: number)
	-- Signed shortest delta to target
	local delta = MathUtils:AngleShortest(npcRecord.angle, npcRecord.targetAngle)

	-- Max rotation this frame
	local maxStep = npcRecord.configuration.turnSpeed * dt

	if delta < 0 then
		if delta < -maxStep then
			delta = -maxStep
		end
	else
		if delta > maxStep then
			delta = maxStep
		end
	end

	-- Apply
	npcRecord.angle += delta
end

function module:ProcessMotionIntoTargetAngle(npcRecord: NpcTypes.npcRecordType)
	local moveVec: Vector3 = MathUtils:FlatVec(npcRecord.motionVector)
	local mag: number = moveVec.Magnitude

	if mag > 0 then
		npcRecord.targetAngle = MathUtils:PlayerVecToAngle(moveVec)
	end
end

function module:HandleWalkingState(npcRecord: NpcTypes.npcRecordType, dt: number)
	--Ground accelerate
	self:ProcessMotionVectorIntoVelocity(npcRecord, dt)

	--Facing
	self:ProcessMotionIntoTargetAngle(npcRecord)

	-- We have our velocity, see if we can update our position now
	-- Remember we only move the pos to places confirmed by SweepMove
	local velocity: Vector3 = npcRecord.velocity * dt
	local desiredMag = Vector3.new(velocity.X, 0, velocity.Z).Magnitude

	if desiredMag > 0.001 then
		local newPosition: Vector3
		local hitResults: RaycastResult?

		newPosition, hitResults = SweepMove(npcRecord.position, velocity, npcRecord.configuration.motionSize)
		local bumpedInstance = nil

		-- If we hit something we retry the move up in the air (stepup)
		if hitResults ~= nil then
			local startPos: Vector3 = npcRecord.position + Vector3.new(0, npcRecord.configuration.maximumStepHeight, 0)

			local stepupPosition: Vector3
			local stepupHitResults: RaycastResult?
			stepupPosition, stepupHitResults =
				SweepMove(startPos, velocity, npcRecord.configuration.motionSize, castParams)

			if stepupHitResults then
				bumpedInstance = stepupHitResults.Instance
			end

			if stepupHitResults == nil then
				-- Sweep down
				stepupPosition, stepupHitResults = SweepMove(
					stepupPosition,
					Vector3.new(0, -npcRecord.configuration.maximumStepHeight * 2, 0),
					npcRecord.configuration.motionSize,
					castParams
				)

				if stepupHitResults then
					newPosition = stepupPosition
				else
					-- print("??")
				end
			end
		end

		--If we didn't make it our whole length, consider this a bump

		local actualVec = (npcRecord.position - newPosition)
		local actualMag = Vector3.new(actualVec.X, 0, actualVec.Z).Magnitude
		if actualMag < desiredMag * 0.5 then -- we didn't even make it half way
			npcRecord.onBumpIntoWall:Fire(bumpedInstance)
			--High precision it.
			npcRecord:ForceReplicate()
		end

		npcRecord.position = newPosition
	end
end

function module:ProcessMovement(npcRecord: NpcTypes.npcRecordType, dt: number)
	assert(npcRecord.internal.deleteFlag == false)

	npcRecord.isOnGround = false

	-- Start with a "Are we on the ground" check
	local _dest: Vector3
	local hitResults: RaycastResult?
	_dest, hitResults = SweepMove(
		npcRecord.position,
		Vector3.new(0, -npcRecord.configuration.groundTolerance, 0),
		npcRecord.configuration.motionSize
	)

	if hitResults ~= nil then
		npcRecord.isOnGround = true
	end

	if npcRecord.jump == true then
		npcRecord.jump = false
		--print(npcRecord.npcId, "jump", npcRecord.velocity)
		npcRecord.velocity = Vector3.new(0, npcRecord.configuration.jumpPower, 0)
		npcRecord:ForceReplicate()

		npcRecord.isOnGround = false
	end

	-- Moving state
	if npcRecord.isOnGround == true then
		self:HandleWalkingState(npcRecord, dt)
	else
		self:HandleFallingState(npcRecord, dt)
	end

	self:UpdateFacingAngle(npcRecord, dt)

	-- Fell out of the map
	if npcRecord.position.Y < -500 then
		npcRecord.onFellOffMap:Fire()
		npcRecord.internal.deleteFlag = true
		return
	end

	npcRecord.hitBox.Position = npcRecord.position
end

return module :: NpcMover
