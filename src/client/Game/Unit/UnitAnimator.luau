--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UnitTypes = require(ReplicatedStorage.Shared.Types.UnitTypes)

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

function UnitAnimator.playChannelAnimation(unit: UnitTypes.ClientUnitRecord, animIndex: number, _channel: number)
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
