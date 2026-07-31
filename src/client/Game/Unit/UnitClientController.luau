--!strict
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UnitTypes = require(ReplicatedStorage.Shared.Types.UnitTypes)
local RingBuffer = require(ReplicatedStorage.Shared.Core.RingBuffer)
local Net_UnitClient = require(ReplicatedStorage.Shared.Network.Generated.Net_UnitClient)
local UnitInterpolator = require(script.Parent.UnitInterpolator)
local UnitAnimator = require(script.Parent.UnitAnimator)
local UnitRenderer = require(script.Parent.UnitRenderer)

local DEFAULT_CONFIG = {
	RESET_TIME_TOLERANCE = 0.4,
	BUFFER_FLUX_ESTIMATION = 0.004,
	MAX_BUFFER_SNAPSHOTS = 10,
}

local UnitClientController = {}
UnitClientController.clientUnits = {} :: { [UnitTypes.UnitId]: UnitTypes.ClientUnitRecord }
UnitClientController.extrapolatedServerTime = 0
UnitClientController.lastReceivedServerTime = 0

function UnitClientController.init()
	-- Listen to Zap Events
	Net_UnitClient.InitialUnitState.setCallback(UnitClientController.onInitialUnitState)
	Net_UnitClient.UnitPositionBatch.setCallback(UnitClientController.onUnitPositionBatch)
	Net_UnitClient.UnitAnimationBatch.setCallback(UnitClientController.onUnitAnimationBatch)
	Net_UnitClient.UnitDespawn.setCallback(UnitClientController.onUnitDespawn)

	-- Render Loop
	RunService.Heartbeat:Connect(UnitClientController.onHeartbeat)
end

function UnitClientController.onInitialUnitState(data: {
	unitId: number,
	templateModel: Instance,
	replicationHz: number,
	position: vector,
	angle: number,
})
	if UnitClientController.clientUnits[data.unitId] then
		return
	end

	local model = (data.templateModel:Clone()) :: Model
	model.Name = "UnitVisual_" .. tostring(data.unitId)

	if model.PrimaryPart then
		model.PrimaryPart.Anchored = true
	end

	local clientRecord: UnitTypes.ClientUnitRecord = {
		unitId = data.unitId,
		model = model,
		animator = model:FindFirstChildOfClass("Animator", true),
		timeline = RingBuffer.new(DEFAULT_CONFIG.MAX_BUFFER_SNAPSHOTS),
		eventline = {},
		currentCFrame = CFrame.new(Vector3.new(data.position.x, data.position.y, data.position.z)),
		isPlaced = false,
		isLoaded = false,
		replicationHz = data.replicationHz,
		invHz = 1 / data.replicationHz,
	}

	UnitClientController.clientUnits[data.unitId] = clientRecord
end

function UnitClientController.onUnitPositionBatch(data: {
	serverTime: number,
	transforms: { { unitId: number, position: vector, angle: number } },
})
	UnitClientController.updateServerTime(data.serverTime)

	for _, transform in data.transforms do
		local unitRecord = UnitClientController.clientUnits[transform.unitId]
		if unitRecord then
			local rotCFrame = CFrame.new(Vector3.new(transform.position.x, transform.position.y, transform.position.z))
				* CFrame.fromEulerAnglesYXZ(0, transform.angle, 0)
			unitRecord.timeline:push({
				timestamp = data.serverTime,
				cframe = rotCFrame,
			})
		end
	end
end

function UnitClientController.onUnitAnimationBatch(data: {
	serverTime: number,
	animations: { { unitId: number, channel: number, animIndex: number } },
})
	UnitClientController.updateServerTime(data.serverTime)

	for _, animUpdate in data.animations do
		local unitRecord = UnitClientController.clientUnits[animUpdate.unitId]
		if unitRecord then
			table.insert(unitRecord.eventline, {
				timestamp = data.serverTime,
				channel = animUpdate.channel,
				animIndex = animUpdate.animIndex,
			})
		end
	end
end

function UnitClientController.onUnitDespawn(data: { unitId: number })
	local unitRecord = UnitClientController.clientUnits[data.unitId]
	if unitRecord then
		UnitRenderer.despawnModel(unitRecord)
		UnitClientController.clientUnits[data.unitId] = nil
	end
end

function UnitClientController.updateServerTime(newServerTime: number)
	UnitClientController.lastReceivedServerTime = newServerTime
	if
		math.abs(UnitClientController.lastReceivedServerTime - UnitClientController.extrapolatedServerTime)
		> DEFAULT_CONFIG.RESET_TIME_TOLERANCE
	then
		UnitClientController.extrapolatedServerTime = UnitClientController.lastReceivedServerTime
	end
end

function UnitClientController.onHeartbeat(dt: number)
	UnitClientController.extrapolatedServerTime += dt

	for _unitId, unitRecord in UnitClientController.clientUnits do
		-- RenderTime calculation (backdated by 2 snapshots + ping flux)
		local renderTime = UnitClientController.extrapolatedServerTime
			- ((unitRecord.invHz * 2) + DEFAULT_CONFIG.BUFFER_FLUX_ESTIMATION)

		-- 1. Sample Interpolated CFrame
		local interpolatedCFrame = UnitInterpolator.sampleTimeline(unitRecord, renderTime)
		if interpolatedCFrame then
			UnitRenderer.renderCFrame(unitRecord, interpolatedCFrame)
		else
			-- Overrun: Hide unit off-screen without reparenting
			UnitRenderer.setCulled(unitRecord, true)
		end

		-- 2. Process Animation Event Line
		UnitAnimator.processEvents(unitRecord, renderTime)
	end
end

return UnitClientController
