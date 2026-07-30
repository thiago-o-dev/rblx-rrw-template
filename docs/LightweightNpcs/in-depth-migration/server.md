# LightweightUnit - Server Architecture & Code Specification

## 1. Overview & Principles

The server tier of **LightweightUnit** is located under `src/server/Game/Unit/`. It is built with a single-responsibility architecture where simulation, lifecycle management, public API dispatching, and network replication sit in decoupled, specialized modules.

Key Server Principles:
1. **Zero Visual Rigs on Server**: Server maintains only lightweight `Part` hitboxes inside `Workspace.DoNotReplicate` (or camera container). Visual models reside in `ReplicatedStorage` and stream to clients.
2. **Kinematic Shapecasting**: Physical movement relies on `Workspace:Blockcast` shapecasting (`UnitSimulator.luau`) rather than Roblox PGS physics assemblies.
3. **Zap Binary Replication**: Network packets are serialized and dispatched using Zap generated network code (`UnitNetworkServer.luau`).
4. **Clean Disconnect & Cleanup**: Explicit memory management on player leaving and unit destruction.

---

## 2. Public API Surface: `UnitService.luau`

`UnitService.luau` is the public-facing facade used by game match scripts, AI managers, and server systems to interact with units.

```lua
--!strict
local UnitServerManager = require(script.Parent.UnitServerManager)
local UnitDefinitions = require(game:GetService("ReplicatedStorage").Shared.Definitions.UnitDefinitions)
local UnitTypes = require(game:GetService("ReplicatedStorage").Shared.Types.UnitTypes)

local UnitService = {}

function UnitService.createUnit(archetypeName: string, initialCFrame: CFrame, customData: { [string]: any }?): UnitTypes.UnitId
	local templateConfig = UnitDefinitions.getDefinition(archetypeName)
	assert(templateConfig ~= nil, string.format("Invalid unit archetype: %s", archetypeName))

	local unitRecord = UnitServerManager.createUnit(templateConfig, initialCFrame.Position, initialCFrame:ToOrientation(), customData)
	return unitRecord.unitId
end

function UnitService.destroyUnit(unitId: UnitTypes.UnitId): ()
	local unitRecord = UnitServerManager.getUnit(unitId)
	if unitRecord then
		UnitServerManager.destroyUnit(unitRecord)
	end
end

function UnitService.moveUnit(unitId: UnitTypes.UnitId, motionVector: Vector3): ()
	local unitRecord = UnitServerManager.getUnit(unitId)
	if unitRecord then
		unitRecord.motionVector = motionVector
	end
end

function UnitService.jumpUnit(unitId: UnitTypes.UnitId): ()
	local unitRecord = UnitServerManager.getUnit(unitId)
	if unitRecord then
		unitRecord.jumpRequested = true
	end
end

function UnitService.playAnimation(unitId: UnitTypes.UnitId, animName: string, channel: number?): ()
	local unitRecord = UnitServerManager.getUnit(unitId)
	if unitRecord then
		UnitServerManager.playAnimation(unitRecord, animName, channel or 1)
	end
end

function UnitService.getUnitByHitbox(hitbox: BasePart): UnitTypes.UnitRecord?
	local unitId = hitbox:GetAttribute("unitId")
	if typeof(unitId) == "number" then
		return UnitServerManager.getUnit(unitId :: number)
	end
	return nil
end

return UnitService
```

---

## 3. Lifecycle & Tick Engine: `UnitServerManager.luau`

`UnitServerManager.luau` manages unit registries, player connection states, simulation heartbeat loops, and unit disposal.

```lua
--!strict
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local UnitTypes = require(game:GetService("ReplicatedStorage").Shared.Types.UnitTypes)
local UnitSimulator = require(script.Parent.UnitSimulator)
local UnitNetworkServer = require(script.Parent.UnitNetworkServer)
local Signal = require(game:GetService("ReplicatedStorage").Shared.Core.Signal)

local DEFAULT_CONFIG = {
	MAX_SERVER_TIME_PER_FRAME_MS = 3.0,
	CULLING_UPDATE_RATE_HZ = 0.5,
}

local UnitServerManager = {}
UnitServerManager.activeUnits = {} :: { [UnitTypes.UnitId]: UnitTypes.UnitRecord }
UnitServerManager.playerRecords = {} :: { [Player]: UnitTypes.PlayerRecord }
local nextUnitId: UnitTypes.UnitId = 0

local function getNextUnitId(): UnitTypes.UnitId
	nextUnitId += 1
	return nextUnitId
end

function UnitServerManager.init()
	-- Connect Player Join / Leave
	Players.PlayerAdded:Connect(UnitServerManager.onPlayerAdded)
	Players.PlayerRemoving:Connect(UnitServerManager.onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		UnitServerManager.onPlayerAdded(player)
	end

	-- Server Simulation & Replication Heartbeat
	RunService.Heartbeat:Connect(UnitServerManager.onHeartbeat)
end

function UnitServerManager.onPlayerAdded(player: Player)
	local playerRecord: UnitTypes.PlayerRecord = {
		player = player,
		isReady = false,
		visibleUnits = {},
	}
	UnitServerManager.playerRecords[player] = playerRecord

	-- Replicate existing units to joining player
	for _, unitRecord in UnitServerManager.activeUnits do
		UnitNetworkServer.sendInitialState(player, unitRecord)
	end
end

function UnitServerManager.onPlayerRemoving(player: Player)
	local playerRecord = UnitServerManager.playerRecords[player]
	if playerRecord then
		-- Clean visibility references
		for _, unitRecord in UnitServerManager.activeUnits do
			unitRecord.internal.playerVisibleMap[player] = nil
		end
		UnitServerManager.playerRecords[player] = nil
	end
end

function UnitServerManager.createUnit(config: UnitTypes.UnitConfig, position: Vector3, angle: number, customData: { [string]: any }?): UnitTypes.UnitRecord
	local unitId = getNextUnitId()

	-- Server Hitbox
	local hitBox = Instance.new("Part")
	hitBox.Name = "UnitHitbox_" .. tostring(unitId)
	hitBox.Size = config.hitboxSize
	hitBox.Position = position
	hitBox.Anchored = true
	hitBox.CanCollide = config.canCollide
	hitBox:SetAttribute("unitId", unitId)
	hitBox.Parent = UnitServerManager.getContainer()

	local unitRecord: UnitTypes.UnitRecord = {
		unitId = unitId,
		hitBox = hitBox,
		templateModel = config.templateModel,
		config = config,
		internal = {
			timeOfNextThink = 0,
			timeOfNextReplicate = 0,
			timeOfNextCullCheck = 0,
			forceReplicate = false,
			deleteFlag = false,
			pendingAnimations = {},
			playerVisibleMap = {},
		},
		position = position,
		facingAngle = angle,
		targetAngle = angle,
		velocity = Vector3.zero,
		motionVector = Vector3.zero,
		isOnGround = false,
		jumpRequested = false,
		playingAnimations = {},
		data = customData or {},
		onThink = Signal.new(),
		onDeath = Signal.new(),
		onCleanup = Signal.new(),
	}

	UnitServerManager.activeUnits[unitId] = unitRecord

	-- Send initial state packet via Zap
	for player, playerRecord in UnitServerManager.playerRecords do
		if playerRecord.isReady then
			UnitNetworkServer.sendInitialState(player, unitRecord)
		end
	end

	return unitRecord
end

function UnitServerManager.destroyUnit(unitRecord: UnitTypes.UnitRecord)
	unitRecord.onCleanup:fire()
	UnitNetworkServer.sendDespawn(unitRecord.unitId)

	if unitRecord.hitBox then
		unitRecord.hitBox:Destroy()
	end

	unitRecord.onThink:destroy()
	unitRecord.onDeath:destroy()
	unitRecord.onCleanup:destroy()

	UnitServerManager.activeUnits[unitRecord.unitId] = nil
end

function UnitServerManager.onHeartbeat(dt: number)
	local serverTime = workspace:GetServerTimeNow()

	-- 1. Simulation Loop (Think @ thinkHz)
	for unitId, unitRecord in UnitServerManager.activeUnits do
		if unitRecord.internal.deleteFlag then
			UnitServerManager.destroyUnit(unitRecord)
			continue
		end

		if serverTime >= unitRecord.internal.timeOfNextThink then
			unitRecord.internal.timeOfNextThink = serverTime + (1 / unitRecord.config.thinkHz)
			unitRecord.onThink:fire(dt)

			-- Execute Physics Sweep
			UnitSimulator.processMovement(unitRecord, dt)
		end
	end

	-- 2. Network Replication Loop (Replicate @ replicationHz)
	UnitNetworkServer.broadcastPositionBatch(UnitServerManager.activeUnits, UnitServerManager.playerRecords, serverTime)
	UnitNetworkServer.broadcastAnimationBatch(UnitServerManager.activeUnits, UnitServerManager.playerRecords, serverTime)
end

function UnitServerManager.getContainer(): Instance
	local container = workspace:FindFirstChild("DoNotReplicate")
	if not container then
		local cam = Instance.new("Camera")
		cam.Name = "DoNotReplicate"
		cam.Parent = workspace
		container = cam
	end
	return container
end

return UnitServerManager
```

---

## 4. Physics Kinematic Solver: `UnitSimulator.luau`

`UnitSimulator.luau` encapsulates all shapecasting (`Workspace:Blockcast`), step-up collision handling, ground friction, and rotation lerping.

```lua
--!strict
local MathUtils = require(game:GetService("ReplicatedStorage").Shared.Core.MathUtils)
local UnitTypes = require(game:GetService("ReplicatedStorage").Shared.Types.UnitTypes)

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
	local groundPos, groundHit = sweepMove(unit.position, Vector3.new(0, -unit.config.groundTolerance, 0), unit.config.hitboxSize)
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
				local dropPos, dropHit = sweepMove(stepPos, Vector3.new(0, -unit.config.stepHeight * 1.5, 0), unit.config.hitboxSize)
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
```

---

## 5. Network Replication Layer: `UnitNetworkServer.luau`

`UnitNetworkServer.luau` uses **Zap** to serialize position batches and animation queues, enforcing per-player spatial culling.

```lua
--!strict
local NetServer = require(game:GetService("ServerScriptService").Server.Network.Generated.UnitReplicationServer)
local UnitTypes = require(game:GetService("ReplicatedStorage").Shared.Types.UnitTypes)

local UnitNetworkServer = {}

function UnitNetworkServer.sendInitialState(player: Player, unit: UnitTypes.UnitRecord)
	NetServer.InitialUnitState.fire(player, {
		unitId = unit.unitId,
		templateModel = unit.templateModel,
		replicationHz = unit.config.replicationHz,
		position = unit.position,
		angle = unit.facingAngle,
	})
end

function UnitNetworkServer.sendDespawn(unitId: number)
	NetServer.UnitDespawn.fireAll({
		unitId = unitId,
	})
end

function UnitNetworkServer.broadcastPositionBatch(
	units: { [number]: UnitTypes.UnitRecord },
	players: { [Player]: UnitTypes.PlayerRecord },
	serverTime: number
)
	for player, playerRecord in players do
		if not playerRecord.isReady then
			continue
		end

		local transformList = {}
		for _, unit in units do
			-- Check spatial visibility flag (defaults to true if nil)
			local isVisible = unit.internal.playerVisibleMap[player]
			if isVisible == nil or isVisible == true then
				if serverTime >= unit.internal.timeOfNextReplicate or unit.internal.forceReplicate then
					table.insert(transformList, {
						unitId = unit.unitId,
						position = unit.position,
						angle = unit.facingAngle,
					})
				end
			end
		end

		if #transformList > 0 then
			NetServer.UnitPositionBatch.fire(player, {
				serverTime = serverTime,
				transforms = transformList,
			})
		end
	end

	-- Reset forceReplicate flags after broadcasting to all players
	for _, unit in units do
		unit.internal.forceReplicate = false
	end
end

function UnitNetworkServer.broadcastAnimationBatch(
	units: { [number]: UnitTypes.UnitRecord },
	players: { [Player]: UnitTypes.PlayerRecord },
	serverTime: number
)
	for player, playerRecord in players do
		if not playerRecord.isReady then
			continue
		end

		local animList = {}
		for _, unit in units do
			local isVisible = unit.internal.playerVisibleMap[player]
			if isVisible == nil or isVisible == true then
				for channel, animIndex in unit.internal.pendingAnimations do
					table.insert(animList, {
						unitId = unit.unitId,
						channel = channel,
						animIndex = animIndex,
					})
				end
			end
		end

		if #animList > 0 then
			NetServer.UnitAnimationBatch.fire(player, {
				serverTime = serverTime,
				animations = animList,
			})
		end
	end

	-- Defer clearing pending animations until ALL player packets are compiled
	for _, unit in units do
		table.clear(unit.internal.pendingAnimations)
	end
end

return UnitNetworkServer
```

---
*Cross-References*:
- [System Overview](file:///C:/Users/Thiago/source/repos/Roblox/rblx-rrw-template/docs/LightweightNpcs/in-depth/overview.md)
- [Shared Code & Zap Protocol](file:///C:/Users/Thiago/source/repos/Roblox/rblx-rrw-template/docs/LightweightNpcs/in-depth/shared.md)
- [Client Presentation Architecture](file:///C:/Users/Thiago/source/repos/Roblox/rblx-rrw-template/docs/LightweightNpcs/in-depth/client.md)
