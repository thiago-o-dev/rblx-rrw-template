# LightweightUnit - Client Architecture & Code Specification

## 1. Overview & Principles

The client tier of **LightweightUnit** is located under `src/client/Game/Unit/`. It is responsible for visual model instantiation, timeline snapshot queueing, 60 FPS frame interpolation, animation track playback, and spatial culling.

Key Client Principles:
1. **Zero Simulation Authority**: Client processes received positions purely as visual interpolation targets.
2. **$O(1)$ Ring Buffer Timeline**: Replaces `table.remove(..., 1)` array shifts with constant-time queue lookups.
3. **Zero-Reparenting Spatial Culling**: Off-screen or out-of-range units are hidden via CFrame placement (`CFrame.new(0, -9999, 0)`), preventing expensive scene-graph rebuilds.
4. **Decoupled Render Pipeline**: Interpolation, Animation, and Rendering sit in specialized sub-modules.

---

## 2. Client Presentation Controller: `UnitClientController.luau`

`UnitClientController.luau` initializes client network listeners using **Zap**, tracks server time extrapolation, and drives the render step on `RunService.Heartbeat`.

```lua
--!strict
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NetClient = require(ReplicatedStorage.Shared.Network.Generated.UnitReplicationClient)
local UnitTypes = require(ReplicatedStorage.Shared.Types.UnitTypes)
local RingBuffer = require(ReplicatedStorage.Shared.Core.RingBuffer)
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
	NetClient.InitialUnitState.on(UnitClientController.onInitialUnitState)
	NetClient.UnitPositionBatch.on(UnitClientController.onUnitPositionBatch)
	NetClient.UnitAnimationBatch.on(UnitClientController.onUnitAnimationBatch)
	NetClient.UnitDespawn.on(UnitClientController.onUnitDespawn)

	-- Render Loop
	RunService.Heartbeat:Connect(UnitClientController.onHeartbeat)
end

function UnitClientController.onInitialUnitState(data: {
	unitId: number,
	templateModel: Instance,
	replicationHz: number,
	position: Vector3,
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
		currentCFrame = CFrame.identity,
		isPlaced = false,
		isLoaded = false,
		replicationHz = data.replicationHz,
		invHz = 1 / data.replicationHz,
	}

	UnitClientController.clientUnits[data.unitId] = clientRecord
end

function UnitClientController.onUnitPositionBatch(data: {
	serverTime: number,
	transforms: { { unitId: number, position: Vector3, angle: number } },
})
	UnitClientController.updateServerTime(data.serverTime)

	for _, transform in data.transforms do
		local unitRecord = UnitClientController.clientUnits[transform.unitId]
		if unitRecord then
			local rotCFrame = CFrame.new(transform.position) * CFrame.fromEulerAnglesYXZ(0, transform.angle, 0)
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
	if math.abs(UnitClientController.lastReceivedServerTime - UnitClientController.extrapolatedServerTime) > DEFAULT_CONFIG.RESET_TIME_TOLERANCE then
		UnitClientController.extrapolatedServerTime = UnitClientController.lastReceivedServerTime
	end
end

function UnitClientController.onHeartbeat(dt: number)
	UnitClientController.extrapolatedServerTime += dt

	for unitId, unitRecord in UnitClientController.clientUnits do
		-- RenderTime calculation (backdated by 2 snapshots + ping flux)
		local renderTime = UnitClientController.extrapolatedServerTime - ((unitRecord.invHz * 2) + DEFAULT_CONFIG.BUFFER_FLUX_ESTIMATION)

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
```

---

## 3. Timeline Interpolation Engine: `UnitInterpolator.luau`

`UnitInterpolator.luau` uses $O(1)$ ring buffer indexing to compute the fractional lerp between timeline snapshots.

```lua
--!strict
local UnitTypes = require(game:GetService("ReplicatedStorage").Shared.Types.UnitTypes)

local UnitInterpolator = {}

function UnitInterpolator.sampleTimeline(unit: UnitTypes.ClientUnitRecord, renderTime: number): CFrame?
	local ringBuffer = unit.timeline
	local count = ringBuffer.count

	if count == 0 then
		return nil
	end

	-- Single snapshot fallback
	if count == 1 then
		local single = ringBuffer:get(1)
		return single and single.cframe or nil
	end

	-- Search snapshots for interpolation interval
	local beforeSnapshot = nil
	local afterSnapshot = nil

	for i = count - 1, 1, -1 do
		local s0 = ringBuffer:get(i)
		local s1 = ringBuffer:get(i + 1)
		if s0 and s1 and s0.timestamp <= renderTime and s1.timestamp >= renderTime then
			beforeSnapshot = s0
			afterSnapshot = s1
			break
		end
	end

	if beforeSnapshot and afterSnapshot then
		local duration = afterSnapshot.timestamp - beforeSnapshot.timestamp
		if duration > 0.0001 then
			local fraction = (renderTime - beforeSnapshot.timestamp) / duration
			fraction = math.clamp(fraction, 0, 1)
			return beforeSnapshot.cframe:Lerp(afterSnapshot.cframe, fraction)
		end
		return beforeSnapshot.cframe
	end

	-- Underrun check: renderTime is older than first snapshot
	local oldest = ringBuffer:get(1)
	if oldest and renderTime < oldest.timestamp then
		return oldest.cframe
	end

	-- Overrun: renderTime exceeds newest snapshot
	return nil
end

return UnitInterpolator
```

---

## 4. Multi-Channel Animator: `UnitAnimator.luau`

`UnitAnimator.luau` manages track loading, track caching, and event dispatching.

```lua
--!strict
local UnitTypes = require(game:GetService("ReplicatedStorage").Shared.Types.UnitTypes)

local UnitAnimator = {}
local loadedTrackCache: { [Animator]: { [number]: AnimationTrack } } = {}

function UnitAnimator.processEvents(unit: UnitTypes.ClientUnitRecord, renderTime: number)
	if #unit.eventline == 0 then
		return
	end

	local index = 1
	while index <= #unit.eventline do
		local event = unit.eventline[index]
		if event.timestamp <= renderTime then
			UnitAnimator.playChannelAnimation(unit, event.animIndex, event.channel)
			table.remove(unit.eventline, index)
		else
			index += 1
		end
	end
end

function UnitAnimator.playChannelAnimation(unit: UnitTypes.ClientUnitRecord, animIndex: number, channel: number)
	if not unit.animator then
		return
	end

	local animator = unit.animator
	if not loadedTrackCache[animator] then
		loadedTrackCache[animator] = {}
	end

	local track = loadedTrackCache[animator][animIndex]
	if not track then
		local anim = Instance.new("Animation")
		anim.AnimationId = "rbxassetid://" .. tostring(animIndex)
		track = animator:LoadAnimation(anim)
		loadedTrackCache[animator][animIndex] = track
	end

	if track then
		track:Play()
	end
end

return UnitAnimator
```

---

## 5. Visual Model Renderer & Culling: `UnitRenderer.luau`

`UnitRenderer.luau` applies visual transformations and performs zero-reparenting spatial culling.

```lua
--!strict
local UnitTypes = require(game:GetService("ReplicatedStorage").Shared.Types.UnitTypes)

local CULL_OFFSCREEN_CFRAME = CFrame.new(0, -9999, 0)
local UNIT_CONTAINER_NAME = "Units"

local UnitRenderer = {}

local function getUnitsFolder(): Folder
	local folder = workspace:FindFirstChild(UNIT_CONTAINER_NAME) :: Folder
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = UNIT_CONTAINER_NAME
		folder.Parent = workspace
	end
	return folder
end

function UnitRenderer.renderCFrame(unit: UnitTypes.ClientUnitRecord, targetCFrame: CFrame)
	if not unit.isPlaced then
		unit.isPlaced = true
		unit.model.Parent = getUnitsFolder()
		unit.model:PivotTo(targetCFrame)
		unit.currentCFrame = targetCFrame
		return
	end

	-- Update PivotTo only if model moved meaningfully (delta > 0.01 studs or rotation change)
	if (unit.currentCFrame.Position - targetCFrame.Position).Magnitude > 0.01
		or unit.currentCFrame.LookVector:Dot(targetCFrame.LookVector) < 0.9999
	then
		unit.model:PivotTo(targetCFrame)
		unit.currentCFrame = targetCFrame
	end
end

function UnitRenderer.setCulled(unit: UnitTypes.ClientUnitRecord, isCulled: boolean)
	if isCulled and unit.isPlaced then
		-- Hide off-screen without reparenting to avoid scene-graph rebuild hitches
		unit.model:PivotTo(CULL_OFFSCREEN_CFRAME)
		unit.isPlaced = false
	end
end

function UnitRenderer.despawnModel(unit: UnitTypes.ClientUnitRecord)
	if unit.model then
		unit.model:Destroy()
	end
end

return UnitRenderer
```

---
*Cross-References*:
- [System Overview](file:///C:/Users/Thiago/source/repos/Roblox/rblx-rrw-template/docs/LightweightNpcs/in-depth/overview.md)
- [Server Architecture](file:///C:/Users/Thiago/source/repos/Roblox/rblx-rrw-template/docs/LightweightNpcs/in-depth/server.md)
- [Shared Core & Zap Schema](file:///C:/Users/Thiago/source/repos/Roblox/rblx-rrw-template/docs/LightweightNpcs/in-depth/shared.md)
