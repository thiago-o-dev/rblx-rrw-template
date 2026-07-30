--!strict
local lightweightNpcsClientModule = {} :: lightweightNpcsClientModuleType

local MessageId = require(game.ReplicatedFirst.LightweightNpcsClient.Code.MessageId)
local ReadBuffer = require(game.ReplicatedFirst.LightweightNpcsClient.Utils.ReadBuffer)
local ClientNpcTypes = require(game.ReplicatedFirst.LightweightNpcsClient.Code.ClientNpcTypes)
local MathUtils = require(game.ReplicatedFirst.LightweightNpcsClient.Utils.MathUtils)
local SignalModule = require(game.ReplicatedFirst.LightweightNpcsClient.Utils.Signal)
local PositionBits = require(game.ReplicatedFirst.LightweightNpcsClient.Code.PositionBits)

lightweightNpcsClientModule.onNpcLoad = SignalModule.new()

type lightweightNpcsClientModuleType = {

	RemoteEvent: RemoteEvent?,
	UnreliableRemoteEvent: UnreliableRemoteEvent?,

	npcRecords: { [number]: ClientNpcTypes.clientNpcRecordType },

	--Methods (: call notation on everything)
	--Init: (self: customNPCsType) -> (),

	Heartbeat: (self: lightweightNpcsClientModuleType, dt: number) -> (),

	ProcessNewServerTime: (self: lightweightNpcsClientModuleType, newServerTime: number) -> (),
	ProcessPositionBuffer: (self: lightweightNpcsClientModuleType, buffer: buffer) -> (),
	ProcessCleanup: (self: lightweightNpcsClientModuleType, npcId: number) -> (),
	ProcessAnimationBuffer: (self: lightweightNpcsClientModuleType, buffer: buffer) -> (),
	ProcessCustomClientEvent: (self: lightweightNpcsClientModuleType, message: any) -> (),
	ProcessLoad: (self: lightweightNpcsClientModuleType, npcRecord: ClientNpcTypes.clientNpcRecordType) -> (),

	ConfirmMostRecentServerFrame: (self: lightweightNpcsClientModuleType) -> (),

	StartAnimation: (
		self: lightweightNpcsClientModuleType,
		npcRecord: ClientNpcTypes.clientNpcRecordType,
		aimationId: number
	) -> (),

	lastReceivedServerFrame: number,
	lastReceivedServerTime: number,
	extrapolatedServerTime: number,

	onNpcLoad: SignalModule.Signal,
}

local config = {
	doDebugPrinting = true,
	resetTimeTolerance = 0.4,
	maxBufferSize = 10,
	bufferFluxEstimation = 0.004, --adds Xms of ping flux tolerance
	rotationOffset = math.rad(180),
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

function lightweightNpcsClientModule:ProcessCustomClientEvent(message: any)
	local npcRecord = self.npcRecords[message.npcId]

	if npcRecord == nil then
		return
	end

	table.insert(npcRecord.eventline, {
		t = message.t,
		id = MessageId.CustomClientEvent,
		event = message.event,
	})
end

function lightweightNpcsClientModule:ProcessPositionBuffer(bufferObj: buffer)
	local readBufferObject = ReadBuffer.new(bufferObj)

	local count = readBufferObject:ReadU16()
	local serverTime = readBufferObject:ReadFloat32()
	self:ProcessNewServerTime(serverTime)

	for j = 1, count do
		local npcId = readBufferObject:ReadU16() --get the id

		local npcRecord = self.npcRecords[npcId]
		if npcRecord == nil then
			--print("error spawn" , id)
			continue
		end

		local bits = readBufferObject:ReadU8()

		local position

		if bit32.band(bits, PositionBits.CompressionOrigin) > 0 then
			--npcRecord.localOrigin = readBufferObject:ReadVector3()
			--print(self.lastReceivedServerFrame)
			--print("c: Got new origin",npcRecord.localOrigin, " with svFrame", self.lastReceivedServerFrame)
		end

		local position = readBufferObject:ReadVector3()
		local angle = readBufferObject:ReadFloat16()
		local timelineRecord = {}

		timelineRecord.t = serverTime
		timelineRecord.o = CFrame.new(position) * CFrame.fromEulerAngles(0, angle + config.rotationOffset, 0)
		table.insert(npcRecord.timeline, timelineRecord)

		--Trim
		local cutoff = serverTime - (npcRecord.invHz * config.maxBufferSize)
		while npcRecord.timeline[1] and npcRecord.timeline[1].t < cutoff do
			table.remove(npcRecord.timeline, 1)
		end
	end
end

function lightweightNpcsClientModule:ProcessAnimationBuffer(bufferObj: buffer)
	local readBufferObject = ReadBuffer.new(bufferObj)

	local count = readBufferObject:ReadU16()
	local serverTime = readBufferObject:ReadFloat32()
	self:ProcessNewServerTime(serverTime)

	for j = 1, count do
		local npcId = readBufferObject:ReadU16() --get the id

		local channel = readBufferObject:ReadU8()
		local animIndex = readBufferObject:ReadU8()

		local npcRecord = self.npcRecords[npcId]
		if npcRecord == nil then
			--print("error spawn" , id)
			continue
		end
		table.insert(npcRecord.eventline, {
			t = serverTime,
			id = MessageId.AnimationBuffer,
			animIndex = animIndex,
			channel = channel,
		})
	end
end

local function Init()
	lightweightNpcsClientModule.lastReceivedServerTime = 0
	lightweightNpcsClientModule.extrapolatedServerTime = 0
	lightweightNpcsClientModule.lastReceivedServerFrame = -1

	lightweightNpcsClientModule.npcRecords = {}

	lightweightNpcsClientModule.RemoteEvent =
		game.ReplicatedStorage:WaitForChild("LightweightNpcsRemoteEvent") :: RemoteEvent

	lightweightNpcsClientModule.UnreliableRemoteEvent =
		game.ReplicatedStorage:WaitForChild("LightweightNpcsUnreliableRemoteEvent") :: UnreliableRemoteEvent

	--Once the unreliable remote is connected, shoot a message to the server so it knows
	if lightweightNpcsClientModule.RemoteEvent then
		lightweightNpcsClientModule.RemoteEvent:FireServer({ id = MessageId.Welcome })
	end

	if lightweightNpcsClientModule.RemoteEvent then
		lightweightNpcsClientModule.RemoteEvent.OnClientEvent:Connect(function(message: any)
			if message.id == MessageId.Welcome then
				lightweightNpcsClientModule:ProcessNewServerTime(message.serverTime)
				return
			end

			if message.id == MessageId.PositionBuffer then
				lightweightNpcsClientModule:ProcessPositionBuffer(message.buffer)
				return
			end
			if message.id == MessageId.AnimationBuffer then
				lightweightNpcsClientModule:ProcessAnimationBuffer(message.buffer)
				return
			end
			if message.id == MessageId.Cleanup then
				lightweightNpcsClientModule:ProcessCleanup(message.npcId)
				return
			end
			if message.id == MessageId.CustomClientEvent then
				lightweightNpcsClientModule:ProcessCustomClientEvent(message)
				return
			end
			if message.id == MessageId.InitialState then
				--We dont have to wait for replication to occur here
				--because our lil friend is atomic
				if message.inst == nil then
					warn("Instance missing from NPC")
					return
				end

				local model: Model = message.inst :: Model

				local npcRecord: ClientNpcTypes.clientNpcRecordType = {
					instance = model,
					npcId = message.npcId,
					hz = message.hz,
					invHz = 1 / message.hz,
					placed = false,
					timeline = {},
					eventline = {},
					cframe = CFrame.identity,
					animations = message.animationsByIndex,
					playingAnimations = {},
					onCustomEvent = SignalModule.new(),
					loaded = false,
				}

				--Assumes we have a primaryPart
				if npcRecord.instance.PrimaryPart then
					npcRecord.instance.PrimaryPart.Anchored = true
				end

				lightweightNpcsClientModule.npcRecords[npcRecord.npcId] = npcRecord
				return
			end
		end)
	end
end

function lightweightNpcsClientModule:ProcessNewServerTime(serverTime: number)
	self.lastReceivedServerTime = serverTime
	if math.abs(self.lastReceivedServerTime - self.extrapolatedServerTime) > config.resetTimeTolerance then
		print("setting time")
		self.extrapolatedServerTime = self.lastReceivedServerTime
	else
		--print("drift",self.lastReceivedServerTime-self.extrapolatedServerTime)
	end
end

function lightweightNpcsClientModule:ProcessCleanup(npcId: number)
	local record = self.npcRecords[npcId]
	if record then
		record.onCustomEvent:Destroy()
		self.npcRecords[npcId] = nil
	end
end

--This is fed from the event timeline on this npc
function lightweightNpcsClientModule:StartAnimation(
	npcRecord: ClientNpcTypes.clientNpcRecordType,
	animationIndex: number,
	channel: number
)
	local existingTrack = npcRecord.playingAnimations[channel]
	if existingTrack then
		if existingTrack.track then
			existingTrack.track:Stop()
		end
	end

	local trackRecord = npcRecord.animations[animationIndex]
	if trackRecord then
		--npcRecord.currentlyPlayingAnimationIndex = animationIndex
		if trackRecord.track then
			trackRecord.track:Play()
			npcRecord.playingAnimations[channel] = trackRecord
			--[[
			
			local baseSpeed = 1
			if (trackRecord.speed) then
				baseSpeed = trackRecord.speed
			end

			 
			if trackRecord.characterWalkSpeed then
				-- we adjust the speed by the ratio difference between runSpeed and movementSpeed
				-- eg: if runSpeed is 8 and movementSpeed is 16, you'd have to playback at 2x

				local runSpeed = trackRecord.characterWalkSpeed
				local movementSpeed = movementSpeed

				if runSpeed > 0 and movementSpeed > 0 then
					local res = movementSpeed / runSpeed
					res = math.clamp(res, 0.01, 20.0)
					trackRecord.track:AdjustSpeed(res * baseSpeed)
				else
					trackRecord.track:AdjustSpeed(baseSpeed)
				end
			end]]
			--
		end
	end
end

function lightweightNpcsClientModule:ProcessLoad(npcRecord: ClientNpcTypes.clientNpcRecordType)
	npcRecord.loaded = true
	npcRecord.animator = npcRecord.instance:FindFirstChild("Animator", true) :: Animator

	if npcRecord.animator ~= nil and npcRecord.animations ~= nil then
		local animations = npcRecord.animations :: any
		for _, record in animations :: any do
			record.animation = Instance.new("Animation")
			record.animation.AnimationId = record.id
			record.track = npcRecord.animator:LoadAnimation(record.animation)
		end
	end

	self.onNpcLoad:Fire(npcRecord)
end

function lightweightNpcsClientModule:Heartbeat(dt: number)
	self.extrapolatedServerTime += dt

	local underrun = 0 --Not enough points yet, which is expected
	local overrun = 0 --ran out of bufffered points

	for id, npcRecord in self.npcRecords do
		--Read back 1 "snapshot" + plus a little extra for ping flux
		local renderTime = self.extrapolatedServerTime - ((npcRecord.invHz * 2) + config.bufferFluxEstimation)

		local before = nil
		local after = nil
		local found = false
		local orientation = nil

		if #npcRecord.timeline == 0 then
			--Dont have enough data yet
			continue
		end

		if #npcRecord.timeline > 1 then
			for t = #npcRecord.timeline - 1, 1, -1 do
				before = npcRecord.timeline[t]
				after = npcRecord.timeline[t + 1]
				if before.t < renderTime and after.t >= renderTime then
					found = true
					local duration = after.t - before.t
					local fraction = (renderTime - before.t) / duration
					orientation = before.o:Lerp(after.o, fraction)

					--print(#record.timeline - t)
					break
				end
			end
		end

		if found == false then
			--We don't have two points to interpolate between
			--we're either before the buffer or after the buffer
			--work out which one and at least show something...

			if renderTime < npcRecord.timeline[1].t then
				--we have not caught up to the timeline yet
				orientation = npcRecord.timeline[1].o

				underrun += 1
			elseif renderTime > npcRecord.timeline[#npcRecord.timeline].t then
				--we shot off the end of the timeline
				--orientation = npcRecord.timeline[#npcRecord.timeline].o

				--Cull them
				npcRecord.placed = false
				npcRecord.instance.Parent = nil
				overrun += 1
				continue
			end
		end

		if npcRecord.placed == false and orientation ~= nil then
			--push it to the world
			npcRecord.placed = true
			npcRecord.instance.Parent = game.Workspace
			npcRecord.cframe = orientation

			--if its their first time added to the world, load their anims
			if npcRecord.loaded == false then
				lightweightNpcsClientModule:ProcessLoad(npcRecord)
			end

			npcRecord.instance:PivotTo(orientation)
			npcRecord.cframe = orientation
		else
			--pivotTo, but only if its moved
			if
				(npcRecord.cframe.LookVector:Dot(orientation.LookVector) < 0.999999)
				or (npcRecord.cframe.Position - orientation.Position).Magnitude > 0.01
			then
				npcRecord.instance:PivotTo(orientation)
				npcRecord.cframe = orientation
			end
		end

		--Apply events
		while true do
			if #npcRecord.eventline == 0 then
				break
			end
			if npcRecord.eventline[1].t > renderTime then
				break
			end
			local event = npcRecord.eventline[1]

			if event.id == MessageId.AnimationBuffer then
				self:StartAnimation(npcRecord, event.animIndex, event.channel)
			end

			if event.id == MessageId.CustomClientEvent then
				npcRecord.onCustomEvent:Fire(event.event, event.t)
			end

			table.remove(npcRecord.eventline, 1)
		end
	end

	if overrun > 0 then
		--print("lightweightNpcs: buffer overrun:", overrun)
	end
	if underrun > 0 then
		--print("lightweightNpcs: buffer underrun:", underrun)
	end
end

game:GetService("RunService").Heartbeat:Connect(function(dt)
	lightweightNpcsClientModule:Heartbeat(dt)
end)

task.spawn(function()
	Init()
end)

return lightweightNpcsClientModule
