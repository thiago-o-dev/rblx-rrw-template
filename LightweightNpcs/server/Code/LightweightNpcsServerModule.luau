--!strict
local lightweightNpcsServerModule = {} :: lightweightNpcsServerModuleType

local MessageId = require(game.ReplicatedFirst.LightweightNpcsClient.Code.MessageId)

local WriteBufferModule = require(game.ReplicatedFirst.LightweightNpcsClient.Utils.WriteBuffer)
local NpcTypes = require(game.ServerScriptService.LightweightNpcs.Code.NpcTypes)
local SignalModule = require(game.ReplicatedFirst.LightweightNpcsClient.Utils.Signal)
local NpcStateModule = require(game.ReplicatedFirst.LightweightNpcsClient.Code.NpcState)
local NpcMover = require(script.Parent.NpcMover)
local PositionBits = require(game.ReplicatedFirst.LightweightNpcsClient.Code.PositionBits)

local config = {
	doDebugPrinting = true,
	debugHitboxes = false,
	targetMaximumTimePerFrame = (1 / 1000) * 3, --x ms
	capServerWorkPerFrame = false,

	doNpcCulling = true,
	cullingUpdateRateHz = 0.5, --every 2 seconds
}

--This isnt the public API: you shouldn't need to be calling any of this
type lightweightNpcsServerModuleType = {
	--Instances
	DoNotReplicate: Camera?,
	RemoteEvent: RemoteEvent?,
	UnreliableRemoteEvent: UnreliableRemoteEvent?,
	--Methods (: call notation on everything)

	CreateNpc: (
		self: lightweightNpcsServerModuleType,
		template: Instance,
		config: any,
		position: Vector3,
		angle: number
	) -> NpcTypes.npcRecordType,
	SendInitialState: (
		self: lightweightNpcsServerModuleType,
		playerRecord: playerRecordType,
		npcRecord: NpcTypes.npcRecordType
	) -> (),
	Heartbeat: (self: lightweightNpcsServerModuleType, dt: number) -> (),
	DestroyNpc: (self: lightweightNpcsServerModuleType, npcRecord: NpcTypes.npcRecordType) -> (),
	CheckForHitpointDeath: (self: lightweightNpcsServerModuleType, npcRecord: NpcTypes.npcRecordType) -> (),
	CheckForCleanup: (self: lightweightNpcsServerModuleType, npcRecord: NpcTypes.npcRecordType) -> boolean,

	playerRecords: { [Player]: playerRecordType },
	npcRecords: { [number]: NpcTypes.npcRecordType },

	timeOffset: number,
	currentServerTime: number,

	nextNpcId: number,
}

type playerRecordType = {
	ready: boolean,
	player: Player,
	SendEvent: (self: playerRecordType, eventData: any) -> (),
}

local _print = print
local function print(...)
	if config.doDebugPrinting then
		_print(...)
	end
end

local _warn = warn
local function warn(...)
	if config.doDebugPrinting then
		_warn(...)
	end
end

local function PlayerConnected(player: Player)
	local playerRecord: playerRecordType = {
		ready = false,
		player = player,
		SendEvent = function(self: playerRecordType, event: any)
			if lightweightNpcsServerModule.RemoteEvent then
				lightweightNpcsServerModule.RemoteEvent:FireClient(player, event)
			end
		end,
	}

	assert(lightweightNpcsServerModule.playerRecords[player] == nil)
	lightweightNpcsServerModule.playerRecords[player] = playerRecord

	playerRecord.player.CharacterAdded:Connect(function()
		for key, npcRecord in lightweightNpcsServerModule.npcRecords do
			npcRecord.internal.timeOfNextCullingCheck = 0 --Reset every npcs cull check when a player spawns
		end
	end)

	--Send them all the existing NPCs
	for key, npcRecord in lightweightNpcsServerModule.npcRecords do
		lightweightNpcsServerModule:SendInitialState(playerRecord, npcRecord)
	end
end

local function PlayerDisconnected(player: Player)
	assert(lightweightNpcsServerModule.playerRecords[player] ~= nil)
	local playerRecord = lightweightNpcsServerModule.playerRecords[player]

	if playerRecord then
		print("Player Disconencted")
		playerRecord.ready = false

		--Clean up keys used for tracking visiblity and reliable data per player
		for key, npcRecord in lightweightNpcsServerModule.npcRecords do
			npcRecord.internal.playerVisibleFlag[player] = nil
			npcRecord.internal.playerReplicationVisible[player] = nil
		end
	end
end

local function UpdateCurrentServerTime()
	lightweightNpcsServerModule.currentServerTime = tick() - lightweightNpcsServerModule.timeOffset
	return lightweightNpcsServerModule.currentServerTime
end

local function GetNextNpcId()
	lightweightNpcsServerModule.nextNpcId += 1
	return lightweightNpcsServerModule.nextNpcId
end

local function Init()
	--This is meant to happen on the first frame so it's there before any client data is replicated
	lightweightNpcsServerModule.DoNotReplicate = Instance.new("Camera")
	if lightweightNpcsServerModule.DoNotReplicate then
		lightweightNpcsServerModule.DoNotReplicate.Name = "DoNotReplicate"
		lightweightNpcsServerModule.DoNotReplicate.Parent = game.Workspace
	end

	lightweightNpcsServerModule.RemoteEvent = Instance.new("RemoteEvent")
	if lightweightNpcsServerModule.RemoteEvent then
		lightweightNpcsServerModule.RemoteEvent.Name = "LightweightNpcsRemoteEvent"
		lightweightNpcsServerModule.RemoteEvent.Parent = game.ReplicatedStorage
	end

	lightweightNpcsServerModule.UnreliableRemoteEvent = Instance.new("UnreliableRemoteEvent")
	if lightweightNpcsServerModule.UnreliableRemoteEvent then
		lightweightNpcsServerModule.UnreliableRemoteEvent.Name = "LightweightNpcsUnreliableRemoteEvent"
		lightweightNpcsServerModule.UnreliableRemoteEvent.Parent = game.ReplicatedStorage
	end

	if lightweightNpcsServerModule.RemoteEvent then --   -_-'
		lightweightNpcsServerModule.RemoteEvent.OnServerEvent:Connect(function(player: Player, data: any)
			local playerRecord = lightweightNpcsServerModule.playerRecords[player]
			if not playerRecord then
				return
			end

			if data.id == MessageId.Welcome then
				--We wait for a ready flag before we send anything.
				--because unreliables just drop data before the connection is ready
				playerRecord.ready = true
				return
			end
		end)
	end

	--init tables
	lightweightNpcsServerModule.playerRecords = {}
	lightweightNpcsServerModule.npcRecords = {}
	lightweightNpcsServerModule.nextNpcId = 0

	--Handle players coming and going
	game.Players.PlayerAdded:Connect(function(player: Player)
		PlayerConnected(player)
	end)

	for key, player in game.Players:GetPlayers() do
		PlayerConnected(player)
	end

	game.Players.PlayerRemoving:Connect(function(player: Player)
		PlayerDisconnected(player)
	end)

	lightweightNpcsServerModule.timeOffset = tick()
	UpdateCurrentServerTime()
end

function GetAnimationState(npcRecord: NpcTypes.npcRecordType)
	local data = {}
	for channel, record in npcRecord.playingAnimations do
		if record and record.index then
			data[channel] = record.index
		else
			data[channel] = 0
		end
	end
	return data
end

function lightweightNpcsServerModule:SendInitialState(playerRecord: playerRecordType, npcRecord: NpcTypes.npcRecordType)
	--Thought: this could be compressed quite a bit with a buffer, but isn't hot path
	playerRecord:SendEvent({
		id = MessageId.InitialState,
		npcId = npcRecord.npcId,
		inst = npcRecord.instance,
		hz = npcRecord.configuration.replicationHzRate,
		pos = npcRecord.position,
		angle = npcRecord.angle,

		animationsByIndex = npcRecord.configuration.animations.animationsByIndex,
		animState = GetAnimationState(npcRecord),
	})
end

local function PickRandom(animTable)
	--Todo: Actually look at the weights etc
	return animTable[1]
end

local function PlayAnimation(
	self: NpcTypes.npcRecordType,
	animName: string,
	forceRestart: boolean,
	channel: number,
	speedMultiplier: number
)
	local existingChannel = self.playingAnimations[channel]
	if existingChannel ~= nil and existingChannel.name == animName and forceRestart == false then
		return -- early out
	end

	local animTable = self.configuration.animations.sourceAnimTable[animName]
	if animTable == nil then
		warn("Missing animation", animName)
		return
	end

	local animTrack = PickRandom(animTable)
	self.playingAnimations[channel] = animTrack

	local animIndex = animTrack.index or 0
	if lightweightNpcsServerModule.RemoteEvent then
		self.internal.pendingAnimationChanges[channel] = animIndex
		--lightweightNpcsServerModule.RemoteEvent:FireAllClients({id = MessageId.AnimationChange, npcId = self.npcId, animIndex = animId, channel = channel, t = lightweightNpcsServerModule.currentServerTime })
	end
end

local function AddClientEvent(self: NpcTypes.npcRecordType, event: any)
	if lightweightNpcsServerModule.RemoteEvent then
		lightweightNpcsServerModule.RemoteEvent:FireAllClients({
			id = MessageId.CustomClientEvent,
			npcId = self.npcId,
			event = event,
			t = lightweightNpcsServerModule.currentServerTime,
		})
	end
end

local function SetPlayerVisibleFlag(self: NpcTypes.npcRecordType, player: Player, visible: boolean)
	self.internal.playerVisibleFlag[player] = visible
end

local function GetPlayerVisibleFlag(self: NpcTypes.npcRecordType, player: Player): boolean
	return self.internal.playerVisibleFlag[player] or true
end

local function ForceReplicate(self: NpcTypes.npcRecordType)
	self.internal.forceReplicate = true
end

local function Move(self: NpcTypes.npcRecordType, motion: Vector3)
	self.motionVector = motion
end

local function Jump(self: NpcTypes.npcRecordType)
	self.jump = true
end

function lightweightNpcsServerModule:CreateNpc(
	template: Instance,
	npcConfig: any,
	position: Vector3,
	angle: number
): NpcTypes.npcRecordType
	local npcId = GetNextNpcId()

	local hitBox = Instance.new("Part")
	hitBox.Size = npcConfig.hitBoxSize
	hitBox.Anchored = true
	hitBox.CollisionGroup = npcConfig.collisionGroup
	hitBox.Name = "NPC"
	hitBox:SetAttribute("npcId", npcId)

	if npcConfig.canCollide then
		hitBox.CanCollide = true
		hitBox.CanQuery = true
		hitBox.CanTouch = true
	else
		hitBox.CanCollide = false
		hitBox.CanQuery = false
		hitBox.CanTouch = false
	end

	hitBox.Position = position

	if config.debugHitboxes == false then
		hitBox.Parent = self.DoNotReplicate
	else
		hitBox.Parent = game.Workspace
	end

	if hitBox.Anchored == false then
		hitBox:SetNetworkOwner(nil)
	end

	local currentInstance = template:Clone() :: Model
	currentInstance.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	currentInstance.Parent = game.ReplicatedStorage
	currentInstance:SetAttribute("npcId", npcId)

	local npcConfiguration: NpcTypes.npcRecordConfiguration = {
		templateInstance = template,
		maximumStepHeight = npcConfig.maximumStepHeight,
		maximumSlopeAngle = npcConfig.maximumSlopeAngle, --Todo!
		replicationHzRate = npcConfig.replicationHzRate,
		thinkHzRate = npcConfig.thinkHzRate,
		motionSize = npcConfig.motionSize,
		groundTolerance = npcConfig.groundTolerance, --Todo: remove this, should be eps
		animations = npcConfig.animations,
		walkSpeed = npcConfig.walkSpeed,
		walkAccel = npcConfig.walkAccel,
		turnSpeed = npcConfig.turnSpeed,
		maxHitPoints = npcConfig.maxHitPoints,
		gravity = npcConfig.gravity,
		jumpPower = npcConfig.jumpPower,
	}

	local npcInternal: NpcTypes.npcRecordInternal = {
		timeOfNextReplicate = 0,
		timeOfNextThink = 0, --if tick() > this
		timeOfLastThink = 0,
		timeOfNextCullingCheck = 0,
		localOrigin = position, --The actual transmitted positions are only float16s, we use this to claw back some precision
		forceReplicate = false,
		forceThink = false,
		isOnGround = false,
		deleteFlag = false,
		pendingAnimationChanges = {}, --These go out in the next animation update packet
		playerReplicationVisible = {},
		playerVisibleFlag = {},
	}

	local npcRecord: NpcTypes.npcRecordType = {
		npcId = npcId,
		hitBox = hitBox,
		instance = currentInstance,

		configuration = npcConfiguration,
		internal = npcInternal,

		npcState = NpcStateModule.Idle,
		position = position,
		angle = angle,
		targetAngle = angle,

		motionVector = Vector3.zero,
		jump = false,
		velocity = Vector3.zero,
		hitPoints = npcConfig.maxHitPoints,
		isOnGround = false,

		onThink = SignalModule.new(),
		onFellOffMap = SignalModule.new(),
		onDeath = SignalModule.new(),
		onCleanup = SignalModule.new(),
		onBumpIntoWall = SignalModule.new(),
		onCrashland = SignalModule.new(),
		onCullCheck = SignalModule.new(),

		PlayAnimation = PlayAnimation,
		AddClientEvent = AddClientEvent,
		SetPlayerVisibleFlag = SetPlayerVisibleFlag,
		GetPlayerVisibleFlag = GetPlayerVisibleFlag,
		ForceReplicate = ForceReplicate,

		Move = Move,
		Jump = Jump,
		playingAnimations = {},
		data = {},
	}

	for key, playerRecord in self.playerRecords do
		self:SendInitialState(playerRecord, npcRecord)
	end

	self.npcRecords[npcRecord.npcId] = npcRecord

	return npcRecord
end

function lightweightNpcsServerModule:CheckForHitpointDeath(npcRecord: NpcTypes.npcRecordType)
	if npcRecord.hitPoints <= 0 then
		--die
		npcRecord.onDeath:Fire()
		npcRecord.internal.deleteFlag = true
	end
end

function lightweightNpcsServerModule:CheckForCleanup(npcRecord: NpcTypes.npcRecordType): boolean
	if npcRecord.internal.deleteFlag then
		self:DestroyNpc(npcRecord)
		return true
	end

	return false
end

function lightweightNpcsServerModule:DestroyNpc(npcRecord: NpcTypes.npcRecordType)
	npcRecord.onCleanup:Fire()
	if npcRecord.instance then
		npcRecord.instance:Destroy()
	end
	self.npcRecords[npcRecord.npcId] = nil

	if self.RemoteEvent then
		self.RemoteEvent:FireAllClients({ id = MessageId.Cleanup, npcId = npcRecord.npcId })
	end

	npcRecord.onThink:Destroy()
	npcRecord.onCleanup:Destroy()
	npcRecord.onFellOffMap:Destroy()
	npcRecord.onDeath:Destroy()
	npcRecord.onBumpIntoWall:Destroy()
	npcRecord.onCrashland:Destroy()
	npcRecord.onCullCheck:Destroy()
end

function lightweightNpcsServerModule:Heartbeat(dt)
	local jobStartTime = tick()
	local serverTime = UpdateCurrentServerTime()
	local jobList: { any } = {}
	local startTime = tick()

	if config.doNpcCulling == true then
		for npcId, npcRecord in self.npcRecords do
			local nextTime = serverTime + (1 / config.cullingUpdateRateHz)
			if serverTime > npcRecord.internal.timeOfNextCullingCheck then
				npcRecord.onCullCheck:Fire()
				npcRecord.internal.timeOfNextCullingCheck = nextTime
			end
		end
	end

	local defer = false
	local deferCount = 0
	for npcID, npcRecord in self.npcRecords do
		if serverTime > npcRecord.internal.timeOfNextThink or npcRecord.internal.forceThink then
			if defer then
				deferCount += 1
				continue
			end
			npcRecord.internal.forceThink = false
			local stepTime: number = serverTime - npcRecord.internal.timeOfLastThink
			stepTime = math.clamp(stepTime, 0, (1 / npcRecord.configuration.thinkHzRate) * 4) --Be reasonable!

			npcRecord.internal.timeOfLastThink = serverTime
			npcRecord.internal.timeOfNextThink = serverTime + (1 / npcRecord.configuration.thinkHzRate)

			npcRecord.onThink:Fire(stepTime)

			self:CheckForHitpointDeath(npcRecord)
			if self:CheckForCleanup(npcRecord) then
				continue
			end

			NpcMover:ProcessMovement(npcRecord, stepTime)

			self:CheckForHitpointDeath(npcRecord)
			if self:CheckForCleanup(npcRecord) then
				continue
			end
		end

		if config.capServerWorkPerFrame == true then
			if not defer then
				local c = tick() - startTime
				if c > config.targetMaximumTimePerFrame then
					defer = true
				end
			end
		end
	end
	if deferCount > 0 then
		print("Deferred:", deferCount)
	end
	--print("Time taken:", tick() - startTime)

	for npcID, npcRecord in self.npcRecords do
		if npcRecord.internal.forceReplicate then
			table.insert(jobList, npcRecord)
			npcRecord.internal.forceReplicate = false
		elseif serverTime > npcRecord.internal.timeOfNextReplicate then
			table.insert(jobList, npcRecord)
			npcRecord.internal.forceReplicate = false
			npcRecord.internal.timeOfNextReplicate = serverTime + (1 / npcRecord.configuration.replicationHzRate)
		end
	end

	for _, playerRecord in self.playerRecords do
		if not playerRecord.ready then
			continue
		end
		--build packet

		local player = playerRecord.player

		local count = 0

		for key, npcRecord in jobList do
			if npcRecord.internal.playerVisibleFlag[player] == true then
				count += 1
			end
		end

		if count == 0 then
			continue
		end

		local writeBuffer = WriteBufferModule.new(count * 10)
		writeBuffer:WriteU16(count)
		writeBuffer:WriteFloat32(serverTime)

		for key, npcRecord in jobList do
			if npcRecord.internal.playerVisibleFlag[player] == true then
				writeBuffer:WriteU16(npcRecord.npcId) --Yknow we could skip this and maintain a table via deltas...
				local bits = 0
				--Teleport bit
				writeBuffer:WriteU8(bits)
				writeBuffer:WriteVector3(npcRecord.position)
				writeBuffer:WriteFloat16(npcRecord.angle)
			end
		end
		local buf = writeBuffer:GetBuffer()
		--print("Count:",count, buffer.len(buf))

		playerRecord:SendEvent({ id = MessageId.PositionBuffer, buffer = buf })
	end

	--Handle all the pending animation Id changes
	for _, playerRecord in self.playerRecords do
		local count = 0
		local player = playerRecord.player
		for npcId, npcRecord in self.npcRecords do
			if npcRecord.internal.playerVisibleFlag[player] == true then
				for channel, animIndex in npcRecord.internal.pendingAnimationChanges do
					count += 1
				end
			end
		end
		if count > 0 then
			local writeBuffer = WriteBufferModule.new((2 + 1 + 1) * count)
			writeBuffer:WriteU16(count)
			writeBuffer:WriteFloat32(serverTime)
			for npcId, npcRecord in self.npcRecords do
				if npcRecord.internal.playerVisibleFlag[player] == true then
					for channel, animIndex in npcRecord.internal.pendingAnimationChanges do
						writeBuffer:WriteU16(npcRecord.npcId)
						writeBuffer:WriteU8(channel)
						writeBuffer:WriteU8(animIndex) --assumes we never have more than 255 anims on a single npc
					end
					npcRecord.internal.pendingAnimationChanges = {}
				end
			end
			local buf = writeBuffer:GetBuffer()
			playerRecord:SendEvent({ id = MessageId.AnimationBuffer, buffer = buf })
		end
	end

	local jobEndTime = ((tick() - jobStartTime) * 1000)
	if jobEndTime > 0.5 then
		--print(string.format("server ms: %.2f", jobEndTime))
	end
end

game["Run Service"].Heartbeat:Connect(function(dt)
	lightweightNpcsServerModule:Heartbeat(dt)
end)

Init()

return lightweightNpcsServerModule
