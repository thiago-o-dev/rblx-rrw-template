--!strict
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LemonSignal = require(ReplicatedStorage.Packages.LemonSignal)
local UnitTypes = require(ReplicatedStorage.Shared.Types.UnitTypes)

local UnitNetworkServer = require(script.Parent.UnitNetworkServer)
local UnitSimulator = require(script.Parent.UnitSimulator)

-- TODO: Find how to implement these limits
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
	UnitNetworkServer.onClientHandshake:Connect(UnitServerManager.onPlayerHandshake)

	for _, player in Players:GetPlayers() do
		UnitServerManager.onPlayerAdded(player)
	end

	-- Server Simulation & Replication Heartbeat
	RunService.Heartbeat:Connect(UnitServerManager.onHeartbeat)
end

function UnitServerManager.onPlayerAdded(player: Player)
	print(`Player {player} joined!`)
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

function UnitServerManager.onPlayerHandshake(player: Player)
	UnitServerManager.playerRecords[player].isReady = true
	print(`Player {player} set as ready due to handshake`)
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

function UnitServerManager.onHeartbeat(dt: number)
	local serverTime = workspace:GetServerTimeNow()

	-- 1. Simulation Loop (Think @ thinkHz)
	for _unitId, unitRecord in UnitServerManager.activeUnits do
		if unitRecord.internal.deleteFlag then
			UnitServerManager.destroyUnit(unitRecord)
			continue
		end

		if serverTime >= unitRecord.internal.timeOfNextThink then
			unitRecord.internal.timeOfNextThink = serverTime + (1 / unitRecord.config.thinkHz)
			unitRecord.onThink:Fire(dt)

			-- Execute Physics Sweep
			UnitSimulator.processMovement(unitRecord, dt)
		end
	end

	-- 2. Network Replication Loop (Replicate @ replicationHz)
	UnitNetworkServer.broadcastPositionBatch(UnitServerManager.activeUnits, UnitServerManager.playerRecords, serverTime)

	UnitNetworkServer.broadcastAnimationBatch(
		UnitServerManager.activeUnits,
		UnitServerManager.playerRecords,
		serverTime
	)
end

function UnitServerManager.createUnit(
	config: UnitTypes.UnitConfig,
	position: Vector3,
	angle: number,
	customData: { [string]: any }?
): UnitTypes.UnitRecord
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
		onThink = LemonSignal.new(),
		onDeath = LemonSignal.new(),
		onCleanup = LemonSignal.new(),
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
	unitRecord.onCleanup:Fire()
	UnitNetworkServer.sendDespawn(unitRecord.unitId)

	if unitRecord.hitBox then
		unitRecord.hitBox:Destroy()
	end

	unitRecord.onThink:Destroy()
	unitRecord.onDeath:Destroy()
	unitRecord.onCleanup:Destroy()

	UnitServerManager.activeUnits[unitRecord.unitId] = nil
end

function UnitServerManager.getUnit(unitId: UnitTypes.UnitId): UnitTypes.UnitRecord
	return UnitServerManager.activeUnits[unitId]
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
