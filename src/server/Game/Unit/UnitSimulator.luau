--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MathUtils = require(ReplicatedStorage.Shared.Core.MathUtils)
local UnitTypes = require(ReplicatedStorage.Shared.Types.UnitTypes)

local castParams = RaycastParams.new()
castParams.CollisionGroup = "Default"
castParams.RespectCanCollide = true

local UnitSimulator = {}

local function sweepMove(origin: Vector3, direction: Vector3, size: Vector3): (Vector3, RaycastResult?)
	local distance = direction.Magnitude
	if distance < 0.001 then
		return origin, nil
	end

	local margin = 0.05
	local sweepSize = Vector3.new(size.X - margin, size.Y - margin, size.Z - margin)
	local hitResult = workspace:Blockcast(CFrame.new(origin), sweepSize, direction, castParams)

	if hitResult then
		local covered = math.max(0, hitResult.Distance - margin)
		return origin + (direction.Unit * covered), hitResult
	end

	return origin + direction, nil
end

function UnitSimulator.processMovement(unit: UnitTypes.UnitRecord, dt: number)
	-- Ground check sweep
	local _groundPos, groundHit =
		sweepMove(unit.position, Vector3.new(0, -unit.config.groundTolerance, 0), unit.config.hitboxSize)
	unit.isOnGround = (groundHit ~= nil)

	-- Jump handling
	if unit.jumpRequested and unit.isOnGround then
		unit.jumpRequested = false
		unit.velocity = Vector3.new(unit.velocity.X, unit.config.jumpPower, unit.velocity.Z)
		unit.isOnGround = false
		unit.internal.forceReplicate = true
	end

	-- Horizontal Walking or Falling
	if unit.isOnGround then
		UnitSimulator.handleWalking(unit, dt)
	else
		UnitSimulator.handleFalling(unit, dt)
	end

	-- Rotate facing angle towards target
	UnitSimulator.updateFacingAngle(unit, dt)

	-- Fallen parts check
	if unit.position.Y < workspace.FallenPartsDestroyHeight then
		unit.internal.deleteFlag = true
		return
	end

	-- Update server hitbox position
	unit.hitBox.Position = unit.position
end

function UnitSimulator.handleWalking(unit: UnitTypes.UnitRecord, dt: number)
	local moveDir = MathUtils.flatVec(unit.motionVector)
	unit.velocity = MathUtils.groundAccelerate(moveDir, unit.config.walkSpeed, unit.config.walkAccel, unit.velocity, dt)

	if moveDir.Magnitude > 0.001 then
		unit.targetAngle = MathUtils.playerVecToAngle(moveDir)
	end

	local moveDelta = unit.velocity * dt
	if moveDelta.Magnitude > 0.001 then
		local newPos, hitResult = sweepMove(unit.position, moveDelta, unit.config.hitboxSize)

		-- StepUp logic for stairs
		if hitResult ~= nil then
			local stepStart = unit.position + Vector3.new(0, unit.config.stepHeight, 0)
			local stepPos, stepHit = sweepMove(stepStart, moveDelta, unit.config.hitboxSize)
			if not stepHit then
				local dropPos, dropHit =
					sweepMove(stepPos, Vector3.new(0, -unit.config.stepHeight * 1.5, 0), unit.config.hitboxSize)
				if dropHit then
					newPos = dropPos
				end
			end
		end
		unit.position = newPos
	end
end

function UnitSimulator.handleFalling(unit: UnitTypes.UnitRecord, dt: number)
	unit.velocity += unit.config.gravity * dt
	local moveDelta = unit.velocity * dt
	local newPos, hitResult = sweepMove(unit.position, moveDelta, unit.config.hitboxSize)

	if hitResult then
		unit.velocity = Vector3.new(unit.velocity.X, 0, unit.velocity.Z)
		unit.internal.forceReplicate = true
	end
	unit.position = newPos
end

function UnitSimulator.updateFacingAngle(unit: UnitTypes.UnitRecord, dt: number)
	local delta = MathUtils.angleShortest(unit.facingAngle, unit.targetAngle)
	local maxStep = unit.config.turnSpeed * dt
	delta = math.clamp(delta, -maxStep, maxStep)
	unit.facingAngle += delta
end

return UnitSimulator
