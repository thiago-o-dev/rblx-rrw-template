--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UnitDefinitions = require(ReplicatedStorage.Shared.Definitions.UnitDefinitions)
local UnitTypes = require(ReplicatedStorage.Shared.Types.UnitTypes)

local UnitServerManager = require(script.Parent.UnitServerManager)

local UnitService = {}

function UnitService.createUnit(
	archetypeName: string,
	initialCFrame: CFrame,
	customData: { [string]: any }?
): UnitTypes.UnitId
	local templateConfig = UnitDefinitions.getDefinition(archetypeName)
	assert(templateConfig ~= nil, string.format("Invalid unit archetype: %s", archetypeName))

	local unitRecord =
		UnitServerManager.createUnit(templateConfig, initialCFrame.Position, initialCFrame:ToOrientation(), customData)
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

-- function UnitService.playAnimation(unitId: UnitTypes.UnitId, animName: string, channel: number?): ()
-- 	local unitRecord = UnitServerManager.getUnit(unitId)
-- 	if unitRecord then
-- 		UnitServerManager.playAnimation(unitRecord, animName, channel or 1)
-- 	end
-- end

function UnitService.getUnitByHitbox(hitbox: BasePart): UnitTypes.UnitRecord?
	local unitId = hitbox:GetAttribute("unitId")
	if typeof(unitId) == "number" then
		return UnitServerManager.getUnit(unitId :: number)
	end
	return nil
end

return UnitService
