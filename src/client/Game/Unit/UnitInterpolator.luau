--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UnitTypes = require(ReplicatedStorage.Shared.Types.UnitTypes)

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

	-- Overrun check: renderTime exceeds newest snapshot -> hold latest known position
	local newest = ringBuffer:get(count)
	if newest then
		return newest.cframe
	end

	return unit.currentCFrame
end

return UnitInterpolator
